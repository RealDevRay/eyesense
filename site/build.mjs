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
const languages = [
  {
    code: "en",
    prefix: "",
    label: "English",
    nav: { privacy: "Privacy", terms: "Terms" },
    index: "index.md",
    indexTitle: "Accessible AI visual assistance",
    pages: [
      { slug: "privacy", source: "privacy-policy.md", title: "Privacy Policy" },
      { slug: "terms", source: "terms-of-service.md", title: "Terms of Use" },
    ],
    footer: [
      'EyeSense is published by DevRay. Questions about this page: <a href="mailto:info@devray.qzz.io">info@devray.qzz.io</a>',
      "These documents are also available inside the app under Settings &rarr; Legal, as screen-reader-accessible text.",
    ],
    skip: "Skip to content",
    navLabel: "Legal documents",
  },
  {
    code: "sw",
    prefix: "/sw",
    label: "Kiswahili",
    nav: { privacy: "Faragha", terms: "Masharti" },
    index: "index.sw.md",
    indexTitle: "Usaidizi wa kuona kwa akili bandia",
    pages: [
      { slug: "privacy", source: "privacy-policy.sw.md", title: "Sera ya Faragha" },
      { slug: "terms", source: "terms-of-service.sw.md", title: "Masharti ya Matumizi" },
    ],
    footer: [
      'EyeSense inatolewa na DevRay. Maswali kuhusu ukurasa huu: <a href="mailto:info@devray.qzz.io">info@devray.qzz.io</a>',
      "Nyaraka hizi zinapatikana pia ndani ya programu chini ya Mipangilio &rarr; Kisheria, kama maandishi yanayoweza kusomwa na kisomaji skrini.",
    ],
    skip: "Nenda kwenye maudhui",
    navLabel: "Nyaraka za kisheria",
  },
];

// Tables here carry real obligations, so they must keep their native roles:
// styling the table itself as a block strips row and column association from
// the accessibility tree. Scrolling goes on a focusable wrapper instead, so a
// keyboard user can reach it on a narrow screen.
const wrapTables = (html, label) =>
  html
    .replaceAll(
      "<table>",
      `<div class="table-wrap" role="region" aria-label="${label}" tabindex="0"><table>`,
    )
    .replaceAll("</table>", "</table></div>");

// `route` is the page within a language, e.g. "" or "/privacy". Prefixing it
// per language keeps the canonical URL, the translation alternates and the
// language switcher all pointing at the same page rather than the homepage.
const url = (lang, route) => `https://eyesense.dpdns.org${lang.prefix}${route || (lang.prefix ? "" : "/")}`;
const path = (lang, route) => `${lang.prefix}${route}` || "/";

const shell = ({ title, body, route, lang }) => `<!doctype html>
<html lang="${lang.code}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — EyeSense</title>
<link rel="canonical" href="${url(lang, route)}">
<meta name="description" content="${title} — EyeSense, an AI visual assistance app for blind and low-vision users.">
${languages.map((l) => `<link rel="alternate" hreflang="${l.code}" href="${url(l, route)}">`).join("\n")}
<link rel="alternate" hreflang="x-default" href="${url(languages[0], route)}">
<link rel="icon" href="/mark.svg" type="image/svg+xml">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<a class="skip" href="#main">${lang.skip}</a>
<header>
  <a class="brand" href="${lang.prefix || "/"}">
    <img src="/mark.svg" alt="" width="40" height="40">
    <span class="wordmark"><span>Eye</span><strong>Sense</strong></span>
  </a>
  <nav aria-label="${lang.navLabel}">
    <a href="${lang.prefix}/privacy">${lang.nav.privacy}</a>
    <a href="${lang.prefix}/terms">${lang.nav.terms}</a>
${languages
  .filter((l) => l.code !== lang.code)
  .map((l) => `    <a href="${path(l, route)}" lang="${l.code}" hreflang="${l.code}">${l.label}</a>`)
  .join("\n")}
  </nav>
</header>
<main id="main">
${body}
</main>
<footer>
${lang.footer.map((line) => `  <p>${line}</p>`).join("\n")}
</footer>
</body>
</html>
`;

await mkdir(out, { recursive: true });
await mkdir(join(out, "fonts"), { recursive: true });

let built = 0;
for (const lang of languages) {
  const dir = lang.prefix ? join(out, lang.prefix.slice(1)) : out;
  await mkdir(dir, { recursive: true });

  const tableLabel =
    lang.code === "sw" ? "Jedwali, linasogea kwa mlalo" : "Table, scrolls horizontally";

  for (const page of lang.pages) {
    const md = await readFile(join(legal, page.source), "utf8");
    await writeFile(
      join(dir, `${page.slug}.html`),
      shell({
        title: page.title,
        route: `/${page.slug}`,
        lang,
        body: wrapTables(marked.parse(md), tableLabel),
      }),
      "utf8",
    );
    built++;
  }

  const index = await readFile(join(here, lang.index), "utf8");
  await writeFile(
    join(dir, "index.html"),
    shell({
      title: lang.indexTitle,
      route: "",
      lang,
      body: wrapTables(marked.parse(index), tableLabel),
    }),
    "utf8",
  );
  built++;
}

for (const asset of ["styles.css", "mark.svg"]) {
  await copyFile(join(here, asset), join(out, asset));
}

// Self-hosted so that reading the privacy policy makes no third-party request.
const fonts = join(repo, "app", "assets", "fonts");
for (const file of await readdir(fonts)) {
  if (file.endsWith(".ttf")) await copyFile(join(fonts, file), join(out, "fonts", file));
}

console.log(`built ${built} pages into dist/`);
