# Rootward

**Program the spell. Descend into the machine.**

Rootward is a deck-building roguelite where every card is a real algorithm. You play cards in order to write one
program; the program actually runs, in Python, JavaScript or C++, and what it computes is what your spell does. How
much work it does matters too: a fast program lands before the foes move, and a slow one lets them strike first.
Big-O is not a lesson here, it is the price of every cast.

Version 1.0.0, for Windows and Linux, in English and Japanese.

![A cast landing: the witch's circle, and the program the played cards wrote, with each call's complexity and ops](docs/images/rootward-cast.jpg)

## Install and play

### Windows

1. Open the [latest release](https://github.com/TylerFreemont0712/rootward-cg/releases/latest) and download
   **`Rootward-Setup-1.0.0.exe`** (under *Assets*; not "Source code").
2. Run it. Windows may say *"Windows protected your PC"*, because the installer is not code-signed: click
   **More info**, then **Run anyway**.
3. Choose where to install (the default needs no administrator), keep or untick the shortcuts, and click **Install**.
   Setup downloads the game (about 360 MB) with a progress bar, checks every file, and tests that spells can run.
4. Click **Play Rootward**. Afterwards it is in the Start menu (and on the desktop if you kept that shortcut).

### Linux

1. From the [latest release](https://github.com/TylerFreemont0712/rootward-cg/releases/latest), download
   **`rootward-setup-1.0.0-linux.tar.gz`**.
2. Unpack it and run the installer:
   ```sh
   tar -xzf rootward-setup-1.0.0-linux.tar.gz
   ./rootward-setup
   ```
3. Install as above. Rootward then appears in your applications menu (with an *Uninstall Rootward* action) and, if you
   kept it, on the desktop.

### Updating, repairing, uninstalling

Run Rootward Setup again: it finds the installed game and offers **Update** (only the parts that changed are
downloaded), **Repair** (everything again) and **Uninstall**. On Windows, uninstalling also works from
*Settings → Apps*. Uninstalling never touches your saves.

### Without an internet connection

Download from the release, into one folder: the installer, `rootward-manifest.json`, `rootward-1.0.0.pck`, and the two
zips for your system (`…-windows-game.zip` and `…-windows-sandbox.zip`, or the `linux` ones). Do not unzip them. Run
the installer from that folder and it installs from those files.

### Good to know

- **Nothing else is needed.** No Godot, no Python, no Node: the game carries its own engine and its own sandbox.
- **Saves and settings** live in `%APPDATA%\Godot\app_userdata\Rootward` on Windows and
  `~/.local/share/godot/app_userdata/Rootward` on Linux.
- **Something wrong?** `Rootward.console.exe -- --self-test` (Windows) or `./Rootward.x86_64 -- --self-test`
  (Linux), run in the game's folder, checks that all three languages run every card correctly and ends with OK or
  FAILED. Setup keeps a log; its *Open the log* button shows it.

## The game

### A descent

You are the Maintainer, descending from the surface station through the rings of a machine: **the Salvage**, **the
Heap**, **the Kernel**, and below them **the Root**. Each ring is a map of rooms on a scroll, with its guardian waiting
at the bottom. You choose your path room by room.

Before the first room you choose:

- **A language**: Python, JavaScript or C++. Every card is written in all three, and the game shows and runs yours.
- **A difficulty**: from beginner up.
- **A paradigm**, from three offered, and a focus within it. Then you draft your starting cards, a pack of three at a
  time.

### The five paradigms

| Paradigm | How it fights |
|---|---|
| **Divide & Conquer** | Split the volley in half, again and again: every level of recursion makes every bolt stronger, so the bigger the volley, the harder it hits. |
| **Search & Index** | Pay once to put the volley in order, then find exactly the bolt each foe needs. Nothing wasted, but only on sorted data. |
| **Greedy** | Take the best choice in front of you, every time. Fast and cheap, great against crowds, not always optimal. |
| **Brute Force** | Try every pair, every subset. Enormous damage and perfect answers, but slow: foes act first, and a big volley times out. |
| **Dynamic Programming** | Build answers from smaller answers. Tables that grow as they go, exact kills with no overkill. |

Each paradigm has a *law* that bends the rules its way, and fifteen *focuses* sharpen them further.

### A fight

- You draw a hand of cards. Each card is a function: a merge sort, a binary search, a hash map, a greedy assignment,
  a 0/1 knapsack, naive or memoised Fibonacci: 161 algorithms in all, most with a faster or stronger `+` version.
- You play cards **in order into your program** (`main.py`, `main.js` or `main.cpp`); the code panel shows the program
  growing line by line. Cards cost mana, and each has a role: a *source* makes bolts, a *shape* or an *order* changes
  them, a *strike* aims them, a *guard* turns them into block.
- Before you commit, the **preview is a real run** of your program in the sandbox: you see exactly the damage, the
  block and the work it will do. The cast then lands exactly what the preview said.
- **The race:** your program's measured work (its operations) races each foe's tempo. Foes faster than your program act
  before it lands. A program that blows its budget times out and lands nothing. Overkill is wasted.
- When you end the turn, the program runs: the code walks line by line with the real numbers, a magic circle is
  built layer by layer as each function runs, and the bolts fly.

### Between fights

| Room | What happens |
|---|---|
| **Fight** and **Elite** | Win to choose a new card; elites drop rare relics. |
| **Issue** | Thirty events, many of them code-reading bets: predict what a program prints, and the sandbox runs it to judge. |
| **Forge** | Melt a card, *refactor* it into its `+` version (shown as a diff), widen it, or bind two. |
| **Rest** | Recover Integrity (your health). |
| **Registry** | Semver's shop: cards, relics, scripts and services, for the cycles you earn per kill. |
| **Treasure** | A relic. |
| **Guardian** | The ring's boss, at the bottom of the map. |

**Relics** (91, common to legendary) change the rules: work, tempo, mana, bolts. **Scripts** are one-use commands for
a tight spot: `git revert`, `sudo`, `kill -9`, `make -j8` and twelve more.

### Foes and guardians

Fifteen creatures of the machine (the Tally Wisp, the Fork Bomb, the Off-by-One Goblin, the Segfault Specter, the
Regex Sphinx, the Stack Overflow Serpent, …), and guardians that each test one quality of your deck:

- **The Quine** sends your last program back at you, and the same program twice cannot hurt it.
- **The Mutator** edits your cards' code in the middle of the fight: can you read what your own card does now?
- **The Halting Oracle** knows whether your program halts.
- **The Page Fault** keeps one page of three resident; **the Cache Lich** remembers; **INT_MAX** overflows;
  **the Unreachable** cuts your program before it runs; **Karp** checks subset sums; **Malloc** summons;
  **the Call Stack Colossus** is built of parts; **the Livelock Twins**, **the Short Circuit** and **the Profiler**
  change how your program lands.
- **The Root Compiler**, at the very bottom, compiles the guardians you beat on the way down.

Every finished run is kept as a commit: the title shows your history as a `git log`.

### And also

- **Spellforge**: the spellbook mode. Build spells from 77 shards, each a small function, and cast whichever you
  choose.
- **Pip's Trial**: a short guided first run, from Pip's travels on the departure desk.
- **The Library**: every card (with its code and its refactor), relic, creature and guardian, searchable.
- **The Character room**: Vesper, the Star-Script Witch, in three looks, with her moves and spell styles to try in a
  practice ring.
- **Profiles**: several players on one computer, each with their own language, look, difficulty and runs.
- **Japanese** throughout, in a hiragana edition for younger readers or with kanji.
- **Safe by design**: player code runs as WebAssembly in a sandbox with no files, no network, a time limit and a memory
  cap. Nothing is sent anywhere.

| | |
|---|---|
| ![The paradigm draft](docs/images/rootward-paradigms.jpg) | ![The whole program, stretched over the arena](docs/images/rootward-program.jpg) |
| ![One ring of the descent](docs/images/rootward-map.jpg) | |

## Working on it

Rootward is made in Godot 4.7.2 with typed GDScript, and developed on Linux.

```sh
git clone https://github.com/TylerFreemont0712/rootward-cg.git   # about 7 MB
cd rootward-cg
scripts/fetch-sandbox.sh   # the sandbox: wasmtime, CPython and QuickJS for WASI, the C++ cards (once)
scripts/fetch-media.sh     # the pictures and sound, about 330 MB from the releases (once)
scripts/play.sh            # play from source (needs Godot 4.7.2 as `godot` on the PATH)
scripts/test.sh            # the tests, headless
scripts/build.sh           # the Windows and Linux builds and both installers, into build/release/
```

Pictures and sound are not in git, which keeps the clone small: `media.lock` pins each file by its hash and
`scripts/fetch-media.sh` brings them. The game also runs without them, drawn plainly and silent. On Windows,
`py scripts\sandbox_dist.py --target windows --out game\sandbox\runtime` sets up the sandbox for the Godot editor.

| Folder | What is in it |
|---|---|
| `game/core/` | The rules: pure, seeded functions over plain data (the run, programs and their work, relics, the map). |
| `game/content/` | Everything the rules play with, as data: cards (each with its `.py`, `.js` and `.cpp`), relics, foes, issues, scripts, balance, and the Japanese text. |
| `game/sandbox/` | Running player code: wasmtime, the launchers, the C++ harness. |
| `game/scenes/` | The screens: the title, the map, the fight, the rooms. |
| `game/app/`, `game/ui/` | What the screens share: the session, saves, profiles, settings, sound, the theme and pictures. |
| `game/test/` | The tests, mirroring the folders above. |
| `installer/` | Rootward Setup, its own small Godot project. |
| `pipeline/` | Making pictures, sound and music with local tools (ComfyUI, Blender, audio scripts). |
| `scripts/` | Every command: play, test, build, fetch, lint, screenshots. |

How we work, and every command: `AGENT.md` and `CLAUDE.md`. What is next: `docs/PLAN.md`. Why things are as they are:
`docs/DECISIONS.md`. What was learned: `docs/LEARNING_LOG.md`.

## Credits and licence

`CREDITS.md` lists the engine, the sandbox, the fonts and the sounds Rootward is built on. There is no licence for
Rootward itself yet, so all rights are reserved.
