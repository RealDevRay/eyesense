# EyeSense API - Cloudflare Worker Proxy & Agent Coordinator

`eyesense-api` is a lightweight, edge-based Cloudflare Worker proxy built for the **EyeSense** accessibility application. It runs on Cloudflare's **free tier** (100,000 requests/day) and provides:

1. **API Key Security**: Stores your Groq API key securely server-side so it is never embedded into the Android APK.
2. **Schema & Safety Validation**: Rejects oversized payloads (>1.5 MiB), enforces strict Zod schemas, and blocks unauthorized clients.
3. **Bounded Agent Prompts**: Formats visual scene descriptions, reading questions, and conversation turns with strict tokens and safety guardrails.

---

## 1. Prerequisites

1. **Node.js** (v18+ or v20+)
2. **Free Groq API Key**:
   - Sign up at [https://console.groq.com](https://console.groq.com).
   - Generate an API key starting with `gsk_...`.
3. **Free Cloudflare Account**:
   - Sign up at [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up).
   - The free plan gives you **100,000 free worker requests every day**.

---

## 2. Local Configuration & Testing

### Step 1: Install Dependencies
Open your terminal in the `worker/` directory:
```bash
cd d:\PROFESSIONAL\eyesense\worker
npm install
```

### Step 2: Create Local Secret File (`.dev.vars`)
Copy `.dev.vars.example` to `.dev.vars`:
```bash
cp .dev.vars.example .dev.vars
```
Open `.dev.vars` in your editor and enter your real Groq API key:
```env
# Developer's Groq API Key (server-side only)
GROQ_API_KEY=gsk_your_actual_groq_key_here

# Demo Access Token for prototype bearer validation
DEMO_ACCESS_TOKEN=eyesense-demo-token-secret-pitch-2026

# Model identifier
GROQ_VISION_MODEL=qwen/qwen3.8-27b

# Cloud requests enabled ("true" or "false")
ENABLE_CLOUD_REQUESTS=true

# Upstream Groq request timeout in milliseconds
UPSTREAM_TIMEOUT_MS=12000
```
*(Note: `.dev.vars` is git-ignored and will never be committed to source control).*

### Step 3: Run the Local Dev Server
```bash
npm run dev
```
Wrangler will launch the local worker at:
```
http://localhost:8787  (or http://127.0.0.1:8787)
```

### Step 4: Test Local Health Endpoint
In PowerShell or a new terminal window:
```powershell
curl http://localhost:8787/health
```
You should receive a `200 OK` JSON response:
```json
{
  "status": "ok",
  "service": "eyesense-api",
  "cloudEnabled": true,
  "version": "1.0.0"
}
```

---

## 3. Deploying to Cloudflare (Free Tier)

### Step 1: Log in to Cloudflare
In your terminal, run:
```bash
npx wrangler login
```
This opens your browser. Authorize Wrangler with your free Cloudflare account.

### Step 2: Upload Secrets to Cloudflare
Never write secret keys into `wrangler.jsonc`. Instead, upload them as encrypted Cloudflare Worker secrets:

```bash
# 1. Set your Groq API Key
npx wrangler secret put GROQ_API_KEY
# (When prompted, paste your gsk_... key and press Enter)

# 2. Set your Demo Access Token (must match what the app sends)
npx wrangler secret put DEMO_ACCESS_TOKEN
# (When prompted, type: eyesense-demo-token-secret-pitch-2026 and press Enter)
```

### Step 3: Deploy the Worker
Run:
```bash
npm run deploy
```
Cloudflare will upload your code and output your live public URL:
```
Uploaded eyesense-api (1.23 sec)
Deployed eyesense-api triggers (0.45 sec)
  https://eyesense-api.<your-subdomain>.workers.dev
```

### Step 4: Test Live Health Endpoint
```powershell
curl https://eyesense-api.<your-subdomain>.workers.dev/health
```
If you get `{"status":"ok", ...}`, your Cloudflare Worker is live and ready!

---

## 4. Connecting the EyeSense Mobile App to Your Worker

You can connect the Flutter app to your Cloudflare Worker in two ways:

### Method A: Directly in the App (No recompilation needed!)
1. Launch **EyeSense** on your Android phone or emulator.
2. Tap the **Settings** button (gear icon in the top right).
3. Select **AI Connection**.
4. Choose **EyeSense service (Hosted prototype)**.
5. In the **Cloudflare Worker API URL** box, paste your URL:
   ```
   https://eyesense-api.<your-subdomain>.workers.dev
   ```
6. Tap **Test Worker Connection**. The app will ping `/health` and display:
   `Success: Cloudflare Worker responded healthy.`
7. In the **Demo Access Token** box, enter:
   ```
   eyesense-demo-token-secret-pitch-2026
   ```
8. Tap **Save Connection Settings**.

### Method B: At APK Compile Time
When building the APK, bake the worker URL directly into the binary:
```bash
flutter build apk --dart-define=API_BASE_URL=https://eyesense-api.<your-subdomain>.workers.dev
```

---

## 5. Endpoints Reference

| Method | Endpoint | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | None | Public health check returning service status |
| `POST` | `/v1/vision` | `Bearer <DEMO_ACCESS_TOKEN>` | Scene description and questions with base64 JPEG |
| `POST` | `/v1/reading` | `Bearer <DEMO_ACCESS_TOKEN>` | Structured reading / text extraction fallback |
| `POST` | `/v1/conversation` | `Bearer <DEMO_ACCESS_TOKEN>` | Bounded conversational intent planning |
