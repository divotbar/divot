# The trail ahead

## Here today

- Product, architecture, infrastructure, and performance specifications.
- This Vue/VitePress landing page and documentation site.
- Versioned JSON configuration examples with a structural validator; the parser, store, and settings surface are implemented and validated against them.
- A Swift foundation: `DivotCore` geometry/placement tests, `DivotAppKit` platform adapter, and a buildable AppKit shell (not physically validated).
- Built-in status providers (frontmost app, battery/power, date/time, network, and volume) wired into the bar with lifecycle, cancellation, and unavailable states (unit-tested, not physically validated).
- A performance harness (`divot --bench`) and automated accessibility/contrast regression checks (unit-tested; no Release measurements or VoiceOver/display results published yet).
- A local preview packager (`just app-package`, `just app-smoke`, `just app-run`) that builds an ad-hoc-signed `.app` with a versioned archive and checksum; not a signed or notarized public release.

## First native release

AppKit panel shell with persistent top/below placement → native providers (workspaces, frontmost app, battery, date/time, network, and volume) → AeroSpace and yabai workspaces → versioned configuration and settings → native default plus four theme families → accessibility/device QA → measured performance → signed and notarized release. The status providers, both workspace adapters (fixture-tested), the versioned configuration and settings, the date/time split and the Appearance bar item, the four theme families, and a local ad-hoc-signed preview package are implemented; physical validation, accessibility/device QA, performance evidence, and the signed/notarized public release remain planned.

There is no promised release date. Each step has its own acceptance criteria and review. A downloadable build appears only after the release gates pass.

## After that

The yabai and AeroSpace workspace adapter layers are implemented with fixtures; more native widgets, per-display customization, and an opt-in script protocol follow, and live yabai/AeroSpace validation remains. An update mechanism may follow. Native macOS Spaces has been researched and is not planned: public APIs cannot list, switch, or map Spaces without private system APIs, which stay outside the initial scope.

## Get involved

[Build with us](../contributing/). Contributions to the docs, tests, native shell, and measurement harness are welcome.
