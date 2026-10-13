# Light on purpose

A persistent bar should spend most of its time waiting for something useful to happen.

## The approach

Swift and AppKit, a shallow view hierarchy, cached text/icons, and targeted updates. Native notifications replace polling wherever possible. Core Animation handles brief transitions; the app should have no permanent rendering loop.

## The targets

The initial engineering budgets are below 0.5% of one CPU core at idle, below 50 MiB physical footprint for the default setup, and below 16 ms p95 from event receipt to committed view update. The reference default is the first-launch bar: workspaces and the active app on the left; battery, a minute time, network, and volume on the right (the date item is optional). These are **targets, not achieved measurements**. A committed update is not the same as a visible frame.

## How we will measure

Optimized Release builds on a recorded reference Mac. Repeat idle and interaction workloads, including both appearance modes and all four theme families. Include helpers and WindowServer effects, and compare identical widgets with other bars. Publish hardware, OS, configuration, timing method, and limitations with results.

An in-process harness (`divot --bench`) now covers the deterministic part — the default workload, both appearance modes, the curated families, workspace bursts, provider cancellation, menu-bar reveal/hide, keyboard actions, and the accessibility contract — but it never reports a target or a prior result. Helper-process cost, WindowServer/compositor cost, and on-device VoiceOver/display checks are captured separately with Instruments and a person. **No performance results have been published yet**; the numbers a claim needs must be measured on the stable reference machine, not inferred from these targets.

Physical validation also covers negative display origins, mixed scales, 60/120 Hz displays, notch and notch-free hardware, sleep/wake, hot-plug, fullscreen, and Spaces. CI tests geometry, configuration, and the automated accessibility contract, but cannot establish the complete desktop experience.

## What helps

Use a minute time, avoid constant graphs when unnecessary, choose opaque material when you prefer it, and enable only useful integrations. The built-in status providers update from system notifications (power, network path, audio, and app activation) and the time wakes at the next minute boundary, so there is no polling loop; their measured cost is not yet documented and needs the physical performance run.
