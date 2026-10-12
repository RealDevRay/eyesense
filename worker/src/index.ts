import { AgentDispatch } from "./agents/agent_dispatch";
import {
  ConversationRequestSchema,
  ReadingRequestSchema,
  VisionRequestSchema,
} from "./schema";

export interface Env {
  GROQ_API_KEY: string;
  DEMO_ACCESS_TOKEN?: string;
  GROQ_VISION_MODEL?: string;
  ENABLE_CLOUD_REQUESTS?: string;
  UPSTREAM_TIMEOUT_MS?: string;
}

const MAX_BODY_BYTES = 1.5 * 1024 * 1024; // 1.5 MiB limit

function jsonResponse(data: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}

function errorResponse(code: string, message: string, status: number): Response {
  return jsonResponse({ error: { code, message } }, status);
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

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health check endpoint (public, non-secret)
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({
        status: "ok",
        service: "eyesense-api",
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

      // Check body size limit
      const contentLength = request.headers.get("content-length");
      if (contentLength && parseInt(contentLength, 10) > MAX_BODY_BYTES) {
        return errorResponse("PAYLOAD_TOO_LARGE", "Request body exceeds 1.5 MiB ceiling", 413);
      }

      let bodyText: string;
      try {
        bodyText = await request.text();
        if (bodyText.length > MAX_BODY_BYTES) {
          return errorResponse("PAYLOAD_TOO_LARGE", "Request body exceeds 1.5 MiB ceiling", 413);
        }
      } catch {
        return errorResponse("BAD_REQUEST", "Unable to read request body", 400);
      }

      let parsedBody: any;
      try {
        parsedBody = JSON.parse(bodyText);
      } catch {
        return errorResponse("INVALID_JSON", "Malformed JSON request body", 400);
      }

      // Reject body if it contains disallowed client-supplied credential fields
      if (parsedBody.apiKey || parsedBody.token || parsedBody.secret || parsedBody.providerUrl) {
        return errorResponse("FORBIDDEN_FIELDS", "Credential or custom provider fields are not permitted in hosted requests", 400);
      }

      // Dispatch route
      try {
        if (url.pathname === "/v1/vision") {
          const parseResult = VisionRequestSchema.safeParse(parsedBody);
          if (!parseResult.success) {
            return errorResponse("VALIDATION_ERROR", parseResult.error.message, 400);
          }
          const result = await AgentDispatch.processVision(parseResult.data, env);
          return jsonResponse({
            requestId: parseResult.data.requestId,
            result,
          });
        }

        if (url.pathname === "/v1/reading") {
          const parseResult = ReadingRequestSchema.safeParse(parsedBody);
          if (!parseResult.success) {
            return errorResponse("VALIDATION_ERROR", parseResult.error.message, 400);
          }
          const result = await AgentDispatch.processReading(parseResult.data, env);
          return jsonResponse({
            requestId: parseResult.data.requestId,
            result,
          });
        }

        if (url.pathname === "/v1/conversation") {
          const parseResult = ConversationRequestSchema.safeParse(parsedBody);
          if (!parseResult.success) {
            return errorResponse("VALIDATION_ERROR", parseResult.error.message, 400);
          }
          const plan = await AgentDispatch.processConversation(parseResult.data, env);
          return jsonResponse({
            requestId: parseResult.data.requestId,
            plan,
          });
        }

        return errorResponse("NOT_FOUND", "Endpoint not found", 404);
      } catch (err: any) {
        if (err.message === "RATE_LIMITED") {
          return errorResponse("RATE_LIMITED", "Upstream AI rate limit encountered. Please retry shortly.", 429);
        }
        if (err.message === "UPSTREAM_TIMEOUT") {
          return errorResponse("GATEWAY_TIMEOUT", "Upstream AI service timed out", 504);
        }
        if (err.message === "UPSTREAM_AUTH_ERROR") {
          return errorResponse("BAD_GATEWAY", "Upstream authorization error", 502);
        }
        return errorResponse("INTERNAL_ERROR", "An unexpected error occurred during processing", 500);
      }
    }

    return errorResponse("NOT_FOUND", "Not found", 404);
  },
};
