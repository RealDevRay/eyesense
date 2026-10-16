# EyeSense MVP remediation and provider-selection guide

Prepared: 16 October 2026. Provider documentation checked on this date.

**Status:** implementation plan, not a record of completed fixes. No application or Worker behavior was changed when this guide was generated.

## 1. Outcome and scope

Ship an Android-first assistant that an intended user can independently open, configure, use, interrupt, and recover:

1. Describe one freshly captured scene.
2. Read printed text locally, including offline use.
3. Ask a typed or short spoken question about a fresh image.
4. Stop local playback/presentation, cancel supported work, and repeat clearly labelled previous information. Already accepted remote processing and charges may continue.

Do not add navigation, crossing advice, background camera, Awareness, physical triggers, accounts, unlimited chat, or extra agent calls during remediation. Keep the existing Flutter app, package identity, Worker endpoint contract, and working service boundaries. This is not a rewrite.

Work in small reviewable batches. Add a regression test with each behavioral fix. Passing a phase means its exit checks pass, not merely that the implementation compiles. Device-dependent checks require real Android evidence.

## 2. Phase order

| Phase | Outcome | Depends on |
| --- | --- | --- |
| 0 | Reproducible baseline and test seams | None |
| 1 | Enforced consent, safe output, truthful privacy | 0 |
| 2 | One cancellable operation with real bounds | 0; integrate 1 |
| 3 | Reliable speech input and playback | 2 |
| 4 | Reliable capture, permissions, lifecycle, cleanup | 2 |
| 5 | Accessible independent setup and controls | 1–4 |
| 6 | Hardened Worker and enforceable usage protection | 0–2; can develop alongside UI |
| 7 | Evidence-based provider evaluation and optional migration | 1, 2, 6 |
| 8 | Complete diagnostics, CI, and accurate documentation | Tests throughout; consolidate 1–7 |
| 9 | Signed candidate and intended-user pilot | All required phase gates |

**Immediate containment:** rotate the shared token if the committed default was deployed, restrict access, and keep the cloud kill switch available. Before expanding hosted testing, require the Phase 6 bounded body reader, rate/concurrency/budget controls, and server output-policy gate as well as consent enforcement. Bring these backend protections forward and develop them alongside app work; the numbered phases are not permission to expose an unhardened deployment. Keep hosted access restricted or disabled until that gate passes.

**Route scope:** decide now whether `/v1/reading` and `/v1/conversation` are part of the pilot. If deferred, disable them server-side; hiding app controls does not disable callable routes. Otherwise retain them only with the same applicable authentication, budget, contract, safety, and test gates as vision.

## 3. Phase 0 — Establish the baseline

### Steps

- [ ] Record the source revision, current Git status, Flutter/Dart/JDK/Android/Node versions, build defines, and deployed Worker configuration names. Do not record secret values.
- [ ] Preserve the existing untracked desktop registration files. Decide separately whether generated platform files should be tracked or ignored; do not delete them as audit cleanup.
- [ ] Record the supplied APK's checksum, SDK levels, and signing fingerprint. Treat it as an unverified prototype artifact until rebuilt from a recorded revision.
- [ ] Pin the tested Flutter version in CI/tooling. Keep both dependency lockfiles. Avoid simultaneous dependency upgrades and behavioral fixes.
- [ ] Resolve the unused `_isLoading` warning in `app/lib/main.dart` without hiding meaningful startup state.
- [ ] Add injectable clock, transport, camera, speech, TTS, and filesystem seams only where tests need them. Prefer the existing constructor-injection pattern over a new state-management framework.
- [ ] Add a minimal CI job for Dart analysis, Flutter tests, Worker typecheck, and Worker tests; grow it in Phase 8.
- [ ] Add a sanitized, tracked `worker/.dev.vars.example` by exempting only that template from `.gitignore`. Keep real environment files ignored.

### Run from the specified directories

From `app/`:

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter analyze --suggestions
dart analyze lib test
flutter test --no-pub
```

From `worker/`:

```sh
npm ci
npm run typecheck
npm test
```

Bound long-running commands. If Flutter analysis hangs, retain that outcome and investigate; a direct Dart analysis result does not establish Android build compatibility.

### Exit checks

- [ ] The existing suites pass from the pinned environment.
- [ ] Analysis has no unexplained warnings or errors.
- [ ] New tests can control completion order without real plugins or paid requests.
- [ ] Setup works from a clean checkout without copying private local files.

**Primary files:** `app/lib/main.dart`, `app/test/widget_test.dart`, `app/pubspec.yaml`, `worker/package.json`, `.gitignore`, `README.md`; proposed CI configuration.

## 4. Phase 1 — Enforce trust, privacy, and output policy

### Steps

- [ ] Check cloud consent in the coordinator before Describe, Ask, or any optional cloud-text task. Apply this equally to hosted, voice-triggered, and BYOK paths. BYOK is not on-device processing.
- [ ] Recheck consent immediately before dispatch and after relevant asynchronous waits. Revocation invalidates active generations, aborts cancellable uploads, and prevents further presentation of obsolete results. Explain that a request already received by a provider cannot be recalled.
- [ ] Keep Read Text available without cloud consent, a provider key, or network access.
- [ ] Replace the empty prohibited-output branch in `OutputPolicy` with explicit enforcement and a conservative limitation response. Validate the actual spoken answer as well as summary and other displayed fields.
- [ ] Establish a refusal/limitation policy for road-crossing decisions, safe-path assurances, exact proximity claims, and walking instructions. Prompt instructions and phrase checks are defense in depth, not proof of safety.
- [ ] Create strict shared contract fixtures for Dart and TypeScript. Require nonblank summaries and valid enum values; reject malformed types, missing required fields, and unsafe defaults such as missing quality becoming `usable`.
- [ ] Require a meaningful Ask answer or an explicit inability explanation. Require useful concern/uncertainty information when corresponding flags warrant it. Do not truncate a result blindly in the middle of an important caveat.
- [ ] Build one presentation record containing task kind, capture/result time, response text, uncertainty, concern details, and current/previous status. Generate visual and spoken output from the same record.
- [ ] Clear scene-only metadata when OCR completes. Label retained output as previous after failure or when repeating; never imply it describes the current scene.
- [ ] Replace unconditional privacy guarantees with factual data-flow disclosures. Include the selected processor, voice-triggered uploads, applicable provider retention terms, system speech-recognition behavior, and BYOK quotas/possible charges.
- [ ] Rotate any deployed committed default token; stop treating a token embedded in every APK as secret authentication. Do not embed developer provider keys or Cloudflare account tokens in the app.

### Tests and exit checks

- [ ] Consent false: Describe, typed Ask, voice Ask, and BYOK produce zero cloud requests.
- [ ] Consent revoked during a delayed capture or pending dispatch: no new upload starts and no obsolete result appears.
- [ ] Local OCR still works with consent false and networking disabled.
- [ ] Dangerous text in `answer`, not only `summary`, reaches the limitation path.
- [ ] English/Kiswahili safety fixtures include paraphrases and photographed prompt injection.
- [ ] Unclear images expose qualifications visually and audibly.
- [ ] OCR after a concern-bearing description does not inherit its warning.

**Primary files:** `app/lib/agents/agent_coordinator.dart`, `output_policy.dart`, `app/lib/models/scene_result.dart`, both app provider adapters, `app/lib/widgets/response_panel.dart`, onboarding/settings, `worker/src/schema.ts`, `worker/src/prompts.ts`.

## 5. Phase 2 — Make operations cancellable, serialized, and bounded

### Steps

- [ ] Give each operation one context: ID, generation, cancellation signal, actual capture timestamp, monotonic deadline, and model-call count.
- [ ] Serialize operation transitions. Define whether activating a new action interrupts or is unavailable; do not permit two workflows to control state concurrently.
- [ ] Check cancellation after every meaningful asynchronous boundary: haptics, permission/init, capture/compression, credential reads, requests, concern feedback, and speech setup.
- [ ] Propagate cancellation to Dio with `CancelToken` and to speech/TTS queues. Physical capture/OCR may not support abort: invalidate its completion and clean up afterward.
- [ ] Abort Worker upstream requests on its deadline. Do not promise that cancelling the mobile request necessarily cancels already accepted upstream inference or its charge.
- [ ] Keep Stop idempotent and immediately effective. Guard late success/error callbacks by operation identity.
- [ ] Make Repeat participate in operation ownership. Explicitly interrupt or disable it during processing; it must not silently reset a different operation to idle.
- [ ] Enforce `maxCalls` before making a call. Enforce the remaining time budget, not just increment counters. Prefer one vision call per task; permit at most one bounded extra attempt only when justified.
- [ ] Start scene freshness at actual capture rather than task construction after compression. Use elapsed monotonic time for deadlines and an injected clock in tests. Validate freshness again before presentation.
- [ ] Define freshness at the start of delivery, not as an excuse to cut a valid spoken description off mid-sentence. Label it as a snapshot, not live awareness.
- [ ] Normalize timeout/cancellation errors so stopping is not spoken as a failure.

### Tests and exit checks

- [ ] Stop during capture, compression, upload, response validation, or pre-speech setup produces no late speech/result.
- [ ] Stopping during readiness preparation does not subsequently activate the microphone.
- [ ] Repeated taps do not create duplicate native captures or network requests.
- [ ] Old callbacks cannot change a newer operation's state.
- [ ] Model-call limits fail before an extra dispatch, and deadlines cover the entire attempt/fallback sequence.
- [ ] Repeat has no camera or network side effects and follows the documented interruption policy.

**Primary files:** `app/lib/agents/agent_coordinator.dart`, `agent_task.dart`, `scene_agent.dart`, `output_policy.dart`, `app/lib/models/app_operation.dart`, `app/lib/services/vision_api_service.dart`, both provider adapters, Worker upstream handlers.

## 6. Phase 3 — Fix speech input, playback, and language support

### Steps

- [ ] Observe native playback start, completion, cancellation, and error. Enable completion-awaiting only with explicit error/cancellation resolution and a bounded failure path; do not assume adding `awaitSpeakCompletion(true)` fixes every plugin outcome.
- [ ] Keep coordinator `speaking` state accurate until playback completes. Notify the UI when TTS changes state; never announce Ready over a still-playing response.
- [ ] Read the platform TTS input limit and split long OCR into bounded sentence/paragraph chunks, respecting UTF-16 limits on Android. Stop must cancel remaining chunks. Repeat includes any spoken prefix in its length budget.
- [ ] Map speech-rate labels to supported plugin values. Migrate existing persisted values if their meaning changes; provide an accessible label and value formatter.
- [ ] Give feedback one owner: concise status via a single semantic mechanism, optional app result TTS, and deliberate error delivery. Remove duplicate live-region/explicit-announcement paths.
- [ ] Honor the chosen automatic-reading policy consistently in results, errors, and practice feedback. Keep essential errors available as accessible text.
- [ ] Return explicit speech-recognition outcomes: recognized text, no speech, timeout, denied, unavailable, cancelled, or error. Do not swallow native status/error callbacks.
- [ ] Bound listening duration and silence. Request microphone permission only for explicit Start voice command or Voice Ask; avoid collecting the app's own readiness speech.
- [ ] Match short commands using exact approved phrases or token-aware rules. Questions containing `stop sign`, `bread`, or `textile` must not be accidentally routed by substrings.
- [ ] Enforce question length in the input UI and at the coordinator/provider boundary, equally for hosted and BYOK. Give actionable feedback rather than a late generic server error.
- [ ] Enumerate available recognition locales/TTS voices. Offer a voice sample and explain unsupported Kiswahili capability; never silently keep a Kiswahili preference while using an English voice.
- [ ] Add Android package-visibility queries for `android.intent.action.TTS_SERVICE` and `android.speech.RecognitionService`.

### Tests and exit checks

- [ ] A delayed TTS fake keeps state speaking until completion; error and cancellation always settle it.
- [ ] More than 4,000 UTF-16 units of OCR are read through bounded chunks; Stop prevents subsequent chunks.
- [ ] Silence and recognition errors leave listening automatically and expose the appropriate retry/typing option.
- [ ] TalkBack plus automatic-reading on/off produces intelligible, noncompeting feedback on the target device.
- [ ] Fresh-install Android 11+ TTS/recognition discovery works with the packaged release manifest.
- [ ] Missing recognition service, microphone denial, and unavailable voices retain direct OCR and typed Ask.

**Primary files:** speech/TTS/feedback services, coordinator, `app/lib/core/accessibility/semantic_announcer.dart`, `app/lib/widgets/operation_status.dart`, settings/onboarding, Android main manifest.

## 7. Phase 4 — Fix camera, permissions, lifecycle, and capture quality

### Steps

- [ ] Remove unhandled eager Home camera initialization. Initialize after an explicit camera task; if preview is retained, make its activation optional and explain camera use.
- [ ] Distinguish denied, permanently denied, unavailable, busy, and processing failures. Provide persistent text, Retry when useful, and Open app settings for permanent denial.
- [ ] Serialize camera initialization and capture; dispose failed partial controllers. Avoid permission/init races between Home, practice, and active tasks.
- [ ] Add an application-lifecycle owner. On background/inactive transitions stop listening/playback and invalidate active tasks; release camera appropriately. Restore lazily on return, without resuming an obsolete capture automatically.
- [ ] Own and dispose OCR recognizers/controllers at the correct lifecycle boundary. Handle route disposal without late state updates.
- [ ] Delete temporary image files in `finally` for success, failure, cancellation, and onboarding practice. Perform narrowly scoped stale capture cleanup after crashes without deleting unrelated cache files.
- [ ] Separate local OCR capture from cloud image preparation. Do not resize/base64-encode an image that only needs on-device OCR.
- [ ] Measure text legibility before choosing resolution. `ResolutionPreset.medium` can limit OCR detail; use a tested OCR-specific capture profile rather than assuming a 1280-pixel maximum creates 1280-pixel source detail.
- [ ] Offload expensive image decoding/resizing/encoding when measurements show UI-isolate jank. Preserve byte/dimension limits.
- [ ] Verify portrait/landscape orientation, rear-camera left/right references, and EXIF handling. Do not add rotation blindly if the decoder already normalizes orientation.
- [ ] Add simple, tested capture guidance for too dark, blurry, or poorly framed images. Clearly distinguish measured signals from model guesses; do not invent proximity or collision alerts.

### Tests and exit checks

- [ ] No permission prompt occurs just from opening Home.
- [ ] Temporary captures disappear after each outcome, including compression failure and cancelled practice.
- [ ] Background/resume and return from app settings restore task availability without resource crashes.
- [ ] Denial/permanent-denial paths can be recovered with TalkBack.
- [ ] Offline OCR works on a clean installed candidate, not only a previously prepared development device.
- [ ] Rotation, lighting, small print, and low-end-device responsiveness are tested with recorded results.

**Primary files:** `app/lib/services/camera_service.dart`, `ocr_service.dart`, `main.dart`, Home/onboarding; proposed lifecycle owner and capture-result metadata.

## 8. Phase 5 — Repair accessible UI, onboarding, and settings

### Steps

- [ ] Replace global infinite-width button minima with finite minima. Apply full-width constraints only at suitable call sites; constrain connection-page Row children or stack them.
- [ ] Replace hardcoded dark-surface/light-accent aliases with paired theme surface/foreground/error/warning colors throughout result, connection, and diagnostic widgets.
- [ ] Make primary action height a minimum, not an exact box. Allow wrapping; avoid single-line ellipsis for essential labels.
- [ ] Put long dropdowns below their labels, flex concern text, and make Ask content scrollable with the keyboard visible. Review startup error layout at large text too.
- [ ] Put Stop in a stable non-scrolling operation area. Either stop before leaving Home or retain an accessible operation control on covering routes.
- [ ] Use one native actionable semantic node per control. Add only missing hints; avoid repeating wrapper labels and tooltips. Verify disabled/loading semantics and stable traversal.
- [ ] Make Start voice command the first primary actionable home item as required; keep Settings available in a deliberate traversal position and preserve focus through state changes.
- [ ] Apply provider/URL changes through an explicit live-configuration update, invalidating active work before switching. Do not report a saved preference as an applied runtime change.
- [ ] Observe preferences rather than keeping stale independent copies. Returning from Tutorial must refresh consent, language, and other changed settings.
- [ ] Validate configured Worker URLs as HTTPS in distributed builds. Keep local HTTP exceptions debug-only. Prefer hiding advanced endpoint/token setup from the ordinary pilot flow.
- [ ] Guard asynchronous UI actions with route-lifetime checks and busy guards: practice, key removal, diagnostics toggles, Save, and Finish. Do not issue obsolete speech after navigation.
- [ ] Persist onboarding progress separately from completion. Keep Skip, but report factual readiness: tutorial complete, camera untested, voice unavailable, or cloud setup required.
- [ ] Show practice outcomes persistently as accessible text, not only TTS. Offer voice samples/capability explanations from Phase 3.
- [ ] Make credential remove/replace feedback truthful and immediately effective. Retain masking, and verify actual TalkBack behavior instead of assuming obscured text proves secrecy.

### Tests and exit checks

- [ ] Widget tests render Home, Ask, AI Connection, Settings, Onboarding, Diagnostics, and result states without layout exceptions.
- [ ] Both themes at approximately 320 logical pixels wide and 200% text scale remain operable without essential-label truncation.
- [ ] Text contrast is at least 4.5:1 and important controls/focus boundaries at least 3:1 where applicable; touch targets remain at least 48 logical pixels.
- [ ] Semantics tests establish one label/action, disabled state, and intended traversal.
- [ ] Save applies provider changes without restart; tutorial return reflects new preferences.
- [ ] A blind/TalkBack-only tester can refuse cloud use, recover camera permission, read locally, ask, repeat, and stop without a sighted helper.

**Primary files:** `app/lib/core/theme/app_theme.dart`, all `app/lib/widgets/`, all `app/lib/features/`, preferences, coordinator, startup UI.

## 9. Phase 6 — Harden the Worker and protect shared usage

### Steps

- [ ] Validate parsed input as a non-null object before property access. Reject null, arrays, primitive JSON, malformed JSON, and unexpected credential fields with controlled responses.
- [ ] Read request bodies with a cumulative byte limit and cancel overflow immediately. Treat Content-Length as an early optimization, not the authoritative safety control. Test multibyte and streamed bodies.
- [ ] Require trimmed nonblank Ask questions, reading text, and conversation messages. Validate base64 encoding, decoded image size, JPEG signature, and practical dimension limits before inference.
- [ ] Strengthen response invariants: nonblank output, a question for `clarify`, an answer/inability explanation for Ask, and qualifications when incomplete/unclear. Detect missing choices, refusals, truncation, and invalid JSON.
- [ ] Supply output bounds to models and use supported structured-output features per model. Keep local validation even when the provider promises a schema.
- [ ] Enforce a Worker-side response policy before returning model output, covering every returned natural-language field and replacing prohibited schema-valid guidance with a conservative limitation response. Keep app enforcement for BYOK and defense in depth. Neither layer establishes general navigation safety.
- [ ] Disable deferred reading/conversation routes server-side, or apply all applicable gates to them. Test disabled routes explicitly rather than assuming absent UI makes them inaccessible.
- [ ] Replace arbitrary exception-message reflection with typed errors and sanitized messages. Distinguish client auth, upstream configuration/auth, rate limit, invalid upstream output, timeout, and service outage.
- [ ] Preserve safe Retry-After/cooldown metadata. Do not automatically run long retry loops for a scene that will become stale.
- [ ] Validate required secrets/configuration without printing them. Bound timeout configuration and distinguish liveness from authenticated readiness/capability checks. Avoid a paid inference on every health poll.
- [ ] Add server-enforced per-invitation/client throttles, global concurrency protection, and a daily usage budget. Use a managed limiter/durable coordination appropriate to the deployment; process-local maps are not global limits, and eventually consistent KV alone is not a strict atomic budget.
- [ ] Do not trust a freely chosen client ID as the security boundary. Keep a small invitation registry for the pilot; supplement with IP signals carefully because shared mobile networks can contain many legitimate users.
- [ ] Avoid duplicate in-flight dispatches by operation ID where feasible. Do not retain scene payloads/results merely to implement deduplication.
- [ ] Keep provider destinations and hosted model allowlists server-controlled. Add untrusted-context treatment to the conversation prompt if that route remains active.
- [ ] Provide budget-exhausted/cooldown responses that leave local OCR usable. Keep a tested cloud kill switch.

### Tests and exit checks

- [ ] Worker-runtime integration tests cover all enabled routes, plus deterministic fetch-mocked tests.
- [ ] Null/primitive bodies, malformed base64/JPEG, missing Ask text, whitespace-only inputs, exact byte boundaries, and multibyte overflow are rejected cleanly.
- [ ] Upstream 401/403/429/5xx, timeout, invalid JSON, schema failures, empty choices, and truncation produce stable sanitized responses.
- [ ] Concurrent requests cannot bypass the configured budget/concurrency policy.
- [ ] Adversarial, schema-valid unsafe responses are stopped before the Worker returns them; disabled routes cannot invoke upstream inference.
- [ ] Timers are cleared and errors contain no raw model response, credentials, or private request data.
- [ ] Health can distinguish configured readiness from mere process liveness.

**Primary files:** `worker/src/index.ts`, `schema.ts`, `vision.ts`, `prompts.ts`, all `worker/src/agents/`, `worker/test/worker.test.ts`, `wrangler.jsonc`; app provider error mapping.

## 10. Phase 7 — Measure providers, then optionally migrate

### Important distinction

The existing Cloudflare Worker is a proxy. It does **not** currently use Workers AI inference and does not increase Groq's quota. Cloudflare Workers request allowance, Workers AI neurons, and Groq/Mistral quotas are separate budgets.

### Steps

- [ ] First read Groq's organization Limits page and capture content-free rate-limit headers plus token usage from representative requests. Determine whether RPM, TPM, RPD, or TPD is the actual bottleneck.
- [ ] Check Mistral's account model access, per-model request/token limits, included monthly usage, PAYG setting, and current retention/data-use terms. Do not adopt third-party free-quota figures as account guarantees.
- [ ] Check Cloudflare model eligibility, rate limits, image-input schema, structured-output support, daily neuron usage, and account plan. Not every listed model is available under the same conditions.
- [ ] Use a consented, non-sensitive evaluation set, for example 40 scene/question cases: ordinary objects, clutter, low light, blur, text questions, unanswerable questions, English/Kiswahili, photographed injection, and prohibited navigation requests. Run providers sequentially and budget the evaluation itself.
- [ ] Compare groundedness, correct uncertainty/refusal, JSON validity, language quality, p50/p95 capture-to-result latency, failure rate, and actual tokens/neurons per successful task. A schema-valid answer can still be wrong.
- [ ] Reject candidates that cannot pass safety/quality gates, even if they provide more free calls. Inspect model retirement/preview status and pin explicit versions where available.
- [ ] Keep the Flutter hosted contract unchanged. Add small server-side adapters behind the existing vision handler for the chosen candidate rather than hardcoding each hosted API into the mobile app.
- [ ] Proposed deployment-only configuration can include `VISION_PROVIDER` and a provider-specific model identifier. Validate that selection against a tested allowlist; these variables do not exist in the current implementation.
- [ ] For Workers AI, add an `AI` binding and use the verified model-specific input/output adapter. Do not assume OpenAI-style messages work identically across models, or that model-architecture vision implies endpoint image support.
- [ ] For hosted Mistral, keep `MISTRAL_API_KEY` as a Worker secret. Never place it or a Cloudflare account token in an APK.
- [ ] Keep existing user-owned Groq BYOK separate and explicitly labelled. Do not broaden mobile BYOK support until a real user need justifies more storage/UI/validation paths.
- [ ] Prefer manual server-side rollback initially. If adding fallback, allow only a tested, disclosed alternative processor, within the original cancellation/deadline/call budget. Do not silently send the same image to several providers.
- [ ] Never retry policy refusals, invalid client input, or safety-blocked output through a more permissive model. Long daily-quota exhaustion should trigger a clear limitation, not repeated attempts.
- [ ] Canary a small pilot cohort and retain the previous server provider configuration for rollback.

### Exit checks

- [ ] A real authenticated image-plus-schema smoke test passes on each enabled provider; GET /models alone is insufficient.
- [ ] The chosen model passes the same result/output-policy fixtures as Groq.
- [ ] Stop/deadlines/consent apply to provider switching and fallback.
- [ ] Estimated capacity is based on measured successful tasks, with retries/failures and a reserve included.
- [ ] Provider disclosures and usage limits match the actual deployed route.

### Current provider comparison

Verified against official documentation on 16 October 2026. Account dashboards and live headers remain authoritative. No authenticated inference benchmark or account inspection was performed for this guide.

| Option | Verified public information | Implication for EyeSense |
| --- | --- | --- |
| Existing Groq Qwen | Vision docs list `qwen/qwen3.8-27b` and 2,048 input tokens per image. Public rate-limit table currently shows 30 RPM, 1,000 RPD, 8,000 TPM, and 200,000 TPD; confirm plan/account applicability. | Image token limits can bind long before 1,000 daily requests. JPEG compression saves upload bytes but does not remove this documented fixed image-token charge. |
| Mistral-hosted API | Free mode permits API keys and included monthly usage. Per-model throughput and actual allowances are shown in the Admin Limits/Subscription pages; monthly allowance may be shared with other Mistral products. Vision-capable models are available, including `ministral-8b-2512`. | Technically suitable to benchmark, but the public evidence does not establish that your free account provides more usable vision tasks than Groq. Confirm quotas, access, retention, and model lifecycle first. |
| Cloudflare Workers AI | 10,000 neurons/day free, reset at 00:00 UTC. Free-plan inference stops after the allocation. Workers Paid is required for excess usage, billed at $0.011 per 1,000 neurons above the allocation; Workers Paid has a $5/month minimum subscription. | A smaller, validated vision model may provide more useful tasks, but there is no fixed free request count. All relevant inference shares the account allocation. |

**Cloudflare candidates:** start with `@cf/meta/llama-3.2-11b-vision-instruct` as a low-cost baseline and `@cf/qwen/qwen3.8-27b` as a closer comparison to the current model. Evaluate newer eligible models only when their image API, quality, pricing, and stability are verified. English performance does not establish Kiswahili quality.

**Important caveat:** Cloudflare's Mistral Small 3.1 model description discusses architectural vision capability, but the published synchronous input schema inspected for that endpoint exposes text input and no image field. Do not recommend it as a working Cloudflare vision replacement without endpoint-level confirmation and a real image test. Mistral-hosted vision support is a separate question.

### Illustrative capacity arithmetic, not a benchmark

Assume **3,000 accounted input tokens, including image tokens, plus 200 accounted output tokens per task**, no retries, no cache discount, no additional reasoning tokens, and no other account usage. The same image can tokenize differently across providers, so these equal-token examples are not measured equal-image comparisons.

```text
Cloudflare neurons/task =
  input_tokens * input_neurons_per_million / 1,000,000
  + output_tokens * output_neurons_per_million / 1,000,000

Cloudflare daily task ceiling = floor(10,000 / neurons_per_task)

Groq token-based daily task ceiling = floor(TPD / accounted_tokens_per_task)
```

| Example | Calculation | Approximate arithmetic ceiling |
| --- | --- | --- |
| Cloudflare Llama 3.2 11B Vision | 3,000 * 4,410 / 1M + 200 * 61,493 / 1M = 25.53 neurons/task | 391 tasks/day |
| Cloudflare Qwen 3.8 27B | 3,000 * 40,909 / 1M + 200 * 290,909 / 1M = 180.91 neurons/task | 55 tasks/day |
| Groq, if your organization has 200,000 TPD | 200,000 / 3,200 | 62 tasks/day before other limits |
| Mistral Free | Account-specific allowance not inspected | Cannot calculate honestly yet |

This illustrates why changing the **host alone** is not necessarily better: the Cloudflare version of the same Qwen model can use the daily free budget quickly. A cheaper model may yield more tasks, but quality must be established. Reserve capacity for failures, schema overhead, reasoning where billed, evaluation, and other account workloads.

At the Llama example above, 1,000 tasks/day would consume about 25,529 neurons/day. Excess inference would be about $0.171/day, or $5.12 over 30 days, plus the $5/month Workers Paid minimum and any other applicable usage/taxes. This is a conditional arithmetic example, not a quote or a measured EyeSense bill.

### Recommendation

Keep the existing Worker as the hosted control plane. Fix waste, consent, cancellation, and limits first. Benchmark Cloudflare's low-cost vision baseline and a currently available Mistral vision model against Groq. Promote a candidate only if it passes the safety/quality/latency gates. For a real pilot, a small explicit monthly budget and hard application usage controls are more sustainable than depending on changing free allowances. Do not create extra accounts or rotate keys to evade provider limits.

## 11. Phase 8 — Finish diagnostics, scope honesty, CI, and documentation

### Steps

- [ ] Replace `errorCode: e.toString()` with an allowlisted error code. Do not log raw model/parsing errors that can contain response excerpts.
- [ ] Instrument capture, OCR, recognition outcome, speech, cancellation, provider status, and safe usage counts. Never include images, audio, questions, OCR/model text, API keys, or arbitrary URLs with credentials.
- [ ] Serialize logging writes and test retention/export/clear behavior. Implement bounded file segments if needed; do not delete the only current log unexpectedly when it crosses the total ceiling.
- [ ] Make clear/export failure statuses truthful. Do not say logs were cleared if deletion was silently swallowed. Keep all logging failures nonfatal to assistance.
- [ ] Ensure diagnostics remain opt-in. Server-side abuse counters should contain only minimal control metadata and have documented retention; do not create hidden content logging through dashboards/AI Gateway.
- [ ] For the current MVP, keep optional reading-summary/conversation features inactive or clearly deferred. Do not describe the first-three-lines stub as AI summarization or unused keyword code as a completed multi-agent flow.
- [ ] If retaining the stubs for future work, document their status and remove unsupported guarantees. Full cloud summarization/clarification is a later vertical slice with explicit consent and tests, not a prerequisite for the three core modes.
- [ ] Add real widget tests, coordinator concurrency tests, provider contract tests, Worker-runtime tests, and a small Android integration suite.
- [ ] Complete CI with pinned SDKs, lockfile installs, analysis, tests, and a clean Android build. Keep live model evaluations opt-in and budgeted; use synthetic fixtures in normal CI.
- [ ] Run bounded dependency audits/outdated checks. Review and patch actual vulnerabilities/compatibility issues individually; do not bulk-upgrade to silence warnings. An audit timeout is not a clean security result.
- [ ] Correct README SDK/toolchain instructions, configuration setup, privacy claims, and provider support. The supplied APK inspected during the audit was min/target/compile SDK 24/36/36; verify the new artifact rather than hardcoding old claims.
- [ ] Update architecture claims about consent, cancellation/mutex, freshness, call budgets, and hosted/BYOK parity to match demonstrated behavior.
- [ ] Expand the existing device checklist rather than creating conflicting verification records. Include Start voice command in microphone checks, both themes, 200% text, refusal, permanent denial, speech coexistence, long OCR, Stop/navigation, and background/resume.
- [ ] Record verification revision, date, command/device, result, and unresolved limitations. Prompt wording alone does not establish prompt-injection protection.

### Exit checks

- [ ] Exported diagnostics from all error fixtures contain only allowlisted metadata.
- [ ] CI tests successful core operations as well as failures, cancellation, and edge cases.
- [ ] No document labels a planned or unexecuted check PASSED.
- [ ] Clean-checkout instructions and actual minimum Android support agree with the release artifact.

**Primary files:** diagnostic service/screen, agent stubs, `app/test/`, proposed `app/integration_test/`, `worker/test/`, CI, README, architecture, demo script, device checklist.

## 12. Phase 9 — Produce and validate a pilot release

### Steps

- [ ] Remove `skipDependencyChecks=true` after establishing a compatible Flutter/Gradle/AGP/Kotlin/JDK combination. Change one build variable at a time; retain documented incremental-build workarounds only while justified.
- [ ] Keep application identity unchanged. Do not rename/recreate the Android project to repair build configuration.
- [ ] Configure protected release signing and preserve the keystore securely outside source control. Existing debug-signed installs may need uninstall/reinstall before accepting a differently signed APK; explain local-data loss or plan migration before distributing the candidate.
- [ ] Disable cleartext traffic in release; keep narrowly scoped local-development exceptions in debug configuration only.
- [ ] Review the **merged** release manifest for permissions and speech queries, not just the source manifest. Remove unnecessary dependency-contributed storage permissions only after verifying compatibility.
- [ ] Make the Gradle wrapper/bootstrap reproducible and add the distribution checksum. Validate a clean build with the pinned SDK and committed lockfiles.
- [ ] Do not re-enable shrinking as a prerequisite if it risks plugin regressions. Optimize APK distribution later using tested per-ABI APKs or an app bundle as appropriate.
- [ ] Build and test the exact signed candidate, including cold-start plugin registration, bundled/offline OCR, secure-storage key replacement/removal, and backup behavior. Do not infer working registration from DEX class presence.
- [ ] Record source revision, build command/defines, toolchain, SDK levels, signer fingerprint, and APK SHA-256. Never record secrets in build manifests or logs.
- [ ] Run the device matrix below and hold a small supervised pilot with blind/low-vision users. Ask testers to complete tasks independently; do not substitute a sighted engineer's successful demo for usability evidence.
- [ ] Review failures, agree a daily usage allowance, provide a feedback/support route, and keep a rollback/kill-switch procedure.

### Required device matrix

| Scenario | Required outcome |
| --- | --- |
| Fresh install, TalkBack only | Complete/skip tutorial, understand limits, activate core actions |
| Cloud refused or revoked | No new upload; local OCR remains usable |
| Camera/microphone denial and permanent denial | Clear explanation and accessible recovery |
| Missing recognition service or language voice | Typed Ask/local OCR remain available; no silent false capability |
| Long OCR, auto-reading on/off | Correct chunking, intelligible output, reliable Stop/Repeat |
| Home/Settings navigation while busy | No hidden unstoppable operation or obsolete speech |
| Background/resume, interruptions, rotation | Resources recover and old tasks do not restart |
| Offline, slow network, 429, exhausted daily budget | Accurate status, bounded wait, local fallback options |
| Small screen, 200% text, light/dark | Operable controls, readable output, preserved focus |
| Hosted and user-owned Groq BYOK | Live changes apply without restart; credentials stay masked/protected |
| Exact release artifact | Verified signing, permissions, SDK support, startup and secure storage |

### Suggested pilot gates — targets, not claims of current performance

- Zero uploads in automated consent-refusal tests.
- Zero obsolete result/speech deliveries in cancellation race tests.
- No prohibited navigation assurance in the curated acceptance evaluation; this is not proof of general safety.
- No essential-control clipping or rendering exceptions in the supported screen/text matrix.
- All core flows can be completed with TalkBack without sighted assistance.
- Capture-to-result p95 fits within the freshness budget with headroom; choose a product target such as 10 seconds only after initial measurement.
- Daily provider usage has a reserve (for example 20%) and a tested exhaustion path.
- No unresolved pilot-blocking defects in privacy, resource lifecycle, output policy, or accessibility.

## 13. First implementation batches

Do not begin by replacing Groq. Use this order for small reviewable changes:

1. Baseline tests, strict consent gate, safe metadata-only errors, token containment, and an explicit enabled-route decision.
2. Shared result invariants, enforced app/Worker output limitation, caveat presentation; in parallel, bounded Worker ingestion and rate/concurrency/budget protection. These are pre-exposure gates.
3. Operation cancellation/serialization/deadline tests and actual capture timestamp.
4. Observable TTS completion, chunking, recognition outcomes, Android speech queries.
5. Capture cleanup/lifecycle/permission recovery and OCR-specific path.
6. Theme/layout/semantics/persistent Stop and preference synchronization.
7. Remaining Worker validation, sanitized errors, readiness, and complete failure-matrix coverage.
8. Provider benchmark and at most one initial alternate hosted adapter.
9. Diagnostics/CI/docs consolidation, clean signed build, and user pilot.

Test continuously rather than postponing validation to the final batch. Do not mark a phase complete until its acceptance evidence exists.

## 14. Official provider references

These establish published capabilities/prices, not authenticated account entitlements or measured EyeSense quality.

1. Groq limits and headers: https://console.groq.com/docs/rate-limits
2. Groq account limits: https://console.groq.com/settings/limits
3. Groq vision and image token accounting: https://console.groq.com/docs/vision
4. Mistral usage/limits: https://docs.mistral.ai/admin/billing-usage/usage-limits
5. Mistral included usage/subscriptions: https://docs.mistral.ai/admin/billing-usage/subscriptions
6. Mistral vision API: https://docs.mistral.ai/studio/conversations/vision
7. Mistral Ministral 3 8B model: https://docs.mistral.ai/models/ministral-3-8b-25-12
8. Mistral model lifecycle/catalogue: https://docs.mistral.ai/models
9. Cloudflare Workers AI pricing: https://developers.cloudflare.com/workers-ai/platform/pricing/
10. Cloudflare Workers AI limits: https://developers.cloudflare.com/workers-ai/platform/limits/
11. Cloudflare Workers plan pricing: https://developers.cloudflare.com/workers/platform/pricing/
12. Cloudflare Llama vision endpoint: https://developers.cloudflare.com/workers-ai/models/llama-3.2-11b-vision-instruct/
13. Cloudflare Qwen vision endpoint: https://developers.cloudflare.com/workers-ai/models/qwen3.8-27b/
14. Cloudflare Mistral endpoint input schema caveat: https://developers.cloudflare.com/workers-ai/models/mistral-small-3.1-24b-instruct/sync-input.json
