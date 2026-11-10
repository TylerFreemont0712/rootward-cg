# Learning log

What building Rootward taught, one entry per lesson, newest last. Entries before 1.0.0 are at the tag
`archive/pre-v1.0` (`git show archive/pre-v1.0:docs/LEARNING_LOG.md`).

## 2026-11-10: a repository's size is its history, and media is most of it

A clone downloads every version of every file, so deleting art from the working tree shrinks nothing. Pictures and
sound are already compressed and change whole, so each repaint adds its full size forever, while code compresses
against its earlier versions. Rootward's media moved to release packs pinned by a lock file of SHA-256 hashes (a
content address, like a Git LFS pointer), and `git filter-repo` rewrote history without it: 832 MB became 7 MB.

In Godot, `ResourceLoader.exists("res://x.png")` is true whenever `x.png.import` exists, even with the picture gone, so
a sidecar must travel with its picture or every "is the art here?" check lies.

## 2026-11-10: res:// is a folder only from source

An exported game's `res://` is the inside of its `.pck`. Godot reads it, but another program cannot, so the sandbox
(wasmtime and its modules) ships as files beside the executable and the game finds it from
`OS.get_executable_path()`. Plain files the game reads itself (JSONC content, card code) must be named in the export
preset's include filter, or the `.pck` silently leaves them out.

## 2026-11-10: machine code for a machine you cannot see

A precompiled WebAssembly module is native code for one OS and one CPU. `wasmtime compile --target <triple>` builds
for another OS, and naming a target drops the host's extra CPU features, so the module runs on any x86-64 PC. Python
`.pyc` files are tied to their sources' modification times; a zip keeps times to two seconds in local time, so a
library shipped in a zip needs `compileall --invalidation-mode unchecked-hash`, or every run recompiles it.

## 2026-11-10: an installer is a promise about failure

The installer checks every download's SHA-256 before it touches the game's folder, so a broken or tampered file stops
the install with the old game intact. A program that is running cannot be replaced on Windows, nor delete itself: the
uninstaller leaves a small script that waits for it to exit. And GDScript has no octal literals (`0o755` is a parse
error), which a release build reports by doing nothing at all: always parse-check before exporting.
