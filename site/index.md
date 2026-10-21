# EyeSense

**Your world, described.**

EyeSense is a prototype visual-information app for blind and low-vision users, including people using the same phone with a sighted helper. It describes one camera image at a time and can be wrong.

## What it does

- **Read Text** recognises printed text on the device without uploading the image for OCR. System speech recognition and text-to-speech are separate: they may need internet, and offline playback needs an installed offline voice.
- **Describe Scene** takes one photograph and requests a description.
- **Ask a Question** lets you speak or type a question about a new photograph.

Home offers labelled Describe / Read / Ask buttons with normal TalkBack controls, Repeat and a persistent Stop. Camera preview is optional; helper profiles start with audible results.

**Settings → Phone & capture guidance** offers optional local accelerometer/gravity, gyroscope, ambient-light and front-proximity checks. Brief checks can give hold-steady, low-light or covered-front-sensor cues; missing sensors never block capture. Capability discovery does not sample. Samples are temporary and never uploaded. These checks do not measure obstacle distance, confirm page framing or provide navigation; no GPS or compass is used.

Describe and Ask require explicit cloud-AI consent. Hosted mode routes through the EyeSense Worker to Groq. With your own key, you explicitly choose Groq, OpenAI, Google Gemini or optional Mistral. There is no silent provider fallback. An optional generated-sample vision test requires separate confirmation and may incur a charge on your account.

## A simple flow, with help when you want it

1. Sit or stand still in a familiar indoor space. Open EyeSense on your Android phone, or ask a trusted helper to set it up with you.
2. Choose **Read Text**, **Describe Scene** or **Ask a Question**. Read Text OCR stays on your device; Describe and Ask need internet, working AI access and your explicit cloud consent.
3. Listen to or read the result. Use **Repeat** to hear it again and **Stop** to stop the current task or speech. Treat AI answers as information to verify, not instructions to move.

TalkBack users can use normal focus and activation gestures. Low-vision users can use their Android font/display settings. A helper can use the optional camera preview, but a preview is not required to start a task. Physical-phone accessibility checks are still required before participant testing.

## Pilot access

The ten-user pilot is **supervised and not yet open for independent use**. A debug/test download is available below for developer evaluation, not a production launch or pilot approval. Cloud vision access and real-device accessibility must pass before participant sessions. There is no sign-up form on this site.

### Download the Android debug test build

[Download EyeSense 1.0.0 debug APK — Android 7.0 or newer, 214 MiB](/download/android-debug)

This link opens GitHub's release download. **Debug/test-signed, version 1.0.0+1; use a dedicated test phone and non-sensitive objects.** The APK has no supplied API key or hosted access token. Configure your connection securely in Settings. **Groq image tests returned 403; cloud vision is not verified. Physical-phone TalkBack testing is still pending.** It is not for navigation, obstacle detection or medical decisions.

Read the [debug release notes and source information](https://github.com/RealDevRay/eyesense/releases/tag/pilot-debug-2026-10-21) before installing. Android may ask you to allow installation from your browser/file manager; do so only if you trust this build, and turn that permission off afterwards. Do not disable device security scanning. Updating an installation signed with a different key can require uninstalling and losing local settings/keys.

[Download SHA256SUMS](https://github.com/RealDevRay/eyesense/releases/download/pilot-debug-2026-10-21/SHA256SUMS). Expected APK SHA-256:

`bcaaceba730891703102ca2f20008ce9c35f3845d39ec373b6ce18c7b022935a`

For pilot questions or accessible information, [email the EyeSense team](mailto:info@devray.qzz.io). Do not email API keys, personal photographs, medical information or identity documents. Email is handled by your email provider; this site does not collect form submissions.

## What it is not

EyeSense is **not a mobility, navigation or medical aid**. Do not use it to decide when to cross a road, whether a path is safe, or how far away an obstacle is. Its prompts and phrase filters do not guarantee that every unsafe answer is blocked.

Use your cane, guide dog, training and judgement—not an AI description—as your mobility support. Read section 2 of the [Terms of Use](/terms).

## Privacy, briefly

There are no user accounts, advertisements or analytics. We do not use your content to train models; selected providers apply their own processing and retention terms. **Mistral Free-mode inputs/outputs may be used for training unless you opt out in your Mistral account; Free mode has no zero-data-retention option.** In hosted mode, raw-IP request counters are persisted. Expired one-minute windows and 60-second concurrency reservations are pruned by later operations, not a scheduled deletion timer; entries may remain while idle. BYOK keys are stored separately and sent only to the selected provider.

The [Privacy Policy](/privacy) explains images, questions, system speech, sensors, credentials, third parties and retention. The **1.1-pilot** update requires an explicit new cloud opt-in for older or missing accepted terms versions; accepting terms alone does not restore cloud consent. Local Read Text OCR remains available.

Hosted pilot defaults are shared service limits of **6 requests/minute, 2 concurrent and 100/day**, not per-user allowances or guaranteed free provider capacity. Cloudflare runs the proxy/budget service, not Workers AI inference.

## Status

This is a prototype, not a release certification. Automated tests do not replace physical-device accessibility testing. A local live Groq sample request on 21 October 2026 returned HTTP 403; successful end-to-end inference remains to be verified.

These documents are also bundled under Settings → Legal:

- [Privacy Policy](/privacy)
- [Terms of Use](/terms)

[Kiswahili](/sw) is available. The translations need fluent legal review; English is the reference where they differ.

Questions or requests for another document format: [info@devray.qzz.io](mailto:info@devray.qzz.io)
