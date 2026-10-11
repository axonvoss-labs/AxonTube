# AxonTube contributor guidance

AxonTube is a native macOS learning player implemented with SwiftUI, AppKit,
AVFoundation, WebKit, and on-device Apple speech and translation frameworks.

- Keep changes within this project. Preserve original media and subtitles;
  exports and conversions must use new destinations or application caches.
- English is the default among 24 interface-language choices. Keep English and
  Simplified Chinese source labels together and update the localization catalog
  for other languages. Store asynchronous messages as `LocalizedText` segments
  so existing messages change language without resetting playback. Preserve
  native language names, both Chinese scripts, and Arabic/Hebrew RTL behavior.
- Translate interface text, never the user's filenames or subtitle content.
- Local playback is offline. Network actions require a visible user action.
  Do not add telemetry, cloud AI fallbacks, or media uploads.
- Use the official YouTube embedded player. Respect playback restrictions,
  branding and controls. Do not import browser cookies or credentials.
- Caption retrieval uses a pinned yt-dlp subprocess for metadata and text only.
  Opening a YouTube link automatically requests captions; Save Video is a
  separate, explicitly selected media download with a user-chosen destination.
  Preserve synchronized subtitle sidecars and never overwrite source files.
  Do not add implicit updates, plugins, browser-cookie imports, or retry loops.
- Website subtitles default to first-track English (`en`) and second-track
  Traditional Chinese (`zh-Hant`). Populate all available choices from the
  current video's usable caption metadata, preserving language and source
  identity. Changing either subtitle choice starts retrieval automatically;
  keep loaded tracks accurately labeled while replacement is pending. Preserve partial first-track success and reject stale pair results.
- Keep the primary toolbar in this order: YouTube, Save Video, Subtitles,
  Language. The language menu directly lists all 24 choices. The default
  YouTube flow needs no local subtitle import, extra fetch action, or live
  speech setup. Keep local-file tools in the File menu.
- Keep interface, website-caption, and live-caption language preferences
  independent. Read Apple speech/translation language support from the SDK and
  check each translation pair. Never label Simplified Chinese as Traditional
  Chinese or claim unsupported languages work. Changing a live language stops
  the session, invalidates old work, and clears that live transcript before reuse.
- YouTube automatic translation comes from YouTube. Apple speech/translation
  runs on device. Do not add ChatGPT, Claude, paid AI API calls, or API-key setup.
- Audio capture requires explicit selection of this app. Reject other apps;
  do not record the microphone or screen. Apple models are system managed;
  downloads require explicit preparation actions, never background support checks.
- Preserve third-party licenses and accurately describe feature limitations.
- Validate changes with `swift build -c release`, `python3 scripts/check-core.py`,
  `python3 scripts/check-model.py`, `python3 scripts/check-captions.py`, and
  `python3 scripts/check-video-save.py`. Review changed UI in English, both Chinese
  scripts, and representative additional languages including RTL. Record only
  checks actually run, and distinguish deterministic checks from live service,
  installed-model, audio-capture, and visual validation.
- AxonTube source publication and subsequent source updates are authorized for
  the project GitHub repository and its configured local Git mirror. Keep the
  AxonTube publication branch `axontube` separate from legacy product branches.
  Only AxonTube may go to public GitHub; every other legacy product and its
  branches must remain local, including all inherited development history.
  Never push legacy history, use `--all`/`--mirror`, or force-push as part of a
  routine update. Preserve third-party notices and licenses.
- Publish only a reviewed, privacy-checked source tree. Keep real names,
  personal email addresses, machine paths, credentials, private infrastructure
  addresses, caches, and user media out of files and publication history. Use
  the project identity and an anonymous commit address. Check a source change
  in the publication checkout before synchronizing both configured remotes.
- After every update, report the product and branch, whether GitHub and the
  local mirror were each updated, the published commit, and actual validation
  results. Verify both remote branch tips against the local publication commit;
  a successful push alone is not sufficient. See `docs/RELEASING.md`. Private
  checkout/remotes and the last synchronization result, when available, are
  recorded in the ignored `qa/publication-state.json` file for local continuity.
