import { z } from "zod";

export const AllowedDirectionSchema = z.enum([
  "left",
  "centre",
  "right",
  "multiple",
  "unknown",
]);
export type AllowedDirection = z.infer<typeof AllowedDirectionSchema>;

export const ImageQualitySchema = z.enum(["usable", "unclear"]);
export type ImageQuality = z.infer<typeof ImageQualitySchema>;

export const SceneResultSchema = z
  .object({
    summary: z.string().trim().min(1).max(350),
    answer: z.string().trim().min(1).max(350).nullable(),
    possibleConcern: z.boolean(),
    concernDescription: z.string().trim().max(250).nullable(),
    direction: AllowedDirectionSchema,
    objects: z.array(z.string().trim().max(60)).max(8),
    imageQuality: ImageQualitySchema,
    uncertainty: z.string().trim().max(250).nullable(),
  })
  .refine(
    (data) =>
      !data.possibleConcern ||
      (typeof data.concernDescription === "string" && data.concernDescription.trim().length > 0),
    {
      message: "concernDescription is required when possibleConcern is true",
      path: ["concernDescription"],
    }
  );
export type SceneResult = z.infer<typeof SceneResultSchema>;

export const VisionRequestSchema = z
  .object({
    requestId: z.string().uuid(),
    mode: z.enum(["describe", "ask"]),
    language: z.enum(["en", "sw"]).default("en"),
    question: z.string().trim().max(300).optional(),
    image: z.object({
      mimeType: z.literal("image/jpeg"),
      base64: z
        .string()
        .min(4)
        .refine((val) => val.startsWith("/9j"), {
          message: "Image base64 must represent a valid JPEG beginning with JPEG header (/9j)",
        }),
    }),
  })
  .refine(
    (data) =>
      data.mode !== "ask" ||
      (typeof data.question === "string" && data.question.trim().length > 0),
    {
      message: "A non-empty question is required when mode is 'ask'",
      path: ["question"],
    }
  );
export type VisionRequest = z.infer<typeof VisionRequestSchema>;

export const VisionResponseSchema = z.object({
  requestId: z.string().uuid(),
  result: SceneResultSchema,
});
export type VisionResponse = z.infer<typeof VisionResponseSchema>;

export const ReadingRequestSchema = z.object({
  requestId: z.string().uuid(),
  language: z.enum(["en", "sw"]).default("en"),
  text: z.string().trim().min(1).max(12000),
  instruction: z.enum(["summarise", "explain"]).default("summarise"),
});
export type ReadingRequest = z.infer<typeof ReadingRequestSchema>;

export const ReadingResultSchema = z.object({
  summary: z.string().trim().min(1).max(700),
  keyPoints: z.array(z.string().trim().max(150)).max(6),
  clarityAssessment: z.enum(["clear", "fragmented", "incomplete"]),
  uncertainty: z.string().trim().max(250).nullable(),
});
export type ReadingResult = z.infer<typeof ReadingResultSchema>;

export const ReadingResponseSchema = z.object({
  requestId: z.string().uuid(),
  result: ReadingResultSchema,
});
export type ReadingResponse = z.infer<typeof ReadingResponseSchema>;

export const ConversationRequestSchema = z.object({
  requestId: z.string().uuid(),
  language: z.enum(["en", "sw"]).default("en"),
  message: z.string().trim().min(1).max(300),
  contextSummary: z.string().trim().max(600).optional(),
});
export type ConversationRequest = z.infer<typeof ConversationRequestSchema>;

export const ConversationPlanSchema = z.object({
  action: z.enum(["describe_scene", "read_text", "ask_scene", "clarify"]),
  question: z.string().trim().max(300).nullable(),
  suggestedPrompt: z.string().trim().max(300).nullable(),
});
export type ConversationPlan = z.infer<typeof ConversationPlanSchema>;

export const ConversationResponseSchema = z.object({
  requestId: z.string().uuid(),
  plan: ConversationPlanSchema,
});
export type ConversationResponse = z.infer<typeof ConversationResponseSchema>;
