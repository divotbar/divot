# Product requirements · Divot

## Intent

An open-source macOS bar that makes workspaces immediately legible and everyday status easy to access, without becoming another source of background load. The camera notch is a deliberate divide: navigation on the left, status on the right. People should be able to use a polished default and customize it without assembling a collection of shell scripts.

## Audience and platform

Primary: Apple-silicon Mac users with AeroSpace, multiple workspaces, and a strong preference for native responsiveness. Initial minimum OS is macOS 26; Intel and older macOS are outside v1. Notched and notch-free displays, mixed scaling, and multi-monitor setups are required. AeroSpace is optional for the bar itself. Yabai is a later adapter, not an MVP dependency.

## Product principles

- Quiet by default: event-driven updates, restrained animation, no always-running render loop.
- Native interactions: focus preservation, keyboard access, VoiceOver, system appearance.
- Local first: no account, telemetry, cloud backend, or network request for core functionality.
- Honest customization: one versioned configuration with useful errors; settings edit the same model.
- Performance is measured over the app, helpers, and compositor impact, not just one PID.

## Layout and display behavior

Use system-reported screen geometry, never a fixed notch width. On notched displays the left and right panels stay inside `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, with configurable padding away from the camera housing. No interactive surface spans the notch. On notch-free displays distribute groups at opposite screen edges with a flexible middle gap. Keep readable minima; overflow into a designed menu instead of crossing the notch or clipping text.

Each display has independent geometry and workspace assignment. Observe display configuration changes, backing-scale changes, sleep/wake, and workspace changes. Preserve customization when displays disappear. Stable display identifiers must be derived from system identity; transient array indices are not persistent IDs.

The system menu bar remains accessible. MVP asks the user to enable system auto-hide if they want to use its top region; it does not force-hide system UI. Provide an inset mode below the menu bar. Fullscreen default is to hide the custom bar; showing over fullscreen is opt-in and requires device validation. Reserving tiling space belongs to the window-manager adapter, not a claim that AppKit changes every app's work area.

## MVP interaction

| Area | Required behavior |
| --- | --- |
| Left | Workspace indicators; distinguish focused, occupied, empty; click/keyboard activation through AeroSpace |
| Right | Minute-resolution clock, battery, frontmost app; status providers fail independently |
| Menus | AppKit menus/popovers; escape dismisses; focus returns predictably |
| Settings | Reorder/enable widgets, size/padding, system or opaque appearance, launch at login |
| Permissions | Request only when the enabled feature needs them; denial preserves other widgets |
| Configuration | Validate before applying; invalid reload preserves last known good configuration |
| Accessibility | Names, roles, selected state, actions, keyboard traversal; no color-only state |

## Release acceptance

Two monitors with different scales; a built-in notched screen; an external notch-free screen; unplug/replug; sleep/wake; app activation; fullscreen transitions; menu-bar auto-hide; reduced motion/transparency; light/dark and VoiceOver must pass on physical hardware. Performance must pass the documented protocol. Sign and notarize the app; installation must not instruct users to strip quarantine. Website is static, responsive, keyboard usable, and labels unfinished features accurately.

## Outside MVP

Third-party menu-extra mirroring, recreation of another application's menu tree, arbitrary native binary plugins, a tiling window manager, cloud sync, a marketplace, a Metal renderer, and private WindowServer/Spaces APIs. Script providers can follow once native built-ins and the measurement harness are stable.

## Current implementation

Static Vue/VitePress website, public guides, proposed JSON examples, and Swift geometry foundation only. Every app behavior above is a requirement, not a delivered capability.

## Appearance release gate

System, Light, and Dark are first-class product modes. Follow system appearance live by default, allow explicit overrides, and persist the choice. Validate every workspace state, widget, settings surface, menu/popover, and error in both light and dark; respect increased contrast and reduced transparency. Changing mode must invalidate cached appearance-dependent assets only. Website and docs share a persisted theme preference; the landing retains the Tahoe palette in both modes.
