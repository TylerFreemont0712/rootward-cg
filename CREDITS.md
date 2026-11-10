# Credits

Rootward stands on other people's work. This file ships with every build (in `LICENSES/`), as the licences below ask.

## Engine and sandbox

| What | By | Licence |
|---|---|---|
| [Godot Engine](https://godotengine.org) 4.7.2 | Juan Linietsky, Ariel Manzur and contributors | MIT (full text and the engine's own third-party notices in `LICENSES/godot-LICENSE.txt`) |
| [Wasmtime](https://wasmtime.dev) 49 | the Bytecode Alliance | Apache-2.0 WITH LLVM-exception (`sandbox/LICENSES/`) |
| [CPython](https://www.python.org) 3.14 for WASI ([build](https://github.com/brettcannon/cpython-wasi-build)) | the Python Software Foundation | PSF License (`sandbox/LICENSES/`) |
| [QuickJS-ng](https://github.com/quickjs-ng/quickjs) 0.17 | Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saúl Ibarra Corretgé | MIT (`sandbox/LICENSES/`) |
| [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) 34 (wasi-libc, libc++) | the WebAssembly and LLVM projects | MIT / Apache-2.0 WITH LLVM-exception (`sandbox/LICENSES/`) |
| [gdUnit4](https://github.com/MikeSchulze/gdUnit4) (tests only, not in builds) | Mike Schulze | MIT |
| [godot-vrm](https://github.com/V-Sekai/godot-vrm), [Godot-MToon-Shader](https://github.com/V-Sekai/godot-vrm) | V-Sekai contributors | MIT |

## Fonts

All under the [SIL Open Font License 1.1](https://openfontlicense.org) (texts in `game/ui/fonts/` and in each build's
`LICENSES/`): **Cinzel** (Natanael Gama), **Spectral** (Production Type), **Alegreya** (Huerta Tipográfica), **Lora**
(Cyreal), **Exo 2** (Natanael Gama), **IBM Plex Mono** (IBM), **VT323** (Peter Hull).

## Sounds

Most sounds are made for the game (`pipeline/audio/`); some are built on these recordings. Thank you:

| Recording | By | Licence |
|---|---|---|
| [Magic Smite](https://opengameart.org/content/magic-smite) | spookymodem | CC-BY 3.0 |
| [Shimmer glitter magic](https://opengameart.org/content/shimmer-glitter-magic) | Iwan "qubodup" Gabovitch | CC-BY 3.0 |
| [Magic SFX Sample](https://opengameart.org/content/magic-sfx-sample) (Magic SFX Preview Pack) | ViRiX | CC-BY 3.0 |
| [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | rubberduck | CC0 |
| [Ice breaking/shattering](https://opengameart.org/content/ice-breakingshattering) | IgnasD | CC0 |
| [Ice spells](https://opengameart.org/content/ice-spells) (most likely source of `ice.wav`) | bart | CC0 |
| [Magic Spell SFX](https://opengameart.org/content/magic-spell-sfx) | JaggedStone | CC0 |
| [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) | artisticdude | CC0 |
| [Spell sounds](https://opengameart.org/content/spell-sounds) | HaelDB | CC0 (or OGA-BY 3.0) |
| Impact, Interface, RPG Audio and Sci-fi Sounds | [Kenney](https://kenney.nl) | CC0 |

CC-BY 3.0: https://creativecommons.org/licenses/by/3.0/. The recordings were trimmed, layered, pitched and mixed.

## Pictures and music

Made for the game with local, free tools: ComfyUI image models (NovaAnimeXL, SDXL 1.0 under CreativeML Open RAIL++-M)
for the art, and YuE, ACE-Step and Stable Audio Open for the music. YuE's weights are CC BY-NC 4.0, so the music is
for non-commercial use, as Rootward is. `docs/ASSET_LICENCES.md` keeps the details, and what must be checked before
anything is ever sold.
