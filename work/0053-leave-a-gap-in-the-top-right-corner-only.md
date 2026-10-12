---
id: "0053"
title: Leave a gap in the top-right corner only while the camera or mic is in use
type: feature
status: ready
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T08:20:42Z"
updated_at: "2026-10-12T08:20:43Z"
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

## Activity

- 2026-10-12T08:20:42Z · created · njachowski@gmail.com
- 2026-10-12T08:20:43Z · status inbox→ready
