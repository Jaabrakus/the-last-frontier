# Thủy Vân: the conversion roadmap (lead plan, revision 2, 2026-10-05)

This plan merges the five survey parts into one roadmap, and revision 2 applies the two judges' reviews. The parts sit
beside it in this folder:

- `inventory.md`: every game system and what happens to it
- `regions.md`: world scale, the regions, and the first region (sketches: `regions_route_graph.png`, `r1_slice_layout.png`)
- `peoples.md`: the eight peoples as creator choices and NPCs
- `story.md`: the player's Book I
- `arts.md`: Tidebreak and the peoples' arts

**Where this plan and a part disagree, this plan wins.** Section 3 lists every canon correction that overrides the
parts. Builders take canon from section 3 and from `data/thuyvan`, never by copying a part's text.

Also in this folder:

- `owner_summary.md`: one page for the owner, with the few questions only he can answer
- `phase1/T0.md` … `phase1/T5.md`: the Phase 1 task texts, ready to dispatch
- `phase1/r1_layout.draft.json`: the draft R1 layout that T0 commits and T3 and T4 both read
- `bin/godot_run.sh`, `bin/blender_run.sh`: the one canonical lock wrapper pair (section 6)

This was a read-only planning pass. No repository was edited, nothing was committed, and Godot and Blender were not run.

---

## 1. The target: what the game is in Thủy Vân

**A river world, played by an ordinary person.** You make a new person of any of the eight peoples. You live through
Book I's five months: a Sacred River stops at Đá Trắng, and a war begins for the wrong reason. You cross paths with the
canon cast but never replace them, decide for them, or learn their hidden matters. You are not a chosen one, no faction
is the good one, and the war starts whatever you do.

**The verbs you have:**

- living (household, food, boats, trades)
- witnessing (the Account: what you saw, were told, can show and owe, each entry separate and sourced)
- working and travelling the water (ferries, towpaths, later locks)
- possibly a small art, learned from a teacher, with costs paid as debts and obligations, never in speed or aim
- Tidebreak, the city's festival sport, where the arts play at full scale because the venue is a prepared place

**What stays the same:**

- the engine: controller, animation, traversal, water and boats, household, survival, story engine, net, the Tidebreak
  ring
- the owner's rules:
  - no target cues on enemies, ever
  - getting hit never slows you or hurts your aim
  - easy to learn, hard to master, human-made feel
  - our own clips and our own assets (AI-assisted Blender authoring is how this project makes them)
  - every look change is shown to the owner by eye, and feel changes are handed to him to play
- internal class names (`FrontierPlayer` and so on, 1,856 references). They are not player-facing.

**What changes:**

- The world becomes walkable regions of at most 4×4 squares, joined by journeys that cost the bible's travel windows in
  game time (1 bible day = 2.4 game hours, so 1 bible month = 3 survival days).
- The first region is **R1, the Đá Trắng Reach and Two Heights** (layout in section 4, Phase 3).
- Water becomes a network (channels, pounds, later locks), with the Silence as a still reach.
- Peoples: Mountain Folk first (the story slice), then the other human-shaped peoples, then the new bodies.
- Arts: Current, Stone, Hearth and Wind now; Fox-fire and Root later. Learned from teachers; never fixed by people.
- All text is English; names keep their Vietnamese spelling with an English title. Fonts must render Vietnamese.

**What retires to git history** (at the cutover, Phase 5; work on it stops at Day 0 if the owner agrees, section 5):
firearms and the 1750s loadout; the fort and the mammoth; the wonder sky and the galleon; the Two Fires and Downbelow
story content; the 1765 world data; the 35 real peoples in the creator lists (every face is kept); the 129 period
garments; the North American species and crops; the frontier music cues.

**When the owner can play something** (estimates, single Godot/Blender lock shared with the Tidebreak loop):

| What | When |
|---|---|
| The **Still Water greybox**: today's valley and river re-lit tropical, the Silent Reach stopping in place, no guns, a Mountain Folk preset | about 3 weeks |
| Tidebreak words cleaned of the show (art names, move names) | whenever the loop takes it as a round (about a week of its time) |
| The **real gorge and village** (R1 squares C1 and B1, baked from the new recipes) | about 9-10 weeks |
| The **story slice**: Prologue "Counted" and Act 1 "Still Water", as Mountain Folk | about 6-8 months |
| Book I completable for Mountain Folk and Stone Children, both inside R1 plus the Lock Road | about 13-16 months |
| Book I for all eight peoples | well past two years |

---

## 2. Decisions the lead has taken (the owner can overturn any of them)

These do not wait on the owner. Each has a default that follows the bible's rules or the owner's own rules. The owner
summary names them in plain words so he can say no.

| Topic | Decision | Why |
|---|---|---|
| Tidebreak's place | The gate game of Vạn Thủy's lock crews. Basin matches in neighbourhood locks all year; the final at the Flood-Rite days. The ring is a **prepared place**, so the arts play at full scale only there. The name stays **Tidebreak**; no Vietnamese name (Phá Triều reads as "breaking the court"). | Owner decision (3); bible §07: power is relational, local and costly |
| Art names | Current, Stone, Hearth, Wind on screen; code ids stay earth, water, fire, air. Lightning is renamed **Thunder** and Fire Jets **Updraft**, mechanics kept, still in the Hearth kit (moving Thunder to Wind is owner question Q5). | No show words; never swap a move's identity unasked |
| Art homes | **Current**: Riverborn channel councils and Dragon-Sea lock guilds. **Stone**: the Stone Houses and the Mountain Folk waystone-builders (field stone, cairns). **Hearth** (proposal): forge and kiln keepers, smiths and potters of any people. **Wind** (proposal): Cloud-Pass windwalkers and Dragon-Sea sail-callers. | Owner decision (3) fixed for water and earth; fire and air homes stay proposals |
| Who learns an art | Anyone, from a teacher, after taking an obligation. The creator picks "Raised in" and a first teacher, with the owner's mapping as the default teacher. **Every start offers "no art yet."** One art per character in the open world (sport menus still let you pick any art per match). Bound characters have Consultation in addition to anything they learn. | D03, D12: peoples are not classes; §07: a trained practitioner |
| Strength by place | Three bands. **No material, no art.** **Material present, away from home or a bond:** reduced reach and knock. **Home, a bond-site, or a prepared place:** full. Speed and aim are never touched. Each open-world use leaves a small named debt ("what is drawn is returned", "every stone set back") in the Account, due by a date. | §07 limit 1 (relationship, practitioner, setting); power creates an obligation |
| Soldiers | Military and militia NPC presets carry spear, bow and dao only. Arts in the open world belong to rare named practitioners, at everyday scale. | The bible's logistics-and-spears war; no canon fighter uses an art |
| First region | R1, the Đá Trắng Reach and Two Heights. The bible's travel windows set the world's scale; the map sheet is topology only; Đá Trắng's reach sits west, 2-3 days' trail from Two Heights, as the bible says. | Bible over sheet; most Book I canon happens here |
| The slice people | Mountain Folk: a human body, the most canon cast nearby, the hook scene. | All parts agree |
| Peoples' order | Mountain Folk complete first; Dragon-Sea and Stone Children NPC presets; Stone Children playable second; Ancestor-Bound as a Condition row; Hồ Tinh in human form as NPCs; Riverborn playable only after the swim track; Floodborn as NPCs, then Mộc Tinh, then playable Floodborn. | Body cost and Book I canon |
| The hook | Your kin (default: your child, just counted at 15-16) is put on a register and levied for river works. The kin always survives Book I. v6's switch to playing the child is dropped for Book I (a Book II storyline may play the grown kin). | Book I is five months; "the dead do not return" leaves no room for fake deaths |
| Death | Wound and rescue: you wake where someone carried you, and you owe them (an Account debt). Story NPCs can die for good. | "Anything claiming to be fully returned from death is suspect" |
| Family across peoples | Same-body-kit households can have children (`ChildLook.from_parents`). Across body kits, the kin is fostered or adopted (P02's adoption through a shared hearth). The bible's open biology question stays open. | Do not create canon through a game system |
| Animals | Horses stay, few, as officials' and soldiers' mounts (the stories have them). Mules, oxen and buffalo carry everyday loads. No foxes or wild crocodiles as game. Buffalo from the bison generator, goats, herons and hawks. | Stories 5, 8, 20; Hồ Tinh and Floodborn are peoples |
| The Silence in play | From S1 the still reach is cordoned by soldiers and clan watchers, who turn people back. What touching the water does, and whether a boat on it moves, stays unanswered in Book I. Hạc's warning is folk knowledge. | Avoids a "named entity behind events" in Book I |
| Story conflicts | V3 wins: #23's novice is unnamed (V3's Vệ is unbound); #15's elder spirit is unnamed (no "Kha Mộc"); #31's scholar is Bùi Khánh only if the owner says so, otherwise an unnamed archivist; #5's Nhàn is a separate scout, not C32 Nhạn. | V3 is the master bible |
| Hán characters | None in game (no CJK font). | Size, and the sheets' Hán labels need correcting first |
| Music | The orchestra pipeline (VSCO 2 CE) stays and takes new cues: the Silence, rites, the Return, the hearing. | Works today |
| Co-op | Single region until Phase 8: a journey moves the whole party or no one. | NetSession assumes one shared world |
| The Smash layer | Strain growth and hitstun only inside the ring. Outside, a hit knocks back and damages, nothing else. | No debuffs outside the sport |
| Crowds | Every Book I scene is written for 12 or fewer animated people until the crowd-card system lands (Phase 3 M2). | The Mac mini budget |

---

## 3. Canon corrections that override the survey parts

These fix what the judges found. Each part file now opens with a banner pointing here.

### 3.1 The player's story (overrides `story.md`)

1. **No hero's view of the whole truth.** Each start's Book I route touches **at most two** of the four canon lines:
   - **N, the north crossing:** Kha Vũ, Hạc, Nhạn, Two Heights (Yên Dao, Dương Sắt, Lệ Thạch, Tấn, Bạc Sơn), Mẹ Lửa
   - **S, the shrines:** An Tâm, Father Từ (Vệ stays at L11 and is not met in Book I)
   - **R, relief and records:** Linh Hải, Bảo, the convoy, the capital's offices (Minh Nguyệt's packet, Lạc Thiên)
   - **M, the moorings:** Ruk-Khan, Kor-Va, Sha-Ra, the burned dig, Har-Kel

   Default routes: Mountain Folk **N+S**; Stone Children **N+R**; Ancestor-Bound **S+R**; Dragon-Sea **R+M**; Riverborn
   **M+R**; Floodborn **M+R**; Hồ Tinh and Mộc Tinh routed under the same rule when their bodies land. The north never
   sees Ruk's interrogation; the marshes never see Dương's survey. Missions carry a `line` tag, and a data test
   (Phase 6) fails any route that uses more than two lines.
2. **The Account never joins the dots.** It has no "link these entries" action and no count of what you have collected.
   Entries stay separate, sourced and unjoined. Contradicting entries sit side by side.
3. **The ending "To keep the Account" is cut.** It is replaced by **"Keep it in the family"**: your testimony goes in the
   household ledger, and one copy goes to a single local holder (a ferry clerk, or a neighbour house's novice). Nothing
   frames it as a right to refuse or correct. "With Ruk's site defense" is offered only on routes that pass through M.
4. **The family token, not an anchor.** Before the kin leaves you agree on an ordinary family token (a knot, a tapped
   rhythm). Its only job is trust: "it's really you, you came." The kin's memory gap of the burn night is like Sha-Ra's
   other patients' (fever and shock, unexplained) and the token never restores it. The word "anchor" never appears on
   screen. The 3.5f novice who records the gap is dropped.
5. **The Mountain start moves.** It is a mixed foothill village of a clan that has **submitted** (P02 allows it), on a
   magistrate's register below Đá Trắng, with a clan name the owner gives (Q3). Its youth are levied through the
   imperial register, so no raid-favouring clan is conscripted. Kha passes through on his way and is never your host.
6. **The elder's death is ordinary.** Just below the still reach, the displaced flow undercuts a bank (or a stranded
   barge's line parts). Your elder is lost there and the body goes downstream. Nobody is taken by the still water.
   Choice B becomes: pull people off the stranded barges, or record times and signs for Nhạn's report.
7. **Private matters stay private.** An Tâm performs your elder's rite; at most you notice her pause over a household
   detail. Vệ is absent. Bảo writes your times into the official log; you never learn he keeps a copy. Kor-Va's dispute
   with Ruk is, at most, a muffled argument behind a screen.
8. **Tấn in Book I is only his canon act:** he argues in public against Yên Dao's price and asks you to back a raid
   (Choice D). "Smoke in Goat Pass" (#5) becomes a northern side quest with its own culprits (traders and a disguised
   porter reading cairn messages: ordinary smuggling, unexplained). Any interception tied to Tấn moves to Book II.
9. **Vân Cổ's rescued column is an imperial garrison or supply column** that you hired onto as a hauler, separate from
   Kha's shared retreat (Kha earns that one). Vân learns and uses the names of soldiers and officers around him. You are
   one face among many; he never speaks your kin's name.
10. **Two Heights' marks carry no meaning in Book I for the player.** On the north route you hold Dương's rods on his
    terms and can see two different marks cut on one pier. The Account records "two marks, meaning not known." The
    charter reading (R04, Book I late) belongs to Kha, Yên Dao and Dương, off-screen.
11. **The north route's Act 3 stays in R1.** Your kin comes home up the Lock Road with released workers whose accounts
    of who freed them contradict each other. At the lock checkpoint (S3, Trần Hổ's arrests) officers want the kin to give
    the useful story ("pirates"). Choice F on this route: let the kin say it and pass, get them past at night, or
    petition through the shrine house (slow, lawful). This makes Book I completable for Mountain Folk inside R1 plus the
    Lock Road journey.
12. **Riverborn kin take imperial pay without a licence.** The channel council's absence and judgement both stand. A
    Riverborn player can guide Linh's convoy through one dangerous unlicensed stretch only, which brings council
    judgement and a named debt. The convoy still lacks licensed pilots.
13. **Choice F's "guide the officers" option** leads to a peripheral mooring that Ruk's people have already left. The
    casualties are named ordinary NPCs you met; no dossier changes.
14. **Timing.** The logline says "a month later" (the Prologue is one month before the Silence). The first sport scene
    is a basin match in Year 0; the news of the Silence reaches Vạn Thủy about a week into Year 0 by dispatch boat. The
    Floodborn crew is barred in month 1, after the burn notices. Riverborn crews have been rare for generations (since
    H14). The flood-rite days at the year's turn are a **proposal** in `calendar.json`. One sport calendar: basin
    matches all year, the final at the Flood-Rite, matches suspended by decree in month 5.
15. **Khe Lan Ferry is the owner's call (Q3).** If he picks it, he also decides Duyên's fate (default: she lives, the
    ferry does not). Its crew is Mountain, Stone and Dragon-Sea; the "Floodborn" evidence is a tally peg traded north
    that officers misread. Otherwise the station is the Fifth Lock's crossing house and #27 stays a storm side quest.
16. **Lesser losses, not canon-scale ones.** Mộc Tinh: the grafted elder tree sickens and goes silent; the grove gives
    no explanation. Stone Children: the elder dies at a lesser retaining wall of the Stone hamlet; the Two Heights anchor
    only "sings" under impossible loads.
17. **Consultation stays domestic.** A Bound player's consultation answers household matters only: family names, field
    boundaries, debts, recipes. "An old joint-mark" is An's signature and is never a player's answer. #23's voice
    commands rather than asks, knows nothing of works, and stays unidentified.
18. **Floodborn are not "monsters attack."** The burn shows both the warband's violence and the dig's forced labour;
    Ruk asks about digging, not tribute; Kor-Va's extraction is late; the Floodborn player kills no workers. (Kept from
    `story.md` §3.1.)

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

### 3.3 Map, data and art sources (overrides `regions.md` and `inventory.md`)

25. **Nine Sacred Rivers in public.** Everything imperial and folk counts **nine** Sacred Rivers by ritual name, one a
    seasonal double. The eight hydraulic channels exist only in author-side data (`tools/`). No in-game art uses the map
    sheet's I-VIII legend. Until the owner names the nine (Q3), the game shows no river list at all. Once named, the
    imperial map's duplicated seasonal district is Bùi's plant: noticeable, never explained in Book I. `story.md` §1.1's
    reveal-guard table (what Book I may and may not show) stays binding.
26. **Nothing spoilery ships in `data/`.** Shipped canon rows carry only public titles, peoples, routes and
    `reveal_book`; no author-truth, hidden-matter or evidence fields. The guard's term lists live in `tools/thuyvan/`
    behind a `.gdignore`, and the export preset (when one is made) excludes `tools/*`. No Hollow faction id until Book IV
    content exists (overrides `inventory.md`'s npc row). "The miniature of the final seal" (`regions.md` §5.1) is an
    author note and never ships.
27. **No sheet image goes into game art without a redraw review.** The map sheet (Ninth River legend, Convergence) and
    the Buried Kingdom sheet ("+ the Convergence", "the Convergence Floor") are Book III and Book V material.
28. **R1's layout is re-cut** so the main river runs north to south through C1-C4 and leaves at the south edge
    (`phase1/r1_layout.draft.json`). D1 and D3 are dropped; C4 is the river exit and first karst; A4 and B4 are rim.
    The Dragon-Sea start is in Vạn Thủy (R2), not R1's lock town.
29. **A Tidebreak ring is not moored in R1.** In R1 the sport is reached by a scene switch from a pier notice board. A
    floating ring in the world can come in Phase 8 if still wanted.

### 3.4 Peoples (overrides `peoples.md`)

30. **The bible's English names are the primary labels.** English titles: "Stone Children, of the Stone Valleys" (not
    "Mountain-Descended", which invites the Mountain Folk merge D02 forbids) and "Floodborn, of the Reed Marches" (not "of
    River and Mountain"; cold slows them).
31. **The sheets' Vietnamese labels misread their own Hán.** Corrected pairs go to the owner and a native speaker (Q4):
    Long Hải Tộc (龍海族) or Dân Biển Rồng; Sơn Dân or Dân Núi; Thạch Duệ (石裔) or Thạch Nhi (石兒); Trạch Duệ (澤裔);
    Thủy Sinh Dân; Hồ Tinh; Mộc Tinh; Tổ Linh Hệ (祖靈繫) or Tiên Tổ Hệ (先祖繫).
32. **Proportions are visual only** (within about ±4% of height) with no capsule or camera change until a traversal
    re-bake is budgeted. Webbed hands wait for the Riverborn body pass after the swim track.

---

## 4. The phases

Each phase lists its goal, contents, done-when, size and lock budget (estimated Godot-hours and Blender-hours on the one
shared heavy-process lock). Code-only lanes (story systems, the Account, the region loader, the guard, mission
scripting) run in parallel because they do not need the lock.

### Phase 0: Day 0 (1-2 days)

- The owner answers Q1 (the stop list in section 5). This changes what other sessions spend the lock on; it does not
  block anything here.
- The lead runs T0: cuts `thuyvan`, makes its worktree (the only imported one), does the first import under the lock,
  commits `data/world/maps/r1/layout.json`, and adds the play launcher's place.

### Phase 1: Foundations and the Still Water greybox (now, about 3 weeks)

**Goal.** Something the owner can play in Thủy Vân's mood within three weeks, plus the data and tools every later
phase reads. Nothing here touches the loop's paths.

**Contents** (task texts in `phase1/`):

- **T0** (lead): branch, worktree, first import, `layout.json`, wrapper pair, merge rhythm
- **T1**: canon data (public fields only), the `ThuyVanCanon` loader, the phrase-based text guard in `tools/`
- **T2**: Vietnamese-capable fonts (system fonts by default; a free OFL font only if Q2 says yes), glyph test, proof
- **T3**: the WaterNetwork core with a channel-local API, its Python twin, R1 `water.json` generated from the layout
- **T4**: R1 terrain recipes and `squares.json` from the layout (Python only)
- **T5**: the Still Water greybox (the Godot lane): region loader, still reach, tropical clock, no guns, a Mountain
  Folk preset, the S0/S1 toggle, mood frames and a launcher
- Storyboards for the slice (Prologue and Act 1 north) start here as a writing lane: one frame per mission plus the
  vistas, for the owner to judge before anything is built.
- The **old T5 (Gate Basin kit) is dropped**: the floodgate and lock kit is built once in Phase 3 M2 and serves both
  the Fifth Lock and the Gate Basin.

**Done when:**

- T1-T5 are merged into `thuyvan` and the lead's Godot test run is green, frontier river, fish, boat and fishing tests
  included.
- The owner has **played** about ten minutes of the Still Water greybox and picked a look from the mood frames.
- The owner has seen the font in a real screen strip and the R1 relief views.
- No owner answer is required to finish: system fonts cover Q2, placeholders cover Q3 and Q4.

**Lock budget.** Godot about 12 h (first import, tests, greybox shots); Blender 0.

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

### Phase 3: R1, the first region

R1's grid (north up; layout in `phase1/r1_layout.draft.json`):

| | A | B | C |
|---|---|---|---|
| 1 | high pass, waystones | the village (submitted clan), rope-rite cliff | **gorge, the Silent Reach**, cairns, survey camp |
| 2 | **Two Heights Bridge** over the torrent | switchbacks, the shrine house | middle reach, the ferry, fishing hamlet |
| 3 | Stone hamlet | foothill paddies | the Fifth Lock (placeholder name), crossing house, barge basin |
| 4 | rim | rim | river exit, journey pier, first karst |

**M0, the real gorge and village (about 6 weeks after Phase 1):**

- T4's recipes bake C1 and B1; they are packed for the region loader from T5. Raw bake binaries stay ignored; the packed
  region resources are committed like today's.
- WorldRiver serves the z-monotonic main channel from the layout's nodes (piecewise level and x by z), plus T5's
  per-reach flow scale. No WaterNetwork wiring yet.
- The look the owner picked in Phase 1 is applied.
- Frame time measured on the M4 mini at medium, water on and off, haze distance settled.
- **Done when:** the owner plays C1 and B1; 60 fps at medium; running vs still water approved from one camera (dawn,
  noon, rain).
- **Lock budget:** about 20 Godot-h, 5 Blender-h.

**M1, the slice squares (about 3 months more):**

- Squares B1 (village), C1 (gorge and Silent Reach), C2 (ferry and fishing hamlet), and B2's path and shrine house.
- **WaterNetwork wired in** with its channel-local API. The ports are explicit tasks, not a drop-in replacement:
  `RiverWater` (L), `FishLife` (M), `WaterSurface` and the boats (M), `StoryLayer` (S), `RiverIce` (S), `fishing_gear`
  (S), `RaidStage` / `MarchStage` / `Captivity` (S each), and their tests and tools (`test_river`, `test_fish`,
  `test_boat`, `test_fishing`, `river_film`, `rapid_shots`). 40 files call `WorldRiver` today (99 calls to `x_at`).
- **The deep-water rule:** deep water pushes the player back to the nearest edge, or floats him in a simple tread. No
  drowning, and hits never slow him. A fall off the ferry is handled.
- Per-region texture arrays (paddy mud, limestone, laterite).
- Vegetation: bamboo, mountain pine (retinted white pine first), broadleaf evergreen, banana, tree fern, reeds, paddy
  rice.
- The Mountain village kit (7 building types) and the shrine (2).
- Sampan and basket boat, poling, the rope ferry.
- Tropical WorldClock with wet and dry seasons; region survival data (rice, fish, salt, rope, bronze cash); year layers
  S0 and S1; the cordon at the still reach.
- **Done when:** the village, gorge, ferry and shrine path are walkable and boatable; S0 to S1 switches in place; 60 fps
  at medium; the owner has approved the square lineups, the village kit beside the Trường Sơn sheet, and the boat lineup.
- **Lock budget:** about 50 Godot-h, 70 Blender-h.

**M2, the rest of R1 (about 3-4 months more):**

- C3 lock town with the **lock and floodgate kit** (gates, towers, winches, sluices, chamber walls), built once for
  the Fifth Lock and the Gate Basin (Phase 2c).
- C4 and the karst kit with skyline cards; the A column (Two Heights hero bridge, the Stone hamlet), B3 paddies.
- **Crowd cards or impostors** (L), with a frame-time test on the M4 mini, before any scene that needs more than 12
  animated people.
- Toll barge and river cutter; year layers S2-S4.
- **Lock budget:** about 60 Godot-h, 100 Blender-h.

### Phase 4: The peoples in the creator (beside Phase 3, sharing its lock queue)

**4a, Mountain Folk complete (gate for Phase 6):**

- Creator rows: People, Raised in, Condition (Bound / Unbound), Mix with; first teacher or "no art yet". No stat
  bonuses; no people locks an art.
- The Mountain preset, 6-8 everyday garments, own-drawn clan tattoos, the kin's 15-16 growth stage (S-M).
- The 35 real peoples leave the lists; every face stays.
- **Cast lineup:** A/B/C looks for each slice character beside their dossier lines, in everyday dress: Kha Vũ, Hạc,
  Nhạn, An Tâm, Mẹ Lửa, Bạc Sơn, Trần Hổ's soldiers, the clan headman and the magistrate's clerk. The owner approves
  before Phase 6 builds missions.
- A first Common Folk set (also used by Phase 2d).

**4b, NPCs:** Dragon-Sea and Stone Children presets; Ancestor-Bound as a Condition row; Hồ Tinh in human form; the
military presets with spear, bow and dao.

**4c, Stone Children playable:** pigment skin mode, mineral plates (the second Book I route).

**Done when:** each wave's in-game lineup beside its sheet (both bodies) and the bold variants are approved.

**Size and lock budget.** 4a about 6-8 weeks (10 Godot-h, 40 Blender-h); 4b and 4c about 2 months more.

### Phase 5: Cutover (Thủy Vân becomes the game; the frontier retires)

**When:** at the owner's word once M1 is playable.

- `main` has been merged into `thuyvan` at every gate all along (section 6), so the cutover merge is small.
- Merge spellcraft into main (a fast-forward if main has not moved), then `thuyvan` into main.
- On a short cut branch: the menu starts Thủy Vân; firearms, loadout, gun IK, the fort, the mammoth, the wonder sky, the
  Two Fires stages, the 1765 data and the old docs go; gun surgery in `upper_body`, `tree_builder`, `player_anim`, NPC
  fighters and HuntKit; the 157 frontier-tied tests re-staged or retired; `project.godot` retitled with
  `use_custom_user_dir` so saves and saved looks keep their place; an export preset that excludes `tools/*`.
- **Done when:** the game boots into Thủy Vân, the tests are green, and the owner has played locomotion, aim and holds
  after the gun removal.
- **Size:** about 3-5 weeks.

### Phase 6: The Book I slice, Mountain Folk (Prologue and Act 1 north)

**Goal.** The story idea tested end to end on one people in R1's slice squares.

- **Missions (about 10):** Prologue "Counted" (morning work that teaches the kin and the controls; the rope rite; the
  register, Choice A; the levy and the family token; the flood-rite days with an empty place) and Act 1 "Still Water"
  (the Silence; the loss at the undercut bank, Choice B; the rite, with Mẹ Lửa's refusal and An Tâm performing it; the
  notice; leaving or staying).
- **Moves:** only the two household moves of the first teacher's art, or none if "no art yet". Teachers, bond-sites and
  strength by place come in Phase 8.
- **The rope rite** is staged on the existing ledge and grip system with a scripted rope; SnowCover stays for the high
  pass only.
- **The Account v1:** a read-only ledger (Seen, Told, Can Show, Owe, Names), no linking.
- The kin as a story person; essential canon NPCs; the route data test (two lines at most); the guard green on all text.
- About 8 own rite clips (tie knots, rope crossing, kneel, say the names, hand over a token, carry a pole, pole a boat,
  bow).
- **Mission scripting starts in Phase 1** on the greybox, as a code lane, so most risk is gone before final art exists.
- **Done when:** it plays from character creation to "Leaving" with the guard green. The owner has approved the
  storyboards (before the build), the kin lineup, the Silence variants, the rite stills, the Account mockups (2-3
  paper-ledger styles), and has played it.
- **Size and lock budget:** about 2 months after M1 and 4a land (25 Godot-h, 15 Blender-h).

### Phase 7: Water bodies and the new bodies

1. **The swim track** (L-XL): own Blender clips for tread, stroke, dive and climbing out onto quays and boats; an
   underwater camera; breath. Then **Riverborn playable**, with gills and webbed hands that do something.
2. **BodyExtensions:** runtime bones before the Skin binds, spring chains, a pose layer, LOD, and a check script.
3. **Hồ Tinh:** fox ears and 1-9 cosmetic tails; Identity Strain only as social tells.
4. **Floodborn as NPCs** (needed before any M-line act): grey-box silhouette review first, then a crocodilian body and
   head on Actor_B plus a tail, an own NPC clip set, reed and net armour.
5. **Mộc Tinh:** a bark body with a crown height cap; NPC first, then playable as a young spirit.
6. **Playable Floodborn:** snout-safe hand-to-face clips, sitting and lying with the tail, climbing.

**Done when:** each body passes its silhouette review, its motion strips, and a door, bed, boat and seat clearance check.
**Size:** swim track about 2 months; Hồ Tinh about 1 month; Floodborn and Mộc Tinh XL each.

### Phase 8: The rest of Book I and the world

- **North routes first:** Acts 2-4 for Mountain Folk and Stone Children inside R1 plus the Lock Road journey (Two
  Heights, the Return as a hauler, the checkpoint at the lock, the station failure, the hearing, the ending). **Book I is
  completable for two peoples here.**
- Open-world arts in full: teachers, obligations, bond-sites, the three bands.
- The Journey system and passage screen; co-op region reload on both peers (S-M).
- An R2 Vạn Thủy district (with the Gate Basin in its home), the toll-corridor pocket (the dig and the burn), the
  other routes and starts.
- About 12 side quests from the stories; wildlife; paddy farming; music cues; Fox-fire and Root; the Tidebreak circuit.
- An in-game atlas map redrawn without spoilers, with no river list until the owner names the nine.
- **Done when:** Book I is completable for two peoples, then all eight, with the guard green and the owner's sign-off
  on each set piece. **Size:** more than a year.

### Lock queue (one priority order for the shared lock)

1. The Tidebreak loop's own gates, while it runs
2. Slice assets: Phase 1 tests, M0, M1, 4a, the slice clips
3. The Tidebreak re-dress (2b-2e)
4. Later regions and bodies

---

## 5. What retires, and when; the Day-0 stop list

**Stop spending the lock on these now** (owner Q1; deleting files still waits for the cutover):

- the period and sky-crew garments, real-people tattoos and 1750s dress (the clothes plan)
- gun and reload polish (musket and pistol reload clips)
- the Two Fires / v6 / Downbelow story, the wonder sky, the galleon, the mammoth
- the invented-peoples test (replaced by Thủy Vân's peoples)
- the loop's rounds on four-element visuals (glyphs, nation dress, element colour bands); its mechanics, balance, Smash
  layer and clips continue
- If any clothes work continues, its `cloth_build.sh` takes the shared lock (it uses a separate Blender lock today).

**Keep on main, because they transfer:** boats (add poling and the rope ferry), household and pathing, NetSession, the
bison generator (as buffalo), the horse system (few horses), first-time tutorial hints, cloth2 recipe types, climbing
and traversal, the leader planner, the soundtrack pipeline.

| What retires | Size | When | Note |
|---|---|---|---|
| Show-like ring dress (15 garments), the four glyphs, the martial-arts stance table | small | Phase 2 | Replaced by peoples' dress, crests and work stances |
| Firearms (`scripts/weapons`), loadout, gun IK, NPC muskets, HuntKit guns | ~17k lines | Phase 5 | Keep bow, throwing spear, Projectile, Weapon, dao. 108 files mention guns. |
| Fort, range, mammoth climb, wonder sky, sky traffic, galleon, SkyBattle, WreckFall, RookWalk, `two_fires.json`, `story_slice` | ~12k lines | Phase 5 | Keep StoryDirector, Objectives, Dialogue, Contact, Bark, Walker, Captivity, MarchStage, the RaidStage pattern |
| `frontier_level.gd`, the 1765 clock, `squares.json`, 1757 layers, the Mohawk vegetation | — | Phase 5 | Thủy Vân runs beside them until then |
| The 35 real peoples in the lists, 129 period garments, period hair | 68 MB | Phase 4 hides, Phase 5 removes | Every face stays |
| North American wildlife and crops, frontier music cues (514 MB WAV) | — | Phase 8, as replacements land | Repo weight |
| `main_story.md`, `maps.md`, `peoples_world.md` | — | Phase 5 | Superseded |

---

## 6. Branch, lock and machine rules

**Facts on 2026-10-05:** main is at `e04be5f`. `worktree-spellcraft` (`6c56011`) contains all of main and is 67 commits
ahead, so main → spellcraft is a fast-forward today. The loop's live branches (`worktree-wf_a5f9a2af-ea8-1..4`,
`wf_1890677f-aae-1/2`, `tb/LOOK-A`, `tb/R2-CLIPS`, `tb/R2-HUD_LESSONS`) touch:

- `data/ring`, `data/bending`, `data/sway/moves.json`, `data/npc/bend_ai.json`
- `scripts/bending`, `scripts/sway`, `scripts/ring`, `scripts/npc/npc_bending|npc_fighter`
- `scripts/ui/{hud,how_to,first_hints,lesson_card,bend_strip,hotbar,equip_wheel,radial_wheel,kit_words}`,
  `scripts/ui/menu/{main_menu,loading_screen}`, `scripts/duel/duel_menu`
- `scripts/core/input_setup.gd`, `scripts/audio/sfx_manifest.gd`, `scripts/look`, `shaders/look`
- `animations/SOURCE.md`, `animations_extra/Frontier_Bend.res`, `tools/anim_author/blender/bend_clips.py`
- `docs/bending_design.md`, `audio/sfx/bend`, `tests/ring|bending|npc|look|ui`

None of them touches `scripts/player`, `scripts/world` or `scripts/boats` today (checked). Round 3's edge-grab ledges
may; check before editing `player.gd`.

**Rules:**

1. **The conversion lives on `thuyvan`**, cut from spellcraft's latest gate commit (`6c56011` if cut now).
2. **Merges flow one way into `thuyvan`, at every gate and at least weekly:** spellcraft's gate commits **and main**.
   `thuyvan` never merges back until the cutover. Nobody commits Thủy Vân work on spellcraft or main.
3. **One imported worktree:** `/Users/kiwimango/Downloads/Frontier/.claude/worktrees/thuyvan`, on the `thuyvan` branch.
   It is the Godot lane: the lead's merges and test runs and T5's greybox work happen there, one at a time. The owner
   plays it through `tools/thuyvan/play_thuyvan.command`. No `.godot` cache is copied without the owner's OK; the first
   import runs under the lock.
4. **Builders without Godot** (T1-T4) work in their own worktrees from `thuyvan`, author files and run Python tests only.
   The lead runs their GDScript tests once per merge in the lane.
5. **Additive until the cutover.** New files, data and scenes. Small edits to shared engine files (the region loader,
   WorldRiver's reaches, `no_firearms`) are listed in each task's report under "cutover notes".
6. **Phase 2a is the loop's own round.** Phases 2b-2e start only when the loop has merged rounds 2-3 (or finished).
7. **The one lock.** Godot and Blender both go through `bin/godot_run.sh` and `bin/blender_run.sh` in this folder. They
   take the loop's lock
   (`/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock`),
   the same one the loop's Godot and Blender wrappers use, so there is one heavy process at a time. Run limits are
   capped at 1100 s, below the 20-minute stale rule, so a live run never looks stale. A second wrapper elsewhere
   (`6af60aef…/godot_run.sh`, `cloth_build.sh`) uses other locks; Thủy Vân work never uses them.
8. **At most two builders at once beside the loop**, and only the lane runs Godot.
9. **No stash.** WIP commits; builders commit only their own paths, with the attribution trailer.

---

## 7. Reviews: what the owner sees, and what stays internal

**Owner-facing (pictures and play):**

| Phase | What |
|---|---|
| 1 | Play the Still Water greybox (about 10 minutes); mood frames (one camera, three looks); running vs still water in-engine; the font in a real screen strip; R1 relief views with A/B/C variants; the names table to mark; storyboards |
| 2 | 2a screen strip; arena before/after; glyphs vs crests; crew lineup; art VFX; Thunder vs lightning; stance sheets |
| 3 | Play C1+B1 (M0), then the slice squares (M1); village kit beside the sheet; boat lineup; karst skyline options |
| 4 | Peoples beside the sheets (both bodies); bold variants; cast lineup with dossier lines; tattoo sheets |
| 5 | Play locomotion, aim and holds after gun removal |
| 6 | Storyboards; kin lineup; Silence variants; rite stills; Account mockups; play the slice |
| 7 | Grey-box silhouettes; motion strips; clearance shots |

**Internal only:** the route graph, flow-speed profiles, pound-level curves, hillshades, frame-ms charts, guard
reports. The owner can't judge numbers, and they are for the builders.

---

## 8. Risks

1. **Collisions** with the live loop and main's sessions. Mitigated by the one-way merges, disjoint path ownership,
   Phase 2a done by the loop itself, and the Day-0 stop list.
2. **Machine load.** One heavy process at a time, now under one lock. Wall-clock time is the real cost; the lock queue
   orders the work.
3. **Content scale.** About 85% of the conversion is art and content. The greybox and M0 give the owner something to
   play early so the look is settled before kits are built.
4. **Water performance is unmeasured.** M0 measures it before any kit.
5. **The WaterNetwork port** touches 40 files; it is split into named port tasks in M1 with their tests run at each step.
6. **Gun removal regresses animation.** Left to the cutover and checked by the owner in play.
7. **The game inventing canon.** Every invented placement is `status: proposal` in `data/thuyvan` until the owner signs
   it off; section 3 removes the inventions the judges found.
8. **Spoilers through data or art.** Section 3.3 items 25-27; the guard's lists never ship.
9. **The show's echo.** Phase 2a removes every visible word; Fox-fire and Root break the four-way symmetry later.
10. **Floodborn read as raiders.** Section 3.1 item 18, and a dedicated review before the burn is built.
11. **Asset sourcing.** The project already uses CC0 downloads (Poly Haven, Quaternius, VSCO). New Thủy Vân assets are
    our own; fonts and the existing CC0 wait on Q2.
12. **Repo weight.** Raw region bakes are ignored; only packed resources are committed, as today.
13. **Reference gaps.** No single Stone Children or Hồ Tinh sheet; the Mộc Tinh sheet is half downloaded.
14. **Phase sizes.** Phase 6 and Phase 8 depend on M1 and 4a; the slice was cut to the Prologue and Act 1 to keep it
    honest.

---

## 9. Owner questions (only these need him; everything else is decided in section 2)

The owner summary asks them in plain words, each with the default that applies until he answers. None blocks Phase 1.

1. **Day-0 stop list** (section 5): stop spending the machine on frontier-only content and on the loop's four-element
   visuals now? Default: no change until he says yes.
2. **Free-licence material:** may we ship one free OFL font family with full Vietnamese (Be Vietnam Pro, Noto Serif),
   and do the CC0 textures already in the game stay? Default: fonts already on the computer; no new downloads.
3. **Book I places only the author can name:**
   - the station destroyed in month 5: Khe Lan Ferry (and what happens to Duyên) or the Fifth Lock's crossing house
   - the Mountain village and its clan (one that submitted to the empire), and the lock town
   - the nine Sacred Rivers' ritual names: which one is counted twice under a seasonal name, and which one is Đá Trắng's

   Default: placeholders marked as proposals, and no river list in the game.
4. **Peoples' Vietnamese names:** pick from the corrected pairs in 3.4 item 31 (a native speaker should check them).
   Default: English names only, Vietnamese shown as "pending".
5. **Thunder:** keep it in the Hearth kit (renamed, new look) or move it to Wind as a pass-storm, mechanics unchanged?
   Default: renamed only, stays in Hearth.

**A request, not a question:** could he re-export the Stone Children and Hồ Tinh sheets, and the whole Mộc Tinh sheet?

---

## 10. Phase 1 tasks

Full texts, ready to dispatch, are in `phase1/T0.md` … `phase1/T5.md`.

| Id | What | Who | Godot | Depends on |
|---|---|---|---|---|
| T0 | Branch, lane worktree, first import, `layout.json`, merge rhythm | lead | lane | — |
| T1 | Canon data, `ThuyVanCanon`, phrase-based guard in `tools/` | builder | no (lead runs its test) | T0 |
| T5 | Still Water greybox: region loader, still reach, tropical clock, no guns, preset, mood frames, launcher | the lane | yes | T0 |
| T3 | WaterNetwork core (channel-local API), Python twin, `water.json` from the layout | builder | no (lead runs its test) | T0 |
| T4 | R1 recipes and `squares.json` from the layout; relief views | builder | no | T0; T3's first commit for carving |
| T2 | Fonts (system by default), `UiFonts`, glyph test, proof | builder | no (lead renders the strip) | T1 merged |

**Dispatch:** T0 first. Then T1 and T5 together (one builder plus the lane). T3 when T1 merges; T4 after T3's first
commit (schema and Python reader); T2 after T1 merges. At most two builders at once beside the loop.

**Merge order into `thuyvan`:** T1, T5, T3, T4, T2. After each merge the lead runs, in the lane: the merged task's tests,
then `tests/world/test_river.gd`, `tests/wildlife/test_fish.gd`, `tests/boats/test_boat.gd`,
`tests/fishing/test_fishing.gd` and `tests/world/test_story_layer.gd`.

---

## 11. Judges' notes

Every severity ≥ 3 problem from both judges is fixed. Where each one landed:

**Judge 1 (canon):**

| Problem | Fixed in |
|---|---|
| Three-holder ending; one player sees all four lines (sev 5) | 3.1 items 1-3 |
| The agreed anchor as a Book IV countermeasure (sev 5) | 3.1 item 4 |
| Tấn's schedule trade in Book I (sev 4) | 3.1 item 8 |
| Arts fixed by people; Ancestor-Bound barred (sev 4) | Section 2 (who learns); 3.2 item 19 |
| Fox-fire as "flames that lie" (sev 4) | 3.2 item 20 |
| H03/H05 leaking into art text (sev 4) | 3.2 item 21 |
| Two maker marks at the Gate Basin; Thủy Vân seal (sev 4) | 3.2 item 22 |
| Spoilers in shipped data; blunt guard (sev 4) | 3.3 item 26; T1 |
| Eight numbered rivers (sev 4) | 3.3 item 25; Q3 |
| Mountain start in Kha's raiding village (sev 4) | 3.1 item 5; Q3 |
| Vân Cổ rescues Kha's retreat; remembers the kin's name (sev 4) | 3.1 item 9 |
| Riverborn kin and pilot erase the absence (sev 3) | 3.1 item 12 |
| Choice F's invented raid (sev 3) | 3.1 item 13 |
| The elder taken by the still water (sev 3) | 3.1 item 6; section 2 (the Silence in play) |
| Vệ, Kor-Va and Bảo's private matters exposed (sev 3) | 3.1 item 7 |
| Arts away from home without the setting rule; soldiers with arts (sev 3) | Section 2 (three bands, soldiers) |
| Mountain Folk given Hearth and Wind; Hearth on Mẹ Lửa's office; Thunder in fire (sev 3) | Section 2 (art homes); 3.2 item 23; Q5 |
| Timing slips (sev 3) | 3.1 item 14 |
| Misread Vietnamese names; merged titles (sev 3) | 3.4 items 30-31; Q4 |
| Khe Lan taken from story #27 without its author; Floodborn up north (sev 3) | 3.1 item 15; Q3 |
| Severity 2 items, also fixed: Mộc Tinh and Stone deaths (3.1 item 16); the full label table (Phase 2a); consultation (3.1 item 17); sheet art rule (3.3 item 27); respawn (section 2) | as listed |

**Judge 2 (production):**

| Problem | Fixed in |
|---|---|
| Nothing playable for 5-6 months (sev 5) | Phase 1 T5, the Still Water greybox (about 3 weeks) |
| M1 builds the wrong squares for the slice; Dragon-Sea start disagreement (sev 5) | Phase 3 M1 re-scoped to B1, C1, C2, B2; Dragon-Sea starts in Vạn Thủy (3.3 item 28) |
| WorldRiver signatures cannot be kept (sev 5) | R1 re-cut z-monotonic (3.3 item 28); M0 keeps WorldRiver; T3's channel-local API; M1 port tasks |
| No single shared lock (sev 5) | Section 6 rule 7; `bin/` wrappers on the loop's lock with a 1100 s cap |
| Frontier work continues until the cutover (sev 4) | Section 5 Day-0 stop list; Q1 |
| Nothing brings main into `thuyvan`; no place for the owner to play (sev 4) | Section 6 rules 2-3; T0; T5's launcher |
| Every builder worktree needs a 1.6 GB import (sev 4) | Section 6 rules 3-4: one imported lane |
| Phase 2 bundled; stance clips in a binary the loop rewrites (sev 4) | Phase 2a-2e; 2e only in the loop's clip lane |
| Render style undecided (sev 4) | T5 mood frames; the owner picks before any kit |
| T5 Gate Basin kit in Phase 1 (sev 3) | Dropped; one shared lock kit in M2 |
| T3 and T4 each invent coordinates (sev 3) | T0's `layout.json`, read by both |
| Guard false positives; spoiler list ships; no voice field (sev 4) | T1: phrase patterns, allowlist, `tools/` with `.gdignore`, `voice` field |
| T1/T2 hidden dependency; guard logic duplicated (sev 3) | T2 after T1; guard in Python only |
| No swimming (sev 5) | Phase 3 M1 deep-water rule; Phase 7 swim track before Riverborn playable |
| The arena flag as a template for an unarmed player (sev 4) | T5's `no_firearms` flag |
| No region loader; compile-time world paths (sev 4) | T5's region loader; M1's per-region texture arrays |
| Phase 4's hidden XL (stature, webbed hands, five peoples at once) (sev 4) | Phase 4a-4c; 3.4 item 32 |
| Phase 6 underestimated (sev 4) | Phase 6 cut to Prologue and Act 1; scripting from Phase 1 |
| No canon cast looks (sev 3) | Phase 4a cast lineup gate |
| Crowds over budget (sev 3) | Section 2 (crowds); M2 crowd cards |
| Charts as owner reviews; too many questions (sev 3) | Section 7; section 9 (five questions with defaults) |
| Parallel lanes overstated (sev 3) | Lock budgets per phase; lock queue |
| The owner's earth mapping not fixed (sev 3) | Section 2 (art homes) |
| Severity 2 items, also fixed: the ring moored in R1 (3.3 item 29); co-op across regions (section 2) | as listed |

**Not done, and why:**

- The five part files were not rewritten line by line. Each now opens with a banner saying this plan overrides it, and
  section 3 is the binding list. Rewriting about 2,000 lines would duplicate section 3 and risk new drift.
- The greybox reuses today's baked terrain and river bed instead of R1's layout. New bakes need T4's recipes and
  packing under the lock, which is M0's job; the greybox is for mood and feel, and for the Silence's look.
- Story routes are fixed as a rule (two lines at most) with defaults per people. The full mission lists for routes
  other than Mountain Folk's are writing work for Phases 6 and 8, checked by the route data test.
