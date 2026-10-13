# Popover snapshot testing

## Overview

`PopoverSnapshotTests` renders Divot's popovers offscreen to PNG files for visual review and pixel-level assertions. The tests skip gracefully when offscreen rendering is unavailable (no display), printing a clear message for each skipped test.

**Important:** Rendered snapshots are local evidence only — they are stored in the gitignored `macos/.build/snapshots/` directory and are not tracked in git. Snapshots are not reproduced across machines or macOS versions; they serve as a checkpoint for the developer who runs them locally. Real headless rendering to PNG is not guaranteed on all systems and is not enforced in CI.

## What gets rendered

### Popovers
- **Volume popover**: output device name, level slider, mute toggle, and Settings link
- **Wi-Fi popover**: nearby networks list, current network marker, and Settings link
- **Appearance popover**: light/dark mode controls, theme family swatches, and Settings link

### Coverage matrix
Each popover is rendered at:
- All six theme families: native, Alpine, Gruvbox, Ayu, Dracula, Tokyo Night
- Both light and dark variants (12 configurations each)
- Default text size (12pt) and one larger size (16pt)

This produces 72 popover snapshots (3 popovers × 6 families × 2 variants × 2 sizes).

## Running the tests

Use the provided script:

```bash
scripts/snapshots.sh
```

This runs the test suite and prints the snapshot output directory. The tests run as part of `swift test --package-path macos` and report clearly if they cannot render (e.g., on headless systems).

## Pixel assertions

When snapshots render successfully, each test suite verifies ALL of the following:

1. **Background opacity** (`assertBackgroundOpaque`): All sampled background pixels have alpha ≥ 0.99 (fully opaque). Samples multiple points across the content area.

2. **Background color** (`assertBackgroundColor`): Sampled background pixels match the theme's popover palette background color within 0.01 sRGB tolerance (per channel). Samples multiple points to verify consistency.

3. **Text contrast** (`assertTextContrast`): Locates non-background (text) pixels in header and content regions, then verifies that at least one text pixel meets the WCAG AA threshold (4.5:1 contrast ratio) against the sampled background color. Uses `ContrastAudit.ratio()` and the palette colors.

4. **Left alignment** (`assertLeftAlignment`): Scans multiple rows in the middle content region and verifies that the first non-background pixel column (content start) lies within a tolerance of the expected 12pt leading inset. The tolerance scales proportionally with bitmap width (4.4% of width) to account for both 1x and 2x displays, ensuring the assertion passes correctly regardless of pixel density.

5. **No clipping** (`assertNoClipping`): Samples pixels at the four edges (left, right, top, bottom) and verifies that no content-like pixels appear in the outermost 4px margin (indicates content is clipped or extends beyond the frame).

These assertions do not use stored baseline images — they verify against the theme palette it was rendered with, so they pass on any machine that has the same layout and theme colors.

## Known limitations

### System popover chrome

Offscreen rendering using `bitmapImageRepForCachingDisplay` does not render the system popover chrome (the arrow pointing to the bar, the window shadow, the material vibrancy). Only the content view and its background are captured.

When this limitation affects test assertions, the test documents it and renders the content view only.

### Headless environments

On systems without a display (e.g., GitHub Actions, Docker), `cacheDisplay` returns an empty bitmap. The test detects this and records a clear message instead of failing on pixel assertions.

### Text layout

The tests sample pixels at fixed coordinates that assume the default font and system appearance. If the macOS font rendering or DPI changes, coordinates may need adjustment.

## Integration with RepoOS

`repoos.toml` declares a `[[shot.targets]]` row named **Divot bar** (areas `macos`, paths `macos/Sources/**` and `macos/Tests/**`, `requires = ["swift"]`). It runs the snapshot suites with `DIVOT_SNAPSHOT_DIR="$REPOOS_SHOT_DIR"` and `DIVOT_SNAPSHOT_SET=shots`, and RepoOS collects `**/*.png` from that directory as the task's shots. So a task that changes native sources gets shots at handoff, a task can name the target in its `## Shots` section, and the maintainer can run `repoos shot --target "Divot bar"` by hand.

- **Directory guard.** `DIVOT_SNAPSHOT_DIR` must be inside a `.build` directory, end in a `snapshots` directory, or equal `REPOOS_SHOT_DIR` under a gitignored `.attachments/` directory (`SnapshotTestHelpers.isIgnoredLocation`). Anything else aborts the test run, so rendered images cannot land in a tracked path.
- **Reduced set.** `DIVOT_SNAPSHOT_SET=shots` writes the bar with chips off plus every popover (Wi-Fi networks, Wi-Fi permission message, Volume, Appearance, Calendar, World clock with zero/two/four timezones and a day-label case) in two themes (Native and Gruvbox), light and dark, at the default text size. Assertions still run for the whole matrix. Without the variable, or via `scripts/snapshots.sh`, the full matrix is written.
- **Popover pixel assertions (#0083).** `assertPixelRules` runs for every popover, all five families, light and dark: the fill is opaque and equals the palette background; every ink row's first pixel is inside the leading inset (nothing centred or right-aligned); every text band reaches 4:1 against the sampled background; and the selected fill (chosen theme row, today) is visible.
- **What the shots do and do not prove.** They render the content view over the solid palette fill, so they prove alignment, contrast and the selected style. They do not draw the popover window, so they cannot show the real chrome. The translucency fix is proven by the runtime test `realPopoverWindowHasNoMaterialAndASolidFillForEveryTheme`, which presents the real panel and walks its view hierarchy (no `NSVisualEffectView`, alpha-1 chrome and content fill), not by the images. Visual sign-off on the packaged app is the maintainer's.
- **Headless.** With no usable graphics context the tests skip and no PNGs are produced; RepoOS then records no shots.

## Assertion strategy

Instead of comparing against golden images (which don't travel across machines), assertions verify against the **resolved theme palette**:

- The popover's background should always be `theme.popoverPalette.background`
- Text color should come from `popoverPalette.label`, `secondary`, or `link`
- This means the assertion passes correctly on any macOS version that has the same theme colors resolved

A popover that renders with the correct theme colors, correct alignment, and no clipping has satisfied the test's intent, even if precise pixel positions vary slightly due to subpixel rendering or system updates.

---

# Bar snapshot testing

`BarSnapshotTests` renders the **right-hand bar group** offscreen and asserts on its pixels. Like the popover snapshots it is local evidence only: PNGs go to the gitignored `macos/.build/snapshots/` (or `DIVOT_SNAPSHOT_DIR`), are never committed, and nothing is compared with a stored golden. Every expected value comes from `BarMetrics`, the resolved `BarTheme`, or `ChargingIndicatorPalette`.

## What is rendered

A `BarContentView(side: .right)` holding `battery, clock, network, volume` in that order, 420 pt wide and `BarMetrics.height` tall, hosted in a light or dark `NSAppearance`. Twenty-four configurations: six theme families × light/dark × the default (14 pt) and one larger (16 pt) text size. Each configuration makes four renders, so 96 PNGs:

| PNG suffix | Chips | Battery | Used for |
| --- | --- | --- | --- |
| `chips-off` | off | charging | slot layout, ink placement, right inset, contrast, charging green |
| `chips-on` | on, 80% transparency | charging | translucent chip fill, contrast on the chip |
| `chips-solid` | on, fully opaque | charging | order, gaps and inset measured from chip edges |
| `not-charging` | off | not charging | no charging green |

Pixels are converted to 8-bit sRGB before sampling, and the bitmap is drawn in sRGB, so alpha blends are comparable with the expected colours.

## What the tests enforce

1. **Item order and gaps.** Laid-out item slots are left to right in configured order, every gap equals `BarMetrics.rightItemSpacing`, and no slot is empty. With chips off, every slot contains drawn pixels and the gaps and leading margin are pure bar background. With solid chips, the chip edges are measured on the centre pixel row: four chips, starting at their slots, separated by the 8 pt gap (within two device pixels).
2. **17 pt right inset.** The last slot ends `BarMetrics.rightEdgeInset` (17 pt) from the right edge, no pixel is drawn in the inset, the rightmost drawn column sits within 4 pt of the inset line, and the solid chip's right edge measures 17 pt from the bitmap edge (scaled by the bitmap scale, within two device pixels).
3. **Chip fill and opacity.** Probed 1 pt inside each slot: chips off is the bar background; 80% transparency is the chip colour blended over the bar background at 20% (within 0.025 per channel, and the test fails if that blend is indistinguishable from the background); a fully opaque chip is the chip colour.
4. **Charging bolt.** While charging, pixels of the fixed `ChargingIndicatorPalette` green (#248E3C) are present, all inside the battery slot and spanning less than the icon width (only the bolt is green), while the battery body draws pixels of the normal label colour. With the battery not charging, no pixel is that green, and the battery still draws.
5. **Text contrast.** The strongest pixel in the clock label meets `ContrastAudit.textThreshold` (4.5:1) against the bar background (chips off) or the blended chip colour (chips on).

The assertions were checked by mutation: changing the right inset, the item gap, the chip alpha, the whole-symbol charging tint, or drawing chips when off each makes the suite fail.

## Running

```bash
swift test --package-path macos --filter BarSnapshotTests
```

`scripts/snapshots.sh` runs the full test suite, shows the popover and bar suite lines, and prints the output directory.

## What is not covered, and why

- **Left group (workspaces, front app, Divot mark).** Not rendered or asserted. This is not an offscreen limitation: `WorkspaceBarView` and the front-app item can be rendered the same way (the existing workspace tests drive the view with a stub adapter and icon provider). These tests simply do not cover it yet, so left-side order, gaps and chip style have no visual evidence.
- **Panel chrome.** The tests render `BarContentView`, not the `NSPanel`s. The panel level, the notch split between the two panels, and the optional bottom-shadow strip are not drawn.
- **Network and volume glyphs.** Their slots are checked for presence, position and spacing, not for which symbol is drawn.
- **Live data.** Items are fed fixed snapshots (80% charging battery, a fixed clock date, Wi-Fi connected, 50% volume), not provider output.
- **Headless sessions.** If AppKit produces no pixels, the test fails (`Offscreen rendering produced no pixels`) rather than passing without assertions. This differs from the popover suite, which prints a skip message.
- **Other machines.** Colours are compared within a tolerance after conversion to sRGB, but font and symbol rasterisation can differ between macOS versions, so a pass here is evidence for the machine that ran it.

## The popover standard (#0083)

Every popover (Wi-Fi in all states, Volume, Appearance, Calendar) is shown by `BarPopoverHost` in a borderless panel, not `NSPopover`. `NSPopover` draws its own frame view with a vibrant material that a layer fill on the content cannot remove, so Divot draws the bubble itself (`PopoverChromeView`): a solid fill, a 1px separator border, an arrow, and the panel shadow. The window is non-opaque only so the rounded corners and arrow are cut out; every pixel inside the bubble is opaque.

- Colours come from `BarTheme.popoverPalette` (background, label, secondary, link, separator, selected, selectedForeground), all fully opaque. Native uses fixed light/dark values; families use their audited tokens. Label, secondary and link clear 4.5:1 against the background; selected text clears 4.5:1 on the selected fill.
- All rows live in `PopoverRowStack`, which pins every row to the leading edge, so nothing is centred or right-aligned. Footer links are `PopoverLinkButton`, which draws flush left. Appearance theme rows and calendar days are drawn by their own buttons with one selected style (filled rounded rect in `selected`, text in `selectedForeground`).
