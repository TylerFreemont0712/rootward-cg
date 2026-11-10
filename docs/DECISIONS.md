# Decisions

Why the game is built the way it is, one line per decision. Comments in the code cite these numbers (`ADR-0012`).
The full records (context, options, consequences) up to v1.0 are in git at the tag `archive/pre-v1.0`:
`git show archive/pre-v1.0:docs/decisions/ADR-0012-programs-paradigms-and-the-speed-race.md`, or browse that tag on GitHub. Numbers
missing below were superseded and removed before v1.0 (most by ADR-0089).

A new decision gets the next number, its own section here, and as much text as a later reader needs.
The next number is **ADR-0092**.

- **ADR-0001**: Rootward is rewritten in Godot, Shardrun first.
- **ADR-0002**: player code runs as WebAssembly under wasmtime, one process per job.
- **ADR-0003**: the Shardrun rules are ported line for line, and proven by replay (superseded by ADR-0021).
- **ADR-0004**: content is JSONC with code in real source files, checked by a small schema language.
- **ADR-0005**: one pipeline into Godot, and characters as real-time 3D.
- **ADR-0006**: the screens are built in code, and one session owns the run.
- **ADR-0007**: skins modelled in code from distance fields, with whole hands (superseded for Vesper by ADR-0008).
- **ADR-0008**: sprite skins from a video model, and spell sprites from the concept boards.
- **ADR-0009**: the card Shardrun first, and spells whose shape depends on what they do.
- **ADR-0010**: code playback moves below the arena; its Verifier contract is superseded.
- **ADR-0011**: Verifier becomes a code course; spell effects gain motion and fixed framing.
- **ADR-0012**: the Shardrun becomes programs: paradigms, measured work, foes faster than your code.
- **ADR-0013**: cards as painted cards held in a hand, details beside them, the turn ending on the Program's run.
- **ADR-0014**: spell animations drawn as motion in the pipeline, light and shade coloured in the game; the strikes retired.
- **ADR-0015**: the sandbox measures loops and recursion; the cast walks through the code.
- **ADR-0016**: a deeper Shardrun: tiered relics of its own, roles on cards, a three-bolt seed, twice the cards, a git log.
- **ADR-0017**: Initiative, a speed per intent and a budget per layer as rules; the Golem as two locks; a program run's foes of its own.
- **ADR-0018**: imports and fight state, keywords, every card's + as a refactor read as a diff, a picture for every card.
- **ADR-0019**: the soundtrack composed as scores, performed by YuE2, measured and picked.
- **ADR-0020**: sounds made on their animations' beats; cues stand in for the music.
- **ADR-0021**: the rules are the game's own; the reference results are re-recordable.
- **ADR-0022**: readable trait and relic help, a live content archive, and shard-specific effects as presentation around proven rules.
- **ADR-0023**: enemy sprites use Vesper's character finish; relic and shard icons keep their pixel-art inventory language, reviewed in small groups.
- **ADR-0024**: a fourth layer for program runs, the Root, and its guardian the Quine; guardians cycle by pool.
- **ADR-0025**: the layer map as a scroll, rooms apart by hue and outline, every layer's guardian in sight; hallway foes at 90%.
- **ADR-0026**: the guardian pool built: five guardians a layer drawn by the seed, their rules in ProgramGuardians, GuardianLanding and RootCompiler, mutants made by mutation operators.
- **ADR-0027**: local player profiles with verified save migration; the guided Trial as a separate saved program run driven by content and session events.
- **ADR-0028**: skins as VRM models (godot-vrm, MToon, spring bones); one move library keyed from readable poses in Blender and retargeted onto every skin.
- **ADR-0029**: the ZZZ-style anime shaders (slot shades, SDF face, specular, LogC LUT, coloured ink), any VRM restyled into them, any rig normalised into a skin; reference skins stay local.
- **ADR-0030**: a motion dummy and lab for the moves; follow-through springs; casts held while their volley flies; magic circles drawn in the air in front of the caster; the wardrobe as a wheel.
- **ADR-0031**: the moves play CC0 motion capture retargeted in Blender, our keys layered on it (offsets, owned bones); the light cast a finger snap; smooth playback; hand-offs that fade from the playing clip.
- **ADR-0032**: the approved lift station becomes the localized front end; Adventure, wardrobe, settings, Library, records and an Academy placeholder around unchanged run launch commands.
- **ADR-0033**: matching program and Spellforge effects resolve to one canonical texture; remaining placeholders get finished originals, and duplicate files are retired.
- **ADR-0034**: the Library opens into its own archive interior, with compact shelf navigation and mode-specific creature/boss dossiers derived from live encounter pools.
- **ADR-0035**: Settings inhabits a control room with left-hand tabs; five bundled font candidates update game themes live while the existing default and monospaced source remain available.
- **ADR-0036**: Character becomes a fitting and rehearsal room using live skins, clips and circles on a local clock; Cinzel becomes the saved default and the passage gains a continuous soft opening.
- **ADR-0037**: every skin fitted to one figure height; a six-slot cosmetic loadout (idle, casts, circle style, bolt, impact) saved with the profile; four new moves and sheets; the Character room's practice ring as a real fight stage on its own clock, with carousels.
- **ADR-0038**: a prompted "Glass Circuit" soundtrack replaces the composed one slot by slot, as the player approves each track.
- **ADR-0039**: the magic circle stacks one layer per shard (twelve kinds drawn from the card), its tier from the shard count (1-2, 3-4, 5, 6 = the grand circle); the generic per-card flourish retired.
- **ADR-0040**: optional Shard Weave constructs the circle from measured shard returns during the code walkthrough, independent of skin poses, and reuses it through the volley; selectable and previewable in Character.
- **ADR-0041**: functions draw circle layers throughout their walkthrough while measured work advances; recorded faster foes act during that walk, and circle glare lines are removed.
- **ADR-0042**: a distinct Script Loom cast stitches a seal in visible sectors during code; geometry follows traversed stroke distance, and Shard Weave stops showing full-disc arrival effects before construction finishes.
- **ADR-0043**: constructing the circle during the code walkthrough is the default cast; Script Loom and Ring Bloom (whole rings growing from a core, one per shard to six) are chosen in Spells.
- **ADR-0044**: Shard Weave and Script Loom move from Moves to Spells; every spell is built during the code walk and a worn move looses it; circles face the foes more; richer Ring Bloom with rune bands.
- **ADR-0045**: the Verifier course is removed from the game; the Academy is built fresh instead of absorbing it.
- **ADR-0046**: C++ as a third spell language: every card compiled ahead of time with wasi-sdk into one module per mode, a harness twin of the others, counted on its own lines.
- **ADR-0047**: every screen in Japanese through one Text: overlays registered with the TranslationServer, formats translated before they are filled, the rules' English sentences matched to their formats.
- **ADR-0048**: paradigm laws and focuses, fight memory, pure Index reads and compatibility with existing drafts and trial lessons (implementation in progress).
- **ADR-0049**: cycles earned per kill by kind, layer and difficulty; the Registry (Semver) with seeded stock, prices and services; sixteen scripts on a belt of three.
- **ADR-0050**: Issues, the program run's events as a stage machine over effect lists, with quizzes made from real sandbox runs of the player's own cards.
- **ADR-0051**: fullscreen is a borderless window the size of the screen (the window manager's fullscreen state flashed green on the player's PRIME laptop), and frames are capped at a whole share of the refresh rate, 90 or less.
- **ADR-0052**: a Graphics settings tab (window, vsync, frame limit, interface size, background slowdown) and a choice of drawing device and renderer applied by relaunching the game; the player's flicker was the NVIDIA-to-AMD frame copy.
- **ADR-0053**: light casts use one or two executed shards; heavy casts use three or more, independent of damage and volley size.
- **ADR-0054**: Keep scheduler-rest provenance on Program bolts.
- **ADR-0056**: the forge opens on doors (melt, refactor, widen, bind) beside the anvil; each stage is framed in its colour, and melting and refactoring act on the cards themselves, through the same one command.
- **ADR-0057**: fire, frost and spark bolts land with blows of their own (hit-ember, hit-rime, hit-arc), drawn without a GPU; anything else keeps the bracket slam.
- **ADR-0058**: Token Stream, a circle where each card's function name lifts out of the code and flies into the circle as its call runs, and dissolves into the layer it writes.
- **ADR-0059**: the program cards, relics and shards say what their code does, a refactor is not cheaper than its base, and the open code and balance questions are listed in docs/CARD_AUDIT_2026-10-08.md.
- **ADR-0060**: the legendary looks, an orrery circle whose last star launches seeded constellation bolts and a black-hole impact per foe, drawn by name in the catalogue; program bolts carry their card and role.
- **ADR-0067**: composed scores performed through ComfyUI (or yue2.cpp) in packages, a solid soundtrack concept, and Lanternroot's own tracks for each place with fallbacks.
- **ADR-0075**: complete adult Japanese alongside the hiragana edition, one selected catalog across all presentation paths, a staged character-creation choice and saved menu settings.
- **ADR-0089**: the open world (The Road) and the 3D models leave this repository, and its history is rewritten without them; the skins are the three drawn Vespers.
- **ADR-0090**: pictures, sound and models live in packs on GitHub releases, pinned by `media.lock`; git holds code, content and docs, so a clone stays small.
- **ADR-0091**: v1.0 is built to play without Godot on Linux and Windows, and installed by Rootward Setup. Below.

## ADR-0091: Builds for Linux and Windows, and an installer (2026-11-10)

The player's words: *"get this setup for cross-platform with windows … make an executable … so that godot isn't
required to play the game … a full installer … that would automatically download the assets and required files …
with a progress bar and proper branding from the game."*

- **The game exports** with Godot's official 4.7.2 templates (`game/export_presets.cfg`, `scripts/build.sh`). Content,
  card code and the C++ harness are plain files read at run time, so the presets' include filter puts them in the
  `.pck`; tests, tools and the test runner stay out. Both platforms' `.pck` are byte-identical, so one ships.
- **The sandbox ships beside the game** as ordinary files (`sandbox/`): wasmtime is a separate program and cannot read
  inside a `.pck`. `Sandbox.runtime_dir()` looks beside the executable in an exported build. `scripts/sandbox_dist.py`
  builds it for either OS from Linux: wasmtime for the target, and every module (CPython, QuickJS, the two C++
  modules) compiled ahead of time with `--target <triple>`, at baseline x86-64 features so one build runs on every
  player's CPU. The standard library's bytecode is compiled with unchecked hashes, because a zip's two-second, local
  times would make every `.pyc` look stale on another machine. `wasmtime-min` (2 MB) was tried and rejected: it has no
  GC support, which the C++ modules' exceptions need.
- **The Python library is read-only on every platform**: an exported game marks its files on first start
  (`Sandbox.protect_stdlib`, read-only attribute on Windows, 0444 on Linux), keyed by the files' age so an update marks
  again. Folders stay writable so the game's folder can be deleted; a program could add a file to the library but not
  change one (the old chmod of folders too made `rm -rf` fail).
- **`--self-test`** (`Rootward -- --self-test`, `Rootward.console.exe` on Windows) runs every worked example in every
  language and exits 0 or 1: the build, the installer and the Windows check all use it.
- **Rootward Setup** (`installer/`, a separate small Godot project so its download stays small) reads
  `rootward-manifest.json`, downloads only the packages whose hash changed, checks every SHA-256 before touching the
  game's folder, unpacks on a worker thread under a progress bar, adds Start-menu or app-menu and desktop shortcuts
  and, on Windows, an entry in Settings > Apps (per user, `HKCU`, no administrator), then runs the self-test. Run
  again it updates, repairs or uninstalls; `--silent` does any of it without a window. It is the game's own look: the
  wordmark, the title backdrop, Cinzel and Spectral, the amber palette. Chosen over NSIS or Inno Setup for one codebase
  on both systems in the game's own style, testable here; the price is size (the Windows installer is Godot's
  109 MB runtime, as an .exe cannot be compressed without tools antivirus programs flag).
- **Downloads** come from the folder beside the installer when it holds a manifest (an offline install), else from
  `installer/config.json`'s address: the repository's own releases, `releases/latest/download/`. The player made the
  repository public on 2026-11-10 so the installer needs no sign-in (an installer must never carry one); `CREDITS.md`
  names the CC-BY recordings and ships in every build.
- **Windows is checked on Windows**: `.github/workflows/windows-check.yml` (run by hand) installs a release with the
  real installer on a clean `windows-latest` machine, checks the files, the shortcut, the Apps entry and the
  self-test, and uninstalls.
