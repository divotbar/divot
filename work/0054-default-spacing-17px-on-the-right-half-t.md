---
id: "0054"
title: "Default spacing: 17px on the right, half that between the Divot icon and workspaces, and 12px for the front app"
type: feature
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/default-spacing-17px-on-the-right-half-t
created_at: "2026-10-12T08:30:32Z"
updated_at: "2026-10-12T08:52:15Z"
review_rounds: 2
review_passes: 2
---
## Problem

The bar spacing is wrong in three places, from the maintainer's screenshots:

1. The right side needs more space between its items. 17px is the right gap.
2. Applying 17px on the right makes the gap between the Divot icon and the workspaces too wide. That gap should be half of the right-side gap by default.
3. The front app next to the Divot icon should keep a 12px gap, and that gap must not change with the side spacing.

## Desired UX

- Right-side items are separated by 17px by default.
- The gap between the Divot icon and the workspace group defaults to half of the right-side gap, so 8.5px.
- The gap between the front app and the Divot icon stays 12px, regardless of the side spacing setting.

## Acceptance criteria

- Add `rightItemSpacing` (default 17), and a left default that is half of it, persisted through the configuration store, with sliders in Settings.
- The Divot-icon-to-workspaces gap follows the half-spacing default unless the user sets it explicitly.
- The front-app-to-Divot-icon gap is fixed at 12px and is not affected by any side-spacing setting.
- Tests cover the 17px default on the right, the half-value default on the left, and the fixed 12px front-app gap when the side spacing changes.
- Verify on the packaged app; record the measured gaps in the task. The maintainer confirms the look.
- repoos check passes.

## Notes for AI

Keep the change to item spacing in the layout code. Do not change the chips, the icon sizes or the opacity, which are in #0052.

## Verification
Automated measurements from the item-layout tests (all passing in this run):

- Right group: adjacent items are 17 pt apart by default (rightGroupItemsAreSeventeenPointsApartByDefault; defaultItemSpacingIsSeventeenOnTheRightAndHalfOnTheLeft).
- Left group: the Divot-mark-to-first-item gap and the item-to-item gap are 8.5 pt by default, i.e. half the right gap (leftGroupUsesHalfTheRightSpacingAfterTheDivotIconByDefault).
- Front app: the gap immediately before the front-app item on the left is a fixed 12 pt and does not move when the left or right spacing sliders change (frontAppToDivotIconGapStaysTwelveWhenSideSpacingChanges). With the real default left order [workspaces, front-app] the gap after the Divot mark is 8.5 pt and the workspace-to-front-app gap is 12 pt (defaultWorkspaceOrderShowsHalfAfterTheIconAndTwelveBeforeTheFrontApp, using the real elastic WorkspaceBarView width, not a status-item surrogate).
- Config: rightItemSpacing default 17 and leftItemSpacing default 8.5 parse, persist through ConfigurationStore, and reach the render metrics (itemSpacingDefaultsToSeventeenAndHalfAndParsesExplicitly; savePersistsItemSpacingAndOmitsItWhenDefault; itemSpacingDefaultsAndEachSidePersistsIndependently).
- REPOOS_CHECK_CHANGED=main repoos check passed, including the packaged-app smoke test (native-app-bundle).

Review round 1 found no bugs. Follow-ups from that review: added the real-default-order layout test above; documented on BarMetrics.groupWidth/fits that they assume one uniform gap (the rendered BarContentView.layout accounts for the fixed front-app gap directly). Independent left/right sliders are intentional (the left setting persists on its own and only defaults to half the right). The fixed 12 pt rule is the gap before front-app on the left, beside the Divot mark.

Pending human verification: the on-screen packaged-app pixel measurements and the maintainer's visual confirmation of the look are not observable in this run. A human must launch the packaged app, measure the three gaps, and confirm them.

## Activity

- 2026-10-12T08:30:32Z · created · njachowski@gmail.com
- 2026-10-12T08:30:33Z · status inbox→ready
- 2026-10-12T08:30:33Z · status ready→active, branch
- 2026-10-12T08:43:32Z · body: section Verification
- 2026-10-12T08:46:55Z · status active→review
- 2026-10-12T08:46:56Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T08:47:50Z · note: review pass 1: needs some work
- 2026-10-12T08:47:50Z · status review→active
- 2026-10-12T08:49:20Z · body: section Verification
- 2026-10-12T08:49:47Z · status active→review
- 2026-10-12T08:49:47Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T08:50:48Z · note: review pass 2: needs some work
- 2026-10-12T08:50:48Z · status review→active
- 2026-10-12T08:51:13Z · status active→review
- 2026-10-12T08:51:13Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T08:52:15Z · note: review pass 3: good to go
