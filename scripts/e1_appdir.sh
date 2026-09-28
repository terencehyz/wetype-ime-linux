#!/bin/bash
# e1_appdir.sh — 组装 WeType 输入法 AppDir（对齐 doubao-ime-linux b1 布局）
# AppDir 只含本项目自己的代码（Paper 式）：不含任何 APK 里的库或词库。
# 本机构建为原生 aarch64，app 内直接运行 ARM64 harness，不需要 QEMU/sysroot。
# 结构:
#   AppDir/usr/lib/wetype-ime/arm64/{lib/{libwetype-shim.so,libz.so.1},wetype-harness,wetype-ime-demo.sh}
#   AppDir/usr/lib/wetype-ime/scripts/  安装时下载官方 APK、校验 SHA-256 并在本机打补丁
#   AppDir/usr/bin/{wetype-ime-engine,wetype-demo}
#   AppDir/usr/lib/fcitx5/libfcitx5-wetype.so
#   用户可写数据: $XDG_DATA_HOME/wetype-ime/dict  (运行时由 harness 通过 WETYPE_WORK_DIR 使用)
set -e
BASE="$(cd "$(dirname "$0")/.." && pwd)"     # wetype-ime-linux 根
APPDIR="$BASE/AppDir"
ENG="$APPDIR/usr/lib/wetype-ime/arm64"
PATCH_SCRIPTS="prepare_assets.sh 10_patch_libs.sh versym_surgery.py 12_rename_syms.py
  promote_shim.py 17_disable_scan_sig.py 21_fake_appender.py"

# Build the project's own ARM64 shim and harness (no APK input needed).
bash "$BASE/scripts/20_build.sh"

# Package the host Fcitx5 addon along with the ARM64 engine.
"$BASE/fcitx5-wetype/build.sh"
ADDON_SO="$BASE/fcitx5-wetype/build/libfcitx5-wetype.so"
[ -f "$ADDON_SO" ] || { echo "Missing Fcitx5 addon: $ADDON_SO" >&2; exit 1; }

rm -rf "$APPDIR"
mkdir -p "$ENG/lib" "$APPDIR/usr/lib/wetype-ime/scripts" "$APPDIR/usr/bin" \
         "$APPDIR/usr/lib/fcitx5" "$APPDIR/usr/share/fcitx5/addon" \
         "$APPDIR/usr/share/fcitx5/inputmethod" "$APPDIR/usr/lib/wetype-ime" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# 1. 自有 ARM64 组件 + demo；WeType 引擎库与词库由 install 在用户机器上生成
cp "$BASE/runtime/libwetype-shim.so" "$BASE/runtime/libz.so.1" "$ENG/lib/"
cp "$BASE/harness/jinterop" "$ENG/wetype-harness"
cp "$BASE/src/wetype-ime-demo.sh" "$ENG/"
chmod +x "$ENG/wetype-ime-demo.sh"

# 第三方运行时：仅 zlib（原生 aarch64 直接运行，不需要 QEMU/独立 glibc sysroot）
pkg_version() { dpkg-query -W -f '${Version}' "$1" 2>/dev/null || echo unknown; }
mkdir -p "$APPDIR/usr/share/doc/wetype-ime"
cat > "$APPDIR/usr/share/doc/wetype-ime/THIRD-PARTY.md" <<NOTICE
# Third-party components bundled in this AppImage

| Component | Files | License | Version (distribution package) |
|---|---|---|---|
| zlib (aarch64) | usr/lib/wetype-ime/arm64/lib/libz.so.1 | Zlib | zlib1g $(pkg_version zlib1g) |

This binary is an unmodified copy from the build host's distribution package.
Corresponding source code is available from the distribution's source archive
(for Debian/Ubuntu: \`apt-get source zlib\`) and from https://zlib.net.

This build targets a native aarch64 host and runs the engine directly; it does not
bundle QEMU or a separate ARM64 glibc sysroot.

WeType (微信输入法) itself is NOT included: its libraries and dictionaries are downloaded
from Tencent's server and patched on the user's machine at install time.
NOTICE

# 2. 安装时运行的下载/校验/补丁脚本
for f in $PATCH_SCRIPTS; do
  cp "$BASE/scripts/$f" "$APPDIR/usr/lib/wetype-ime/scripts/"
done
chmod +x "$APPDIR"/usr/lib/wetype-ime/scripts/*.sh

# 3. 引擎启动器（行协议 REPL，fcitx5 addon 也 exec 它）
cat > "$APPDIR/usr/bin/wetype-ime-engine" <<EOF
#!/bin/bash
ENG="\$(dirname "\$(readlink -f "\$0")")/../lib/wetype-ime/arm64"
ulimit -c 0
USRDATA="\${XDG_DATA_HOME:-\$HOME/.local/share}/wetype-ime"
mkdir -p "\$USRDATA/dict/userdict/v5" "\$USRDATA/dict/userdict/user_hot_word"
exec env LD_LIBRARY_PATH="\$ENG/lib" \\
         WETYPE_LIB_DIR="\$ENG/lib" \\
         WETYPE_DICT_DIR="\$ENG/dicts" \\
         WETYPE_ASSET_DIR="\$ENG/dicts" \\
         WETYPE_WORK_DIR="\$USRDATA/dict" \\
    "\$ENG/wetype-harness" "\$ENG/lib/libwxhld_jni.so" --daemon
EOF
chmod +x "$APPDIR/usr/bin/wetype-ime-engine"

# 4. CLI 演示启动器
cat > "$APPDIR/usr/bin/wetype-demo" <<EOF
#!/bin/bash
ENG="\$(dirname "\$(readlink -f "\$0")")/../lib/wetype-ime/arm64"
WETYPE_ENGINE_DIR="\$ENG" bash "\$ENG/wetype-ime-demo.sh" "\$@"
EOF
chmod +x "$APPDIR/usr/bin/wetype-demo"

# 5. Fcitx5 addon, registration files, and AppImage entry point
cp "$ADDON_SO" "$APPDIR/usr/lib/fcitx5/libfcitx5-wetype.so"
cp "$BASE/fcitx5-wetype/wetype-addon.conf" "$APPDIR/usr/share/fcitx5/addon/wetype.conf"
cp "$BASE/fcitx5-wetype/wetype-im.conf" "$APPDIR/usr/share/fcitx5/inputmethod/wetype-im.conf"
cp "$BASE/scripts/appimage_manage.sh" "$APPDIR/usr/lib/wetype-ime/appimage-manage.sh"
cp "$BASE/scripts/appimage_run.sh" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/lib/wetype-ime/appimage-manage.sh"

# 6. desktop + icon
cat > "$APPDIR/usr/share/applications/wetype-ime.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=WeType IME Engine
Comment=微信输入法引擎（候选词驱动, 原生 aarch64）
Exec=wetype-demo nihao
Icon=wetype-ime
Categories=Utility;
Terminal=true
EOF
cp "$BASE/assets/wetype-ime.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/wetype-ime.png"
cp "$BASE/assets/wetype-ime.png" "$APPDIR/wetype-ime.png"
cp "$APPDIR/usr/share/applications/wetype-ime.desktop" "$APPDIR/"

# 7. 防线：AppDir 内绝不能出现 APK 派生文件
leaked="$(find "$APPDIR" \( -name 'libwxhld*' -o -name 'libandromeda*' -o -name 'libcryptopp*' \
  -o -name 'libc++_shared*' -o -name 'libime_net*' -o -name 'libowl*' -o -name 'libprotobuf-lite*' \
  -o -name 'libtensorflowlite*' -o -name 'libwcwss*' -o -name 'libwechatxlog*' \
  -o -name 'index.json' -o -name '*.bin' -o -name '*.apk' \) -print)"
if [ -n "$leaked" ]; then
  echo "AppDir 含有 APK 派生文件，拒绝打包:" >&2
  echo "$leaked" >&2
  exit 1
fi

echo "== AppDir 就绪 =="
du -sh "$APPDIR"
