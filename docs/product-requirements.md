# Product requirements · Divot

## Intent

An open-source macOS bar that makes workspaces immediately legible and everyday status easy to access, without becoming another source of background load. The camera notch is a deliberate divide: workspaces and the active app on the left, everyday status on the right. People should be able to use a polished default and customize either side without assembling a collection of shell scripts.

## Audience and platform

Primary: Apple-silicon Mac users with AeroSpace, multiple workspaces, and a strong preference for native responsiveness. Initial minimum OS is macOS 26; Intel and older macOS are outside v1. Notched and notch-free displays, mixed scaling, and multi-monitor setups are required. AeroSpace is optional for the bar itself and is the first workspace adapter; yabai follows as a second adapter in its own milestone. Native macOS Spaces is a research question, not a committed adapter.

## Product principles

- Quiet by default: event-driven updates, restrained animation, no always-running render loop.
- Native interactions: focus preservation, keyboard access, VoiceOver, system appearance.
- Local first: no account, telemetry, cloud backend, or network request for core functionality.
- Honest customization: one versioned configuration with useful errors; settings edit the same model.
- Expressive but restrained: a comfortable native default plus four curated theme families, each with honest light and dark variants.
- Performance is measured over the app, helpers, and compositor impact, not just one PID.

## Layout and display behavior

Use system-reported screen geometry, never a fixed notch width. On notched displays the left and right panels stay inside `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, with configurable padding away from the camera housing. No interactive surface spans the notch. On notch-free displays distribute groups at opposite screen edges with a flexible middle gap. Keep readable minima; overflow into a designed menu instead of crossing the notch or clipping text.

Each display has independent geometry and workspace assignment. Observe display configuration changes, backing-scale changes, sleep/wake, and workspace changes. Preserve customization when displays disappear. Stable display identifiers must be derived from system identity; transient array indices are not persistent IDs.

The system menu bar remains accessible and Divot stays visible around it. Persistent top/below behavior replaces the starter's earlier fullscreen-hide default: when the native menu bar is hidden, Divot occupies the top edge; when it appears, Divot shifts below it, and it returns to the top when the bar hides. If the system bar is configured always visible, Divot remains below it. This is a requirement, not a proven capability: detecting actual native-menu-bar visibility is still under feasibility validation, and on notched displays the camera housing masks the same band, so that case remains unresolved without a validated Accessibility observation. No run yet proves always-visible behavior. Fullscreen, Spaces, and multi-display limits will be documented with the design; see [the menu-bar evidence](evidence/0009-native-menu-bar-coexistence.md). Reserving tiling space belongs to the window-manager adapter, not a claim that AppKit changes every app's work area.

## MVP interaction

Both sides are ordered `left`/`right` groups, and any supported item can move between them. Defaults preserve the first-launch bar.

| Area | Required behavior |
| --- | --- |
| Left | Workspace indicators and the frontmost application; distinguish focused, occupied, empty; optional per-workspace app icons; click/keyboard activation through the workspace adapter |
| Right | Battery percentage, minute clock with weekday and date, network status, and volume; status providers fail independently |
| Menus | AppKit menus/popovers; escape dismisses; focus returns predictably |
| Settings | Add/remove/reorder/move items on both sides, per-item options, theme family and System/Light/Dark, size/padding, material, launch at login |
| Permissions | Request only when the enabled feature needs them; denial preserves other widgets |
| Configuration | Validate before applying; invalid reload preserves last known good configuration |
| Accessibility | Names, roles, selected state, actions, keyboard traversal; no color-only state |

## Release acceptance

Two monitors with different scales; a built-in notched screen; an external notch-free screen; unplug/replug; sleep/wake; app activation; fullscreen transitions; persistent menu-bar top/below transitions; reduced motion/transparency; light/dark and all four theme families; and VoiceOver must pass on physical hardware. Performance must pass the documented protocol. Sign and notarize the app; installation must not instruct users to strip quarantine. Website is static, responsive, keyboard usable, and labels unfinished features accurately.

## Outside MVP

Third-party menu-extra mirroring, recreation of another application's menu tree, arbitrary native binary plugins, a tiling window manager, cloud sync, a marketplace, a Metal renderer, and private WindowServer/Spaces APIs. Script providers can follow once native built-ins and the measurement harness are stable.

## Current implementation

Static Vue/VitePress website, public guides, proposed JSON examples, and a Swift foundation with an executable AppKit shell that builds and places panels from the tested geometry/state machine. A native provider pipeline now feeds the default bar's clock, battery/power, network, volume, and frontmost-app items with real local data behind small, tested reading protocols; it is unit-tested but not physically validated. The shell is not physically validated: on notched displays it reports the native-bar state as indeterminate without Accessibility permission and never hides. Physical rendering, click behavior, and the settings-pane links are unverified, and the workspaces item is not implemented (it is the workspace-adapter milestone). The full configuration model and the four theme families are proposed, not implemented. Every remaining app behavior above is a requirement, not a delivered capability.

## Appearance and themes

System, Light, and Dark remain first-class appearance modes, and the chosen theme family is a separate, persisted setting. Follow system appearance live by default, allow explicit overrides, and validate every workspace state, widget, settings surface, menu/popover, and error in both variants. Ship the comfortable native default plus four curated hacker families—Gruvbox, Ayu, Dracula, and Tokyo Night—as first-class release content, not deferred polish. Where an upstream family has no official light variant, label Divot's light adaptation honestly. Semantic color tokens carry foreground/background/accent/selected/occupied/error roles, and color alone never carries state. Changing family or mode invalidates cached appearance-dependent assets only; respect increased contrast and reduced transparency. Website and docs share a persisted theme preference; the landing retains the Tahoe palette in both modes.
