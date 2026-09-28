#!/bin/bash
# e2_img.sh — AppImage packaging with a pinned appimagetool release (native aarch64).
set -eo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"
ARCH="${ARCH:-$(uname -m)}"
case "$ARCH" in
  aarch64|arm64) ARCH=aarch64 ;;
  *) echo "This packaging script targets aarch64 (got $ARCH)." >&2; exit 1 ;;
esac
TOOL="${APPIMAGETOOL:-$BASE/.deps/tools/appimagetool-1.9.1-${ARCH}.AppImage}"
if [ ! -x "$TOOL" ]; then
  echo "== 下载 appimagetool 1.9.1 ($ARCH) =="
  mkdir -p "$(dirname "$TOOL")"
  curl -fL --retry 3 -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-${ARCH}.AppImage"
  chmod +x "$TOOL"
fi
bash scripts/e1_appdir.sh
cp AppDir/usr/share/applications/wetype-ime.desktop AppDir/
OUT="WeTypeIME-Engine-${ARCH}.AppImage"
rm -f WeTypeIME-Engine-*.AppImage
TOOL_ARGS=(--comp zstd)
if [ -n "${APPIMAGE_RUNTIME:-}" ]; then
  TOOL_ARGS+=(--runtime-file "$APPIMAGE_RUNTIME")
fi
ARCH="$ARCH" "$TOOL" "${TOOL_ARGS[@]}" AppDir "$OUT" 2>&1 | tail -3
ls -la "$OUT" | awk '{print $5, $9}'
