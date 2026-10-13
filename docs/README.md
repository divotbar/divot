# Engineering context

Read in this order:

1. [Product requirements](product-requirements.md): audience, behaviors, acceptance, boundaries.
2. [Architecture](architecture.md): panels, rendering, providers, and ownership.
3. [Infrastructure](infrastructure.md): tooling, repository, checks, distribution.
4. [Performance](performance.md): provisional budgets, the optimized-build protocol, and the harness.
5. [Accessibility physical checks](accessibility-physical-checks.md): the VoiceOver/display/fullscreen checklist a person runs.
6. [Configuration](configuration.md): versioned configuration contract and migration rules.
7. [Roadmap](roadmap.md): delivery order and release gates.
8. [Local preview](local-preview.md): packaging, install/run, and the remaining hardware checklist.
9. [Troubleshooting and known limitations](troubleshooting.md): constraints and workarounds.
10. [Native architecture ADR](adr/0001-native-appkit.md).
11. [Native menu-bar feasibility evidence](evidence/0009-native-menu-bar-coexistence.md): what public APIs were observed to do, and the open decision.
12. [App shell evidence](evidence/0003-app-shell.md): what the AppKit shell and display coordinator actually do, and what still needs physical proof.
13. [Native providers evidence](evidence/0004-native-providers.md): what the provider pipeline and status widgets do, and what still needs physical proof.
14. [AeroSpace workspace adapter evidence](evidence/0005-aerospace-workspace-adapter.md): the live read-only observation and what remains unverified.
15. [Native macOS Spaces feasibility](evidence/0013-native-spaces-feasibility.md): why public APIs cannot drive a native Spaces adapter, and the scope that is honestly supportable.
16. [Performance harness evidence](evidence/0007-performance-harness.md): what the harness and accessibility checks cover, and what a person must still measure.
17. [Local preview evidence](evidence/0014-local-preview.md): what the packaging smoke test observed, and what it does not prove.
18. [Cursor-reveal slide evidence](evidence/0023-cursor-reveal-menu-bar-slide.md): automated checks for task 0023, and what still needs a screen capture.
19. [Notification banner overlap evidence](evidence/0075-notification-banner-overlap.md): why notification banners overlap the bar when auto-hide is on, and whether a fix is possible.
20. [Popover and bar snapshot testing](popover-snapshot-testing.md): offscreen rendering of the popovers and the right-hand bar group for visual review and pixel assertions; local evidence only, no golden images; also the `Divot bar` RepoOS shot target.

`docs/` is engineering context. `site/` is public documentation and marketing. Keep implementation status consistent across both. The app is not shipping yet.
