#!/usr/bin/env bash
#
# Build the local Divot.app preview from THIS checkout and run it as the real
# bundle, for the RepoOS Dev page's "Divot bar (packaged)" target (#0094).
#
# Why this exists:
#   * The dev binary (`swift run --package-path macos divot`) has no Info.plist
#     and no bundle identity. It cannot ask for or hold Location permission, and
#     its Accessibility grant attaches to the host terminal. The packaged app is
#     the version that behaves like the product.
#   * It launches the bundle with `open`, so LaunchServices makes Divot its own
#     responsible process. A directly exec'd child of the RepoOS server would
#     attach Accessibility/Location grants to the wrong host.
#   * It stops only this checkout's own bar, matched by its exact executable
#     path and stopped by PID. It never uses pkill/killall or a name pattern.
#
# The packaged target and the dev-binary target must not run together — two bars
# stack on screen — so this stops both a running dist/Divot.app and a running
# dev binary of THIS checkout before it launches.
#
# Usage: scripts/run-packaged.sh [options]
#   --configuration <debug|release>  Swift build configuration (default release)
#   --dry-run                        print what it would do, change nothing
#   --stop-only                      stop this checkout's running bars and exit
#   --print-pids <path>              print PIDs whose executable is exactly <path>
#   -h, --help                       print this help
#
# On SIGTERM (RepoOS stopping the target) it quits the app PID: a graceful TERM,
# then KILL after DIVOT_STOP_TIMEOUT seconds (default 5).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIGURATION="release"
DRY_RUN=0
STOP_ONLY=0
PRINT_PIDS=""
STOP_TIMEOUT="${DIVOT_STOP_TIMEOUT:-5}"
WAIT_TIMEOUT="${DIVOT_APP_WAIT_TIMEOUT:-30}"

# The exact executable paths of THIS checkout. Discovery matches argv[0] against
# one of these strings, so it can never hit another checkout or a lookalike name.
APP_DIR="$ROOT/dist/Divot.app"
APP_EXEC="$APP_DIR/Contents/MacOS/divot"
DEV_BIN_DEBUG="$ROOT/macos/.build/debug/divot"
DEV_BIN_RELEASE="$ROOT/macos/.build/release/divot"

usage() {
  cat <<'USAGE'
Build the local Divot.app preview from this checkout and run it as the real
bundle (the RepoOS Dev page's "Divot bar (packaged)" target).

Usage: scripts/run-packaged.sh [options]
  --configuration <debug|release>  Swift build configuration (default release)
  --dry-run                        print what it would do, change nothing
  --stop-only                      stop this checkout's running bars and exit
  --print-pids <path>              print PIDs whose executable is exactly <path>
  -h, --help                       print this help

It stops only this checkout's own Divot processes, matched by exact executable
path and stopped by PID. It never uses a name- or pattern-based kill.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --configuration) CONFIGURATION="${2:?--configuration needs a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --stop-only) STOP_ONLY=1; shift ;;
    --print-pids) PRINT_PIDS="${2:?--print-pids needs a path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "run-packaged: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$CONFIGURATION" in
  debug|release) ;;
  *) echo "run-packaged: --configuration must be debug or release (got $CONFIGURATION)" >&2; exit 2 ;;
esac

# PIDs whose argv[0] is EXACTLY the given executable path. Exact-path matching,
# never a pattern: a process named `divot` or a bar from another checkout does
# not match. `ps -o command` prints argv[0] first, so the first token is the
# executable the process was launched from.
pids_for_path() {
  local target="$1"
  [ -n "$target" ] || return 0
  ps -Ao pid=,command= | while read -r pid rest; do
    [ -n "${pid:-}" ] || continue
    if [ "${rest%% *}" = "$target" ]; then
      printf '%s\n' "$pid"
    fi
  done
}

# Send TERM to one PID, wait up to STOP_TIMEOUT for it to exit, then KILL.
stop_pid() {
  local pid="$1"
  kill -TERM "$pid" 2>/dev/null || return 0
  local deadline=$(( $(date +%s) + STOP_TIMEOUT ))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "run-packaged: pid $pid did not exit after ${STOP_TIMEOUT}s; sending KILL"
      kill -KILL "$pid" 2>/dev/null || true
      return 0
    fi
    sleep 0.2
  done
}

# Stop every running instance whose executable is exactly $1, with a clear line.
stop_path() {
  local path="$1" label="$2"
  local pids pid
  pids="$(pids_for_path "$path")"
  [ -n "$pids" ] || return 0
  for pid in $pids; do
    echo "run-packaged: stopping $label (pid $pid)"
    stop_pid "$pid"
  done
}

# Diagnostic/test mode: print the PIDs that would be matched, then exit.
if [ -n "$PRINT_PIDS" ]; then
  pids_for_path "$PRINT_PIDS"
  exit 0
fi

print_plan() {
  local packaged dev_pids
  packaged="$(pids_for_path "$APP_EXEC")"
  dev_pids="$(pids_for_path "$DEV_BIN_DEBUG"; pids_for_path "$DEV_BIN_RELEASE")"
  echo "run-packaged: dry run (nothing is changed)"
  echo "  checkout:        $ROOT"
  echo "  configuration:   $CONFIGURATION"
  echo "  build:           scripts/package-app.sh --configuration $CONFIGURATION --no-archive"
  echo "  app:             $APP_DIR"
  echo "  packaged pids:   ${packaged:-none}"
  echo "  dev-binary pids: ${dev_pids:-none}"
  echo "  launch:          open $APP_DIR"
  echo "  then:            wait for the app pid and print 'run-packaged: running commit <commit> pid <pid>'"
  echo "  on SIGTERM:      quit the app pid (TERM, then KILL after ${STOP_TIMEOUT}s) and exit"
}

if [ "$DRY_RUN" -eq 1 ]; then
  print_plan
  exit 0
fi

if [ "$STOP_ONLY" -eq 1 ]; then
  stop_path "$APP_EXEC" "Divot bar (packaged)"
  stop_path "$DEV_BIN_DEBUG" "Divot bar (dev binary)"
  stop_path "$DEV_BIN_RELEASE" "Divot bar (dev binary)"
  exit 0
fi

# The app PID, filled in once `open` has launched the bundle.
app_pid=""

# Quit the app on SIGTERM/SIGINT from RepoOS. TERM is the graceful path; KILL is
# the fallback after STOP_TIMEOUT. Installed before the build so a Stop during a
# slow build is handled too.
on_term() {
  trap - TERM INT
  if [ -n "$app_pid" ]; then
    echo "run-packaged: stopping Divot (pid $app_pid)"
    stop_pid "$app_pid"
  fi
  exit 0
}
trap on_term TERM INT

# Never run two bars at once: stop this checkout's packaged app and dev binary.
stop_path "$APP_EXEC" "Divot bar (packaged)"
stop_path "$DEV_BIN_DEBUG" "Divot bar (dev binary)"
stop_path "$DEV_BIN_RELEASE" "Divot bar (dev binary)"

echo "run-packaged: building Divot.app from $ROOT ($CONFIGURATION)"
if ! "$SCRIPT_DIR/package-app.sh" --configuration "$CONFIGURATION" --no-archive; then
  echo "run-packaged: build failed; not launching" >&2
  exit 1
fi

if [ ! -x "$APP_EXEC" ]; then
  echo "run-packaged: no executable at $APP_EXEC after the build" >&2
  exit 1
fi

# The commit package-app.sh recorded in the bundle, so the Dev page shows what
# was actually built rather than a fresh HEAD that may have moved.
COMMIT="$(sed -n 's/^commit: //p' "$APP_DIR/Contents/Resources/DivotBuildInfo.txt" 2>/dev/null | head -1)"
SHORT_COMMIT="${COMMIT:0:12}"

echo "run-packaged: launching $APP_DIR"
if ! open "$APP_DIR"; then
  echo "run-packaged: 'open' failed for $APP_DIR" >&2
  exit 1
fi

deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
while [ -z "$app_pid" ]; do
  app_pid="$(pids_for_path "$APP_EXEC" | head -1 || true)"
  if [ -n "$app_pid" ]; then
    break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "run-packaged: the app did not appear within ${WAIT_TIMEOUT}s" >&2
    exit 1
  fi
  sleep 0.3
done

echo "run-packaged: running commit ${SHORT_COMMIT:-unknown} pid $app_pid"

# Stay alive while the app runs so RepoOS sees the target as running. `wait` is
# interruptible by the TERM trap, so Stop quits the app promptly.
while kill -0 "$app_pid" 2>/dev/null; do
  sleep 1 &
  wait $! 2>/dev/null || true
done

echo "run-packaged: Divot exited"
exit 0
