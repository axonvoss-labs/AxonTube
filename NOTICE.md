# Notices and attribution

AxonTube — YouTube AI Learning Player is an independently implemented native
macOS application built with SwiftUI, AppKit, AVFoundation, and WebKit. Its
application source, project scripts, original documentation, and original
demonstration graphics and subtitle text are distributed under the
[MIT License](LICENSE), except where a file identifies different terms.
Third-party materials retain their own licenses and notices.

## Caption helper

YouTube caption retrieval uses yt-dlp as a separate command-line process.
yt-dlp's own source is released under the Unlicense. Its upstream macOS
standalone executable includes third-party components and is licensed as
GPLv3-or-later according to the pinned upstream release documentation.

The application license does not replace the licenses of yt-dlp or its
dependencies. Preserve the complete [yt-dlp LICENSE](vendor/yt-dlp/LICENSE),
[THIRD_PARTY_LICENSES.txt](vendor/yt-dlp/THIRD_PARTY_LICENSES.txt), and
[dependency provenance](vendor/yt-dlp/PROVENANCE.md).
See [source and dependency access](docs/SOURCE-ACCESS.md) before distributing
a package containing the helper.

## Optional conversion tool

FFmpeg is an optional, separately installed program used for local compatibility
conversion. This source repository does not distribute FFmpeg. Its license
depends on the particular build; see the [FFmpeg legal page](https://ffmpeg.org/legal.html).

## Apple frameworks and models

Apple frameworks are supplied by macOS. Speech and translation models are
managed by the operating system; they are not included in this repository or
licensed by this project. The 0.5.0 demonstration is a silent geometric video
with project-authored subtitle text; Apple system voice recordings are not
part of its intended public assets.

## Online content and trademarks

YouTube playback uses the official embedded player. YouTube, Google, Apple,
and other product names belong to their respective owners. This project is
not affiliated with or endorsed by those companies.

Videos, website captions, account information, and user caches are not project
assets and are not covered by the application's MIT License. Access to online
services remains subject to their own terms and content permissions.
