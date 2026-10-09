# Evidence · 0013 native macOS Spaces feasibility

Status: **research complete, no native adapter recommended** · task 0013 ·
2026-10-10. This is a capability report, not an implementation. It records what
public APIs were observed to do in one run, why the rest is unavailable without
private APIs, and the scope that is honestly supportable.

Story: [Navigate the workspaces and apps I actually use](../../stories/navigate-the-workspaces-and-apps-i-actually-use.md).

## Question

Can Divot build a native macOS Spaces adapter — list Spaces, switch Spaces, and
map apps to Spaces, across multiple displays — using only public/supported APIs,
without private symbols or disabling System Integrity Protection?

Short answer: **no.** Public APIs expose displays and the active Space's on-screen
windows, and a notification that *something* changed. They do not expose a Space
identity, do not enumerate Spaces, do not switch a Space, and do not attribute a
window to a Space. That is the recommendation's basis, and it is why the story
calls this an honest unavailable state rather than fake native Spaces support.

## What was run

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 (build 25F84) |
| Hardware | Apple silicon (arm64), one built-in **notched** display, `CGDirectDisplayID 1` |
| Toolchain | Swift 6.3.3, Xcode 26 |
| Probe | `swift build --package-path macos`, then `macos/.build/debug/divot-spaces-probe` (`--windows` for the per-window table) |

The probe is read-only and public-API-only. It imports no private framework,
loads no private symbol, moves no panel, and never switches a Space. Single
machine, single display: every multi-display and real Space-switch claim below is
marked as unobserved.

## Observed in this run

The probe's capability report and observation pass, verbatim:

```text
# divot spaces probe
os=26.5.2
api=public-only (no private Symbols; read-only)
# capability: what a native Spaces adapter would need
  listSpaces=private-only — ... enumerating Spaces uses the private SkyLight call CGSCopyManagedDisplaySpaces.
  switchToSpace=private-only — ... Direct activation is private (CGSSetActiveSpace) and, in yabai, requires System Integrity Protection to be disabled.
  mapAppsToSpaces=private-only — ... Attribution to a named Space is private (CGSCopyWindowsWithOptionsAndTags / CGSCopySpacesForWindows).
  perDisplaySpaces=private-only — ... Which Space is on which display comes from the private CGSCopyManagedDisplaySpaces ledger.
  observeActiveSpaceChange=public-no-identity — NSWorkspace.activeSpaceDidChangeNotification is public ... but carries no Space identity, index, or name.
  listDisplays=public — NSScreen.screens exposes each display's frame, visibleFrame, backing scale, and stable CGDirectDisplayID.
  mapAppsToDisplays=public — ... maps an app to the display it currently occupies — a display, not a Space.
  publicly-achievable=observeActiveSpaceChange,listDisplays,mapAppsToDisplays
  not-publicly-achievable=listSpaces,switchToSpace,mapAppsToSpaces,perDisplaySpaces
# observation: displays (public NSScreen)
displays=1 multiDisplay=false
  [1] "Built-in Retina Display" main=true scale=2.0 frame=(0.0, 0.0, 1710.0, 1107.0) visible=(60.0, 0.0, 1650.0, 1074.0) windows=9 apps=[Claude,RepoOS Hub,RepoOS · repoos,System Settings,Finder,Ghostty,Safari,Zed]
# observation: Spaces (public APIs)
spaces=unavailable (No supported API returns the set of Spaces or their identities. ...)
onScreenWindows(layer0)=12 mappedToDisplay=9 unmapped=3 apps=[Claude,RepoOS Hub,RepoOS · repoos,System Settings,Finder,Google Chrome,Ghostty,Safari,Zed]
note=on-screen windows are the active Space only; no public Space id is attached to any window
```

The per-window table (`--windows`) shows what the app-to-display mapping sees and
where it stops:

```text
onScreenWindows(layer0)=12 mappedToDisplay=9 unmapped=3
  window[27653] pid=29802 app="RepoOS · repoos" bounds=(60.0, 0.0, 1603.0, 1074.0) display=1
  window[37570] pid=23415 app="Claude" bounds=(267.0, 116.0, 1443.0, 854.0) display=1
  window[38401] pid=28098 app="System Settings" bounds=(846.0, 257.0, 723.0, 625.0) display=1
  window[18414] pid=3909 app="Google Chrome" bounds=(1709.0, -1033.0, 1536.0, 1074.0) display=none
  window[31503] pid=3909 app="Google Chrome" bounds=(1709.0, -1033.0, 1536.0, 1074.0) display=none
  window[33613] pid=73365 app="Safari" bounds=(1709.0, -1018.0, 1541.0, 1070.0) display=none
  ...
```

Readings that matter:

1. **No public API listed a Space.** The probe's `listSpaces` path returns
   `unavailable` with a reason; it never printed a Space id, name, index, or
   count. There was nothing to fabricate, so nothing was.
2. **Public `NSScreen` reads displays cleanly.** One display, `frame`
   `1710 × 1107`, `visibleFrame` inset by the menu-bar/housing band, scale `2.0`,
   and a stable `CGDirectDisplayID` — all from documented API. This is the one
   axis that is genuinely achievable.
3. **App-to-display mapping worked and is honest about its limits.** On-screen
   windows carry owner PID and bounds; after flipping Core Graphics' top-left
   origin the probe mapped 9 of 12 windows to the single display by window
   center. The 3 unmapped windows sat at `x = 1709` (the right edge of a
   1710-point display) with large negative y — parked off-screen yet still
   returned as on-screen. Two of them belong to an app that already has a mapped
   window, so the deduplicated app set only gains Google Chrome. The point is
   not the count: it is that public APIs cannot say **which Space** any of these
   windows is on, and cannot even guarantee that an "on-screen" window is
   spatially on a display.
4. **The public change notification is a trigger with no payload.**
   `NSWorkspace.activeSpaceDidChangeNotification` is real and fires on a Spaces
   change, but carries no Space identity — so it can only schedule a re-read,
   and there is no supported Space state to re-read. It is not a workspace
   adapter.

## Public API inventory

| API | Shape | What it can do | Limitation found |
| --- | --- | --- | --- |
| `NSScreen.screens`, `.frame`, `.visibleFrame`, `.backingScaleFactor` | read | Enumerate displays, geometry, scale. | Displays only; reports no Space. |
| `NSScreen.deviceDescription["NSScreenNumber"]` | read | Stable `CGDirectDisplayID` per display. | No Space association. |
| `NSWorkspace.activeSpaceDidChangeNotification` | event | Fires when the active Space changes. | Carries no Space identity/index/name; only a re-read trigger with nothing to read. |
| `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` | read | Owner PID, owner name, bounds, layer, window number for windows public APIs can see. | Returns the active Space's windows *plus* some parked off-display windows; **no Space id** is attached. |
| `kCGWindowWorkspace` | read (deprecated) | Historically reported a window's workspace id. | **Deprecated since macOS 10.11** and not populated; not usable. |
| `NSRunningApplication` (by PID) | read | Owner bundle id and localized name for a window's app. | Identity only; no window→Space or app→Space mapping. |
| `CGEvent` keyboard synthesis | write (gated) | Could synthesize the Mission Control "switch Space" shortcut. | Indirect, requires Accessibility/Input Monitoring trust, depends on the user's shortcut configuration, and cannot target a specific Space. Not a supported switch. |
| `CGSCopyManagedDisplaySpaces`, `CGSGetWindowWorkspace`, `CGSCopyWindowsWithOptionsAndTags`, `CGSCopySpacesForWindows`, `CGSSetActiveSpace` | private (SkyLight) | Full Space enumeration, attribution, and switching. | Private/undocumented **CoreGraphics Services (SkyLight)** symbols. Out of scope; yabai additionally requires SIP to be disabled to use this surface. |

## Findings

**Achievable with public APIs (modeled and tested in this branch):**

- Display enumeration and identity (`NativeSpaceDisplay`, stable
  `CGDirectDisplayID`).
- App-to-display mapping by joining on-screen window bounds to `NSScreen`
  frames, with per-display deduplication by bundle identity (`NativeSpaceObservation`).
- A public, polling-free Spaces-change trigger (`observeActiveSpaceChange`) that
  can only schedule a re-read.

**Not achievable with public APIs (the honest unavailable state):**

- Listing Spaces with an identity, name, or order.
- Switching to a specific Space.
- Attributing a window or app to a specific Space.
- Knowing which Space is on each display.

**The shared adapter model cannot be populated natively.** The story's shared
`WorkspaceAdapting` model needs workspace IDs/names, focused/occupied state,
monitor association, and app identities. Public APIs provide none of the
workspace-shaped inputs, so native Spaces cannot be implemented behind that
interface without private APIs. The research module therefore stays out of
`WorkspaceManagerKind`: `selectionPriority` remains `[.aerospace, .yabai]`, locked
by a test.

## Recommendation

1. **Ship the honest unavailable state.** When no supported manager is installed,
   Divot keeps drawing no workspace chips; it does not present native macOS
   Spaces as a workspace source. This matches the story's acceptance criterion.
2. **Keep AeroSpace and yabai as the adapters.** Do not block or delay them, and
   do not add a `nativeSpaces` manager case or private API calls to claim parity.
3. **If a "display" mode is ever wanted**, the only defensible public-API slice is
   app-to-display mapping (which app is on which monitor), explicitly labeled as
   displays, not Spaces. That is a different feature from workspace navigation and
   is not proposed here.
4. **Private APIs remain out of scope.** The full native adapter would require
   undocumented SkyLight symbols and, in the yabai case, disabling SIP. That
   contradicts the product boundary in
   [product requirements](../product-requirements.md).

## Prototype

- `macos/Sources/DivotCore/NativeSpaces.swift` — `NativeSpacesOperation`,
  `NativeSpacesSupport`, `NativeSpacesCapability`, `NativeSpacesCapabilities`
  (the primary-source capability table), and the public-API observation model
  (`NativeSpaceDisplay`, `NativeSpaceWindow`, `NativeSpaceObservation`,
  `NativeSpaceListing`). Research-only; not wired into the workspace feed.
- `macos/Sources/DivotSpacesProbe/main.swift` — read-only CLI probe. `--report`
  prints the capability table and one observation pass; `--windows` adds the
  per-window table; `--watch` logs the public Spaces/display notifications.

Run it:

```sh
swift build --package-path macos
macos/.build/debug/divot-spaces-probe            # capability report + one pass
macos/.build/debug/divot-spaces-probe --windows  # per-window display mapping
macos/.build/debug/divot-spaces-probe --watch    # event log, Ctrl-C to stop
```

## Tests

`swift test --package-path macos` (206 tests total; the 9 added here are pure and
need no window server):

- `listDisplays`, `mapAppsToDisplays`, and `observeActiveSpaceChange` are the
  only publicly achievable operations; `listSpaces`, `switchToSpace`,
  `mapAppsToSpaces`, and `perDisplaySpaces` are not.
- The capability table covers every operation exactly once.
- Native Spaces is not a selected manager: `WorkspaceManagerKind` stays
  `[.aerospace, .yabai]`.
- `spaceListing` is always `unavailable` and never an empty "no Spaces" list.
- Windows map to the display containing their center; apps deduplicate by bundle
  identity per display; a window whose center is off every display is not guessed
  at a Space.

## Not observed — a human must supply

No fabricated proof is included. The following were **not** performed in this run
and must be filled in by a person on the relevant hardware if any of it is ever
pursued:

- Switching a real Space while the probe runs, to confirm the change
  notification fires and to record its payload (expected: none).
- Two or more displays, to observe per-display window grouping and what the
  private-vs-public gap looks like there.
- A notch-free display, mixed display scales, and repeated Space switches to test
  the off-display "on-screen" window quirk further.
- Any private-API behavior. None was called, and none should be, absent an
  explicit product decision that reverses the boundary above.
