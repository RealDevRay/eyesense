# EyeSense

**Tagline:** Your world, described.  
**Positioning:** AI visual assistance for blind and low-vision users.  
**Author:** Raymond Robert Klanderman, for MUA Innovation Week 2026.  
**Target:** Android-first Flutter mobile application with a hardened Cloudflare Worker backend and Groq LLM visual reasoning.

---

## 1. Project Overview

EyeSense provides fast, accessible, and privacy-centric visual assistance through an Android-first experience designed specifically for TalkBack screen reader exploration:

1. **Describe Scene:** Captures a still camera frame and produces a concise spoken and visual description of the visible environment, identifying prominent objects, spatial relations, and potential environmental concerns.
2. **Read Text (100% Offline):** Reads printed text aloud entirely on-device using Google ML Kit Text Recognition (zero network roundtrips, offline capable, zero data retention, and requires no cloud consent).
3. **Ask a Question:** Accepts spoken or typed questions, captures a fresh image frame, and delivers an image-grounded spoken answer.
4. **Immediate Control & Interruptibility:** Persistent Stop button and TalkBack actions allow users to interrupt speech playback or cancel in-flight operations at any millisecond.
5. **Repeat Output:** Replays previous information with clear `"Previous result:"` auditory and visual prefixes.

---

## 2. Bounded Multi-Agent Architecture

What actually runs today is `AgentCoordinator`, `SceneAgent` for Describe and Ask, on-device OCR for Read Text, and `ConversationAgent.matchIntent` for voice commands. `ReadingAgent.summarise` is a deferred stub: it returns the first three lines prefixed with "Summary:" and hardcodes `clarityAssessment: 'clear'`. It has no production call site and is not summarisation. `AppMode.awareness` is not a separate workflow.

EyeSense decomposes the live paths like this:

```
                           +----------------------+
                           |   AgentCoordinator   |
                           |    (Orchestrator)    |
                           +----------+-----------+
                                      |
         +----------------------------+----------------------------+
         |                            |                            |
         v                            v                            v
+------------------+         +------------------+         +--------------------+
|    SceneAgent    |         |   ReadingAgent   |         | ConversationAgent  |
| (Vision & Q&A)   |         | (Local Text/OCR) |         |  (Intent Routing)  |
+------------------+         +------------------+         +--------------------+
```

- **`AgentCoordinator` (Orchestrator):** Manages the central state machine (`idle`, `capturing`, `listening`, `processingLocal`, `processingCloud`, `speaking`, `error`), enforces operation serialization, handles physical haptics/TTS, and controls monotonic generation invalidation.
- **`SceneAgent` (Vision & Visual Q&A):** Handles visual reasoning. The client request timeout is 10 seconds. A result is discarded as stale only after 25 seconds from capture, and only before it is spoken.
- **Read Text:** On-device ML Kit. It does not use `ReadingAgent`. Stop discards a late result; ML Kit itself cannot abort `processImage`.
- **`ConversationAgent` (Intent & Spoken Commands):** Token-matches voice utterances such as "describe the scene", "soma maandishi", "stop" and "repeat". Anything that is not a command or a question is clarified locally and is not sent to the cloud.
- **`OutputPolicy` (Safety Supervisor):** Enforces strict safety invariants on both device and Cloudflare Worker. Prohibited road-crossing guidance, clear-path assertions, and collision claims are intercepted and replaced with conservative limitation statements in English and Kiswahili.

---

## 3. AI Connection Modes

EyeSense supports two AI connection modes with live runtime switching:

1. **EyeSense Service (Hosted Prototype):** Connects through the hardened Cloudflare Worker (`eyesense-api`), protecting upstream credentials with bearer token authorization, rate limiting (30 req/min), concurrency caps (10 concurrent), and a daily budget ceiling (1,000 req/day).
2. **Bring Your Own Key (BYOK Mode):** Direct device-to-Groq HTTPS connection (`https://api.groq.com/openai/v1/chat/completions`) using the user's personal encrypted Groq API key, stored securely in Android EncryptedSharedPreferences (`flutter_secure_storage`).

---

## 4. Modern Material 3 UI/UX & Accessibility

- **Material 3 Theming:** Dark, light, system, and a maximum-contrast theme (black, white, and `#FFD400`). Body text uses Atkinson Hyperlegible. Contrast ratios are design targets and still need a recorded measurement pass.
- **TalkBack:** Each home action is one semantic button with a label and hint. Status is a live region. App speech is a single TTS queue. This has widget coverage and still needs a pass with TalkBack on a device.
- **200% Font Scale:** Primary actions use a 72 dp minimum height and wrap. A widget test pumps every changed screen goal at 320 logical pixels and text scale 2.0 for Home. Other screens still need that same pass on a device.
- **Finite Minimum Touch Targets:** Global touch targets conform to standard 48x48 dp minimums, avoiding unbounded width layout exceptions.
- **Responsive Layouts:** Action rows utilize `Wrap` widgets to adapt naturally to diverse screen widths, foldables, and large accessibility display scaling.

---

## 5. Google Play Store Specifications & Device Compatibility

| Attribute | Specification | Notes |
| :--- | :--- | :--- |
| **Package Name** | `com.devray.eyesense` | Unique Android application identifier |
| **Minimum SDK** | API 24 (Android 7.0) | Pinned in `android/app/build.gradle.kts`. This is Flutter's current default and the `flutter_tts` floor. It is not API 21. |
| **Target SDK** | API 36 | Pinned next to `compileSdk` 36 and NDK `28.2.13676358` |
| **Supported Architectures** | Whatever the Flutter CLI selects for the build | The project does not set `abiFilters`. `flutter build apk --split-per-abi` is what produces per-ABI files. |
| **Package Format** | Android App Bundle (`.aab`) & Universal / Split APKs | Google Play Store publication ready |
| **Backup Protection** | `android:allowBackup="false"` | Prevents sensitive credentials from syncing to cloud backups |
| **Network Security** | Scoped `network_security_config.xml` | Enforces HTTPS in release; limits cleartext strictly to local loopback/emulator testing |
| **Android 11+ Queries** | `TTS_SERVICE` & `RecognitionService` | Explicit intent queries declared for system speech recognition and TTS engines |

---

## 6. Repository Structure

```
eyesense/
├── .github/workflows/ci.yml       # Continuous Integration (Flutter test + Worker test)
├── app/                           # Flutter Android application
│   ├── android/                   # Native Android configuration (Kotlin DSL, Gradle wrapper)
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml # Permissions, TTS queries, network security config
│   │       └── res/xml/network_security_config.xml # Scoped network security
│   ├── lib/
│   │   ├── agents/                # Coordinator, Scene, Reading, Conversation, OutputPolicy
│   │   ├── core/                  # Theme, accessibility announcer, config, exceptions
│   │   ├── features/              # Home, Settings, AI Connection, Onboarding, Diagnostics
│   │   ├── models/                # PresentationRecord, SceneResult, AppOperation models
│   │   ├── services/              # Camera, OCR, TTS, Speech, Storage, Diagnostics
│   │   └── widgets/               # Accessible buttons, status bars, response panels
│   └── test/                      # Unit, coordinator, speech, and widget test suites
├── worker/                        # Cloudflare Worker backend (eyesense-api)
│   ├── src/                       # TypeScript handlers, output policy, Zod schemas, Groq client
│   └── test/                      # Vitest backend integration tests
├── docs/                          # Architecture, remediation plan, test checklists
├── .gitignore                     # Git exclusion rules
└── README.md                      # This file
```

---

## 7. Verification & Testing

### 7.1 Flutter Test Suite (24 tests passing)
```bash
cd app
dart analyze lib test
flutter test --no-pub
```

### 7.2 Cloudflare Worker Vitest Suite (10 tests passing)
```bash
cd worker
npm run typecheck
npm test
```

---

## 8. Build & Release Instructions

### 8.1 Build Google Play Store App Bundle (`.aab`)
Google Play Store mandates the Android App Bundle format for all new app releases:
```bash
cd app
flutter build appbundle --release
```
*Output: `app/build/app/outputs/bundle/release/app-release.aab`*

### 8.2 Build Universal Release APK
To test on a physical Android device or distribute standalone:
```bash
cd app
flutter build apk --release
```
*Output: `app/build/app/outputs/flutter-apk/app-release.apk`*

### 8.3 Build Split Per-ABI APKs (Optimized file size)
To produce architecture-optimized APKs for `arm64-v8a`, `armeabi-v7a`, and `x86_64`:
```bash
cd app
flutter build apk --release --split-per-abi
```
*Outputs:*
- `app-armeabi-v7a-release.apk` (~15 MB, 32-bit ARM devices)
- `app-arm64-v8a-release.apk` (~17 MB, 64-bit modern Android devices)
- `app-x86_64-release.apk` (~18 MB, 64-bit emulators and Chromebooks)

---

## 9. Privacy, Security & Diagnostics

1. **Consent-Gated Cloud Analysis:** Describe Scene and Ask Question require explicit user opt-in consent. Read Text operates 100% locally on-device without consent, API keys, or internet connectivity.
2. **Prohibited Safety Guidance:** Road crossing, clear-path assertions, and collision guarantees are scrubbed and replaced with conservative safety limitations in English and Kiswahili.
3. **Hosted access token:** The app binary does not contain a demo bearer token. Hosted mode fails closed until a token is saved in secure storage. `--dart-define=HOSTED_ACCESS_TOKEN=...` is for internal builds only and those artifacts must not be distributed. A token previously committed in source is public and must be rotated with `wrangler secret put DEMO_ACCESS_TOKEN` before any hosted use. Groq keys stay as Worker secrets. Personal BYOK keys stay in encrypted storage. Per-device credentials are not implemented yet.
4. **Android Backup Protection:** `android:allowBackup="false"` in AndroidManifest prevents sensitive credentials from syncing to Google Cloud backups.
5. **Live Provider Synchronization:** Switching between Hosted and BYOK modes or updating Worker endpoints takes effect live in runtime without an app restart.
6. **Opt-in Metadata Diagnostics:** Local technical logging (`eyesense-*.jsonl`) is strictly opt-in and metadata-only (operation durations, error codes, token counts). Zero camera images, audio recordings, or question text are retained.
