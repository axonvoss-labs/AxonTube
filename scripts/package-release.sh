#!/bin/bash
# Archive an already prepared app; never download, sign with a certificate, or publish.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_DIR=""
OUTPUT_DIR=""
HELPER_DIR=""
usage() {
  cat <<'EOF'
Usage: bash scripts/package-release.sh --app AxonTube.app
       --helper-dir PREPARED_PROFILE [--output-dir NEW_DIRECTORY]

Produces AxonTube-VERSION-macos-arm64.zip, .dmg, a dependency-materials.tar.gz
companion containing source materials and licenses, and SHA256SUMS.txt.
The output directory must be new. SOURCE_DATE_EPOCH controls ZIP timestamps.
Only an app with a prepared release-helper profile is accepted for release.
EOF
}
fail() { printf '%s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app|--output-dir|--helper-dir)
      [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1"
      case "$1" in
        --app) APP_DIR="$2" ;;
        --output-dir) OUTPUT_DIR="$2" ;;
        --helper-dir) HELPER_DIR="$2" ;;
      esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
done
[[ -n "$APP_DIR" && -d "$APP_DIR" ]] || fail 'Pass a prepared app with --app.'
APP_DIR="$(cd "$APP_DIR" && pwd)"
[[ -n "$HELPER_DIR" && -d "$HELPER_DIR" ]] || fail 'Pass the matching prepared helper profile with --helper-dir.'
HELPER_DIR="$(cd "$HELPER_DIR" && pwd)"
bash "$PROJECT_DIR/scripts/package.sh" --verify-helper "$HELPER_DIR"
bash "$PROJECT_DIR/scripts/package.sh" --verify-app "$APP_DIR"
cmp -s "$HELPER_DIR/MANIFEST.json" "$APP_DIR/Contents/Resources/Licenses/release-helper/MANIFEST.json" || fail 'App and dependency profile manifests differ.'
python3 - "$APP_DIR/Contents/Resources/Licenses/release-helper/MANIFEST.json" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
if manifest.get("profile") == "standalone-local-review":
    raise SystemExit("The legacy standalone helper is for local review only; prepare a release helper profile first.")
if not any(item["path"].startswith("SOURCES/") for item in manifest["files"]):
    raise SystemExit("Release helper manifest must include its source materials.")
PY
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Unexpected release version.'
mkdir -p "$PROJECT_DIR/dist" "$PROJECT_DIR/.build"
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(mktemp -d "$PROJECT_DIR/dist/$VERSION-release.XXXXXX")"
else
  [[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] || fail 'Output directory already exists; choose a new directory.'
  mkdir -p "$(dirname "$OUTPUT_DIR")"
  mkdir "$OUTPUT_DIR"
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
fi
WORK_DIR="$(mktemp -d "$PROJECT_DIR/.build/release-archive.XXXXXX")"
ASSET_NAME="AxonTube-$VERSION-macos-arm64"
SOURCE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || printf '0')}"
python3 - "$HELPER_DIR" "$OUTPUT_DIR/AxonTube-$VERSION-dependency-materials.tar.gz" "$SOURCE_EPOCH" "$VERSION" <<'PY'
import gzip, pathlib, sys, tarfile
profile, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
epoch = int(sys.argv[3] or "0")
prefix = "AxonTube-" + sys.argv[4] + "-dependency-materials"
def clean_metadata(entry):
    entry.uid = entry.gid = 0
    entry.uname = entry.gname = ""
    entry.mtime = epoch
    entry.pax_headers = {}
    return entry
with output.open("xb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=epoch) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
            for name in ("LICENSES", "MANIFEST.json", "SOURCES"):
                archive.add(profile / name, arcname=prefix + "/" + name, filter=clean_metadata)
with tarfile.open(output, "r:gz") as archive:
    for entry in archive:
        if entry.uid or entry.gid or entry.uname or entry.gname or entry.name.startswith("/") or ".." in pathlib.PurePosixPath(entry.name).parts:
            raise SystemExit("Unexpected dependency archive metadata")
print("Dependency materials and archive metadata verified")
PY
python3 - "$APP_DIR" "$OUTPUT_DIR/$ASSET_NAME.zip" "$SOURCE_EPOCH" <<'PY'
import datetime, pathlib, stat, sys, zipfile
app, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
epoch = max(315532800, int(sys.argv[3] or "0"))
timestamp = datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc)
date_time = (timestamp.year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute, timestamp.second)
with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in [app, *sorted(app.rglob("*"))]:
        mode = path.lstat().st_mode
        name = path.relative_to(app.parent).as_posix()
        directory = stat.S_ISDIR(mode)
        entry = zipfile.ZipInfo(name + ("/" if directory else ""), date_time)
        entry.create_system = 3
        entry.external_attr = mode << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        if directory:
            entry.external_attr |= 0x10
            data = b""
        elif path.is_symlink():
            data = str(path.readlink()).encode()
        else:
            data = path.read_bytes()
        archive.writestr(entry, data)
with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise SystemExit("ZIP integrity check failed")
    if any(item.extra for item in archive.infolist()):
        raise SystemExit("Unexpected ZIP metadata")
print("ZIP CRC and metadata checks passed")
PY
mkdir "$WORK_DIR/extracted" "$WORK_DIR/dmg"
ditto --norsrc --noextattr --noqtn --noacl -x -k "$OUTPUT_DIR/$ASSET_NAME.zip" "$WORK_DIR/extracted"
bash "$PROJECT_DIR/scripts/package.sh" --verify-app "$WORK_DIR/extracted/AxonTube.app"
ditto --norsrc --noextattr --noqtn --noacl "$APP_DIR" "$WORK_DIR/dmg/AxonTube.app"
ln -s /Applications "$WORK_DIR/dmg/Applications"
hdiutil create -volname "AxonTube $VERSION" -srcfolder "$WORK_DIR/dmg" \
  -fs HFS+ -format UDZO -nospotlight -anyowners -srcowners off \
  "$OUTPUT_DIR/$ASSET_NAME.dmg"
hdiutil verify "$OUTPUT_DIR/$ASSET_NAME.dmg"
python3 - "$OUTPUT_DIR" <<'PY'
import hashlib, pathlib, sys
output = pathlib.Path(sys.argv[1])
with (output / "SHA256SUMS.txt").open("x") as handle:
    for path in sorted(output.iterdir()):
        if path.suffix in (".zip", ".dmg") or path.name.endswith("-dependency-materials.tar.gz"):
            handle.write(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name + "\n")
PY
printf 'Release archives: %s\n' "$OUTPUT_DIR"
