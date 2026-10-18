# Terms of Use — moved

The Terms of Use now live at **`app/assets/legal/terms-of-service.md`**.

It was moved there because the app bundles it as an asset and renders it in
Settings → Legal, and `site/build.mjs` publishes that same file to
<https://eyesense.dpdns.org/terms>. Keeping one copy is the only way the in-app
text and the published page cannot drift apart.

Edit `app/assets/legal/terms-of-service.md`. Do not reintroduce a copy here.

Outstanding legal questions and the interim drafting choices are recorded in
[`OUTSTANDING.md`](./OUTSTANDING.md).
