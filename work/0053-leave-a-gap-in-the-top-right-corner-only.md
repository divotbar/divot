---
id: "0053"
title: Leave a gap in the top-right corner only while the camera or mic is in use
type: feature
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/leave-a-gap-in-the-top-right-corner-only
created_at: "2026-10-12T08:20:42Z"
updated_at: "2026-10-12T08:32:34Z"
review_rounds: 1
review_passes: 1
---
## Problem

macOS draws a green camera-in-use dot in the top-right corner of the screen, over every app window. It draws over Divot's right-side items during a video call, and the maintainer wants to avoid that overlap. The dot appears only while a call is using the camera or microphone.

AVFoundation's `isInUseByAnotherApplication` returned false for both the camera and microphone during a live call, so it can't be used as the signal.

## Desired UX

- While the camera or microphone is in use, Divot keeps the top-right corner clear by leaving a gap sized to the dot. Otherwise the bar uses the full width.
- A Settings toggle, "Keep room for the camera indicator", on by default.

## Acceptance criteria

- Detect capture in use with the public `IOPMCopyAssertionsByProcess` API: a process holding a sleep-prevention assertion from camera or audio capture (for example `cameracaptured` or the coreaudiod device assertions). Do not use private APIs or shell out to `pmset`.
- Check every 2 seconds while the bar is visible, with a fixed interval, and stop checking when the bar is hidden. Document why polling is needed.
- The gap applies only while capture is detected. Test the on and off transitions with a fake assertion source.
- Verify live during a call on the packaged app: the corner is clear during the call and the full width is restored after it. Record the observations in the task.
- Add the Settings toggle, persisted through the configuration store.
- repoos check passes.

## Notes for AI

Keep the detection in its own type behind a protocol so the tests use a fake source. Do not change the keep-awake cup, which is handled in #0051.

## Live verification
Automated coverage: `CaptureInUseTests` drives the on and off transitions with a fake `CaptureAssertionReading` (a `cameracaptured` assertion or a `coreaudiod` microphone-device assertion turns the gap on; removing it turns the gap off; an output-only `coreaudiod` assertion does not). `BarGeometryTests`/`DisplayLayoutTests` assert the right edge is trimmed only at the top edge, and a `DisplayCoordinator` test drives the same transition through the panel placement.

Pending human verification: the packaged-app check during a real call has **not** been performed in this run and no observation is recorded. A person must run the packaged app, start a video call, confirm the top-right corner is clear while macOS draws the privacy dot, end the call, and confirm the bar returns to full width. Record the observed build, date, call app, whether audio-only playback leaves the corner full, and whether the 24 pt reserve looked right. If a real microphone is missed, widen the `coreaudiod` match in `CaptureInUseDetector`.

## Activity

- 2026-10-12T08:20:42Z · created · njachowski@gmail.com
- 2026-10-12T08:20:43Z · status inbox→ready
- 2026-10-12T08:20:43Z · status ready→active, branch
- 2026-10-12T08:28:07Z · body: section Live verification
- 2026-10-12T08:29:49Z · status active→review
- 2026-10-12T08:29:49Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T08:30:28Z · note: review pass 1: needs some work
- 2026-10-12T08:30:28Z · status review→active
- 2026-10-12T08:31:35Z · body: section Live verification
- 2026-10-12T08:32:34Z · status active→review
- 2026-10-12T08:32:34Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
