---
id: "0094"
title: "Dev page: add a 'Divot bar (packaged)' target that rebuilds and runs the real dist/Divot.app"
type: feature
status: ready
priority: p2
area: [macos, infra]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T17:21:21Z"
updated_at: "2026-10-13T19:09:23Z"
---
## Problem
The Dev page's 'Divot bar' target runs swift run --package-path macos divot, a bare dev binary with no Info.plist and no bundle identity. It cannot ask for or hold Location permission (so the Wi-Fi name and network list show nothing), its Accessibility grant attaches to the host terminal or app, and permissions are never persistent. The packaged dist/Divot.app (scripts/package-app.sh) is the version that behaves like the real product, but today the maintainer has to build and relaunch it by hand.

## Desired UX
- A second [[dev.targets]] entry named 'Divot bar (packaged)' on the Dev page with Start, Stop and Restart, shown next to the existing dev-binary target. Start rebuilds the app from the current checkout and runs the real bundle; Stop quits it; Restart does both.
- The packaged target and the dev-binary target must not run at the same time (starting one stops the other with a clear message), since two bars would stack on screen.
- Output shows the build log and then a line with the commit the app was built from and its PID.

## Acceptance criteria
- Add scripts/run-packaged.sh (or a just recipe) and a [[dev.targets]] entry (kind process, like the existing one; edit repoos.toml on the task branch only, never on main). The script: runs scripts/package-app.sh (release by default, --configuration debug optional), stops only an already-running dist/Divot.app instance by its exact PID (match the full path dist/Divot.app/Contents/MacOS/divot of THIS checkout; never pkill by name pattern), launches the bundle with 'open' so LaunchServices makes Divot its own responsible process (a directly exec'd child of the RepoOS server would attach Accessibility/Location grants to the wrong host), waits for the app PID, and on SIGTERM from RepoOS quits that PID (graceful TERM, then KILL after a timeout) and exits; it exits non-zero if the build fails, with the error visible on the Dev page.
- Document the difference between the two targets, and the permission behaviour (Location prompt appears only in the packaged app; Accessibility and Location grants persist per app but an ad-hoc re-sign on rebuild may drop them) in docs/ and in the site troubleshooting and getting-started pages.
- Tests for the script's pure parts where possible (argument handling, PID discovery function) and a dry-run mode (--dry-run prints what it would do) so repoos check can exercise it without launching UI; repoos check --changed main passes.
- Verify with the Dev page: Start builds and launches, the process shows as running, Stop quits it; record what you saw. If the Dev page cannot be driven from the agent environment say so and test the script directly with --dry-run and a real run.

## Notes for AI
Related: #0014 (package-app.sh), #0061 (Accessibility prompt), #0039 (Location). Do not kill processes by name or pattern: PIDs only. The current dev target is at repoos.toml [[dev.targets]] name = divot.

## Activity

- 2026-10-13T17:21:21Z · created · njachowski@gmail.com
- 2026-10-13T19:09:23Z · status inbox→ready
