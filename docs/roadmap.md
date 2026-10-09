# Roadmap

## Foundation · present

RepoOS initialization, requirements, architecture ADR, performance protocol, static landing/docs website, proposed JSON configurations, and a tested native core. An executable AppKit app shell and notch-aware display coordinator now build (task 0003); it is not physically validated and there is no downloadable, signed app.

## 0.1 · useful native bar

1. AppKit app target and display adapter: executable shell and per-display left/right panels with persistent top/below placement are in place (task 0003); item rendering, overflow, and physical validation remain.
2. Provider pipeline: the native providers for the frontmost app, battery/power, a minute clock with weekday/date, network, and volume are implemented with lifecycle, notifications, cancellation, and contextual unavailable states (task 0004); physical validation of the status widgets remains.
3. Workspace adapter: the AeroSpace adapter layer — capability detection, documented-CLI reads, event-driven refresh with reconnect, async actions, deduplicated app identities, per-monitor/overflow rules, and the left-panel workspace row — is implemented (task 0005); the yabai adapter behind the same interface is implemented and fixture-tested (task 0012); on-device appearance, click activation, app-icon rendering, and live yabai behavior remain to be physically validated.
4. Versioned configuration (left/right item groups, namespaced options), atomic reload, settings, launch at login.
5. Appearance: native default plus the Gruvbox, Ayu, Dracula, and Tokyo Night families with light/dark variants; accessibility.
6. Physical device QA and performance evidence.
7. Developer ID signing/notarization and source/build release instructions.

## 0.2 · personal workflows

The yabai adapter layer (task 0012) is implemented and fixture-tested; per-display profiles, additional native status providers, a safe script protocol, and live yabai validation remain. Every item remains subject to measured cost and independent failure handling.

## Later

Native macOS Spaces research outcome, an optional update mechanism, and configuration editor improvements. Private APIs, mirrored menu extras, and a marketplace are not baseline commitments.

Create execution tasks through `repoos new` when the control-plane project is live. The initial inbox vision/setup tasks are suggestions; do not mark them complete because this document exists.
