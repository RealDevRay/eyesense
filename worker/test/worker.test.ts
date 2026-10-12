import { describe, expect, it } from "vitest";
import worker from "../src/index";

const mockEnv = {
  GROQ_API_KEY: "test-api-key",
  DEMO_ACCESS_TOKEN: "valid-secret-token",
  GROQ_VISION_MODEL: "qwen/qwen3.8-27b",
  ENABLE_CLOUD_REQUESTS: "true",
  UPSTREAM_TIMEOUT_MS: "12000",
};

describe("EyeSense Cloudflare Worker", () => {
  it("GET /health returns 200 with service metadata", async () => {
    const req = new Request("https://api.eyesense.dev/health", { method: "GET" });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(200);

    const body = (await res.json()) as any;
    expect(body.status).toBe("ok");
    expect(body.service).toBe("eyesense-api");
    expect(body.cloudEnabled).toBe(true);
  });

  it("POST /v1/vision fails with 401 when Authorization header is missing", async () => {
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ requestId: "123e4567-e89b-12d3-a456-426614174000" }),
    });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(401);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("UNAUTHORIZED");
  });

  it("POST /v1/vision rejects requests containing client apiKey in body", async () => {
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({
        requestId: "123e4567-e89b-12d3-a456-426614174000",
        apiKey: "unauthorized-client-key",
      }),
    });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(400);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("FORBIDDEN_FIELDS");
  });

  it("POST /v1/vision returns 503 when ENABLE_CLOUD_REQUESTS is false", async () => {
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({ requestId: "123e4567-e89b-12d3-a456-426614174000" }),
    });
    const res = await worker.fetch(req, { ...mockEnv, ENABLE_CLOUD_REQUESTS: "false" });
    expect(res.status).toBe(503);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("CLOUD_DISABLED");
  });

  it("POST /v1/vision returns 400 on malformed schema", async () => {
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({
        requestId: "invalid-uuid",
        mode: "describe",
      }),
    });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(400);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("VALIDATION_ERROR");
  });
});
