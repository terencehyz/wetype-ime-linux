# WeType Linux

在 Linux 上通过 Fcitx 5 使用微信输入法（WeType）引擎。引擎是 Android ARM64 版本，本项目在 **原生 aarch64** 主机上直接运行它。

> **非官方项目**，与腾讯无关，也未获其认可。WeType、微信输入法、微信是腾讯的商标。使用 WeType 引擎须遵守腾讯的相关条款。

本仓库和 AppImage 只包含本项目自己的代码，以及可再分发的运行时（zlib），不包含任何 WeType 文件。安装时会从腾讯官方服务器下载 WeType 3.5.4 APK，校验 SHA-256 后在本机打补丁，思路类似 Minecraft 的 Paper。

## 安装

先安装依赖：

```sh
sudo apt install python3 patchelf unzip curl          # Debian / Ubuntu
sudo dnf install python3 patchelf unzip curl          # Fedora（RHEL 上 patchelf 来自 EPEL）
sudo pacman -S --needed python patchelf unzip curl    # Arch
```

然后运行（需要 aarch64 主机）：

```sh
./WeTypeIME-Engine-aarch64.AppImage install            # 安装到 ~/.local；用 sudo 则安装到 /usr
```

安装完成后重启 Fcitx5，并在输入法配置中添加“微信拼音”。

其他命令：

```sh
./WeTypeIME-Engine-aarch64.AppImage install --apk 文件   # 使用已下载的 APK（仅支持 3.5.4，其他版本未经测试，会被拒绝）
./WeTypeIME-Engine-aarch64.AppImage uninstall            # 卸载（保留词库和用户数据）
./WeTypeIME-Engine-aarch64.AppImage demo nihao           # 命令行测试候选词
```

APK 约 214 MB，只下载一次，缓存在 `~/.cache/wetype-ime`。用户学习数据在 `~/.local/share/wetype-ime`。

Fcitx5 插件依赖 Fcitx5 ≥ 5.0.11（使用 `InputMethodEngineV2`）。若发行版仓库只有很旧的 Fcitx5，需要自行构建较新版本。

## 从源码构建

构建环境为 **aarch64 的 Debian / Ubuntu**（引擎是 ARM64，不再交叉编译，也不需要 QEMU）：

```sh
sudo apt install build-essential cmake patchelf binutils file unzip python3 curl \
  libfcitx5core-dev
```

插件是宿主（aarch64）的 Fcitx5 addon，`find_package(Fcitx5Core)` 需要对应的开发包。

```sh
scripts/e2_img.sh        # 构建插件、harness 并打包 AppImage（不需要 APK）
```

没有 FUSE 时（容器、虚拟机）请设置 `APPIMAGE_EXTRACT_AND_RUN=1`。打包时如果发现任何来自 APK 的文件，会拒绝打包。

在源码树中直接调试引擎：

```sh
scripts/20_build.sh          # 构建 shim 和 harness（原生 aarch64）
scripts/prepare_assets.sh    # 下载并校验 APK 到 .deps/
scripts/10_patch_libs.sh     # 修补 APK 中的库，输出到 runtime/
```

`20_build.sh` 需要 aarch64 的 zlib（`/usr/lib/aarch64-linux-gnu/libz.so.1`），也可以用 `WETYPE_ZLIB_SO` 指向其他位置的 `libz.so.1`。

插件日志默认写入 `/tmp/wetype-harness.log`。

## 目录结构

- `fcitx5-wetype/`：Fcitx 5 插件
- `harness/`、`shim/`：ARM64 JNI 兼容层
- `scripts/`：下载、补丁、构建、打包和测试脚本

## 许可证

本项目使用 GPL-3.0-or-later，见 [LICENSE](LICENSE)。AppImage 内附带的 zlib 的许可说明见镜像内的 `usr/share/doc/wetype-ime/THIRD-PARTY.md`。WeType 引擎和词库归腾讯所有，不在本许可范围内，本项目也不分发它们。
