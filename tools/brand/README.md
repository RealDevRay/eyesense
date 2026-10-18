# Brand raster generation

Most EyeSense artwork is vector and needs no build step. This generates only
the rasters that Android and Play cannot accept as vectors.

```bash
cd tools/brand
npm install
node generate.mjs
```

| Output | Purpose |
| --- | --- |
| `app/.../res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | Pre-API-26 launcher fallback, 48–192 px |
| `store/play-icon-512.png` | Play listing icon, 512 px, 32-bit, opaque |
| `store/play-icon-512.svg` | The exact source of the above |

## Why the two sets differ

API 26 and above resolve `@mipmap/ic_launcher` to
`res/mipmap-anydpi-v26/ic_launcher.xml`, so the density PNGs are reached only
on older releases. Legacy icons had to supply their own silhouette, which is
why these carry a rounded ink plate. The adaptive layers deliberately do not:
the system masks those to its own shape, and a plate baked into the foreground
would be clipped unpredictably across OEMs.

The Play tile is square with no rounded corners, because Play applies its own
mask and rounding the source would double it.

## Geometry

`generate.mjs` holds the mark inline rather than reading the SVGs, so the
rasters are generated from the same coordinates as
`res/drawable/ic_launcher_foreground.xml` and `res/drawable/splash_mark.xml`:
three arcs concentric on the dot at `43.8, 53.88` within a 108-unit canvas,
stroke `4.62`, amber `#FFC247` on ink `#0A0C10`.

If the mark ever changes, update it in all three places together. The splash
mark had previously drifted in both colour and radii, which is the failure this
note exists to prevent.
