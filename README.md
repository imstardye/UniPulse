<div align="center">

<img src="assets/images/icon.png" alt="UniPulse" width="88">

# UniPulse

UniPulse is an independent multi-platform proxy client based on ClashMeta/mihomo. Simple to use, open source and ad-free.

**English** · [简体中文](README_zh_CN.md)

[![Release](https://img.shields.io/github/v/release/imstardye/UniPulse?style=flat-square&label=release)](https://github.com/imstardye/UniPulse/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/imstardye/UniPulse/total?style=flat-square&logo=github)](https://github.com/imstardye/UniPulse/releases)
[![License](https://img.shields.io/github/license/imstardye/UniPulse?style=flat-square)](LICENSE)

[Download](#download) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="snapshots/preview-dark.png">
    <img alt="UniPulse dashboard on a MacBook and a phone" src="snapshots/preview.png" width="92%">
  </picture>
</p>

## Features

- **One app for Android, Windows, macOS and Linux**, with x64 and ARM64 builds on the desktop.
- **mihomo (Clash.Meta) core** with rule routing, proxy groups, latency tests, system proxy and TUN mode.
- **Profiles** from a subscription link or a file, with a built-in editor, override scripts, and custom rules,
  proxies and proxy groups.
- **Live views** of connections, requests, DNS queries and logs.
- **Material You design with Apple-style interaction**: dynamic color, light and dark themes, continuous corners,
  sheets that snap between heights, and layouts that adapt from phones to desktops.
- **Backup and restore** through WebDAV or a local file.
- **Platform touches**: a Quick Settings tile, per-app proxy and Android TV support on Android; a tray menu and
  global hotkeys on the desktop.
- **Open source and ad-free**, licensed under GPL-3.0.

## Download

Get the latest build from [GitHub Releases](https://github.com/imstardye/UniPulse/releases/latest).

| Platform | Packages | Notes |
| --- | --- | --- |
| Android | APK for `arm64-v8a`, `armeabi-v7a` and `x86_64` | Most phones use `arm64-v8a`. |
| Windows 10 and later | Installer (`.exe`) or portable `.zip`, for x64 and ARM64 | Pick ARM64 on Snapdragon and other ARM laptops. |
| macOS 12 and later | DMG for Apple Silicon and Intel | |
| Linux | `.deb`, `.rpm` and AppImage, for x64 and ARM64 | See the tray note below. |

<p>
  <a href="https://github.com/imstardye/UniPulse/releases/latest"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Linux tray icon**

The tray icon is a StatusNotifierItem. KDE Plasma, XFCE and most panels show it as is; GNOME needs the
AppIndicator and KStatusNotifierItem Support extension.

**Unattended desktop**

UniPulse starts the core only after the disclaimer is accepted. Where nobody can click it, such as a container, set
`UNIPULSE_ACCEPT_DISCLAIMER=1` in the app's environment to accept it on first launch.

## Usage

**Import a profile from a link.** Opening a link in this form imports the subscription into UniPulse. The `clash://`, `clashmeta://` and `flclash://` schemes remain compatible.

```text
unipulse://install-config?url=<URL-encoded subscription link>
```

**Automate on Android.** Tasker, MacroDroid and similar apps can start, stop or toggle the proxy by starting an
activity with one of these actions:

```text
com.imstardye.unipulse.action.START
com.imstardye.unipulse.action.STOP
com.imstardye.unipulse.action.TOGGLE
```

From a computer, the same works over adb:

```bash
adb shell am start -a com.imstardye.unipulse.action.TOGGLE
```

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.50 (release builds use 3.50.0),
[Go](https://go.dev/dl/) 1.27 and [Rust](https://rustup.rs/) installed through rustup. Each platform builds on its own
host, except Android, which builds anywhere.

```bash
git clone --recursive https://github.com/imstardye/UniPulse.git
cd UniPulse
flutter pub get
dart run tool/package.dart android   # or windows, macos, linux
```

Packages land in `dist/`. The Go core and the Rust libraries are compiled as part of the Flutter build.

| Platform | Also needed |
| --- | --- |
| Android | Android SDK with the NDK. Add `--arch arm64` to build a single ABI. |
| Windows | GCC (MinGW-w64) for the core and [Inno Setup](https://jrsoftware.org/isinfo.php) 6 for the installer. |
| macOS | Xcode and Node.js. The script installs `appdmg` through npm. |
| Linux | Debian or Ubuntu. The script installs the build packages with apt and downloads `appimagetool`. |

Run `dart run tool/package.dart --help` for the remaining options, such as `--targets` to build only some package formats or `--dry-run` to list the files a run would write.

## Support

Starring the repository is the easiest way to support the project. Bugs and feature requests go to
[GitHub Issues](https://github.com/imstardye/UniPulse/issues).

<a href="https://star-history.com/#imstardye/UniPulse&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=imstardye/UniPulse&type=Date&theme=dark">
    <img alt="Star history" src="https://api.star-history.com/svg?repos=imstardye/UniPulse&type=Date" width="640">
  </picture>
</a>

## Migration

UniPulse uses the new application ID `com.imstardye.unipulse`. Android and macOS users install it as a new app. Quit the old app before the first launch. Desktop data is copied and verified automatically; the original remains available for rollback. Android sandboxing prevents direct access to the old app’s private data on standard devices: export a backup from the old app and restore it in UniPulse before removing it. The old Android actions `com.follow.clash.action.START/STOP/TOGGLE` remain accepted; shared `clash://`, `clashmeta://` and `flclash://` links also work.

Homebrew, Telegram and F-Droid distribution will be announced after their new endpoints are confirmed.

## License

UniPulse is released under the [GPL-3.0 license](LICENSE).
