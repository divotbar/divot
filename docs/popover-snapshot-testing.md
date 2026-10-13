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
- All five theme families: native, Gruvbox, Ayu, Dracula, Tokyo Night
- Both light and dark variants (10 configurations each)
- Default text size (12pt) and one larger size (16pt)

This produces 60 popover snapshots (3 popovers × 5 families × 2 variants × 2 sizes).

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

When RepoOS adds support for capturing native screenshots (#0761), the snapshots from this test can be included in task reports by point the feature to the output directory.

## Assertion strategy

Instead of comparing against golden images (which don't travel across machines), assertions verify against the **resolved theme palette**:

- The popover's background should always be `theme.popoverPalette.background`
- Text color should come from `popoverPalette.label`, `secondary`, or `link`
- This means the assertion passes correctly on any macOS version that has the same theme colors resolved

A popover that renders with the correct theme colors, correct alignment, and no clipping has satisfied the test's intent, even if precise pixel positions vary slightly due to subpixel rendering or system updates.
