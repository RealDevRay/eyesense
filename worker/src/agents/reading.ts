import { READING_AGENT_SYSTEM_PROMPT } from "../prompts";
import { ReadingRequest, ReadingResult, ReadingResultSchema } from "../schema";
import { VisionEnv } from "../vision";

export async function processReadingRequest(
  req: ReadingRequest,
  env: VisionEnv
): Promise<ReadingResult> {
  const model = env.GROQ_VISION_MODEL || "qwen/qwen3.8-27b";
  const timeoutMs = parseInt(env.UPSTREAM_TIMEOUT_MS || "12000", 10);

  const messages = [
    {
      role: "system",
      content: `${READING_AGENT_SYSTEM_PROMPT}\n\nReturn JSON conforming to:
{
  "summary": "Concise summary in ${req.language}",
  "keyPoints": ["point 1", "point 2"],
  "clarityAssessment": "clear" | "fragmented" | "incomplete",
  "uncertainty": "Description if text was degraded or ambiguous, otherwise null"
}`,
    },
    {
      role: "user",
      content: `Instruction: ${req.instruction}\nLanguage: ${req.language}\nOCR Text:\n${req.text}`,
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
        max_tokens: 768,
        temperature: 0.1,
      }),
      signal: controller.signal,
    });

    if (!res.ok) {
      if (res.status === 429) throw new Error("RATE_LIMITED");
      if (res.status === 401 || res.status === 403) throw new Error("UPSTREAM_AUTH_ERROR");
      throw new Error(`UPSTREAM_ERROR: ${res.status}`);
    }

    const data = (await res.json()) as any;
    const content = data.choices?.[0]?.message?.content;
    if (!content) throw new Error("EMPTY_UPSTREAM_RESPONSE");

    const parsed = JSON.parse(content);
    return ReadingResultSchema.parse(parsed);
  } catch (err: any) {
    if (err.name === "AbortError") throw new Error("UPSTREAM_TIMEOUT");
    throw err;
  } finally {
    clearTimeout(timer);
  }
}
