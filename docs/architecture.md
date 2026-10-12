# EyeSense Architecture & System Design

**Brand Name:** EyeSense  
**Tagline:** Your world, described.  
**Platform:** Android-first Flutter mobile application with Cloudflare Worker proxy and Groq LLM visual reasoning.

---

## 1. High-Level Architecture Overview

EyeSense provides visual assistance for blind and low-vision users through spoken descriptions, local optical character recognition (OCR), and image-grounded visual questions.

```
+-----------------------------------------------------------------------------------------+
|                                    EYESENSE FLUTTER APP                                 |
|                                                                                         |
|  +------------------------+      +-----------------------+      +--------------------+  |
|  |     CameraService      |      |      OcrService       |      |     TtsService     |  |
|  | (Rear camera, 1280px,  |      |   (Google ML Kit      |      |   (flutter_tts,    |  |
|  |  JPEG 80%, < 1 MiB)    |      |    Latin script)      |      |   rate & stop)     |  |
|  +-----------+------------+      +-----------+-----------+      +---------^----------+  |
|              |                               |                            |             |
|              v                               v                            |             |
|  +------------------------------------------------------------------------+----------+  |
|  |                                  AGENT COORDINATOR                                |  |
|  |  * State Machine: idle, listening, capturing, processingLocal, processingCloud,    |  |
|  |                   speaking, error                                                 |  |
|  |  * Request Freshness: 15-second expiration timeout                                |  |
|  |  * Generation Tokens: Immediate invalidation on Cancel/Stop/Mode Switch           |  |
|  |  * Max AI Model Calls: Strictly capped at 2 per operation                         |  |
|  +---------------------+-------------------------------------------------------------+  |
|                        |                                                                |
+------------------------|----------------------------------------------------------------+
                         |
           +-------------+-------------+
           | (Hosted Mode)             | (BYOK Mode)
           v                           v
+--------------------------+  +---------------------------------+
| CLOUDFLARE WORKER PROXY  |  | DIRECT GROQ HTTPS ENDPOINT      |
| (eyesense-api)           |  | https://api.groq.com/openai/... |
|                          |  |                                 |
| * Bearer Token Auth      |  | * User's Encrypted Personal Key |
| * Developer GROQ_API_KEY |  | * Identical System Prompt       |
| * Schema & Size Guard    |  | * Identical Structured Schema   |
| * Cache-Control: no-store|  | * No Server-Side Logging        |
+------------+-------------+  +----------------+----------------+
             |                                 |
             +----------------+----------------+
                              |
                              v
                +----------------------------+
                |         GROQ LLM           |
                |   Model: qwen/qwen3.8-27b  |
                +----------------------------+
```

---

## 2. Data Flow Pipelines

### 2.1 Hosted Describe & Ask Flow
1. User taps **Describe** or submits question via **Ask**.
2. `CameraService` captures a still image, resizes to long edge $\le 1280$ px at $80\%$ JPEG quality (decoded size $< 1$ MiB).
3. `AgentCoordinator` checks user cloud processing consent, stamps operation with a UUID `requestId` and monotonic generation token.
4. `HostedVisionProvider` dispatches request to Cloudflare Worker `POST /v1/vision` with `DEMO_ACCESS_TOKEN`.
5. Worker validates bearer token, enforces 1.5 MiB request ceiling, invokes Groq vision completion.
6. Groq responds with strict JSON matching `SceneResultSchema`.
7. `OutputPolicy` locally verifies:
   - Request generation matches current UI generation.
   - Elapsed time from capture $\le 15$ seconds.
   - Text conforms to length bounds ($\le 350$ chars).
8. Text is spoken aloud via `TtsService` and rendered on screen.

### 2.2 BYOK (Bring Your Own Key) Describe & Ask Flow
1. User enters personal Groq key in **Settings $\to$ AI Connection**, stored in encrypted Android storage via `flutter_secure_storage`.
2. Flow bypasses the Cloudflare Worker completely.
3. Mobile app communicates directly with `https://api.groq.com/openai/v1/chat/completions`.
4. Executes the identical system prompt and JSON schema as hosted mode, ensuring zero drift.

### 2.3 Read Text Flow (Zero Cloud Calls)
1. User taps **Read Text**.
2. Camera captures a still frame.
3. `OcrService` uses on-device Google ML Kit Text Recognition (Latin script).
4. Verbatim extracted text is returned locally with zero network calls and read aloud immediately.

---

## 3. Bounded Agent Roles

| Agent | Responsibility | Permitted Tools / Actions | Max Completion Tokens |
|---|---|---|---|
| **Scene Agent** | Describes visible scene, answers visual questions grounded in image. | Reads supplied image, returns structured JSON. | 512 tokens |
| **Reading Agent** | Summarises or explains OCR text only upon explicit user request. | Reads supplied text, returns bounded summary. | 768 tokens |
| **Conversation Agent**| Clarifies ambiguous requests, classifies user intent. | Returns plan (`describe_scene`, `read_text`, `ask_scene`, `clarify`). | 256 tokens |
| **Coordinator** | Deterministic state machine, mutex, cancellation, freshness. | Executes local services, enforces policies. | N/A (deterministic code) |

---

## 4. Privacy, Security & Diagnostics

1. **No Cloud Backup of Credentials:** `android:allowBackup="false"` in AndroidManifest ensures encrypted keys are never synchronized to Google Cloud backups.
2. **Opt-in Diagnostics:** Disabled by default. Writes strictly allowlisted technical metrics (latencies, token counts, error codes) into local JSONL files (`eyesense-YYYY-MM-DD-001.jsonl`).
3. **No Private Content in Logs:** Images, voice audio, questions, OCR text, and API keys are strictly excluded from logs and exports.
