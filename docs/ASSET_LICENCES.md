# What could ship, and what could not

Rootward is an in-house project, so nothing here blocks anything today. This page is for the day the game might go
public or commercial: what is clearly ours or free to ship, what needs a credit, and what must be checked or replaced
first. Written 2026-10-09; keep it current when an asset source is added (CLAUDE.md asks for it). "Verify" means the
licence was not read in full for this page; read it before relying on it.

Since 2026-11-07 (ADR-0089) this repository is the card game alone: the open world's art (the town, its people,
terrain and buildings) and every 3D model left it, and its history was rewritten without them.

## Ours, free to ship

- Code-made art: puppet sheets (`pipeline/art/puppet.py`), effects drawn in code (spell circles, bolts, impacts).
- All code, content, dialogue and text.

## Free with a credit or a licence file

- **Kenney packs** (`pipeline/sources/vendor/kenney-*`): CC0, no credit required (a credit is polite).
- **OpenGameArt sounds** (`pipeline/sources/vendor/oga-*`, `ccby-oga`): mixed CC0, CC-BY and OGA-BY. CC-BY and
  OGA-BY need the author credited. Verify each file's licence in its folder before shipping.
- **Fonts** (`game/ui/fonts/`): Alegreya, Cinzel, Exo 2 and Lora under the SIL Open Font License (OFL files beside
  them); IBM Plex Mono is OFL too (verify its licence file is shipped).
- **Motion capture under the moves** (`pipeline/moves/mocap/`, ADR-0031): Quaternius's Universal Animation Library,
  CC0. It carries animation only for the move library; no 3D skin ships.

## Check before shipping (AI-generated)

Everything made with ComfyUI or the music models. The usual position is that a model's licence governs use, and
generated images may not be protectable as your own work in some countries. Read each licence before going public:

- **Pictures:** `novaAnimeXL_ilV190` (an Illustrious XL merge; its licence is on its model page, verify),
  `sd_xl_base_1.0` (CreativeML Open RAIL++-M: commercial use allowed within its use restrictions), RMBG background
  removal (verify). This covers card art, creatures, foes, backdrops, menus and the Vesper sprite skins
  (`game/assets/sprites/`, `pipeline/sprites/`).
- **Music and sound:** YuE, ACE-Step, Stable Audio Open 1.0 and Stable Audio 3 (each with its own licence; Stability
  AI's community licence has a revenue limit and terms; verify all four).
  YuE2 is used twice for the same scores (ADR-0067): the GGUF weights through `yue2.cpp` and the ComfyUI
  `yue2_MusicGen` workflow's checkpoint (`yue2-comfy-...` takes); both are CC BY-NC 4.0, non-commercial.

## Do not ship as is

- **Characters from existing games or shows.** A model or portrait of someone else's character cannot ship, however
  it was made. The local reference skins (`game/characters/_local/`, git-ignored) and their portraits stay private;
  their portraits were removed from the repository on 2026-11-07.
- **VRM or other 3D models:** none are in the repository. If one is added, each `.vrm` carries its own licence in its
  metadata (who may use it, whether commercially, whether it may be modified); read it before anything ships.
- **Mana Seed** art is not used and must not be: its licence forbids use alongside generative AI.
