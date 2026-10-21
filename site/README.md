# EyeSense public site — Vercel

Static, accessible pilot information and legal pages for the intended domain <https://eyesense.dpdns.org>. No client JavaScript, API keys, camera access, sign-up form, analytics or AI calls. Vercel hosts this website; the Android app's AI requests continue to use the separate Cloudflare Worker or an explicitly selected direct provider.

## Pages

| Route | Source |
| --- | --- |
| `/` | `site/index.md` |
| `/privacy` | `app/assets/legal/privacy-policy.md` |
| `/terms` | `app/assets/legal/terms-of-service.md` |
| `/sw` | `site/index.sw.md` |
| `/sw/privacy` | `app/assets/legal/privacy-policy.sw.md` |
| `/sw/terms` | `app/assets/legal/terms-of-service.sw.md` |
| `/download/android-debug` | Temporary redirect to the pinned GitHub prerelease APK in `vercel.json` |
| `/downloads.json` | Public version, SHA-256, size and release URLs from `site/downloads.json` |

The legal documents are the same assets the Android app renders in Settings → Legal. Fonts are copied from `app/assets/fonts` and served locally, not from a third-party CDN. Pages include language alternates, a language switcher, a focusable skip target and native accessible tables. Respect browser text size and preferred colour scheme; all translations still need fluent/legal review.

## Local build and verification

From `site/`, with Node.js 22 or a compatible newer version:

```sh
npm ci
npm run check
```

`check` builds `dist/` and runs dependency-free Node tests for all six pages, internal links/assets, privacy/terms versions, language markup, table semantics, preview routing, redirects, pinned debug-download metadata and security settings. These automated checks are not a real screen-reader audit.

For manual preview, run `node preview.mjs` and visit `http://127.0.0.1:4321`. It binds to loopback only. Stop it with Ctrl+C when done. The preview resolves `/sw` to `sw/index.html`, supports clean URLs and mirrors the configured redirects and common security headers; it is not a substitute for checking actual Vercel behavior.

`dist/` is generated and ignored by Git. Do not copy APKs, `.dev.vars`, `.env` or credentials into it.

## Deploy through Vercel's Git integration

1. Make the intended source changes available in `RealDevRay/eyesense` on GitHub using your normal review/commit/push process. Local edits are not automatically uploaded. No commit or push is performed by these instructions.
2. Import that repository into the intended Vercel account/team. Do not create a second production project if one already hosts the domain.
3. Configure the project:

   | Setting | Value |
   | --- | --- |
   | Framework Preset | Other |
   | Root Directory | `site` |
   | Node.js version | 22.x |
   | Install Command | `npm ci` |
   | Build Command | `npm run check` |
   | Output Directory | `dist` |

   Build/install/output settings are also explicit in `site/vercel.json`.
4. In Root Directory settings, **enable “Include source files outside of the Root Directory in the Build Step”**. The build deliberately reads `../app/assets/legal` and `../app/assets/fonts`. Do not assume this is enabled by default. See [Vercel monorepo FAQ](https://vercel.com/docs/monorepos/monorepo-faq#can-i-share-source-files-between-projects-are-shared-packages-supported).
5. Deploy a preview, check all six routes, language switching, keyboard navigation, 200% text and a narrow mobile viewport. Confirm headers/redirects in the actual deployment, not only locally.
6. Deliberately promote the reviewed version to production. Under Settings → Domains, add `eyesense.dpdns.org` and apply **the exact DNS record Vercel provides**. Do not guess a DNS target. Confirm HTTPS and all six routes on the custom domain.

**No environment variables or provider keys are required for this site.** Do not add `GROQ_API_KEY`, `MISTRAL_API_KEY`, a hosted token or a Supabase service-role/secret key to this static project's build variables. Static build output is public; adding a key here does not securely connect the Android app to AI.

Local verification completed with Node.js 26.10.0: `npm ci` succeeded (0 reported vulnerabilities), `npm run check` built six pages and passed all **15 tests**. The Node.js 22 Vercel build still needs verification on the selected project.

A public Vercel URL is obtained only after deploying to an authenticated, selected project. Local build success does not mean a deployment occurred. The Vercel CLI/project link was not available during local setup; no production domain or DNS changes were made.

## After deployment

- Check `/`, `/privacy`, `/terms`, `/sw`, `/sw/privacy` and `/sw/terms` return the intended language, not a fallback 404.
- Check `/privacy-policy` and `/terms-of-service` redirect correctly.
- Confirm the CSP, Permissions-Policy and content-type headers; verify there are no third-party requests or secrets in output.
- Confirm the legal pages show `1.1-pilot`, including Mistral/sensor/reconsent disclosures.
- Complete the outstanding review in `docs/legal/OUTSTANDING.md`. `/privacy/history` and `/sw/privacy/history` still redirect to the current policy; publish archived notices before claiming history is available.
- Confirm `/download/android-debug` redirects to the intended GitHub prerelease asset, not an old APK or a mutable latest-release URL. The binary lives in GitHub Releases, not the Vercel static build or Git history.
- Keep pilot access wording truthful: this is a public **debug/test-only** download, not an independent-user launch or pilot approval; live Groq vision and physical TalkBack checks remain gates.

## Updating the test download

`site/downloads.json` records the pinned GitHub prerelease, app-source commit, exact bytes and SHA-256. Both landing pages show installation warnings, the same checksum and links to the release notes/checksum asset. `vercel.json` redirects `/download/android-debug` to that exact asset. Tests keep these values consistent; they do not fetch the large APK or prove a remote upload exists.

Publish and verify a GitHub prerelease containing the APK, `SHA256SUMS` and `build-info.json` **before** pointing the website at it. Update the metadata, redirect and both language pages together, run `npm run check`, then push the site changes. Never replace a binary under an existing published tag without issuing a new version and checksum. The current artifact is Android 7.0/API 24+, debug/test-signed and approximately 214 MiB. Its app source is committed separately from the site update; backend edits/deployment are not implied.

See [hosting and secrets](../docs/hosting-and-secrets.md) for the recommended Vercel/Cloudflare architecture and where Supabase could fit later.
