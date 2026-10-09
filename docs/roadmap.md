# Roadmap

## Foundation · present

RepoOS initialization, requirements, architecture ADR, performance protocol, static landing/docs website, proposed JSON configurations, and tested native geometry library. Documentation is aligned with the six user stories; no downloadable app.

## 0.1 · useful native bar

1. AppKit app target and display adapter: left/right panels with persistent top/below placement, focus, multiple displays, notch-free fallback, overflow.
2. Provider pipeline: workspaces, frontmost app, battery, network, volume, and a minute clock with weekday/date; notifications and cancellation.
3. Workspace adapter: AeroSpace capabilities/events, workspace indicators and async actions.
4. Versioned configuration (left/right item groups, namespaced options), atomic reload, settings, launch at login.
5. Appearance: native default plus the Gruvbox, Ayu, Dracula, and Tokyo Night families with light/dark variants; accessibility.
6. Physical device QA and performance evidence.
7. Developer ID signing/notarization and source/build release instructions.

## 0.2 · personal workflows

Yabai as a second workspace adapter, per-display profiles, additional native status providers, and a safe script protocol. Every item remains subject to measured cost and independent failure handling.

## Later

Native macOS Spaces research outcome, an optional update mechanism, and configuration editor improvements. Private APIs, mirrored menu extras, and a marketplace are not baseline commitments.

Create execution tasks through `repoos new` when the control-plane project is live. The initial inbox vision/setup tasks are suggestions; do not mark them complete because this document exists.
