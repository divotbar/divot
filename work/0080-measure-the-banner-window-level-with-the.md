---
id: "0080"
title: Measure the banner window level with the probe and decide the fix
type: chore
status: ready
priority: p3
area: macos
depends_on: ["0075"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T07:47:17Z"
updated_at: "2026-10-14T06:15:13Z"
---
## Problem
#0075 shipped an investigation, evidence doc and a read-only divot-notification-banner-probe, but nobody has measured the notification banner window yet, so the core question is still open: can Divot sit below banners (or otherwise avoid hiding their content) with public API? Maintainer screenshot 2026-10-13 shows a Chrome / Google Calendar banner whose title row is tucked under the Divot bar.

## Maintainer steps (human only, an agent cannot do these)
1. Build the packaged app and run it: scripts/package-app.sh, then open dist/Divot.app. Native menu bar set to auto-hide as usual.
2. Show a real banner (for example a calendar or chat notification, or send yourself a test notification), and while it is on screen run: swift run --package-path macos divot-notification-banner-probe (or the built binary). Save the output.
3. Repeat once with the native menu bar revealed, and once with Divot's bar and a fullscreen app if you can.
4. Paste the outputs into this task (kCGWindowLevel and bounds of the banner window versus Divot's panel).

## Agent steps after the outputs are pasted
- Update docs/evidence/0075-notification-banner-overlap.md with the measured numbers and replace every 'NOT measured' label that the data now covers. Keep the CG top-left versus AppKit coordinate labelling.
- Decide the fix from the data and write the decision in the task: lower Divot's window level below banners without losing the placement/fullscreen behaviour from #0009/#0021/#0023, or inset the bar / leave a gap, or document the limitation and add an optional setting.
- Implement the chosen fix only if it uses public API, with tests on the level or geometry selection, and update docs/ and site/ pages that describe window behaviour and the troubleshooting page.

## Acceptance criteria
- The evidence doc has real measured banner level and bounds from the maintainer's run, no invented values.
- A recorded decision with reasoning; if a fix is implemented, tests and docs/site updates; if not, the limitation is documented honestly with options.
- The maintainer verifies by eye on the packaged app with a real notification; do not claim visual sign-off.

## Notes for AI
Do not start this until the maintainer pastes the probe output; if the task body has no measured output, stop and ask in a task note rather than guessing. Related: #0075, bar placement decisions #0021/#0023, notch hugging #0028.

## Screenshots
Maintainer screenshot 2026-10-13 23:26: a macOS 'App Background Activity' notification banner. Its title row is tucked under the Divot bar (the bar overlaps the top of the banner), the same overlap as the earlier Chrome / Google Calendar banner.

![Banner under the Divot bar](/api/tasks/0080/attachments/screenshot-1.png)

## Probe output
$ swift run --package-path macos divot-notification-banner-probe --watch 20
os=26.5.2
Watching all windows for 20 seconds, polling twice per second...

[13:13:17] window-77191 [Divot panel] owner=divot pid=89801 layer=23 CG-bounds=(0, 0, 769, 39) AppKit-bounds=(0, 1068, 769, 39) alpha=1.00 on-screen=true
[13:13:17] window-77192 [Divot panel] owner=divot pid=89801 layer=23 CG-bounds=(942, 0, 768, 39) AppKit-bounds=(942, 1068, 768, 39) alpha=1.00 on-screen=true

[13:13:33] ControlCenter panels (layer 25, above Divot panel layer 23): window-53 (Amphetamine), window-14505, window-54133, window-61067, window-61090, window-61353, window-77190 (all Item-0), CG-bounds y=-34, on-screen=false
[13:13:33] window-77197 owner=Window Server name="System Status Item Clone" layer=25 CG-bounds=(1425, -26, 20, 18) alpha=0.29 on-screen=false

## Summary
Divot panel layer (measured): 23
CG-bounds: (942, 0, 768, 39)
AppKit-bounds: (942, 1068, 768, 39)

Highest-layer windows visible at end of watch period:
1. IsThereNet (layer 2147483628)
2. divot [Divot panel] (layer 23)
3. Notification Centre [NotificationCenter banner] (layer 21)
4. Dock (layer 20)


## Activity

- 2026-10-13T07:47:17Z · created · njachowski@gmail.com
- 2026-10-13T16:27:12Z · body: section Screenshots
- 2026-10-13T19:20:59Z · status inbox→ready
- 2026-10-14T06:15:13Z · body: section Probe output
