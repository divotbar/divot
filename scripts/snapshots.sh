#!/bin/bash
# Render popover and bar snapshots and print the output directory.
#
# Usage: scripts/snapshots.sh [--only token[,token,...]]
#
# This script runs the test suite (PopoverSnapshotTests and BarSnapshotTests) and captures PNG renders
# of popovers and the right-hand bar in all supported themes and light/dark variants. Snapshots
# are written to a gitignored directory for manual review.
#
# Options:
#   --only <tokens>   Filter snapshots by comma-separated tokens (e.g., --only worldclock or --only wifi,volume).
#                     Only snapshots whose names contain one of the tokens are rendered. Unknown tokens
#                     produce a visible note and no snapshots.
#
# On macOS with a display, snapshots are rendered using offscreen AppKit
# bitmap caching. On headless systems (CI), tests skip gracefully with a
# clear message and the suite still passes.
#
# Note: DIVOT_SNAPSHOT_DIR should point to a gitignored directory.
# By default it uses macos/.build/snapshots/ which is covered by the
# existing macos/.build/ ignore rule.

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_DIR="${DIVOT_SNAPSHOT_DIR:-$REPO_ROOT/macos/.build/snapshots}"

export DIVOT_SNAPSHOT_DIR="$SNAPSHOT_DIR"

# Parse --only flag
DIVOT_SNAPSHOT_ONLY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --only)
            DIVOT_SNAPSHOT_ONLY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -n "$DIVOT_SNAPSHOT_ONLY" ]; then
    export DIVOT_SNAPSHOT_ONLY="$DIVOT_SNAPSHOT_ONLY"
    echo "Running popover snapshot tests with filter: $DIVOT_SNAPSHOT_ONLY"
else
    echo "Running popover snapshot tests..."
fi
echo "Snapshots will be written to: $SNAPSHOT_DIR"
echo ""

cd "$REPO_ROOT"
# Run the suite under the machine-wide swift-test lock (#0091) so parallel agent
# runs queue; the grep shows the snapshot suites and the pass/fail summary.
"$REPO_ROOT/scripts/swift-test-lock.sh" 2>&1 | grep -E 'Popover snapshots|Bar snapshots|Test.*popover.*renders|passed|failed'

# Capture the exit code from swift test (not grep)
exit_code=${PIPESTATUS[0]}
if [ $exit_code -ne 0 ]; then
    echo "Test suite failed with exit code $exit_code"
    exit $exit_code
fi

echo ""
echo "Snapshots directory: $SNAPSHOT_DIR"
if [ -d "$SNAPSHOT_DIR" ] && [ -n "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
    echo "Snapshot files:"
    ls -lh "$SNAPSHOT_DIR"/*.png 2>/dev/null || echo "  (no PNG files generated)"
else
    echo "  (no snapshots generated — likely a headless environment)"
fi
