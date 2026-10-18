# Google Play Data Safety declaration

What to enter in **Play Console → App content → Data safety**, with the reason for
each answer and where in the code or the policy it is grounded.

Keep this file in step with `app/assets/legal/privacy-policy.md`. Play compares the
declaration against the policy, and a mismatch is a listing rejection. If you change
what the app sends, change both.

**Privacy policy URL:** `https://eyesense.dpdns.org/privacy`

Play's definitions, which the answers below depend on:

- **Collected** means transmitted off the device. On-device processing is *not*
  collection, however sensitive the data.
- **Shared** means transferred to a third party. Transfer to a service provider
  acting on your instructions is excluded — see the judgement call in §4.
- **Processed ephemerally** means held in memory only, for no longer than needed to
  service the request.

## 1. Overview answers

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** | Describe Scene and Ask a Question transmit a photograph and question text. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | `android:networkSecurityConfig` forbids cleartext; all provider calls are HTTPS. |
| Do you provide a way for users to request that their data be deleted? | **No** | Nothing is retained to delete. The app has no accounts, keeps no server-side record, and all local data goes with an uninstall. Policy §11. |
| Does your app have an account creation feature? | **No** | No accounts exist, so the account-deletion URL requirement does not apply. |

## 2. Data types to declare as collected

### Photos and videos → Photos

| Field | Answer |
| --- | --- |
| Collected | **Yes** |
| Shared | **Yes** — see §4 |
| Processed ephemerally | **Yes** |
| Required or optional | **Optional** — "Users can choose whether this data is collected" |
| Purpose | **App functionality** only |

Grounding: `agent_coordinator.dart` refuses every cloud path with
`ErrorCode.cloudConsentRequired` unless `preferencesService.cloudConsentGranted` is
true, so collection cannot happen until the user turns it on, and turning it off
stops it. Images are deleted after each operation and the app has no gallery.
Policy §3.1.

Do **not** select any purpose beyond app functionality. There is no analytics,
advertising, personalisation or fraud-prevention use of the image.

### App activity → Other user-generated content

| Field | Answer |
| --- | --- |
| Collected | **Yes** |
| Shared | **Yes** — see §4 |
| Processed ephemerally | **Yes** |
| Required or optional | **Optional** |
| Purpose | **App functionality** only |

This is the question text the user asks about a photograph. It travels with the
image and is not stored after the answer is delivered. Policy §3.2.

## 3. Data types to declare as NOT collected, and why

| Play data type | Answer | Why |
| --- | --- | --- |
| Audio files → Voice or sound recordings | **Not collected** | The app never receives audio. It calls the Android speech service and receives text. See the judgement call in §4. |
| Location → Approximate / Precise | **Not collected** | No location permission is requested, and the IP address is never resolved to a location. See §5. |
| Personal info → Name, Email, User IDs | **Not collected** | No accounts, no registration, no identifiers requested. |
| App info and performance → Crash logs, Diagnostics | **Not collected** | Diagnostic logging is off by default and writes to a local file that is never transmitted. Export is a user-initiated share, which Play excludes. Policy §3.5. |
| Device or other IDs | **Not collected** | No advertising ID, Android ID, or installation ID is read or sent. |
| Files and docs | **Not collected** | The app reads no user files. |
| Contacts, Calendar, Messages, Health, Financial, Web browsing | **Not collected** | No such access exists in the app. |

The recognised text from **Read Text** is not declared: Google ML Kit runs the
recognition on the device and the result is never transmitted. Policy §3.1.

The stored Groq API key in Bring-Your-Own-Key mode is not declared either. It is
the user's own credential, held in `EncryptedSharedPreferences`, sent only to Groq
as the authorisation header on the user's own request, and never to us. Policy §3.4.

## 4. Two judgement calls to confirm before submitting

Both of these are defensible readings rather than settled facts, and both are
recorded in `docs/legal/OUTSTANDING.md` for the same reviewer.

**Sharing, for photos and question text.** Play excludes transfers to a service
provider processing on your behalf. Cloudflare plausibly qualifies: it proxies the
request and retains nothing of it for us. Groq is the harder case — the policy
itself states that retention there is governed by Groq's terms and that we cannot
recall a request (§5). Where we cannot assert control over retention, we should not
claim the service-provider exclusion, so **declare these as shared**. This is the
conservative answer; an under-declaration is a policy violation, an
over-declaration is not.

**Audio.** The app uses the platform speech recogniser and only ever holds the
transcribed text, so it does not collect voice recordings. But on many devices that
recogniser sends speech to Google's servers, and a reviewer may read the user's
experience as "the app sent my voice somewhere". The app's position is already
disclosed in plain terms in policy §3.3. If the reviewer prefers caution, declare
**Audio files → Voice or sound recordings** as collected and shared, ephemeral,
optional, app functionality only.

## 5. The IP address row

Play's data type list has **no IP address entry**, so there is no field to fill in —
which is exactly why this needs writing down rather than leaving to inference.

- Play's *Device or other IDs* covers advertising IDs, Android ID, IMEI, MAC and
  installation IDs. An IP address is none of these, so nothing is declared there.
- An IP address *would* require declaring **Approximate location** if it were used
  to derive location. It is not. The Worker reads `CF-Connecting-IP` solely as the
  key for a per-client request counter, so nothing is declared under Location.
- The counter lives in a Durable Object and is cleared at the UTC day boundary;
  there is no permanent IP log. Policy §3.7 and §7.

So: **no Data Safety entry, and a deliberate one.** The processing is disclosed in
the privacy policy because it is real, and Play requires the policy to be complete
even where the form has no matching field.

This applies to hosted mode only. In Bring-Your-Own-Key mode the request goes from
the device to Groq and never reaches our service.

## 6. Before you submit

- [ ] Re-read `app/assets/legal/privacy-policy.md` and confirm every row above
      still matches it.
- [ ] Confirm the two judgement calls in §4 with the reviewer named in
      `docs/legal/OUTSTANDING.md`.
- [ ] Check that the policy URL serves the English page and that
      `https://eyesense.dpdns.org/sw/privacy` serves the Kiswahili one.
- [ ] Confirm the consent gate still blocks every cloud path, by running the
      agent coordinator tests rather than by reading the setting.
