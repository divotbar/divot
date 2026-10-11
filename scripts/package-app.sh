#!/usr/bin/env bash
#
# Package a local, ad-hoc-signed Divot.app preview for this Mac.
#
# This produces a LOCAL preview artifact. It is signed ad-hoc (codesign -s -)
# and is NOT Developer ID signed, NOT notarized, and NOT a public release.
# Public signed distribution stays task #0008.
#
# It deliberately does none of the following:
#   * no root installer and no `sudo`;
#   * no change to Gatekeeper, quarantine, or any security setting;
#   * no quarantine-stripping instructions or `xattr` calls;
#   * no guessed Developer ID identity, provisioning profile, or team ID;
#   * no public upload or deployment.
#
# Outputs, under `dist/` by default:
#   Divot.app                                     the runnable bundle
#   Divot-<version>-<commit>.zip                  versioned archive
#   Divot-<version>-<commit>.zip.sha256           checksum for that archive
#   Divot-<version>-<commit>.build.txt            build facts (commit, signing)
#   divot-preview-manifest.txt                    machine-readable manifest
#
# Usage: scripts/package-app.sh [options]
#   --configuration <debug|release>  Swift build configuration (default release)
#   --output <dir>                   output directory (default <root>/dist)
#   --version <string>               override the version (default: VERSION file)
#   --build-number <string>          CFBundleVersion (default 1)
#   --binary <path>                  reuse a prebuilt `divot` executable
#   --resource-dir <path>            directory holding menubar-mark.pdf
#   --no-build                       skip `swift build` (requires a built product)
#   --no-archive                     assemble Divot.app only, skip the zip
#   -h, --help                       print this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIGURATION="release"
OUTPUT_DIR=""
VERSION=""
BUILD_NUMBER="1"
BINARY=""
RESOURCE_DIR=""
DO_BUILD=1
DO_ARCHIVE=1

usage() {
  cat <<'USAGE'
Package a local, ad-hoc-signed Divot.app preview for this Mac.

This is a LOCAL preview artifact: ad-hoc signed, not Developer ID signed, and
not notarized. Public signed distribution stays task #0008.

Usage: scripts/package-app.sh [options]
  --configuration <debug|release>  Swift build configuration (default release)
  --output <dir>                   output directory (default <root>/dist)
  --version <string>               override the version (default: VERSION file)
  --build-number <string>          CFBundleVersion (default 1)
  --binary <path>                  reuse a prebuilt `divot` executable
  --resource-dir <path>            directory holding menubar-mark.pdf
  --no-build                       skip `swift build` (requires a built product)
  --no-archive                     assemble Divot.app only, skip the zip
  -h, --help                       print this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --configuration) CONFIGURATION="${2:?}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?}"; shift 2 ;;
    --version) VERSION="${2:?}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:?}"; shift 2 ;;
    --binary) BINARY="${2:?}"; shift 2 ;;
    --resource-dir) RESOURCE_DIR="${2:?}"; shift 2 ;;
    --no-build) DO_BUILD=0; shift ;;
    --no-archive) DO_ARCHIVE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "package-app: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$VERSION" ]; then
  if [ -f "$ROOT/VERSION" ]; then
    VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
  else
    echo "package-app: no --version and no VERSION file at $ROOT/VERSION" >&2
    exit 1
  fi
fi

# Apple's CFBundleShortVersionString must be dotted-numeric; the preview label
# lives in CFBundleVersion and a custom key instead.
SHORT_VERSION="${VERSION%%-*}"

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$ROOT/dist"
fi
case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$ROOT/$OUTPUT_DIR" ;;
esac

BUILD_CONFIG_DIR="$ROOT/macos/.build/$CONFIGURATION"
if [ -z "$BINARY" ]; then
  BINARY="$BUILD_CONFIG_DIR/divot"
fi
if [ -z "$RESOURCE_DIR" ]; then
  RESOURCE_DIR="$BUILD_CONFIG_DIR/DivotCore_DivotAppKit.bundle"
fi

if [ "$DO_BUILD" -eq 1 ]; then
  echo "package-app: swift build -c $CONFIGURATION --product divot"
  swift build --package-path "$ROOT/macos" -c "$CONFIGURATION" --product divot
fi

if [ ! -x "$BINARY" ]; then
  echo "package-app: no executable at $BINARY (build first or pass --binary)" >&2
  exit 1
fi
if [ ! -f "$RESOURCE_DIR/menubar-mark.pdf" ]; then
  echo "package-app: menu-bar mark missing at $RESOURCE_DIR/menubar-mark.pdf" >&2
  exit 1
fi

# Build facts. The commit and a dirty flag are recorded honestly; a checkout
# with uncommitted sources is labelled dirty rather than pretended clean.
COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
SHORT_COMMIT="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  DIRTY="true"
else
  DIRTY="false"
fi
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

APP_NAME="Divot"
APP_IDENTIFIER="local.divot.preview"
SIGNING_LABEL="ad-hoc (local preview; not Developer ID signed, not notarized)"

# Assembly happens in a staging directory and is only moved into place once it
# is complete and signed, so a failed run never leaves a half-written bundle.
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/divot-package.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

APP="$STAGING/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/divot"
chmod +x "$APP/Contents/MacOS/divot"

# The mark is copied to Contents/Resources so the app resolves it through
# Bundle.main, the standard location for a packaged .app.
cp "$RESOURCE_DIR/menubar-mark.pdf" "$APP/Contents/Resources/menubar-mark.pdf"

BUILD_INFO="$(cat <<EOF
Divot local preview
version: $VERSION
shortVersion: $SHORT_VERSION
buildNumber: $BUILD_NUMBER
commit: $COMMIT
shortCommit: $SHORT_COMMIT
dirty: $DIRTY
builtAt: $BUILD_DATE
configuration: $CONFIGURATION
bundleIdentifier: $APP_IDENTIFIER
signing: $SIGNING_LABEL
note: local preview only; public Developer ID signing and notarization is task #0008
EOF
)"
printf '%s\n' "$BUILD_INFO" > "$APP/Contents/Resources/DivotBuildInfo.txt"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>divot</string>
	<key>CFBundleIdentifier</key>
	<string>$APP_IDENTIFIER</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$SHORT_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key>
	<string>26.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Location permission is needed to show the Wi-Fi network name.</string>
	<key>DivotPreviewVersion</key>
	<string>$VERSION</string>
	<key>DivotBuildCommit</key>
	<string>$COMMIT</string>
	<key>DivotBuildShortCommit</key>
	<string>$SHORT_COMMIT</string>
	<key>DivotBuildDirty</key>
	<string>$DIRTY</string>
	<key>DivotBuildDate</key>
	<string>$BUILD_DATE</string>
	<key>DivotSigning</key>
	<string>$SIGNING_LABEL</string>
</dict>
</plist>
EOF

plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc signature: the identity is the anonymous "-", never a guessed name.
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

# Move the finished, signed bundle into place.
mkdir -p "$OUTPUT_DIR"
FINAL_APP="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$FINAL_APP"
ditto "$APP" "$FINAL_APP"

ARCHIVE=""
SHA256=""
if [ "$DO_ARCHIVE" -eq 1 ]; then
  STEM="$APP_NAME-$VERSION-$SHORT_COMMIT"
  ARCHIVE="$OUTPUT_DIR/$STEM.zip"
  rm -f "$ARCHIVE" "$ARCHIVE.sha256" "$OUTPUT_DIR/$STEM.build.txt"
  # ditto preserves the signature, extended attributes, and resource forks.
  ditto -c -k --sequesterRsrc --keepParent "$FINAL_APP" "$ARCHIVE"
  ( cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256" )
  SHA256="$(awk '{print $1}' "$ARCHIVE.sha256")"
  cp "$FINAL_APP/Contents/Resources/DivotBuildInfo.txt" "$OUTPUT_DIR/$STEM.build.txt"
fi

MANIFEST="$OUTPUT_DIR/divot-preview-manifest.txt"
{
  echo "version=$VERSION"
  echo "short_version=$SHORT_VERSION"
  echo "commit=$COMMIT"
  echo "short_commit=$SHORT_COMMIT"
  echo "dirty=$DIRTY"
  echo "built_at=$BUILD_DATE"
  echo "configuration=$CONFIGURATION"
  echo "bundle_identifier=$APP_IDENTIFIER"
  echo "signing=$SIGNING_LABEL"
  echo "app=$FINAL_APP"
  echo "archive=$ARCHIVE"
  echo "sha256=$SHA256"
} > "$MANIFEST"

echo "package-app: app       $FINAL_APP"
if [ -n "$ARCHIVE" ]; then
  echo "package-app: archive   $ARCHIVE"
  echo "package-app: sha256    $SHA256"
fi
echo "package-app: manifest  $MANIFEST"
echo "package-app: note      $SIGNING_LABEL"
