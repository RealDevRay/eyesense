# EyeSense Device Test & Verification Checklist

**Application:** EyeSense Mobile (Android)  
**Target Date:** 12 October 2026 Pitch  
**Package:** `com.devray.eyesense`

---

## 1. Automated Verification Status (Verified in CI/Local Suite)

| Check Item | Status | Verification Detail |
|---|---|---|
| **Dart Analysis & Lints** | **PASSED** | Clean pass with zero errors/warnings via `dart analyze`. |
| **Worker Vitest Suite** | **PASSED** | 5/5 unit tests passed for `/health`, `/v1/vision` validation, auth headers, and size limits. |
| **Worker TypeScript Typecheck** | **PASSED** | Clean pass with zero type errors via `tsc --noEmit`. |
| **Vision Schema Contract Tests** | **PASSED** | Structured schema validation, string truncation bounds ($\le 350$ chars), and enum parsing verified. |
| **OutputPolicy Freshness Enforcement** | **PASSED** | Stale results ($> 15$s) and mismatched generations correctly throw `AppException`. |
| **Prompt Injection Protection** | **PASSED** | User questions and OCR text treated strictly as data in user prompts, not system instructions. |

---

## 2. Physical Android Device Checklist

Run this on the physical target Android device prior to the demonstration:

### Camera & Capture
- [ ] Camera permission prompt appears on initial use with accessible explanation.
- [ ] Rear camera preview initializes cleanly in portrait orientation.
- [ ] Still capture compresses image to $\le 1280$ px long edge and $\le 1$ MiB decoded.
- [ ] Left/right scene references align with actual camera view (no inverted preview references).

### Audio, Speech & Playback
- [ ] TTS speaks descriptions with audible volume and clear pronunciation.
- [ ] Speech rate slider (0.5x – 2.0x) takes effect on next playback.
- [ ] Stop button immediately cuts off audio within 100 ms.
- [ ] Repeat button replays the last result without triggering a new camera capture.
- [ ] Microphone permission requested only when user enters Voice Ask mode.

### Local OCR
- [ ] Reads a printed "Innovation Week 2026" sign verbatim.
- [ ] Functions with airplane mode enabled (offline capability confirmed).
- [ ] Returns *"No readable text found"* when pointed at a plain blank surface.

### AI Connection (Hosted & BYOK)
- [ ] Hosted mode connects to Cloudflare Worker with valid `DEMO_ACCESS_TOKEN`.
- [ ] BYOK mode stores user Groq key securely in `flutter_secure_storage`.
- [ ] "Test Key" button validates personal Groq key via `GET /models` without image upload.
- [ ] "Remove Key" cleanly purges credential from secure storage.
- [ ] Personal key field is masked on screen and excluded from TalkBack readout.

### Diagnostics & Privacy
- [ ] Diagnostic logging is disabled by default.
- [ ] Opting in records only allowlisted event metadata to `eyesense-*.jsonl`.
- [ ] Export logs opens standard Android Share sheet.
- [ ] Clear logs purges all `.jsonl` files from support directory.
- [ ] Confirmed zero images, audio, keys, or question text present in exported files.
