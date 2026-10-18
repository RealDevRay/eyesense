import { marked } from "marked";
import { mkdir, readFile, writeFile, copyFile, readdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "..");
const legal = join(repo, "app", "assets", "legal");
const out = join(here, "dist");

// The app bundles these same files as assets and renders them in
// Settings -> Legal, so the published page and the in-app text cannot drift.
const pages = [
  { slug: "privacy", source: "privacy-policy.md", title: "Privacy Policy" },
  { slug: "terms", source: "terms-of-service.md", title: "Terms of Use" },
];

// Tables here carry real obligations, so they must keep their native roles:
// styling the table itself as a block strips row and column association from
// the accessibility tree. Scrolling goes on a focusable wrapper instead, so a
// keyboard user can reach it on a narrow screen.
const wrapTables = (html) =>
  html.replaceAll(
    "<table>",
    '<div class="table-wrap" role="region" aria-label="Table, scrolls horizontally" tabindex="0"><table>',
  ).replaceAll("</table>", "</table></div>");

const shell = ({ title, body, canonical }) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — EyeSense</title>
<link rel="canonical" href="https://eyesense.dpdns.org/${canonical}">
<meta name="description" content="${title} for EyeSense, an AI visual assistance app for blind and low-vision users.">
<link rel="icon" href="/mark.svg" type="image/svg+xml">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header>
  <a class="brand" href="/">
    <img src="/mark.svg" alt="" width="40" height="40">
    <span class="wordmark"><span>Eye</span><strong>Sense</strong></span>
  </a>
  <nav aria-label="Legal documents">
    <a href="/privacy">Privacy</a>
    <a href="/terms">Terms</a>
  </nav>
</header>
<main id="main">
${body}
</main>
<footer>
  <p>EyeSense is published by DevRay. Questions about this page: <a href="mailto:info@devray.qzz.io">info@devray.qzz.io</a></p>
  <p>These documents are also available inside the app under Settings &rarr; Legal, as screen-reader-accessible text.</p>
</footer>
</body>
</html>
`;

await mkdir(out, { recursive: true });
await mkdir(join(out, "fonts"), { recursive: true });

for (const page of pages) {
  const md = await readFile(join(legal, page.source), "utf8");
  const html = shell({
    title: page.title,
    canonical: page.slug,
    body: wrapTables(marked.parse(md)),
  });
  await writeFile(join(out, `${page.slug}.html`), html, "utf8");
}

const index = await readFile(join(here, "index.md"), "utf8");
await writeFile(
  join(out, "index.html"),
  shell({ title: "Accessible AI visual assistance", canonical: "", body: wrapTables(marked.parse(index)) }),
  "utf8",
);

for (const asset of ["styles.css", "mark.svg"]) {
  await copyFile(join(here, asset), join(out, asset));
}

// Self-hosted so that reading the privacy policy makes no third-party request.
const fonts = join(repo, "app", "assets", "fonts");
for (const file of await readdir(fonts)) {
  if (file.endsWith(".ttf")) await copyFile(join(fonts, file), join(out, "fonts", file));
}

console.log(`built ${pages.length + 1} pages into dist/`);
