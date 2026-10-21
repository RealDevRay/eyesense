# EyeSense Privacy Policy

**Effective date:** 21 October 2026

**Last updated:** 21 October 2026

**Version:** 1.1-pilot

**Pilot notice:** Draft for review, not a legal-compliance or production-readiness certification. Kiswahili translations require native-speaker and legal review.

## 1. Who we are

EyeSense ("the app") is an AI visual assistance application for blind and low-vision users, published by DevRay ("we", "us").

You can contact us about anything in this policy at **info@devray.qzz.io**. If you need this policy in another format, or help exercising any right described here, contact us and we will assist.

## 2. Summary

- EyeSense has no user accounts. We do not ask for your name, email address or phone number.
- **Read Text OCR runs on your device without uploading the image.** System speech recognition and text-to-speech (TTS) may need internet; offline playback requires an installed offline voice.
- **Describe Scene and Ask a Question send one photograph off your device**, and only after you have explicitly turned on cloud processing.
- Hosted mode sends requests through our Cloudflare Worker to Groq only. BYOK sends directly to your explicitly selected provider: Groq, OpenAI, Google Gemini, or optional Mistral (`mistral-small-latest` by default), using that provider's own key and fixed official API endpoint. No fallback or silent image routing is used.
- In hosted mode, our service receives your IP address and persists raw-IP request counters to limit abuse. There is no guaranteed midnight deletion. See §3.7.
- We do not use advertising, analytics, attribution or tracking services.
- We do not sell or rent your data, and DevRay does not use it to train AI models. **Mistral Free-mode inputs/outputs may be used for training unless you opt out in your Mistral account; Free mode has no zero-data-retention option.** See §5.
- Optional Android accelerometer, gravity, gyroscope, light and front proximity checks are local and temporary; neither sensor metadata nor samples are uploaded. See §3.8.
- Technical diagnostic logging is off unless you turn it on, and stays on your device.

## 3. What the app processes, and when

### 3.1 Camera images

| Feature | What happens to the image |
| --- | --- |
| **Read Text** | Captured, recognised on-device by Google ML Kit, then deleted. The image is not uploaded for OCR; speech services are separate, as described in §3.3. |
| **Describe Scene** | Captured, resized, and sent to the AI provider you have configured. Deleted from your device after the operation. |
| **Ask a Question** | As Describe Scene, together with your question. |

Describe Scene and Ask a Question only operate after you turn on **Cloud Processing Consent**. Until you do, both features are unavailable and no camera image is sent for AI analysis. You can withdraw that consent at any time in Settings, which stops further cloud-AI submissions; it cannot recall data already sent.

For **1.1-pilot**, a saved cloud opt-in with an older or missing accepted terms version is treated as off. Review the revised notices and explicitly enable Cloud Processing Consent in Settings to reconsent. Completing the tutorial previously does not force you to repeat it, and reading or accepting terms alone does not re-enable cloud processing. Safety acknowledgement is versioned separately and an older acknowledgement no longer counts. **Local Read Text OCR remains available without cloud consent.**

Images are held on your device only for as long as the operation takes, and are deleted afterwards. We do not maintain a history of your photographs, and the app has no gallery or saved-results feature.

### 3.2 Your question text

When you use Ask a Question, the words of your question are sent with the image to your selected AI provider. The app does not maintain a saved question history; the current question/result can remain in memory for display or repetition.

### 3.3 Microphone and speech

When you use a voice feature, the app asks your Android device's own speech recognition service to listen and convert what you said into text. **The app receives only the resulting text; it never records, stores or transmits audio itself.**

Important: the conversion is performed by your device's speech provider, which on most Android devices is supplied by Google. Depending on your device, its language settings and its configuration, that service may process your speech on the device or on its provider's servers. That processing is governed by your device provider's privacy policy, not by this one. You can check and change which speech service your device uses in your Android settings.

Read Text's OCR does not require a network connection, but spoken input and TTS are separate system services. Your selected TTS engine may process text online under its own terms. Install and select an offline voice for offline playback; cloud-AI consent does not control these system services.

### 3.4 Your AI provider credentials

In "Bring Your Own Key" (BYOK) mode you explicitly select Groq, OpenAI, Google Gemini, or optional Mistral and can edit that provider's model ID. Each provider's personal API key is stored separately on your device using encrypted local storage (`flutter_secure_storage`, with Android `EncryptedSharedPreferences`). It is not sent to the EyeSense Worker. A request uses only the selected provider's key, transmitted to that provider as an authorisation header; another provider's key is not reused. You can remove the selected provider's key in Settings. Removing one does not remove keys saved for other providers.

In hosted mode, the app uses an access token to authorise access to our Worker. It is not a personal EyeSense account or a per-device identity. The Worker holds its Groq key server-side; it does not receive your BYOK keys.

Neither mode silently switches provider or model if a request fails. Hosted mode uses Groq only; BYOK uses the selected provider directly. Gemini uses Google's official OpenAI-compatibility endpoint, which sends requests to Google, not to OpenAI.

Mistral uses the fixed official base `https://api.mistral.ai/v1`: inference is `POST /chat/completions` and metadata checks are `GET /models`. It uses your own Mistral key, never another provider's key or a hosted token. The default model is `mistral-small-latest`; the alias may change and availability is not guaranteed. It is never selected as a fallback.

### 3.4.1 Optional connection checks

**Check key and model** sends an authenticated `GET /models` request to the selected provider using the entered key. It sends no photo or question and does not access the camera or run inference. It checks authentication and whether the model is listed, not vision or JSON support.

The separate **generated sample image test** requires cloud-AI consent and a further confirmation before sending one generated 64 × 64 red image to the selected provider using the entered key and model. No camera or personal photograph is accessed. This is one potentially billable inference call under your provider account, with no retry. Neither check automatically saves connection settings; saving is a separate action.

### 3.5 Diagnostic logs

Diagnostic logging is **off by default**. If you turn it on, the app writes technical records to a file on your device containing operation durations, error codes and token counts.

These logs never contain camera images, audio, your questions, recognised text, or API keys. They stay on your device. They are not transmitted to us. You can view the file size, export it, or delete it at any time in Settings. Exporting shares the file wherever you choose to send it, at which point this policy no longer governs it.

### 3.6 Your settings

Your preferences — including assistance profile, speech, haptics, theme, consent state, tutorial progress, provider selection, and per-provider model IDs — are stored locally. The selected response language and model ID are included in relevant AI requests; the app does not upload a copy of your preferences.

### 3.7 Your IP address, in hosted mode

When you use Describe Scene or Ask a Question in hosted mode, your request reaches our service over the internet, so our service necessarily receives **your IP address**.

We use the raw IP address as the key for per-client one-minute request counters, including a pre-parse throttle that can count authenticated requests later rejected by validation or disabled routes. These keys and counters are persisted in Cloudflare Durable Object storage. We also keep global one-minute and daily request counts and expiring concurrency reservations, none keyed to a client. These global counts are shared across the hosted pilot, not personal usage allowances.

On the next pre-parse, charge or release operation, the budget code prunes expired one-minute IP windows from both maps and expired concurrency reservations (60-second leases). Successful release also removes its reservation. A later operation observing a new UTC date resets the global daily total; minute windows can span midnight. **There is no scheduled deletion alarm or guaranteed deletion at expiry or 00:00 UTC. While idle, stored entries can remain until a later operation performs cleanup.**

Hosted pilot defaults are **6 requests per minute globally, 2 concurrent reservations and 100 requests per UTC day globally**; the operator can configure these limits. These are service budget controls, not guarantees of provider quota, successful inference or availability. Provider account limits also apply.

We do not use these IP counters to build a personal profile or infer your location. They are nevertheless a server-side record keyed to a raw IP address, not anonymous statistics. Cloudflare's own network processing is also subject to its policies.

In BYOK mode, AI requests go directly from your device to the selected provider, not our Worker. That provider receives your network address under its own terms.

### 3.8 Optional local Android sensor checks

EyeSense can read availability metadata and brief samples from the Android **accelerometer, gravity, gyroscope, ambient light and front proximity sensors**. Capability discovery does not start sampling. Sampling occurs only during an explicit capture with guidance or **Check Sensors**, for **less than one second**, with cancellation and foreground/lifecycle cleanup; it is not continuous background monitoring.

Metadata and samples remain local, ephemeral in-memory state for the check/current support display. They are not saved to a sensor history, added to diagnostic logs or included in network requests. **No GPS, compass or location sensing is used; no sensor metadata or samples are uploaded.**

Accelerometer/gravity give only approximate gravity-relative phone pose, not page alignment or subject orientation. Gyroscope provides a movement/hold-steady cue, not heading or distance. Ambient light is a rough light cue. Proximity means only that the **FRONT** sensor reports covered, not distance from a rear-camera subject or obstacle. These checks cannot establish page framing, road/path safety or navigation; missing sensors or no warning are not proof of safety or image quality. Hardware behavior and physical-device accessibility remain to be verified.

## 4. What we do not do

- We do not create user accounts or profiles.
- We do not collect your location. The app requests no location permission.
- We do not use cookies, advertising identifiers or device fingerprinting.
- We include no advertising, analytics, attribution or crash-reporting services.
- We do not sell, rent or trade any data.
- We do not use your images, questions or any other content to train AI models.
- We do not track you across other apps or websites.

## 5. Who else is involved

When you use a cloud feature, the image and relevant question or test prompt are processed by the parties on the selected route. We do not control their systems. Groq is the inference host for the configured Qwen model (`qwen/qwen3.8-27b` by default), not the model's name. Direct defaults are `gpt-5-mini` for OpenAI, `gemini-3.8-flash` for Google Gemini and `mistral-small-latest` for optional, explicitly selected Mistral; model IDs are editable and are not a guarantee of availability or capability.

| Party | Role | What they receive | Their privacy policy |
| --- | --- | --- | --- |
| **Cloudflare, Inc.** | Operates our API proxy at the network edge, in hosted mode | The request as it passes through, including the image, and your IP address | [cloudflare.com/privacypolicy](https://www.cloudflare.com/privacypolicy/) |
| **Groq LLC** | Inference host in hosted mode, or in BYOK only when Groq is the selected provider | Image and question/test prompt; your Groq key and network address for direct BYOK requests | [Groq privacy policy](https://groq.com/privacy-policy) |
| **OpenAI** | Direct AI processing only when OpenAI is the selected BYOK provider | Image and question/test prompt, OpenAI key, and network address | [OpenAI privacy policy](https://openai.com/policies/privacy-policy/) |
| **Google — Gemini API** | Direct AI processing only when Google Gemini is the selected BYOK provider, through Google's OpenAI-compatibility endpoint | Image and question/test prompt, Gemini key, and network address | [Gemini API terms](https://ai.google.dev/gemini-api/terms) and [Google privacy policy](https://policies.google.com/privacy) |
| **Mistral AI** | Direct AI processing only when Mistral is explicitly selected in BYOK, using its fixed official API | Image and question/test prompt, your own Mistral key and network address | [Mistral privacy policy](https://legal.mistral.ai/terms/privacy-policy) and [terms](https://legal.mistral.ai/terms) |
| **Google / selected system speech provider** | On-device ML Kit OCR; separately, system speech recognition and TTS | The OCR image is not uploaded. The selected speech service may receive speech or text as described in §3.3 | [Google privacy policy](https://policies.google.com/privacy); check your selected speech provider's terms |

**Please read this carefully:** once a request has been received by an AI provider, it is subject to that provider's own processing and retention terms, and **we cannot recall it**. Stopping an operation in the app cancels our request; it does not necessarily stop processing that the provider has already begun, or any charge it incurs.

In BYOK mode, requests go directly to the **selected provider** under your own account, subject to your agreement with that provider and its quotas and charges. Local image deletion does not establish provider-side deletion, zero retention, or exclusion from provider training.

**Mistral Free-mode warning:** input/output data may be used for training unless you opt out in your Mistral account (Admin → Privacy → Anonymous improvement data). EyeSense does not inspect or change that setting. Training opt-out is not zero retention: **zero-data retention is unavailable on Free mode**; eligible paid arrangements require provider approval. Do not assume automatic provider-side deletion. The account's current Limits page and terms are authoritative; a free key does not guarantee vision/model access, remaining quota, support or production reliability. No live Mistral test has been performed. See [training guidance](https://help.mistral.ai/en/articles/347617-do-you-use-my-user-data-to-train-your-artificial-intelligence-models), [opt-out instructions](https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training), and [zero-retention guidance](https://help.mistral.ai/en/articles/347612-can-i-activate-zero-data-retention-zdr).

These official links are references, not legal approval or an assurance of account-specific retention, training or transfer terms. Review of the selected provider's current API terms, account tier, processing, retention, training use, and international transfer conditions is required before release or sensitive use. Terms can change.

## 6. Why we are allowed to process this

Where data protection law requires a legal basis, we rely on:

- **Your consent**, for sending images and questions to a cloud AI provider. You give it explicitly and can withdraw it at any time in Settings. Withdrawal does not affect processing already completed.
- **Performance of our agreement with you**, for the on-device processing needed to make the app work at all.
- **Our legitimate interests**, for protecting the hosted service against abuse and excessive cost, using your IP address as described in §3.7.

## 7. How long things are kept

| Data | Retention |
| --- | --- |
| Camera images on your device | Deleted after each operation |
| Images and questions held by AI providers | Governed by the provider's terms, not by us — see §5 |
| Diagnostic logs | On your device until you delete them or uninstall the app |
| Your settings and stored API keys | On your device until removed or the app is uninstalled; keys are separate per provider |
| Local sensor metadata and samples | Ephemeral in-memory check/current display only; not saved or uploaded — see §3.8 |
| Per-client request counters keyed to your raw IP address | Expired one-minute windows pruned on a later pre-parse/charge/release; no timed deletion guarantee — see §3.7 |
| Global budget counts and concurrency reservations | Minute/day counts reset lazily; 60-second reservations expire and are pruned on a later operation or removed by release; not per-client |

## 8. Security

- All network connections use HTTPS. The app's Android network security configuration forbids unencrypted traffic in release builds.
- Your personal API keys are stored separately per provider in encrypted local storage using Android `EncryptedSharedPreferences`.
- `android:allowBackup="false"` prevents your stored credentials being copied into cloud device backups.
- Our hosted service holds provider credentials as server-side secrets; they are not present in the app.

No system is perfectly secure. We cannot guarantee absolute security, and you should not use EyeSense to photograph material you consider highly sensitive.

## 9. Children

EyeSense is not directed at children, and we do not knowingly process data from children. If you believe a child has used the app in a way that concerns you, contact us at info@devray.qzz.io and we will assist.

## 10. International transfers

The AI providers and edge infrastructure in §5 may process data in other countries, including the United States. The selected route determines who receives the image, question/test prompt, and network address. Our edge provider receives hosted requests; BYOK requests go directly to the selected provider. This notice does not establish a legally sufficient international transfer mechanism; review is required.

To avoid cloud-AI image transfers, leave cloud consent off and use **Read Text** OCR. To keep the speech workflow offline too, avoid online speech recognition and select an installed offline TTS voice; cloud consent alone does not control system speech services.

## 11. Your rights

Depending on where you live, you may have rights to access, correct, delete, restrict or object to the processing of your personal data, to withdraw consent, and to complain to a regulator.

EyeSense has no user accounts, but the hosted service stores raw-IP counters as disclosed in §3.7. Many controls are available directly on your device:

- **Withdraw consent:** turn off Cloud Processing Consent in Settings.
- **Delete local data:** delete diagnostic logs and remove each saved provider key in Settings, or uninstall the app. This does not delete data held by a provider or the hosted IP counters.
- **Stop cloud-AI transfers:** leave cloud consent off and use Read Text OCR. System speech services have separate settings; see §3.3.

For anything you cannot do yourself, contact **info@devray.qzz.io** and we will respond within **30 days**. We may be unable to act on a request for data we cannot link to you — in most cases we simply do not hold any.

You may also complain to the data protection authority in your country.

## 12. Changes to this policy

We will update this policy when the app's behaviour changes. We revise the effective date and version for changes. This pilot's 1.1-pilot consent gate requires an explicit new cloud opt-in for older or missing accepted versions, as described in §3.1. Publishing superseded notices at [eyesense.dpdns.org/privacy/history](https://eyesense.dpdns.org/privacy/history) and verifying an accessible in-app review notification remain release tasks; this source update does not claim either has been published or physically tested.

## 13. Accessibility of this policy

This policy is available in the app as screen-reader-accessible text, and at [eyesense.dpdns.org/privacy](https://eyesense.dpdns.org/privacy). If you need it in another format or another language, contact us and we will provide one.
