#!/usr/bin/env bash
#
# Run the bare dev Divot binary for the RepoOS Dev page's "Divot bar" target
# (#0094).
#
# The dev binary (`swift run --package-path macos divot`) has no Info.plist and
# no bundle identity, so it cannot ask for or hold Location permission and its
# Accessibility grant attaches to the host terminal. Use the "Divot bar
# (packaged)" target when you need the permission-accurate behaviour.
#
# The two targets must not run together — two bars stack on screen — so this
# stops a running packaged dist/Divot.app of THIS checkout (by exact PID, never
# by name pattern) before it execs the dev binary.
#
# Usage: scripts/run-dev.sh [--dry-run] [--help]
#   --dry-run  print what it would do, change nothing
#   -h, --help print this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'USAGE'
Run the bare dev Divot binary (the RepoOS Dev page's "Divot bar" target).

Usage: scripts/run-dev.sh [--dry-run] [--help]
  --dry-run  print what it would do, change nothing
  -h, --help print this help

It first stops this checkout's packaged dist/Divot.app so two bars never stack.
USAGE
      exit 0 ;;
    *) echo "run-dev: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo "run-dev: dry run (nothing is changed)"
  echo "  stop: scripts/run-packaged.sh --stop-only  (stops this checkout's packaged Divot.app)"
  echo "  run:  swift run --package-path macos divot"
  exit 0
fi

# Stop the packaged bar first so two bars never stack on screen.
"$SCRIPT_DIR/run-packaged.sh" --stop-only

exec swift run --package-path macos divot
