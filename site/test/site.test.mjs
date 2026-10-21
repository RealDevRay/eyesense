import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { readFile, access } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createPreviewServer } from "../preview.mjs";

const site = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(site, "dist");
const config = JSON.parse(await readFile(join(site, "vercel.json"), "utf8"));
const routes = new Map([
  ["/", "index.html"],
  ["/privacy", "privacy.html"],
  ["/terms", "terms.html"],
  ["/sw", "sw/index.html"],
  ["/sw/privacy", "sw/privacy.html"],
  ["/sw/terms", "sw/terms.html"],
]);
let server;
let base;
before(async () => {
  server = createPreviewServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => {
  if (server?.listening) {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
});

for (const [route, file] of routes) {
  test(`${route} builds accessible static markup and serves its own content`, async () => {
    const html = await readFile(join(dist, file), "utf8");
    const language = route.startsWith("/sw") ? "sw" : "en";
    assert.match(html, new RegExp(`<html lang="${language}">`));
    assert.equal((html.match(/<h1\b/g) ?? []).length, 1);
    assert.match(html, /<main id="main" tabindex="-1">/);
    assert.match(html, /class="skip" href="#main"/);
    assert.match(html, /name="viewport" content="width=device-width, initial-scale=1"/);
    assert.match(html, /rel="alternate" hreflang="sw"/);
    assert.match(html, /rel="canonical"/);
    assert.doesNotMatch(html, /<script\b|<form\b|<iframe\b/i);
    assert.doesNotMatch(html, /gsk_[A-Za-z0-9]{20,}|sb_secret_[A-Za-z0-9]{20,}/);
    if (route.endsWith("privacy") || route.endsWith("terms")) {
      assert.match(html, /1\.1-pilot/);
      assert.match(html, /Mistral/);
    }
    const response = await fetch(`${base}${route}`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type"), /^text\/html/);
    assert.equal(await response.text(), html);
    assert.match(response.headers.get("content-security-policy"), /frame-ancestors 'none'/);
    assert.equal(response.headers.get("permissions-policy"), "camera=(), microphone=(), geolocation=()");
  });
}

test("all generated same-site links and assets resolve", async () => {
  for (const [route, file] of routes) {
    const html = await readFile(join(dist, file), "utf8");
    for (const [, value] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      const url = new URL(value, `https://eyesense.dpdns.org${route}`);
      if (url.origin !== "https://eyesense.dpdns.org") continue;
      const response = await fetch(`${base}${url.pathname}`, { redirect: "manual" });
      assert.ok([200, 307, 308].includes(response.status), `${route}: broken link ${value}`);
      await response.arrayBuffer();
    }
  }
  const css = await readFile(join(dist, "styles.css"), "utf8");
  for (const [, font] of css.matchAll(/url\("\/([^\"]+)"\)/g)) {
    await access(join(dist, font));
  }
});

test("legal tables retain table, row and header semantics", async () => {
  for (const file of ["privacy.html", "sw/privacy.html"]) {
    const html = await readFile(join(dist, file), "utf8");
    assert.match(html, /class="table-wrap" role="region" aria-label="[^"]+" tabindex="0"><table>/);
    assert.match(html, /<thead>/);
    assert.match(html, /<th>/);
    assert.match(html, /<tr>/);
  }
});

test("configured legacy links redirect to valid pages", async () => {
  for (const rule of config.redirects) {
    assert.ok(routes.has(rule.destination));
    const response = await fetch(`${base}${rule.source}`, { redirect: "manual" });
    assert.equal(response.status, rule.permanent ? 308 : 307);
    assert.equal(response.headers.get("location"), rule.destination);
  }
});

test("Kiswahili trailing-slash route redirects and query strings work", async () => {
  const response = await fetch(`${base}/sw/`, { redirect: "manual" });
  assert.equal(response.status, 308);
  assert.equal(response.headers.get("location"), "/sw");
  const page = await fetch(`${base}/privacy?preview=1`);
  assert.equal(page.status, 200);
  await page.arrayBuffer();
});

test("HEAD serves headers without a body and non-read requests are rejected", async () => {
  const head = await fetch(`${base}/terms`, { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(await head.text(), "");
  const post = await fetch(`${base}/`, { method: "POST" });
  assert.equal(post.status, 405);
  assert.equal(post.headers.get("allow"), "GET, HEAD");
});

test("preview rejects malformed paths, traversal and unpublished files", async () => {
  for (const path of ["/%ZZ", "/%2e%2e%2fpackage.json", "/%5cpackage.json", "/%00", "/%2fexample.com/"]) {
    const response = await fetch(`${base}${path}`);
    assert.equal(response.status, 400, path);
  }
  for (const path of ["/missing", "/.env", "/package.json", "/build.mjs"]) {
    const response = await fetch(`${base}${path}`);
    assert.equal(response.status, 404, path);
    await response.arrayBuffer();
  }
});

test("Vercel builds only dist with checks and no app-facing API", () => {
  assert.equal(config.framework, null);
  assert.equal(config.installCommand, "npm ci");
  assert.equal(config.buildCommand, "npm run check");
  assert.equal(config.outputDirectory, "dist");
  assert.equal(config.cleanUrls, true);
  assert.equal(config.trailingSlash, false);
  assert.equal(config.functions, undefined);
  assert.equal(config.env, undefined);
});
