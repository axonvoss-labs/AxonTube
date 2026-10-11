# Source and dependency access

This repository provides the AxonTube application source, tests, build scripts,
and original documentation. The application source is available under the
[MIT License](../LICENSE). Third-party materials retain their own terms.

## Caption helper

YouTube caption retrieval uses the unmodified upstream macOS executable from
yt-dlp version **2026.06.09**. The executable is excluded from the source
repository. The explicit preparation script downloads it from the upstream
release and checks its SHA-256 before use:

```sh
bash scripts/prepare-ytdlp.sh
```

Expected SHA-256:

```text
b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244
```

The preparation script does not install the tool globally. Building or
packaging the application does not silently download dependencies. A local
application package includes the helper only after it has been prepared.

## Matching upstream sources

- [Pinned release and source archive](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.06.09)
- [Matching source repository](https://github.com/yt-dlp/yt-dlp/tree/2026.06.09)
- [Third-party notices and source-access information](https://github.com/yt-dlp/yt-dlp/blob/2026.06.09/THIRD_PARTY_LICENSES.txt)
- [Matching upstream project metadata](https://github.com/yt-dlp/yt-dlp/blob/2026.06.09/pyproject.toml)

Local notices, build metadata, and download manifests are retained under
[`vendor/yt-dlp/`](../vendor/yt-dlp/). Large executable and source archives are
excluded from Git. The retained materials identify upstream versions and
sources; they are not a certification that every embedded native dependency
can be rebuilt from this checkout.

The original upstream source-access statement remains in
[`THIRD_PARTY_LICENSES.txt`](../vendor/yt-dlp/THIRD_PARTY_LICENSES.txt), with
matching maintainer information in
[`pyproject.toml`](../vendor/yt-dlp/sources/build-metadata/pyproject.toml).
These upstream statements are preserved as received; this project does not
make a new offer on another party's behalf.

## Binary redistribution

A locally packaged application includes the standalone caption helper. Anyone
distributing that package must also satisfy the helper's applicable licensing
and corresponding-source requirements.

The source repository does not itself offer a complete Corresponding Source
bundle for every component of the upstream standalone executable. In particular,
Python's native runtime, native libraries embedded in third-party wheels, and
transitive JavaScript solver build inputs have not all been reconstructed here.
A generic upstream homepage link is not a substitute for checking completeness.

For public binary distribution, provide complete corresponding source and
required notices through an applicable GPLv3 section 6 method. A matching,
verified source bundle alongside the binary is one possible approach. See
[dependency provenance](../vendor/yt-dlp/PROVENANCE.md) for the exact artifact
and the limits of the retained source material.

Apple models, user media, online videos and captions, credentials, and local
caches are not included in the source distribution.
