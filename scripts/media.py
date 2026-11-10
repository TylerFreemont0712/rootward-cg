#!/usr/bin/env python3
"""Rootward's media outside git (ADR-0090): pictures, sound and models live in packs on GitHub releases.

Git holds the code, the content, the docs and `media.lock`, which names every media file with its SHA-256 and the
pack (a tar on a release) that carries it. A clone is small; `scripts/fetch-media.sh` brings the media.

    status                    what is installed, missing, changed, and new media the lock does not name yet
    fetch [game|dev|all|<pack>...] [--force]
                              install the packs' files (default: game, what the game shows and plays)
    pack                      rebuild the packs whose files changed and rewrite media.lock (a new release tag)
    publish                   upload every pack media.lock names that its release does not have yet

Which files are media is decided by one block in `.gitignore` (between `# >>> media` and `# <<< media`): a file
that git ignores only because of that block is media. Packs are named after the folder they hold: `assets-<dir>` for
game/assets/<dir>/, `game-<dir>` for the rest of game/ (the game needs these), `dev-<dir>` for the top-level folders
(concepts, pipeline sources, research: only for making things).

Stdlib only: it runs before anything else is installed.
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
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "media.lock"
GITIGNORE = ROOT / ".gitignore"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "rootward" / "media"
BLOCK_START = "# >>> media"
BLOCK_END = "# <<< media"
# Packs carry the game's own files apart from the folders kept in git whatever their type.
NEVER_MEDIA = ("game/addons/",)


# --- the lock ---------------------------------------------------------------------------------------------------


class Lock:
    """media.lock: `repo`, one `pack` line per pack and one `file` line per file, tab separated, paths last."""

    def __init__(self) -> None:
        self.repo = ""
        self.packs: dict[str, dict] = {}  # id -> {tag, sha, size, count}
        self.files: dict[str, dict] = {}  # path -> {pack, sha, size}

    @staticmethod
    def read() -> "Lock":
        lock = Lock()
        if not LOCK.exists():
            return lock
        for line in LOCK.read_text(encoding="utf-8").splitlines():
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if cols[0] == "repo":
                lock.repo = cols[1]
            elif cols[0] == "pack":
                lock.packs[cols[1]] = {"tag": cols[2], "sha": cols[3], "size": int(cols[4]), "count": int(cols[5])}
            elif cols[0] == "file":
                lock.files[cols[4]] = {"pack": cols[1], "sha": cols[2], "size": int(cols[3])}
        return lock

    def write(self) -> None:
        lines = [
            "# Rootward's media outside git (ADR-0090). Written by scripts/pack-media.sh; do not edit by hand.",
            "# scripts/fetch-media.sh installs these files from the packs on the repository's GitHub releases.",
            "# repo  <owner/name>",
            "# pack  <id>  <release tag>  <sha256 of the tar>  <bytes>  <files>",
            "# file  <pack>  <sha256>  <bytes>  <path>",
            f"repo\t{self.repo}",
        ]
        for pid in sorted(self.packs):
            p = self.packs[pid]
            lines.append(f"pack\t{pid}\t{p['tag']}\t{p['sha']}\t{p['size']}\t{p['count']}")
        for path in sorted(self.files):
            f = self.files[path]
            lines.append(f"file\t{f['pack']}\t{f['sha']}\t{f['size']}\t{path}")
        LOCK.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def pack_files(self, pid: str) -> dict[str, dict]:
        return {path: f for path, f in self.files.items() if f["pack"] == pid}


# --- helpers ----------------------------------------------------------------------------------------------------


def sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def pack_of(path: str) -> str:
    parts = path.split("/")
    if parts[0] == "game":
        if len(parts) > 3 and parts[1] == "assets":
            return "assets-" + parts[2].lower()
        if len(parts) > 2 and parts[1] != "assets":
            return "game-" + parts[1].lower()
        return "game"
    return "dev-" + (parts[0].lower() if len(parts) > 1 else "root")


def group_of(pid: str) -> str:
    return "dev" if pid.startswith("dev-") else "game"


def human(size: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1000 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1000
    return ""


def installed_state_path() -> Path:
    # LEARN: what fetch installed is remembered per clone, inside .git, so it is never committed and never seen.
    # It is how fetch tells "this file is an old version I put here" (safe to update) from "the player edited this
    # picture" (keep it unless --force): the same question Git LFS answers with its smudge filter.
    git_dir = ROOT / ".git"
    if git_dir.is_dir():
        return git_dir / "rootward-media-installed.json"
    return CACHE / ("installed-" + hashlib.sha256(str(ROOT).encode()).hexdigest()[:16] + ".json")


def read_state() -> dict[str, str]:
    path = installed_state_path()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def write_state(state: dict[str, str]) -> None:
    path = installed_state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=0, sort_keys=True), encoding="utf-8")


def cached_tar(pid: str, sha: str) -> Path:
    return CACHE / f"{pid}-{sha[:16]}.tar"


# --- which files are media --------------------------------------------------------------------------------------


def media_on_disk() -> list[str]:
    """Every file git ignores only because of the media block of .gitignore."""
    text = GITIGNORE.read_text(encoding="utf-8").splitlines()
    try:
        start, end = text.index(BLOCK_START), text.index(BLOCK_END)
    except ValueError:
        sys.exit(f"{GITIGNORE} has no '{BLOCK_START}' ... '{BLOCK_END}' block")
    patterns = [line for line in text[start + 1 : end] if line and not line.startswith("#")]
    exts = tuple(line[1:].lower() for line in patterns if line.startswith("*."))
    with tempfile.NamedTemporaryFile("w", suffix=".gitignore", delete=False) as other:
        other.write("\n".join(text[:start] + text[end + 1 :]) + "\n")
    try:
        ignored = set(git("ls-files", "-z", "--others", "--ignored", "--exclude-standard").split("\0"))
        by_others = set(git("ls-files", "-z", "--others", "--ignored", f"--exclude-from={other.name}").split("\0"))
    finally:
        os.unlink(other.name)
    media = [
        path
        for path in ignored - by_others
        if path and path.lower().endswith(exts) and not path.startswith(NEVER_MEDIA) and (ROOT / path).is_file()
    ]
    return sorted(media)


# --- status -----------------------------------------------------------------------------------------------------


def cmd_status(_args: argparse.Namespace) -> int:
    lock = Lock.read()
    state = read_state()
    on_disk = set(media_on_disk())
    stale = False
    print(f"media.lock: {len(lock.packs)} packs, {len(lock.files)} files, from {lock.repo or '(no repo yet)'}")
    for pid in sorted(lock.packs):
        files = lock.pack_files(pid)
        missing = changed = 0
        for path, f in files.items():
            disk = ROOT / path
            if not disk.is_file():
                missing += 1
            elif disk.stat().st_size != f["size"] or sha256(disk) != f["sha"]:
                changed += 1
                if state.get(path) != sha256(disk):
                    stale = True  # an edit the lock does not have yet
        p = lock.packs[pid]
        mark = "ok" if not (missing or changed) else f"{missing} missing, {changed} differ"
        print(f"  {pid:28} {group_of(pid):4} {human(p['size']):>9} {p['count']:5} files  {p['tag']:22} {mark}")
    new = sorted(on_disk - set(lock.files))
    if new:
        stale = True
        print(f"{len(new)} media files on disk that media.lock does not name (scripts/pack-media.sh packs them):")
        for path in new[:20]:
            print(f"  + {path}")
        if len(new) > 20:
            print(f"  ... and {len(new) - 20} more")
    return 1 if stale else 0


# --- pack -------------------------------------------------------------------------------------------------------


def build_tar(pid: str, paths: list[str]) -> Path:
    """A deterministic tar of the files, in the cache, named after its own hash."""
    CACHE.mkdir(parents=True, exist_ok=True)
    part = CACHE / f"{pid}.tar.part"

    def normalise(info: tarfile.TarInfo) -> tarfile.TarInfo:
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        info.mtime = 0
        info.mode = 0o644
        return info

    with tarfile.open(part, "w", format=tarfile.GNU_FORMAT) as tar:
        for path in sorted(paths):
            tar.add(ROOT / path, arcname=path, recursive=False, filter=normalise)
    final = cached_tar(pid, sha256(part))
    os.replace(part, final)
    return final


def cmd_pack(args: argparse.Namespace) -> int:
    lock = Lock.read()
    if args.repo:
        lock.repo = args.repo
    if not lock.repo:
        sys.exit("media.lock names no repository yet: pass --repo <owner/name>")
    tag = args.tag or "media-" + datetime.datetime.now(datetime.UTC).strftime("%Y%m%d-%H%M%S")
    now: dict[str, dict] = {}
    for path in media_on_disk():
        disk = ROOT / path
        now[path] = {"pack": pack_of(path), "sha": sha256(disk), "size": disk.stat().st_size}
    packs = sorted({f["pack"] for f in now.values()} | set(lock.packs))
    changed = 0
    for pid in packs:
        mine = {path: f for path, f in now.items() if f["pack"] == pid}
        if not mine:
            print(f"  {pid}: no files left, dropped")
            lock.packs.pop(pid, None)
            changed += 1
            continue
        same = {p: (f["sha"], f["size"]) for p, f in mine.items()} == {
            p: (f["sha"], f["size"]) for p, f in lock.pack_files(pid).items()
        }
        if same and pid in lock.packs:
            continue
        tar = build_tar(pid, list(mine))
        lock.packs[pid] = {"tag": tag, "sha": sha256(tar), "size": tar.stat().st_size, "count": len(mine)}
        changed += 1
        print(f"  {pid}: {len(mine)} files, {human(tar.stat().st_size)} -> {tag}")
    lock.files = now
    lock.write()
    # The files on disk are now exactly what the lock names: fetch may update them later.
    write_state({path: f["sha"] for path, f in now.items()})
    total = sum(p["size"] for p in lock.packs.values())
    print(f"media.lock: {len(lock.packs)} packs ({changed} new), {len(now)} files, {human(total)}")
    if changed:
        print("next: commit media.lock, push, then scripts/pack-media.sh --publish")
    return 0


# --- publish ----------------------------------------------------------------------------------------------------


def gh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    if not shutil.which("gh"):
        sys.exit("publishing needs the GitHub CLI (gh), logged in with write access to the repository")
    return subprocess.run(["gh", *args], cwd=ROOT, check=check, capture_output=True, text=True)


def cmd_publish(_args: argparse.Namespace) -> int:
    lock = Lock.read()
    by_tag: dict[str, list[str]] = {}
    for pid, p in lock.packs.items():
        by_tag.setdefault(p["tag"], []).append(pid)
    for tag, pids in sorted(by_tag.items()):
        view = gh("release", "view", tag, "-R", lock.repo, "--json", "assets", "-q", ".assets[].name", check=False)
        if view.returncode != 0:
            notes = "Media packs for Rootward (ADR-0090). Install them with scripts/fetch-media.sh, not by hand."
            gh("release", "create", tag, "-R", lock.repo, "--title", tag, "--notes", notes, "--latest=false")
            have: set[str] = set()
            print(f"{tag}: release created")
        else:
            have = set(view.stdout.split())
        todo = [pid for pid in sorted(pids) if f"{pid}.tar" not in have]
        if not todo:
            print(f"{tag}: all {len(pids)} packs already uploaded")
            continue
        with tempfile.TemporaryDirectory(dir=CACHE) as staging:
            for pid in todo:
                src = cached_tar(pid, lock.packs[pid]["sha"])
                if not src.is_file() or sha256(src) != lock.packs[pid]["sha"]:
                    sys.exit(f"{pid}: its tar is not in {CACHE}; run scripts/pack-media.sh on the machine that made it")
                named = Path(staging) / f"{pid}.tar"
                os.link(src, named)
                print(f"{tag}: uploading {named.name} ({human(src.stat().st_size)})", flush=True)
                gh("release", "upload", tag, "-R", lock.repo, str(named))
    print("published")
    return 0


# --- fetch ------------------------------------------------------------------------------------------------------


def download(lock: Lock, pid: str, dest: Path) -> None:
    p = lock.packs[pid]
    name = f"{pid}.tar"
    local = os.environ.get("ROOTWARD_MEDIA_FROM")
    if local:  # packs copied by hand (offline, or another machine's cache)
        source = Path(local) / name
        if not source.is_file():
            matches = sorted(Path(local).glob(f"{pid}-{p['sha'][:16]}.tar"))
            source = matches[0] if matches else source
        shutil.copyfile(source, dest)
        return
    if shutil.which("gh"):
        run = subprocess.run(["gh", "release", "download", p["tag"], "-R", lock.repo, "-p", name, "-O", str(dest),
                              "--clobber"], capture_output=True, text=True)
        if run.returncode == 0:
            return
        print(f"  gh could not download {name} ({run.stderr.strip()}); trying a plain download", file=sys.stderr)
    url = f"https://github.com/{lock.repo}/releases/download/{p['tag']}/{name}"
    try:
        urllib.request.urlretrieve(url, dest)
    except OSError as error:
        sys.exit(f"could not download {url}: {error}\n"
                 "The repository is private: install the GitHub CLI and run `gh auth login`, "
                 "or set ROOTWARD_MEDIA_FROM to a folder holding the packs.")


def obtain(lock: Lock, pid: str) -> Path:
    sha = lock.packs[pid]["sha"]
    tar = cached_tar(pid, sha)
    if tar.is_file() and sha256(tar) == sha:
        return tar
    CACHE.mkdir(parents=True, exist_ok=True)
    part = tar.with_suffix(".part")
    print(f"  downloading {pid} ({human(lock.packs[pid]['size'])}, {lock.packs[pid]['tag']})", flush=True)
    download(lock, pid, part)
    if sha256(part) != sha:
        part.unlink(missing_ok=True)
        sys.exit(f"{pid}: checksum mismatch, nothing installed from it")
    os.replace(part, tar)
    return tar


def cmd_fetch(args: argparse.Namespace) -> int:
    lock = Lock.read()
    if not lock.packs:
        print("media.lock names no packs: nothing to fetch")
        return 0
    wanted: set[str] = set()
    for item in args.packs or ["game"]:
        if item == "all":
            wanted |= set(lock.packs)
        elif item in ("game", "dev"):
            wanted |= {pid for pid in lock.packs if group_of(pid) == item}
        elif item in lock.packs:
            wanted.add(item)
        else:
            sys.exit(f"unknown pack '{item}': game, dev, all, or one of {', '.join(sorted(lock.packs))}")
    state = read_state()
    installed = kept = 0
    for pid in sorted(wanted):
        need: dict[str, dict] = {}
        for path, f in lock.pack_files(pid).items():
            disk = ROOT / path
            if not disk.is_file():
                need[path] = f
                continue
            have = sha256(disk)
            if have == f["sha"]:
                state[path] = have
            elif args.force or state.get(path) == have:
                need[path] = f
            else:
                kept += 1
                print(f"  kept {path}: changed here since it was fetched (--force replaces it)")
        if not need:
            continue
        tar_path = obtain(lock, pid)
        with tarfile.open(tar_path) as tar:
            for path, f in sorted(need.items()):
                # LEARN: files are written to the paths the lock names, never to the names inside the tar, so a
                # pack cannot write outside the project; each one is checked against the lock before it lands.
                member = tar.getmember(path)
                source = tar.extractfile(member)
                if source is None:
                    sys.exit(f"{pid}: {path} is not a file in the pack")
                disk = ROOT / path
                disk.parent.mkdir(parents=True, exist_ok=True)
                part = disk.with_name(disk.name + ".part")
                with part.open("wb") as out:
                    shutil.copyfileobj(source, out)
                if sha256(part) != f["sha"]:
                    part.unlink()
                    sys.exit(f"{pid}: {path} does not match media.lock")
                # A fresh modification time, so play.sh's import pass sees new pictures.
                os.replace(part, disk)
                state[path] = f["sha"]
                installed += 1
        print(f"  {pid}: {len(need)} files installed")
    write_state(state)
    total = sum(len(lock.pack_files(pid)) for pid in wanted)
    print(f"media: {total} files in {len(wanted)} packs, {installed} installed now"
          + (f", {kept} kept as changed here" if kept else ""))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status").set_defaults(run=cmd_status)
    fetch = sub.add_parser("fetch")
    fetch.add_argument("packs", nargs="*")
    fetch.add_argument("--force", action="store_true")
    fetch.set_defaults(run=cmd_fetch)
    pack = sub.add_parser("pack")
    pack.add_argument("--repo", help="owner/name of the GitHub repository whose releases hold the packs")
    pack.add_argument("--tag", help="the release tag for changed packs (default: media-<UTC time>)")
    pack.set_defaults(run=cmd_pack)
    sub.add_parser("publish").set_defaults(run=cmd_publish)
    args = parser.parse_args()
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
