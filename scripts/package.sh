#!/bin/bash
# Local, ad-hoc signed packaging. Dependency preparation is a separate action.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

usage() {
  cat <<'EOF'
Usage: bash scripts/package.sh [--skip-build] [--output-dir NEW_DIRECTORY]
                               [--helper-dir PREPARED_PROFILE]
       bash scripts/package.sh --verify-app AxonTube.app
       bash scripts/package.sh --verify-helper PREPARED_PROFILE

Creates a new arm64 app bundle without replacing earlier packages. A prepared
helper profile contains Helpers/, LICENSES/, SOURCES/, and MANIFEST.json.
Without --helper-dir, the pinned standalone helper is used for local review.
No dependencies are downloaded and no Developer ID certificate is used.
EOF
}
fail() { printf '%s\n' "$*" >&2; exit 1; }

verify_helper_manifest() {
  python3 - "$1" "$2" "$3" <<'PY'
import hashlib, json, pathlib, stat, sys
manifest_path, destination, scope = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
manifest = json.loads(manifest_path.read_text())
app_roots = {
    "Helpers": "Contents/Helpers" if manifest.get("profile") == "standalone-local-review" else "Contents/Resources/release-helper",
    "LICENSES": "Contents/Resources/Licenses/release-helper",
}
if scope == "app" and manifest.get("profile") != "standalone-local-review":
    helper_link = destination / "Contents/Helpers"
    if not helper_link.is_symlink() or helper_link.readlink().as_posix() != "Resources/release-helper":
        raise SystemExit("Release helper entry point must use the expected internal directory link")
entries = manifest.get("files")
if not isinstance(entries, list) or not entries:
    raise SystemExit("Helper manifest has no file entries")
seen = set()
bundle_root = destination.resolve()
for root in ("Helpers", "LICENSES", "SOURCES"):
    if scope == "app":
        if root == "SOURCES":
            continue
        folder = destination / app_roots[root]
    else:
        folder = destination / root
    if folder.is_symlink() or not folder.is_dir() or not folder.resolve().is_relative_to(bundle_root):
        raise SystemExit("Helper roots must be real directories inside the bundle")
for item in entries:
    relative = pathlib.PurePosixPath(item["path"])
    if relative.is_absolute() or ".." in relative.parts or not relative.parts:
        raise SystemExit("Unsafe helper manifest path")
    name = relative.as_posix()
    if name in seen:
        raise SystemExit("Duplicate helper manifest path")
    seen.add(name)
    if relative.parts[0] not in ("Helpers", "LICENSES", "SOURCES"):
        raise SystemExit("Unexpected helper manifest root")
    if scope == "app":
        if relative.parts[0] == "SOURCES":
            continue
        prefix = app_roots[relative.parts[0]]
        path = destination / prefix / pathlib.Path(*relative.parts[1:])
    else:
        path = destination / relative
    if not path.resolve(strict=True).is_relative_to(bundle_root):
        raise SystemExit("Helper entry escapes its bundle: " + name)
    if item["type"] == "symlink":
        if not path.is_symlink() or path.readlink().as_posix() != item["target"]:
            raise SystemExit("Helper symlink mismatch: " + name)
        if scope == "profile" and relative.parts[0] in ("LICENSES", "SOURCES"):
            resolved_root = path.resolve().relative_to(bundle_root).parts[0]
            if resolved_root not in ("LICENSES", "SOURCES"):
                raise SystemExit("Source material symlink points outside the companion archive: " + name)
    elif item["type"] == "file":
        if path.is_symlink() or not path.is_file():
            raise SystemExit("Missing helper file: " + name)
        if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
            raise SystemExit("Helper checksum mismatch: " + name)
    else:
        raise SystemExit("Unknown helper manifest entry type")
    if "mode" in item and item["type"] == "file":
        mode = item["mode"]
        mode = int(mode, 8) if isinstance(mode, str) else mode
        if stat.S_IMODE(path.stat().st_mode) != mode:
            raise SystemExit("Helper permission mismatch: " + name)
for root in ("Helpers", "LICENSES", "SOURCES"):
    if scope == "app":
        if root == "SOURCES":
            continue
        folder = destination / app_roots[root]
    else:
        folder = destination / root
    for path in folder.rglob("*"):
        if path.is_file() or path.is_symlink():
            relative = root + "/" + path.relative_to(folder).as_posix()
            if scope == "app" and relative == "LICENSES/MANIFEST.json":
                continue
            if relative not in seen:
                raise SystemExit("Unlisted helper file: " + relative)
print("Helper manifest verified (" + scope + ")")
PY
}

verify_app() {
  local app="$1"
  [[ -d "$app" ]] || fail 'App bundle is missing.'
  [[ "$(lipo -archs "$app/Contents/MacOS/AxonTube")" == arm64 ]] || fail 'Expected an arm64 app executable.'
  [[ -s "$app/Contents/Resources/PlayerIcon.icns" ]] || fail 'App icon is missing.'
  [[ -x "$app/Contents/Helpers/yt-dlp" ]] || fail 'Subtitle helper is not executable.'
  verify_helper_manifest "$app/Contents/Resources/Licenses/release-helper/MANIFEST.json" "$app" app
  python3 - "$app" "$PROJECT_DIR" <<'PY'
import pathlib, plistlib, re, sys
app = pathlib.Path(sys.argv[1])
private_prefixes = [str(pathlib.Path(sys.argv[2]).resolve()).encode(), str(pathlib.Path.home()).encode()]
macho = {bytes.fromhex(value) for value in ("cffaedfe", "cefaedfe", "feedfacf", "feedface", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
with (app / "Contents/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
if info.get("CFBundleExecutable") != "AxonTube" or info.get("CFBundleIconFile") != "PlayerIcon":
    raise SystemExit("Unexpected app bundle metadata")
for path in app.rglob("*"):
    relative = path.relative_to(app)
    if any(part in (".DS_Store", ".git", "__MACOSX") or part.endswith(".dSYM") for part in relative.parts):
        raise SystemExit("Private build metadata found in app")
    if path.is_symlink():
        if not path.resolve().is_relative_to(app.resolve()):
            raise SystemExit("App symlink escapes the bundle")
        continue
    if not path.is_file():
        continue
    data = path.read_bytes()
    if any(prefix in data for prefix in private_prefixes):
        raise SystemExit("Local build path found in app: " + str(relative))
    if data[:4] in macho and re.search(rb"/(?:Users|home)/[^/\x00\s]+/", data):
        raise SystemExit("Personal build path found in Mach-O: " + str(relative))
print("App architecture, icon, and build-path checks passed")
PY
  codesign --verify --deep --strict "$app"
}

SKIP_BUILD=false
OUTPUT_DIR=""
HELPER_DIR=""
VERIFY_APP=""
VERIFY_HELPER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --output-dir|--helper-dir|--verify-app|--verify-helper)
      [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1"
      case "$1" in
        --output-dir) OUTPUT_DIR="$2" ;;
        --helper-dir) HELPER_DIR="$2" ;;
        --verify-app) VERIFY_APP="$2" ;;
        --verify-helper) VERIFY_HELPER="$2" ;;
      esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
done
if [[ -n "$VERIFY_APP" ]]; then
  [[ -z "$OUTPUT_DIR" && -z "$HELPER_DIR" && -z "$VERIFY_HELPER" && "$SKIP_BUILD" == false ]] || fail '--verify-app cannot be combined with other options.'
  verify_app "$VERIFY_APP"
  exit 0
fi
if [[ -n "$VERIFY_HELPER" ]]; then
  [[ -z "$OUTPUT_DIR" && -z "$HELPER_DIR" && "$SKIP_BUILD" == false ]] || fail '--verify-helper cannot be combined with build options.'
  verify_helper_manifest "$VERIFY_HELPER/MANIFEST.json" "$VERIFY_HELPER" profile
  exit 0
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)
if [[ -n "$HELPER_DIR" ]]; then
  HELPER_DIR="$(cd "$HELPER_DIR" && pwd)"
  verify_helper_manifest "$HELPER_DIR/MANIFEST.json" "$HELPER_DIR" profile
else
  HELPER="$PROJECT_DIR/vendor/yt-dlp/yt-dlp"
  [[ -x "$HELPER" ]] || fail 'Missing local-review helper. Prepare a helper profile or run scripts/prepare-ytdlp.sh explicitly.'
  LEGACY_SHA256='b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244'
  [[ "$(shasum -a 256 "$HELPER" | cut -d ' ' -f 1)" == "$LEGACY_SHA256" ]] || fail 'Local-review helper checksum mismatch.'
fi
mkdir -p "$PROJECT_DIR/dist" "$PROJECT_DIR/.build"
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(mktemp -d "$PROJECT_DIR/dist/$VERSION-package.XXXXXX")"
else
  [[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] || fail 'Output directory already exists; choose a new directory.'
  mkdir -p "$(dirname "$OUTPUT_DIR")"
  mkdir "$OUTPUT_DIR"
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
fi
WORK_DIR="$(mktemp -d "$PROJECT_DIR/.build/package.XXXXXX")"
APP_DIR="$OUTPUT_DIR/AxonTube.app"
if [[ "$SKIP_BUILD" == true ]]; then
  EXECUTABLE="$PROJECT_DIR/.build/release/AxonTube"
else
  swift build -c release --arch arm64 -debug-info-format none --scratch-path "$WORK_DIR/build" \
    --disable-automatic-resolution --disable-prefetching --disable-netrc --disable-keychain \
    -Xswiftc -debug-prefix-map -Xswiftc "$PROJECT_DIR=/build/axontube" \
    -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_DIR=/build/axontube" \
    -Xcc "-ffile-prefix-map=$PROJECT_DIR=/build/axontube" \
    -Xcc "-fdebug-prefix-map=$PROJECT_DIR=/build/axontube"
  EXECUTABLE="$WORK_DIR/build/arm64-apple-macosx/release/AxonTube"
fi
[[ -x "$EXECUTABLE" ]] || fail 'Release executable is missing.'
[[ "$(lipo -archs "$EXECUTABLE")" == arm64 ]] || fail 'Only arm64 release packaging is supported.'
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/Samples" "$APP_DIR/Contents/Resources/Licenses/release-helper"
cp -X "$EXECUTABLE" "$APP_DIR/Contents/MacOS/AxonTube"
# Strip only the staged first-party executable. Pinned helpers stay byte-for-byte intact.
strip -S "$APP_DIR/Contents/MacOS/AxonTube"
if [[ -n "$HELPER_DIR" ]]; then
  # Python modules and archives are resource files, not nested code bundles.
  # A directory link preserves the frozen launcher's relative paths unchanged.
  ditto --norsrc --noextattr --noqtn --noacl "$HELPER_DIR/Helpers" "$APP_DIR/Contents/Resources/release-helper"
  ln -s Resources/release-helper "$APP_DIR/Contents/Helpers"
  ditto --norsrc --noextattr --noqtn --noacl "$HELPER_DIR/LICENSES" "$APP_DIR/Contents/Resources/Licenses/release-helper"
  cp -X "$HELPER_DIR/MANIFEST.json" "$APP_DIR/Contents/Resources/Licenses/release-helper/MANIFEST.json"
else
  mkdir "$APP_DIR/Contents/Helpers"
  cp -X "$HELPER" "$APP_DIR/Contents/Helpers/yt-dlp"
  chmod 755 "$APP_DIR/Contents/Helpers/yt-dlp"
  mkdir -p "$APP_DIR/Contents/Resources/Licenses/yt-dlp/sources/build-metadata"
  cp -X vendor/yt-dlp/LICENSE vendor/yt-dlp/THIRD_PARTY_LICENSES.txt vendor/yt-dlp/PROVENANCE.md "$APP_DIR/Contents/Resources/Licenses/yt-dlp/"
  cp -X vendor/yt-dlp/sources/build-metadata/pyproject.toml "$APP_DIR/Contents/Resources/Licenses/yt-dlp/sources/build-metadata/"
  python3 - "$APP_DIR/Contents/Resources/Licenses/release-helper/MANIFEST.json" "$LEGACY_SHA256" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"profile": "standalone-local-review", "files": [{"path": "Helpers/yt-dlp", "type": "file", "sha256": sys.argv[2], "mode": "0755"}]}, indent=2) + "\n")
PY
fi
cp -X NOTICE.md docs/SOURCE-ACCESS.md LICENSE "$APP_DIR/Contents/Resources/Licenses/"
cp -X README.md README.zh-CN.md "$APP_DIR/Contents/Resources/"
cp -X Samples/* "$APP_DIR/Contents/Resources/Samples/"
cp -X scripts/Info.plist "$APP_DIR/Contents/Info.plist"
# Always derive the icon from its tracked original drawing, avoiding stale local assets.
xcrun swift scripts/make-icon.swift "$WORK_DIR/PlayerIcon.iconset"
iconutil -c icns "$WORK_DIR/PlayerIcon.iconset" -o "$APP_DIR/Contents/Resources/PlayerIcon.icns"
verify_helper_manifest "$APP_DIR/Contents/Resources/Licenses/release-helper/MANIFEST.json" "$APP_DIR" app
codesign --force --sign - --timestamp=none "$APP_DIR"
SOURCE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || printf '0')}"
python3 - "$APP_DIR" "$SOURCE_EPOCH" <<'PY'
import os, pathlib, sys
app, epoch = pathlib.Path(sys.argv[1]), int(sys.argv[2] or "0")
for path in [*app.rglob("*"), app]:
    os.utime(path, (epoch, epoch), follow_symlinks=False)
PY
verify_app "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
