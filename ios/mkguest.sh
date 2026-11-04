#!/bin/bash
# Offline-translate the selected Android ARM64 guest libraries into iOS-stamped
# Mach-O frameworks. This is the iOS counterpart of visionos/mkguest.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${KLEPTON_TARGET:-}"
if [[ -z "$TARGET" ]]; then
  echo "usage: KLEPTON_TARGET=<target> ios/mkguest.sh" >&2
  echo "targets: $(cd "$ROOT" && python3 visionos/targets.py --list | tr '\n' ' ')" >&2
  exit 2
fi

eval "$(cd "$ROOT" && python3 visionos/targets.py "$TARGET")"
SRC="$ROOT/$KLT_SRCDIR"
OUT="$ROOT/ios/Frameworks/$KLT_NAME"
LD="$ROOT/build/klepton-ld"

[[ -x "$LD" ]] || { echo "missing $LD; run 'make build/klepton-ld' on Apple Silicon macOS" >&2; exit 1; }
[[ -d "$SRC" ]] || { echo "missing guest library directory: $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

for NAME in $KLT_LIBS; do
  INPUT="$SRC/$NAME.so"
  [[ -f "$INPUT" ]] || { echo "missing guest library: $INPUT" >&2; exit 1; }
  ID_NAME="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9.-' '-')"
  FWNAME="$(printf '%s' "$NAME" | tr '+' 'x')"
  FW="$OUT/$FWNAME.framework"
  mkdir -p "$FW"
  "$LD" "$INPUT" -o "$FW/$FWNAME" --platform ios \
    --install-name "@rpath/$FWNAME.framework/$FWNAME" --quiet
  cat > "$FW/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$FWNAME</string>
  <key>CFBundleIdentifier</key><string>dev.iquest.guest.$ID_NAME</string>
  <key>CFBundleName</key><string>$FWNAME</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>17.0</string>
</dict></plist>
PLIST
  printf '  %-24s translated for iOS\n' "$NAME"
done

echo "[iQuest] guest frameworks staged at $OUT"
echo "NOTE: embedding/signing these frameworks into the app is a separate Xcode project-generation step; this script does not install or run the guest."
