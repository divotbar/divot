# Build with us

Divot is MIT licensed and in its foundation stage. The source repository currently exists locally; a public remote and issue tracker have not been provisioned. There is no invented GitHub URL or download link on this site.

## Useful first contributions

- AppKit app target and display coordinator with persistent top/below placement (delivered; not physically validated).
- Native status providers — frontmost app, battery, a minute clock, network, and volume — are delivered and unit-tested.
- Workspace adapters (AeroSpace and yabai) with integration fixtures (delivered; both need physical validation).
- Versioned configuration, settings, and launch at login (delivered).
- Gruvbox, Ayu, Dracula, and Tokyo Night theme families.
- Accessibility and physical-device QA.
- Performance measurement harness.

## Working locally

```sh
bun install --frozen-lockfile
bun run check
swift test --package-path macos
```

Project requirements live in `docs/`; public guides live in `site/`. Keep both aligned with delivered behavior. Native built-ins use system frameworks without third-party runtime dependencies. The bar uses AppKit; SwiftUI is permitted for settings.

## RepoOS workflow

Use `repoos list` for board context. Task creation/metadata go through the CLI or API, never direct edits to task Markdown. Work in the assigned branch/worktree, check before review, and let the human-approved RepoOS close-out pipeline land changes.

## Evidence

Don't invent device testing, signing, or benchmark results. Record what ran and what remains unverified. Keep planned capabilities clearly marked. The interactive preview is intentionally illustrative.

## License

Code and documentation: MIT, copyright 2026 Divot contributors. The Lake Tahoe photograph has its own attribution/share-alike license; see [credits](../credits).
