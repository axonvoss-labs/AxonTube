# Notices and attribution

AxonTube — YouTube AI Learning Player is an independently implemented native
macOS application built with SwiftUI, AppKit, AVFoundation, and WebKit. Its
application source, project scripts, original documentation, and original
demonstration graphics and subtitle text are distributed under the
[MIT License](LICENSE), except where a file identifies different terms.
Third-party materials retain their own licenses and notices.

## Caption helper

YouTube caption retrieval and explicit Save Video actions use yt-dlp as a
separate command-line process. Public arm64 packages use its official Unix
zipimport executable with a private Python runtime, QuickJS, and certificate
roots. yt-dlp and EJS use the Unlicense; their bundled astring and meriyah
JavaScript use MIT and ISC. QuickJS uses MIT. Python and its native components
retain their respective licenses, and certifi's certificate bundle uses MPL-2.0.
The exact profile, original notices, and certifi source-access directions are
described in [release helper notices](vendor/release-helper/NOTICE.md).

The optional local `prepare-ytdlp.sh` workflow instead retrieves upstream's
PyInstaller macOS standalone executable. That separate combined artifact is
GPLv3-or-later according to the pinned upstream release documentation; it is
not the helper selected for this public binary profile.

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
