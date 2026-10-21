# ADR-0086: The Builder shows blocks, and its Python arrives when the job works

Accepted 2026-10-20. Builds on ADR-0085.

## Context

Pebblebrook's jobs were playable, and the player's notes on the editor were about how it reads. The Learn notes were open
on every visit and took a fifth of the window. The Builder drew the blocks and the code they make side by side, so the
code was something to copy rather than something earned, and the Builder and the Scribe felt like one screen with two
ways to type. The blocks' switches sat in a gutter at x = 299, which pushed the code lines far to the right.

## Decision

**Learn is a folded chip.** `LessonGuide` starts folded (every setup folds it again). Its chip sits beside the hints' chip
under the goal (`take_toggle`), and the notes open under the chips when asked. Nothing of the guide takes room while it is
folded. This is the shared guide, so the Boots and Lesson editors fold it too.

**The Builder and the Scribe are separate screens.** The task editor's Builder shows only blocks: a "Blocks" heading, the
blocks well, and a right column titled "Python, the code your blocks make" that holds a quiet note, "Your code shows up
here once every case works." The code is not in the editor while it is veiled, so there is nothing to copy. The Scribe is
the full code editor with the glossary (its button is now **Words**, so "Hints" means only the task's hints).

**The code arrives when the job works.** On a pass the veil lifts, `Tasks.source_map` supplies the code and, for each
chip and switch, where it landed (line, column, length). The code fades in, then a copy of each chip flies from its place
in the blocks to its place in the code, and the line it lands on pulses (`LessonCode.pulse_line`, `spot_rect`). The reveal
is about two seconds, ends with nothing left in the overlay, and is skipped with reduced motion. A stage the player has
already passed shows its code at once, and later block edits keep it in step. The Builder's results and advice no longer
name a line number the player cannot see.

**The blocks sit flush left.** Every code line starts at one inset (`CODE_INSET`). A switch's group is a card whose
padding hangs to the left of that edge (an expanded margin) and whose switch is in its header, so a switched-off group
still reads as code, dimmed, and no line is pushed right by a gutter.

## Consequences

The Builder's last step is a small reward in itself (the player sees their blocks become Python) without a reward system.
`source_map` is pure and tested against the same sources as `Tasks.source`. The Boots and Lesson editors still draw live
code beside their blocks; converting them is the next step if the player wants the same rule there. The pop-down hints are
anchored under their chip and as wide as the goal's column, and still move nothing.
