# yt-dlp dependency provenance

AxonTube uses yt-dlp for user-initiated caption metadata and subtitle retrieval.
It runs as a separate command-line process. The executable and large source
archives are excluded from the source repository; notices, verification data,
build metadata, and source-download manifests are retained here.

## Pinned upstream artifact

- Project: <https://github.com/yt-dlp/yt-dlp>
- Version: **2026.06.09**
- Upstream asset: `yt-dlp_macos`
- Local filename: `yt-dlp`
- Size: **36,478,448 bytes**
- Architectures: **arm64 and x86_64**
- SHA-256:
  `b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244`
- Release: <https://github.com/yt-dlp/yt-dlp/releases/tag/2026.06.09>
- Download: <https://github.com/yt-dlp/yt-dlp/releases/download/2026.06.09/yt-dlp_macos>

[`prepare-ytdlp.sh`](../../scripts/prepare-ytdlp.sh) retrieves this named
upstream asset and checks the expected SHA-256. It renames the file locally
and sets executable permission without modifying its contents. The helper's
macOS 10.15+ requirement is separate from AxonTube's platform requirements.
The download does not install the helper globally or execute source build hooks.

During the earlier local preparation on 2026-10-02, the size and hash matched
the upstream release digest and `SHA2-256SUMS`; the executable's version command
reported `2026.06.09`. No independent GPG signature verification was performed.
A new application package must verify the copied helper again rather than
assuming that an earlier check certifies its bytes.

`SHA2-256SUMS` preserves the upstream asset names. `SHA256SUMS` records a prior
local dependency-material inventory and can mention archives not tracked in
this source checkout; its presence does not imply those archives are included.

## License boundary

The [pinned upstream README](https://github.com/yt-dlp/yt-dlp/blob/2026.06.09/README.md#licensing)
distinguishes the Unlicense-covered yt-dlp source from its PyInstaller
executables. The complete macOS standalone executable includes third-party
components and is licensed as **GPLv3-or-later**.

Preserve the complete, original files:

- [`LICENSE`](LICENSE): the upstream yt-dlp Unlicense text.
- [`THIRD_PARTY_LICENSES.txt`](THIRD_PARTY_LICENSES.txt): aggregated third-party
  notices and license terms, including GPLv3 and other component terms.
- The source-access information and provenance accompanying the dependency.

Do not replace upstream copyright notices with the application maintainer's
name or describe the complete executable as public domain. The aggregate
notice covers multiple upstream platforms; it is not an independently verified
inventory of exactly which libraries are present in this macOS binary. Some
original notice bytes are not UTF-8. Copying must preserve them without
lossy decoding or normalization.

The upstream source-access statement is retained unchanged in the notice,
with matching maintainer information in
[`sources/build-metadata/pyproject.toml`](sources/build-metadata/pyproject.toml).
This document does not create a new source offer on another party's behalf.

## Source references and retained metadata

1. [Official source archive](https://github.com/yt-dlp/yt-dlp/releases/download/2026.06.09/yt-dlp.tar.gz):
   5,980,415 bytes; SHA-256
   `7603f876b78d08b5fdd5bcd1d368590fde22c3c18e4ea00766d51120d21cc679`.
   This is yt-dlp's source, not the source of every bundled third-party component.
2. [Complete tag archive](https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2026.06.09.tar.gz):
   upstream workflows, PyInstaller packaging code, requirements, and `uv.lock`.
3. [`sources/build-metadata/`](sources/build-metadata/): selected upstream files
   retained for inspection, including the workflow, bundling script, macOS
   requirements, project metadata, and dependency lockfile.
4. [`sources/PINNED_SDISTS.json`](sources/PINNED_SDISTS.json) and
   [`sources/SDIST_DOWNLOAD.curl`](sources/SDIST_DOWNLOAD.curl): pinned URLs,
   versions, sizes, and hashes for 29 Python source distributions selected from
   those requirements and the lockfile. The prior local download totaled
   29,499,783 bytes and was checked against the recorded sizes and hashes.

Large archives are not tracked in Git. The 29-package set includes runtime and
build tooling, as well as conditional packages; it does not assert that all
29 packages are loaded by AxonTube. Their source build hooks need not be run
to build the Swift application.

## Corresponding-source limitation

These notices and references aid inspection but do **not** establish a complete
Corresponding Source bundle for every embedded native library. Python's native
runtime, native libraries embedded in third-party wheels, and transitive source
and build inputs of the JavaScript solver have not all been reconstructed or
audited here. The Python source-distribution set alone does not resolve this.

For public binary redistribution, provide complete corresponding source and
required notices using an applicable GPLv3 section 6 method. A matching,
verified source bundle alongside the app/helper download is one possible
approach. Section 6(d) also permits an appropriately maintained third-party
source location with clear directions beside the binary; linking to a generic
homepage is not a completeness check.

A local build is not evidence that a future binary release meets these
requirements. See [source and dependency access](../../docs/SOURCE-ACCESS.md).
Keeping the helper as a separate command-line process does not relicense it
under the application's MIT License.

## Packaging and updates

When packaging the helper, retain its original bytes, required notices, and
source-access information. Check its SHA-256 after copying it into the app.
Signing the outer app should not rewrite the helper executable.

Updates are deliberate: choose a named release, review its notices and source
inputs, update the expected hash, and test caption retrieval. Do not enable
implicit automatic updates, configuration discovery, or browser-cookie import.

No JavaScript runtime or FFmpeg binary is supplied by this dependency
preparation. Upstream identifies a supported JavaScript runtime as necessary
for full YouTube support. Successful subtitle retrieval for one video is not
a promise that every video works or that website behavior will remain stable.
