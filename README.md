# Rootward

A programming roguelite. Your spells are real code: every card is an algorithm in Python, JavaScript or C++, run in
a sandbox, and its measured work races the foes' tempo. Big-O prices the cast.

Godot 4.7.2, typed GDScript, for Linux and Windows. English and Japanese. Version 1.0.0.

![A cast landing: the witch's circle, and the program the played cards wrote, with each call's complexity and ops](docs/images/rootward-cast.jpg)

A run starts with a **paradigm** (Divide & Conquer, Search & Index, Greedy, Brute Force, Dynamic Programming), a school
of real algorithms with a speed class. The cards are those algorithms. You play them in order into one program; the
program runs in the sandbox, and a slow program lets the foes act first.

| | |
|---|---|
| ![The paradigm draft](docs/images/rootward-paradigms.jpg) | ![The whole program, stretched over the arena](docs/images/rootward-program.jpg) |
| ![One ring of the descent](docs/images/rootward-map.jpg) | The rules are pure and seeded (`game/core/`); the sandbox is `wasmtime` running CPython, QuickJS and C++ as WebAssembly (`game/sandbox/`). |

## Play it

Run the installer for your system from the [latest release](../../releases/latest): `Rootward-Setup-<version>.exe`
on Windows, `rootward-setup-<version>-linux.tar.gz` on Linux (unpack it, run `rootward-setup`). It downloads the
game (about 360 MB), checks every file, adds the shortcuts and tests the sandbox; run it again to update, repair or
uninstall. No Godot and no administrator rights are needed. Windows may warn that the installer is unrecognised (it is
not code-signed): **More info, Run anyway**.

Offline, or while the repository is private: download the release's files into one folder with the installer and run
it there; it installs from them.

## Work on it

```
git clone https://github.com/TylerFreemont0712/rootward-cg.git    # about 40 MB: code, content, docs
scripts/fetch-sandbox.sh   # wasmtime, CPython and QuickJS for WASI, and the C++ cards (pinned by SHA-256)
scripts/fetch-media.sh     # the pictures and sound, about 330 MB from the releases (gh auth login first)
scripts/play.sh            # run from source (Godot 4.7.2 on the PATH)
scripts/test.sh            # gdUnit4, headless
scripts/build.sh           # the Linux and Windows builds and installers, into build/release/
```

The clone holds code, content and docs only; media lives in release packs pinned by `media.lock` (ADR-0090). The game
runs without it, drawn plainly and silent. Developed on Linux; on Windows, `py scripts\sandbox_dist.py --target windows
--out game\sandbox\runtime` sets up the sandbox for the editor.

There is no licence file yet, so all rights are reserved. The engine's, the sandbox's, the fonts' and the assets'
licences ship with every build (`LICENSES/`, `sandbox/LICENSES/`); see `docs/ASSET_LICENCES.md` before publishing it.

## Where to read

| To learn | Read |
|---|---|
| How to work here | `AGENT.md`, `CLAUDE.md` (commands, conventions) |
| What is done and next | `docs/PLAN.md` |
| Why it is built this way | `docs/DECISIONS.md` (one line per decision; the full records are at the tag `archive/pre-v1.0`) |
| The run's state | `docs/shardrun-state.md` |
| Cards in C++ | `docs/CPP_CARDS.md` |
| Translating | `docs/TRANSLATION.md` |
| Art, sound, music | `pipeline/README.md`, `docs/ASSET_LICENCES.md` |
| Specialist agents | `docs/AGENTS.md` |
| What was learned | `docs/LEARNING_LOG.md` |
