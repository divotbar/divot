#!/usr/bin/env bash
#
# Create an unsigned Divot.dmg from Divot.app with drag-to-Applications layout.
#
# This script creates a distributable disk image containing the unsigned Divot app.
# The DMG includes a symlink to /Applications to encourage drag-and-drop installation.
# It is NOT Developer ID signed, NOT notarized, and requires right-click Open.
#
# The app inside must be ad-hoc signed already (run scripts/package-app.sh first).
#
# Usage: scripts/make-dmg.sh [options]
#   --app <path>          path to Divot.app (default dist/Divot.app)
#   --output <dir>        output directory (default <root>/dist)
#   --volume-name <name>  DMG volume name (default "Divot")
#   -h, --help            print this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="$ROOT/dist/Divot.app"
OUTPUT_DIR="$ROOT/dist"
VOLUME_NAME="Divot"

usage() {
  cat <<'USAGE'
Create an unsigned Divot.dmg from Divot.app with drag-to-Applications layout.

This script creates a distributable disk image containing the unsigned Divot app.
The DMG includes a symlink to /Applications for easy installation.

Usage: scripts/make-dmg.sh [options]
  --app <path>          path to Divot.app (default dist/Divot.app)
  --output <dir>        output directory (default <root>/dist)
  --volume-name <name>  DMG volume name (default "Divot")
  -h, --help            print this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP_PATH="${2:?}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?}"; shift 2 ;;
    --volume-name) VOLUME_NAME="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "make-dmg: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Ensure paths are absolute
case "$APP_PATH" in
  /*) ;;
  *) APP_PATH="$ROOT/$APP_PATH" ;;
esac
case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$ROOT/$OUTPUT_DIR" ;;
esac

if [ ! -d "$APP_PATH" ]; then
  echo "make-dmg: app bundle not found at $APP_PATH (run scripts/package-app.sh first)" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

DMG_PATH="$OUTPUT_DIR/Divot.dmg"
rm -f "$DMG_PATH"

# Create a temporary directory for DMG contents.
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/divot-dmg.XXXXXX")"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# Create the source directory structure:
# - Divot.app
# - Applications -> /Applications (symlink for drag-to-install)
SOURCE_DIR="$TEMP_DIR/source"
mkdir -p "$SOURCE_DIR"

# Copy the app into the source directory.
cp -a "$APP_PATH" "$SOURCE_DIR/Divot.app"

# Create a symlink to /Applications for drag-and-drop installation.
ln -s /Applications "$SOURCE_DIR/Applications"

# Create the DMG from the source directory using hdiutil.
# We create a temporary read-write DMG, configure it, then convert to compressed.
TEMP_DMG="$TEMP_DIR/Divot-temp.dmg"

# Create a read-write DMG large enough to hold the app plus padding for filesystem overhead.
# App size plus 10 MB padding should be sufficient.
APP_SIZE=$(du -sk "$SOURCE_DIR" | awk '{print $1}')
DMG_SIZE=$((APP_SIZE + 10240))

hdiutil create -volname "$VOLUME_NAME" \
  -srcfolder "$SOURCE_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH" > /dev/null 2>&1

if [ ! -f "$DMG_PATH" ]; then
  echo "make-dmg: failed to create DMG at $DMG_PATH" >&2
  exit 1
fi

echo "make-dmg: dmg       $DMG_PATH"
echo "make-dmg: volume    $VOLUME_NAME"
echo "make-dmg: note      unsigned; requires right-click Open"
