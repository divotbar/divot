# ADR 0001 · AppKit owns the bar

Status: accepted initial direction · 2026-10-10.

## Decision

Use Swift and AppKit for persistent panels and bar widgets. Use cached layer-backed rendering and native menus. Permit SwiftUI for settings. Start with public APIs, no runtime third-party dependencies, and no Metal render loop.

## Reason

The primary requirement is predictable native behavior and control over update scope, focus, geometry, and idle work. An explicit view/provider architecture is appropriate for a small persistent desktop surface. This decision is not a claim that SwiftUI, C, or Rust is categorically faster; benchmark the real implementation.

## Consequences

More manual layout/accessibility work than SwiftUI. Two panels per display avoid notch hit regions but require coordinated ordering and transitions. Public APIs may limit full replacement of system menus. Configuration remains the extension surface; arbitrary loaded code is excluded initially.

Revisit rendering or language only with profiles showing a concrete bottleneck and a representative comparison.
