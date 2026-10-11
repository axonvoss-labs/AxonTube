#!/usr/bin/env python3
"""Prepare the pinned, self-contained arm64 caption helper for public releases.

Downloads require --download. Existing output directories are never replaced.
The final manifest covers every file and symlink other than the manifest itself.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import stat
import subprocess
import tarfile
import tempfile
import urllib.parse
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "vendor" / "release-helper"
MACHO_MAGIC = {b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
               b"\xfe\xed\xfa\xce", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"}
LAUNCHER = '''#!/bin/sh
# AxonTube's private, pinned helper. No system Python or first-run installation.
set -eu
helper_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export SSL_CERT_FILE="$helper_dir/cacert.pem"
exec "$helper_dir/runtime/bin/python3.13" -I -B "$helper_dir/yt-dlp.pyz" \\
  --ignore-config --no-plugin-dirs --no-update --no-js-runtimes \\
  --js-runtimes "quickjs:$helper_dir/qjs" --no-remote-components "$@"
'''


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def validate_input(path, item):
    if not path.is_file() or path.is_symlink():
        raise ValueError("Missing regular input file: " + item["filename"])
    if path.stat().st_size != item["size"] or digest(path) != item["sha256"]:
        raise ValueError("Input size or SHA-256 mismatch: " + item["filename"])


def obtain_input(item, cache, allow_download):
    path = cache / item["filename"]
    if not path.exists():
        if not allow_download:
            raise ValueError("Missing " + item["filename"] + "; use --download explicitly")
        url = urllib.parse.urlsplit(item["url"])
        if url.scheme != "https" or url.netloc not in {
                "github.com", "files.pythonhosted.org", "bellard.org", "registry.npmjs.org"}:
            raise ValueError("Unexpected upstream download origin")
        pending = path.with_name(path.name + ".download")
        if pending.exists():
            raise ValueError("An incomplete download already exists: " + pending.name)
        run(["/usr/bin/curl", "--fail", "--location", "--proto", "=https",
             "--proto-redir", "=https", "--connect-timeout", "30", "--max-time", "600",
             "--output", pending, item["url"]])
        validate_input(pending, item)
        pending.rename(path)
    validate_input(path, item)
    return path


def safe_relative(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        raise ValueError("Unsafe archive path")
    return path


def extract_tar(archive, destination, include=lambda name: True):
    """Extract checked members without ownership restoration or link traversal."""
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as source:
        members = []
        for member in source:
            relative = safe_relative(member.name)
            if not include(str(relative)):
                continue
            if not (member.isfile() or member.isdir() or member.issym()):
                raise ValueError("Unsupported archive entry type: " + member.name)
            if member.issym():
                safe_relative(member.linkname)
                target = (destination / relative.parent / member.linkname).resolve()
                if destination.resolve() not in target.parents:
                    raise ValueError("Archive symlink escapes extraction root")
            members.append((member, relative))
        # Reject members below symlinks, independently of archive member order.
        links = {relative for member, relative in members if member.issym()}
        for _, relative in members:
            if any(parent in links for parent in relative.parents):
                raise ValueError("Archive path traverses a symlink")
        for member, relative in members:
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if member.isdir():
                target.mkdir(exist_ok=True)
            elif member.issym():
                target.symlink_to(member.linkname)
            else:
                with source.extractfile(member) as src, target.open("xb") as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(0o755 if member.mode & 0o111 else 0o644)


def copy_license(source, destination):
    if not source.is_file():
        raise ValueError("Required upstream license is missing: " + source.name)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    destination.chmod(0o644)


def runtime_member(name):
    # Keep the interpreter and standard library, not pip/ensurepip, Tk, tests,
    # development headers, static archives, manpages, or command-line tools.
    if name in ("python/bin/python3.13", "python/bin/python", "python/bin/python3",
                "python/lib/libpython3.13.dylib"):
        return True
    prefix = "python/lib/python3.13/"
    if not name.startswith(prefix):
        return False
    relative = PurePosixPath(name[len(prefix):])
    if not relative.parts:
        return True
    if relative.parts[0] in {"site-packages", "ensurepip", "idlelib", "tkinter", "turtledemo",
                              "test", "config-3.13-darwin"}:
        return False
    return "__pycache__" not in relative.parts and not relative.name.startswith("_tkinter.")


def extract_python_licenses(archive, scratch, licenses):
    destination = scratch / "python-metadata"
    destination.mkdir()
    # The exact archive is pinned and verified before invoking macOS libarchive.
    # Only these fixed, non-executable upstream metadata paths are extracted.
    run(["/usr/bin/tar", "-xf", archive, "-C", destination,
         "python/PYTHON.json", "python/licenses"])
    metadata_path = destination / "python" / "PYTHON.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if (metadata["python_version"] != "3.13.16"
            or metadata["target_triple"] != "aarch64-apple-darwin"):
        raise ValueError("Wrong Python metadata version or target")
    extensions = metadata["build_info"]["extensions"]
    if "_gdbm" in extensions:
        raise ValueError("GPL GDBM must not be present in the release runtime")
    readline = extensions.get("readline", [])
    if not readline or not all("BSD-3-Clause" in item.get("licenses", []) for item in readline):
        raise ValueError("Expected BSD libedit-backed readline")
    inventory = {"python": metadata["licenses"], "extensions": {}}
    for name, variants in sorted(extensions.items()):
        if name == "_tkinter":
            continue
        declared = sorted({license_id for item in variants for license_id in item.get("licenses", [])})
        if any("GPL" in license_id for license_id in declared):
            raise ValueError("Unexpected copyleft native runtime component: " + name)
        if declared:
            inventory["extensions"][name] = declared
    target = licenses / "python"
    target.mkdir(parents=True)
    for path in sorted((destination / "python" / "licenses").iterdir()):
        copy_license(path, target / path.name)
    copy_license(metadata_path, target / "PYTHON.json")
    write_json(target / "RUNTIME-LICENSE-INVENTORY.json", inventory)
    return inventory


def inventory_files(root):
    result = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if relative == "MANIFEST.json":
            continue
        mode = format(stat.S_IMODE(path.lstat().st_mode), "04o")
        if path.is_symlink():
            target = os.readlink(path)
            if root.resolve() not in path.resolve().parents or not path.resolve().is_file():
                raise ValueError("Broken or escaping profile symlink: " + relative)
            result.append({"path": relative, "type": "symlink", "target": target, "mode": mode})
        elif path.is_file():
            result.append({"path": relative, "type": "file", "sha256": digest(path),
                           "size": path.stat().st_size, "mode": mode})
        elif not path.is_dir():
            raise ValueError("Unexpected profile object: " + relative)
    return result


def native_audit(helpers):
    native = []
    helpers = helpers.resolve()

    def commands(path):
        text = run(["/usr/bin/otool", "-l", path], capture_output=True, text=True).stdout
        runpaths, minimum, command = [], None, None
        for line in text.splitlines():
            words = line.strip().split()
            if len(words) == 2 and words[0] == "cmd":
                command = words[1]
            elif command == "LC_RPATH" and words and words[0] == "path":
                runpaths.append(line.strip()[5:].split(" (offset ", 1)[0])
            elif command == "LC_BUILD_VERSION" and len(words) == 2 and words[0] == "minos":
                minimum = words[1]
            elif command == "LC_VERSION_MIN_MACOSX" and len(words) == 2 and words[0] == "version":
                minimum = words[1]
        return runpaths, minimum

    def expand(value, image, executable):
        if value.startswith("@loader_path/"):
            return (image.parent / value[len("@loader_path/"):]).resolve()
        if value.startswith("@executable_path/"):
            return (executable.parent / value[len("@executable_path/"):]).resolve()
        if value.startswith(("/usr/lib/", "/System/Library/")):
            return Path(value)
        raise ValueError("Unsupported or external native search path")

    def inside_or_system(path, must_exist=True):
        if str(path).startswith(("/usr/lib/", "/System/Library/")):
            # Modern macOS can supply these from the dyld shared cache.
            return True
        return helpers in path.parents and (not must_exist or path.is_file())

    python = helpers / "runtime/bin/python3.13"
    python_runpaths, _ = commands(python)
    for path in sorted(helpers.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open("rb") as source:
            if source.read(4) not in MACHO_MAGIC:
                continue
        relative = path.relative_to(helpers).as_posix()
        architecture = run(["/usr/bin/lipo", "-archs", path], capture_output=True, text=True).stdout.strip()
        if architecture != "arm64":
            raise ValueError("Unexpected native architecture: " + relative)
        runpaths, minimum = commands(path)
        if not minimum or tuple(map(int, minimum.split(".")[:2])) > (14, 0):
            raise ValueError("Native dependency exceeds the app's macOS 14 target: " + relative)
        executable = helpers / "qjs" if relative == "qjs" else python
        searches = [expand(value, path, executable) for value in runpaths]
        if executable == python:
            searches += [expand(value, python, python) for value in python_runpaths]
        if any(not inside_or_system(item, must_exist=False) for item in searches):
            raise ValueError("Native runpath escapes the helper: " + relative)
        linked = run(["/usr/bin/otool", "-L", path], capture_output=True, text=True).stdout.splitlines()[1:]
        dependencies = [line.strip().split(" (", 1)[0] for line in linked]
        own_ids = run(["/usr/bin/otool", "-D", path], capture_output=True, text=True).stdout.splitlines()[1:]
        dependencies = [value for value in dependencies if value not in own_ids]
        for dependency in dependencies:
            if dependency.startswith("@rpath/"):
                candidates = [(base / dependency[len("@rpath/"):]).resolve() for base in searches]
            else:
                candidates = [expand(dependency, path, executable)]
            if not any(inside_or_system(candidate) for candidate in candidates):
                raise ValueError("Unresolved or external native dependency: " + relative + ": " + dependency)
        signature = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(path)],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if signature.returncode:
            run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", path],
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        run(["/usr/bin/codesign", "--verify", "--strict", path],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        native.append({"path": relative, "architecture": architecture, "minimum_macos": minimum,
                       "dependencies": dependencies, "runpaths": runpaths})
    return native


def smoke_test(helpers):
    version = run([helpers / "yt-dlp", "--version"], capture_output=True, text=True).stdout.strip()
    if version != "2026.06.09":
        raise ValueError("Wrong helper version")
    result = run([helpers / "qjs", "-e", "console.log([1,2,3].map(x=>x*2).join(','))"],
                 capture_output=True, text=True).stdout.strip()
    if result != "2,4,6":
        raise ValueError("QuickJS execution failed")
    code = """import importlib.util,json,os,ssl,sys
sys.path.insert(0,sys.argv[1])
import yt_dlp,yt_dlp_ejs
from yt_dlp_ejs._version import __version__ as ejs_version
assert importlib.util.find_spec('_gdbm') is None
assert importlib.util.find_spec('pip') is None
assert sys.flags.isolated and sys.dont_write_bytecode
ctx=ssl.create_default_context()
assert ctx.cert_store_stats()['x509_ca'] > 100
opts=yt_dlp.parse_options(['--ignore-config','--no-plugin-dirs','--no-cache-dir',
 '--no-js-runtimes','--js-runtimes','quickjs:'+sys.argv[2],
 '--skip-download','--write-auto-subs','--sub-format','vtt','--sub-langs','^en$',
 '--paths','caption test','--output','caption.%(ext)s','--simulate'])
assert opts.ydl_opts['js_runtimes']['quickjs']['path'] == sys.argv[2]
print(json.dumps({'python':sys.version.split()[0],'openssl':ssl.OPENSSL_VERSION,
 'ca_count':ctx.cert_store_stats()['x509_ca'],'ejs':ejs_version}))
"""
    environment = dict(os.environ, SSL_CERT_FILE=str(helpers / "cacert.pem"))
    result = run([helpers / "runtime/bin/python3.13", "-I", "-B", "-c", code,
                  helpers / "yt-dlp.pyz", helpers / "qjs"], env=environment,
                 capture_output=True, text=True)
    return json.loads(result.stdout)


def prepare(args):
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("This release profile must be prepared on arm64 macOS")
    pins = json.loads((PROFILE / "INPUTS.json").read_text(encoding="utf-8"))
    output = Path(args.output).resolve()
    cache = Path(args.cache).resolve()
    if output.exists():
        raise ValueError("Output exists; choose a new destination instead of overwriting it")
    cache.mkdir(parents=True, exist_ok=True)
    inputs = {item["id"]: obtain_input(item, cache, args.download) for item in pins["inputs"]}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir()
    helpers, licenses, sources = (output / name for name in ("Helpers", "LICENSES", "SOURCES"))
    for directory in (helpers, licenses, sources):
        directory.mkdir()
    with tempfile.TemporaryDirectory(prefix="axontube-helper-build-", dir=output.parent) as temp:
        scratch = Path(temp)
        runtime_tmp = scratch / "runtime"
        extract_tar(inputs["python-runtime"], runtime_tmp, runtime_member)
        shutil.move(str(runtime_tmp / "python"), helpers / "runtime")
        runtime_licenses = extract_python_licenses(inputs["python-metadata"], scratch, licenses)
        extracted = {}
        for key in ("yt-dlp-source", "quickjs-source", "certifi-source", "ejs-source",
                    "astring-source", "meriyah-source"):
            destination = scratch / key
            extract_tar(inputs[key], destination)
            entries = list(destination.iterdir())
            if len(entries) != 1 or not entries[0].is_dir():
                raise ValueError("Expected one archive root: " + key)
            extracted[key] = entries[0]
        qjs_source = extracted["quickjs-source"]
        compiler_flags = "-ffile-prefix-map=" + str(scratch) + "=. -fdebug-prefix-map=" + str(scratch) + "=."
        environment = dict(os.environ, MACOSX_DEPLOYMENT_TARGET="13.0", CFLAGS=compiler_flags)
        run(["/usr/bin/make", "-j2", "qjs", "CC=/usr/bin/clang"], cwd=qjs_source, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        shutil.copyfile(qjs_source / "qjs", helpers / "qjs")
        (helpers / "qjs").chmod(0o755)
        run(["/usr/bin/strip", "-S", "-x", helpers / "qjs"])
        run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", helpers / "qjs"],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        shutil.copyfile(inputs["yt-dlp-zip"], helpers / "yt-dlp.pyz")
        shutil.copyfile(extracted["certifi-source"] / "certifi/cacert.pem", helpers / "cacert.pem")
        (helpers / "yt-dlp").write_text(LAUNCHER, encoding="utf-8")
        (helpers / "yt-dlp").chmod(0o755)
        for key, subdir, filename in (("yt-dlp-source", "yt-dlp", "LICENSE"),
                                      ("quickjs-source", "quickjs", "LICENSE"),
                                      ("certifi-source", "certifi", "LICENSE"),
                                      ("ejs-source", "ejs", "LICENSE"),
                                      ("astring-source", "astring", "LICENSE"),
                                      ("meriyah-source", "meriyah", "LICENSE.md")):
            copy_license(extracted[key] / filename, licenses / subdir / filename)
        with zipfile.ZipFile(inputs["yt-dlp-zip"]) as archive:
            js = archive.read("yt_dlp_ejs/yt/solver/lib.min.js")
            notice = js.split(b"*/", 1)[0] + b"*/\n"
            (licenses / "ejs" / "BUNDLED-JAVASCRIPT-NOTICES.txt").write_bytes(notice)
        copy_license(PROFILE / "NOTICE.md", licenses / "NOTICE.md")
        for item in pins["inputs"]:
            if item["kind"] == "source":
                shutil.copyfile(inputs[item["id"]], sources / item["filename"])
        shutil.copyfile(PROFILE / "INPUTS.json", sources / "INPUTS.json")
        shutil.copyfile(PROFILE / "README.md", sources / "README.md")
        shutil.copyfile(PROFILE / "NOTICE.md", sources / "NOTICE.md")
        shutil.copyfile(Path(__file__), sources / "prepare-release-helper.py")
        native = native_audit(helpers)
        # Do not publish a local username or path introduced by this build.
        private_markers = [str(Path.home()).encode(), str(ROOT).encode()]
        for path in helpers.rglob("*"):
            if path.is_file() and not path.is_symlink():
                data = path.read_bytes()
                if any(marker in data for marker in private_markers):
                    raise ValueError("Private build path found in a helper file")
        before = inventory_files(output)
        smoke = smoke_test(helpers)
        if before != inventory_files(output):
            raise ValueError("Executing the helper mutated the prepared bundle")
        manifest = {"schema_version": 1, "profile": "axontube-arm64-helper-v1",
                    "target": "arm64-apple-macos", "components": pins["components"],
                    "inputs": pins["inputs"], "runtime_licenses": runtime_licenses,
                    "native_files": native, "offline_smoke_test": smoke, "files": before}
        write_json(output / "MANIFEST.json", manifest)
    print("Prepared " + str(output))
    print("Manifest covers " + str(len(manifest["files"])) + " files and symlinks")
    print(json.dumps(smoke, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="new output profile directory")
    parser.add_argument("--cache", default=str(ROOT / "dist" / "release-helper-downloads"))
    parser.add_argument("--download", action="store_true", help="explicitly allow pinned upstream downloads")
    args = parser.parse_args()
    try:
        prepare(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        detail = str(error)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            detail += "\n" + (error.stderr.decode(errors="replace")
                               if isinstance(error.stderr, bytes) else error.stderr)
        detail = detail.replace(str(ROOT), "<project>").replace(str(Path.home()), "<home>")
        parser.exit(1, "Preparation failed: " + detail + "\n")


if __name__ == "__main__":
    main()
