# EyeSense Terms of Use

**Effective date:** 21 October 2026

**Last updated:** 21 October 2026

**Version:** 1.1-pilot

**Pilot draft:** Not a legal-compliance, physical TalkBack or production-readiness certification. Kiswahili translations need native-speaker and qualified legal review.

## 1. Agreement

These terms are between you and DevRay ("we", "us"). They govern your use of the EyeSense mobile application ("the app").

By installing or using the app you accept these terms. If you do not accept them, do not use the app.

Our handling of your information is described in the EyeSense Privacy Policy at [eyesense.dpdns.org/privacy](https://eyesense.dpdns.org/privacy), which forms part of these terms.

## 2. Safety — please read this section

**This is the most important part of these terms.**

### 2.1 EyeSense is not a mobility aid

EyeSense is a supplementary source of visual information. It is **not** a replacement for a white cane, a guide dog, a sighted guide, orientation and mobility training, or your own judgement. It must not be relied upon for:

- deciding whether it is safe to cross a road;
- determining whether a path is clear or free of obstacles;
- judging distance, proximity, speed or the risk of collision;
- navigation or turn-by-turn walking directions;
- detecting hazards, drop-offs, steps, traffic or moving objects;
- any decision where being wrong could cause injury.

The app is designed to refuse these requests, but prompts and filters do not guarantee every unsafe answer is blocked. That refusal is deliberate. Please do not attempt to work around it.

### 2.2 EyeSense is not a medical device

The app is not a medical device and is not intended to diagnose, treat, cure or prevent any condition. It must not be used to read dosage instructions, prescription labels or any other medical information where an error could cause harm. Always confirm medical information with a pharmacist, clinician, or another person you trust.

### 2.3 The app describes a single photograph, and it can be wrong

Each result is based on one still image taken at one moment. It is not live awareness, and it does not know what has changed since. The underlying AI models can misidentify objects, misread text, omit important things, and state incorrect information confidently. Poor lighting, motion, reflections, unusual angles and small print all make errors more likely.

**Treat every result as a suggestion to verify, not a fact to act on.**

### 2.4 Optional local sensor checks

Android accelerometer, gravity, gyroscope, light and **FRONT** proximity availability metadata and brief samples stay local and ephemeral, without sensor history or network uploads. Capability discovery does not sample. Checks run for **less than one second** only during an explicit capture with guidance or **Check Sensors**, with cancellation and foreground/lifecycle cleanup. They use no GPS, compass or location sensing.

Accelerometer/gravity estimate only approximate phone pose, not page alignment. Gyroscope is a movement/hold-steady cue only. Light is an ambient-light cue; front proximity indicates a possibly covered front sensor, not distance to a rear-camera subject. None measures subject distance, confirms page framing, judges roads/paths or supplies navigation. Missing sensors or no warning do not establish safety or picture quality. Physical-device behavior remains to be verified.

### 2.5 Your responsibility

You remain responsible for your own safety and for your decisions. Use the app in combination with your usual mobility aids, techniques and judgement — never in place of them.

## 3. Prototype status

EyeSense is currently a prototype provided for evaluation. It may be unavailable, may behave unpredictably, may lose your settings, and may be withdrawn or changed substantially at any time without notice. Hosted pilot defaults are **6 requests per minute globally, 2 concurrent reservations and 100 requests per UTC day globally**, configurable by the operator and shared across users, not individual entitlements. Provider account limits also apply; these controls guarantee neither successful inference nor availability. Raw-IP one-minute windows and 60-second concurrency reservations expire logically and are pruned on the next pre-parse/charge/release operation; successful release removes its reservation. The global daily total resets lazily on a new UTC date, with minute windows spanning midnight. No scheduled deletion alarm or guaranteed idle/midnight deletion is provided; see the Privacy Policy §3.7. Read Text OCR does not use the cloud-AI service. System speech recognition and TTS may need internet; offline playback requires an installed offline voice.

## 4. What you may and may not do

You may use the app for its intended purpose: obtaining descriptions of scenes, reading printed text, and asking questions about what the camera can see.

You may not:

- use it for any unlawful purpose, or to infringe anyone's rights;
- photograph people in order to identify them, infer personal characteristics about them, or conduct surveillance. The app is designed to refuse this;
- photograph others where doing so is unlawful or a breach of their privacy. You are responsible for complying with the law where you are;
- attempt to defeat the safety limitations in §2, including through prompt manipulation;
- probe, overload, reverse-engineer or interfere with our hosted service, or attempt to extract credentials from the app;
- exceed, circumvent or attempt to circumvent usage limits, including by creating multiple identities or rotating credentials;
- resell, sublicense or redistribute access to the hosted service.

We may suspend or withdraw access to the hosted service if we reasonably believe it is being misused, or to protect the service or its other users.

## 5. AI providers and your own API key

The app can operate in two modes.

**Hosted mode** routes requests through our Cloudflare Worker to **Groq only**. Groq is the inference host; the configured default model is Qwen `qwen/qwen3.8-27b`, not a "Groq model". The operator can change the hosted model. Availability and usage limits are set by us and may change.

**Bring Your Own Key (BYOK) mode** sends requests directly from your device to your explicitly selected provider: **Groq, OpenAI, Google Gemini, or optional Mistral**, using that provider's own API key and account. Default model IDs are `qwen/qwen3.8-27b`, `gpt-5-mini`, `gemini-3.8-flash`, and `mistral-small-latest`, respectively. Model IDs are editable; defaults do not guarantee access, vision support, JSON support, or availability. Gemini uses Google's official OpenAI-compatibility endpoint, not OpenAI's service.

Mistral is used only when explicitly selected, with your own Mistral key and the fixed official `https://api.mistral.ai/v1` API (`POST /chat/completions`, `GET /models`); the `-latest` alias can change. Another provider's key or hosted token is never reused.

**Mistral Free mode:** inputs/outputs may train models unless you opt out in your Mistral account (Admin → Privacy → Anonymous improvement data). EyeSense does not change this setting. Opt-out is not zero retention: **Free mode has no zero-data-retention option**, and approved paid arrangements are separate. Do not assume provider-side deletion. The account's current limits and terms are authoritative; a free key does not guarantee model access, remaining quota, support or production suitability. No live Mistral test was performed.

Keys are stored separately per provider in encrypted local storage. Saving connection settings is explicit. There is **no provider/model fallback or silent image routing** when a request fails. In BYOK mode:

- your use is governed by your own agreement with the **selected provider**, in addition to these terms;
- **you are responsible for all charges and quota consumption on your account**;
- you are responsible for keeping your key secure, and for revoking it if it is exposed;
- we have no visibility of, and no responsibility for, your account, its limits or its billing.

**Optional checks:** Check key and model makes an authenticated `GET /models` request to the selected provider without a photo or inference. It does not prove vision or JSON support. The separate generated sample image test requires cloud-AI consent and explicit confirmation. It sends one generated 64 × 64 red image using the entered provider/key/model, with no camera or personal photograph, one potentially billable inference call, and no retry. Neither check automatically saves connection settings.

Official references: [Groq privacy policy](https://groq.com/privacy-policy), [OpenAI privacy policy](https://openai.com/policies/privacy-policy/), [Gemini API terms](https://ai.google.dev/gemini-api/terms), and [Mistral terms/privacy](https://legal.mistral.ai/terms). These links do not certify review or compliance. Review of current provider/API terms, billing, retention, training use, and transfer conditions is required; no legal approval or account-specific provider guarantee is claimed.

In both modes, once a request has reached the selected AI provider it is subject to that provider's terms and **cannot be recalled by us**. Stopping an operation in the app cancels our request; it does not necessarily halt processing a provider has already begun, or prevent an associated charge.

## 6. Availability

We do not promise that the app or the hosted service will be available, uninterrupted or error-free. We may modify, suspend or discontinue any part of the service, including specific features or the hosted endpoint entirely, at any time.

Read Text's on-device OCR works without uploading the image for recognition. This is not a promise that the whole speech workflow is offline: system speech recognition and TTS may need internet, and offline playback requires an installed offline voice.

## 7. Intellectual property

The app, its name, and its design are owned by us or our licensors. These terms grant you a personal, revocable, non-exclusive, non-transferable licence to use the app on devices you control, for the purposes described here. No other rights are granted.

The app includes third-party open-source components. Their licences are listed in the app under Settings → Legal → Open-Source Licences, and those licences govern those components.

Content you capture with your own camera remains yours. We claim no ownership of it.

## 8. Disclaimers

To the fullest extent permitted by law, the app is provided "as is" and "as available", without warranties of any kind, whether express or implied, including any implied warranty of merchantability, fitness for a particular purpose, accuracy, or non-infringement.

We specifically do not warrant that descriptions, answers or recognised text will be accurate, complete, current or suitable for any purpose.

Nothing in these terms excludes or limits any liability that cannot lawfully be excluded or limited, including liability for death or personal injury caused by negligence, for fraud, or any rights you have as a consumer that cannot be waived.

## 9. Limitation of liability

Subject to §8, and to the fullest extent permitted by law:

- we are not liable for indirect, incidental, special, consequential or punitive loss, or for loss of profit, revenue, data or goodwill;
- we are not liable for any decision you make, or any action you take or do not take, in reliance on information the app provides;
- we are not liable for charges incurred on your own AI provider account;
- our total aggregate liability arising out of or in connection with these terms is limited to the greater of the total amount you have paid us for the app — which, while the app is provided free of charge, is nil — and the minimum amount that applicable law requires.

## 10. Indemnity

You agree to indemnify us against claims, losses and reasonable costs arising from your breach of §4, or from your use of the app in a way these terms do not permit.

## 11. Changes to these terms

We may update these terms. We will revise the effective date and, where the change materially affects your rights or the safety limitations in §2, notify you in the app and ask you to accept the revised terms before continuing to use affected features.

For **1.1-pilot**, a saved cloud opt-in with an older or missing accepted terms version is treated as off. Review the revised Terms and Privacy Policy, then explicitly enable Cloud Processing Consent in Settings to reconsent. Reading or accepting terms alone does not restore cloud access. Previously completed onboarding remains complete; the tutorial is not forced again. An older safety acknowledgement no longer counts for this version. **Local Read Text OCR remains available without cloud consent.** An accessible in-app version-review notification remains a release verification task, not a claim made by this document.

Your continued use after a non-material change constitutes acceptance; it never substitutes for the explicit cloud opt-in described above.

## 12. Ending this agreement

You may stop using the app at any time by uninstalling it, which removes all local data including your settings and any stored API key.

We may suspend or terminate your access to the hosted service as described in §4. Sections 2, 7, 8, 9, 10 and 13 survive termination.

## 13. Governing law and disputes

These terms are governed by the laws of the country in which you reside, and you may bring proceedings before the courts of that country.

Nothing in these terms deprives you of the protection of the mandatory laws of your country of residence, or of any right you have as a consumer to bring proceedings there.

## 14. General

If any provision is held unenforceable, the remainder stays in effect. Our failure to enforce a provision is not a waiver of it. These terms, together with the Privacy Policy, are the entire agreement between us regarding the app. You may not transfer your rights under these terms; we may transfer ours in connection with a merger, acquisition or transfer of the app.

## 15. Contact

**info@devray.qzz.io**

If you need these terms in another format or another language, or help understanding them, contact us and we will assist.
