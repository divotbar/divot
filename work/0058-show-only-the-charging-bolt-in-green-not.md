---
id: "0058"
title: "Show only the charging bolt in green, not the battery outline"
type: feature
status: active
priority: p2
area: macos
depends_on: ["0057"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/show-only-the-charging-bolt-in-green-not
created_at: "2026-10-12T08:36:25Z"
updated_at: "2026-10-12T09:38:13Z"
---
## Problem

When charging, the battery item shows a bolt, but it is drawn in the same colour as the battery and is hard to see. The maintainer wants only the bolt green, with the battery outline left as it is.

## Desired UX

- While charging, the bolt is green and the battery outline keeps the bar's normal colour.
- When not charging, there is no bolt and no green.

## Acceptance criteria

- Draw the bolt as a separate green element on top of the battery symbol, using a fixed green from the theme's accent set rather than a hard-coded colour in a view.
- Tests cover the charging and not-charging states and that only the bolt uses the green.
- Verify on the packaged app while charging; record the observed colours in the task.
- repoos check passes.

## Notes for AI

Depends on the icon-size task, which changes the same battery symbol drawing.

## Observed Results
**Implementation.** The battery item now draws the charging bolt as a separate `bolt.fill` badge over the plain battery symbol instead of the combined `battery.100.bolt` glyph. `DivotCore.WidgetPresenter` returns the full plain battery outline (`battery.100`, the same outline it drew before) plus `WidgetBadge(symbolName: "bolt.fill", role: .charging)` while charging, and no badge otherwise. `DivotAppKit.BarItemView` draws that badge in its own `NSImageView` over the icon (same icon box, so the item width is unchanged) and tints it with the theme accent — the theme's green `#D6F58A` by default — through the semantic `WidgetBadge.Role.charging`, not a literal in the view. The battery outline and label stay `theme.foreground`.

**Tests.** `DivotCoreTests.WidgetPresentationTests.batteryPresentationShowsPercentageAndPowerSymbols` (charging -> `battery.100` + `bolt.fill`/`.charging`; not charging -> no badge), `DivotAppKitTests.WidgetViewTests.batteryItemShowsBoltWhileChargingAndPlainSymbolOtherwise` (the badge appears/disappears live), and `WidgetViewTests.onlyTheChargingBoltUsesTheThemeAccentGreen` (badge tint == `BarTheme.systemDefault.accent` == `#D6F58A`, while the icon and label tints == `theme.foreground`, and no accent tint when not charging). `repoos check --changed main` passes (site build, 592 native tests, packaged-app smoke test, justfile).

**Packaged app (observed 2026-10-12, machine on AC power and charging).** `dist/Divot.app/Contents/MacOS/divot --widgets`, built from this branch, printed:

```
statusSymbol.battery=battery.100 28x13pt
theme.accent=#D6F58A
battery: 98% · Battery 98%, charging
battery.badge=bolt.fill role=charging
```

So the packaged app resolves the plain battery outline plus a `bolt.fill` badge tinted with the theme accent `#D6F58A`.

**Still human.** The on-screen rendered colours (that only the bolt shows green and the battery outline does not) need the maintainer's eye on the running bar; a pixel-level capture of the rendered menu-bar item is a device/human check I cannot make from this sandbox.


## Activity

- 2026-10-12T08:36:25Z · created · njachowski@gmail.com
- 2026-10-12T08:36:28Z · depends_on
- 2026-10-12T09:31:21Z · status inbox→ready
- 2026-10-12T09:31:22Z · status ready→active, branch
- 2026-10-12T09:36:57Z · body: section Observed Results
- 2026-10-12T09:38:13Z · body: section Observed Results
