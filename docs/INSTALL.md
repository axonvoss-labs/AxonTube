# Install AxonTube 0.5.3 / 安装 AxonTube 0.5.3

[English](#english) · [简体中文](#简体中文)

## English

AxonTube 0.5.3 is a public preview for **Apple Silicon Macs (arm64)**. The
deployment target is macOS 14 or later; the tested system is **macOS 26.5.2**.
Other macOS versions and Intel Macs have not been verified.

### Download and check

Choose one application archive from the [v0.5.3 release](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3):

| File | Use |
| --- | --- |
| [AxonTube-0.5.3-macos-arm64.dmg](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.dmg) | Open a disk image and drag the app into Applications. |
| [AxonTube-0.5.3-macos-arm64.zip](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.zip) | Extract the app and move it into Applications. |
| [SHA256SUMS.txt](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/SHA256SUMS.txt) | Compare the checksum of your downloaded archive. |

In Terminal, open the download folder and calculate the archive's checksum:

```sh
cd ~/Downloads
shasum -a 256 AxonTube-0.5.3-macos-arm64.dmg
```

For the ZIP, replace the filename with `AxonTube-0.5.3-macos-arm64.zip`.
The resulting digest must match the line for that filename in `SHA256SUMS.txt`.
If it differs, download the file again from the release page before opening it.

### Install

Choose either method:

- **DMG:** open the downloaded disk image, drag `AxonTube.app` into
  **Applications**, then eject the disk image.
- **ZIP:** double-click the ZIP in Finder, then move the extracted
  `AxonTube.app` into **Applications**.

Open AxonTube from **Applications**.

### First launch and macOS security

This preview uses an **ad-hoc signature**. It is **not Developer ID signed or
Apple-notarized**, so macOS may block the first launch.

Only after downloading from the project release page, checking the checksum,
and deciding that you trust this preview:

1. Try to open `AxonTube.app` once.
2. Open **System Settings → Privacy & Security**. Find the blocked-app entry
   and choose **Open Anyway**.
3. Confirm **Open** in the subsequent prompt.

This is an exception for this app. Follow
[Apple's official guidance](https://support.apple.com/en-us/102445); managed
Macs may restrict this option. A warning that software is damaged or will harm
the computer is a different condition: stop and verify the download instead
of treating it as a routine developer-verification warning.

### Start learning

Open a local video and subtitle files from the **File** menu, or choose
**YouTube** and paste a video link. The YouTube flow requests available captions
automatically, defaulting to English and Traditional Chinese. YouTube captions,
translations, embedded playback and downloads depend on the video's availability
and service restrictions. The latest live download check encountered sign-in /
bot verification; successful online retrieval is still unverified.

[Release notes](releases/v0.5.3.md) · [English guide](guides/en.md) ·
[Verification record](VERIFICATION.md) · [Dependency and source information](SOURCE-ACCESS.md)

## 简体中文

AxonTube 0.5.3 是面向 **Apple Silicon Mac（arm64）** 的公开预览版。
部署目标为 macOS 14 或更高版本；目前实际测试的系统是 **macOS 26.5.2**。
其他 macOS 版本及 Intel Mac 尚未验证。

### 下载并核对文件

从 [v0.5.3 发布页面](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3)
选择一种应用压缩包：

| 文件 | 用途 |
| --- | --- |
| [AxonTube-0.5.3-macos-arm64.dmg](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.dmg) | 打开磁盘映像，将应用拖入“应用程序”。 |
| [AxonTube-0.5.3-macos-arm64.zip](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.zip) | 解压后将应用移入“应用程序”。 |
| [SHA256SUMS.txt](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/SHA256SUMS.txt) | 核对下载文件的校验值。 |

在“终端”中进入下载文件夹，计算文件的校验值：

```sh
cd ~/Downloads
shasum -a 256 AxonTube-0.5.3-macos-arm64.dmg
```

如果下载的是 ZIP，将文件名替换为 `AxonTube-0.5.3-macos-arm64.zip`。
输出的摘要必须与 `SHA256SUMS.txt` 中对应文件名那一行一致。
如果不一致，请先从发布页面重新下载，再打开文件。

### 安装

选择其中一种方式：

- **DMG：**打开下载的磁盘映像，将 `AxonTube.app` 拖入**“应用程序”**，
  然后推出磁盘映像。
- **ZIP：**在“访达”中双击 ZIP，将解压得到的 `AxonTube.app` 移入**“应用程序”**。

从**“应用程序”**打开 AxonTube。

### 首次启动与 macOS 安全提示

此预览版使用 **ad-hoc 签名**，**没有 Developer ID 签名，也未经过 Apple 公证**，
因此 macOS 可能会阻止首次启动。

从项目发布页面下载、核对校验值，并确认信任此预览版后：

1. 先尝试打开一次 `AxonTube.app`。
2. 打开**“系统设置”→“隐私与安全性”**，找到被阻止的应用提示，选择**“仍要打开”**。
3. 在随后出现的提示中确认**“打开”**。

这是针对该应用的例外设置。请参阅
[Apple 官方说明](https://support.apple.com/zh-cn/102445)；受组织管理的 Mac
可能限制此选项。如果系统提示软件“已损坏”或“将损坏你的计算机”，请停止打开并
重新核对下载文件，不要把这类提示当作普通的开发者身份验证提示。

### 开始学习

从**“文件”**菜单打开本地视频和字幕，或者选择 **YouTube** 并粘贴视频链接。
YouTube 流程会自动请求可用字幕，默认第一轨为英语，第二轨为繁体中文。
YouTube 字幕、翻译、嵌入播放和下载取决于视频是否可用以及服务限制。
最近一次在线下载检查遇到了登录／机器人验证要求，当前在线获取是否成功仍未验证。

[版本说明](releases/v0.5.3.md) · [简体中文指南](guides/zh-Hans.md) ·
[验证记录](VERIFICATION.md) · [依赖与源码信息](SOURCE-ACCESS.md)
