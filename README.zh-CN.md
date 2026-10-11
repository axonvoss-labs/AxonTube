<p align="center">
  <img src="docs/assets/axontube-banner.svg" alt="AxonTube — 用 AI，更快掌握世界语言。" width="720">
</p>

<h1 align="center">AxonTube<br>用 AI，更快掌握世界语言。</h1>

<p align="center"><strong>把 YouTube 变成你的私人语言课堂。</strong></p>

<p align="center">
  <img src="docs/assets/badges/swift.svg" alt="开发语言：Swift" width="112" height="20">
  <img src="docs/assets/badges/macos.svg" alt="运行平台：macOS" width="104" height="20">
  <img src="docs/assets/badges/interface-languages.svg" alt="24 种界面语言" width="153" height="20">
  <a href="LICENSE"><img src="docs/assets/badges/license-mit.svg" alt="许可：MIT" width="81" height="20"></a>
  <img src="docs/assets/badges/preview.svg" alt="版本 0.5.3 — macOS 预览版" width="141" height="20">
</p>

[English](README.md) · **简体中文** · [繁體中文](docs/guides/zh-Hant.md) · [日本語](docs/guides/ja.md) · [한국어](docs/guides/ko.md) · [Español](docs/guides/es.md)

[Français](docs/guides/fr.md) · [Deutsch](docs/guides/de.md) · [Italiano](docs/guides/it.md) · [Português](docs/guides/pt.md) · [Русский](docs/guides/ru.md) · [العربية](docs/guides/ar.md)

[हिन्दी](docs/guides/hi.md) · [Türkçe](docs/guides/tr.md) · [Tiếng Việt](docs/guides/vi.md) · [ไทย](docs/guides/th.md) · [Bahasa Indonesia](docs/guides/id.md) · [Nederlands](docs/guides/nl.md)

[Polski](docs/guides/pl.md) · [Українська](docs/guides/uk.md) · [Svenska](docs/guides/sv.md) · [Dansk](docs/guides/da.md) · [Suomi](docs/guides/fi.md) · [עברית](docs/guides/he.md)

[产品亮点](#产品亮点) · [已有功能](#已有功能) · [快速开始](#快速开始) · [待解决问题](#待解决问题) · [开发说明](#详细说明与开发)

**看你热爱的视频，学你向往的语言。**

从热爱的视频出发，借助 YouTube 字幕和自动翻译，双语对照、逐句重听，把感兴趣的内容变成可以反复学习的材料。

**24 种界面语言 · 多语字幕学习**

> **0.5.3 · 适用于 Apple 芯片 Mac 的预览版。** 最近一次 YouTube 下载检查遇到登录／机器人验证，当前在线取流仍需实际验证。

**[下载 DMG 安装包](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.dmg)** · [下载 ZIP](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/AxonTube-0.5.3-macos-arm64.zip) · [SHA-256 校验码](https://github.com/axonvoss-labs/AxonTube/releases/download/v0.5.3/SHA256SUMS.txt) · [版本说明](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3)

需要 Apple 芯片 Mac；最低部署目标为 macOS 14。此预览版采用临时签名，尚未经过 Apple 公证，首次打开前请阅读[安装说明](docs/INSTALL.md)。下方仍提供源码构建方法。

![AxonTube 双语播放与逐句练习](docs/assets/interface-study.png)

*实际应用窗口：播放随附本地示例，显示英语和繁体中文字幕；截图使用英语界面。*

<details>
<summary>更多截图：欢迎页、双语字幕选择、YouTube 入口</summary>

### 欢迎页与主要入口

![欢迎页与主要入口](docs/assets/interface-zh.png)

展示四个顶部入口、常驻的两个字幕选择框、本地化标语，以及未打开视频时的明确禁用状态。

### 第一字幕与第二字幕

![第一字幕与第二字幕](docs/assets/interface-caption-languages.png)

英语界面的实际截图：两轨语言可独立选择，默认分别是英语和繁体中文。

### 打开 YouTube 链接

![打开 YouTube 链接](docs/assets/interface-youtube-dialog.png)

英语界面的链接输入窗口实际截图。打开链接后开始播放，并请求当前选择的两条字幕。

</details>

## 产品亮点

- **从观看到练习，步骤直接** — 顶部四个入口依次为 YouTube → 保存视频 → 字幕设置 → 语言。打开链接后自动取字幕，无须再点击额外的获取按钮。
- **学习资料可以留下来** — 时间轴字幕用于听力练习，Word／TXT 便于阅读和复习。导出使用新目标位置，保留原始文件。
- **本地处理，无需 AI API 密钥** — 本地媒体和已保存字幕可离线使用。网站字幕与自动翻译由 YouTube 提供；应用不设置遥测，不上传本地媒体，也不需要付费 AI API 密钥。

## 已有功能

| 功能 | 具体能力 |
| --- | --- |
| 两条独立字幕轨道 | 默认英语／繁体中文，可选择当前视频提供的原语字幕或自动译文。第二轨失败时，已获取的第一轨仍可阅读和导出。 |
| 围绕句子的听读练习 | 支持字幕搜索、点句跳转、上一句／下一句、重听、循环、倍速，以及跟随当前句滚动。 |
| 保存视频与同步字幕 | 字幕仍在获取时也能开始保存。每次建立新目录，写入可下载的视频；有可用字幕时，另存带时间轴的 SRT 与双语阅读文件。支持只保存视频，未完成内容保留在 .partial 目录中。 |
| 导出 Word、TXT、SRT | 按当前字幕与时间偏移导出。Word 和 TXT 按时间重叠配对双语内容；只有一条字幕时也能导出。 |
| 24 种本地化界面 | 菜单、状态提示和学习标语随语言一起切换，阿拉伯语和希伯来语支持从右向左排版。切换界面不会改写字幕内容。 |
| 本地播放与明确的按钮状态 | 可从“文件”菜单打开本地媒体和字幕。不可用按钮灰显并说明原因，已选模式高亮加勾，保存过程显示忙碌状态。 |

24 种指界面语言选项。字幕语言以当前视频实际提供的轨道为准，不代表保证掌握 24 种语言。

## 快速开始

1. **打开 YouTube:** 粘贴视频链接，自动请求可用字幕，默认第一字幕英语、第二字幕繁体中文。首次获取可能需要约 1–2 分钟，实际可用性取决于视频和服务状态。
2. **选择语言并练习:** 通过常驻的两个字幕下拉框选择语言。点击句子可跳转、重听，也可以开启单句循环。
3. **保存或导出:** “保存视频”将可下载的媒体和可用字幕存入指定目录；“导出双语字幕”把已经载入的字幕保存为 Word、TXT 或 SRT。
4. **调整学习方式:** 切换界面语言、倍速、字幕字号和两轨各自的时间偏移。应用会记住界面语言与字幕语言选择。

## 待解决问题

| 优先级 | 问题 | 当前状态与后续工作 |
| --- | --- | --- |
| P0 | YouTube 字幕与视频的实际可用性 | 最近一次在线检查遇到 YouTube 登录／机器人验证，尚未证实当前环境下能成功下载在线字幕或视频。公开发布前，需要在实际使用网络和不同代表性视频上验证。 |
| P1 | 嵌入播放和账号限制 | 部分作者或视频不允许嵌入播放。尚无应用内 Google SSO；浏览器入口使用独立的登录与播放会话。这些限制不能视为已经解决。 |
| P1 | 正式签名及更多 Mac 测试 | 安装包目前为 ad-hoc 签名，未做 Developer ID 公证。已测试 Apple Silicon、macOS 26.5.2；macOS 27 和 Intel Mac 尚未实测。macOS 14 是部署目标，不代表每个版本都已验证。 |
| P2 | 下载画质与字幕准确性 | 保存选用完整音视频流，不合并独立的高分辨率视频与音频流。ASS／SSA 只导入文字。自动字幕、译文以及按时间配对的双语内容均可能有误差。本地播放取决于编解码器支持；可选 FFmpeg 转换可能无法保留额外音轨、HDR 和内嵌字幕。 |
| P2 | 学习记录与进阶学习工具 | 播放历史恢复、生词本、间隔复习、OCR 与图片字幕提取尚未实现。记住语言偏好不等于保存了学习进度。 |
| P2 | 各语言的母语级校对 | 24 种界面与宣传语已经通过切换检查，这证明了覆盖和交互正常，不等于全部译文均经过专业母语审校。 |

## 验证情况

0.5.3 已通过 105 项核心检查、138 项模型断言、29 项字幕检查、60 项视频保存检查及 317 项原生界面断言。实际点击了全部 24 个语言选项，并检查了六种语言界面与德文紧凑窗口。

已验证本地播放、导出、状态切换和原生保存目录弹窗。离线样本和模拟下载工具测试，不能证明 YouTube 当前允许在线字幕或视频下载。测试没有导入用户登录凭据。

[查看完整验证记录](docs/VERIFICATION.md)

## 详细说明与开发

<details>
<summary>使用细节：双语字幕、按钮状态、保存和导出</summary>

### 四个入口

顶部依次为 **YouTube → 保存视频 → 字幕 → 语言**。

1. **YouTube：**粘贴链接并打开，自动获取第一字幕英语、第二字幕繁体中文。
   第一轨获取成功后先显示，自动译文通常还需等待一至两分钟，无需另点获取字幕。
2. **保存视频：**选择目录，将视频与同步字幕一起保存，方便本地使用。
   打开视频后即可保存，字幕仍在下载或获取失败都不会禁用按钮。
   只有主动选择保存才下载视频；直接打开链接使用在线播放。
3. **字幕：**需要时调整两轨的时间和外观。
   句子列表上方的“导出双语字幕”可保存 SRT、Word `.docx` 或 UTF-8 `.txt`。
4. **语言：**下拉菜单直接列出全部 24 种界面语言。默认英语，记住选择；
   界面语言和字幕内容分别处理。

**第一字幕**和**第二字幕**两个语言下拉框固定显示在句子列表上方，默认英语和
繁体中文。下拉列表提供当前视频实际可用的字幕，选择后自动获取，无需额外按钮。

不可用按钮明显置灰，播放或保存区域会显示原因；已启用模式高亮，菜单以勾选标明
当前语言、倍速和字幕模式，便于区分状态和互斥选项。

点句跳转、上一句／下一句、重听、单句循环、字幕搜索和倍速均保留。
两轨可分别调整时间偏移，画面字幕和句子列表可分别调整字号。

字幕原文及自动译文来自 YouTube，应用通过内置 yt-dlp 工具获取。
不调用 ChatGPT、Claude 或收费翻译 API，不需要 AI API key。
字幕语言以当前视频实际提供的内容为准，繁体中文不可用时不会以简体中文冒充。

### 界面语言

支持英语、简体中文、繁体中文、日语、韩语、西班牙语、法语、德语、意大利语、
葡萄牙语、俄语、阿拉伯语、印地语、土耳其语、越南语、泰语、印度尼西亚语、
荷兰语、波兰语、乌克兰语、瑞典语、丹麦语、芬兰语和希伯来语。
阿拉伯语、希伯来语使用从右到左布局。

这份名单不限制 YouTube 字幕语言。切换界面不会改写字幕；系统对话框、外部错误和
YouTube 官方播放器可能使用自身的语言设置。

### 保存和导出

“保存视频”将本地视频与同步字幕文件放在选定目录；列表上方的字幕导出则把当前
已获取内容保存为阅读文档或时间轴字幕，两种用途分别提供。

选好目录后立即下载视频。如果字幕仍在获取，同一次保存会等候当前请求完成并收录
已获取的轨道。只有一轨或没有字幕时会明确提示，不会因字幕失败而阻止保存可下载的视频。

每次保存建立新目录，包含 `video.<扩展名>`、已有轨道的 `video.primary.srt`、
`video.secondary.srt`，有字幕时另存 `subtitles.bilingual.srt`、`.txt`、`.docx`。
随视频保存的字幕保留原始分段，时间偏移只应用一次；下次保存会记住上次目录。
失败或取消后保留 `.partial` 文件夹及已生成字幕。

YouTube 保存选择同时含画面与声音的单文件格式，优先 MP4，无需 FFmpeg。
不会合并分离的高分辨率音视频流，画质以网站提供的完整格式为准。
本地视频也能复制，有已载入字幕时一起保存。

单独导出字幕时保留按句整理和两轨时间偏移。SRT 按实际时间边界分段；Word、TXT 按时间重叠
配对并保留未匹配文字。只有一轨可用时也能导出。搜索条件和画面隐藏状态不会裁掉
导出内容，保存对话框打开之后完成的新请求也不会改写这次导出的快照。

文件菜单仍保留本地视频和字幕导入，便于使用已有文件；YouTube 学习流程无需导入。
随附静音几何示例用于演示播放、字幕和导出。

</details>

<details>
<summary>系统要求、构建和架构</summary>

### 系统要求与构建

目前构建面向 Apple Silicon，Intel 尚未验证。基础播放与 YouTube 字幕的部署目标
为 macOS 14+；构建需要含 macOS 26 SDK 的 Apple 工具和 Python 3。
可选格式转换需要单独安装 FFmpeg。部署目标不代表所有版本都已实机测试。

源代码保留 macOS 26 的 Apple 本机听写与翻译组件，它们不属于简化后的顶部入口，
也不参与自动获取 YouTube 字幕的流程。

```sh
git clone --branch axontube https://github.com/axonvoss-labs/AxonTube.git
cd AxonTube

python3 scripts/prepare-release-helper.py --download \
  --cache dist/helper-downloads --output dist/release-helper-arm64
swift build -c release
python3 scripts/check-core.py
python3 scripts/check-model.py
python3 scripts/check-captions.py
python3 scripts/check-video-save.py
bash scripts/package.sh --skip-build --helper-dir dist/release-helper-arm64 \
  --output-dir dist/app-0.5.3
open "dist/app-0.5.3/AxonTube.app"

bash scripts/package-release.sh --app dist/app-0.5.3/AxonTube.app \
  --helper-dir dist/release-helper-arm64 --output-dir dist/release-0.5.3
```

依赖准备需要 Apple 芯片 Mac；带 `--download` 的命令显式下载并校验固定版本工具。
输出目录必须是新目录，保留已有安装包。打包会生成图标、去除本机编译路径并校验
辅助程序清单，打包过程本身不下载依赖。预览版使用 ad-hoc 签名，未做 Developer ID 签名或公证。
完整 Xcode 可运行 `swift test`，CLT 检查脚本结果单独记录，不冒充 XCTest。

[系统架构与代码导览](docs/ARCHITECTURE.md)

</details>

<details>
<summary>网络、隐私与格式限制</summary>

### 网络和当前边界

本地媒体和已保存字幕可离线使用，无遥测、不上传本地媒体。
打开 YouTube 链接会联网播放并自动获取字幕；主动点击“保存视频”并选择目录后，
才开始下载媒体文件。

YouTube 可能限制嵌入、字幕、翻译或下载。应用会提示失败，保留已成功载入的字幕；
不自动反复重试，不导入浏览器凭据或绕过登录。浏览器入口打开原站，浏览器的
账号与播放进度不会自动同步到内嵌播放器。

字幕缓存不等于离线视频；元数据读取成功也不代表字幕和视频一定可下载。
本轮在线验证结果见[验证记录](docs/VERIFICATION.md)。

AVFoundation 支持的格式取决于文件；可选 FFmpeg 转换生成新的 H.264/AAC MP4，
不保证保留全部音轨、HDR 或内嵌字幕。ASS/SSA 只导入文字。
播放历史恢复、OCR、生词本、Whisper、云端 AI、应用内 Google SSO、图片字幕提取
尚未实现。自动字幕和译文可能有错误。

</details>

[English guide](docs/guides/en.md) · [简体中文说明](docs/guides/zh-Hans.md) · [繁體中文說明](docs/guides/zh-Hant.md) · [Architecture](docs/ARCHITECTURE.md) · [YouTube details](docs/YOUTUBE.md)

各语言说明都是仓库内的 Markdown 页面。另保留[离线 HTML 说明](docs/product-guide.html)，下载后可在本地浏览。

## 许可

应用自有代码采用[MIT 许可](LICENSE)，第三方材料保留原许可，
见 [NOTICE](NOTICE.md) 与[源码及依赖说明](docs/SOURCE-ACCESS.md)。
