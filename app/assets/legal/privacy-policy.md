# EyeSense Privacy Policy

**Effective date:** 18 October 2026

**Last updated:** 18 October 2026

**Version:** 1.0

## 1. Who we are

EyeSense ("the app") is an AI visual assistance application for blind and low-vision users, published by DevRay ("we", "us").

You can contact us about anything in this policy at **info@devray.qzz.io**. If you need this policy in another format, or help exercising any right described here, contact us and we will assist.

## 2. Summary

- EyeSense has no user accounts. We do not ask for your name, email address or phone number.
- **Read Text works entirely on your device.** Nothing is sent anywhere.
- **Describe Scene and Ask a Question send one photograph off your device**, and only after you have explicitly turned on cloud processing.
- When you use a cloud feature, our service sees your IP address in order to limit abuse. See §3.7.
- We do not use advertising, analytics, attribution or tracking services.
- We do not sell or rent your data, and we do not use it to train AI models.
- Technical diagnostic logging is off unless you turn it on, and stays on your device.

## 3. What the app processes, and when

### 3.1 Camera images

| Feature | What happens to the image |
| --- | --- |
| **Read Text** | Captured, analysed on your device by Google ML Kit, then deleted. No network connection is used or required. |
| **Describe Scene** | Captured, resized, and sent to the AI provider you have configured. Deleted from your device after the operation. |
| **Ask a Question** | As Describe Scene, together with your question. |

Describe Scene and Ask a Question only operate after you turn on **Cloud Processing Consent**. Until you do, both features are unavailable and no image leaves your device. You can withdraw that consent at any time in Settings, which immediately stops further images being sent.

Images are held on your device only for as long as the operation takes, and are deleted afterwards. We do not maintain a history of your photographs, and the app has no gallery or saved-results feature.

### 3.2 Your question text

When you use Ask a Question, the words of your question are sent with the image to your configured AI provider. Questions are not stored by the app after the answer is delivered.

### 3.3 Microphone and speech

When you use a voice feature, the app asks your Android device's own speech recognition service to listen and convert what you said into text. **The app receives only the resulting text; it never records, stores or transmits audio itself.**

Important: the conversion is performed by your device's speech provider, which on most Android devices is supplied by Google. Depending on your device, its language settings and its configuration, that service may process your speech on the device or on its provider's servers. That processing is governed by your device provider's privacy policy, not by this one. You can check and change which speech service your device uses in your Android settings.

### 3.4 Your AI provider credentials

If you use "Bring Your Own Key" mode, your personal Groq API key is stored on your device using Android `EncryptedSharedPreferences`. It is never sent to us. It is transmitted only to Groq, as the authorisation header on your own requests. You can remove it at any time in Settings.

In hosted mode, the app uses an access token for our service. This identifies the app, not you.

### 3.5 Diagnostic logs

Diagnostic logging is **off by default**. If you turn it on, the app writes technical records to a file on your device containing operation durations, error codes and token counts.

These logs never contain camera images, audio, your questions, recognised text, or API keys. They stay on your device. They are not transmitted to us. You can view the file size, export it, or delete it at any time in Settings. Exporting shares the file wherever you choose to send it, at which point this policy no longer governs it.

### 3.6 Your settings

Your preferences — language, speech rate, haptics, automatic reading, theme, consent state, tutorial progress — are stored locally on your device. They are not transmitted.

### 3.7 Your IP address, in hosted mode

When you use Describe Scene or Ask a Question in hosted mode, your request reaches our service over the internet, so our service necessarily receives **your IP address**.

We use it for one purpose: to count how many requests a single client has made in the last minute, so that no one person can exhaust the service for everyone else. That counter is held in temporary server-side storage and is **cleared automatically at 00:00 UTC each day**. We also keep a global daily request total, which is not linked to any client.

We do not use your IP address to identify you, build a profile, infer your location, or link your requests to each other beyond that one-minute window. We do not log your IP address to a permanent record.

This does not apply in "Bring Your Own Key" mode, where your requests go directly from your device to Groq and never reach our service.

## 4. What we do not do

- We do not create user accounts or profiles.
- We do not collect your location. The app requests no location permission.
- We do not use cookies, advertising identifiers or device fingerprinting.
- We include no advertising, analytics, attribution or crash-reporting services.
- We do not sell, rent or trade any data.
- We do not use your images, questions or any other content to train AI models.
- We do not track you across other apps or websites.

## 5. Who else is involved

When you use a cloud feature, your image and question pass through third parties. We have chosen them, but we do not control their systems.

| Party | Role | What they receive | Their privacy policy |
| --- | --- | --- | --- |
| **Cloudflare, Inc.** | Operates our API proxy at the network edge, in hosted mode | The request as it passes through, including the image, and your IP address | [cloudflare.com/privacypolicy](https://www.cloudflare.com/privacypolicy/) |
| **Groq LLC** | Performs the AI visual analysis | The image and your question | [groq.com/privacy-policy](https://groq.com/privacy-policy) |
| **Google LLC** | Provides on-device text recognition (ML Kit) and, via your device, text-to-speech and speech recognition | ML Kit receives nothing over the network. Speech recognition may receive your speech, as described in §3.3 | [policies.google.com/privacy](https://policies.google.com/privacy) |

**Please read this carefully:** once a request has been received by an AI provider, it is subject to that provider's own processing and retention terms, and **we cannot recall it**. Stopping an operation in the app cancels our request; it does not necessarily stop processing that the provider has already begun, or any charge it incurs.

In "Bring Your Own Key" mode, your requests go directly from your device to Groq under **your own** account, subject to your agreement with Groq and your account's quotas and charges.

We reviewed these providers' published policies on 18 October 2026. Their terms may change; we are not responsible for those changes, and we encourage you to check them.

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
| Your settings and stored API key | On your device until you clear them or uninstall the app |
| Per-client request counters keyed to your IP address | Cleared automatically at 00:00 UTC each day — see §3.7 |
| Global daily request total | Reset at 00:00 UTC each day; not linked to any client |

## 8. Security

- All network connections use HTTPS. The app's Android network security configuration forbids unencrypted traffic in release builds.
- Your personal API key is stored in Android `EncryptedSharedPreferences`.
- `android:allowBackup="false"` prevents your stored credentials being copied into cloud device backups.
- Our hosted service holds provider credentials as server-side secrets; they are not present in the app.

No system is perfectly secure. We cannot guarantee absolute security, and you should not use EyeSense to photograph material you consider highly sensitive.

## 9. Children

EyeSense is not directed at children, and we do not knowingly process data from children. If you believe a child has used the app in a way that concerns you, contact us at info@devray.qzz.io and we will assist.

## 10. International transfers

The AI providers and edge infrastructure described in §5 operate servers in other countries, including the United States. If you use a cloud feature, your image and question will be transferred internationally, and your IP address will be visible to our edge provider.

If you prefer that nothing leaves your device or your country, use **Read Text**, which is entirely local, and leave cloud processing consent turned off.

## 11. Your rights

Depending on where you live, you may have rights to access, correct, delete, restrict or object to the processing of your personal data, to withdraw consent, and to complain to a regulator.

Because EyeSense has no accounts and we hold no identifiable record of you, most of these rights you can exercise directly on your device:

- **Withdraw consent:** turn off Cloud Processing Consent in Settings.
- **Delete your data:** delete diagnostic logs and remove your API key in Settings, or uninstall the app, which removes all local data.
- **Stop all transfers:** leave cloud consent off and use Read Text only.

For anything you cannot do yourself, contact **info@devray.qzz.io** and we will respond within **30 days**. We may be unable to act on a request for data we cannot link to you — in most cases we simply do not hold any.

You may also complain to the data protection authority in your country.

## 12. Changes to this policy

We will update this policy when the app's behaviour changes. We will revise the effective date, keep prior versions available at [eyesense.dpdns.org/privacy/history](https://eyesense.dpdns.org/privacy/history), and, for changes that materially affect how your data is used, notify you in the app and ask again for consent where required.

## 13. Accessibility of this policy

This policy is available in the app as screen-reader-accessible text, and at [eyesense.dpdns.org/privacy](https://eyesense.dpdns.org/privacy). If you need it in another format or another language, contact us and we will provide one.
