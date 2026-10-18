// Generates the raster icons that Android and Play cannot take as vectors.
//
// API 26+ uses the adaptive icon in res/mipmap-anydpi-v26, so these density
// PNGs exist only as the pre-26 fallback. Legacy icons supply their own shape,
// hence the rounded-rect plate here; the adaptive layers deliberately do not
// have one, because the system masks those itself.
//
// The mark geometry is the single source of truth shared with
// res/drawable/ic_launcher_foreground.xml and res/drawable/splash_mark.xml:
// three arcs concentric on the dot at 43.8,53.88 inside a 108-unit canvas.
//
// Usage: npm install && node generate.mjs

import sharp from "sharp";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const res = join(repo, "app", "android", "app", "src", "main", "res");
const store = join(repo, "store");

const INK = "#0A0C10";
const AMBER = "#FFC247";

/// The mark occupies only ~42% of the 108 canvas, which is correct for an
/// adaptive foreground but too timid for a legacy icon or a store tile. `scale`
/// grows it about the canvas centre.
const mark = (scale) => `
  <g transform="translate(54 54) scale(${scale}) translate(-54 -54)">
    <path fill="${AMBER}" d="M43.8,53.88 m-5.46,0 a5.46,5.46 0 1,0 10.92,0 a5.46,5.46 0 1,0 -10.92,0"/>
    <g fill="none" stroke="${AMBER}" stroke-width="4.62" stroke-linecap="round">
      <path d="M50.71,44.36 A11.76,11.76 0 0 1 50.71,63.40"/>
      <path d="M54.66,38.93 A18.48,18.48 0 0 1 54.66,68.83"/>
      <path d="M58.61,33.49 A25.2,25.2 0 0 1 58.61,74.27"/>
    </g>
  </g>`;

const svg = ({ scale, radius }) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <rect width="108" height="108" rx="${radius}" ry="${radius}" fill="${INK}"/>
  ${mark(scale)}
</svg>`;

// Legacy launcher densities, in dp-equivalent pixels.
const densities = {
  mdpi: 48,
  hdpi: 72,
  xhdpi: 96,
  xxhdpi: 144,
  xxxhdpi: 192,
};

const render = async (markup, size, out) => {
  await mkdir(dirname(out), { recursive: true });
  await sharp(Buffer.from(markup), { density: 1024 })
    .resize(size, size)
    // Flatten first so nothing is actually transparent, then restore a fully
    // opaque alpha channel: Play asks for a 32-bit PNG, and flatten alone
    // leaves a 24-bit RGB file.
    .flatten({ background: INK })
    .ensureAlpha(1)
    .png({ compressionLevel: 9 })
    .toFile(out);
  console.log(`${out.replace(repo, ".")}  ${size}x${size}`);
};

// Legacy icon: rounded plate, mark grown to ~61% of the tile.
const legacy = svg({ scale: 1.45, radius: 24 });
for (const [bucket, size] of Object.entries(densities)) {
  await render(legacy, size, join(res, `mipmap-${bucket}`, "ic_launcher.png"));
}

// Play listing icon: square, no rounded corners (Play applies its own mask),
// 32-bit PNG, no transparency.
await mkdir(store, { recursive: true });
await render(svg({ scale: 1.4, radius: 0 }), 512, join(store, "play-icon-512.png"));

// Keep the exact source of each raster alongside it for future regeneration.
await writeFile(join(store, "play-icon-512.svg"), svg({ scale: 1.4, radius: 0 }), "utf8");
