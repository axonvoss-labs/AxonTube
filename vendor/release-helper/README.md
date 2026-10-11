# Public release helper profile

This profile provides a self-contained arm64 macOS helper. Users do not need
Python, Homebrew, Node, or a first-run dependency installer. The existing
`Contents/Helpers/yt-dlp` interface remains unchanged.

Prepare on arm64 macOS with Python 3.9+ and the Xcode command-line tools:

```sh
python3 scripts/prepare-release-helper.py --download \
  --cache dist/release-helper-downloads --output dist/release-helper-arm64
```

Downloads occur only with the explicit `--download` option. Without it, all
pinned files must already be in the cache. The script checks every input's size
and SHA-256 before extraction or execution. It refuses to replace an existing
output directory. Choose a fresh output path for another preparation.

The output contains `Helpers/`, `LICENSES/`, `SOURCES/`, and `MANIFEST.json`.
The manifest records every regular file's SHA-256, size, and mode, plus every
symlink target. It excludes only itself. Native files are checked for arm64
architecture, portable library paths, and valid ad-hoc signatures before the
manifest is written. QuickJS is compiled from the pinned source, stripped, and
signed before hashing. The packager must preserve helper bytes and copy the
license directory. Publish the dependency-materials archive beside the app.

The launcher uses bundled Python with `-I -B`, so user Python configuration is
ignored and executing the app does not add bytecode to the signed bundle.
It sets `SSL_CERT_FILE` to the bundled certifi roots, selects only bundled
QuickJS, and disables configuration, plugins, updates, and remote components.
It uses `exec` so exit status and cancellation refer to the actual helper.
The original Unix yt-dlp executable is retained byte for byte as `yt-dlp.pyz`.

The app uses metadata, VTT captions, automatic translations supplied by YouTube,
and a single complete video/audio format for Save Video. These operations do
not need mutagen's thumbnail embedding, curl_cffi's optional TLS impersonation,
or FFmpeg merging. Those optional tools are not bundled. EJS is already inside
the pinned Unix executable; QuickJS provides the required JavaScript engine.
Online restrictions, codec limits, and the availability of directly saveable
formats still apply. Passing the offline checks is not proof that a particular
YouTube video is currently accessible.

The recipe copies a selected runtime from the upstream Python artifact. It
omits package installers, Tk, tests, and development tools; it does not modify
the retained Python native binaries or library source. The matching full
Python archive supplies original license texts and `PYTHON.json`. The exact
runtime metadata is checked for GPL GDBM and GNU readline before packaging.
See `NOTICE.md` for each component's license and certifi source access.

To reuse the recipe from a dependency-materials archive, copy
`SOURCES/prepare-release-helper.py` to `scripts/prepare-release-helper.py` and
`SOURCES/{INPUTS.json,NOTICE.md,README.md}` to `vendor/release-helper/` in a new
working directory. Use `SOURCES` as `--cache`; `--download` will fetch the
three pinned binary/metadata inputs that are deliberately not duplicated in
that source-and-notice archive. The checked source archives are already there.

Input provenance: GitHub release digests pin Python and yt-dlp; PyPI's release
metadata pins certifi and EJS. astring and meriyah additionally match the
SHA-512 integrity values in EJS's published `package-lock.json`. QuickJS's
official HTTPS source archive is pinned by the recorded local SHA-256; no
independent upstream signature verification is claimed.

Upstream references:

- <https://github.com/yt-dlp/yt-dlp/tree/2026.06.09#licensing>
- <https://github.com/yt-dlp/yt-dlp/wiki/EJS>
- <https://github.com/astral-sh/python-build-standalone/releases/tag/20261009>
- <https://github.com/astral-sh/python-build-standalone/blob/main/docs/running.rst>
- <https://bellard.org/quickjs/>
