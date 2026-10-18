# EyeSense — Fix and Design Plan

> **SUPERSEDED — 18 October 2026.** Do not use this document for sequencing or status.
>
> **The source of truth is [`docs/implementation-plan.md`](implementation-plan.md).**
>
> This document is retained because it carries the detailed per-defect code analysis — file paths, line numbers, quoted code and reasoning — that the current plan summarises. Read it for *why* a fix is needed; read `implementation-plan.md` for *what to do and in what order*.
>
> Note that Part B's gesture layer, volume-key Stop, earcons and aiming guidance were new scope that conflicted with the previous plan's scope lock. That conflict is resolved in `implementation-plan.md` §2, and the work is sequenced there as Stage 5.

**Prepared:** 18 October 2026
**Status:** Background reference. No application or Worker behaviour has been changed by this document.
**Baseline verified on this date:** `dart analyze lib test` → clean; `flutter test --no-pub` → 24/24 pass; `npm run typecheck` → clean; `npm test` → 10/10 pass. Flutter 3.47.6, Dart 3.13.5.

## How to use this document

This is a companion to `docs/mvp-remediation-plan.md`, not a replacement. That document defines the phased delivery programme and its exit gates. This document records **specific defects found by code inspection**, the **non-visual interaction model** the app needs in order to be usable by its intended audience, the **design system** required for it to read as a finished product, and the **legal documents** required before any public release.

Where the two overlap, the phase gates in `mvp-remediation-plan.md` take precedence for sequencing.

> **Important caveat on the clean test baseline.** `dart analyze` reports no issues partly because deprecations are globally suppressed:
>
> ```yaml
> analyzer:
>   errors:
>     deprecated_member_use: ignore
> ```
>
> There are 19 `withOpacity` call sites, deprecated since Flutter 3.27. The suite also contains no widget tests and no semantics tests, so none of the accessibility defects in Part A are detectable by CI today.

---

## Contents

- [Part A — Defect fixes](#part-a--defect-fixes)
- [Part B — Blind-first interaction model](#part-b--blind-first-interaction-model)
- [Part C — Design system](#part-c--design-system)
- [Part D — Legal, privacy and store compliance](#part-d--legal-privacy-and-store-compliance)
- [Part E — Backend, build and release](#part-e--backend-build-and-release)
- [Part F — Verification matrix](#part-f--verification-matrix)
- [Part G — Suggested sequencing](#part-g--suggested-sequencing)

---

# Part A — Defect fixes

Severity reflects impact on the intended user, not implementation difficulty. Each item lists the file, the problem, and the concrete change.

## A1 — Remove the shared bearer token from the binary

**Severity: Critical. Security.**

`app/lib/core/config/app_config.dart` lines 12–15 embed a fallback token that is compiled into every APK:

```dart
static const String defaultDemoAccessToken = String.fromEnvironment(
  'HOSTED_ACCESS_TOKEN',
  defaultValue: 'eyesense-demo-token-secret-pitch-2026',
);
```

`CredentialService.getDemoAccessToken()` returns this constant whenever secure storage is empty, so the token ships in the binary alongside the live Worker URL and is recoverable by unzipping the APK. This contradicts README §9.3.

### Steps

- [ ] Rotate the deployed `DEMO_ACCESS_TOKEN` Worker secret immediately. Treat the current value as public.
- [ ] Change `defaultValue` to the empty string so hosted mode fails closed.
- [ ] Make `getDemoAccessToken()` return `null` rather than a constant when storage is empty, and let `HostedVisionProvider._getAuthHeaders()` raise its existing `upstreamAuthFailed` exception.
- [ ] Supply the token at build time via `--dart-define=HOSTED_ACCESS_TOKEN=…` for internal pilot builds only, and document that the resulting artifact must not be distributed publicly.
- [ ] Before any public or Play distribution, replace the shared token with per-device credentials issued by the Worker. A token embedded in a client binary is not authentication.
- [ ] Remove the sample token string from `worker/README.md` and `.dev.vars.example`; use an obvious placeholder.

### Exit check

- [ ] A release build with no `--dart-define` cannot reach the hosted endpoint and reports a clear, accessible configuration error.
- [ ] `rg -i "pitch-2026|demo-token-secret" --hidden` returns no matches outside this plan.

---

## A2 — Stop the lifecycle handler cancelling the first operation

**Severity: High. Core flow broken on first run.**

`app/lib/features/home/home_screen.dart` lines 37–43:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
    widget.coordinator.stop();
    widget.coordinator.cameraService.dispose();
  }
}
```

On Android, the runtime permission dialog moves the app to `inactive`. First run therefore goes: user activates Describe → permission dialog appears → this handler calls `stop()`, which increments `_currentGeneration` and disposes the controller → the user grants permission → every `if (gen != _currentGeneration) return;` guard in `executeDescribe` aborts. The result is silence: no speech, no error, and the status region left on "Stopped". The same applies to any transient system overlay or the app switcher.

### Steps

- [ ] React only to `AppLifecycleState.paused` and `AppLifecycleState.detached`. Ignore `inactive` and `hidden`.
- [ ] Do not call `coordinator.stop()` from the lifecycle handler; it announces "Stopped" as the app is leaving the foreground. Add a separate `coordinator.suspend()` that cancels in-flight network work and halts playback **without** emitting a user-facing announcement.
- [ ] Release the camera in `suspend()`, and let the existing lazy initialisation re-acquire it on the next capture.
- [ ] Request camera and microphone permission from an explicit, labelled step rather than implicitly during a capture, so a permission dialog never interleaves with an active operation. The onboarding practice step already does this correctly — route first use through it.

### Exit check

- [ ] On a fresh install with permissions not yet granted, activating Describe and granting permission completes the description without a second activation.
- [ ] Backgrounding during an operation produces no speech after resume and no obsolete result.

---

## A3 — Connect the TalkBack hints, which are currently dead code

**Severity: High. Accessibility; the app's central claim.**

`app/lib/widgets/accessible_action_button.dart` declares `semanticHint` (line 11), assigns it in the constructor (line 21), and then never references it. `build()` returns a bare `ConstrainedBox` → `ElevatedButton` with no `Semantics` wrapper. All six hints written on the home screen are silently discarded, so a screen-reader user hears only "Describe scene, button" and never "Take a picture and describe visible information".

A second defect sits in the same widget. When `isLoading` is true the child is replaced wholesale by a spinner (lines 68–77), removing `Text(label)` entirely and setting `onPressed: null`. The control the user just activated becomes an unlabelled, disabled node, so anyone exploring by touch mid-operation loses their place.

### Steps

- [ ] Wrap the button in a single actionable `Semantics` node and exclude the inner tree to avoid a duplicate node:

```dart
return Semantics(
  button: true,
  enabled: onPressed != null && !isLoading,
  label: label,
  hint: semanticHint,
  child: ExcludeSemantics(
    child: ConstrainedBox(/* existing */),
  ),
);
```

- [ ] Keep the label visible and readable during loading. Place the spinner **beside** the text rather than replacing it, and convey busy state through the semantics node, not by erasing the label.
- [ ] Review the `Semantics` wrapper around the Settings `IconButton` (home screen lines 141–162). It supplies `label: 'Settings'` over an `IconButton` that also carries `tooltip: 'Settings'`, which can produce a doubled announcement. Keep one source.
- [ ] Add `liveRegion: true` to `OperationStatusWidget`'s `Semantics` (currently `readOnly: true` with a label but no live region), so status changes are announced without relying on imperative calls.
- [ ] Add semantics tests asserting label, hint, enabled state and traversal order for every home control. None exist today.

### Exit check

- [ ] A semantics test asserts the hint text is present on all six home controls.
- [ ] During an operation, every control still exposes a readable label, and the active one reports a busy state.

---

## A4 — Show progress on the control the user actually activated

**Severity: Medium. Correctness and orientation.**

`executeAskQuestion` and `executeReadText` both transition through `OperationState.capturing`, but only the Describe button watches for it:

```dart
isLoading: state == OperationState.capturing || state == OperationState.processingCloud,
```

So asking a question makes **Describe** spin, and Read Text makes Describe spin before handing over to Read. The progress indicator appears on an unrelated control.

### Steps

- [ ] Track which operation is active, not only the coarse state. Add an `AppOperation?` or `TaskKind?` field to the coordinator, set at the start of each workflow and cleared in `finally`.
- [ ] Drive `isLoading` from `activeTask == TaskKind.describe && isBusy`, and so on per control.
- [ ] Keep the global status region driven by `OperationState`, which is the correct granularity for it.

---

## A5 — Collapse the two competing speech channels into one

**Severity: High. Accessibility.**

The app speaks through two independent engines with no coordination. `_setState` announces every transition through TalkBack:

```dart
void _setState(OperationState newState, {String? announcement}) {
  _state = newState;
  notifyListeners();
  final message = announcement ?? newState.localizedAnnouncement;
  SemanticAnnouncer.announce(message);
}
```

Then the result is spoken by `flutter_tts`. For Describe the sequence is TalkBack saying "Taking a picture" → "Describing" → "Speaking", with `ttsService.speak(description)` beginning at the same instant as that final announcement. The two overlap on the most important utterance in the product. README §4 claims no duplicate announcements.

`_handleError` compounds it (lines 514–517): the message goes through `_setState`'s announcement **and** `ttsService.speak()`, un-awaited, ignoring the user's auto-read preference.

### Steps

- [ ] Choose app TTS as the single output channel for content and status, with a serial queue and explicit priorities (an error or Stop pre-empts a pending description).
- [ ] Reserve `SemanticsService.announce` for short, non-content events only, and never issue it within ~300 ms of starting app TTS.
- [ ] Remove the unconditional `ttsService.speak()` from `_handleError`. Route errors through the queue, honour `autoRead`, and always leave the message available as accessible on-screen text so a user with auto-read off can still reach it.
- [ ] Set `OperationState.speaking` only when speech actually begins. All three workflows currently set it unconditionally and then check `autoRead`, so with auto-read off the status reports "Speaking" in silence.
- [ ] Use the existing `SpeechFeedbackCoordinator.speakResult`, which already implements the correct `autoRead` branch and is currently never called by the coordinator.
- [ ] Give `OperationState.error` a dismissal path; `_errorMessage` currently persists until the next operation with no way to clear it.

### Exit check

- [ ] With TalkBack active, no two utterances overlap across capture, processing, result, error and Stop.
- [ ] With auto-read off, status never claims "Speaking", and error text is reachable by exploration.

---

## A6 — Make Stop genuinely persistent and the layout stable

**Severity: High. Accessibility; contradicts a documented guarantee.**

The home screen comment says "Persistent Operation Control Area", but the control is conditional:

```dart
if (isBusy || isSpeaking) ...[
  AccessibleActionButton(label: 'Stop current task', …),
  const SizedBox(height: AppTheme.elementSpacing),
],
```

It is inserted **above** the action list when an operation starts, so all five buttons shift down by roughly 88 logical pixels at precisely the moment the user most wants to reach Stop. Separately, the camera preview appears permanently once `cameraService.isInitialized` flips after the first capture, displacing everything by a further ~156 pixels for the rest of the session.

Blind touch users rely heavily on remembered positions. The spatial map currently changes transiently during every operation and permanently after the first one.

Related: the "Stop Audio" control inside `ResponsePanelWidget` can never appear. `_setState(OperationState.speaking)` notifies listeners **before** `await ttsService.speak(...)`, and `HomeScreen`'s `ListenableBuilder` observes only the coordinator, so `isSpeaking` — which resolves to `ttsService.isSpeaking` — is still `false` at paint time, and the TTS service's own notifications never reach the widget.

### Steps

- [ ] Reserve the Stop control's space at all times. Render it disabled when idle rather than removing it from the tree, so no sibling ever moves.
- [ ] Place Stop in a fixed, non-scrolling region (a bottom bar or a persistent header slot) so it is reachable without scrolling regardless of result length.
- [ ] Remove the camera preview from the blind-first layout entirely; see [B4](#b4--serve-blind-and-low-vision-as-distinct-profiles). If retained for low-vision users, reserve its space from first paint with a placeholder so nothing shifts.
- [ ] Fix `isSpeaking` propagation with `Listenable.merge([coordinator, coordinator.ttsService])`, or have the coordinator subscribe to `ttsService` and re-emit.
- [ ] Remove one of the two Repeat controls. Two affordances for the same action add swipe noise with no benefit.

### Exit check

- [ ] A widget test asserts that the vertical offset of every action control is identical in idle, capturing, processing and speaking states.
- [ ] The Stop Audio control appears while speech is playing.

---

## A7 — Make the speech-rate control functional across its whole range

**Severity: High. Primary-audience preference silently broken.**

`settings_screen.dart` lines 83–92 exposes `min: 0.5, max: 2.0, divisions: 6`. `tts_service.dart` line 54 clamps it:

```dart
final rate = _prefs.speechRate.clamp(0.25, 1.0);
```

The positions 1.25, 1.5, 1.75 and 2.0 all collapse to 1.0 while the label reports up to "2.0x". Four of seven positions do nothing. Experienced screen-reader users almost always prefer faster-than-default speech, so this breaks the setting that matters most to the intended audience.

### Steps

- [ ] Decide on a single user-facing scale and map it explicitly to the platform range. `flutter_tts` accepts 0.0–1.0 on Android, so a 0.5×–2.0× product scale needs a deliberate mapping function rather than a clamp.
- [ ] Add a `speechRateMultiplier` → platform-rate conversion in `TtsService` with unit tests at the boundaries and midpoints.
- [ ] Migrate persisted values if their meaning changes, so existing installs do not silently alter.
- [ ] Add `label:` to the `Slider` so the value is announced while dragging, and a `semanticFormatterCallback` producing e.g. "1.5 times normal speed".
- [ ] Add a "Preview voice" action next to the control, since a blind user cannot evaluate a rate from a numeric label.

### Exit check

- [ ] A test asserts that every slider division produces a distinct platform rate.
- [ ] Changing the rate and previewing it is audibly different at each step on a real device.

---

## A8 — Widen the freshness budget so valid results are not discarded

**Severity: High. Users lose successful work.**

```dart
static const Duration clientTimeout = Duration(seconds: 15);
static const Duration sceneFreshnessLimit = Duration(seconds: 15);
```

`captureTimestamp` is stamped before compression and before the request, but `OutputPolicy.validateSceneResult` throws `staleResultDiscarded` once elapsed time exceeds 15 seconds. Capture, plus decode/resize/JPEG-encode of a 1280-pixel image, plus up to 15 seconds of network, routinely exceeds the window on a slow connection. The user waits the full duration and is then told the observation expired.

### Steps

- [ ] Separate the two budgets. The freshness limit must exceed capture plus preparation plus request timeout, with headroom. A workable starting pair is a 10-second client timeout against a 25-second freshness limit; confirm against measured p95.
- [ ] Measure capture-to-result p50/p95 on a mid-range device over a throttled connection before fixing the constants.
- [ ] Evaluate freshness at the *start* of delivery, not mid-utterance, so a valid description is never cut off part-way.
- [ ] Use elapsed monotonic time for the deadline and keep the injected clock for tests.
- [ ] When a result genuinely is stale, say what to do next ("that took too long, please capture again") rather than only that it expired.

---

## A9 — Prevent the AppBar overflowing at large text scales

**Severity: Medium. Accessibility; contradicts a documented guarantee.**

`home_screen.dart` lines 123–138 places a two-line `Column` — a 26-pixel bold title plus a `bodySmall` tagline — inside a default 56-pixel toolbar. This is already tight at normal scale and overflows vertically at the 200 % scale claimed in README §4.

### Steps

- [ ] Move the tagline out of the AppBar. It is decorative and adds a traversal stop before the primary actions.
- [ ] Set an explicit `toolbarHeight` that accommodates the title at the maximum supported scale, or let the title wrap.
- [ ] Add widget tests at 320 logical pixels wide and `textScaler` 2.0 for every screen. None exist today.

---

## A10 — Route voice commands on natural phrasing

**Severity: High. The primary modality mishandles ordinary speech.**

`agent_coordinator.dart` lines 459–462 match whole strings only:

```dart
final isDescribe = RegExp(r'^(describe|describe scene|tazama|eleza|eleza mandhari)$').hasMatch(clean);
final isRead     = RegExp(r'^(read|read text|soma|soma maandishi)$').hasMatch(clean);
```

"describe the scene", "read this label", or any recogniser output carrying trailing punctuation fails to match and falls through to `executeAskQuestion`, which requires cloud consent. An offline read request therefore becomes a consent error.

A second problem: `ConversationAgent.resolveIntent` — which exists to do exactly this job and handles both languages — has zero call sites. `readingAgent` also has zero call sites, and `setMode` / `AppMode` / `_currentMode` / `awarenessEnabled` are never read by any UI. README §2's agent diagram overstates what is wired up.

### Steps

- [ ] Replace the anchored regexes with token-aware matching: normalise the utterance, strip punctuation and filler words, then match against approved phrase sets on word boundaries.
- [ ] Preserve the existing protection against false positives. "stop sign", "bread" and "textile" must not trigger Stop or Read; test each explicitly.
- [ ] Resolve read-text intent **before** the cloud fallback, so an offline request never requires consent.
- [ ] Route command resolution through `ConversationAgent.resolveIntent` so there is one implementation, or delete the agent and correct README §2. Do not keep both.
- [ ] When intent is ambiguous, ask a short clarifying question rather than silently defaulting to a cloud call. `resolveIntent` already returns a `clarify` branch for this.
- [ ] Remove or document `readingAgent`, `AppMode`, `setMode` and `awarenessEnabled` as deferred, and align README §2 with what actually executes.

### Exit check

- [ ] A test table of at least 30 natural utterances per language routes to the expected workflow.
- [ ] No utterance that is not an explicit read or describe command reaches a cloud call without consent.

---

## A11 — Make the Ask flow voice-first

**Severity: Medium. Primary audience friction.**

`_showAskDialog` opens an `AlertDialog` whose text field carries `autofocus: true`, which raises the software keyboard immediately and places the user in typing mode. Typing a question on glass is slow and error-prone without sight. Voice — the natural input — is the second of three action buttons, below the field and past the keyboard. Submit also does nothing at all when the field is empty (`if (q.isNotEmpty)`), with no feedback, so an activation simply appears to fail.

### Steps

- [ ] Make voice the default path: activating "Ask a question" should begin listening directly, with typing offered as an explicit alternative.
- [ ] If the dialog is retained, remove `autofocus`, present the voice action first in both visual and traversal order, and make the content scrollable with the keyboard visible.
- [ ] Give empty-submit an accessible, spoken rejection instead of a silent no-op.
- [ ] Enforce the 300-character limit in the input affordance, not only at the coordinator boundary, with a live announced count.
- [ ] Prefer a dedicated route over a dialog. Dialogs are a known source of screen-reader focus friction, and this one is a primary flow rather than a confirmation.

---

## A12 — Release native resources and delete temporary captures

**Severity: Medium. Resource leak; contradicts a retention claim.**

- `AgentCoordinator` extends `ChangeNotifier` but never overrides `dispose()`. `OcrService.dispose()`, which closes the ML Kit recogniser, has zero call sites. `TtsService` is never released.
- `OnboardingScreen._requestCameraPermissionAndPractice` calls `captureAndCompress()` but never `deleteTemporaryCapture()`, unlike every coordinator workflow. Each practice capture leaves a JPEG on disk, against the zero-retention claim in README §9.6.

### Steps

- [ ] Override `AgentCoordinator.dispose()` to close the OCR recogniser, stop and release TTS, cancel speech recognition, dispose the camera controller and cancel any active `CancelToken`.
- [ ] Delete the practice capture in a `finally` block covering success, failure and cancellation.
- [ ] Add a narrowly scoped startup sweep for orphaned captures left by a crash, restricted to the app's own capture directory.

---

## A13 — Remove the blanket deprecation suppression

**Severity: Low now, blocking at the next SDK bump.**

`analysis_options.yaml` sets `deprecated_member_use: ignore`, which is why analysis is clean. There are 19 `withOpacity` call sites across `accessible_action_button.dart` (2), `operation_status.dart` (3), `response_panel.dart` (8), `conversation_agent.dart` (1), `diagnostics_screen.dart` (2) and `home_screen.dart` (3).

### Steps

- [ ] Replace each `withOpacity(x)` with `withValues(alpha: x)`.
- [ ] Delete the `deprecated_member_use: ignore` entry and fix whatever it was masking.
- [ ] Consider promoting the remaining analysis infos to warnings in CI so regressions surface.

---

## A14 — Delete the dead theme tokens

**Severity: Low. Maintainability.**

`app_theme.dart` lines 33–41 define nine backward-compatible aliases (`backgroundNavy`, `surfaceNavy`, `surfaceVariant`, `textNearWhite`, `textMuted`, `tealAccent`, `tealLight`, `errorRed`, `warningOrange`) that are referenced nowhere outside their own declarations. Lines 17 and 28 define `darkFocusIndicator` and `lightFocusIndicator`, which are never used anywhere — the focus indicator the design calls for is not implemented.

### Steps

- [ ] Delete the alias block.
- [ ] Wire the focus-indicator tokens into a real focus treatment; see [C5](#c5--focus-and-state-treatment).

---

# Part B — Blind-first interaction model

Part A fixes defects in the current design. This part changes the design itself, because the present interaction model asks a blind user to locate specific on-screen targets by touch exploration for every action. That is workable but slow, and it is not how comparable products behave.

## B0 — What a blind user experiences today

Recorded here so the gap is explicit.

| Step | Current experience |
| --- | --- |
| Launch | Silent. No earcon, no spoken orientation. The user must begin exploring to confirm the app opened. |
| Find an action | Five full-width controls differing only by label, explored by dragging a finger down the screen. |
| Activate Describe | One `HapticFeedback.lightImpact()`. No shutter sound, no audio cue. |
| During the operation | The activated control loses its label and becomes a disabled spinner ([A3](#a3--connect-the-talkback-hints-which-are-currently-dead-code)); all other controls shift position ([A6](#a6--make-stop-genuinely-persistent-and-the-layout-stable)). |
| Result arrives | TalkBack says "Speaking" while app TTS begins the description, overlapping ([A5](#a5--collapse-the-two-competing-speech-channels-into-one)). |
| Re-read the result | The response panel renders after all five controls, so it is last in traversal order. Focus is never moved to it. |
| Interrupt | Requires locating a control that has just moved, while audio is playing. |

## B1 — Replace target-hunting with a gesture layer

The highest-impact change in this document. The user should not have to find anything to perform the common action.

Proposed gesture set:

| Gesture | Action |
| --- | --- |
| Double-tap anywhere | Run the current mode |
| Two-finger tap | Stop / interrupt immediately |
| Swipe left / right | Cycle mode: Describe → Read Text → Ask, announcing the new mode |
| Long press | Start voice command |
| Three-finger tap | Repeat last result |

### Steps

- [ ] Implement the surface as a **single full-screen actionable node** that exposes each action as a `CustomSemanticsAction`. TalkBack consumes raw gestures, so custom actions surfaced through its local context menu are the supported route. The app currently uses `CustomSemanticsAction` nowhere.
- [ ] Keep the existing explicit button list reachable as a secondary, fully labelled path. Do not remove it — discoverability and gesture memory serve different users, and some switch-access hardware needs discrete targets.
- [ ] Announce mode changes through the single speech channel from [A5](#a5--collapse-the-two-competing-speech-channels-into-one), and persist the selected mode across launches.
- [ ] Make the current mode audible on demand, not only on change.
- [ ] Bind Stop to the hardware volume keys as well. Interrupting speech must never require locating a moving on-screen target.

### Exit check

- [ ] A blind tester completes Describe, Read Text and Ask without locating any specific on-screen position.
- [ ] Every gesture action is reachable through TalkBack's local context menu.

## B2 — Add real-time aiming guidance before capture

This is the central functional gap. The user cannot know whether the camera is pointed at the subject, too close, too far, tilted, or obstructed by a finger. The app captures without feedback and reports failure afterwards:

```dart
userMessage: 'No readable text found. Try a clearer view or better lighting.',
```

"Try a clearer view" is advice the user has no means of acting on. `SceneResult` carries `imageQuality` and `uncertainty`, but only on the cloud path and only after the round trip. Read Text — the offline flagship, the feature used on a medicine bottle — has no quality signal at all.

### Steps

- [ ] Stream low-resolution preview frames during Read Text and run on-device detection to estimate text presence, coverage and stability.
- [ ] Speak short, actionable corrections on a throttled cadence: "move closer", "tilt up", "hold steady", "whole page not visible".
- [ ] Auto-capture when the frame is stable and the subject is adequately framed, with an audible shutter. Keep manual capture available.
- [ ] Add measured pre-capture checks for luminance (too dark) and sharpness (motion blur), and distinguish measured signals from model opinions in what is spoken.
- [ ] Detect a likely obstructed lens (uniformly dark or low-variance frame) and say so specifically.
- [ ] Do not invent proximity, distance or collision information. Framing guidance is about the image, not the physical world, and must not drift into navigation advice prohibited by `OutputPolicy`.
- [ ] Apply the same guidance to Describe and Ask, where it is valuable but less critical.

### Exit check

- [ ] A blind tester reads a medicine label and a utility bill unaided, with recorded success rate before and after.
- [ ] Guidance never asserts path safety, distance or clearance.

## B3 — Replace single-channel speech with structured audio feedback

`HapticService` offers only `lightImpact()` and a double `mediumImpact()`. There are no audio cues anywhere in the app. Earcons carry more information than vibration, work when the device is in a pocket, and are substantially faster than speech for state changes.

### Steps

- [ ] Add a short, distinct earcon set: capture shutter, processing loop (quiet, looping, so silence is never ambiguous), success, error, and potential concern.
- [ ] Keep earcons under roughly 300 ms except the processing loop, and duck them under speech rather than interleaving.
- [ ] Make them individually disableable, and respect the existing haptics preference separately.
- [ ] Add a distinct, unmistakable cue for "listening started" — currently `playReadinessCue()` only vibrates, so the user must infer that recording began.
- [ ] Keep haptics as redundant confirmation for users with hearing loss; do not replace one channel with the other.

## B4 — Serve blind and low-vision as distinct profiles

The app claims both audiences but is designed visually and annotated with semantics afterwards. The two have materially different needs: a blind user wants gestures, audio density and no preview; a low-vision user wants the preview, high contrast, large type and a magnifier-friendly layout.

### Steps

- [ ] Add a first-run choice — "I use a screen reader" / "I have some usable vision" / "I am sighted and assisting someone" — and persist it. Keep it changeable in Settings and never lock the user out of either behaviour.
- [ ] Blind profile: gesture layer active, camera preview off, auto-read on, earcons on, result region first in traversal order.
- [ ] Low-vision profile: preview on with reserved space, high-contrast theme, large type defaults, generous targets.
- [ ] Detect an active screen reader via `MediaQuery.accessibleNavigationOf(context)` to seed the default, but let the explicit choice override it.
- [ ] Do not use the profile to withhold functionality. It sets defaults only.

## B5 — Fix output order, focus and progressive disclosure

### Steps

- [ ] Move the result region directly after the status region, ahead of the action controls, so the most important output is not last in traversal order.
- [ ] Move accessibility focus to the result when it arrives, so the next swipe explores the text rather than hunting for it. Nothing in the app manages focus today — the only `autofocus` is on the Ask dialog's text field.
- [ ] Speak a one-sentence summary first, then offer an explicit "more detail" action, rather than one long utterance the user must sit through or restart.
- [ ] Add sentence-level navigation of a long result (next / previous sentence), which matters most for OCR output that can run to thousands of characters.
- [ ] Keep the "Previous result:" prefix behaviour, which `PresentationRecord.asPrevious()` already implements correctly.

## B6 — Give the app an audible identity at launch

### Steps

- [ ] On launch, play a short brand earcon and speak a one-line orientation: ready state, current mode, and how to act. Keep it skippable and suppressible after the first few sessions.
- [ ] Announce initialisation failures audibly. `main.dart`'s error state is currently visual only, so a blind user hits silence when bootstrap fails.
- [ ] Make onboarding audible without requiring exploration. Six screens of dense paragraphs — including a long privacy disclosure — currently rely entirely on the user swiping through each one with TalkBack. Offer per-step narration with a "read this aloud" control and a "continue" that does not require locating a target.

---

# Part C — Design system

The objective is a product that reads as considered and professional. Two things currently work against that: a `ColorScheme` that is only partially specified, so a large share of the UI renders in Material's stock baseline palette; and the absence of any spacing, radius, type or icon scale, so sizes are chosen ad hoc at each call site.

## C0 — What makes the current UI read as generic

Honest diagnosis, because this drives the recommendations.

1. **Saturated cyan-teal on deep navy with rounded cards and soft drop shadows** is the default palette of generated app mock-ups. The colours are individually fine; the combination is the most over-used pairing in the category and signals "template" before any content is read.
2. **No scale discipline.** Border radii in use: 8, 10, 14, 16, 18, 20, 24. Icon sizes: 14, 18, 20, 22, 24, 26, 28, 30, 52, 64. Spacing values: 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 36, 40. Font sizes: 11, 14, 16, 18, 20, 22, 24, 26, 28, 30. Nothing derives from a system, so nothing lines up optically.
3. **Borders used as the primary separator.** Outlines at 1, 1.5 and 2 pixels with 30–50 % opacity appear on nearly every container. Mature interfaces separate with surface tone and spacing, reserving outlines for state.
4. **Identical controls stacked vertically.** Five full-width 72-pixel buttons differing only by a 30 %-opacity border read as a debug menu, not a hierarchy.
5. **Decorative chrome instead of a brand.** The splash hand-draws a circle around `Icons.visibility`; `assets/icon/app_icon.png` is registered in `pubspec.yaml` but referenced nowhere in Dart, and `flutter_launcher_icons` is not a dependency.

## C1 — Fix the ColorScheme first

This is the single largest visual defect. Both themes are built with the `const` constructors specifying seven roles:

```dart
colorScheme: const ColorScheme.dark(
  primary: darkPrimaryFill,
  onPrimary: darkTextOnPrimary,
  surface: darkSurface,
  onSurface: darkMainText,
  error: darkError,
  onError: darkBackground,
  outline: Color(0xFF334B6E),
),
```

Every other Material 3 role — `secondary`, `tertiary`, `primaryContainer`, `secondaryContainer`, `surfaceVariant`, `onSurfaceVariant`, the whole `surfaceContainer*` family, `outlineVariant`, `inverseSurface`, `scrim` — silently retains Material's baseline lavender-and-grey defaults. Every widget reading those roles renders off-brand: `Switch` tracks, `Slider` inactive tracks, `Radio` fills, `Divider`, `DropdownButton` menus, `SnackBar`, `Chip`. The app's own code reaches for them too, at `operation_status.dart:29` (`surfaceContainerHighest`) and `ai_connection_screen.dart:280` (`onSurfaceVariant`). Settings is dense with switches, sliders, radios and dropdowns, so that screen shows the mismatch most clearly.

### Steps

- [ ] Generate the scheme from a seed so all roles harmonise, then override only what must be exact:

```dart
static final ColorScheme _dark = ColorScheme.fromSeed(
  seedColor: brandAccent,
  brightness: Brightness.dark,
  contrastLevel: 0.5,
).copyWith(
  surface: surfaceBase,
  onSurface: textPrimary,
);
```

- [ ] Verify every pairing actually used against WCAG 2.1: 4.5:1 for body text, 3:1 for large text and for the boundaries of meaningful controls.
- [ ] Remove hardcoded hex from widgets so light mode is coherent: `Color(0xFF132240)` at `operation_status.dart:29` and `response_panel.dart:49`, the navy constants throughout `main.dart`, and `Colors.green` at `onboarding_screen.dart:223`. That last one is a genuine failure — Material green on the `#F7F9FC` light background is roughly 2.8:1, below the 4.5:1 threshold, in a product whose premise is accessibility.
- [ ] Add a `ThemeExtension` for semantic colours the Material scheme has no slot for: `success`, `warning`, `concern`, and the focus ring.

## C2 — Choose a palette with a point of view

Two viable directions. I recommend the first.

### Recommended — high-visibility amber on true ink

Amber-on-dark is the established colour language of accessibility and high-visibility equipment, which makes it both distinctive in this category and defensible in a pitch. It also has a practical advantage: amber retains more perceived contrast than cyan for users with the most common forms of colour vision deficiency, and holds up under the yellowing lens tint typical of cataract.

| Role | Dark | Light |
| --- | --- | --- |
| Background | `#0A0C10` | `#FBFBF9` |
| Surface | `#14171D` | `#FFFFFF` |
| Surface raised | `#1C2029` | `#F2F3F0` |
| Primary accent | `#FFC247` | `#8A5A00` |
| On accent | `#1A1200` | `#FFFFFF` |
| Text primary | `#F7F8F8` | `#14171D` |
| Text secondary | `#B6BCC6` | `#4A525E` |
| Focus ring | `#FFD86B` | `#8A5A00` |
| Error | `#FF8A7A` | `#A8231A` |
| Concern | `#FFB020` | `#7A4A00` |

True ink rather than saturated navy also reads as more serious and gives deeper blacks on OLED, which meaningfully reduces battery draw for a camera app.

### Alternative — keep teal, but discipline it

If brand continuity matters more, retain `#35D6C4` but desaturate the base from `#0B1630` toward a neutral ink, and restrict the accent to interactive and focus elements only. The present design applies teal to the accent, the tagline, every icon, the status border, the panel border and the focus colour simultaneously, which removes its signalling value. Accent should mark what the user can act on, not decorate.

### Steps

- [ ] Choose a direction and record the decision.
- [ ] Add a third genuinely high-contrast theme — pure `#000000`/`#FFFFFF` with the amber accent. "Dark Navy" is not maximum contrast, and many low-vision users specifically need pure black with a single saturated accent. Expose it as a fourth option alongside System / Dark / Light.
- [ ] Verify all three themes at 320 logical pixels and 200 % text scale.

## C3 — Define and enforce scales

### Steps

- [ ] Adopt a 4-point spacing scale and use only its steps: 4, 8, 12, 16, 24, 32, 48. Replace the twelve ad-hoc values currently in use.
- [ ] Adopt three radii: 8 for inputs and chips, 16 for cards and buttons, 28 for sheets and dialogs. Replace the seven currently in use.
- [ ] Adopt three icon sizes: 20 inline, 24 standard, 32 primary action. Replace the ten currently in use.
- [ ] Define the full 15-style Material 3 text theme. Only six are defined today, so `bodySmall` (the AppBar tagline), `labelMedium` and `titleSmall` (both used in `response_panel.dart`) fall back to defaults.
- [ ] Derive the type scale from a consistent ratio rather than choosing sizes per call site, and express sizes so they scale with `TextScaler` rather than being pinned.
- [ ] Expose all tokens through a single `ThemeExtension` and forbid raw literals in widget code. Add a lint or review rule.

## C4 — Choose a typeface deliberately

The app uses default Roboto with no declared family.

### Steps

- [ ] Ship **Atkinson Hyperlegible** for UI text. It was designed by the Braille Institute specifically to maximise character disambiguation for low-vision readers. It is a genuine usability improvement and a credible, specific design decision rather than a default.
- [ ] Pair it with a neutral grotesque or the same family for numerals; keep to two weights (regular and semibold) to avoid a decorative feel.
- [ ] Bundle the font rather than fetching it at runtime, so the app renders identically offline.
- [ ] Set `height` explicitly per style. Line height drives perceived quality more than family choice, and the current theme sets it on only two styles.

## C5 — Focus and state treatment

`darkFocusIndicator` and `lightFocusIndicator` exist as tokens and are used nowhere. For a product targeting switch access and external keyboards, a visible focus ring is essential.

### Steps

- [ ] Implement a 3-pixel focus ring with a 2-pixel offset, meeting 3:1 against both the control and its background, applied through `WidgetStateProperty` so it is consistent across every control type.
- [ ] Define all five states — default, hover, focus, pressed, disabled — for each interactive component, rather than relying on the default overlay.
- [ ] Ensure disabled controls still meet 3:1 for their text, since disabled state currently carries meaning in this app (Repeat is disabled until a result exists).

## C6 — Add the missing component themes

Currently themed: `appBar`, `card`, `dialog`, `inputDecoration`, `textTheme`, `elevatedButton`. Everything else inherits defaults.

### Steps

- [ ] Add `switchTheme`, `sliderTheme`, `radioTheme`, `checkboxTheme`, `dividerTheme`, `listTileTheme`, `outlinedButtonTheme`, `textButtonTheme`, `filledButtonTheme`, `iconButtonTheme`, `segmentedButtonTheme`, `snackBarTheme`, `progressIndicatorTheme`, `tooltipTheme`, `bottomSheetTheme`, `dropdownMenuTheme`.
- [ ] Migrate from `ElevatedButton` to the Material 3 button set so hierarchy is expressed by component rather than by border opacity: `FilledButton` for the primary action, `FilledButton.tonal` for secondary actions, `OutlinedButton` for tertiary.

## C7 — Rework the screens

### Home

### Steps

- [ ] Establish a hierarchy. One prominent primary action, with secondary actions visually subordinate — not five identical controls. Keep the single-column order and the 72-pixel minimum height, which are correct for screen-reader traversal; express difference through component type and surface tone rather than size alone.
- [ ] Order the content: status, then result, then actions, then the persistent Stop region. See [B5](#b5--fix-output-order-focus-and-progressive-disclosure).
- [ ] Remove the camera preview from the default layout, per [B4](#b4--serve-blind-and-low-vision-as-distinct-profiles).

### Settings and AI Connection

### Steps

- [ ] Replace the flat `ListView` of zero-padding `ListTile`s, hand-written `Text` headers and `Divider(height: 32)` spacers with grouped card sections and a consistent section-header style. This is the cheapest single change that makes the app look shipped.
- [ ] Move the Worker URL and demo token behind an "Advanced" disclosure. They are developer configuration and should not sit in the ordinary pilot flow.
- [ ] Add the legal entries from [Part D](#part-d--legal-privacy-and-store-compliance).

### Splash and branding

### Steps

- [ ] Read the persisted theme preference before first paint. `main.dart` currently hardcodes `AppTheme.darkTheme` and navy colours regardless of the saved setting, so light-mode users see a navy flash on every cold start.
- [ ] Use the real brand mark instead of a `Container` circle around `Icons.visibility`, and add `flutter_launcher_icons` to generate the launcher and adaptive icons from `assets/icon/app_icon.png`.
- [ ] Add a proper Android 12+ splash definition. `launch_background.xml` currently references `@mipmap/launch_image` only inside comments.

## C8 — Motion

There is no `pageTransitionsTheme`, so navigation uses the platform default, and the response panel appears with no transition.

### Steps

- [ ] Add shared-axis transitions between Home, Settings and the sub-screens.
- [ ] Animate the result region's appearance with an `AnimatedSwitcher`, keeping it brief (under 200 ms) so it never delays speech.
- [ ] Honour `MediaQuery.disableAnimationsOf(context)` and skip all non-essential motion when set.
- [ ] Never gate an announcement or a state change on an animation completing.

---

# Part D — Legal, privacy and store compliance

The app currently has no privacy policy, no terms, and no legal screens. The only privacy text is inline prose in onboarding step 3, a notice in the diagnostics screen, and a section heading in settings. Google Play requires a publicly hosted privacy policy URL for every app, and requires it unconditionally for any app that requests camera or microphone permission.

Drafts have been written to:

- `docs/legal/privacy-policy.md`
- `docs/legal/terms-of-service.md`

Both are drafts prepared from the observed behaviour of the codebase. **They require review by a qualified lawyer in the operating jurisdiction before publication.** They are not legal advice.

## D1 — Confirm the facts the policy asserts

The drafts describe the app as the code behaves today. Confirm each before publishing, because a privacy policy that overstates protection is a worse liability than none.

- [ ] Read Text performs no network I/O. Verify on a device with networking disabled.
- [ ] Captured images are deleted after every outcome, including failure, cancellation and onboarding practice — currently **not true** for the practice capture ([A12](#a12--release-native-resources-and-delete-temporary-captures)).
- [ ] Diagnostics contain no image, audio, question or OCR text. Verify an export from every error fixture.
- [ ] No analytics, advertising, attribution or crash-reporting SDK is linked. Verify against the merged release dependency tree, not the source list.
- [ ] Confirm what Cloudflare and Groq retain under current terms, and cite the version and date reviewed.
- [ ] Confirm whether Android's speech recognition on target devices processes audio on-device or server-side. This varies by OEM and language, and the honest disclosure is that it is governed by the device's own speech provider, not by EyeSense.

## D2 — Establish the publisher and jurisdiction

- [ ] Decide the publishing entity: an individual developer, the university, or a registered company. This determines the data-controller identity, which both documents must name.
- [ ] Confirm the governing jurisdiction. Given the Kiswahili support and the MUA Innovation Week context, Tanzania's Personal Data Protection Act 2022 is the likely primary regime; Kenya's Data Protection Act 2019 applies if users are there. The drafts carry placeholders — do not publish with them unresolved.
- [ ] Publish both documents at stable public URLs before submitting to Play. A repository file is not an acceptable policy URL.
- [ ] Provide a working contact address for data requests, and a route a blind user can actually use.
- [ ] Record the effective date and keep a version history.

## D3 — Add in-app legal screens

- [ ] Add a "Legal" section to Settings containing Privacy Policy, Terms of Use, Safety and Limitations, Open-Source Licences, and app version with build number.
- [ ] Render the policy text **in-app** as selectable, screen-reader-accessible text, not only as an external browser link. A blind user should not be forced out to a browser to read terms.
- [ ] Use Flutter's built-in `LicensePage` for third-party licences; the dependency set (ML Kit, camera, dio, flutter_tts, speech_to_text and others) carries attribution obligations that are currently unmet.
- [ ] Record consent events — which version of the terms was accepted and when — in local storage. The current `cloudConsentGranted` boolean does not record what was agreed to.
- [ ] Surface Safety and Limitations prominently, not buried. The onboarding text "EyeSense is a supplementary visual assistant. It is not a replacement for a cane, guide dog, or personal mobility aid" is the most important sentence in the product and currently appears once, in step 1 of a skippable tutorial.

## D4 — Complete the Play Data Safety declaration

Play requires a per-data-type declaration. Based on the current code, the accurate answers are:

| Data type | Collected | Shared | Purpose | Notes |
| --- | --- | --- | --- | --- |
| Photos | Yes, transient | Yes, with consent | App functionality | Sent to the inference provider for Describe and Ask only; not retained by the app |
| Audio | No | No | — | Captured by the device speech service, not by the app; the recognised text is what the app receives |
| Approximate/precise location | No | No | — | No location permission requested |
| Personal identifiers | No | No | — | No accounts |
| App activity / diagnostics | Yes, optional | No | Diagnostics | Opt-in, local only, never transmitted |
| Device identifiers | No | No | — | — |
| Credentials | Yes, local only | No | App functionality | BYOK key held in `EncryptedSharedPreferences`, never transmitted except to Groq as the authorisation header |

- [ ] Declare photos as collected and shared. Transient processing still counts as collection under Play's definitions when the data leaves the device.
- [ ] Declare data as encrypted in transit (all endpoints are HTTPS; verify after the release cleartext change in [E3](#e3--release-build-and-signing)).
- [ ] State that there is no account, therefore no deletion request mechanism beyond uninstalling and clearing storage — and provide a data-deletion explanation anyway, as Play now requires one.
- [ ] Complete the accessibility declaration honestly; do not claim full screen-reader support until [Part A](#part-a--defect-fixes) and [Part B](#part-b--blind-first-interaction-model) are verified on a device by a blind tester.

## D5 — Medical and assistive-device positioning

- [ ] Keep an explicit, prominent statement that EyeSense is not a medical device, not a mobility aid, and not a navigation aid. This is both an ethical obligation and the primary liability boundary.
- [ ] Keep `OutputPolicy`'s refusal of crossing decisions, clear-path assertions and walking directions, and extend it to the fields it currently misses ([E1](#e1--worker-correctness-and-limits)).
- [ ] Review store listing and promotional copy for any implied safety capability. Phrases suggesting the app can keep a user safe, detect hazards reliably, or guide movement must not appear.
- [ ] Note that marketing an app as an aid for disabled people can attract accessibility-specific regulatory expectations in some jurisdictions; confirm with counsel.

---

# Part E — Backend, build and release

Detail and line references for these are in the audits summarised below. They are reproduced here as actionable steps.

## E1 — Worker correctness and limits

- [ ] **Replace in-memory limits with durable state.** `budgetState` in `worker/src/index.ts` is a module-scope object. Cloudflare runs many isolates per location, each with its own counters, and cold starts reset them. The advertised 30 requests/minute, 10 concurrent and 1,000/day are not enforced. Use Durable Objects or the Rate Limiting API.
- [ ] **Fix the daily reset.** It compares `new Date().getUTCDate()` — day of month, not calendar date — so a budget exhausted on 15 January and left idle is still exhausted on 15 February. Compare a full `YYYY-MM-DD` key.
- [ ] **Fix the concurrency race.** The check and the increment are not atomic, so two in-flight requests can both observe 9 and both proceed.
- [ ] **Extend the output policy to all fields.** `enforceWorkerOutputPolicy` scans `summary`, `answer` and `concernDescription`, but not `objects[]` or `uncertainty`. Prohibited guidance placed in those fields reaches the client and is spoken.
- [ ] **Only replace fields that violated.** A violation in `answer` currently overwrites `concernDescription` as well, discarding legitimate content.
- [ ] **Use a constant-time token comparison** instead of `===`.
- [ ] **Charge the budget after validation, not before**, and apply a lightweight throttle before JSON parsing so authenticated malformed requests cannot be used to bypass accounting.
- [ ] **Bound `UPSTREAM_TIMEOUT_MS`.** An invalid value yields `NaN`, which `setTimeout` treats as 0, aborting immediately.
- [ ] **Cap the base64 image length in the Zod schema**, not only the 1.5 MiB body limit.
- [ ] **Return a real `Retry-After`** computed from the time to the next UTC midnight.
- [ ] **Stop returning raw Zod messages** to clients; log details server-side and return a sanitised message.
- [ ] **Reduce `/health` disclosure.** `ready: false` publicly confirms a misconfigured deployment.
- [ ] **Correct `worker/README.md` §5**, which lists `/v1/reading` and `/v1/conversation` as active while the code returns `ROUTE_DISABLED`.

## E2 — Android configuration

- [ ] **Correct the minSdk claim.** README §5 states API 21; the effective floor is **24**, set by Flutter's default and by `flutter_tts`. Either state 24, or pin it explicitly in `defaultConfig`.
- [ ] **Pin the SDK levels explicitly** rather than inheriting `flutter.minSdkVersion` / `flutter.targetSdkVersion`, so a Flutter upgrade cannot silently change the published compatibility.
- [ ] **Remove `skipDependencyChecks=true`** from `android/gradle.properties` after establishing a compatible toolchain combination.
- [ ] **Track the Gradle wrapper.** `gradlew`, `gradlew.bat` and `gradle-wrapper.jar` are gitignored, so a fresh clone cannot build without regenerating them.
- [ ] **Declare `abiFilters`** in Gradle if a fixed ABI set is required in all build paths, or correct README §5 to say the ABI set comes from the Flutter CLI.
- [ ] **Add `flutter_launcher_icons`** and generate launcher plus adaptive icons.

## E3 — Release build and signing

- [ ] **Configure real release signing.** `android/app/build.gradle.kts` lines 32–38 sign release builds with the debug key, so the `.aab` instructions in README §8 cannot produce a publishable artifact. Add a `release` signing config reading `key.properties`, which is already gitignored.
- [ ] Store the keystore securely outside source control with a documented backup. Losing it means losing the ability to update the listing.
- [ ] Note that users with debug-signed installs must uninstall before accepting the newly signed build, which destroys their local settings and stored BYOK key. Plan and communicate this.
- [ ] Review the **merged** release manifest for permissions and queries, not just the source manifest.
- [ ] Record the source revision, build command and defines, toolchain versions, SDK levels, signer fingerprint and artifact SHA-256 for every candidate.

## E4 — CI and test coverage

The suite is 24 Flutter tests plus 10 Worker tests, all passing. The gaps matter more than the count.

- [ ] **Add widget tests.** There are none, despite `test/widget_test.dart` being so named — it contains model and policy unit tests only. Rename it and add real `testWidgets` coverage.
- [ ] **Add semantics tests** asserting labels, hints, enabled state and traversal order. Every defect in [A3](#a3--connect-the-talkback-hints-which-are-currently-dead-code) is invisible to the current suite.
- [ ] **Add layout tests** at 320 logical pixels and `textScaler` 2.0 for every screen, which would catch [A9](#a9--prevent-the-appbar-overflowing-at-large-text-scales).
- [ ] **Add provider contract tests** for `HostedVisionProvider` and `GroqDirectVisionProvider`. Neither is tested.
- [ ] **Cover the voice command router**, `SceneAgent`, `ConversationAgent`, cancellation races and TTS interruption. `DelayedChunkTtsService` exists in the tests but nothing asserts that Stop halts mid-chunk.
- [ ] **Replace real platform services in `speech_tts_test.dart`** (lines 137–147 construct real `CameraService`, `OcrService` and `CredentialService`) with the fakes already written in `coordinator_test.dart`.
- [ ] **Add an Android assemble job to CI.** It currently runs analysis and unit tests only, so manifest merge failures, missing resources and signing problems surface only on a manual build.
- [ ] **Add Worker tests** for the isolate-bypass, concurrency race, daily-reset and output-policy field gaps above.

---

# Part F — Verification matrix

A change is not complete until its row passes. Device-dependent rows require evidence from real Android hardware, not an emulator.

| # | Scenario | Required outcome | Covers |
| --- | --- | --- | --- |
| 1 | Release build with no `--dart-define` | Hosted mode fails closed with an accessible error; no embedded token in the artifact | A1 |
| 2 | Fresh install, grant camera at first Describe | Description completes on the first activation | A2 |
| 3 | Screen reader explores every home control | Label and hint both announced; busy state announced during operations | A3 |
| 4 | Each workflow in turn | Progress appears only on the activated control | A4 |
| 5 | Full Describe cycle with a screen reader active | No overlapping speech at any point | A5 |
| 6 | Measure control offsets across all states | No control moves between idle, capturing, processing and speaking | A6 |
| 7 | Every speech-rate position | Each produces an audibly distinct rate | A7 |
| 8 | Throttled network, p95 latency | No valid result is discarded as stale; p95 fits the budget with headroom | A8 |
| 9 | All screens at 320 px and 200 % text | No overflow, no clipped essential labels | A9 |
| 10 | 30+ natural utterances per language | Each routes to the intended workflow; read requests never require consent | A10 |
| 11 | Ask flow with a screen reader | Voice reachable without passing through the keyboard; empty submit gives feedback | A11 |
| 12 | Repeated operations and practice captures | No orphaned files; recogniser and TTS released on disposal | A12 |
| 13 | Blind tester, gesture layer | Three core tasks completed without locating any on-screen position | B1 |
| 14 | Blind tester reads a medicine label | Succeeds unaided; guidance never asserts path safety or distance | B2 |
| 15 | Audio feedback set | Every state change is distinguishable without speech | B3 |
| 16 | All themes, all three contrast modes | Body text ≥ 4.5:1, controls and focus ≥ 3:1 | C1, C2 |
| 17 | Keyboard and switch-access traversal | Focus ring visible on every control at ≥ 3:1 | C5 |
| 18 | Settings legal section with a screen reader | Policy and terms readable in-app without a browser | D3 |
| 19 | Data Safety declaration against merged dependencies | No undeclared collection; no linked analytics SDK | D4 |
| 20 | Concurrent Worker load across locations | Configured budget and concurrency cannot be exceeded | E1 |
| 21 | Worker output policy with adversarial responses | Prohibited guidance blocked in every returned field | E1 |
| 22 | Exact signed release candidate | Verified signing, permissions, SDK levels, cold start, offline OCR, secure storage | E3 |
| 23 | Supervised pilot, blind and low-vision users | Core tasks completed independently, without sighted assistance | All |

---

# Part G — Suggested sequencing

Small reviewable batches, each landing with the tests that prove it. Do not defer validation to the end.

**Batch 1 — Containment.** Rotate the token and land [A1](#a1--remove-the-shared-bearer-token-from-the-binary). Keep hosted access restricted until [E1](#e1--worker-correctness-and-limits)'s durable limits and output-policy gaps are closed. Nothing else should precede this.

**Batch 2 — Accessibility defects.** [A3](#a3--connect-the-talkback-hints-which-are-currently-dead-code), [A5](#a5--collapse-the-two-competing-speech-channels-into-one), [A6](#a6--make-stop-genuinely-persistent-and-the-layout-stable), [A7](#a7--make-the-speech-rate-control-functional-across-its-whole-range). These are small, independent, and fix the claims the product is built on. Land the semantics and layout test harness with them, since nothing in this group is currently detectable by CI.

**Batch 3 — Core flow correctness.** [A2](#a2--stop-the-lifecycle-handler-cancelling-the-first-operation), [A4](#a4--show-progress-on-the-control-the-user-actually-activated), [A8](#a8--widen-the-freshness-budget-so-valid-results-are-not-discarded), [A10](#a10--route-voice-commands-on-natural-phrasing), [A12](#a12--release-native-resources-and-delete-temporary-captures). Measure latency before fixing the constants in A8.

**Batch 4 — Worker hardening.** All of [E1](#e1--worker-correctness-and-limits). This gates any widening of hosted access.

**Batch 5 — Design system.** [C1](#c1--fix-the-colorscheme-first) and [C3](#c3--define-and-enforce-scales) first, since every later visual change depends on the tokens. Then [C4](#c4--choose-a-typeface-deliberately), [C5](#c5--focus-and-state-treatment), [C6](#c6--add-the-missing-component-themes). Review [C2](#c2--choose-a-palette-with-a-point-of-view) as a decision before starting.

**Batch 6 — Interaction model.** [B4](#b4--serve-blind-and-low-vision-as-distinct-profiles) and [B5](#b5--fix-output-order-focus-and-progressive-disclosure), then [B1](#b1--replace-target-hunting-with-a-gesture-layer), then [B3](#b3--replace-single-channel-speech-with-structured-audio-feedback) and [B6](#b6--give-the-app-an-audible-identity-at-launch). Land profiles before gestures so the gesture layer has a place to live.

**Batch 7 — Aiming guidance.** [B2](#b2--add-real-time-aiming-guidance-before-capture) is the largest single piece of new work and the biggest functional differentiator. Treat it as its own vertical slice with device evidence.

**Batch 8 — Screens and polish.** [C7](#c7--rework-the-screens), [C8](#c8--motion), [A9](#a9--prevent-the-appbar-overflowing-at-large-text-scales), [A11](#a11--make-the-ask-flow-voice-first), [A13](#a13--remove-the-blanket-deprecation-suppression), [A14](#a14--delete-the-dead-theme-tokens).

**Batch 9 — Legal and store.** All of [Part D](#part-d--legal-privacy-and-store-compliance), with legal review started early since it is not on the engineering critical path and will take calendar time.

**Batch 10 — Release.** [E2](#e2--android-configuration), [E3](#e3--release-build-and-signing), [E4](#e4--ci-and-test-coverage), then the [Part F](#part-f--verification-matrix) matrix and a supervised pilot.

## Source of findings

Application-layer defects in Part A were found by direct inspection on 18 October 2026. Backend findings in E1 and Android findings in E2–E3 were produced by two parallel audit passes over `worker/` and `app/android/` respectively; their full reports include additional low-severity items not reproduced here.
