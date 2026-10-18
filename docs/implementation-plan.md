# EyeSense — Implementation Plan (Source of Truth)

**Version:** 1.0
**Date:** 18 October 2026
**Supersedes:** `docs/mvp-remediation-plan.md` and `docs/fix-and-design-plan.md`, which are retained as background reference only.

> **Authority.** Where this document disagrees with any other document in the repository, including `README.md`, this document wins. The two superseded plans contain useful detail — provider economics in the first, per-defect code analysis in the second — and are cited here rather than duplicated. Neither should be used for sequencing any more.

## Verified baseline

Measured on this machine on 18 October 2026, Flutter 3.47.6 / Dart 3.13.5:

| Check | Result |
| --- | --- |
| `dart analyze lib test` | Clean |
| `flutter test --no-pub` | 24/24 pass |
| `npm run typecheck` | Clean |
| `npm test` | 10/10 pass |
| CI | `.github/workflows/ci.yml` pins Flutter 3.47.6, runs `dart analyze --fatal-infos`, Flutter tests, Worker typecheck and Worker tests |

**The clean analysis result is partly an artifact.** `app/analysis_options.yaml` contains:

```yaml
analyzer:
  errors:
    deprecated_member_use: ignore
```

This hides 19 `withOpacity` call sites deprecated since Flutter 3.27. The test suite also contains no widget tests and no semantics tests, so none of the accessibility defects in this plan are detectable by CI today. Treat the green build as "compiles and the unit tests pass", not as "correct".

---

## 1. Status of the previous plan

`docs/mvp-remediation-plan.md` declares itself "an implementation plan, not a record of completed fixes" and states that no behaviour was changed when it was written. **That header is now stale.** A substantial amount of it has since been implemented. The table below is the verified position, established by reading the code rather than by trusting either document.

Legend: **Done** — verified in code. **Partial** — mechanism exists but is incomplete or unenforced. **Not done** — absent.

### Phase 0 — Baseline — substantially done

| Item | Status | Evidence |
| --- | --- | --- |
| CI for analysis, tests, Worker typecheck and tests | Done | `.github/workflows/ci.yml` |
| Pinned Flutter version in CI | Done | `flutter-version: '3.47.6'` |
| Resolve unused `_isLoading` | Done | Used at `main.dart:182` |
| Injectable clock, transport, camera, speech, TTS seams | Done | `AgentCoordinator({visionApi, nowProvider})`; all services take optional constructor dependencies |
| Tracked `worker/.dev.vars.example` | Done | Present |
| No unexplained warnings | **Partial** | True only because deprecations are globally suppressed |

### Phase 1 — Consent, privacy, output policy — substantially done, one critical gap

| Item | Status | Evidence |
| --- | --- | --- |
| Consent checked before Describe, Ask, voice Ask | Done | `agent_coordinator.dart:149, 288, 399` |
| Consent rechecked immediately before dispatch | Done | `agent_coordinator.dart:174, 330` |
| Read Text works without consent or network | Done | `executeReadText` has no consent gate |
| `OutputPolicy` enforcement with limitation response | Done | `output_policy.dart:94-116`, English and Kiswahili |
| Spoken answer validated, not only summary | Done (app) | `answerViolates` at `output_policy.dart:91` |
| Single presentation record for display and speech | Done | `PresentationRecord`, `toSpokenText()` |
| Scene metadata cleared when OCR completes | Done | `_lastSceneResult = null` at `agent_coordinator.dart:259` |
| Factual data-flow disclosure | Done | `onboarding_screen.dart:178-184` |
| **Rotate / remove the committed default token** | **Not done** | `app_config.dart:12-15` — see [S1.1](#s11--remove-the-shared-bearer-token-from-the-binary) |
| Worker output policy covers every returned field | **Not done** | `objects[]` and `uncertainty` unscanned — see [S4.4](#s44--close-the-output-policy-field-gap) |

### Phase 2 — Cancellation, serialisation, bounds — partial

| Item | Status | Evidence |
| --- | --- | --- |
| Operation context with ID, generation, capture timestamp | Done | `AgentTask` |
| Generation invalidation across async boundaries | Done | `if (gen != _currentGeneration) return;` throughout |
| `CancelToken` propagation for Describe and Ask | Done | Passed to `SceneAgent` and both providers |
| Freshness starts at actual capture, before compression | Done | `camera_service.dart:158` stamps before `takePicture()` |
| Repeat refuses to run during an operation | Done | `agent_coordinator.dart:123-130` |
| Cancellation not spoken as a failure | Done | `_handleError` returns early for `operationCancelled` |
| **`maxCalls` enforced before a call** | **Not done** | `canExecuteMoreCalls` is declared at `agent_task.dart:30` and **never referenced**; `recordCall()` increments a counter nothing reads |
| **Remaining time budget enforced** | **Not done** | `remainingTimeBudget` and `timeout` are declared and **never referenced** |
| **Freshness window exceeds capture plus timeout** | **Not done** | Both are 15 s — see [S2.4](#s24--separate-the-freshness-and-timeout-budgets) |
| Read Text cancellable | **Partial** | `_activeCancelToken = null` at `agent_coordinator.dart:241`; only generation invalidation applies |

### Phase 3 — Speech — partial

| Item | Status | Evidence |
| --- | --- | --- |
| Native playback start/completion/cancel/error observed | Done | `tts_service.dart:24-43` |
| Long text split into bounded chunks | Done | `splitIntoChunks`, 3500 UTF-16 limit |
| Stop cancels remaining chunks | Done | `_stopRequested` |
| Explicit speech recognition outcomes | Done | `SpeechOutcome` / `SpeechOutcomeType` |
| Bounded listening and silence | Done | `listenFor: 10s`, `pauseFor: 3s` |
| Android TTS and RecognitionService queries | Done | `AndroidManifest.xml:53-64` |
| **Speech rate mapped to supported plugin values** | **Not done** | Slider 0.5–2.0 against a 0.25–1.0 clamp — see [S1.4](#s14--make-the-speech-rate-control-functional) |
| **One owner for feedback; no duplicate announcement paths** | **Not done** | Two parallel channels — see [S1.3](#s13--collapse-the-two-speech-channels) |
| **Auto-read policy honoured for errors** | **Not done** | `_handleError` speaks unconditionally |
| **TTS state changes notify the UI** | **Not done** | See [S1.5](#s15--make-stop-persistent-and-the-layout-stable) |
| Locale and voice enumeration with a sample | **Not done** | No voice preview anywhere |
| Token-aware command matching | **Partial** | Anchored regexes avoid false positives but reject natural phrasing — see [S2.5](#s25--route-voice-commands-on-natural-phrasing) |
| Question length enforced in the input UI | **Partial** | Coordinator only, not the dialog |

### Phase 4 — Camera, permissions, lifecycle — partial

| Item | Status | Evidence |
| --- | --- | --- |
| No eager camera initialisation on Home | Done | Lazy; comment at `home_screen.dart:27` |
| Denied / permanently denied / unavailable / busy distinguished | Done | `camera_service.dart:43-65, 117-123` |
| OCR capture separated from cloud image preparation | Done | `captureForOcr` vs `captureAndCompress` |
| Temporary captures deleted in `finally` | **Partial** | Coordinator yes; onboarding practice **no** |
| Application lifecycle owner | **Done but incorrect** | Reacts to `inactive`, breaking the first capture — see [S1.2](#s12--stop-the-lifecycle-handler-cancelling-the-first-operation) |
| **OCR recogniser and TTS disposed at the right boundary** | **Not done** | `OcrService.dispose()` has zero call sites |
| **Capture guidance for dark, blurry, poorly framed images** | **Not done** | See [S5.2](#s52--real-time-aiming-guidance) |

### Phase 5 — Accessible UI — partial

| Item | Status | Evidence |
| --- | --- | --- |
| Finite button minima | Done | `Size(88.0, 48.0)` in both themes |
| Minimum height with wrapping, no ellipsis | Done | `ConstrainedBox(minHeight: 72)`, `softWrap: true` |
| Start voice command first in reading order | Done | `home_screen.dart:248` |
| Live provider/URL reconfiguration | Done | `refreshVisionProvider()` |
| HTTPS required in release builds | Done | `_validateWorkerUrl` with `kReleaseMode` |
| Route-lifetime guards on async UI actions | Done | `mounted` checks throughout |
| Onboarding progress persisted separately from completion | Done | `onboardingStep` + `completedOnboarding` |
| Practice outcome shown as text, not only speech | Done | But uses `Colors.green`, which fails contrast on light |
| **Hardcoded surfaces replaced with theme colours** | **Not done** | `Color(0xFF132240)` in three files, navy constants in `main.dart` |
| **Stop in a stable non-scrolling area** | **Not done** | Conditional and inside the scroll view |
| **One actionable semantic node per control, with hints** | **Not done** | All six hints are dead code — see [S1.3](#s13--collapse-the-two-speech-channels) and [S1.6](#s16--connect-the-talkback-hints) |
| Preferences observed rather than copied | **Partial** | `app.dart` observes; `SettingsScreen` keeps local copies and re-syncs manually |

### Phase 6 — Worker — partial

Bounded body reading, Zod validation, a forbidden-fields check, route disabling and a health endpoint are **done**. Not done: durable rate/concurrency/budget enforcement, the daily-reset date bug, concurrency atomicity, output-policy field coverage, constant-time token comparison, and timeout bounds. All are in [Stage 4](#stage-4--worker-hardening).

### Phase 7 — Provider evaluation — not started, and now lower priority

The configured model `qwen/qwen3.8-27b` was **verified against Groq's current vision documentation on 18 October 2026 and is correct and current**. Both the app (`app_config.dart:22`) and the Worker (`vision.ts:15`) use it. There is no correctness reason to migrate. The cost argument in `mvp-remediation-plan.md` §10 remains valid and is retained as background, but provider migration should not block release. Re-prioritise only if measured cost becomes a constraint.

### Phase 8 — Diagnostics, docs — partial

| Item | Status | Evidence |
| --- | --- | --- |
| Allowlisted error codes, not `e.toString()` | Done | `scene_agent.dart:79` uses `e.code.name` |
| Metadata-only log schema | Done | `diagnostic_log_service.dart:52-64` |
| Logging opt-in and non-fatal | Done | Returns early when disabled; all failures swallowed |
| Export reports a truthful status | Done | Returns `ShareResultStatus.success` |
| **Clear reports a truthful status** | **Not done** | `clearLogs()` returns `void` and swallows every error, so the UI cannot know it failed |
| **Rotation never deletes the only current log** | **Not done** | `_enforceRotation` deletes a single oversized current file |
| **Widget, semantics, provider contract tests** | **Not done** | Three test files, no widget or semantics tests |
| **README corrected** | **Not done** | minSdk, secret-leakage and agent-architecture claims all wrong |
| Reading/conversation stubs documented as deferred | **Not done** | `ReadingAgent.summarise` returns `'Summary: ' + first three lines` with `clarityAssessment: 'clear'` hardcoded, and has zero call sites |

### Phase 9 — Release — mostly not started

Cleartext traffic is correctly disabled in release. Release signing still uses debug keys, `skipDependencyChecks=true` remains, the Gradle wrapper is untracked, and no device matrix or pilot has been run.

### Summary

| Phase | Approximate completion |
| --- | --- |
| 0 — Baseline | 90 % |
| 1 — Consent and output policy | 85 %, with one critical gap |
| 2 — Cancellation and bounds | 60 % |
| 3 — Speech | 55 % |
| 4 — Camera and lifecycle | 60 % |
| 5 — Accessible UI | 55 % |
| 6 — Worker | 40 % |
| 7 — Provider evaluation | 0 %, deliberately deprioritised |
| 8 — Diagnostics and docs | 40 % |
| 9 — Release | 15 % |

---

## 2. Reconciling the two plans

The two documents are broadly compatible — the defects in `fix-and-design-plan.md` map onto the phases above. Four genuine divergences had to be resolved, and this is how.

**Scope conflict on new interaction features.** `mvp-remediation-plan.md` §1 instructs: "Do not add navigation, crossing advice, background camera, Awareness, physical triggers, accounts, unlimited chat, or extra agent calls during remediation." The gesture layer, volume-key Stop, earcons and aiming guidance proposed in `fix-and-design-plan.md` Part B are new scope under that rule.

*Resolution:* the scope lock is correct and is kept. Stages 1–4 of this plan are remediation only. The experience work moves to [Stage 5](#stage-5--blind-first-experience), explicitly gated behind remediation, and aiming guidance is reclassified as a feature rather than a fix. Volume-key Stop is a "physical trigger" under the lock and is therefore deferred to Stage 5, not treated as part of the Stop fix.

**Design system.** The previous plan treats theming only as accessibility repair. It has no colour system, type scale, shape scale or brand. [Stage 6](#stage-6--design-system-and-brand) supplies these.

**Legal.** The previous plan requires "truthful privacy claims" but produces no publishable documents. [Stage 7](#stage-7--legal-and-store-compliance) owns the drafts now in `docs/legal/`.

**Provider migration.** Deprioritised, for the reason given under Phase 7 above.

---

## 3. Work programme

Stages are ordered by dependency. Each item is independently reviewable and lands with the tests that prove it. Do not begin a stage before its predecessor's exit checks pass, except where noted.

## Stage 1 — Containment and accessibility defects

Nothing else should precede this stage. Items S1.1 and S1.3–S1.6 are small, independent, and fix the claims the product is built on.

### S1.1 — Remove the shared bearer token from the binary

**Critical, security.** `app_config.dart:12-15` embeds a fallback token compiled into every APK; `CredentialService.getDemoAccessToken()` returns it whenever secure storage is empty. With the live Worker URL also embedded, anyone can extract both and consume the inference budget. This contradicts README §9.3.

- [ ] Rotate the deployed `DEMO_ACCESS_TOKEN` Worker secret. Treat the current value as public.
- [ ] Change `defaultValue` to the empty string so hosted mode fails closed.
- [ ] Return `null` from `getDemoAccessToken()` when storage is empty and let `HostedVisionProvider._getAuthHeaders()` raise its existing `upstreamAuthFailed`.
- [ ] Supply the token via `--dart-define` for internal builds only; document that such artifacts must not be distributed.
- [ ] Before any public release, replace the shared token with per-device credentials issued by the Worker.
- [ ] Remove the sample token from `worker/README.md` and `.dev.vars.example`.
- [ ] **Exit:** a release build with no define cannot reach the endpoint and reports an accessible configuration error; `rg -i "pitch-2026|demo-token-secret"` finds nothing outside the plans.

### S1.2 — Stop the lifecycle handler cancelling the first operation

**High.** `home_screen.dart:37-43` reacts to `AppLifecycleState.inactive`, which Android emits when the runtime permission dialog appears. First run therefore goes: activate Describe → permission dialog → `stop()` increments the generation and disposes the controller → the user grants permission → every generation guard aborts. The result is silence, with the status region left on "Stopped".

- [ ] React only to `paused` and `detached`. Ignore `inactive` and `hidden`.
- [ ] Add `coordinator.suspend()` that cancels network work and halts playback **without** a user-facing announcement, and call that instead of `stop()`.
- [ ] Release the camera in `suspend()`; let lazy initialisation reacquire it.
- [ ] Move first-time permission requests into an explicit labelled step so a dialog never interleaves with an active operation. The onboarding practice step already does this correctly.
- [ ] **Exit:** on a fresh install, activating Describe and granting permission completes on the first activation.

### S1.3 — Collapse the two speech channels

**High.** The app speaks through two uncoordinated engines. `_setState` announces every transition via TalkBack, then results go through `flutter_tts`. For Describe that is "Taking a picture" → "Describing" → "Speaking", with `ttsService.speak(description)` starting at the same instant as that last announcement. `_handleError` is worse: the message is announced **and** spoken, un-awaited, ignoring `autoRead`.

- [ ] Make app TTS the single channel for content and status, with a serial queue and priorities so an error or Stop pre-empts a pending description.
- [ ] Reserve `SemanticsService.announce` for short non-content events, never within ~300 ms of starting TTS.
- [ ] Remove the unconditional `speak()` from `_handleError`; honour `autoRead` and always leave the message as accessible on-screen text.
- [ ] Set `OperationState.speaking` only when speech actually begins. All three workflows currently set it before checking `autoRead`, so with auto-read off the status claims "Speaking" in silence.
- [ ] Use `SpeechFeedbackCoordinator.speakResult`, which already implements the correct branch and is currently never called.
- [ ] Give `OperationState.error` a dismissal path.
- [ ] **Exit:** with a screen reader active, no two utterances overlap across capture, processing, result, error and Stop.

### S1.4 — Make the speech-rate control functional

**High.** `settings_screen.dart:83-92` offers `min: 0.5, max: 2.0, divisions: 6`; `tts_service.dart:54` clamps to `0.25–1.0`. Four of seven positions collapse to 1.0 while the label reads up to "2.0x". Faster-than-default speech is the preference screen-reader users most commonly rely on.

- [ ] Decide one user-facing scale and map it explicitly to the platform range. `flutter_tts` accepts 0.0–1.0 on Android, so a 0.5×–2.0× product scale needs a mapping function, not a clamp.
- [ ] Migrate persisted values if their meaning changes.
- [ ] Add `label:` and a `semanticFormatterCallback` so the value is announced while dragging.
- [ ] Add a "Preview voice" action; a rate cannot be evaluated from a numeric label without sight.
- [ ] **Exit:** a test asserts every division yields a distinct platform rate, confirmed audibly on a device.

### S1.5 — Make Stop persistent and the layout stable

**High.** The comment at `home_screen.dart:236` says "Persistent Operation Control Area" but the control is conditional, so all five buttons shift down roughly 88 px exactly when the user wants Stop. Separately the camera preview appears permanently after the first capture, displacing everything a further ~156 px. Blind touch users rely on remembered positions.

The panel's "Stop Audio" control can also never appear: `_setState(OperationState.speaking)` notifies **before** `await ttsService.speak(...)`, and `HomeScreen` observes only the coordinator, so `isSpeaking` is still false at paint time.

- [ ] Reserve Stop's space at all times, rendered disabled when idle, so no sibling moves.
- [ ] Place Stop in a fixed non-scrolling region reachable regardless of result length.
- [ ] Remove the camera preview from the default layout; see [S6.7](#s67--screens). If retained, reserve its space from first paint.
- [ ] Fix propagation with `Listenable.merge([coordinator, coordinator.ttsService])`.
- [ ] Remove one of the two Repeat controls.
- [ ] **Exit:** a widget test asserts every control's vertical offset is identical across idle, capturing, processing and speaking.

### S1.6 — Connect the TalkBack hints

**High.** `accessible_action_button.dart` declares `semanticHint` at line 11, assigns it at line 21, and never references it. There is no `Semantics` wrapper in `build()`, so all six home-screen hints are discarded. A second defect: when `isLoading` is true the child is replaced wholesale by a spinner (lines 68-77), removing `Text(label)` and setting `onPressed: null`, so the control the user just activated becomes an unlabelled disabled node.

- [ ] Wrap in one actionable node and exclude the inner tree:

```dart
return Semantics(
  button: true,
  enabled: onPressed != null && !isLoading,
  label: label,
  hint: semanticHint,
  child: ExcludeSemantics(child: ConstrainedBox(/* existing */)),
);
```

- [ ] Keep the label visible during loading; place the spinner beside the text and convey busy state through semantics.
- [ ] Resolve the doubled Settings announcement — `home_screen.dart:141-162` sets a `Semantics` label over an `IconButton` that also has a tooltip.
- [ ] Add `liveRegion: true` to `OperationStatusWidget`'s `Semantics`.
- [ ] **Exit:** semantics tests assert label, hint and enabled state on all six controls.

### Stage 1 exit gate

- [ ] Token rotated and absent from the binary.
- [ ] Semantics and widget test harness exists and runs in CI.
- [ ] A screen-reader user can complete Describe, Read Text and Ask with no overlapping speech and no moving controls.

## Stage 2 — Core flow correctness

### S2.1 — Enforce the call and time budgets that already exist

`AgentTask` declares `maxCalls`, `timeout`, `canExecuteMoreCalls` and `remainingTimeBudget`. **None of the three accessors is referenced anywhere.** `recordCall()` increments a counter nothing reads. The bounds are decorative.

- [ ] Check `canExecuteMoreCalls` before dispatching, and fail with a clear error rather than silently exceeding the budget.
- [ ] Consult `remainingTimeBudget` before dispatch and pass it as the effective request deadline.
- [ ] Use elapsed monotonic time, not wall-clock differences, and keep the injected clock for tests.
- [ ] Prefer one vision call per task; allow at most one bounded retry, and only with justification.

### S2.2 — Show progress on the control the user activated

`executeAskQuestion` and `executeReadText` both pass through `OperationState.capturing`, but only Describe watches for it, so asking a question makes Describe spin.

- [ ] Track the active task kind on the coordinator, set at workflow start and cleared in `finally`.
- [ ] Drive each control's `isLoading` from the active task, keeping the status region on the coarse state.

### S2.3 — Make Read Text cancellable

`executeReadText` sets `_activeCancelToken = null`, and ML Kit's `processImage` cannot be aborted, so Stop only invalidates the generation while work continues.

- [ ] Document the limit honestly, and ensure Stop is immediate from the user's perspective: halt playback, return to idle, and discard the result when it arrives.
- [ ] Do not claim the underlying recognition was cancelled when it was not.

### S2.4 — Separate the freshness and timeout budgets

`clientTimeout` and `sceneFreshnessLimit` are both 15 s, but the capture timestamp precedes compression and the request. Capture, plus decode/resize/encode of a 1280 px image, plus up to 15 s of network, routinely exceeds the window, so the user waits the full time and is then told the observation expired.

- [ ] Measure capture-to-result p50/p95 on a mid-range device over a throttled connection **before** choosing constants.
- [ ] Set the freshness limit to exceed capture plus preparation plus request timeout with headroom. A 10 s client timeout against a 25 s freshness limit is a reasonable starting pair.
- [ ] Evaluate freshness at the start of delivery, never mid-utterance.
- [ ] When a result genuinely is stale, say what to do next.

### S2.5 — Route voice commands on natural phrasing

`agent_coordinator.dart:459-462` matches whole strings only, so "describe the scene" or "read this label" falls through to `executeAskQuestion` and an offline read request becomes a consent error. Meanwhile `ConversationAgent.resolveIntent` — written for exactly this job, in both languages — has zero call sites, as does `readingAgent`.

- [ ] Replace anchored regexes with token-aware matching: normalise, strip punctuation and filler, match approved phrase sets on word boundaries.
- [ ] Keep the existing protection against false positives; test "stop sign", "bread" and "textile" explicitly.
- [ ] Resolve read-text intent **before** the cloud fallback.
- [ ] Route through `ConversationAgent.resolveIntent` so there is one implementation, or delete the agent and correct README §2. Do not keep both.
- [ ] Use its `clarify` branch for ambiguous input instead of defaulting to a cloud call.
- [ ] **Exit:** a table of 30+ natural utterances per language routes correctly, and no non-command utterance reaches a cloud call without consent.

### S2.6 — Release resources and delete every temporary capture

- [ ] Override `AgentCoordinator.dispose()` to close the OCR recogniser, release TTS, cancel recognition, dispose the camera and cancel any active token. `OcrService.dispose()` currently has zero call sites.
- [ ] Delete the onboarding practice capture in a `finally` block. It is the only capture path that leaks a file, and it contradicts README §9.6.
- [ ] Add a narrowly scoped startup sweep for captures orphaned by a crash.

### S2.7 — Make diagnostics status truthful

- [ ] Change `clearLogs()` to return a success status instead of `void`, and surface failure in the UI. It currently swallows every error, so the screen can report a deletion that did not happen.
- [ ] Fix `_enforceRotation` so it never deletes the only current log file when that file alone exceeds the ceiling.

### S2.8 — Fix the AppBar at large text scales

`home_screen.dart:123-138` places a two-line column with a 26 px title in a default 56 px toolbar, which overflows at the 200 % scale README §4 claims.

- [ ] Move the tagline out of the AppBar; it is decorative and adds a traversal stop before the primary actions.
- [ ] Set an explicit `toolbarHeight`, or let the title wrap.
- [ ] Add layout tests at 320 logical px and `textScaler` 2.0 for every screen.

## Stage 3 — Honest documentation

Small, and it removes the risk of shipping false claims.

- [ ] Correct README §5: minSdk is effectively **24**, set by Flutter's default and `flutter_tts`, not 21. Update the "greater than 99 % of devices" claim accordingly.
- [ ] Correct README §9.3. The current token arrangement is not secret; restate it accurately or land [S1.1](#s11--remove-the-shared-bearer-token-from-the-binary) first.
- [ ] Correct README §2. `ConversationAgent.resolveIntent` and `readingAgent` have no call sites; `setMode`, `AppMode`, `_currentMode` and `awarenessEnabled` are read by no UI. Describe what executes, or wire them up.
- [ ] Correct README §4. The hint, duplicate-announcement and 200 %-scale claims are currently false; land Stage 1 first or soften them.
- [ ] Mark `ReadingAgent.summarise` as a deferred stub. It returns the first three lines prefixed with "Summary:" and hardcodes `clarityAssessment: 'clear'`; it must not be described as summarisation.
- [ ] Correct `worker/README.md` §5, which lists `/v1/reading` and `/v1/conversation` as active while the code returns `ROUTE_DISABLED`.
- [ ] Add a header to both superseded plans pointing here.

## Stage 4 — Worker hardening

This stage gates any widening of hosted access. Full analysis in `fix-and-design-plan.md` §E1.

### S4.1 — Replace in-memory limits with durable state

`budgetState` is a module-scope object. Cloudflare runs many isolates per location, each with its own counters, and cold starts reset them. The advertised 30/minute, 10 concurrent and 1,000/day are **not enforced**.

- [ ] Move counters to Durable Objects or the Rate Limiting API.
- [ ] Decide and document whether the daily budget is global or per-client; it is currently global while the per-minute limit is per-IP.

### S4.2 — Fix the daily reset

- [ ] Compare a full `YYYY-MM-DD` UTC key. The code compares `new Date().getUTCDate()` — day of month — so a budget exhausted on 15 January and left idle is still exhausted on 15 February.
- [ ] Return a real `Retry-After` computed from time to next UTC midnight, not a fixed 3600.

### S4.3 — Fix the concurrency race

- [ ] Reserve the slot atomically. Check and increment are currently separate, so two requests can both observe 9 and both proceed.

### S4.4 — Close the output-policy field gap

- [ ] Scan every returned string, including each entry of `objects[]` and `uncertainty`. Prohibited guidance placed there currently reaches the client and is spoken.
- [ ] Replace only the fields that violated. A violation in `answer` currently overwrites `concernDescription`, discarding legitimate content.

### S4.5 — Remaining Worker items

- [ ] Constant-time token comparison instead of `===`.
- [ ] Charge the budget after validation, and apply a lightweight pre-parse throttle so authenticated malformed requests cannot bypass accounting.
- [ ] Bound `UPSTREAM_TIMEOUT_MS`; an invalid value yields `NaN`, which `setTimeout` treats as 0.
- [ ] Cap base64 image length in the Zod schema, not only via the 1.5 MiB body limit.
- [ ] Stop returning raw Zod messages to clients.
- [ ] Reduce `/health` disclosure; `ready: false` publicly confirms a misconfigured deployment.
- [ ] Reject a non-numeric `Content-Length`.
- [ ] Add Worker tests for the isolate bypass, concurrency race, daily reset and output-policy gaps.

### Stage 4 exit gate

- [ ] Concurrent load across locations cannot exceed the configured budget or concurrency.
- [ ] Adversarial schema-valid responses are blocked in every returned field.
- [ ] Disabled routes cannot invoke upstream inference.

---

**Stages 5, 6 and 7 may proceed in parallel with each other once Stage 4's gate passes. Stage 6 has no dependency on Stage 5.**

## Stage 5 — Blind-first experience

New scope, deliberately gated behind remediation by the scope lock discussed in [§2](#2-reconciling-the-two-plans). Background in `fix-and-design-plan.md` Part B.

The problem this stage solves: the app currently requires a blind user to locate a specific on-screen target by touch exploration for every action, and it captures images with no feedback about what the camera is actually pointed at.

### S5.1 — Profiles before gestures

- [ ] Add a first-run choice: "I use a screen reader" / "I have some usable vision" / "I am sighted and assisting someone". Persist it; make it changeable in Settings.
- [ ] Seed the default from `MediaQuery.accessibleNavigationOf(context)`, but let the explicit choice override.
- [ ] Screen-reader profile: gestures on, camera preview off, auto-read on, earcons on, result region first in traversal order.
- [ ] Low-vision profile: preview on with reserved space, high-contrast theme, large type defaults.
- [ ] The profile sets defaults only. It must never withhold functionality.

### S5.2 — Real-time aiming guidance

The central functional gap. The user cannot know whether the camera is aimed at the subject, too close, too far, tilted, or obstructed. The app captures and reports failure afterwards with "Try a clearer view or better lighting" — advice that cannot be acted on without sight. Read Text, the offline flagship used on a medicine bottle, has no quality signal at all.

- [ ] Stream low-resolution preview frames during Read Text; estimate text presence, coverage and stability on-device.
- [ ] Speak short throttled corrections: "move closer", "tilt up", "hold steady", "whole page not visible".
- [ ] Auto-capture when stable and adequately framed, with an audible shutter. Keep manual capture.
- [ ] Add measured luminance and sharpness checks, and distinguish measured signals from model opinions in what is spoken.
- [ ] Detect a likely obstructed lens (uniformly dark or low-variance frame) and say so specifically.
- [ ] **Never** infer proximity, distance or collision risk. Framing guidance concerns the image, not the physical world, and must not drift into territory `OutputPolicy` prohibits.
- [ ] **Exit:** a blind tester reads a medicine label and a utility bill unaided, with success rate recorded before and after.

### S5.3 — Gesture layer

- [ ] Implement a full-screen actionable surface exposing each action as a `CustomSemanticsAction` — the supported route, since screen readers consume raw gestures. The app uses `CustomSemanticsAction` nowhere today.

| Gesture | Action |
| --- | --- |
| Double-tap anywhere | Run the current mode |
| Two-finger tap | Stop immediately |
| Swipe left / right | Cycle Describe → Read Text → Ask, announcing the new mode |
| Long press | Start voice command |
| Three-finger tap | Repeat last result |

- [ ] Keep the explicit labelled button list as a secondary path. Discoverability and gesture memory serve different users, and switch-access hardware needs discrete targets.
- [ ] Persist the selected mode; make it audible on demand, not only on change.
- [ ] Bind Stop to the hardware volume keys. This is the "physical trigger" the scope lock deferred, and it belongs here.

### S5.4 — Audio feedback

`HapticService` offers only `lightImpact()` and a double `mediumImpact()`. There are no audio cues anywhere.

- [ ] Add a distinct earcon set: shutter, processing loop (quiet and looping, so silence is never ambiguous), success, error, potential concern.
- [ ] Keep each under ~300 ms except the loop; duck under speech rather than interleaving.
- [ ] Make earcons separately disableable from haptics.
- [ ] Add an unmistakable "listening started" cue. `playReadinessCue()` currently only vibrates, so the user must infer that recording began.
- [ ] Keep haptics as redundant confirmation for users with hearing loss.

### S5.5 — Output order, focus and progressive disclosure

- [ ] Move the result region directly after status, ahead of the actions. It is currently last in traversal order.
- [ ] Move accessibility focus to the result when it arrives. Nothing in the app manages focus today; the only `autofocus` is on the Ask dialog's text field.
- [ ] Speak a one-sentence summary first, with an explicit "more detail" action, rather than one long utterance.
- [ ] Add sentence-level navigation of long results, which matters most for OCR output running to thousands of characters.

### S5.6 — Make the Ask flow voice-first

`_showAskDialog` sets `autofocus: true`, raising the keyboard and placing the user in typing mode, while voice is the second of three actions below the field. Submit silently does nothing when the field is empty.

- [ ] Activating "Ask a question" should begin listening directly, with typing as an explicit alternative.
- [ ] Remove `autofocus`; present voice first in both visual and traversal order.
- [ ] Give empty submit a spoken rejection instead of a silent no-op.
- [ ] Enforce the 300-character limit in the input affordance with a live announced count.
- [ ] Prefer a dedicated route over a dialog. This is a primary flow, not a confirmation.

### S5.7 — Audible identity and onboarding

- [ ] On launch, play a brand earcon and speak a one-line orientation: ready state, current mode, how to act. Skippable and suppressible after the first few sessions.
- [ ] Announce initialisation failures audibly. `main.dart`'s error state is visual only, so bootstrap failure is silent.
- [ ] Offer per-step narration in onboarding with a "read this aloud" control. Six screens of dense prose, including a long privacy disclosure, currently rely entirely on the user swiping through each one.

---

## Stage 6 — Design system and brand

The objective is a product that reads as considered and professional. Two things work against that today: a `ColorScheme` that specifies only 7 of roughly 30 Material 3 roles, so much of the UI renders in Material's stock baseline palette; and no spacing, type, shape or icon scale, so sizes are chosen ad hoc at each call site.

### S6.0 — Honest diagnosis

1. **Saturated cyan-teal on deep navy, with rounded cards and soft drop shadows, is the default palette of generated app mock-ups.** The colours are individually fine; the combination signals "template" before any content is read.
2. **No scale discipline.** Radii in use: 8, 10, 14, 16, 18, 20, 24. Icon sizes: 14, 18, 20, 22, 24, 26, 28, 30, 52, 64. Spacing: 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 36, 40. Font sizes: 11, 14, 16, 18, 20, 22, 24, 26, 28, 30. Nothing derives from a system, so nothing aligns optically.
3. **Outlines do the work of separation.** Borders at 1, 1.5 and 2 px with 30–50 % opacity appear on nearly every container. Mature interfaces separate with surface tone and spacing and reserve outlines for state.
4. **Five identical stacked controls** differing only by a 30 %-opacity border read as a debug menu, not a hierarchy.
5. **Decorative chrome instead of a brand.** The splash hand-draws a circle around `Icons.visibility`; `assets/icon/app_icon.png` is registered in `pubspec.yaml` and referenced nowhere in Dart; `flutter_launcher_icons` is not a dependency; `launch_background.xml` references `@mipmap/launch_image` only inside comments.

### S6.1 — Colour system

**Direction: high-visibility amber on true ink.** Amber-on-dark is the established colour language of accessibility and high-visibility equipment, which makes it distinctive in this category and defensible in a pitch. It holds perceived contrast better than cyan under the common colour vision deficiencies and under the yellowed lens tint typical of cataract. True ink rather than saturated navy reads as more serious and gives deeper OLED blacks, which measurably reduces battery draw in a camera app.

#### Core tokens

| Token | Dark | Light | Contrast on its background |
| --- | --- | --- | --- |
| `background` | `#0A0C10` | `#FBFBF9` | — |
| `surface` | `#14171D` | `#FFFFFF` | — |
| `surfaceRaised` | `#1C2029` | `#F2F3F0` | — |
| `surfaceSunken` | `#05070A` | `#EDEEEA` | — |
| `accent` | `#FFC247` | `#8A5A00` | 11.6:1 / 5.2:1 |
| `onAccent` | `#1A1200` | `#FFFFFF` | 11.6:1 / 5.2:1 |
| `textPrimary` | `#F7F8F8` | `#14171D` | 17.4:1 / 15.8:1 |
| `textSecondary` | `#B6BCC6` | `#4A525E` | 8.9:1 / 7.6:1 |
| `textTertiary` | `#878E99` | `#6B737F` | 4.9:1 / 4.6:1 |
| `border` | `#2A2F39` | `#D8DAD4` | — |
| `borderStrong` | `#3D434F` | `#B4B7B0` | 3.1:1 / 3.2:1 |
| `focusRing` | `#FFD86B` | `#8A5A00` | ≥ 3:1 against both |
| `error` | `#FF8A7A` | `#A8231A` | 7.8:1 / 5.9:1 |
| `concern` | `#FFB020` | `#7A4A00` | 9.8:1 / 7.1:1 |
| `success` | `#5FD39A` | `#0F6B45` | 9.1:1 / 5.0:1 |

Ratios are design targets. **Verify every pairing with a contrast tool against the implemented theme** and record the results; do not trust this table.

#### Third theme: maximum contrast

"Dark Navy" is not maximum contrast, and many low-vision users specifically need pure black with a single saturated accent.

- [ ] Add a fourth option alongside System / Dark / Light: pure `#000000` background, `#FFFFFF` text, `#FFD400` accent, `#FFFFFF` borders at full opacity, no shadows, no translucency.

#### Steps

- [ ] Generate the scheme from a seed so **all** roles harmonise, then override only what must be exact:

```dart
static final ColorScheme _dark = ColorScheme.fromSeed(
  seedColor: EyeSenseColors.accent,
  brightness: Brightness.dark,
  contrastLevel: 0.5,
).copyWith(
  surface: EyeSenseColors.surface,
  onSurface: EyeSenseColors.textPrimary,
);
```

- [ ] Add a `ThemeExtension` for the roles Material has no slot for: `concern`, `success`, `focusRing`, `surfaceRaised`, `surfaceSunken`.
- [ ] Remove every hardcoded hex from widget code: `Color(0xFF132240)` in `operation_status.dart:29`, `response_panel.dart:49` and `diagnostics_screen.dart:101`; the navy constants throughout `main.dart`; and `Colors.green` at `onboarding_screen.dart:223`. That last one is a genuine failure — Material green on `#F7F9FC` is roughly 2.8:1, below the 4.5:1 threshold, in a product whose premise is accessibility.
- [ ] Delete the nine dead aliases at `app_theme.dart:33-41`, referenced nowhere outside their own declarations.

### S6.2 — Typography

The app currently uses default Roboto with no declared family and defines only 6 of 15 Material 3 text styles, so `bodySmall` (the AppBar tagline), `labelMedium` and `titleSmall` (both used in `response_panel.dart`) fall back to defaults.

**Family: Atkinson Hyperlegible.** Designed by the Braille Institute specifically to maximise character disambiguation for low-vision readers. It is a real usability improvement and a specific, defensible design decision rather than a default. Licensed under the SIL Open Font License, so it can be bundled.

- [ ] Bundle `AtkinsonHyperlegible-Regular.ttf` and `-Bold.ttf` under `app/assets/fonts/`; declare them in `pubspec.yaml`. Bundle rather than fetch so rendering is identical offline.
- [ ] Use two weights only — Regular 400 and Bold 700. More weights read as decorative.
- [ ] Keep the system monospace for the diagnostics log view, where character alignment matters.

#### Type scale

Ratio 1.2 from a 16 px base. All sizes scale with `TextScaler`; none are pinned.

| Style | Size | Weight | Line height | Tracking | Use |
| --- | --- | --- | --- | --- | --- |
| `displaySmall` | 33 | 700 | 1.2 | −0.5 | Splash wordmark |
| `headlineMedium` | 28 | 700 | 1.25 | −0.25 | Screen titles |
| `headlineSmall` | 23 | 700 | 1.3 | 0 | Section titles |
| `titleLarge` | 20 | 700 | 1.35 | 0 | Card titles, primary button labels |
| `titleMedium` | 18 | 700 | 1.4 | 0 | List titles |
| `bodyLarge` | 18 | 400 | 1.55 | 0 | **Result text — the most important style in the app** |
| `bodyMedium` | 16 | 400 | 1.5 | 0 | Body, descriptions |
| `bodySmall` | 14 | 400 | 1.45 | 0 | Captions, helper text |
| `labelLarge` | 16 | 700 | 1.2 | 0.1 | Secondary button labels |
| `labelMedium` | 14 | 700 | 1.2 | 0.25 | Chips, badges |

- [ ] Define all 15 styles; derive from the ratio rather than choosing per call site.
- [ ] Set `height` explicitly on every style. Line height drives perceived quality more than family choice, and the current theme sets it on only two.
- [ ] Never go below 14 px for any user-facing text. `operation_status.dart` currently uses 11 px for the preview badge.

### S6.3 — Shape and "boxes"

Three radii only, replacing the seven in use:

| Token | Radius | Applies to |
| --- | --- | --- |
| `radiusSmall` | 8 | Inputs, chips, badges, log rows |
| `radiusMedium` | 16 | Buttons, cards, result panel, status region |
| `radiusLarge` | 28 | Dialogs, bottom sheets, splash mark container |

**Container recipe.** Replace the current outline-everywhere approach:

- Separate surfaces by **tone first** — `surface` on `background`, `surfaceRaised` on `surface`. No border needed.
- Use a **1 px `border` outline only** where tone alone is insufficient (adjacent same-tone surfaces).
- Use **`borderStrong` at 2 px only to signal state** — active operation, concern, error, focus.
- **No drop shadows in dark mode.** They are invisible on near-black and only muddy the surface. Use tone. In light mode use one subtle elevation token at most: `0 1px 2px rgba(20,23,29,0.06)`.
- Border radius is never mixed within a single component.

- [ ] Remove the `boxShadow` blocks at `home_screen.dart:188-194` and `response_panel.dart:57-63`.
- [ ] Define `elevation: 0` on cards in dark mode and rely on `surfaceRaised`.

### S6.4 — Spacing and sizing

- [ ] Adopt a 4-point scale and use only its steps: **4, 8, 12, 16, 24, 32, 48**. Replace the twelve ad-hoc values currently in use.
- [ ] Three icon sizes only: **20** inline, **24** standard, **32** primary action. Replace the ten in use.
- [ ] Keep the existing minimums, which are correct: 48 dp touch target, 72 dp primary action height as a **minimum** not a fixed box.
- [ ] Standard screen padding 16; section gap 24; related-element gap 12; inside-component gap 8.

### S6.5 — Focus and state

`darkFocusIndicator` and `lightFocusIndicator` exist as tokens at `app_theme.dart:17` and `:28` and are used nowhere. For a product targeting switch access and external keyboards, a visible focus ring is essential.

- [ ] Implement a 3 px `focusRing` with a 2 px offset, meeting ≥ 3:1 against both the control and its background, applied through `WidgetStateProperty` so it is identical across every control type.
- [ ] Define all five states for every interactive component — default, hover, focus, pressed, disabled — rather than relying on the default overlay.
- [ ] Keep disabled text at ≥ 3:1. Disabled state carries meaning here: Repeat is disabled until a result exists.

### S6.6 — Component themes

Currently themed: `appBar`, `card`, `dialog`, `inputDecoration`, `textTheme`, `elevatedButton`. Everything else inherits Material defaults, which is why switches, sliders, radios, dividers, dropdown menus and snack bars render off-palette.

- [ ] Add `switchTheme`, `sliderTheme`, `radioTheme`, `checkboxTheme`, `dividerTheme`, `listTileTheme`, `outlinedButtonTheme`, `textButtonTheme`, `filledButtonTheme`, `iconButtonTheme`, `segmentedButtonTheme`, `snackBarTheme`, `progressIndicatorTheme`, `tooltipTheme`, `bottomSheetTheme`, `dropdownMenuTheme`.
- [ ] Migrate from `ElevatedButton` to the Material 3 button set so hierarchy is expressed by component rather than border opacity: `FilledButton` primary, `FilledButton.tonal` secondary, `OutlinedButton` tertiary.

### S6.7 — Screens

**Home**

- [ ] Establish hierarchy: one prominent primary action, with secondary actions visually subordinate. Keep the single-column order and the 72 dp minimum, which are correct for traversal; express difference through component type and surface tone.
- [ ] Order content: status → result → actions → persistent Stop. See [S5.5](#s55--output-order-focus-and-progressive-disclosure).
- [ ] Remove the camera preview from the default layout, per [S5.1](#s51--profiles-before-gestures).

**Settings and AI Connection**

- [ ] Replace the flat `ListView` of zero-padding `ListTile`s, hand-written `Text` headers and `Divider(height: 32)` spacers with grouped card sections and one consistent section-header style. This is the cheapest single change that makes the app look shipped.
- [ ] Move the Worker URL and demo token behind an "Advanced" disclosure. They are developer configuration.
- [ ] Add the Legal section from [Stage 7](#stage-7--legal-and-store-compliance).

### S6.8 — Motion

- [ ] Add a `pageTransitionsTheme` with shared-axis transitions between Home, Settings and sub-screens.
- [ ] Animate the result region with an `AnimatedSwitcher`, under 200 ms so it never delays speech.
- [ ] Honour `MediaQuery.disableAnimationsOf(context)` and skip all non-essential motion.
- [ ] Never gate an announcement or state change on an animation completing.

### S6.9 — Brand: logo, app icon, splash

Source files are provided in `app/assets/brand/`. All are SVG and editable.

#### Concept

A literal eyeball was rejected deliberately: it is the most clichéd mark in the category, and an eye icon as the identity of a product for blind users is tone-deaf. The mark instead expresses what the product actually does — **light in, speech out**.

It is a solid dot (the lens) with three arcs of increasing radius opening to the right (sound radiating). It reads as an aperture and as an audio emanation simultaneously, works in a single colour, and stays legible at 24 px because it is three strokes and a disc.

#### Files

| File | Contents | Use |
| --- | --- | --- |
| `logo-horizontal.svg` | Mark + "EyeSense" wordmark, left-aligned | Splash, headers, documentation, pitch deck |
| `logo-stacked.svg` | Mark above wordmark, centred | Square placements, social |
| `logo-mark.svg` | Mark only, no text | App icon source, favicon, watermark |
| `logo-wordmark.svg` | "EyeSense" only | Inline text contexts |
| `icon-adaptive-foreground.svg` | Mark inside the Android adaptive safe zone | Android adaptive icon foreground |
| `icon-monochrome.svg` | Single-path mark | Android 13+ themed icons |

#### Wordmark specification

- Set in **Atkinson Hyperlegible Bold**, matching the app's own typeface so the identity and the interface are the same voice.
- **"Eye" in `textPrimary`, "Sense" in `accent`.** The split reinforces the name's construction and gives the accent a job in the mark. A single-colour variant is provided for one-colour reproduction.
- Tracking −0.5 % — slightly tight, never cramped.
- Cap height aligned optically to the mark's outer arc, not mathematically to its bounding box.
- Clear space on all sides equal to the mark's dot diameter. Never place the lockup closer than that to any other element.
- **Minimum sizes:** horizontal lockup 120 px wide; stacked 80 px; mark alone 24 px.
- Never stretch, re-colour outside the defined pairs, add effects, outline, or re-set the wordmark in another typeface.

#### App icon

- [x] ~~Add `flutter_launcher_icons`~~ — not needed. The layers are hand-authored
      `VectorDrawable`s, which stay sharp at every density and avoid a build-time
      codegen dependency for three static shapes.
- [x] **Adaptive icon:** `res/mipmap-anydpi-v26/ic_launcher.xml`, with
      `drawable/ic_launcher_foreground.xml` (mark in `accent`, inside the central
      66 dp safe zone) over `@color/icon_background` (`#0A0C10`). API 26+
      resolves to this; older releases fall back to the raster mipmaps, so the
      manifest reference is unchanged.
- [x] **Monochrome layer:** `drawable/ic_launcher_monochrome.xml`, referenced by
      the `<monochrome>` tag. Identical geometry; the platform tints it from the
      wallpaper palette, so only its alpha matters.
- [x] **Play listing icon:** `store/play-icon-512.png`, 512 × 512, 32-bit, fully
      opaque, square. Verified `channels=4, alpha=true` — `sharp`'s `.flatten()`
      alone emits 24-bit, which Play rejects, so `.ensureAlpha(1)` is required.
- [x] Icon is **mark only, never the wordmark**.
- [x] Replaced the generic launcher mipmaps. `tools/brand/generate.mjs` renders
      `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` at 48/72/96/144/192 from the
      same geometry as the vectors, so the two cannot drift. The rasters carry an
      ink plate and rounded corners because nothing masks them before API 26;
      the adaptive layers must not, because the platform masks those itself.

Verified with `aapt2 compile --dir res` followed by `aapt2 link`, then
`aapt2 dump resources`, which confirms `mipmap/ic_launcher` resolves to
`(anydpi-v26) ic_launcher.xml` with the density PNGs retained as the fallback.

#### Splash screen

Two distinct surfaces that currently disagree.

**1. Android 12+ system splash** (`windowSplashScreenAnimatedIcon`). Shown before Flutter starts and cannot be changed at runtime.

- [x] Background: solid `#0A0C10` via `@color/splash_background`.
- [x] Icon: `drawable/splash_mark.xml`, artwork within the central ~52 % of its
      canvas so the system's circular mask cannot clip it.
- [x] No wordmark here.
- [x] Defined in `values-v31/styles.xml` (`windowSplashScreenBackground`,
      `windowSplashScreenAnimatedIcon`) with `drawable/launch_background.xml` as
      the pre-31 layer list.
- [x] **Splash mark re-aligned to the brand mark.** It had drifted: amber
      `#FFD400` instead of `#FFC247`, arc radii 12/20/28 instead of the scaled
      brand 11.76/18.48/25.2, and a differently sized dot. It now shares exact
      geometry with `ic_launcher_foreground.xml`, so the splash and the launcher
      icon are the same mark.

**2. Flutter bootstrap screen** (`main.dart`), shown while services initialise.

- [ ] Replace the hand-drawn `Container` circle around `Icons.visibility` with the horizontal lockup.
- [ ] Composition: lockup centred, tagline "Your world, described." in `bodyMedium` / `textSecondary` 24 below it, progress indicator 48 below that.
- [ ] **Read the persisted theme before first paint.** `main.dart` currently hardcodes `AppTheme.darkTheme` and navy colours regardless of the saved setting, so light-mode users see a flash of the wrong theme on every cold start.
- [ ] Announce the ready state and any initialisation failure audibly; this screen is currently silent. See [S5.7](#s57--audible-identity-and-onboarding).
- [ ] Keep it under one frame of visible work where possible; it should not become a branding opportunity at the cost of time to first action.

#### Steps

- [ ] Review the provided SVGs, adjust, and commit the chosen variants.
- [x] Export PNG raster sets for contexts that cannot consume SVG — `tools/brand/`
      (`npm install && npm run build`), checked in so the build needs no Node.
- [x] Add the font and brand directories to `pubspec.yaml` assets — `assets/brand/`,
      `assets/earcons/`, `assets/legal/` and the two Atkinson Hyperlegible faces
      are all registered, and `AppTheme.fontFamily` consumes the family.
- [x] Removed the unused `assets/icon/app_icon.png` and its `pubspec.yaml` entry.
      It was referenced from no Dart code and shipped in every APK.

---

## Stage 7 — Legal and store compliance

Both documents are now at **version 1.0** and live at
`app/assets/legal/privacy-policy.md` and `app/assets/legal/terms-of-service.md`.
That is the single source of truth: `pubspec.yaml` bundles them as app assets,
`LegalDocumentScreen` renders them in Settings → Legal, and `site/build.mjs`
publishes the same files to <https://eyesense.dpdns.org>, so the in-app text and
the published page cannot drift. The former copies under `docs/legal/` are now
pointers.

**Neither has been reviewed by a qualified lawyer.** What remains open, and the
interim drafting choices made so the pages could be published without inventing
facts, are tracked in [`docs/legal/OUTSTANDING.md`](./legal/OUTSTANDING.md).

### S7.1 — Verify every factual claim

A privacy policy that overstates protection is a worse liability than none.

- [ ] Read Text performs no network I/O — verify with networking disabled.
- [ ] Captured images are deleted after **every** outcome. Currently false for the onboarding practice capture; [S2.6](#s26--release-resources-and-delete-every-temporary-capture) must land first.
- [ ] Diagnostics contain no image, audio, question or OCR text — verify an export from every error fixture.
- [ ] No analytics, advertising, attribution or crash-reporting SDK is linked — verify against the merged release dependency tree.
- [x] Confirm what Cloudflare and Groq retain under current terms; cite version and review date. Reviewed 18 October 2026: Cloudflare, Inc. (effective 4 November 2025) and **Groq LLC** — the earlier draft wrongly said "Groq, Inc." Both linked from §5.
- [x] **Disclose the IP address.** `worker/src/index.ts` keys its rate limiter on the raw `CF-Connecting-IP` header and persists it in the budget Durable Object; the earlier draft described this only as "minimal technical information about request volumes". Policy §3.7, §6 and §7 now state it plainly, including that `rollDay()` clears the per-client map at 00:00 UTC so the counter is not retained beyond the day.
- [ ] Confirm whether Android speech recognition on target devices processes audio on-device or server-side. This varies by OEM and language; the honest disclosure is that it is governed by the device's own speech provider.

### S7.2 — Publisher and jurisdiction

- [~] Publishing entity named as **DevRay**, inferred from the
      `com.devray.eyesense` application ID and the `devray.qzz.io` contact
      domain. No legal form or registered address — several regimes require a
      controller's physical address in a privacy notice. See `OUTSTANDING.md`.
- [ ] Confirm governing jurisdiction. Given Kiswahili support and the MUA context, Tanzania's Personal Data Protection Act 2022 is the likely primary regime; Kenya's Data Protection Act 2019 applies if users are there. Until this is fixed, terms §13 falls back to the law of the user's own country of residence, and the policy names no supervisory authority or transfer mechanism, because naming one would have been a fabrication.
- [x] Every `[PLACEHOLDER]` resolved. Where a value was genuinely unknowable the
      clause was **rewritten to be accurate without it** rather than filled with
      a guess — the children's age threshold, supervisory authority and transfer
      mechanism are all phrased generically for this reason.
- [x] Published at stable public URLs: `/privacy` and `/terms` on
      <https://eyesense.dpdns.org>, served by `site/` (see `site/README.md`).
      `/privacy` is the URL for the Play listing.
- [x] Contact route a blind user can use: `info@devray.qzz.io`, with an offer of
      an alternative format or language in both documents.
- [x] Prepare Kiswahili translations, given the app's supported languages.
      `privacy-policy.sw.md` and `terms-of-service.sw.md` are served at
      `/sw/privacy` and `/sw/terms` and loaded in-app when the language is
      Kiswahili. `LegalDocumentScreen` takes a language and falls back to
      English with an explicit on-screen notice rather than an error when a
      translation is absent — guarded by `test/legal_document_test.dart`.

      Both translations close by stating that the English version governs where
      they differ, because **neither has been reviewed by a Kiswahili-speaking
      lawyer**. See `docs/legal/OUTSTANDING.md`.

      The site now builds both languages with per-page `hreflang` alternates and
      a language switcher that stays on the same document rather than returning
      to the homepage.

### S7.3 — In-app legal screens

- [x] Add a Legal section to Settings: Privacy Policy, Terms of Use, Safety and Limitations, Open-Source Licences, version and build number.
- [x] Render policy text **in-app** as selectable screen-reader-accessible text, not only as a browser link.

      This was previously only half-true. `LegalDocumentScreen` loaded the
      markdown and dropped it into one `Text` widget, so TalkBack read the
      syntax aloud — `## 3. What the app processes`, and worse, pipe tables
      cell-by-cell with every delimiter. It also showed a hardcoded "Draft for
      review … placeholders" banner that is now false.

      `features/legal/legal_markdown.dart` now renders the documents' known
      subset of Markdown: headings carry `Semantics(header: true)` so TalkBack's
      heading navigation can jump between sections, bullet glyphs are wrapped in
      `ExcludeSemantics` so they are not spoken, and **tables are flattened into
      one labelled block per row** — each cell paired with its column heading,
      because a grid read cell-by-cell is unintelligible aloud.

      Guarded by `test/legal_markdown_test.dart`, which asserts against the
      semantics tree rather than the widget tree: no `**`, backtick, `#`, `](`,
      URL or bullet glyph reaches a screen reader; three headings are announced
      as headings; and no `|` or `---` survives table rendering.
- [ ] Use Flutter's `LicensePage` for third-party licences. ML Kit, camera, dio, flutter_tts, speech_to_text and others carry attribution obligations currently unmet.
- [ ] Record which terms version was accepted and when. The current `cloudConsentGranted` boolean does not record what was agreed to.
- [x] Surface Safety and Limitations prominently. It had been one sentence inside
      the welcome paragraph of a skippable tutorial, with a Skip button beside it.

      It is now its own onboarding step. `features/onboarding/safety_briefing.dart`
      holds the five limits **as data**, so the same wording is spoken aloud and
      shown on screen and the two cannot drift; it is also what makes the
      briefing translatable without touching the screen. The step:

      - speaks the whole briefing on arrival, because a blind user is the least
        likely to discover a wall of text by exploring for it;
      - gives each limit its own semantics node carrying its full text, so a
        single point can be re-read without replaying all five;
      - requires "I understand these limits" before continuing, recorded against
        `AppConfig.termsVersion` so a change to the wording asks again;
      - **keeps Continue enabled and explains the gate aloud when pressed**, since
        a disabled button announces itself as dimmed and gives no reason; and
      - removes Skip from this step, and makes Skip elsewhere land *on* the
        briefing rather than past it while it is unacknowledged.

      Guarded by `test/onboarding_safety_test.dart` (5 tests), including that
      Skip cannot be used to escape it.

### S7.4 — Play Data Safety declaration

Written out field by field in **`docs/legal/play-data-safety.md`**, with the
reason for every answer and the code or policy section it rests on. The summary
table that used to live here is gone: it is the kind of thing that drifts out of
step with the policy, which is exactly the failure Play rejects listings for.

- [x] Declare photos as collected **and** shared. Transient processing counts as
      collection when data leaves the device.
- [x] Declare the question text, under *App activity → Other user-generated
      content*. It was missing entirely.
- [x] **The IP address.** Resolved, and the answer is that Play's data-type list
      has no IP address entry at all — so the right outcome is *no declaration*,
      deliberately, with the reasoning recorded. It is not a *Device or other ID*
      (that category means advertising IDs, Android ID, IMEI, MAC), and it would
      only require *Approximate location* if used to derive location, which it is
      not: it is the key for a rate-limit counter cleared at the UTC day boundary.
      It stays disclosed in policy §3.7 because Play requires the policy to be
      complete even where the form has no matching field.
- [x] Declare encryption in transit — `android:networkSecurityConfig` forbids
      cleartext.
- [x] Resolve data deletion: nothing is retained to delete, there are no
      accounts, and local data goes with an uninstall. No account-deletion URL
      is required.
- [ ] Enter it in Play Console. Two judgement calls listed in
      `play-data-safety.md` §4 should be confirmed by the reviewer first; both are
      currently answered conservatively, so being wrong over-declares rather than
      under-declares.
- [ ] Complete the accessibility declaration honestly. Do not claim full screen-reader support until Stages 1 and 5 are verified on a device by a blind tester.

### S7.5 — Medical and assistive positioning

- [ ] Keep a prominent statement that EyeSense is not a medical device, not a mobility aid, and not a navigation aid.
- [ ] Review store listing and promotional copy for any implied safety capability. Phrases suggesting the app keeps a user safe, detects hazards reliably, or guides movement must not appear.

---

## Stage 8 — Release engineering

### S8.1 — Android configuration

- [ ] Pin `minSdk`, `targetSdk`, `compileSdk` and `ndkVersion` explicitly rather than inheriting `flutter.*`, so a Flutter upgrade cannot silently change published compatibility. Effective minSdk is **24**.
- [ ] Remove `skipDependencyChecks=true` from `android/gradle.properties` after establishing a compatible toolchain combination. Change one build variable at a time.
- [ ] Track the Gradle wrapper. `gradlew`, `gradlew.bat` and `gradle-wrapper.jar` are gitignored, so a fresh clone cannot build without regenerating them. Add the distribution checksum.
- [ ] Declare `abiFilters` if a fixed ABI set is required in all build paths, or correct README §5 to say the set comes from the Flutter CLI.

### S8.2 — Signing

- [ ] Configure real release signing. `android/app/build.gradle.kts:32-38` signs release with the debug key, so README §8's `.aab` instructions cannot produce a publishable artifact. Read from `key.properties`, already gitignored.
- [ ] Store the keystore securely outside source control with a documented backup. Losing it means losing the ability to update the listing.
- [ ] Plan and communicate that users with debug-signed installs must uninstall first, destroying their local settings and stored BYOK key.
- [ ] Review the **merged** release manifest for permissions and queries, not just the source manifest.
- [ ] Record source revision, build command and defines, toolchain versions, SDK levels, signer fingerprint and artifact SHA-256 for every candidate.

### S8.3 — Test coverage

The suite is 24 Flutter plus 10 Worker tests, all passing. The gaps matter more than the count.

- [ ] Add widget tests. There are none, despite `test/widget_test.dart` being so named — it contains model and policy unit tests only. Rename it.
- [ ] Add semantics tests for labels, hints, enabled state and traversal order. Every defect in [S1.6](#s16--connect-the-talkback-hints) is invisible to the current suite.
- [ ] Add layout tests at 320 logical px and `textScaler` 2.0 for every screen.
- [ ] Add provider contract tests for `HostedVisionProvider` and `GroqDirectVisionProvider`. Neither is tested.
- [ ] Cover the voice command router, `SceneAgent`, `ConversationAgent`, cancellation races and TTS interruption. `DelayedChunkTtsService` exists but nothing asserts Stop halts mid-chunk.
- [ ] Replace real platform services in `speech_tts_test.dart:137-147` with the fakes already written in `coordinator_test.dart`.
- [ ] Add an Android assemble job to CI. It currently runs analysis and unit tests only.
- [ ] Remove `deprecated_member_use: ignore` and fix the 19 `withOpacity` sites with `withValues(alpha:)`.

### S8.4 — Pilot

- [ ] Run the verification matrix in [§4](#4-verification-matrix) on real hardware.
- [ ] Hold a supervised pilot with blind and low-vision users. Ask them to complete tasks independently; a sighted engineer's successful demo is not usability evidence.
- [ ] Agree a daily usage allowance, provide a feedback route, and keep a tested rollback and kill switch.

---

## 4. Verification matrix

A change is not complete until its row passes. Device rows require evidence from real Android hardware.

| # | Scenario | Required outcome | Stage |
| --- | --- | --- | --- |
| 1 | Release build with no `--dart-define` | Fails closed with an accessible error; no token in the artifact | S1.1 |
| 2 | Fresh install, grant camera at first Describe | Completes on the first activation | S1.2 |
| 3 | Full Describe cycle, screen reader active | No overlapping speech at any point | S1.3 |
| 4 | Every speech-rate position | Each yields an audibly distinct rate | S1.4 |
| 5 | Measure control offsets across all states | No control moves between idle, capturing, processing, speaking | S1.5 |
| 6 | Screen reader explores every home control | Label and hint announced; busy state announced during operations | S1.6 |
| 7 | Exceed the call budget | Rejected before dispatch, not after | S2.1 |
| 8 | Each workflow in turn | Progress appears only on the activated control | S2.2 |
| 9 | Throttled network at p95 | No valid result discarded as stale | S2.4 |
| 10 | 30+ natural utterances per language | Each routes correctly; read requests never require consent | S2.5 |
| 11 | Repeated operations and practice captures | No orphaned files; recogniser and TTS released on disposal | S2.6 |
| 12 | Clear diagnostics with the directory read-only | Failure reported truthfully | S2.7 |
| 13 | All screens at 320 px and 200 % text | No overflow, no clipped essential labels | S2.8 |
| 14 | README claims against code | Every claim verifiable | Stage 3 |
| 15 | Concurrent Worker load across locations | Configured budget and concurrency cannot be exceeded | S4.1–S4.3 |
| 16 | Adversarial schema-valid responses | Prohibited guidance blocked in every returned field | S4.4 |
| 17 | Blind tester reads a medicine label | Succeeds unaided; guidance never asserts path safety or distance | S5.2 |
| 18 | Blind tester, gesture layer | Three core tasks completed without locating any on-screen position | S5.3 |
| 19 | Audio feedback set | Every state change distinguishable without speech | S5.4 |
| 20 | All four themes | Body text ≥ 4.5:1, controls and focus ≥ 3:1, measured | S6.1 |
| 21 | Keyboard and switch-access traversal | Focus ring visible on every control at ≥ 3:1 | S6.5 |
| 22 | Icon at launcher size, all Android icon modes | Mark legible at 24 px; themed and adaptive variants correct | S6.9 |
| 23 | Cold start, light theme preference | No flash of the wrong theme | S6.9 |
| 24 | Settings Legal section with a screen reader | Policy and terms readable in-app without a browser | S7.3 |
| 25 | Data Safety declaration against merged dependencies | No undeclared collection; no linked analytics SDK | S7.4 |
| 26 | Exact signed release candidate | Verified signing, permissions, SDK levels, cold start, offline OCR, secure storage | S8.2 |
| 27 | Supervised pilot | Core tasks completed independently, without sighted assistance | S8.4 |

---

## 5. Definition of done

A stage is complete when every checkbox is ticked **and** its matrix rows pass with recorded evidence. Specifically:

- No document in the repository states a claim the code does not support.
- No checkbox is ticked on the strength of "it compiles".
- Every behavioural fix landed with a regression test, and that test fails without the fix.
- Device-dependent rows carry the device, OS version, date and result.
- No stage is marked complete while its predecessor's exit gate is open.

## 6. Provenance

Phase completion status in [§1](#1-status-of-the-previous-plan) was established by reading the code on 18 October 2026, not by trusting either prior document. Application defects were found by direct inspection. Worker findings and Android build findings came from two parallel audit passes whose full reports contain additional low-severity items not reproduced here. The Groq model identifier was verified against Groq's published vision documentation on the same date.
