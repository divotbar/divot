# Accessibility physical checks

Automated checks live in `swift test --package-path macos` (see
[Performance](performance.md#accessibility-regression-checks)). They cannot make
the checks below, because those need VoiceOver, real displays, and a person. This
is the checklist a human fills in; no result here is recorded until it is
observed on the target machine. Do not mark an item passing from the automated
suite.

Record for each run: commit, macOS version, hardware, display configuration,
appearance mode, theme family, and whether Accessibility permission was granted.

## VoiceOver

- [ ] Launch Divot and turn VoiceOver on. Every bar item is reachable and reads
      its full label (battery, clock with weekday/date, network, volume,
      front-app, workspace chips), not just its glyph.
- [ ] The reading order matches the visual left/right groups on each display.
- [ ] Activating an interactive item with `VO-Space` performs the same action as
      a click: battery toggles keep-awake, network/volume/clock open the matching
      System Settings pane, front-app activates the running app.
- [ ] The keep-awake state is announced, and turning it on/off updates the
      announcement without a relaunch.
- [ ] An unavailable widget (permission denied, failed, no manager) is announced
      with its reason and does not strand the rest of the bar.
- [ ] Focused/occupied/empty workspace chips are distinguishable by VoiceOver
      without relying on color.
- [ ] The settings window is fully traversable by keyboard alone (`Tab`,
      `Shift-Tab`, arrow keys), every control has a label, and the family, mode,
      material, and accent controls announce their current value.
- [ ] Opening and closing the settings window never steals focus from the
      frontmost app once it closes.

## Display and fullscreen

- [ ] Negative-origin display (a monitor to the left of the primary) places each
      panel in the correct coordinates; nothing clips or lands off-screen.
- [ ] Mixed scale factors (for example a 1× external next to a 2× built-in)
      render at the correct backing scale with no blur or half-pixel seam.
- [ ] Notch and notch-free displays both behave: the bar splits around the
      camera housing on notched hardware and the notch gap is dropped in the
      below-native-bar row.
- [ ] Native-menu-bar reveal/hide: the bar moves below the revealed bar and
      returns to the top edge when it hides, on both notched and notch-free
      displays. A resolved notched display holds rather than guessing when the
      state is undecidable.
- [ ] Fullscreen: entering and leaving fullscreen on each display leaves the bar
      reachable and never over the app's own chrome in a way that steals clicks.
- [ ] Spaces: switching Spaces and moving windows behind the material keeps the
      bar visible and interactive.
- [ ] Sleep/wake: after wake, panels return to the correct display and placement
      with no duplicate or orphan panel.
- [ ] Monitor hot-plug: adding or removing a display does not draw an
      intermediate layout on the other displays and does not leave an orphan
      panel.
- [ ] Reduced Motion and Reduced Transparency system settings are honored: no
      animation and an opaque background respectively.
- [ ] WindowServer/GPU idle cost is measured with Instruments, not assumed zero,
      while windows move behind the material.

## Evidence

Store captured reports under `docs/benchmarks/`. Reference the capture, do not
paste a screenshot, and do not record a pass you did not observe in this run.
