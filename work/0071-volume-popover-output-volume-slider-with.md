---
id: "0071"
title: "Volume popover: output volume slider with mute and an Open Sound Settings row"
type: feature
status: inbox
needs_input: true
needs_input_reason: needs-human-step
needs_input_detail: "Acceptance criteria mention a real device, physical hardware, accounts, credentials, or third-party registration — split that verification into a separate human-only task. (matched: device verification)"
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T02:01:04Z"
updated_at: "2026-10-13T02:01:04Z"
---
## Problem
Clicking the volume item only opens a System Settings pane. The maintainer wants a popup/dropdown with a slider to change the volume, like the new Wi-Fi popover (#0070).

## Desired UX
- Clicking the volume item opens a popover anchored to the item (same look and behaviour as the Wi-Fi popover) containing: a horizontal output-volume slider with the current percentage, a mute toggle, and a final row 'Open Sound Settings...' that opens the Sound pane (same pattern as 'Open Wi-Fi Settings...').
- The slider changes the default output device volume live; the bar item's icon and percentage update as it moves, and the popover reflects external changes (keyboard keys, other apps) while it is open.
- Devices that have no settable volume (some HDMI/DisplayPort outputs) show the slider disabled with a short note, not a broken control.

## Acceptance criteria
- Public CoreAudio / AudioToolbox API only (default output device, virtual main volume and mute properties), no private APIs, no polling timer: use property listeners already used by the volume provider, and remove them when the popover closes.
- Audio set/get logic sits behind a protocol seam and is unit tested with fakes (clamping 0...1, mute toggle, unsettable device state, external-change updates).
- Reuse the existing popover component from #0070; do not duplicate it.
- The click behaviour change is documented in docs/ and the matching site/ pages (widgets guide and configuration reference if the click action is described there); the item stays optional per existing settings.
- Keyboard accessibility: slider is adjustable with arrow keys and has an accessibility label and value.
- Record in the task what CoreAudio reported for the current device and any device without settable volume; do not invent behaviour. The maintainer verifies on the packaged app that the slider changes the real volume (human step).

## Notes for AI
Look at how the volume provider reads volume today and how #0070 built its popover and fake-backed tests. Out of scope: input devices, per-app volume, output device switching (possible follow-up).

## Activity

- 2026-10-13T02:01:04Z · created · njachowski@gmail.com
- 2026-10-13T02:01:04Z · needs_input
