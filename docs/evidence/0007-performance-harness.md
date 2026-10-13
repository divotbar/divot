# Evidence · 0007 performance harness and accessibility regression checks

Status: **harness and automated checks implemented and tested; no measured
performance evidence yet** · task 0007 · 2026-10-10. This records what the
harness and the accessibility contract actually do, what is covered by tests,
and what a person must still measure on real hardware. It is not a claim that
any CPU, memory, latency, compositor, or VoiceOver result was observed.

Story: [A native companion that stays out of my way](../../stories/a-native-companion-that-stays-out-of-my-way.md).
Protocol: [Performance](../performance.md). Physical checklist:
[Accessibility physical checks](../accessibility-physical-checks.md).

## What was built

| Piece | Path | Role |
| --- | --- | --- |
| Pure harness | `macos/Sources/DivotCore/PerformanceHarness.swift` | Scenarios, environment, measurements, audited contrast checks, and the human-check list. |
| AppKit harness | `macos/Sources/DivotAppKit/PerformanceHarnessAppKit.swift` | View-level accessibility audit and per-family render measurement. |
| CLI | `macos/Sources/DivotApp/DivotBench.swift`, `main.swift` | `divot --bench [--json]` with `--commit/--hardware/--displays/--appearance/--power` facts. |
| Core checks | `macos/Tests/DivotCoreTests/PerformanceHarnessTests.swift`, `AccessibilityRegressionTests.swift` | Structural harness coverage and the pure accessibility contract. |
| AppKit checks | `macos/Tests/DivotAppKitTests/AccessibilityContractTests.swift` | View role/label/help/press contract across every family × appearance. |

## What the harness measures

`divot --bench` runs on the current build and prints only what it observed. It
covers the deterministic in-process part of the protocol: the native default
workload (network, volume, front-app, clock with weekday/date, battery), both
appearance modes, all four theme families × light/dark with the contrast audit,
workspace bursts through the pure feed state machine, subscription teardown and
stale-emission rejection for provider cancellation, rapid native-menu-bar
reveal/hide placement, the default action mapping, and the view-level
accessibility/render contract.

> Note: this record predates task 0033; the default workload now uses the split
> `date`/`time` items rather than the combined clock.

The harness reports the build configuration it ran in and warns when it is not
Release. It leaves the commit, hardware, display configuration, appearance, and
power source blank unless a person supplies them, and it names the
helper-process, compositor, physical-display, VoiceOver, and reference-machine
checks it cannot make.

## Tests

`swift test --package-path macos` covers:

- **Harness coverage**: every `PerformanceScenario` is exercised, every
  measurement is finite and non-negative, and the contrast audit returns 56
  checks (four families × two variants × seven roles, the seventh being the
  fixed charging green added in #0074) that all clear their floors.
- **No invented evidence**: the auto-detected environment leaves every
  human-supplied field `nil`, and the human-check list names helper, compositor,
  and VoiceOver work.
- **Accessible labels**: every default, loading, and unavailable widget
  presentation carries a non-empty label; an error also carries a glyph.
- **Contrast**: every family variant clears its per-role floor in the pure layer.
- **View contract**: interactive items expose a button role, label, and help and
  perform a press; non-interactive items expose static text and refuse one; a
  restyle keeps the label; every default item is labelled and roled under every
  family × appearance.
- **State without color**: keep-awake is announced through the battery label and
  indicator; error uses a glyph as well as a color.

## Honest status by claim

**Implemented and covered by tests**: the harness scenarios and report shape,
the contrast audit, the accessibility contract at the core and view layers, and
the CLI plumbing.

**Observed in this run (not evidence)**: a local, debug-build `divot --bench`
run completed and printed a well-formed report. That is a smoke check that the
wiring runs; it is **not** a benchmark, and no number from it is published or
committed.

**Not verified at all — a human must supply (do not treat as working):**

- Any Release-build measurement on the stable reference machine: idle CPU,
  memory, update latency, main-thread work, and burst behavior.
- Helper-process CPU/wakeups, WindowServer/compositor cost, and end-to-visible
  latency: these need Instruments and a real display.
- Physical display/fullscreen/Spaces/sleep-wake/hot-plug behavior, and every
  VoiceOver check in `docs/accessibility-physical-checks.md`.
- Any comparison against SketchyBar or a-bar, and the no-custom-bar baseline.

## Commands

```sh
swift test --package-path macos
swift build --package-path macos -c release --product divot
macos/.build/release/divot --bench
macos/.build/release/divot --bench --json --commit "$(git rev-parse HEAD)"
```
