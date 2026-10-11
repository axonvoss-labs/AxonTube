# Release helper notices

The public arm64 helper profile uses the official Unix zipimport build of
yt-dlp 2026.06.09, not its PyInstaller macOS standalone executable. The Unix
build contains yt-dlp and EJS under the Unlicense, astring 1.9.0 under MIT, and
meriyah 6.1.4 under ISC. Their original license texts and bundled JavaScript
notices are included here without replacing upstream copyright attribution.

QuickJS 2026-06-04 is built from the official source and distributed under MIT.
The private CPython 3.13.16 runtime comes from python-build-standalone release
20261009. Python, its native dependencies, and bundled standard-library code
retain their own notices in `python/`. `PYTHON.json` is the original upstream
metadata. `RUNTIME-LICENSE-INVENTORY.json` identifies declared licenses for the
selected runtime. Upstream's full license directory also includes supplemental
texts for configurations or modules not present in this profile; a license
file's presence alone does not mean that component is shipped.

The runtime does not contain GPL GDBM or GNU readline. Its readline interface
uses macOS libedit. Package installers, their vendored packages, Tk, tests,
headers, and other development tools are omitted. This profile is for the
application's helper, not a general-purpose Python installation.

`cacert.pem` is copied without modification from certifi 2026.5.20 and is
covered by MPL-2.0. The original license is in `certifi/LICENSE`. Its matching
source distribution is included in the release's dependency-materials archive
as `SOURCES/certifi-2026.5.20.tar.gz`, also available from the exact upstream
URL and SHA-256 in `SOURCES/INPUTS.json` and `MANIFEST.json`. The source and the
MPL rights remain available independently of the application's MIT license.

The dependency-materials archive also supplies the matching yt-dlp, EJS,
astring, meriyah, and QuickJS sources, the build recipe, the runtime license
metadata, and pinned download locations for the upstream Python binary inputs.
It is not described as a source rebuild of the entire Python distribution.
Python's applicable terms and notices are retained. This profile does not
include the GPL PyInstaller helper or make a GPL source offer for that separate
optional local-build artifact.

FFmpeg and Apple frameworks/models are not included in this helper profile.
macOS supplies its system libraries under their applicable terms.
