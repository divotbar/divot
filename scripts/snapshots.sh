#!/bin/bash
# Render popover snapshots and print the output directory.
#
# This script runs the PopoverSnapshotTests suite and captures PNG renders
# of popovers in all supported themes and light/dark variants. Snapshots
# are written to a gitignored directory for manual review.
#
# On macOS with a display, snapshots are rendered using offscreen AppKit
# bitmap caching. On headless systems (CI), the test records a clear message
# and continues without error.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_DIR="${DIVOT_SNAPSHOT_DIR:-$REPO_ROOT/macos/.build/snapshots}"

export DIVOT_SNAPSHOT_DIR="$SNAPSHOT_DIR"

echo "Running popover snapshot tests..."
echo "Snapshots will be written to: $SNAPSHOT_DIR"
echo ""

cd "$REPO_ROOT"
swift test --package-path macos --filter PopoverSnapshot 2>&1 | grep -E "Test|passed|failed|Suite"

echo ""
echo "Snapshots directory: $SNAPSHOT_DIR"
if [ -d "$SNAPSHOT_DIR" ] && [ -n "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
    echo "Snapshot files:"
    ls -lh "$SNAPSHOT_DIR"/*.png 2>/dev/null || echo "  (no PNG files generated)"
else
    echo "  (no snapshots generated — likely a headless environment)"
fi
