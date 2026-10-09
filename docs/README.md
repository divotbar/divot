# Engineering context

Read in this order:

1. [Product requirements](product-requirements.md): audience, behaviors, acceptance, boundaries.
2. [Architecture](architecture.md): panels, rendering, providers, and ownership.
3. [Infrastructure](infrastructure.md): tooling, repository, checks, distribution.
4. [Performance](performance.md): provisional budgets and measurement protocol.
5. [Configuration](configuration.md): proposed v2 contract and migration rules.
6. [Roadmap](roadmap.md): delivery order and release gates.
7. [Native architecture ADR](adr/0001-native-appkit.md).
8. [Native menu-bar feasibility evidence](evidence/0009-native-menu-bar-coexistence.md): what public APIs were observed to do, and the open decision.
9. [App shell evidence](evidence/0003-app-shell.md): what the AppKit shell and display coordinator actually do, and what still needs physical proof.

`docs/` is engineering context. `site/` is public documentation and marketing. Keep implementation status consistent across both. The app is not shipping yet.
