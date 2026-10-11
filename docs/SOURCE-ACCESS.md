# Source and dependency access

This repository provides the AxonTube application source, tests, build scripts,
and original documentation under the [MIT License](../LICENSE). Third-party
materials retain their own terms and copyright notices.

## Public arm64 binary profile

Public arm64 packages use the official Unix zipimport build of **yt-dlp
2026.06.09**, bundled with a private **CPython 3.13.16** runtime from
python-build-standalone **20261009**, **QuickJS 2026-06-04**, and the unmodified
**certifi 2026.5.20** certificate roots. This package needs no system Python,
Homebrew, or first-run dependency installation.

Prepare the profile explicitly on arm64 macOS:

```sh
python3 scripts/prepare-release-helper.py --download \
  --cache dist/release-helper-downloads --output dist/release-helper-arm64
```

Without `--download`, preparation only uses already cached, verified inputs.
The script checks fixed sizes and SHA-256 values before extracting or building
anything. Building or launching the app does not silently download tools.
All input versions, exact URLs, sizes, and digests are in
[`vendor/release-helper/INPUTS.json`](../vendor/release-helper/INPUTS.json).

The output includes `Helpers`, `LICENSES`, `SOURCES`, and a complete file
manifest. Packaging must preserve helper bytes, include the notices, and
provide the dependency-materials archive beside the app. That archive supplies
the matching yt-dlp, EJS, astring, meriyah, QuickJS, and certifi source archives,
the preparation recipe, the upstream runtime license metadata, and exact
download locations for the prebuilt Python inputs. It is not represented as
a source rebuild of the entire Python distribution.

The official Unix yt-dlp build contains Unlicense, MIT, and ISC components.
QuickJS is MIT. Python's native license inventory is checked against the exact
upstream `PYTHON.json`; the selected runtime has no GPL GDBM or GNU readline.
Package installers and their vendored libraries, Tk, and development tools are
omitted. Original runtime license texts are retained. See the
[profile documentation](../vendor/release-helper/README.md) and
[component notices](../vendor/release-helper/NOTICE.md).

The bundled `cacert.pem` remains covered by MPL-2.0. Its matching source is
available in `SOURCES/certifi-2026.5.20.tar.gz` in the dependency-materials
archive and at the exact official URL in the manifest. The original MPL text
is included as `LICENSES/certifi/LICENSE`. The application license does not
restrict the source rights granted by MPL-2.0.

## Optional local standalone workflow

For local development, the existing command remains available:

```sh
bash scripts/prepare-ytdlp.sh
```

It downloads the unmodified upstream **yt-dlp_macos 2026.06.09** PyInstaller
executable, verifies SHA-256
`b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244`,
and does not install anything globally. That combined standalone artifact is
GPLv3-or-later. It is a different dependency profile from the public arm64
package described above.

The retained standalone source references do not establish complete
Corresponding Source for its Python runtime, native wheel libraries, and
JavaScript build inputs. Anyone distributing that separate standalone-based
package must satisfy its applicable GPLv3 source and notice requirements.
The new public profile does not turn those incomplete references into a new
source offer or relicense the standalone executable. See its
[dependency provenance](../vendor/yt-dlp/PROVENANCE.md).

The complete original [yt-dlp LICENSE](../vendor/yt-dlp/LICENSE),
[aggregate notices](../vendor/yt-dlp/THIRD_PARTY_LICENSES.txt), and
[upstream metadata](../vendor/yt-dlp/sources/build-metadata/pyproject.toml)
remain unchanged. Aggregate notices cover multiple upstream configurations;
they are not the exact inventory of the new public profile.

FFmpeg, Apple models, user media, online videos and captions, credentials, and
local caches are not included in these dependency materials.
