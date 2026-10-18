import { describe, expect, it } from "vitest";
import worker from "../src/index";
import { memoryBudget, previewCharge, resetMemoryBudget, secondsUntilUtcMidnight, utcDayKey } from "../src/budget";
import { enforceWorkerOutputPolicy } from "../src/output_policy";
import { SceneResult } from "../src/schema";
import { boundedTimeoutMs } from "../src/vision";

const mockEnv = {
  GROQ_API_KEY: "test-api-key",
  DEMO_ACCESS_TOKEN: "valid-secret-token",
  GROQ_VISION_MODEL: "qwen/qwen3.8-27b",
  ENABLE_CLOUD_REQUESTS: "true",
  UPSTREAM_TIMEOUT_MS: "12000",
};

describe("EyeSense Cloudflare Worker", () => {
  it("GET /health returns only a status", async () => {
    const req = new Request("https://api.eyesense.dev/health", { method: "GET" });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(200);

    const body = (await res.json()) as any;
    expect(body).toEqual({ status: "ok" });
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
    expect(safeResult.possibleConcern).toBe(false);
    expect(safeResult.concernDescription).toBeNull();

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
    expect(safeResultSw.possibleConcern).toBe(false);
    expect(safeResultSw.concernDescription).toBeNull();
  });

  it("replaces only the fields that violate the output policy", () => {
    const mixed: SceneResult = {
      summary: "A doorway is ahead.",
      answer: "It is safe to cross.",
      possibleConcern: true,
      concernDescription: "A box blocks part of the doorway.",
      direction: "centre",
      objects: ["door", "safe to cross"],
      imageQuality: "usable",
      uncertainty: "The path is clear.",
    };
    const safe = enforceWorkerOutputPolicy(mixed, "en");
    expect(safe.summary).toBe("A doorway is ahead.");
    expect(safe.concernDescription).toBe("A box blocks part of the doorway.");
    expect(safe.answer).toContain("cannot determine path safety");
    expect(safe.objects).toEqual(["door", "unspecified"]);
    expect(safe.uncertainty).toContain("Safety limitation");
  });

  it("enforces daily budget limits and returns 503 with Retry-After until UTC midnight", async () => {
    resetMemoryBudget();
    memoryBudget.snapshot.dailyCount = 1000;
    memoryBudget.snapshot.dailyKey = utcDayKey(Date.now());

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
    expect(res.headers.get("Retry-After")).toBe(String(secondsUntilUtcMidnight(Date.now())));
    resetMemoryBudget();
  });

  it("resets a daily budget on the next UTC date, including the same day-of-month", () => {
    const january = Date.parse("2026-01-15T12:00:00Z");
    const february = Date.parse("2026-02-15T00:30:00Z");
    const exhausted = previewCharge(
      { concurrent: 0, dailyCount: 1000, dailyKey: "2026-01-15", minutes: {}, preparse: {} },
      "client",
      january,
    );
    expect(exhausted.decision.allowed).toBe(false);
    expect(exhausted.decision.retryAfter).toBe(secondsUntilUtcMidnight(january));
    expect(exhausted.decision.retryAfter).not.toBe(3600);

    const reset = previewCharge(exhausted.state, "client", february);
    expect(reset.decision.allowed).toBe(true);
    expect(reset.state.dailyKey).toBe("2026-02-15");
    expect(reset.state.dailyCount).toBe(1);
  });

  it("does not let two reservations from the same snapshot both succeed", async () => {
    const start = { concurrent: 9, dailyCount: 0, dailyKey: utcDayKey(Date.now()), minutes: {}, preparse: {} };
    const first = previewCharge(start, "a", Date.now());
    const second = previewCharge(start, "b", Date.now());
    expect(first.decision.allowed && second.decision.allowed).toBe(true);

    resetMemoryBudget();
    memoryBudget.snapshot.concurrent = 9;
    const [left, right] = await Promise.all([
      import("../src/budget").then((budget) => budget.memoryExclusive(() => memoryBudget.charge("a"))),
      import("../src/budget").then((budget) => budget.memoryExclusive(() => memoryBudget.charge("b"))),
    ]);
    expect([left.allowed, right.allowed].filter(Boolean)).toHaveLength(1);
    expect(memoryBudget.snapshot.concurrent).toBe(10);
    resetMemoryBudget();
  });

  it("does not charge the daily budget for a malformed authenticated request", async () => {
    resetMemoryBudget();
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
      },
      body: JSON.stringify({ requestId: "not-a-uuid" }),
    });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(400);
    expect(memoryBudget.snapshot.dailyCount).toBe(0);
    expect(memoryBudget.snapshot.preparse.default_client.count).toBe(1);
  });

  it("rejects a non-numeric Content-Length", async () => {
    const req = new Request("https://api.eyesense.dev/v1/vision", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-secret-token",
        "Content-Length": "nope",
      },
      body: JSON.stringify({}),
    });
    const res = await worker.fetch(req, mockEnv);
    expect(res.status).toBe(400);
  });

  it("bounds a non-numeric upstream timeout", () => {
    expect(boundedTimeoutMs(undefined)).toBe(12000);
    expect(boundedTimeoutMs("not-a-number")).toBe(12000);
    expect(boundedTimeoutMs("500")).toBe(1000);
    expect(boundedTimeoutMs("999999")).toBe(30000);
  });
});
