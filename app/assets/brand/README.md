# EyeSense brand assets

Source files for the EyeSense identity. All editable SVG. Specification and
usage rules live in `docs/implementation-plan.md` §S6.9.

## Concept

**Light in, speech out.** A solid disc (the lens) with three arcs of increasing
radius opening to the right (sound radiating). It reads as an aperture and as an
audio emanation at the same time, works in one colour, and stays legible at
24 px because it is three strokes and a disc.

A literal eyeball was rejected deliberately: it is the most clichéd mark in the
category, and an eye as the identity of a product for blind users is tone-deaf.

## Files

| File | Contents | Use |
| --- | --- | --- |
| `logo-horizontal.svg` | Mark + "EyeSense" wordmark | **Primary.** Splash, headers, docs, pitch deck |
| `logo-stacked.svg` | Mark above wordmark, centred | Square placements, social avatars |
| `logo-mark.svg` | Mark only | App icon source, favicon, watermark |
| `logo-wordmark.svg` | "EyeSense" only | Inline contexts where the mark is already present |
| `icon-adaptive-foreground.svg` | Mark in the Android safe zone | Adaptive icon foreground |
| `icon-adaptive-background.svg` | Flat ink fill | Adaptive icon background |
| `icon-monochrome.svg` | Single-path mark | Android 13+ themed icons |

## Colour

| Context | Mark and "Sense" | "Eye" | Background |
| --- | --- | --- | --- |
| Dark (default) | `#FFC247` | `#F7F8F8` | `#0A0C10` |
| Light | `#8A5A00` | `#14171D` | `#FBFBF9` |
| Maximum contrast | `#FFD400` | `#FFFFFF` | `#000000` |
| One colour | any single approved value | same | any |

## Typeface

The wordmark is set in **Atkinson Hyperlegible Bold** — the same family the app
UI uses, so the identity and the interface speak with one voice. Designed by the
Braille Institute to maximise character disambiguation for low-vision readers,
and licensed under the SIL Open Font License.

The lockup SVGs use a live `<text>` element so they stay editable. **Convert the
text to outlines before distributing outside the app** (web, print, store
listing), so rendering does not depend on the font being installed.

## Rules

- Clear space on all sides equal to the mark's dot diameter. Nothing closer.
- Minimum sizes: horizontal lockup 120 px wide, stacked 80 px, mark alone 24 px.
- The app icon is **mark only**. Never the wordmark — text is illegible at
  launcher size, and Play rejects icons that embed a name as a graphic device.
- Never stretch, re-colour outside the pairs above, add effects or shadows,
  outline the wordmark, or re-set it in another typeface.
- Adaptive icon artwork stays inside the central 66 dp of the 108 dp canvas.
  The system masks to its own shape and OEM shapes vary.

## Still to produce

- [ ] Outlined (path) variants of each lockup for distribution
- [ ] PNG raster sets at 1×, 2×, 3× for contexts that cannot consume SVG
- [ ] 512 × 512 Play listing icon, 32-bit, no transparency, square corners
- [ ] Android 12+ splash drawable: mark on a 288 dp canvas, artwork inside the
      central 192 dp circle, wired up in `styles.xml`
