# Tidebreak in Thủy Vân: the parts of the conversion plan that touch the ring game

From the Thủy Vân conversion plan (session d8726f05, 2026-10-05; full plan: thuyvan_plan/plan.md, the arts survey: thuyvan_plan/arts.md).
Owner decisions behind it: Thủy Vân replaces the 1765 world; English text, names kept with English titles; Tidebreak's kits become
PEOPLES' ARTS; the player is an ordinary person in Book I. The plan proposes the art names Current / Stone / Hearth / Wind; the
owner answered (2026-10-05): Thunder moves to WIND (a mountain-pass storm, mechanics unchanged); the Day-0 stop list is NOT YET (nothing stops, four-element visual work may continue). Ids stay unchanged;
everything below is data/labels/dress, offered as a round for the loop to schedule after the Smash layer.

### 3.2 Arts and Tidebreak (overrides `arts.md`)

19. **Section 2's rows on art homes, who learns, three bands and soldiers** replace `arts.md` §2.2-§2.3 and
    `story.md` §2.2's "Household art" column and §6.
20. **Fox-fire is built on witnessed contracts**, not lies: a lantern flame lent against a named debt. Signature moves:
    the debt-taking Guard; a flame that marks a promise-breaker for witnesses (in-world people see it; the player's screen
    never shows a target cue); a refuge-veil Wall. One concealment move may stay, but it is not the identity. Anyone
    under contract to a Hồ Tinh house can learn it.
21. **No later reveals in art or sport text.** H03 and H05 are removed from every art and sport line. In Book I,
    Floodborn who play Current are "marsh pilots and mooring crews." The mixed founding of the river cities appears only
    as the quay families' counter-account to the palace version, never as fact. There is no Memory art, in any book's
    content before Book V.
22. **The Gate Basin's pier is lacquered over.** A patient player can find one chipped spot after Act 2, with no
    caption. Witness candles are plain shrine custom. The court box carries **Cửu Giang's seal**; "Thủy Vân" is the
    world's name only and never an emblem of any authority.
23. **Hearth is not Mẹ Lửa's office.** Its keepers are forge and kiln workers. Mẹ Lửa remains a critic of the sport
    ("a spending of what should be kept").
24. **Every show-like label goes, not just two.** Phase 2a's label table (section 4) renames every element-prefixed
    label and the show's technique names (Water Whip, Redirect, Air Redirect).


### Phase 2: Tidebreak in Thủy Vân dress (split into five pieces)

**Goal.** The built sport reads as Vạn Thủy's gate game with no trace of the show's four nations.

**2a, words only (S; offered to the loop as its next round, because it owns these files):**

- "Art" replaces "element" on screen; competitor names "the Current", "the Stone", "the Hearth", "the Wind"; stocks read
  as three tally pegs; results read aloud by three witnesses (text only, no new screen).
- The full label table for `data/sway/moves.json` (ids unchanged):

  | Today | On screen |
  |---|---|
  | Water Whip | Lash |
  | Redirect | Turn |
  | Air Redirect | Wind Turn |
  | Air Blast, Air Jump, Air Palm, Air Shield | Wind Blast, Wind Leap, Wind Palm, Wind Guard |
  | Earth Grip, Earth Shove, Earth Skate, Earth Wall, Rock Jab | Stone Grip, Stone Shove, Stone Skate, Stone Wall, Stone Jab |
  | Fire Arc, Fire Blast, Fire Jab, Fire Wall | Coal Arc, Coal Blast, Coal Jab, Ember Wall |
  | Fire Jets | Updraft |
  | Water Jet, Water Shield | Current Jet, Current Guard |
  | Lightning (ring and bending data) | Thunder |
  | Breath, Catch, Evade, Flow, Footwork, Frost, Gust, Ice, Mend, Parry, Patch, Pillar, Stone Form, Wave, Wind Run | unchanged |

- The same pass over `data/ring/elements.json`, `screens.json`, `lessons.json` and `data/bending/schemes.json`; "zone"
  dropped from strings once round 3 lands.
- `tests/ring/test_player_words.gd` widened with the show-word list (bend, bender, bending, pro-bending, avatar, the
  show's nation names, water whip, air scooter, redirect lightning, seismic sense, firebending and the like). Show words
  are not spoilers, so this list may live in the test.
- **Done when:** the scan of moves, elements, lessons, screens and schemes is green and the owner has seen a screen strip.

**2b, crests and VFX (M; after the loop's rounds 2-3 merge):** district crests and maker marks replace the four
glyphs; Cửu Giang's seal on the court box; per-art VFX palettes (Hearth coal-amber with ash, Current green-blue lock
water, Stone chalk dust and maker-mark cracks, Wind feather-and-ribbon streaks), in the look the owner picked in
Phase 1; Thunder's falling-strike look.

**2c, the Gate Basin (L; after Phase 3 M2's lock and floodgate kit, and after round 3 has merged):** the shared kit
dressed into the ring scene (`ring_dressing`, `ring_look`, `ring_crowd`); `ring.json`'s deck edges read only after
round 3 is final; the pier lacquered (3.2 item 22).

**2d, dress (L; after Phase 4a's Common Folk garments):** the 15 four-nation ring garments retire; competitors wear
their own people's clothes under a crew sash, with an art token (a signed stone, an ember-pot, a water-gourd, a hawk
jess).

**2e, stances (M; only inside the loop's own clip lane):** mason, poler, bellows and hawk-launch references, keyed in
`bend_clips.py`, recorded in `animations/SOURCE.md`. Nobody outside that lane edits `animations_extra/Frontier_Bend.res`.

**Done when (2b-2e):** Quick match and Practice run in the Gate Basin; the scans are green; the balance tests pass at
the loop's last numbers; the owner has approved the arena before/after (3 angles × noon, golden, night), glyphs vs
crests, the crew lineup on both bodies, the art VFX, Thunder vs lightning, and the stance sheets.

**Lock budget.** 2a about 2 Godot-h. 2b-2e about 15 Godot-h and 25 Blender-h.


## From the Day-0 stop list (owner question 1, default: no change until he says yes)

- the loop's rounds on four-element visuals (glyphs, nation dress, element colour bands); its mechanics, balance, Smash layer and clips continue

## Lock

Thủy Vân's Godot/Blender runs use the SAME lock as the loop (84dd193e.../scratchpad/godot.lock, via thuyvan_plan/bin/godot_run.sh and
blender_run.sh, run limit capped at 1100 s), so there is still one heavy process at a time. Thủy Vân work lives on a new branch
`thuyvan` (cut from spellcraft's latest gate commit, lane worktree .claude/worktrees/thuyvan); spellcraft gate commits merge ONE WAY into
thuyvan; nothing is committed on spellcraft or main by the Thủy Vân side.
