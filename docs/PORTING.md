# Platform design and compatibility

AxonTube is an independently implemented native macOS application. SwiftUI and
AppKit provide the interface; AVFoundation handles local media; WebKit hosts
the official YouTube player. There is no Windows compatibility layer and no
third-party Swift package dependency.

## Runtime capabilities

| Area | Implementation | Boundary |
| --- | --- | --- |
| Local playback | AVPlayer and AVFoundation | Supported containers still depend on their actual codecs |
| Online playback | WKWebView and official YouTube IFrame API | Accessible and embeddable videos only |
| Imported subtitles | Native Swift parser and timeline | SRT, WebVTT, ASS/SSA text; no styled ASS rendering |
| Website captions | Independent yt-dlp process | Automatic retrieval after opening a YouTube link; first English, second Traditional Chinese by default |
| Save Video | Separate explicit yt-dlp download or local copy | New destination folder with synchronized subtitle files; one complete audio/video format |
| Retained on-device speech components | Apple SpeechAnalyzer | macOS 26+, actual SDK-supported languages; outside the simplified YouTube toolbar |
| Retained on-device translation components | Apple Translation | SDK-supported pairs and system-managed packs; not used for YouTube automatic translations |
| Bilingual exports | Native Swift | SRT, TXT, DOCX; no Office installation required |
| Format conversion | Separately installed FFmpeg | Creates a new H.264/AAC file |
| UI languages | 24 choices, default English | Direct full language menu; separate from subtitle content |

The package deployment target is macOS 14. Building the entire application
requires an SDK containing the newer speech APIs. Runtime availability checks
gate features that require a newer system. A deployment target does not
establish successful testing on every supported release.

## Hardware and distribution

Current packaging targets Apple Silicon. Intel, macOS 27, other physical Macs,
and older macOS releases require their own testing before compatibility claims
are extended. Historical results and current checks are recorded in
[VERIFICATION.md](VERIFICATION.md).

Local packaging applies an ad-hoc signature. Developer ID signing, Apple
notarization, and App Store distribution are not implemented. Applications
transferred to another Mac may therefore require the normal macOS security
review for software from an unidentified developer.

## Deliberate boundaries

Local media and subtitle files remain unchanged. Derived conversion files go
to the app's cache; exports go to a destination selected by the user. Save Video
creates a unique folder containing the video and loaded subtitle sidecars.
Unfinished operations retain their `.partial` folder and do not overwrite source
files. Video saving does not require FFmpeg; it selects an available combined
audio/video format instead of merging separate streams.

The app uses separate timelines for each subtitle track. It does not assume
that the English and Chinese arrays have the same count or matching indices.
Sentence grouping works from existing cue timing and does not invent word-level
timestamps. Machine-generated translations are not silently treated as verified.

The demonstration video uses project-generated geometric graphics without
spoken narration. It demonstrates playback and subtitles, not transcription.

## Possible future work

These are design options, not delivered features:

- Additional playback backends and embedded subtitle/audio-track support.
- Alternative local speech or translation backends, with separately reviewed
  model licenses and explicit preparation controls.
- Playback history, vocabulary collections, and dictionary integration.
- OCR and broader subtitle formats.
- Intel validation, signed/notarized distribution, and wider device testing.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the current component boundaries.
