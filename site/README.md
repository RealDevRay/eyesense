# EyeSense public site

Serves the legal pages that Google Play requires and that the app links to, at
<https://eyesense.dpdns.org>.

| Route | Content |
| --- | --- |
| `/` | Landing page, from `index.md` |
| `/privacy` | Privacy Policy, from `app/assets/legal/privacy-policy.md` |
| `/terms` | Terms of Use, from `app/assets/legal/terms-of-service.md` |

## Why it is built this way

The two legal documents are **not** duplicated here. `build.mjs` reads the same
markdown files that `pubspec.yaml` bundles as app assets and that
`LegalDocumentScreen` renders in Settings → Legal. Edit the markdown once and
both the app and this site change together, which is the only way to keep a
published policy and an in-app policy from drifting apart.

The output is static HTML with no JavaScript, and the Atkinson Hyperlegible
fonts are copied from `app/assets/fonts` and self-hosted. A privacy policy page
that itself calls out to a third-party font CDN is a bad look, so it doesn't.
The `Content-Security-Policy` in `vercel.json` enforces that: `default-src
'none'` with only same-origin images, styles and fonts allowed.

## Local build

```bash
cd site
npm install
npm run build
node preview.mjs    # http://localhost:4321
```

`preview.mjs` is a local-only static server that mirrors the `cleanUrls`
behaviour, so `/privacy` and `/terms` resolve during preview exactly as they
will in production. Vercel serves `dist/` itself and never runs it.

`npm run build` writes `dist/index.html`, `dist/privacy.html`,
`dist/terms.html`, `dist/styles.css`, `dist/mark.svg` and `dist/fonts/`.

## Deploying to Vercel

Push the repository to GitHub, then import it in Vercel and set:

| Setting | Value |
| --- | --- |
| Framework Preset | Other |
| Root Directory | `site` |
| Build Command | `npm run build` |
| Output Directory | `dist` |
| Install Command | `npm install` |

Root Directory must be `site`, but the build still reaches up into
`app/assets/legal` and `app/assets/fonts` for its sources. Leave
"Include files outside the root directory" enabled — it is on by default, and
the build fails without it.

`cleanUrls` is on, so `/privacy` serves `privacy.html` without the extension.

### Domain

Add `eyesense.dpdns.org` under Project → Settings → Domains and create the DNS
record Vercel shows you. Once it resolves, confirm these three URLs load:

- <https://eyesense.dpdns.org/>
- <https://eyesense.dpdns.org/privacy>
- <https://eyesense.dpdns.org/terms>

The privacy URL is the one to paste into the Play Console listing.

## Before submitting to Play

`/privacy/history` currently redirects to `/privacy`, because there is only one
version. Section 12 of the policy promises prior versions will be kept there, so
when the policy is first revised, publish the superseded version at that path
and turn the redirect off.

Outstanding legal items are tracked in `docs/legal/OUTSTANDING.md`. Resolve
those before treating these pages as final.
