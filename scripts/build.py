#!/usr/bin/env python3
"""Builds Rootward to play without Godot, for Linux and Windows, and its installers (ADR-0091).

    scripts/build.sh                  build everything into build/release/ (Linux host; about two minutes)
    scripts/build.sh --publish        then upload it as the GitHub release v<version>

build/stage/<os>/    the game as installed: Rootward(.x86_64|.exe), Rootward.pck, sandbox/, LICENSES/
build/release/       what the installer downloads, and the installers themselves:
  rootward-<v>-<os>-game.zip       the executable and the licences (small)
  rootward-<v>-<os>.pck            everything the game shows, plays and reads (one file, copied as it is)
  rootward-<v>-<os>-sandbox.zip    wasmtime and the three languages, compiled for that OS
  Rootward-Setup-<v>.exe, rootward-setup-<v>-linux.tar.gz
  rootward-manifest.json           every file with its size and SHA-256; the installer reads it first

Needs the game's media (scripts/fetch-media.sh), the sandbox (scripts/fetch-sandbox.sh, which also builds the C++
modules) and Godot 4.7.2; the export templates are downloaded once, checked against Godot's published SHA-512.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
INSTALLER = ROOT / "installer"
BUILD = ROOT / "build"
STAGE = BUILD / "stage"
RELEASE = BUILD / "release"
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or str(Path.home() / "godot")
GODOT_VERSION = "4.7.2"
TEMPLATES = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "godot" / "export_templates" / f"{GODOT_VERSION}.stable"
TEMPLATE_FILES = ("linux_debug.x86_64", "linux_release.x86_64", "windows_debug_x86_64.exe",
                  "windows_release_x86_64.exe", "windows_debug_x86_64_console.exe",
                  "windows_release_x86_64_console.exe", "version.txt")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "rootward" / "godot"
GODOT_RELEASES = f"https://github.com/godotengine/godot-builds/releases/download/{GODOT_VERSION}-stable"
PLATFORMS = {
    "linux": {"preset": "Linux", "exe": "Rootward.x86_64", "extra": []},
    "windows": {"preset": "Windows", "exe": "Rootward.exe", "extra": ["Rootward.console.exe"]},
}
EXECUTABLE = 0o100755 << 16
REGULAR = 0o100644 << 16


def sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def run(*args: str, cwd: Path = ROOT, quiet: bool = False) -> subprocess.CompletedProcess:
    result = subprocess.run(list(args), cwd=cwd, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if result.returncode != 0 or not quiet:
        out = (result.stdout + result.stderr).strip()
        if out and result.returncode != 0:
            print(out[-4000:])
    if result.returncode != 0:
        sys.exit(f"failed ({result.returncode}): {' '.join(args)}")
    return result


def version() -> str:
    for line in (GAME / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip('"')
    sys.exit("project.godot has no config/version")


def ensure_templates() -> None:
    if all((TEMPLATES / name).is_file() for name in TEMPLATE_FILES):
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    tpz = CACHE / f"Godot_v{GODOT_VERSION}-stable_export_templates.tpz"
    sums = CACHE / "SHA512-SUMS.txt"
    urllib.request.urlretrieve(f"{GODOT_RELEASES}/SHA512-SUMS.txt", sums)
    want = next(line.split()[0] for line in sums.read_text().splitlines() if line.endswith(f" {tpz.name}"))

    def digest() -> str:
        with tpz.open("rb") as handle:
            return hashlib.file_digest(handle, "sha512").hexdigest()

    if not tpz.is_file() or digest() != want:
        print(f"downloading Godot {GODOT_VERSION}'s export templates (1.3 GB, once)", flush=True)
        urllib.request.urlretrieve(f"{GODOT_RELEASES}/{tpz.name}", tpz)
        if digest() != want:
            sys.exit("the export templates do not match Godot's published SHA-512")
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(tpz) as archive:  # only what these two platforms need, not the 1.3 GB of every platform
        for name in TEMPLATE_FILES:
            target = TEMPLATES / name
            target.write_bytes(archive.read(f"templates/{name}"))
            target.chmod(0o755)
    print(f"export templates installed in {TEMPLATES}")


def check_inputs() -> None:
    media = run(sys.executable, str(ROOT / "scripts" / "media.py"), "status", quiet=True).stdout
    if any(line.strip().startswith("assets-") and "missing" in line for line in media.splitlines()):
        sys.exit("the game's media is not all here: run scripts/fetch-media.sh")
    runtime = GAME / "sandbox" / "runtime" / "cpp"
    for module in ("program", "spellforge"):
        stamp = runtime / f"{module}.stamp"
        built = runtime / "build" / module / "STAMP"
        if not stamp.is_file() or not built.is_file() or stamp.read_text() != built.read_text():
            sys.exit(f"the C++ {module} module is missing or stale: run scripts/build-cpp.sh")


def licences(into: Path) -> None:
    into.mkdir(parents=True, exist_ok=True)
    run(GODOT, "--headless", "--path", str(GAME), "-s", "res://tools/licenses.gd", "--", str(into / "godot-LICENSE.txt"),
        quiet=True)
    for font in sorted((GAME / "ui" / "fonts").glob("OFL-*.txt")):
        shutil.copyfile(font, into / f"font-{font.name}")
    shutil.copyfile(ROOT / "docs" / "ASSET_LICENCES.md", into / "ASSETS.md")


README = """Rootward {version}
==========

Start the game with {exe}. Saves and settings are kept in {saves}.

The sandbox/ folder beside the game runs the code your spells are made of (wasmtime, with Python, JavaScript and
C++ compiled to WebAssembly); the game needs it next to {exe}.

To check that everything works without playing: {selftest}
It runs every card's worked examples in each language and ends with OK or FAILED.

Licences of the engine, the sandbox, the fonts and the assets are in LICENSES/ and sandbox/LICENSES/.
"""


def stage(name: str, ver: str) -> Path:
    spec = PLATFORMS[name]
    out = STAGE / name
    if out.exists():
        for path in out.rglob("*"):
            if path.is_file():
                path.chmod(0o644)
        shutil.rmtree(out)
    out.mkdir(parents=True)
    print(f"{name}: exporting", flush=True)
    run(GODOT, "--headless", "--path", str(GAME), "--export-release", spec["preset"], str(out / spec["exe"]), quiet=True)
    for produced in [spec["exe"], "Rootward.pck", *spec["extra"]]:
        if not (out / produced).is_file():
            sys.exit(f"{name}: the export did not write {produced}")
    print(f"{name}: sandbox", flush=True)
    run(sys.executable, str(ROOT / "scripts" / "sandbox_dist.py"), "--target", name, "--out", str(out / "sandbox"),
        quiet=True)
    licences(out / "LICENSES")
    saves = ("%APPDATA%\\Godot\\app_userdata\\Rootward" if name == "windows"
             else "~/.local/share/godot/app_userdata/Rootward")
    selftest = ("Rootward.console.exe -- --self-test" if name == "windows" else "./Rootward.x86_64 -- --self-test")
    text = README.format(version=ver, exe=spec["exe"], saves=saves, selftest=selftest)
    (out / "README.txt").write_text(text.replace("\n", "\r\n") if name == "windows" else text, encoding="utf-8")
    return out


def self_test(out: Path) -> None:
    print("linux: self-test of the exported game", flush=True)
    result = run(str(out / "Rootward.x86_64"), "--headless", "--", "--self-test", cwd=out, quiet=True)
    print("  " + result.stdout.strip().splitlines()[-1])


def zip_dir(out: Path, base: Path, members: list[Path], executables: set[str]) -> None:
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(members):
            arcname = path.relative_to(base).as_posix()
            info = zipfile.ZipInfo(arcname, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = EXECUTABLE if arcname in executables else REGULAR
            archive.writestr(info, path.read_bytes())


def package(name: str, out: Path, ver: str) -> dict:
    spec = PLATFORMS[name]
    executables = {spec["exe"], *spec["extra"], "sandbox/bin/wasmtime"}
    entries = []
    game_zip = RELEASE / f"rootward-{ver}-{name}-game.zip"
    game_files = [out / spec["exe"], out / "README.txt", *[out / e for e in spec["extra"]],
                  *[p for p in (out / "LICENSES").rglob("*") if p.is_file()]]
    zip_dir(game_zip, out, game_files, executables)
    entries.append({"id": "game", "file": game_zip.name, "kind": "zip"})
    # The .pck holds no platform's code, so both exports write the same bytes: one download serves both.
    pck = RELEASE / f"rootward-{ver}.pck"
    if pck.is_file() and sha256(pck) != sha256(out / "Rootward.pck"):
        pck = RELEASE / f"rootward-{ver}-{name}.pck"
    if not pck.is_file():
        shutil.copyfile(out / "Rootward.pck", pck)
    entries.append({"id": "data", "file": pck.name, "kind": "file", "target": "Rootward.pck"})
    sandbox_zip = RELEASE / f"rootward-{ver}-{name}-sandbox.zip"
    zip_dir(sandbox_zip, out, [p for p in (out / "sandbox").rglob("*") if p.is_file()], executables)
    entries.append({"id": "sandbox", "file": sandbox_zip.name, "kind": "zip"})
    for entry in entries:
        path = RELEASE / entry["file"]
        entry["size"] = path.stat().st_size
        entry["sha256"] = sha256(path)
    installed = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    return {"executable": spec["exe"], "installed_size": installed, "packages": entries,
            "executables": sorted(executables)}


def build_installers(ver: str) -> list[Path]:
    if not (INSTALLER / "project.godot").is_file():
        print("no installer/ project: installers skipped")
        return []
    brand = INSTALLER / "brand"
    brand.mkdir(exist_ok=True)
    for source, target in [
        (GAME / "assets" / "backgrounds" / "title.webp", "backdrop.webp"),
        (GAME / "assets" / "menus" / "rootward-wordmark.png", "wordmark.png"),
        (GAME / "assets" / "brand" / "icon-256.png", "icon.png"),
        (GAME / "ui" / "fonts" / "cinzel.ttf", "cinzel.ttf"),
        (GAME / "ui" / "fonts" / "spectral.ttf", "spectral.ttf"),
        (GAME / "ui" / "fonts" / "spectral-600.ttf", "spectral-600.ttf"),
        (GAME / "ui" / "fonts" / "OFL-cinzel.txt", "OFL-cinzel.txt"),
        (GAME / "ui" / "fonts" / "OFL-spectral.txt", "OFL-spectral.txt"),
    ]:
        if source.is_file():
            shutil.copyfile(source, brand / target)
    (INSTALLER / "version.txt").write_text(ver + "\n", encoding="utf-8")
    run(GODOT, "--headless", "--import", "--path", str(INSTALLER), quiet=True)
    made = []
    for name, preset, exe in [("windows", "Windows", f"Rootward-Setup-{ver}.exe"),
                              ("linux", "Linux", "rootward-setup")]:
        out = BUILD / "installer" / name
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        print(f"{name}: exporting the installer", flush=True)
        run(GODOT, "--headless", "--path", str(INSTALLER), "--export-release", preset, str(out / exe), quiet=True)
        if name == "windows":
            target = RELEASE / exe
            shutil.copyfile(out / exe, target)
        else:
            # A download loses the executable bit; a tar keeps it, so Linux gets the installer in one.
            target = RELEASE / f"rootward-setup-{ver}-linux.tar.gz"
            with tarfile.open(target, "w:gz") as archive:
                info = archive.gettarinfo(str(out / exe), arcname=exe)
                info.mode, info.uid, info.gid, info.uname, info.gname = 0o755, 0, 0, "", ""
                with (out / exe).open("rb") as handle:
                    archive.addfile(info, handle)
        made.append(target)
    return made


def publish(ver: str, files: list[Path]) -> None:
    tag = f"v{ver}"
    repo = next(line.split("\t")[1].strip() for line in (ROOT / "media.lock").read_text().splitlines()
                if line.startswith("repo\t"))
    notes = (f"Rootward {ver}. Run the installer for your system (Rootward-Setup-{ver}.exe on Windows, "
             f"rootward-setup-{ver}-linux.tar.gz on Linux): it downloads the rest. Or put these files beside it "
             "to install without a connection.")
    view = subprocess.run(["gh", "release", "view", tag, "-R", repo], capture_output=True, text=True)
    if view.returncode != 0:
        run("gh", "release", "create", tag, "-R", repo, "--title", f"Rootward {ver}", "--notes", notes, quiet=True)
    for path in files:
        print(f"uploading {path.name} ({path.stat().st_size / 1e6:.0f} MB)", flush=True)
        run("gh", "release", "upload", tag, "-R", repo, str(path), "--clobber", quiet=True)
    print(f"published https://github.com/{repo}/releases/tag/{tag}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--publish", action="store_true", help="upload build/release/ as the GitHub release v<version>")
    parser.add_argument("--only", choices=sorted(PLATFORMS), help="build one platform")
    args = parser.parse_args()
    ver = version()
    check_inputs()
    ensure_templates()
    run(GODOT, "--headless", "--import", "--path", str(GAME), quiet=True)
    shutil.rmtree(RELEASE, ignore_errors=True)
    RELEASE.mkdir(parents=True)
    manifest = {"name": "Rootward", "version": ver,
                "built": datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"), "platforms": {}}
    for name in [args.only] if args.only else sorted(PLATFORMS):
        out = stage(name, ver)
        if name == "linux":
            self_test(out)
        manifest["platforms"][name] = package(name, out, ver)
    (RELEASE / "rootward-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    installers = build_installers(ver)
    files = sorted(RELEASE.iterdir())
    for path in files:
        print(f"  {path.stat().st_size / 1e6:8.1f} MB  {path.name}")
    if args.publish:
        publish(ver, files)
    return 0


if __name__ == "__main__":
    sys.exit(main())
