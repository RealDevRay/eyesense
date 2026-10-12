# EyeSense

**Tagline:** Your world, described.  
**Positioning:** AI visual assistance for blind and low-vision users.  
**Author:** Raymond Robert Klanderman, for MUA Innovation Week 2026.  
**Target:** Android-first Flutter application with a Cloudflare Worker proxy and Groq LLM visual reasoning.

---

## 1. Project Overview

EyeSense provides accessible, privacy-centric visual assistance through three core capabilities:
1. **Describe:** Captures a still camera frame and produces a concise scene description with potential concern alerts.
2. **Read Text:** Reads printed text aloud entirely on-device via Google ML Kit OCR (zero network roundtrips, offline capable).
3. **Ask:** Accepts short voice or typed questions, captures a fresh image, and delivers an image-grounded spoken answer.

EyeSense supports two distinct AI connection modes:
- **EyeSense service (Hosted prototype):** Routed through a Cloudflare Worker proxy (`eyesense-api`) protecting developer secrets with restricted bearer token access.
- **Use my Groq key (BYOK mode):** Direct HTTPS connection between the mobile app and Groq API using the user's encrypted personal API key.

---

## 2. Repository Structure

```
eyesense/
├── app/                  # Flutter Android application
│   ├── lib/
│   │   ├── agents/       # Agent coordinator, Scene, Reading, Conversation roles
│   │   ├── core/         # Config, theme, accessibility announcer, error codes
│   │   ├── features/     # Home screen, Settings, AI Connection, Diagnostics
│   │   ├── models/       # SceneResult, AppOperation models
│   │   ├── services/     # Camera, OCR, TTS, Speech, Storage, Diagnostics
│   │   └── widgets/      # Accessible action buttons, status bars, response panels
│   └── test/             # Flutter unit & contract verification tests
├── worker/               # Cloudflare Worker proxy (eyesense-api)
│   ├── src/              # TypeScript handlers, Zod schemas, Groq dispatchers
│   └── test/             # Vitest test suite
├── docs/                 # Architecture, live demo script, device checklist
├── .gitignore            # Git exclusion rules (secrets, build artifacts, logs)
└── README.md             # This file
```

---

## 3. Getting Started & Setup

### Prerequisites
- **Flutter SDK:** $\ge 3.47.0$ (Dart $\ge 3.13.0$)
- **Android SDK:** Platform 34+ / Build-Tools 34+ (Android 5.0+ / API 21 minimum)
- **Node.js:** $\ge 20.0.0$ and npm $\ge 10.0.0$

### 3.1 Cloudflare Worker (`worker/`)
1. Change into the worker directory:
   ```bash
   cd worker
   npm install
   ```
2. Copy the example environment variables:
   ```bash
   cp .dev.vars.example .dev.vars
   ```
3. Set your Groq API key and demo token inside `.dev.vars`:
   ```bash
   GROQ_API_KEY="gsk_your_groq_api_key_here"
   DEMO_ACCESS_TOKEN="your_prototype_demo_token"
   ```
4. Run automated tests and start local development:
   ```bash
   npm test
   npm run dev
   ```

### 3.2 Flutter Mobile App (`app/`)
1. Change into the app directory:
   ```bash
   cd app
   flutter pub get
   ```
2. Run automated tests and static analysis:
   ```bash
   flutter test --no-pub
   flutter analyze
   ```
3. Run on a connected Android phone or emulator:
   ```bash
   flutter run --dart-define=API_BASE_URL=https://api.eyesense.dev
   ```

---

## 4. Security & Privacy Guarantees

- **No Secret Leakage:** Developer Groq keys exist strictly as server-side Worker secrets.
- **Android Backup Protection:** `android:allowBackup="false"` in AndroidManifest prevents sensitive credentials from syncing to cloud backups.
- **Opt-in Diagnostics:** Local technical logging (`eyesense-*.jsonl`) is strictly opt-in and metadata-only (operation durations, error codes, token counts). Zero camera images, audio recordings, or question text are retained.
