---
id: "0057"
title: "Battery, volume and Wi-Fi icons match the native menu bar icon size"
type: feature
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/battery-volume-and-wi-fi-icons-match-the
created_at: "2026-10-12T08:36:24Z"
updated_at: "2026-10-12T09:13:44Z"
review_passes: 1
---
## Problem

The battery, volume and Wi-Fi icons on the Divot bar are small and hard to read beside the native menu bar icons. The maintainer wants them about the same size as the native icons.

## Desired UX

- The battery, volume and Wi-Fi icons match the size of the native menu bar icons on the same display.
- The size follows the bar's icon size setting, so it scales with it.

## Acceptance criteria

- Set the default symbol size for these three icons to match the native menu bar icon size, measured on the packaged app and recorded in the task.
- Icons scale with the app icon size setting, with a test at the smallest and largest sizes.
- Verify the three icons read at the same visual weight as the native bar's; the maintainer confirms the look.
- repoos check passes.

## Notes for AI

Keep the change to these three icons' symbol sizing. Do not change spacing or alignment, which are in #0054 and #0055.

## Observed Results
**Implementation.** The battery, network and volume items resolve their SF Symbol through `NativeStatusSymbol.image(symbolName:metrics:)` at `BarMetrics.statusSymbolPointSize` (the bar's icon size, `text.size + 2`) and draw it in the symbol's own box instead of the square status-icon box, so the wide battery is not scaled down. Every other item keeps the square box; spacing and vertical centring are unchanged (#0054/#0055).

**Packaged-app measurement.** `dist/Divot.app/Contents/MacOS/divot --widgets`, built from this branch (working tree on af4b88e), on the notched built-in display (1710x1107 pt @2x), 2026-10-12:
- `metrics.statusSymbolSize=16` (default)
- `statusSymbol.battery=battery.100 28x13pt`
- `statusSymbol.network=wifi 22x15pt`
- `statusSymbol.volume=speaker.wave.2.fill 23x16pt`

Before the change the same three symbols resolved at the SF Symbol default of 13 pt (battery.100 22x11, wifi 17x13, speaker.wave.2.fill 19x14), and the square status-icon box scaled the wide battery down further.

**Tests.** `BarMetricsTests.statusSymbolSizeMatchesTheNativeDefaultAndFollowsTextSize` (16 pt default; 12 pt at the smallest text size 10 and 22 pt at the largest 20; independent of `appIconSize`) and `WidgetViewTests` (`nativeStatusSymbolsUseTheBarIconSizeAndScaleWithTextSize`, `nativeStatusSymbolIsConfiguredNotLeftAtTheRawSymbolSize`, `otherSymbolsKeepTheSquareStatusIconBox`). `repoos check --changed main` passes (564 native tests, site build, packaged-app smoke test; the smoke test asserts the default 16 pt symbol size and that all three symbols resolve).

**Still human.** The native menu bar is auto-hidden behind the running Divot on this Mac (its status-item windows sit off-screen at y=-34 and cannot be captured), so a direct on-screen native-vs-Divot comparison and the maintainer's look-and-feel sign-off are human steps. The 16 pt target is the existing `BarMetrics` status-icon default and the macOS menu-bar symbol size; it should be adjusted if the on-device comparison says otherwise.


## Activity

- 2026-10-12T08:36:24Z · created · njachowski@gmail.com
- 2026-10-12T08:36:31Z · status inbox→ready
- 2026-10-12T08:36:31Z · status ready→active, branch
- 2026-10-12T08:47:18Z · body: section Observed Results
- 2026-10-12T08:47:54Z · status active→review
- 2026-10-12T08:47:54Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T08:48:30Z · note: review pass 1: good to go
- 2026-10-12T09:11:28Z · status review→active
- 2026-10-12T09:11:28Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-12T09:13:44Z · status active→review
- 2026-10-12T09:13:44Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
