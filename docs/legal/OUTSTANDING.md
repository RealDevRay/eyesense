# Outstanding legal items

The published documents at <https://eyesense.dpdns.org> are complete enough to
submit to Google Play: they contain no placeholders and every factual claim was
checked against the code on 18 October 2026. This file records what is still
genuinely unresolved, and the interim choices made so that the pages could be
published at all.

Sources of truth: `app/assets/legal/privacy-policy.md` and
`app/assets/legal/terms-of-service.md`. The app bundles them as assets and the
site renders the same files, so edit them there and nowhere else.

## 1. Needs a lawyer

Neither document has been reviewed by a qualified lawyer. The following are the
parts most likely to need changing.

- **Publishing entity.** Both documents name "DevRay" with no legal form and no
  registered address, inferred from the `com.devray.eyesense` application ID and
  the `devray.qzz.io` contact domain. If DevRay is a registered company, its
  full legal name and registered address should appear in §1 of the policy and
  §1 of the terms. Several jurisdictions require a controller's physical address
  in a privacy notice, not just an email.
- **Disclaimers and limitation of liability** (terms §8, §9). These are drafted
  in the usual "to the fullest extent permitted by law" form with a
  non-excludable carve-out. How much of this survives varies widely by
  jurisdiction, and consumer-protection rules may override it entirely.
- **Indemnity** (terms §10). Retained, but worth a deliberate decision about
  whether an indemnity clause is appropriate in a free accessibility app aimed
  at a vulnerable user group.
- **Children's age threshold** (policy §9). The section now says the app is not
  directed at children without naming an age, because the threshold is
  jurisdiction-dependent (13 under COPPA, 13–16 under GDPR, different again
  elsewhere). Once the operating jurisdiction is fixed, state the age.

## 2. Deliberate interim choices

These are not placeholders. They are decisions that let the documents be
published without inventing facts, and each should be revisited.

- **Governing law** (terms §13) says the law of the user's own country of
  residence, and that they may sue locally. This is accurate and
  consumer-friendly but **unfavourable to the publisher** — it exposes DevRay to
  proceedings anywhere. The usual alternative is to name DevRay's own
  jurisdiction and courts, preserving mandatory consumer protections. This was
  chosen only because naming a jurisdiction would have been a fabrication.
- **Supervisory authority** (policy §11) says "the data protection authority in
  your country" rather than naming one, for the same reason.
- **International transfers** (policy §10) states the fact that transfers occur
  and where, but claims no specific transfer mechanism. If the app operates
  somewhere that requires a lawful transfer basis — standard contractual
  clauses, an adequacy decision, or explicit consent — §10 must say which.
- **Liability cap** (terms §9) is expressed as the greater of what the user paid
  (nil, while free) and the statutory minimum, rather than a figure. Revisit if
  the app is ever charged for.
- **Response period** (policy §11) is 30 days, which satisfies the common
  statutory maximum. Confirm against the operating jurisdiction.

## 3. Verified on 18 October 2026

Recorded so the next review knows what was actually checked rather than assumed.

- **Groq's legal entity is "Groq LLC"**, not "Groq, Inc." as the earlier draft
  stated. Corrected. Privacy policy: <https://groq.com/privacy-policy>,
  effective 12 November 2025.
- **Cloudflare, Inc.** privacy policy: <https://www.cloudflare.com/privacypolicy/>,
  effective 4 November 2025.
- **Google LLC** privacy policy: <https://policies.google.com/privacy>.
- **IP address processing was previously undisclosed.** `worker/src/index.ts`
  keys its rate limiter on the raw `CF-Connecting-IP` header and persists it in
  a Durable Object. The earlier draft described this only as "minimal technical
  information about request volumes", which understated it. The policy now
  discloses it explicitly in §3.7, §6 and §7.
- **Retention of that counter is bounded.** `rollDay()` in
  `worker/src/budget.ts` clears the per-client `minutes` map whenever the UTC
  day key changes, so per-IP entries do not persist past 00:00 UTC. §3.7 and §7
  state this.
- Read Text makes no network call; ML Kit recognition is on-device.
- Diagnostic logging defaults to off and never leaves the device.
- `allowBackup="false"` and the release network security config are both present.

## 4. Still to do, not legal

- **Kiswahili translations** of both documents. The app offers Kiswahili, so
  publishing English-only legal text is a real accessibility gap for part of the
  intended audience.
- **Play Data Safety declaration** must match the policy, and in particular must
  now declare that an IP address is collected for abuse prevention and not
  linked to a user.
- **Safety section surfaced in onboarding**, not only in the terms. A blind user
  who never opens Settings → Legal should still hear that this is not a mobility
  aid.
- **`/privacy/history`** redirects to `/privacy` while only one version exists.
  Policy §12 promises prior versions live there, so publish the superseded
  version and drop the redirect at the first revision.
