# Evidence · 0005 AeroSpace workspace adapter

Status: **observed (one machine, one display)** · task 0005 · 2026-10-10. This
records what the AeroSpace adapter reported in one run, and — just as
importantly — what was **not** exercised. It is not a claim that the workspace
indicators render or that multi-monitor behavior works.

Story: [Navigate the workspaces and apps I actually use](../../stories/navigate-the-workspaces-and-apps-i-actually-use.md).

## What was run

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 (build 25F84) |
| Hardware | Apple silicon (arm64), one built-in **notched** display |
| Toolchain | Swift 6.3.3, Xcode 26 |
| AeroSpace | 0.21.3-Beta, CLI at `/opt/homebrew/bin/aerospace` |
| Command | `swift build --package-path macos --product divot`, then `macos/.build/debug/divot --report` |

`divot --report` performs read-only queries only (`list-workspaces` /
`list-windows` / capability `--help` probes); it never subscribes and never
moves a panel.

## Observed in this run

```text
# workspaces
adapter=aerospace
availability=available (workspaces, windows, events, callbacks, monitors)
  1 monitor=1 state=focused apps=[Activity Monitor,ChatGPT,Claude,Finder,Ghostty,RepoOS Hub,RepoOS · repoos,Safari,Zed]
  2 monitor=1 state=occupied apps=[Google Chrome,Safari]
  3 monitor=1 state=empty apps=[]
```

Readings that matter:

1. **Capability detection worked against a real install.** The documented
   `list-workspaces`, `list-windows`, and `subscribe` subcommands all answered,
   and a live `list-workspaces --all --count` liveness query succeeded, so the
   adapter reported `available`.
2. **Real workspace names, focus and occupancy were read**, not invented:
   workspace `1` focused, `2` occupied, `3` empty. The empty workspace remains a
   real manager workspace (a persistent workspace), not a Divot placeholder.
3. **App icons are deduplicated per workspace.** Workspace `1` reported nine
   distinct app identities across its windows; Safari appears only once even
   though it also has a window on workspace `2` (the identity appears once per
   workspace, deduplicated by bundle id).

The documented event stream was also captured with `aerospace subscribe --all`:

```text
{"_event":"focused-workspace-changed","prevWorkspace":"1","workspace":"1"}
{"_event":"mode-changed","mode":"main"}
{"_event":"focus-changed","windowId":32501,"workspace":"1"}
{"_event":"focused-monitor-changed","monitorId":1,"workspace":"1"}
```

These match the JSON shapes the parser expects; `mode-changed` is correctly
classified as not requiring a snapshot refresh.

## Not observed (human/later verification)

- **On-device rendering.** The left-panel workspace row is implemented and
  covered by an offscreen render test that proves the view draws workspace chips
  (a populated row has more distinct pixels than an empty one) and that enabling
  icons attaches every deduplicated app, not just the first. Its on-screen
  appearance with the live app — fonts, spacing, the overflow control, and the
  current-program label — still needs a human look.
- **Options path.** The row's options (`showEmpty`, `showAppIcons`,
  `showDetails`, `maxAppIconsPerWorkspace`) are read at launch from
  `widgets.workspaces` in `~/.config/divot/config.json`, with environment
  overrides; changing them today needs a relaunch, and the full settings surface
  and hot reload remain task 0006.
- **Sustained subscription.** Only the raw documented event lines were captured
  for a few seconds. The app-owned `AeroSpaceSubscription` stream, its teardown,
  and the feed's reconnect-and-refresh behavior over time were not measured on
  hardware (reconnect is covered by fixture tests).
- **Multi-monitor mapping.** This run had a single display; the per-monitor
  filtering (by AeroSpace's `monitor-appkit-nsscreen-screens-id`) and overflow
  are covered by fixtures, not by two live monitors.
- **Activation clicks and performance.** Clicking a chip through the bar and the
  workspace-burst performance budget remain unmeasured on hardware.

No physical multi-display, VoiceOver, or performance claim is made from this run.
