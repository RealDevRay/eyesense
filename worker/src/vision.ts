import { enforceWorkerOutputPolicy } from "./output_policy";

export function boundedTimeoutMs(raw: string | undefined): number {
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return 12_000;
  return Math.min(30_000, Math.max(1_000, Math.floor(parsed)));
}
import { SCENE_AGENT_SYSTEM_PROMPT } from "./prompts";
import { SceneResult, SceneResultSchema, VisionRequest } from "./schema";

export interface VisionEnv {
  GROQ_API_KEY: string;
  GROQ_VISION_MODEL?: string;
  UPSTREAM_TIMEOUT_MS?: string;
}

export async function processVisionRequest(
  req: VisionRequest,
  env: VisionEnv
): Promise<SceneResult> {
  const model = env.GROQ_VISION_MODEL || "qwen/qwen3.8-27b";
  const timeoutMs = boundedTimeoutMs(env.UPSTREAM_TIMEOUT_MS);

  const userPrompt =
    req.mode === "ask" && req.question
      ? `Visual Question: ${req.question}\nTarget Language: ${req.language}\nPlease answer the question based only on the image.`
      : `Action: Describe Scene\nTarget Language: ${req.language}\nPlease provide a concise scene description and note any potential concerns.`;

  const messages = [
    {
      role: "system",
      content: `${SCENE_AGENT_SYSTEM_PROMPT}\n\nYou must return a JSON object with this exact structure:
{
  "summary": "Short scene description in ${req.language}",
  "answer": ${req.mode === "ask" ? `"Answer in ${req.language}"` : "null"},
  "possibleConcern": true | false,
  "concernDescription": "Description of potential concern or null",
  "direction": "left" | "centre" | "right" | "multiple" | "unknown",
  "objects": ["object1", "object2"],
  "imageQuality": "usable" | "unclear",
  "uncertainty": "Description if unclear, otherwise null"
}`,
    },
    {
      role: "user",
      content: [
        { type: "text", text: userPrompt },
        {
          type: "image_url",
          image_url: {
            url: `data:image/jpeg;base64,${req.image.base64}`,
          },
        },
      ],
    },
  ];

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages,
        response_format: { type: "json_object" },
        max_tokens: 512,
        temperature: 0.1,
      }),
      signal: controller.signal,
    });

    if (!res.ok) {
      if (res.status === 429) {
        throw new Error("RATE_LIMITED");
      }
      if (res.status === 401 || res.status === 403) {
        throw new Error("UPSTREAM_AUTH_ERROR");
      }
      throw new Error("UPSTREAM_SERVICE_ERROR");
    }

    const groqJson = (await res.json()) as any;
    const rawContent = groqJson.choices?.[0]?.message?.content;
    if (!rawContent) {
      throw new Error("EMPTY_UPSTREAM_RESPONSE");
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(rawContent);
    } catch {
      throw new Error("INVALID_JSON_RESPONSE");
    }

    const validated = SceneResultSchema.parse(parsed);
    // Enforce server-side output policy and conservative limitations
    const safeResult = enforceWorkerOutputPolicy(validated, req.language);
    return safeResult;
  } catch (err: any) {
    if (err.name === "AbortError") {
      throw new Error("UPSTREAM_TIMEOUT");
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}
