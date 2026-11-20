<div align="center">

<img src="assets/images/icon.png" alt="UniPulse" width="88">

# UniPulse

基于 ClashMeta/mihomo 的独立多平台代理客户端，简单易用，开源无广告。

[English](README.md) · **简体中文**

[![Release](https://img.shields.io/github/v/release/imstardye/UniPulse?style=flat-square&label=release)](https://github.com/imstardye/UniPulse/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/imstardye/UniPulse/total?style=flat-square&logo=github)](https://github.com/imstardye/UniPulse/releases)
[![License](https://img.shields.io/github/license/imstardye/UniPulse?style=flat-square)](LICENSE)

[下载](#下载) · [更新日志](CHANGELOG.md) · [从源码构建](#从源码构建)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="snapshots/preview-dark.png">
    <img alt="UniPulse 在 MacBook 与手机上的仪表盘" src="snapshots/preview.png" width="92%">
  </picture>
</p>

## 功能

- **一个应用覆盖 Android、Windows、macOS 和 Linux**，桌面端同时提供 x64 与 ARM64 版本。
- **mihomo（Clash.Meta）内核**：规则分流、代理组、延迟测试、系统代理与 TUN 模式。
- **配置管理**：通过订阅链接或文件导入配置，内置编辑器，支持覆写脚本以及自定义规则、代理和代理组。
- **实时查看**连接、请求、DNS 查询和日志。
- **Material You 设计，融合 Apple 式交互**：支持动态取色、浅色与深色主题，连续曲率圆角，弹出面板可在几档高度间吸附，布局随屏幕从手机到桌面自适应。
- **备份与恢复**：通过 WebDAV 或本地文件。
- **平台细节**：Android 上有快捷设置磁贴、分应用代理和 Android TV 支持；桌面端有托盘菜单和全局快捷键。
- **开源无广告**，以 GPL-3.0 协议发布。

## 下载

从 [GitHub Releases](https://github.com/imstardye/UniPulse/releases/latest) 获取最新版本。

| 平台 | 安装包 | 说明 |
| --- | --- | --- |
| Android | `arm64-v8a`、`armeabi-v7a`、`x86_64` 三种 APK | 绝大多数手机选 `arm64-v8a`。 |
| Windows 10 及以上 | 安装版（`.exe`）或便携版（`.zip`），分 x64 与 ARM64 | 骁龙等 ARM 架构笔记本选 ARM64。 |
| macOS 12 及以上 | Apple Silicon 与 Intel 两种 DMG |  |
| Linux | `.deb`、`.rpm` 和 AppImage，分 x64 与 ARM64 | 托盘依赖见下方说明。 |

<p>
  <a href="https://github.com/imstardye/UniPulse/releases/latest"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Linux 托盘图标**

托盘图标是 StatusNotifierItem。KDE Plasma、XFCE 和多数面板直接显示；GNOME 需要安装 AppIndicator and KStatusNotifierItem Support 扩展。

**无人值守的桌面环境**

UniPulse 要在免责声明被接受后才会启动核心。在容器等无人点击的环境里，可在应用的环境变量中设置
`UNIPULSE_ACCEPT_DISCLAIMER=1`，首次启动时即视为接受。

## 使用

**通过链接导入配置。** 打开下面格式的链接，即可把订阅导入 UniPulse。`clash://`、`clashmeta://` 和 `flclash://` 兼容链接同样可用。

```text
unipulse://install-config?url=<经过 URL 编码的订阅链接>
```

**Android 自动化。** Tasker、MacroDroid 等应用可以用下面的 Action 启动 Activity，从而启动、停止或切换代理：

```text
com.imstardye.unipulse.action.START
com.imstardye.unipulse.action.STOP
com.imstardye.unipulse.action.TOGGLE
```

在电脑上也可以通过 adb 触发：

```bash
adb shell am start -a com.imstardye.unipulse.action.TOGGLE
```

## 从源码构建

需要 [Flutter](https://docs.flutter.dev/get-started/install) 3.50（正式版构建使用 3.50.0）、[Go](https://go.dev/dl/) 1.27，
以及通过 rustup 安装的 [Rust](https://rustup.rs/)。桌面端需要在对应系统上构建，Android 在任意系统上都能构建。

```bash
git clone --recursive https://github.com/imstardye/UniPulse.git
cd UniPulse
flutter pub get
dart run tool/package.dart android   # 或 windows、macos、linux
```

安装包输出到 `dist/`。Go 内核和 Rust 库会在 Flutter 构建过程中一并编译。

| 平台 | 额外依赖 |
| --- | --- |
| Android | 带 NDK 的 Android SDK。加上 `--arch arm64` 可以只构建单个 ABI。 |
| Windows | 编译内核用的 GCC（MinGW-w64），以及打包安装程序用的 [Inno Setup](https://jrsoftware.org/isinfo.php) 6。 |
| macOS | Xcode 与 Node.js。脚本会通过 npm 安装 `appdmg`。 |
| Linux | Debian 或 Ubuntu。脚本会用 apt 安装构建所需的软件包，并下载 `appimagetool`。 |

其余选项可以运行 `dart run tool/package.dart --help` 查看，例如用 `--targets` 只构建部分安装包格式，用 `--dry-run` 列出这次会生成的文件。

## 支持

给仓库点一个 Star 是支持项目最简单的方式。Bug 与功能建议请提交到 [GitHub Issues](https://github.com/imstardye/UniPulse/issues)。

<a href="https://star-history.com/#imstardye/UniPulse&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=imstardye/UniPulse&type=Date&theme=dark">
    <img alt="Star history" src="https://api.star-history.com/svg?repos=imstardye/UniPulse&type=Date" width="640">
  </picture>
</a>

## 数据迁移

UniPulse 使用新应用 ID `com.imstardye.unipulse`，Android 和 macOS 需作为新应用安装。首次启动前先退出旧应用；桌面版自动复制并校验旧数据，原目录保留以便回滚。普通 Android 设备的系统沙箱禁止跨应用读取私有数据，请先从旧应用导出备份，在 UniPulse 中恢复后再卸载旧应用。旧 Android 动作 `com.follow.clash.action.START/STOP/TOGGLE` 以及 `clash://`、`clashmeta://`、`flclash://` 链接仍可使用。

Homebrew、Telegram 与 F-Droid 新地址确认后再公布。

## 许可证

UniPulse 以 [GPL-3.0 协议](LICENSE)发布。
