import { describe, expect, it } from "vitest";
import worker, { budgetState } from "../src/index";
import { enforceWorkerOutputPolicy } from "../src/output_policy";
import { SceneResult } from "../src/schema";

const mockEnv = {
  GROQ_API_KEY: "test-api-key",
  DEMO_ACCESS_TOKEN: "valid-secret-token",
  GROQ_VISION_MODEL: "qwen/qwen3.8-27b",
  ENABLE_CLOUD_REQUESTS: "true",
  UPSTREAM_TIMEOUT_MS: "12000",
};

describe("EyeSense Cloudflare Worker", () => {
  it("GET /health returns 200 with service metadata and ready status", async () => {
    const req = new Request("https://api.eyesense.dev/health", { method: "GET" });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(200);

    const body = (await res.json()) as any;
    expect(body.status).toBe("ok");
    expect(body.ready).toBe(true);
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

  it("rejects non-object bodies (arrays, primitives, null) with INVALID_JSON", async () => {
    const payloads = [
      JSON.stringify(["array", "not", "object"]),
      JSON.stringify(42),
      JSON.stringify("string"),
      JSON.stringify(null),
    ];

    for (const bodyStr of payloads) {
      const req = new Request("https://api.eyesense.dev/v1/vision", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer valid-secret-token",
        },
        body: bodyStr,
      });
      const res = await worker.fetch(req, mockEnv);
      expect(res.status).toBe(400);
      const data = (await res.json()) as any;
      expect(data.error.code).toBe("INVALID_JSON");
    }
  });

  it("disables deferred routes /v1/reading and /v1/conversation with ROUTE_DISABLED 404", async () => {
    for (const route of ["/v1/reading", "/v1/conversation"]) {
      const req = new Request(`https://api.eyesense.dev${route}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer valid-secret-token",
        },
        body: JSON.stringify({ test: "data" }),
      });
      const res = await worker.fetch(req, mockEnv);
      expect(res.status).toBe(404);
      const data = (await res.json()) as any;
      expect(data.error.code).toBe("ROUTE_DISABLED");
    }
  });

  it("rejects non-JPEG base64 and whitespace questions in ask mode", async () => {
    // 1. Invalid image base64 (not starting with /9j)
    const reqBadImage = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({
        requestId: "123e4567-e89b-12d3-a456-426614174000",
        mode: "describe",
        image: {
          mimeType: "image/jpeg",
          base64: "iVBORw0KGgo=", // PNG header
        },
      }),
    });
    const resBadImage = await worker.fetch(reqBadImage, mockEnv);
    expect(resBadImage.status).toBe(400);
    const bodyBadImage = (await resBadImage.json()) as any;
    expect(bodyBadImage.error.code).toBe("VALIDATION_ERROR");

    // 2. Ask mode without question
    const reqEmptyAsk = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({
        requestId: "123e4567-e89b-12d3-a456-426614174000",
        mode: "ask",
        question: "   ",
        image: {
          mimeType: "image/jpeg",
          base64: "/9j/4AAQSkZJRg==",
        },
      }),
    });
    const resEmptyAsk = await worker.fetch(reqEmptyAsk, mockEnv);
    expect(resEmptyAsk.status).toBe(400);
    const bodyEmptyAsk = (await resEmptyAsk.json()) as any;
    expect(bodyEmptyAsk.error.code).toBe("VALIDATION_ERROR");
  });

  it("enforces conservative limitation response on prohibited navigation output", () => {
    const unsafeEnglish: SceneResult = {
      summary: "The road is safe to cross and the path is clear ahead.",
      answer: "Cross now, no hazards present.",
      possibleConcern: false,
      concernDescription: null,
      direction: "centre",
      objects: ["crosswalk", "road"],
      imageQuality: "usable",
      uncertainty: null,
    };

    const safeResult = enforceWorkerOutputPolicy(unsafeEnglish, "en");
    expect(safeResult.summary).toContain("EyeSense cannot confirm navigation safety or crossing decisions");
    expect(safeResult.answer).toContain("EyeSense cannot determine path safety or crossing decisions");
    expect(safeResult.possibleConcern).toBe(true);
    expect(safeResult.concernDescription).toContain("Safety limitation");

    // Swahili limitation test
    const unsafeSwahili: SceneResult = {
      summary: "Ni salama kuvuka barabara sasa, njia iko wazi.",
      answer: "Vuka sasa.",
      possibleConcern: false,
      concernDescription: null,
      direction: "centre",
      objects: ["barabara"],
      imageQuality: "usable",
      uncertainty: null,
    };

    const safeResultSw = enforceWorkerOutputPolicy(unsafeSwahili, "sw");
    expect(safeResultSw.summary).toContain("haiwezi kuthibitisha njia salama");
    expect(safeResultSw.answer).toContain("haiwezi kuamua usalama wa njia au kuvuka");
    expect(safeResultSw.possibleConcern).toBe(true);
  });

  it("enforces daily budget limits and returns 503 with Retry-After header", async () => {
    // Temporarily saturate daily count
    const originalCount = budgetState.dailyCount;
    budgetState.dailyCount = 1000;

    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({
        requestId: "123e4567-e89b-12d3-a456-426614174000",
        mode: "describe",
        image: {
          mimeType: "image/jpeg",
          base64: "/9j/4AAQSkZJRg==",
        },
      }),
    });

    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(503);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("DAILY_BUDGET_EXHAUSTED");
    expect(res.headers.get("Retry-After")).toBe("3600");

    // Restore count
    budgetState.dailyCount = originalCount;
  });
});
