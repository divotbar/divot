#!/bin/bash
# Run the macos Swift test suite under a shared, machine-wide lock.
#
# Only one `swift test` for this repository runs at a time across every git
# worktree on the machine, so parallel agent runs queue instead of piling up test
# processes (three concurrent runs used to flash Divot bars and popovers over the
# maintainer's desktop and spike the load; #0091).
#
# The lock is a directory under the *common* repository's macos/.build, so a
# worktree and the main checkout share it (git rev-parse --git-common-dir finds
# the common .git from either). It is released on exit, breaks a lock left by a
# dead process, and times out instead of blocking forever.
#
# Usage: scripts/swift-test-lock.sh [extra `swift test` arguments...]
#   DIVOT_SWIFT_TEST_LOCK_WAIT   seconds to wait for the lock (default 1800)
set -euo pipefail

readonly EX_TEMPFAIL=75

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A worktree's own macos/.build is private to that worktree, which would let two
# worktrees run at once. Resolve the common repository instead so every checkout
# of this repo on the machine shares one lock under macos/.build.
common_dir="$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$common_dir" ]; then
    case "$common_dir" in
        /*) ;;
        *) common_dir="$REPO_ROOT/$common_dir" ;;
    esac
    LOCK_ROOT="$(cd "$(dirname "$common_dir")" && pwd)"
else
    LOCK_ROOT="$REPO_ROOT"
fi
LOCK_DIR="$LOCK_ROOT/macos/.build/swift-test.lock"

LOCK_WAIT_SECONDS="${DIVOT_SWIFT_TEST_LOCK_WAIT:-1800}"

mkdir -p "$(dirname "$LOCK_DIR")"

acquired=0
waited=0
while [ "$acquired" -eq 0 ]; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        acquired=1
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        break
    fi
    # Break a lock whose owner is gone (a run killed mid-test), so a dead lock
    # never wedges the machine.
    if [ -f "$LOCK_DIR/pid" ]; then
        owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
        if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
            echo "swift-test-lock: removing lock left by dead process $owner" >&2
            rm -rf "$LOCK_DIR"
            continue
        fi
    fi
    if [ "$waited" -ge "$LOCK_WAIT_SECONDS" ]; then
        owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo unknown)"
        echo "swift-test-lock: timed out after ${LOCK_WAIT_SECONDS}s waiting for $LOCK_DIR (owner $owner); refusing to block forever" >&2
        exit "$EX_TEMPFAIL"
    fi
    if [ "$waited" -eq 0 ]; then
        echo "swift-test-lock: another swift test is running; waiting up to ${LOCK_WAIT_SECONDS}s" >&2
    fi
    sleep 1
    waited=$((waited + 1))
done

cleanup() { rm -rf "$LOCK_DIR"; }
trap cleanup EXIT INT TERM

if [ "$waited" -gt 0 ]; then
    echo "swift-test-lock: lock acquired after ${waited}s" >&2
fi

swift test --package-path "$REPO_ROOT/macos" "$@"
