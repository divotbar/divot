# Light on purpose

A persistent bar should spend most of its time waiting for something useful to happen.

## The approach

Swift and AppKit, a shallow view hierarchy, cached text/icons, and targeted updates. Native notifications replace polling wherever possible. Core Animation handles brief transitions; the app should have no permanent rendering loop.

## The targets

The initial engineering budgets are below 0.5% of one CPU core at idle, below 50 MiB physical footprint for the default setup, and below 16 ms p95 from event receipt to committed view update. The reference default is the first-launch bar: workspaces and the active app on the left; battery, a clock with weekday and date, network, and volume on the right. These are **targets, not achieved measurements**. A committed update is not the same as a visible frame.

## How we will measure

Optimized builds on a recorded reference Mac. Repeat idle and interaction workloads, including both appearance modes and all four theme families. Include helpers and WindowServer effects, and compare identical widgets with other bars. Publish hardware, OS, configuration, timing method, and limitations with results.

Physical validation also covers 60/120 Hz displays, sleep/wake, and multiple displays. CI tests geometry and configuration, but cannot establish the complete desktop experience.

## What helps

Use a minute clock, avoid constant graphs when unnecessary, choose opaque material when you prefer it, and enable only useful integrations. As providers land, their expected costs will be documented here.
