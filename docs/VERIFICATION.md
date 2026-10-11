# Verification record

## Initial public source preview — 2026-10-11

The reviewed AxonTube tree was exported into a separate publication checkout
on branch `axontube`, without inherited development commits. The publication
history uses a project identity and anonymous address. The source tree was
checked for private identifiers, credentials, machine paths, and image/video
author metadata; required third-party license files remain intact.

Validation in the clean publication checkout:

| Check | Result |
| --- | --- |
| Release build | `swift build -c release` passed |
| Core | 105 checks, zero failures |
| Model | 138 assertions passed |
| Caption handling | 29 offline assertions passed |
| Video saving | 60 assertions passed with a fake helper |
| Documentation | 24 language editions regenerated; 884 local Markdown references resolved |
| Publication scope | Source, tests, scripts, notices, documentation and original demo assets only; no packaged app, helper binary, user caches or media |

These results establish the inspected source build and offline behavior. They
do not resolve YouTube login/bot restrictions, signing/notarization, broader
Mac compatibility, or the binary redistribution limits documented below.

## AI language-learning headline — 2026-10-11

The README titles, promotional banner, and all 24 guide headlines/intros now
emphasize learning the world's languages faster with AI. All other translated
feature, issue, and evidence fields are unchanged. The copy identifies YouTube
as the source of captions and automatic translation.

The banner's SVG text bounds passed local rendering checks. The updated
English/Chinese README previews passed ten WebKit checks and were visually
reviewed on desktop and mobile. The guide passed 250 WebKit assertions across
all 24 languages at both viewport widths. No application feature changed;
the existing service and compatibility limitations still apply.

## Repository README presentation — 2026-10-11

The English and Chinese repository homepages now present the product directly:
centered branding, five local factual badges, 24 language links, real app
screenshots, feature and open-issue tables, and collapsible usage/build details.
All 24 translated Markdown guides now link to every language edition and back
to the root READMEs. The standalone HTML guide remains an optional offline view.

Local GFM rendering covered both root READMEs and all 24 language guides;
884 local document and image references resolved. Native WebKit inspection
passed ten checks for loaded assets, four collapsed sections, section links,
feature/issue tables, expanded screenshots, English/Chinese navigation, mobile
width, and absence of remote resources. Five desktop/mobile preview images
were rendered and reviewed. Badge SVG text fits the declared bounds.

The GitHub-style repository frame is a local visual simulation. It has not
been uploaded to GitHub, does not prove GitHub server rendering, and contains
no invented Stars, Forks, CI status, or public release. Application source and
the packaged player were unchanged; application tests were not rerun for this
documentation-only update.

## Illustrated product guide — 2026-10-11

This documentation update leaves application source and the 0.5.3 package unchanged.
`python3 scripts/build-guide.py` generates the offline HTML page and 24 Markdown
editions from matching language-data schemas. Each edition includes four screenshot
types, four workflow steps, six features, three highlights, six prioritized issues,
and the distinction between local test results and current YouTube availability.

Local WebKit inspection passed **250 assertions**, covering all 24 languages at
1280-pixel and 390-pixel viewport widths, text and direction changes, section counts,
image loading, horizontal overflow, language-specific links, repeated section and
brand navigation, language/section restoration after reload, and the accessible
screenshot dialog. No remote scripts, stylesheets, or image resources were loaded.
Desktop English, Simplified Chinese and Arabic, the Chinese issue list, and the
Chinese mobile layout were rendered and visually reviewed.

The study screenshot captures only an isolated application window playing the
bundled silent `demo.mp4` with English and Traditional Chinese subtitle files.
It shows local playback and sentence controls; it is not evidence of a successful
YouTube download. The translation coverage checks are not native-speaker editorial
certification. The app's online-service and platform limits below remain open.

## 0.5.3 — control states and localized learning message, 2026-10-11

The interface distinguishes available, disabled, selected, and busy controls.
Playback readiness and save availability remain separate conditions. The
welcome message is “Learn languages faster. Explore a world of knowledge.”;
its supporting count describes 24 interface choices, not a fixed count of
learnable or downloadable subtitle languages.

| Check | Result |
| --- | --- |
| Release compilation | `swift build -c release` passed |
| Core and model | 105 core checks with zero failures; 138 application-model assertions passed |
| Caption cache and fetcher | 29 assertions passed offline |
| Video save controller | 60 assertions passed with a fake helper |
| Native interaction | 317 assertions passed: welcome/unready/ready availability, actual Play/Pause and loop/follow clicks, one selected rate/language per menu, both subtitle dropdowns, and the Save directory chooser |
| Localized copy | Nine new keys resolved correctly in all 24 languages (216 checks); 364 unique catalog rows with 21 additional language columns |
| Visible language switching | Selected all 24 choices in the actual native menu and verified the displayed headline and language-count badge changed accordingly |
| Layout | English, both Chinese scripts, German, Japanese, Arabic, and 1160×720 compact German reviewed; selected and unselected study controls captured |
| Promotional banner | Local WebKit render reviewed; every SVG text element fits the 1440×420 bounds |
| Source preservation | All 61 recorded original source hashes remain unchanged |
| Final package | 0.5.3 build 11; 24 locales, release executable UUID, pinned helper SHA-256, resources, strict ad-hoc signature, and ZIP CRC passed; archive checksum recorded |
| Packaged window | Final application launched; Accessibility inspection confirmed version 0.5.3, the new welcome headline, both subtitle menus, and Save disabled before opening media |

The online-service and platform limitations recorded below remain applicable.
This update is a local review build.

## 0.5.2 — visible subtitle controls and Save Video, 2026-10-11

Read-only accessibility inspection of the running 0.5.1 application confirmed
that Save Video was disabled on the welcome screen, although its custom style
still looked active. Code inspection also found that opened YouTube videos
could not be saved while captions were pending, missing, or failed. The two
language controls existed only inside settings after a YouTube video was open.

Both subtitle-language dropdowns now remain visible above the sidebar export
action. Save Video is visibly dimmed with an explanatory tooltip before a video
is opened. Once a video is open, caption availability does not disable saving.
Pending captions are collected from the same request while media saves; their
timing offsets are captured at destination selection. Completion accurately
distinguishes two tracks, one track, and video without subtitles.

| Check | Result |
| --- | --- |
| Release compilation | `swift build -c release` passed |
| Core | 105 checks, zero failures |
| Model | 138 assertions passed; includes saving with pending/failed/absent captions, captured offsets, bounded waits, and changed-video/language isolation |
| Caption cache and fetcher | 29 assertions passed offline |
| Video save controller | 60 assertions passed with a fake helper; covers video-only saves, video finishing before captions, subtitle-stage cancellation, both offsets, partial results, and retained partial media |
| Localization | 355 unique catalog rows, 21 additional language columns, 24 interface languages total |
| Native subtitle menus | Both sidebar menus opened, changed selection, persisted it, and returned to English / Traditional Chinese without opening settings |
| Native Save action | A YouTube controller with no captions and no webpage loaded enabled the actual toolbar button; Accessibility press opened a directory-only `NSOpenPanel`. Cancelling started no download |
| Interface language menu | All 24 choices appeared directly; actual Japanese selection took effect |
| Native playback and layout | AVPlayer clock, eight cues per track, seek, sentence loop, and language changes passed; six interface languages and compact German reviewed |
| Source preservation | All 61 recorded original source hashes remain unchanged |
| Local package | Version 0.5.2, build 10; release Mach-O UUID, 24 locales, pinned helper hash, resources, strict ad-hoc signature, and ZIP CRC passed; archive SHA-256 recorded |
| Packaged application | Launched the final 0.5.2 app; Accessibility inspection found both subtitle-menu identifiers on its welcome screen and the expected disabled Save action before opening media |

The online-service limitation recorded below still applies. This update does
not establish a successful live YouTube download; it fixes button availability,
language-control placement, and the local save workflow.

## 0.5.1 — simplified workflow, 2026-10-11

The toolbar is now **YouTube → Save Video → Subtitles → Language**. Opening a
YouTube video starts the selected caption pair automatically, defaulting to
English and Traditional Chinese. The extra fetch, local subtitle, language-loader,
and live-speech entries have been removed from the main workflow. Subtitle
language changes trigger retrieval; same-video reloads keep captions and pending
translations. File-menu local import remains available.

| Check | Result |
| --- | --- |
| Core parsing, caption selection, exports, localization, and save arguments | 105 checks, zero failures |
| Actual application-model workflow | 124 assertions passed, including automatic captions, language changes, cache reuse, failure retention, video isolation, and synchronized save snapshots |
| Caption fetcher/cache | 29 assertions passed without a helper or network |
| Video save controller | 42 assertions passed with an offline fake helper, including bounded pipe output, live progress, cancellation, stale callbacks, unique folders, failures, two subtitle offsets, DOCX/TXT/SRT, and original-file preservation |
| Interface | Compiled native views reviewed in English, both Chinese scripts, German, Japanese, Arabic, and compact German; simplified URL dialog and two subtitle selectors reviewed |
| Language dropdown | The actual native menu opened with all 24 languages at the first level; selecting Japanese updated the interface preference. The native menu also contains its empty internal title item, not an extra language or submenu |
| Playback regression | Actual AVPlayer clock, eight cues in each language, seek, bilingual overlay, language switching without a position reset, and sentence looping passed |
| Original source | All 61 recorded source hashes unchanged |
| Release compilation | `swift build -c release` passed for 0.5.1 |
| Local package | Version 0.5.1, build 9, matching release Mach-O UUID, 24 locales, icon/demo/notices, pinned helper hash, and strict ad-hoc signature verification passed |

Save Video uses a new directory and writes independent timed SRT sidecars plus
bilingual SRT, Word, and TXT copies. It takes a snapshot of current raw cues and
applies each timing offset once. Failures and cancellations leave a `.partial`
directory and do not report success. A test caught the output pipe waiting for
a full buffer before publishing progress; reads now return available bytes,
and the progress/cancellation regression check passes.

The model and save checks use local fixtures. Their success **does not certify
current YouTube availability**. A fresh metadata request for the public official
iframe-demo video returned a sign-in / “confirm you’re not a bot” warning, no
captions, and no downloadable formats. Thus live YouTube subtitle and video
downloads remain unverified in this environment. No browser cookies or login
credentials were imported. Embedded playback, captions, and downloadable media
can have different access conditions.

This update remains a local review build. The package is ad-hoc signed; macOS 27,
Intel hardware, notarization, and other physical Macs have not been tested.

## 0.5.0 — local review build, 2026-10-11

Environment: Apple Silicon arm64, macOS 26.5.2 (25F84), Apple Swift 6.3.
The renamed application is being checked independently of the historical
baseline below. This update remains local pending interface/documentation review.

| Check | Current result |
| --- | --- |
| Release build for AxonTube | Passed: `swift build -c release` |
| Core subtitle, language, caption-plan, and export checks | 102 checks, zero failures on the final language catalog |
| Application-model checks | 106 assertions passed in isolated preference domains |
| Real caption fetcher and cache checks | 29 assertions passed, with no helper or network invoked |
| Full app-owned localization lookup | 322/322 source keys × 21 added language columns passed, including all 15 dynamic templates; 24 interface languages total |
| English default and saved language choices | Passed in separate processes; website defaults `en` / `zh-Hant` |
| Language switch preserves playback/session state | Passed in model checks and native preview |
| Native UI snapshots | Reviewed English, both Chinese scripts, German, Japanese, Arabic, 1160×720 compact layout, and YouTube language controls |
| Local media and sentence practice | AVPlayer clock advanced; eight cues in each track loaded; seeking, bilingual overlay, and loop wrapping passed |
| SRT / TXT / DOCX output | Core structure/ordering checks and model write/readback passed; native save dialog not repeated this run |
| Package identity, helper hash, and signature | Passed: version/bundle/24 locales, matching release Mach-O UUID, icon/demo/notices, helper SHA-256, and `codesign --verify --deep --strict` |
| Original project preservation | SHA-256 comparison: all 61 recorded original files unchanged |
| First-party source audit | No stale first-party brand references, private home/LAN paths, or tested credential patterns found |
| Documentation links | All local Markdown references resolved |

The current app identity is **AxonTube 0.5.0**, bundle identifier
`io.github.axonvoss-labs.axontube`, packaged locally at
`dist/0.5.0/AxonTube.app`.

### What these checks establish

`python3 scripts/check-core.py` executes the core test functions through a
Command Line Tools assertion adapter. It covers parsing, timing, sentence
grouping, caption metadata and source identity, Traditional/Simplified Chinese
selection, cache-plan validation, export contents, and interface interpolation.
It is not reported as a successful XCTest invocation.

`python3 scripts/check-model.py` compiles the real application sources into an
isolated harness. Checks include preference persistence, default languages,
changing stored status text without recreating playback state, asynchronous
subtitle replacement, offsets, immutable export snapshots, and actual file
writes. `python3 scripts/check-captions.py` separately exercises the real cache
and fetcher, including both language choices in cache identity, stale result
rejection, changed-file digests, source-qualified choices, and video identity
for language discovery. It uses isolated temporary data and no helper/network.

Native previews use the actual SwiftUI views and PlayerModel in an isolated
application. Screenshots in `docs/assets/` show real compiled views, not mockups.
The local playback check uses the silent bundled geometric video and English /
Traditional Chinese sidecars. NSView bitmap capture does not include AVPlayer's
composited video layer; study captures with that limitation stay in private QA.
The observed AVPlayer clock and subtitle/loop checks are reported separately.

### Live-service and platform limits

A public-video metadata request completed but returned only partial information:
a video title/ID, no caption entries, no formats, and no duration. Because the
helper uses `--ignore-no-formats-error`, exit status zero does not certify full
metadata, prove that a video has no subtitles, or identify the exact cause.
**This run did not successfully validate downloading live YouTube subtitles.**
The app reports that the current request returned no tracks and that captions
may be absent or access restricted. Offline selection tests do not establish
current YouTube service availability.

The expanded Apple speech/translation language selectors were compiled and
language matching was checked with eight isolated Foundation cases. Language
packs were not downloaded and the new language combinations were not tested
with live speech. YouTube application-audio capture remains unverified end to
end. macOS 27, Intel hardware, and other physical Macs were not tested.

Interface coverage checks verify catalog keys, language columns, placeholders,
and literal preservation; they are not a native-speaker editorial review.
Apple-owned dialogs, the YouTube player, and external system diagnostics may
follow their own language settings. User filenames and subtitle content retain
their original text.

Third-party licenses and notices remain in the project. Public binary
redistribution requires the separate dependency/source review described in
[SOURCE-ACCESS.md](SOURCE-ACCESS.md). The local package is ad-hoc signed, not
Developer ID signed or notarized. It has not been uploaded or published.

## Historical baseline — 0.1 through 0.4.3

The following summarizes prior local records from 2026-10-02 and 2026-10-04.
The environment was Apple Silicon arm64, macOS 26.5.2, and Swift 6.3 Command
Line Tools. These observations predate the 0.5.0 naming and UI-language changes.

### Build and deterministic checks

- Release builds and local ad-hoc signature checks passed for the recorded
  baseline versions.
- The final 0.4.3 core run reported **83 checks, zero failures**. It covered
  subtitle parsing and encoding, overlapping intervals, YouTube links and
  caption selection, live transcript revisions, sentence grouping, SRT export,
  and DOCX/TXT output structure.
- The 0.4.3 model harness reported **100 assertions passed**, including export
  snapshots, independent offsets, late-result isolation, source-file protection,
  saved preferences, and actual exported-file readback.
- Core checks used a Command Line Tools assertion adapter against the project's
  test functions. `swift test` did not run successfully in that environment
  because XCTest was unavailable. These are not reported as XCTest passes.

### Local playback and study interface

Native UI checks opened an original short demonstration with two subtitle
tracks, observed playback and subtitle changes, searched and selected a sentence,
and confirmed repeated playback within a selected loop. Independent time offsets,
subtitle size settings, persistence, and switching sentence grouping off and on
were exercised. An original MKV test file was converted into a new playable MP4.

The baseline UI was primarily Chinese. These observations do not verify the
new English interface or the completeness of a language switch.

### YouTube playback and website captions

A public Google for Developers video was loaded in the official embedded
player. Playback, pause, five-second seeking, sentence looping with imported
subtitles, and opening the original video in the system browser were observed.
No password entry, OAuth flow, or cookie export formed part of those tests.

A later website-caption test retrieved **466 English cues** and **424 nonempty
Chinese cues**. Both raw tracks contained 466 intervals; 42 Chinese intervals
were empty. The app retained missing translations rather than fabricating them.
A repeated request restored valid captions from cache. These online captions
were test data and were not included in the application or source package.

The baseline sentence grouping produced 246 English groups and 242 Chinese
groups, leaving four English groups without a paired translation. Switching to
raw mode restored the original English cues. The source cache remained unchanged.

These figures describe one video at the time of testing. They are not current
service availability or accuracy guarantees.

### On-device speech and translation

The baseline UI prepared English speech and English/Simplified Chinese
translation models. A short local test without subtitle sidecar files produced
eight finalized English sentences and eight generated Chinese translations.
The test fixture then used system-generated English narration; its audio is
not an asset intended for public redistribution.

Separate checks exercised pause-aware audio feeding, cancellation, seeking,
resampling, transcript revision, and stale-translation rejection. Short synthetic
speech observations do not establish performance across accents, noise, or
long recordings.

For YouTube, the baseline reached the system application picker after models
were prepared. **The application-audio capture and live-transcription path was
not authorized and tested end to end.** This remains an open verification gap.

### Bilingual document export

The native save panel produced SRT, Word `.docx`, and UTF-8 `.txt` files.
Checks covered output extensions, source-file and symbolic-link protection,
ZIP CRCs, DOCX XML structure, text ordering, and content readback.

A short DOCX was laid out as one page by macOS native OOXML import and TextKit;
a longer fixture occupied two pages. The rendered pages were visually inspected
for clipping and missing text. This was a native-rendering fallback, not the
`render_docx.py` workflow, and did not establish full Microsoft Word, WPS, or
LibreOffice compatibility. Pagination can differ between readers.

## Remaining limits

The baseline did not test macOS 27, Intel hardware, other physical Macs, or the
macOS 14–25 runtime matrix. It did not cover every codec, multi-hour sessions,
DRM, all HDR/audio-track combinations, every file-system failure mode, or every
subtitle format variation.

Private, membership, age-restricted, region-restricted, and continuously updated
live YouTube content are outside the verified scope. Browser viewing remains
separate from the app's playback clock. App-internal Google SSO is not implemented.

There is no Apple Developer ID signature or notarization. A valid local ad-hoc
signature does not guarantee Gatekeeper acceptance on another Mac.

New results should identify the actual command or UI action, artifact version,
observed outcome, and material limitation. Do not turn a code review, earlier
result, or successful build into a claim of an unperformed runtime test.
