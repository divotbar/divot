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

---

# Bar snapshot testing

`BarSnapshotTests` renders the menu bar (right-side panel) offscreen to PNG files for visual verification and pixel-level assertions. Like popover snapshots, bar snapshots are stored in the gitignored `macos/.build/snapshots/` directory and are local evidence only.

## What gets rendered

### Bar right panel
The right-side panel containing status items (clock, battery, network, volume, etc.) is rendered at:
- All five theme families: native, Gruvbox, Ayu, Dracula, Tokyo Night
- Both light and dark variants (10 configurations each)
- Default text size (14pt) and one larger size (16pt)
- Both with chips enabled and disabled

This produces 40 bar snapshots (1 right panel × 5 families × 2 variants × 2 sizes × 2 chip states).

## Running the tests

The bar snapshots run as part of the standard test suite:

```bash
swift test --package-path macos
```

Or use the provided script:

```bash
scripts/snapshots.sh
```

This command also prints the snapshot output directory.

## Pixel assertions

When snapshots render successfully, each test verifies ALL of the following:

1. **Background color** (`assertBackgroundColor`): The bar's background matches the theme's palette background color within a tolerance of 0.1 sRGB per channel, accounting for subpixel rendering differences.

2. **Right edge inset** (`assertRightEdgeInset`): The bar respects the fixed 17 pt inset from `BarMetrics.rightEdgeInset`, which keeps the camera-in-use indicator clear. This is verified as a structural metric.

3. **Text contrast** (`assertTextContrast`): When text pixels are present, they meet the WCAG AA threshold (4.5:1 contrast) against the background. If no text is found, the assertion passes (the bar may be icons-only or minimal).

4. **Chip styling** (`assertChipOpacity`): When chips are enabled, the visual styling reflects the `chipOpacity` setting. When disabled, the bar renders without the chip background.

## Known limitations

### Test scope

The initial test renders only the right-side panel with a minimal set of items (clock). The left-side panel (workspaces and front app) requires live workspace data and icon fetching, making it unsuitable for simple offscreen rendering tests. Future tests can extend coverage to the left side with mock workspace data.

### No live provider data

Bar snapshots do not render live provider output (battery, network, volume, time). These would require injecting mock provider state through the WidgetPipeline. The current tests render the structural layout and demonstrate the theming system. This limitation affects verification of:

- **Charging indicator color**: The battery widget would display the fixed green (#248E3C) from `ChargingIndicatorPalette.green` when charging, but requires a `BatterySnapshot` with `isCharging: true`. To test this, inject mock battery state through `WidgetPipeline.emit()` or similar provider machinery.
- **Real-time data widgets**: Items like time, network signal, and volume level require provider input.

### Headless environments

On systems without a display, `cacheDisplay` returns an empty bitmap. The test detects this and records a clear message instead of failing.

## Assertion strategy

Like popover snapshots, bar assertions verify against the **resolved theme palette**:

- The bar's background should always be `theme.background`
- Text/icons should meet contrast requirements against the background
- This means the assertion passes correctly on any macOS version with the same theme colors resolved

A bar that renders with the correct theme colors and acceptable contrast has satisfied the test's intent.
