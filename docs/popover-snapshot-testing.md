# Popover snapshot testing

## Overview

`PopoverSnapshotTests` renders Divot's bar popovers offscreen to PNG files for visual review and pixel-level assertions. The tests run headlessly without a display and gracefully skip when offscreen rendering is unavailable (e.g., CI environments without a frame buffer).

**Important:** Rendered snapshots are local evidence only — they are not tracked in git and are not reproduced across machines or macOS versions.

## What gets rendered

- **Volume popover**: output device name, level slider, mute toggle, and Settings link
- **Wi-Fi popover**: nearby networks list, current network marker, and Settings link
- **Appearance popover**: light/dark mode controls, theme family swatches, and Settings link

Each popover is rendered for:
- All theme families: native, Gruvbox, Ayu, Dracula, Tokyo Night
- Both light and dark variants (where applicable)
- Default text size and one larger size (when implemented)

## Running the tests

Use the provided script:

```bash
scripts/snapshots.sh
```

This runs the test suite and prints the snapshot output directory. The tests run as part of `swift test --package-path macos` and report clearly if they cannot render (e.g., on headless systems).

## Pixel assertions

When snapshots render successfully, the test verifies:

1. **Background opacity**: All background pixels have alpha = 1.0 (fully opaque)
2. **Background color**: Center pixels match the theme's popover palette color (within sRGB tolerance)
3. **Left alignment**: Content columns start near the expected 12pt inset
4. **No clipping**: Content bounds stay within the popover frame

These assertions do not use stored baseline images — they verify the popover against the theme palette it was rendered with, so they pass on any machine that has the same text layout and theme colors.

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
