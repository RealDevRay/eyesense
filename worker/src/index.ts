import { AgentDispatch } from "./agents/agent_dispatch";
import {
  BudgetDecision,
  BudgetDurableObject,
  chargeClient,
  preparseClient,
  releaseClient,
} from "./budget";
import { VisionRequestSchema } from "./schema";

export { BudgetDurableObject };

export interface Env {
  GROQ_API_KEY: string;
  DEMO_ACCESS_TOKEN?: string;
  GROQ_VISION_MODEL?: string;
  ENABLE_CLOUD_REQUESTS?: string;
  UPSTREAM_TIMEOUT_MS?: string;
  BUDGET?: DurableObjectNamespace;
}

const MAX_BODY_BYTES = 1.5 * 1024 * 1024;

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

function timingSafeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  const length = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

function authenticate(request: Request, env: Env): boolean {
  if (!env.DEMO_ACCESS_TOKEN) return false;
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return false;
  const token = authHeader.substring(7).trim();
  return timingSafeEqual(token, env.DEMO_ACCESS_TOKEN);
}

export async function readBodyWithLimit(request: Request, maxBytes: number): Promise<string> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^\d+$/.test(contentLength.trim())) {
      throw new Error("BAD_CONTENT_LENGTH");
    }
    if (parseInt(contentLength, 10) > maxBytes) {
      throw new Error("PAYLOAD_TOO_LARGE");
    }
  }

  if (!request.body) return "";

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

function budgetError(decision: BudgetDecision): Response {
  const status = decision.code === "DAILY_BUDGET_EXHAUSTED" ? 503 : 429;
  return errorResponse(
    decision.code || "RATE_LIMITED",
    decision.message || "Rate limit exceeded",
    status,
    decision.retryAfter ? { "Retry-After": decision.retryAfter.toString() } : {},
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      return jsonResponse({ status: "ok" });
    }

    if (url.pathname.startsWith("/v1/")) {
      if (request.method !== "POST") {
        return errorResponse("METHOD_NOT_ALLOWED", "Method not allowed", 405);
      }

      if (env.ENABLE_CLOUD_REQUESTS === "false") {
        return errorResponse("CLOUD_DISABLED", "Cloud processing is currently disabled on the server", 503);
      }

      if (!authenticate(request, env)) {
        return errorResponse("UNAUTHORIZED", "Missing or invalid demo access token", 401);
      }

      const clientKey = request.headers.get("CF-Connecting-IP") || "default_client";
      const throttle = await preparseClient(env.BUDGET, clientKey);
      if (!throttle.allowed) return budgetError(throttle);

      let bodyText: string;
      try {
        bodyText = await readBodyWithLimit(request, MAX_BODY_BYTES);
      } catch (err: any) {
        if (err.message === "PAYLOAD_TOO_LARGE") {
          return errorResponse("PAYLOAD_TOO_LARGE", "Request body exceeds 1.5 MiB ceiling", 413);
        }
        if (err.message === "BAD_CONTENT_LENGTH") {
          return errorResponse("BAD_REQUEST", "Content-Length must be a number.", 400);
        }
        return errorResponse("BAD_REQUEST", "Unable to read request body", 400);
      }

      let parsedBody: any;
      try {
        parsedBody = JSON.parse(bodyText);
      } catch {
        return errorResponse("INVALID_JSON", "Malformed JSON request body", 400);
      }

      if (!parsedBody || typeof parsedBody !== "object" || Array.isArray(parsedBody)) {
        return errorResponse("INVALID_JSON", "Request body must be a non-null JSON object", 400);
      }

      if (parsedBody.apiKey || parsedBody.token || parsedBody.secret || parsedBody.providerUrl) {
        return errorResponse(
          "FORBIDDEN_FIELDS",
          "Credential or custom provider fields are not permitted in hosted requests",
          400,
        );
      }

      if (url.pathname === "/v1/reading" || url.pathname === "/v1/conversation") {
        return errorResponse("ROUTE_DISABLED", "This endpoint is disabled for the pilot release.", 404);
      }

      if (url.pathname === "/v1/vision") {
        const parseResult = VisionRequestSchema.safeParse(parsedBody);
        if (!parseResult.success) {
          return errorResponse("VALIDATION_ERROR", "Request did not match the expected format.", 400);
        }

        const budgetCheck = await chargeClient(env.BUDGET, clientKey);
        if (!budgetCheck.allowed) return budgetError(budgetCheck);

        try {
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
          await releaseClient(env.BUDGET);
        }
      }

      return errorResponse("NOT_FOUND", "Endpoint not found", 404);
    }

    return errorResponse("NOT_FOUND", "Not found", 404);
  },
};
