# Performance acceptance and evidence

These are **provisional engineering targets**, not measurements or marketing claims. Revisit only with recorded evidence.

## Default workload

The reference workload is the first-launch bar: workspaces and the frontmost app on the left; battery percentage, network, volume, and a minute clock with weekday and date on the right, with the native theme and system appearance. Other configurations are measured against this baseline.

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

A committed view update is not proof of pixels appearing; record end-to-visible latency separately using frame capture when feasible. A static blurred bar may still cost WindowServer work as underlying windows move. Measure that contribution rather than assuming zero GPU cost.

## Protocol

Build optimized Release code, without a debugger. Record commit, OS, hardware, display count/scales/refresh rates, configuration, appearance, power source, and enabled integrations. Warm up for 60 seconds, sample for five minutes, repeat at least three times. Compare identical workloads against SketchyBar and a-bar; include helper process CPU and wakeups. Also capture an idle baseline without any custom bar.

Use Instruments Time Profiler, Allocations/physical footprint tools, energy diagnostics, and animation/hitch traces. Measure idle, both appearance modes and all four theme families, rapid workspace switching, repeated popovers, moving windows behind material, graph sampling, native-menu-bar reveal/hide, sleep/wake, and monitor hot-plug. Do not report Activity Monitor screenshots as sufficient evidence for tail latency.

## Regression checks

Geometry and config validation can run in CI. Performance ceilings need a stable physical reference machine; shared CI timing is advisory. Add a real app benchmark harness before declaring v0.1 ready. Store reports under `docs/benchmarks/` with raw captures linked outside Git if large. No performance results exist in this starter.
