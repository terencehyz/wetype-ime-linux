#!/usr/bin/env bash
# Build the project's own aarch64 pieces (shim + harness) into runtime/ and harness/.
# Native build: the host must be aarch64 (the WeType engine is ARM64).
# Needs no APK input; scripts/10_patch_libs.sh adds the patched WeType libraries.
set -e
cd "$(dirname "$0")/.."
case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "Native aarch64 host required (uname -m = $(uname -m))." >&2; exit 1 ;;
esac
CC="${CC:-cc}"
for tool in "$CC" patchelf; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
mkdir -p runtime harness
if [ ! -f runtime/libz.so.1 ]; then
  ZLIB_SO="${WETYPE_ZLIB_SO:-}"
  for candidate in \
    /usr/lib/aarch64-linux-gnu/libz.so.1 \
    /usr/lib/libz.so.1 \
    /lib/aarch64-linux-gnu/libz.so.1; do
    if [ -z "$ZLIB_SO" ] && [ -f "$candidate" ]; then ZLIB_SO="$candidate"; fi
  done
  if [ -z "$ZLIB_SO" ] || [ ! -f "$ZLIB_SO" ]; then
    echo "Missing aarch64 zlib. Install zlib1g-dev or set WETYPE_ZLIB_SO." >&2
    exit 1
  fi
  cp -fL "$ZLIB_SO" runtime/libz.so.1
fi
"$CC" -shared -fPIC -O2 -o runtime/libwetype-shim.so \
  shim/wetype-shim.c shim/wetype-signal.c -ldl
# shim 自身去掉全部 DT_NEEDED：glibc _dl_sort_maps 按深度重排搜索列表时，
# 依赖 libc 的 shim 会被排到 libc 之后导致 stdio 包装失效；无依赖叶子节点则稳居第一，
# 其 UND 符号（dlsym/fprintf 等）从全局作用域解析（主程序已加载 libc）。
patchelf --remove-needed libc.so.6 runtime/libwetype-shim.so 2>/dev/null || true
patchelf --remove-needed libdl.so.2 runtime/libwetype-shim.so 2>/dev/null || true
echo "shim NEEDED 残留: $(patchelf --print-needed runtime/libwetype-shim.so | wc -l)"
"$CC" -O0 -g -o harness/jinterop harness/jinterop.c \
  -ldl -lpthread -Wl,--no-as-needed -lm "$PWD/runtime/libz.so.1"
"$CC" -O0 -g -o harness/probe harness/probe.c -ldl -lpthread \
  -Wl,--no-as-needed -lm "$PWD/runtime/libz.so.1"
echo "build ok"
