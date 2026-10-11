# YouTube playback, subtitles, and saving

The main flow is **YouTube → Save Video → Subtitles → Language**. Paste a video
link into YouTube and open it. The official player loads, while English and
Traditional Chinese subtitles are requested automatically. There is no extra
**Get YouTube Captions** or local subtitle-import step.

## Automatic subtitles

The first track defaults to English (`en`); the second defaults to Traditional
Chinese (`zh-Hant`). The two selections are independent of the interface language.
The first track is shown when ready, followed by the second. A translated track
usually adds around a minute of waiting; allow roughly one to two minutes for
the initial pair. This is an estimate, not a service guarantee.

**First subtitle** and **Second subtitle** are always visible in the sidebar,
above export and search. Each dropdown uses the current video's actual caption
metadata. **Subtitles** contains timing and appearance settings. Changing a
subtitle language requests that pair automatically. Existing loaded content keeps its
correct label until the replacement is ready. A failed second track does not
remove a successfully loaded first track, which remains usable and exportable.

The pinned yt-dlp helper reads website caption metadata and text. It is not a
ChatGPT or Claude integration and needs no AI API key. YouTube supplies automatic
translations. This feature does not use the public YouTube Data API or imply
permission to edit the selected video's captions.

The catalog retains each safe WebVTT track and its source: manual captions,
original automatic recognition, automatic translation, or automatic content with
an unknown source. An English translation of French speech is labeled as a
translation. Available tracks vary by video; the 24 interface languages are not
a limit on subtitle language choices.

A language-only first-track choice prefers manual captions, then original
recognition, then an available translation. A second automatic track must match
the selected underlying source. Exact catalog choices retain their specific
source. Traditional Chinese and Simplified Chinese remain distinct.

Automatic-translation requests include an approximately 65-second wait to reduce
previously observed rate limiting. That delay can apply to either translated
track. A missing track, sign-in requirement, request limit, or network failure is
reported; it is not silently replaced by another language. There is no automatic
retry loop, proxy switching, or browser-cookie import.

## Save Video

Save Video is an explicit action, separate from opening and streaming a video.
Choose a destination to save the video together with its synchronized subtitle
files. The button becomes available as soon as a video is open, even if captions
are still loading, absent, or failed. It is disabled while another save is active.

The video download starts immediately after the destination is chosen. If the
selected subtitle pair is still loading, the save waits up to 420 seconds for
that same request to finish. It keeps available tracks if the request fails or
the wait expires, and reports whether it saved both tracks, one track, or video
without subtitles. No extra subtitle request is started by Save Video. Loaded
captions are captured once ready, with the time offsets from the destination
selection. Changing video or subtitle language cannot insert unrelated captions
into the save.

Each operation creates a unique `AxonTube <video ID> <UUID>` folder. It contains
`video.<ext>`, the available `video.primary.srt` / `video.secondary.srt`, and
`subtitles.bilingual.srt`, `.txt`, and `.docx` when captions are available.
Subtitles preserve the downloaded cue divisions and apply each timing offset once. A folder keeps its `.partial`
suffix until media and subtitle saving complete; failure or cancellation preserves the
partial output and already-written subtitles. The app remembers the chosen
parent destination for the next save.

The helper selects a complete format with picture and sound, preferring MP4.
Separate audio/video streams are not merged, so FFmpeg is not required and
available quality can differ from the highest streaming resolution.

Media availability is checked by the download itself. YouTube can allow embedded
playback while refusing a media download, or expose metadata without a downloadable format; in
those cases the operation reports the failure. It does not bypass account or
service restrictions.

A subtitle cache alone is not an offline video. For offline playback, use the
video and subtitle files produced by a successful save. Existing local files can
also be opened through the File menu without adding import buttons to the
YouTube study flow.

## Subtitle export

**Export Bilingual Subtitles**, above the sentence list, saves bilingual SRT,
Word `.docx`, or UTF-8 `.txt`. Export includes current grouping and time offsets, even when a search
filter or visibility setting hides part of the content. Word and TXT pair cues
by overlap and keep unmatched text; SRT uses actual time boundaries.

Exports take a snapshot of loaded captions. Captions that arrive after an export
begins require a new export. No Microsoft Word installation or online service is
needed to create the files.

## Playback and account limits

AxonTube uses the official embedded player in WKWebView. Link parsing accepts
watch, short-link, Shorts, live, and embed URLs; only a validated video ID and
start time reach the player. The player preserves YouTube controls, branding,
and advertisements. AxonTube displays its study subtitles below the video;
YouTube's own CC settings remain separate.

The WebKit session is nonpersistent. AxonTube does not import Safari or Chrome
cookies, request Google passwords, or implement Google SSO inside the app.
Opening a video in the browser uses that browser's account session; its playback
clock and login do not synchronize to the app.

Embedding, account, age, regional, and verification restrictions may prevent
playback. The app displays the IFrame error and YouTube's own message. Errors
101/150 alone are not treated as proof that an author disabled embedding. Error
153 has a separate app-identity diagnostic. The browser action is available when
the official player requires it.

References: [IFrame API](https://developers.google.com/youtube/iframe_api_reference),
[IFrame errors](https://developers.google.com/youtube/iframe_api_reference#onError),
[native-app OAuth](https://developers.google.com/identity/protocols/oauth2/native-app),
[Data API caption permissions](https://developers.google.com/youtube/v3/docs/captions/download).

## Local data and validation

Caption caches live under
`~/Library/Caches/io.github.axonvoss-labs.axontube/YouTubeCaptions/v3/`.
Keys include video, cache schema, and both ordered language/source choices. The
manifest validates track identity and content hashes. Cancelled or superseded
requests cannot populate a different video's session. Metadata previews are
memory-only and bound to a video ID; old cache versions remain untouched.

The helper ignores external yt-dlp configuration and plugins. Automatic caption
retrieval does not download video media. Save Video has a separate explicit
media-download path. Neither path imports browser credentials or uploads local
media.

`--ignore-no-formats-error` allows caption metadata retrieval even when video
formats are unavailable. A successful process exit with empty subtitle tables
is not a successful caption download. Earlier public-video checks returned empty
caption and format tables; they did not establish successful online retrieval.
The current build's actual checks and remaining gaps are recorded in
[Verification](VERIFICATION.md). Offline fixtures separately check selection,
cache isolation, cancellation, and export behavior.

Apple live speech components remain in the source but are not part of the
simplified YouTube flow and are not used to obtain website translations. Opening
a YouTube link triggers neither speech-model preparation nor audio capture.
