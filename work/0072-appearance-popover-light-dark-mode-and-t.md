---
id: "0072"
title: "Appearance popover: light/dark mode and theme family picker on the moon item"
type: feature
status: active
priority: p2
area: macos
depends_on: ["0071"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/appearance-popover-light-dark-mode-and-t
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T02:01:47Z"
updated_at: "2026-10-13T02:36:19Z"
review_rounds: 1
review_passes: 1
---
## Problem
Clicking the moon (Appearance) item only toggles Divot's own light/dark mode (#0037). The maintainer wants a popup/dropdown on that item to either set light/dark or pick the theme family (Gruvbox, Ayu, etc.).

## Desired UX
- Clicking the moon item opens a popover anchored to the item, in the same style and using the same shared popover component as the Wi-Fi (#0070) and volume (#0071) popovers.
- Mode section: a three-way choice System / Light / Dark showing the current mode, matching the appearance.mode setting values (system, light, dark).
- Theme section: a list of the theme families (Native, Gruvbox, Ayu, Dracula, Tokyo Night, matching appearance.family) with the current one checked.
- Choosing an option applies immediately to the bar and is saved to the config exactly as the Settings window does, so the Settings window and the popover never disagree.
- A final row 'Open Divot Settings...' opens Divot's own Settings window (not System Settings).
- Divot's theme only: no 'Full system' option and no change to the macOS appearance (decision #0037).

## Acceptance criteria
- Reuse the shared popover component; do not duplicate it. Build the list from the same family/mode enums and single settings source as the Settings window and the config CLI schema (no hand-copied list), so a new theme appears automatically.
- Apply changes through the existing configuration store (atomic write, live reload); unit test the mode/family selection logic behind a protocol seam with fakes, including 'popover reflects a change made elsewhere while open'.
- Keyboard accessible: options are reachable and selectable with the keyboard and have accessibility labels and a selected state.
- The moon item's click behaviour change (it no longer toggles directly) is documented in docs/ and the matching site/ pages (widgets guide, configuration reference, themes page where applicable).
- Contrast and theme tests still pass for every family in light and dark.

## Notes for AI
Look at how the Appearance item toggles today and how the Settings window reads and writes appearance.family and appearance.mode. Start after #0071 lands so the shared popover component is stable. A quick toggle back to the old one-click behaviour is out of scope; if the maintainer wants a shortcut it will be a follow-up.

## Activity

- 2026-10-13T02:01:47Z · created · njachowski@gmail.com
- 2026-10-13T02:20:07Z · status inbox→ready
- 2026-10-13T02:20:07Z · cli_override, model_override
- 2026-10-13T02:20:08Z · status ready→active, branch
- 2026-10-13T02:33:35Z · status active→review
- 2026-10-13T02:33:35Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T02:34:24Z · note: review pass 1: needs some work
- 2026-10-13T02:34:24Z · status review→active
- 2026-10-13T02:36:19Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
