---
id: "0003"
title: Build the native AppKit shell and notch-aware display coordinator
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
story: Divot stays visible when the native menu bar appears
depends_on: ["0009", "0010"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/build-the-native-appkit-shell-and-notch-
review_cli_override: cursor
review_model_override: composer-2.5
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T17:42:47Z"
review_passes: 4
review_rounds: 2
---
## Problem

Create the Swift/AppKit app target and display coordinator around the proven persistent top/below placement strategy.

## Desired UX

Notch-aware bar panels stay visible; when the native menu bar appears they shift below it, and return to the top when it hides. Correct focus and per-display geometry.

## Acceptance criteria

Executable app builds on macOS 26+; tested placement state machine and notch/no-notch geometry; cancellable rapid transitions; reduced-motion reposition; no overlap/focus theft. Below-bar mode recomputes layout and content gap policy. Add app build gate. Physical fullscreen/Spaces/display evidence is recorded separately, never invented.

## Notes for AI

User-approved story supersedes starter hide-on-fullscreen assumption. Read the feasibility report and aligned docs. Do not implement hide as fallback without a product decision.

## Feasibility handoff
Tasks 0009 and 0010 are landed after independent review and validated close-out. Read docs/evidence/0009-native-menu-bar-coexistence.md carefully: top/below geometry and state logic are tested, but actual native menu-bar reveal/hide detection on notched hardware is NOT proven. Build the app shell and reusable public-API observation adapter honestly, exposing indeterminate state and documenting any required Accessibility permission and remaining physical validation. Do not silently convert pointer proximity to true visibility, hide as fallback, or claim continuous behavior has been physically verified. Keep fullscreen/Spaces and window-manager gap policy limits explicit; raise concrete product decisions when needed. Current maintainer Mac uses AeroSpace with a-bar; do not stop a-bar until a usable checked preview exists. The user revoked the spend cap provided configured roles, coding agents and models stay unchanged.

## Focused review repair
Reviewer at 2026-10-09T17:31:16Z requires fixes before sign-off: (1) DisplayLayout.swift screenChanged path reapplies committed stale menu-bar state after queuing a visibility update. Apply latest placement immediately when geometry and visibility change together, with regression coverage for reveal and hide. (2) SystemMenuBarProbe.swift must not treat unvalidated AX hidden/position sample as decisive. Preserve indeterminate until a justified tested visibility policy exists, documenting physical validation needed on notched hardware and lack of a proven pointer-only reveal trigger. Do not substitute silent hiding or pretend feasibility solved. (3) Add meaningful negative-test evidence that the changed native-app build guard rejects a broken app input at branch HEAD without corrupting the working project. Run declared scoped check once after repairs, and obtain a fresh independent review. Preserve configured roles/agents/models. These are targeted fixes to this task, not authorization to land it or change product scope.

## Remaining review repair
Latest independent review at 2026-10-09T17:41:29Z reports no bugs in the focused geometry/AX repairs, but requests meaningful native-app negative-test evidence. Replace or extend the TOML-shape-only test with a subprocess build of an isolated temporary Swift package fixture containing a deliberately broken divot executable target. Execute the same swift build --package-path <fixture> --product divot command shape as the declared gate and assert nonzero exit and appropriate failure output. Keep the real macos tree untouched, no symlink writes into project files, clean temporary artifacts. Preserve the positive production app build check. Add the optional advance-after-immediate-reposition regression if it demonstrates a real pending-state concern; no unrelated expansion. Run the scoped check, obtain a new independent review, and leave all configured roles/agents/models unchanged. Notched visibility and always-visible setting observation remain documented unresolved physical/API work; do not misrepresent them as delivered.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:20:19Z · status inbox→ready
- 2026-10-09T16:20:19Z · note: Bootstrap docs, site, core geometry tests, and RepoOS gate are complete; first native implementation slice is ready for kickoff.
- 2026-10-09T16:41:13Z · story, depends_on, body
- 2026-10-09T16:41:15Z · status ready→inbox
- 2026-10-09T16:41:15Z · note: Product stories add a persistent top/below feasibility gate and docs alignment before the shell.
- 2026-10-09T17:11:41Z · body: section Feasibility handoff
- 2026-10-09T17:11:51Z · status inbox→ready
- 2026-10-09T17:11:52Z · status ready→active, branch
- 2026-10-09T17:21:15Z · status active→review
- 2026-10-09T17:21:15Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T17:23:52Z · note: review pass 1: needs some work
- 2026-10-09T17:23:53Z · status review→active
- 2026-10-09T17:26:33Z · status active→review
- 2026-10-09T17:26:33Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T17:27:45Z · note: review pass 2: needs some work
- 2026-10-09T17:27:45Z · status review→active
- 2026-10-09T17:29:28Z · status active→review
- 2026-10-09T17:29:28Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T17:31:16Z · note: review pass 3: needs some work
- 2026-10-09T17:31:16Z · needs_input
- 2026-10-09T17:32:25Z · review_cli_override
- 2026-10-09T17:32:27Z · review_model_override
- 2026-10-09T17:32:33Z · status review→active
- 2026-10-09T17:32:42Z · body: section Focused review repair
- 2026-10-09T17:40:37Z · status active→review
- 2026-10-09T17:40:37Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T17:41:29Z · note: review pass 4: needs some work
- 2026-10-09T17:41:29Z · needs_input
- 2026-10-09T17:41:29Z · needs_input
- 2026-10-09T17:42:47Z · body: section Remaining review repair
