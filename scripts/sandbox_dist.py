#!/usr/bin/env python3
"""Builds the sandbox runtime for one platform (ADR-0091): what a shipped game puts in `sandbox/` beside itself.

    python3 scripts/sandbox_dist.py --target linux|windows --out <dir>

    <dir>/bin/wasmtime[.exe]        the Wasm engine for the target
    <dir>/python/python.cwasm       CPython for WASI, compiled ahead of time for the target
    <dir>/python/lib/               its standard library, with bytecode that never goes stale
    <dir>/js/qjs.cwasm              QuickJS-ng, compiled for the target
    <dir>/cpp/<module>.cwasm        every card's C++ (from scripts/build-cpp.sh), compiled for the target
    <dir>/LICENSES/                 the licences of all of it
    <dir>/VERSIONS

It runs on Linux or Windows: on Windows, `py scripts\\sandbox_dist.py --target windows --out game\\sandbox\\runtime`
sets up a development copy (C++ only if the modules were built on Linux and copied into game/sandbox/runtime/cpp/build).
Downloads are pinned by SHA-256 and cached in ~/.cache/rootward/sandbox, shared with scripts/fetch-sandbox.sh.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "rootward" / "sandbox"
WASMTIME = "v49.0.0"
QJS = "v0.17.0"
PYTHON = "3.14.7"
DOWNLOADS = {
    "wasmtime-linux": (f"https://github.com/bytecodealliance/wasmtime/releases/download/{WASMTIME}/wasmtime-{WASMTIME}-x86_64-linux.tar.xz",
                       "a956c279ac6e80109369a285db30fc46f68239fa1bbeb03ccfa8e913bbca85fc", f"wasmtime-{WASMTIME}.tar.xz"),
    "wasmtime-windows": (f"https://github.com/bytecodealliance/wasmtime/releases/download/{WASMTIME}/wasmtime-{WASMTIME}-x86_64-windows.zip",
                         "7f2a583694aac3dfeecc43ce51248155e72eaa695733d803c6923ef27103681a", f"wasmtime-{WASMTIME}-x86_64-windows.zip"),
    "qjs": (f"https://github.com/quickjs-ng/quickjs/releases/download/{QJS}/qjs-wasi.wasm",
            "42a732a676ec2d93488c19411e0fad283bf72658fdad746f089914b523c783b1", f"qjs-wasi-{QJS}.wasm"),
    "qjs-licence": (f"https://raw.githubusercontent.com/quickjs-ng/quickjs/{QJS}/LICENSE",
                    "96f73f9d2a16c21a36b418f06073be26e7d6d5e7c1bc99756b21a4f2c74ef171", f"quickjs-ng-{QJS}-LICENSE"),
    "python": (f"https://github.com/brettcannon/cpython-wasi-build/releases/download/v{PYTHON}/python-{PYTHON}-wasi_sdk-24.zip",
               "2e064d3fb8172471d39d741348efa722349c40b96301f69968dff714999c584b", f"python-{PYTHON}.zip"),
}
# LEARN: a .cwasm is machine code for one operating system and CPU. Naming the target triple compiles for that OS
# with only the baseline x86-64 instruction set, so one build runs on every player's PC, not just on this one.
TRIPLES = {"linux": "x86_64-unknown-linux-gnu", "windows": "x86_64-pc-windows-msvc"}
CPP_MODULES = ("program", "spellforge")
WASI_LIBC_NOTE = """The C++ modules (cpp/*.cwasm) are compiled with wasi-sdk 34 (https://github.com/WebAssembly/wasi-sdk).
They contain portions of wasi-libc (MIT, Apache-2.0 WITH LLVM-exception and CC0; it includes musl, MIT) and of
LLVM's libc++, libc++abi and libunwind (Apache-2.0 WITH LLVM-exception, whose exception covers code compiled into a
program). Copyright notices: https://github.com/WebAssembly/wasi-libc/blob/main/LICENSE-MIT and
https://github.com/llvm/llvm-project/blob/main/libcxx/LICENSE.TXT
"""


def sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def fetch(key: str) -> Path:
    url, sha, name = DOWNLOADS[key]
    path = CACHE / name
    if path.is_file() and sha256(path) == sha:
        return path
    CACHE.mkdir(parents=True, exist_ok=True)
    print(f"downloading {name}", flush=True)
    part = path.with_suffix(path.suffix + ".part")
    urllib.request.urlretrieve(url, part)
    if sha256(part) != sha:
        part.unlink()
        sys.exit(f"checksum mismatch for {name}")
    os.replace(part, path)
    return path


def wasmtime_for(system: str, into: Path) -> Path:
    """Unpacks wasmtime for `system` into `into` and returns the binary."""
    exe = "wasmtime.exe" if system == "windows" else "wasmtime"
    into.mkdir(parents=True, exist_ok=True)
    if system == "windows":
        with zipfile.ZipFile(fetch("wasmtime-windows")) as archive:
            for member in ("wasmtime.exe", "LICENSE"):
                (into / member).write_bytes(archive.read(f"wasmtime-{WASMTIME}-x86_64-windows/{member}"))
    else:
        with tarfile.open(fetch("wasmtime-linux")) as archive:
            for member in ("wasmtime", "LICENSE"):
                source = archive.extractfile(f"wasmtime-{WASMTIME}-x86_64-linux/{member}")
                assert source is not None
                (into / member).write_bytes(source.read())
        (into / exe).chmod(0o755)
    return into / exe


def compile_module(host: Path, source: Path, out: Path, target: str, flags: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(host), "compile", "-W", flags, "--target", TRIPLES[target], str(source), "-o", str(out)],
                   check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--target", choices=sorted(TRIPLES), required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out: Path = args.out.resolve()
    host_system = "windows" if platform.system() == "Windows" else "linux"
    with tempfile.TemporaryDirectory() as scratch_name:
        scratch = Path(scratch_name)
        host = wasmtime_for(host_system, scratch / "host")
        if out.exists():
            for path in out.rglob("*"):  # the standard library was made read-only last time
                if path.is_file():
                    path.chmod(0o644)
            shutil.rmtree(out)
        (out / "LICENSES").mkdir(parents=True)
        shipped = wasmtime_for(args.target, out / "bin")
        shutil.move(str(shipped.parent / "LICENSE"), out / "LICENSES" / "wasmtime-LICENSE.txt")
        # Python: the library unpacked, its bytecode compiled once, the interpreter compiled for the target.
        with zipfile.ZipFile(fetch("python")) as archive:
            archive.extractall(out / "python")
        shutil.move(str(out / "python" / "LICENSE"), out / "LICENSES" / "cpython-LICENSE.txt")
        python_wasm = scratch / "python.wasm"
        shutil.move(str(out / "python" / "python.wasm"), python_wasm)
        # LEARN: by default a .pyc remembers its source's modification time and is thrown away when that differs. A
        # zip keeps times only to two seconds, in local time, so on another machine every .pyc would look stale and
        # each run would compile the library again in memory (it may not write). An unchecked-hash .pyc is trusted
        # as it is: the library never changes after it ships.
        print("compiling the Python standard library to bytecode", flush=True)
        subprocess.run([str(host), "run", "-W", "timeout=900s", "--dir", f"{out / 'python' / 'lib'}::/lib",
                        "--env", "PYTHONHOME=/", str(python_wasm), "-m", "compileall", "-q",
                        "--invalidation-mode", "unchecked-hash", f"/lib/python{PYTHON.rsplit('.', 1)[0]}"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"compiling for {args.target}: python", flush=True)
        compile_module(host, python_wasm, out / "python" / "python.cwasm", args.target, "epoch-interruption=y")
        print(f"compiling for {args.target}: javascript", flush=True)
        compile_module(host, fetch("qjs"), out / "js" / "qjs.cwasm", args.target, "epoch-interruption=y")
        shutil.copyfile(fetch("qjs-licence"), out / "LICENSES" / "quickjs-ng-LICENSE.txt")
        built = ROOT / "game" / "sandbox" / "runtime" / "cpp"
        for module in CPP_MODULES:
            wasm = built / "build" / module / f"{module}.wasm"
            if not wasm.is_file():
                print(f"warning: no {wasm} (run scripts/build-cpp.sh on Linux): C++ is left out", file=sys.stderr)
                continue
            print(f"compiling for {args.target}: c++ {module}", flush=True)
            compile_module(host, wasm, out / "cpp" / f"{module}.cwasm", args.target, "epoch-interruption=y,exceptions=y")
            shutil.copyfile(built / "build" / module / "STAMP", out / "cpp" / f"{module}.stamp")
        (out / "LICENSES" / "wasi-sdk-NOTICE.txt").write_text(WASI_LIBC_NOTE, encoding="utf-8")
    (out / "VERSIONS").write_text(f"wasmtime {WASMTIME}, quickjs-ng {QJS}, cpython {PYTHON}\n", encoding="utf-8")
    (out / ".gdignore").write_text("", encoding="utf-8")
    size = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    print(f"sandbox for {args.target}: {out} ({size / 1e6:.0f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
