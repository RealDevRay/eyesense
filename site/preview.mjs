// Local preview only. Production is served by Vercel from dist/.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(await readFile(join(here, "vercel.json"), "utf8"));
const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
};

export function createPreviewServer({ root = join(here, "dist") } = {}) {
  return createServer(async (req, res) => {
    // Mirror the site's common security headers without exposing another origin.
    for (const { key, value } of config.headers.find((rule) => rule.source === "/(.*)").headers) {
      res.setHeader(key, value);
    }
    if (req.method !== "GET" && req.method !== "HEAD") {
      res.writeHead(405, { Allow: "GET, HEAD" });
      res.end();
      return;
    }
    let path;
    try {
      path = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    } catch {
      res.writeHead(400);
      res.end();
      return;
    }
    if (path.startsWith("//") || path.includes("\\") || path.includes("\0") || path.split("/").includes("..")) {
      res.writeHead(400);
      res.end();
      return;
    }
    const redirect = config.redirects.find((rule) => rule.source === path);
    if (redirect) {
      res.writeHead(redirect.permanent ? 308 : 307, { Location: redirect.destination });
      res.end();
      return;
    }
    if (path !== "/" && path.endsWith("/")) {
      res.writeHead(308, { Location: path.replace(/\/+$/, "") });
      res.end();
      return;
    }
    const candidates = path === "/"
      ? ["index.html"]
      : extname(path)
        ? [path.slice(1)]
        : [`${path.slice(1)}.html`, join(path.slice(1), "index.html")];
    for (const candidate of candidates) {
      const type = types[extname(candidate)];
      if (!type) continue;
      try {
        const body = await readFile(join(root, candidate));
        res.writeHead(200, { "Content-Type": type });
        res.end(req.method === "HEAD" ? undefined : body);
        return;
      } catch (error) {
        if (error.code === "ENOENT" || error.code === "EISDIR" || error.code === "ENOTDIR") continue;
        res.writeHead(500);
        res.end();
        return;
      }
    }
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(req.method === "HEAD" ? undefined : "not found");
  });
}

const isMain = process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  createPreviewServer().listen(4321, "127.0.0.1", () => {
    console.log("preview on http://127.0.0.1:4321");
  });
}
