---
id: "0080"
title: Measure the banner window level with the probe and decide the fix
type: chore
status: inbox
priority: p3
area: macos
depends_on: ["0075"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T07:47:17Z"
updated_at: "2026-10-13T07:47:17Z"
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

## Activity

- 2026-10-13T07:47:17Z · created · njachowski@gmail.com
