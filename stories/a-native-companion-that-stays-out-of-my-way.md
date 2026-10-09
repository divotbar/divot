---
name: A native companion that stays out of my way
number: "0006"
created_at: "2026-10-09T16:41:11.852Z"
created_by: api
---
## User story

As a Mac user, I want Divot to feel immediate and remain quiet in the background, so an always-visible bar does not cost battery, interrupt focus, or fight my displays.

## Acceptance criteria

- Swift/AppKit owns persistent panels and bar widgets; settings may use SwiftUI. Native menus, keyboard traversal and VoiceOver actions are required.
- Providers collect off-main, emit bounded immutable snapshots, and invalidate only affected views.
- No permanent rendering loop, unnecessary high-frequency polling, or repeated shell launches for native built-ins.
- Use the performance targets/protocol in docs/performance.md as provisional budgets; publish measured evidence, including helper and compositor costs, before making claims.
- Validate negative screen origins, mixed scales, notch and notch-free displays, sleep/wake, hot-plug, and both appearance variants.
- Permission/integration failures stay local to the affected widget and never strand the whole bar.

## Delivery

Performance/accessibility task #0007 and the human evidence gate #0008. These are acceptance constraints for every other story, not optional late cleanup.
