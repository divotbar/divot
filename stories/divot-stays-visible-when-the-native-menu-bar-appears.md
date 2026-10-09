---
name: Divot stays visible when the native menu bar appears
number: "0002"
created_at: "2026-10-09T16:41:10.801Z"
created_by: api
---
## User story

As a Mac user, I want Divot to remain visible while I access the native menu bar, so my workspaces and status never disappear during normal desktop use.

## Required behavior

When the native macOS menu bar is hidden, Divot occupies the top edge. When it appears, Divot shifts down below it; when it hides, Divot returns to the top. If the native bar is configured always visible, Divot remains below it. Do not replace this with disappearing or a permanent below-bar-only layout. The requirement is continuous visibility, not a recreation of app menus.

## Acceptance criteria

- Detect actual native bar visibility and transition between top and below-bar positions without overlap, flashing, duplicate bars, or focus theft.
- Rapid reveal/hide cycles converge to the actual system state; intermediate animations are cancellable, and Reduced Motion uses an immediate reposition.
- Validate menu-bar auto-hide, always-visible mode, app menus, multiple displays/scales, fullscreen/Spaces, notch-free displays, sleep/wake, and hot-plug.
- Do not silently implement the starter's earlier fullscreen-hide default. The user's intent is persistent visibility; record platform constraints and obtain a product decision if public APIs cannot provide it in a scenario.
- Moving below the native bar recomputes geometry; it must not carry an unusable notch gap into the inset row or cover tiled content without a documented window-manager gap policy.
- Use public, supported APIs and event-driven observation where possible. No permanent high-frequency polling loop or unreviewed private API workaround.

## Feasibility gate

Prove visibility detection, ordering, focus and repositioning early on macOS 26. Document what is reliable, what needs physical proof, and what is unsupported. If the design is impossible under current constraints, escalate with evidence rather than hiding the requirement.
