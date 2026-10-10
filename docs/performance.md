# Performance acceptance and evidence

These are **provisional engineering targets**, not measurements or marketing
claims. Revisit only with recorded evidence. No performance result is published
or committed to this repository yet; the harness and protocol below say how to
produce one, and a person on the reference machine supplies the numbers.

## Default workload

The reference workload is the first-launch bar: workspaces and the frontmost app
on the left; battery percentage, a minute clock with weekday and date, network,
and volume on the right, with the native theme and system appearance. Other
configurations are measured against this baseline.

## Targets

| Metric | Initial target / condition |
| --- | --- |
| Idle app CPU | Below 0.5% of one core averaged over 5 minutes on the default workload |
| Memory | Below 50 MiB physical footprint after warm-up for the default bar |
| Update latency | p95 event receipt to committed view update below 16 ms under normal load |
| Main-thread work | p95 bar update below 2 ms; no synchronous I/O or subprocess waits |
| Idle rendering | No app-driven continuous display loop; unchanged widgets do not redraw |
| Interaction | No visible hitches at 60/120 Hz during workspace changes or popover transitions |
| Provider load | Bounded concurrency, bounded output, no growing queue under bursts |

A committed view update is not proof of pixels appearing; record end-to-visible
latency separately using frame capture when feasible. A static blurred bar may
still cost WindowServer work as underlying windows move. Measure that
contribution rather than assuming zero GPU cost.

## Optimized-build protocol

Build optimized Release code (`-c release`), without a debugger. Record the
following before sampling, and fill every human-supplied field rather than
guessing it:

- commit under test, macOS version, and hardware model of the reference machine;
- display count, per-display scale factors, and refresh rates;
- configuration document, appearance mode, theme family, and material;
- power source (AC/battery) and enabled integrations (workspace manager, login
  item).

Warm up for 60 seconds, sample for five minutes, and repeat at least three
times. Compare identical workloads against SketchyBar and a-bar, and include
every helper process's CPU and wakeups — not just the main process. Also capture
an idle baseline with no custom bar.

Use Instruments Time Profiler, Allocations/physical footprint tools, energy
diagnostics, and animation/hitch traces. The protocol covers, at minimum:

| Scenario | What to capture |
| --- | --- |
| Native default workload | Idle CPU, memory, update latency, main-thread work for network/volume/front-app/clock (time + weekday + date)/battery |
| Both appearance modes | Light and dark, on the native family and the four families |
| All four theme families | Gruvbox, Ayu, Dracula, and Tokyo Night, each light/dark, plus material variants |
| Workspace bursts | Rapid switches and a snapshot burst; coalescing and no growing queue |
| Native-menu-bar reveal/hide | Repeated reveal/hide with the bar behind material; helper and compositor cost |
| Provider cancellation | Stop/reconfigure under load; no leaked observers, timers, or subprocesses |
| Keyboard actions | VoiceOver/keyboard activation of every item and the settings window |
| Helper/compositor cost | Each helper process's CPU/wakeups and WindowServer/GPU work; end-to-visible latency |
| Sleep/wake and hot-plug | Displays added/removed and machine sleep/wake during sampling |

Do not report Activity Monitor screenshots as sufficient evidence for tail
latency. Physical display/fullscreen and VoiceOver checks are documented
separately in [Accessibility physical checks](accessibility-physical-checks.md).

## Harness

`divot --bench` runs a repeatable, in-process harness and prints only what the
current build actually measured. It never writes a target or a prior result, and
it names the checks it cannot make so the output is honest about its scope.

```sh
swift build --package-path macos -c release --product divot
macos/.build/release/divot --bench
macos/.build/release/divot --bench --json \
  --commit "$(git rev-parse HEAD)" \
  --hardware "Mac15,3" \
  --displays "1 display: 3024x1964@2, 120 Hz" \
  --appearance "dark (Gruvbox)" \
  --power "AC"
```

The harness covers the deterministic, in-process part of the matrix:

- **default workload** — presentation of network, volume, front-app, clock
  (time + weekday + date), and battery;
- **appearance modes** — resolving every family under light and dark;
- **theme families** — resolving and contrast-auditing all four families ×
  light/dark;
- **workspace bursts** — 256 snapshots through the pure feed state machine;
- **provider cancellation** — subscription teardown and stale-emission rejection;
- **native-menu-bar reveal/hide** — rapid placement cycles through the display
  coordinator;
- **keyboard actions** — the default action mapping for every widget;
- **accessibility contract** — every default item is labelled and roled for
  every family × appearance, and the bar builds and restyles for each.

It runs on a shared CI runner, where timing is **advisory only** and no threshold
is asserted. The Release numbers a person captures on the stable reference
machine are the evidence; helper-process CPU/wakeups, WindowServer/compositor
cost, end-to-visible latency, and physical display behavior require Instruments
and hardware the harness cannot reach.

## Accessibility regression checks

`swift test --package-path macos` runs the automated accessibility contract:

- every widget presentation — default, loading, and every honest unavailable
  state — carries a non-empty accessible label;
- every family variant clears the per-role contrast floors (AA 4.5:1 for text,
  3:1 for state/icons, 2.5:1 for the accent/chrome role);
- an error is never signalled by color alone: it also carries a distinct glyph
  and an announced reason;
- interactive items expose a button role, a label, and help; non-interactive
  items expose static text and refuse a press;
- the keep-awake state is announced through both the battery label and the
  indicator;
- an accessible label survives every theme restyle.

## Regression checks

Geometry and config validation run in CI. Performance ceilings need a stable
physical reference machine; shared CI timing is advisory. The harness above is
the app benchmark; it is not a substitute for the physical reference run. Store
reports under `docs/benchmarks/` with raw captures linked outside Git if large.
**No performance results exist in this starter** — the numbers a claim needs
must be measured, not inferred from this document.
