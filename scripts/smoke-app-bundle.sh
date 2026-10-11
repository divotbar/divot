#!/usr/bin/env bash
#
# Package and smoke-test the local Divot.app preview.
#
# This is the automated launch gate: it assembles the bundle, checks its
# structure and Info.plist, verifies the ad-hoc signature and the archive
# checksum, and then actually runs the bundled Mach-O (`--help`, `--report`,
# `--widgets`). It never opens a window, changes a security setting, or claims a
# person looked at the bar. Anything visual stays on the hardware checklist.
#
# Usage: scripts/smoke-app-bundle.sh [package-app.sh options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DIST="${DIVOT_SMOKE_DIST:-$ROOT/dist}"

fail() { echo "smoke-app-bundle: FAIL: $*" >&2; exit 1; }
pass() { echo "smoke-app-bundle: ok  $*"; }

"$SCRIPT_DIR/package-app.sh" --output "$DIST" "$@"

APP="$DIST/Divot.app"
MANIFEST="$DIST/divot-preview-manifest.txt"

[ -d "$APP" ] || fail "missing $APP"
[ -x "$APP/Contents/MacOS/divot" ] || fail "bundle has no executable at $APP/Contents/MacOS/divot"
[ -f "$APP/Contents/Info.plist" ] || fail "bundle has no Info.plist"
[ -f "$APP/Contents/Resources/menubar-mark.pdf" ] || fail "bundle is missing the menu-bar mark asset"
[ -f "$APP/Contents/Resources/DivotBuildInfo.txt" ] || fail "bundle is missing DivotBuildInfo.txt"
pass "bundle structure"

plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null; }

[ "$(plist_value CFBundleExecutable)" = "divot" ] || fail "CFBundleExecutable is not divot"
[ "$(plist_value CFBundlePackageType)" = "APPL" ] || fail "CFBundlePackageType is not APPL"
[ "$(plist_value CFBundleIdentifier)" = "local.divot.preview" ] || fail "unexpected CFBundleIdentifier"
[ "$(plist_value LSUIElement)" = "true" ] || fail "LSUIElement is not true (accessory app)"
[ "$(plist_value LSMinimumSystemVersion)" = "26.0" ] || fail "unexpected LSMinimumSystemVersion"
COMMIT_FULL="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
[ "$(plist_value DivotBuildCommit)" = "$COMMIT_FULL" ] || fail "Info.plist commit does not match HEAD"
case "$(plist_value DivotPreviewVersion)" in
  *-preview.*) ;;
  *) fail "preview version is not labelled as a preview" ;;
esac
pass "Info.plist keys and version labelling"

codesign --verify --deep --strict "$APP" || fail "ad-hoc signature did not verify"
SIGNATURE_INFO="$(codesign -dv "$APP" 2>&1 || true)"
case "$SIGNATURE_INFO" in
  *"Signature=adhoc"*) ;;
  *) fail "bundle is not ad-hoc signed" ;;
esac
pass "ad-hoc signature verifies"

# Actually launch the bundled executable. These subcommands are headless-safe:
# `--help` prints usage, `--report` prints one observation pass, and `--widgets`
# prints the built-in providers for a short window.
HELP="$("$APP/Contents/MacOS/divot" --help)" || fail "--help exited non-zero"
case "$HELP" in
  *"usage: divot"*) ;;
  *) fail "--help did not print usage" ;;
esac
pass "bundled app launches (--help)"

REPORT="$("$APP/Contents/MacOS/divot" --report)" || fail "--report exited non-zero"
case "$REPORT" in
  *"divot shell placement report"*) ;;
  *) fail "--report did not print the placement report" ;;
esac
case "$REPORT" in
  *"menuBarMark=resolved"*) ;;
  *) fail "packaged app did not resolve its bundled menu-bar mark" ;;
esac
pass "bundled app resolves resources (--report)"

WIDGETS="$("$APP/Contents/MacOS/divot" --widgets)" || fail "--widgets exited non-zero"
case "$WIDGETS" in
  *"layout.left=workspaces,front-app"*) ;;
  *) fail "default left group is not workspaces,front-app" ;;
esac
case "$WIDGETS" in
  *"layout.right=battery,time,network,volume"*) ;;
  *) fail "default right group is not battery,time,network,volume" ;;
esac
pass "default bar layout through the packaged app"

[ -f "$MANIFEST" ] || fail "missing manifest $MANIFEST"
ARCHIVE="$(sed -n 's/^archive=//p' "$MANIFEST")"
EXPECTED="$(sed -n 's/^sha256=//p' "$MANIFEST")"
[ -n "$ARCHIVE" ] || fail "manifest has no archive"
[ -f "$ARCHIVE" ] || fail "archive listed in the manifest is missing: $ARCHIVE"
ACTUAL="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[ "$ACTUAL" = "$EXPECTED" ] || fail "archive checksum mismatch (manifest $EXPECTED, actual $ACTUAL)"
[ -f "$ARCHIVE.sha256" ] || fail "archive sidecar checksum is missing"
grep -q "$EXPECTED" "$ARCHIVE.sha256" || fail "archive sidecar checksum does not match"
pass "versioned archive and checksum"

echo "smoke-app-bundle: PASS"
