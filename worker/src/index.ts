import { AgentDispatch } from "./agents/agent_dispatch";
import { VisionRequestSchema } from "./schema";

export interface Env {
  GROQ_API_KEY: string;
  DEMO_ACCESS_TOKEN?: string;
  GROQ_VISION_MODEL?: string;
  ENABLE_CLOUD_REQUESTS?: string;
  UPSTREAM_TIMEOUT_MS?: string;
}

const MAX_BODY_BYTES = 1.5 * 1024 * 1024; // 1.5 MiB limit

export function jsonResponse(data: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}

export function errorResponse(code: string, message: string, status: number, headers: HeadersInit = {}): Response {
  return jsonResponse({ error: { code, message } }, status, headers);
}

function authenticate(request: Request, env: Env): boolean {
  if (!env.DEMO_ACCESS_TOKEN) {
    // If no demo token configured, fail closed
    return false;
  }
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return false;
  }
  const token = authHeader.substring(7).trim();
  return token === env.DEMO_ACCESS_TOKEN;
}

// Bounded body reader reading with cumulative byte limits
export async function readBodyWithLimit(request: Request, maxBytes: number): Promise<string> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && parseInt(contentLength, 10) > maxBytes) {
    throw new Error("PAYLOAD_TOO_LARGE");
  }

  if (!request.body) {
    return "";
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) {
        totalBytes += value.byteLength;
        if (totalBytes > maxBytes) {
          await reader.cancel("Payload limit exceeded");
          throw new Error("PAYLOAD_TOO_LARGE");
        }
        chunks.push(value);
      }
    }
  } finally {
    reader.releaseLock();
  }

  const concatenated = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    concatenated.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(concatenated);
}

// In-memory rate and budget tracking
interface BudgetState {
  currentConcurrent: number;
  dailyCount: number;
  dailyResetDay: number;
  minuteCounts: Map<string, { count: number; windowStart: number }>;
}

const MAX_CONCURRENT = 10;
const MAX_PER_MINUTE = 30;
const MAX_DAILY = 1000;

export const budgetState: BudgetState = {
  currentConcurrent: 0,
  dailyCount: 0,
  dailyResetDay: new Date().getUTCDate(),
  minuteCounts: new Map(),
};

export function checkRateAndBudget(clientKey: string): {
  allowed: boolean;
  code?: string;
  message?: string;
  retryAfter?: number;
} {
  const now = Date.now();
  const currentDay = new Date().getUTCDate();

  // Daily budget reset at 00:00 UTC
  if (budgetState.dailyResetDay !== currentDay) {
    budgetState.dailyCount = 0;
    budgetState.dailyResetDay = currentDay;
    budgetState.minuteCounts.clear();
  }

  if (budgetState.dailyCount >= MAX_DAILY) {
    return {
      allowed: false,
      code: "DAILY_BUDGET_EXHAUSTED",
      message: "Daily hosted usage allowance reached. Please use local Read Text or retry tomorrow.",
      retryAfter: 3600,
    };
  }

  if (budgetState.currentConcurrent >= MAX_CONCURRENT) {
    return {
      allowed: false,
      code: "CONCURRENCY_LIMIT_REACHED",
      message: "Too many concurrent requests. Please wait a moment and retry.",
      retryAfter: 3,
    };
  }

  let clientThrottle = budgetState.minuteCounts.get(clientKey);
  if (!clientThrottle || now - clientThrottle.windowStart > 60000) {
    clientThrottle = { count: 0, windowStart: now };
    budgetState.minuteCounts.set(clientKey, clientThrottle);
  }

  if (clientThrottle.count >= MAX_PER_MINUTE) {
    const retryAfter = Math.ceil((clientThrottle.windowStart + 60000 - now) / 1000);
    return {
      allowed: false,
      code: "RATE_LIMITED",
      message: "Client rate limit reached. Please wait before retrying.",
      retryAfter: Math.max(1, retryAfter),
    };
  }

  clientThrottle.count++;
  budgetState.dailyCount++;
  budgetState.currentConcurrent++;
  return { allowed: true };
}

export function releaseConcurrent() {
  if (budgetState.currentConcurrent > 0) {
    budgetState.currentConcurrent--;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health and root status endpoint (public, non-secret)
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      const isConfigured = !!env.GROQ_API_KEY && !!env.DEMO_ACCESS_TOKEN;
      return jsonResponse({
        status: "ok",
        ready: isConfigured,
        service: "eyesense-api",
        description: "EyeSense Visual Assistance API Proxy",
        cloudEnabled: env.ENABLE_CLOUD_REQUESTS !== "false",
        version: "1.0.0",
      });
    }

    // All /v1/* endpoints require POST and authentication
    if (url.pathname.startsWith("/v1/")) {
      if (request.method !== "POST") {
        return errorResponse("METHOD_NOT_ALLOWED", "Method not allowed", 405);
      }

      // Check cloud requests toggle
      if (env.ENABLE_CLOUD_REQUESTS === "false") {
        return errorResponse("CLOUD_DISABLED", "Cloud processing is currently disabled on the server", 503);
      }

      // Check bearer token authentication
      if (!authenticate(request, env)) {
        return errorResponse("UNAUTHORIZED", "Missing or invalid demo access token", 401);
      }

      // Bounded body reading with cumulative byte limits
      let bodyText: string;
      try {
        bodyText = await readBodyWithLimit(request, MAX_BODY_BYTES);
      } catch (err: any) {
        if (err.message === "PAYLOAD_TOO_LARGE") {
          return errorResponse("PAYLOAD_TOO_LARGE", "Request body exceeds 1.5 MiB ceiling", 413);
        }
        return errorResponse("BAD_REQUEST", "Unable to read request body", 400);
      }

      // Validate parsed JSON as non-null object
      let parsedBody: any;
      try {
        parsedBody = JSON.parse(bodyText);
      } catch {
        return errorResponse("INVALID_JSON", "Malformed JSON request body", 400);
      }

      if (!parsedBody || typeof parsedBody !== "object" || Array.isArray(parsedBody)) {
        return errorResponse("INVALID_JSON", "Request body must be a non-null JSON object", 400);
      }

      // Reject body if it contains disallowed client-supplied credential fields
      if (parsedBody.apiKey || parsedBody.token || parsedBody.secret || parsedBody.providerUrl) {
        return errorResponse("FORBIDDEN_FIELDS", "Credential or custom provider fields are not permitted in hosted requests", 400);
      }

      // Explicit route scoping: /v1/reading and /v1/conversation are deferred for pilot
      if (url.pathname === "/v1/reading" || url.pathname === "/v1/conversation") {
        return errorResponse("ROUTE_DISABLED", "This endpoint is disabled for the pilot release.", 404);
      }

      if (url.pathname === "/v1/vision") {
        const clientKey = request.headers.get("CF-Connecting-IP") || "default_client";
        const budgetCheck = checkRateAndBudget(clientKey);
        if (!budgetCheck.allowed) {
          const status = budgetCheck.code === "DAILY_BUDGET_EXHAUSTED" ? 503 : 429;
          return errorResponse(
            budgetCheck.code || "RATE_LIMITED",
            budgetCheck.message || "Rate limit exceeded",
            status,
            budgetCheck.retryAfter ? { "Retry-After": budgetCheck.retryAfter.toString() } : {}
          );
        }

        try {
          const parseResult = VisionRequestSchema.safeParse(parsedBody);
          if (!parseResult.success) {
            return errorResponse("VALIDATION_ERROR", parseResult.error.message, 400);
          }

          const result = await AgentDispatch.processVision(parseResult.data, env);
          return jsonResponse({
            requestId: parseResult.data.requestId,
            result,
          });
        } catch (err: any) {
          if (err.message === "RATE_LIMITED") {
            return errorResponse("RATE_LIMITED", "Upstream AI rate limit encountered. Please retry shortly.", 429);
          }
          if (err.message === "UPSTREAM_TIMEOUT") {
            return errorResponse("GATEWAY_TIMEOUT", "Upstream AI service timed out", 504);
          }
          if (err.message === "UPSTREAM_AUTH_ERROR") {
            return errorResponse("BAD_GATEWAY", "Upstream provider authentication failed", 502);
          }
          if (err.message === "UPSTREAM_SERVICE_ERROR") {
            return errorResponse("BAD_GATEWAY", "Upstream AI provider error. Please try again.", 502);
          }
          return errorResponse("INTERNAL_ERROR", "Internal service error occurred during vision processing", 500);
        } finally {
          releaseConcurrent();
        }
      }

      return errorResponse("NOT_FOUND", "Endpoint not found", 404);
    }

    return errorResponse("NOT_FOUND", "Not found", 404);
  },
};
