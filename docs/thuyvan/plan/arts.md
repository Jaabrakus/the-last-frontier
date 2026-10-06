# Tidebreak in Thủy Vân, and the peoples' arts (plan, read-only pass, 2026-10-05)

Inputs read: worktree-spellcraft `docs/bending_design.md` (to 6c56011), `data/sway/moves.json` (elements, arts, move labels),
`data/ring/{elements,ring,screens,lessons}.json`, `tests/ring/test_player_words.gd`, `scripts/ring/*` (file list and sizes),
`tools/asset_author/blender/ring_kit.py` (glyphs), the improvement loop's approved kit redesign (round 2 `skills_r2/spec.md`,
`owner_answers.md`) and the Smash layer (round 3 `critic_r2/owner_answers_r3.md`), Bible V3 (D01-D16, H01-H23, P01-P08,
L01-L16, §06 factions, §07 world rules, Book I, dossiers of Mẹ Lửa, Nara and Dương), the v1 bible's world rules, the
paintbook (stories 1, 7, 15, 20), all 15 concept sheets, and the owner's memory notes.

Nothing in any repo was touched. Everything below is a proposal for the owner.

---

## 0. The short version

- **Tidebreak stays Tidebreak.** In the world it is the **gate game of the Flood-Rite Days**: the five unnumbered days at
  the turn of Cửu Giang's year (Bible V3 §03 calendar). It is played on a deck slung across a **festival lock chamber in
  Vạn Thủy**, the Gate Basin, and "knocked into the water" means "given to the river". It is the city's mixed-crew sport.
  Lock crews were always mixed peoples (H05, H10: the river cities were "co-built with Riverborn guides, Floodborn channel
  guardians, and Stone engineering crews"), so the sport carries the sheets' line in its rules: **"Different waters, the
  same sea."**
- **The four kits become four ARTS of places, not four nations.** Each art is a **relationship with a counterparty in a
  place**: lock water, signed stone, a household hearth, a pass wind. Each art has a home community that keeps and teaches
  it. Anyone of any people can apprentice in it (D03, D12: a classification, not a lock-and-key).
  - **Current** (water): Riverborn channel councils and the Dragon-Sea lock guilds.
  - **Stone** (earth): the Stone Houses of Thạch Uyên.
  - **Hearth** (fire): the Mountain Folk hearth-keepers.
  - **Wind** (air): the Mountain Folk Cloud-Pass windwalkers and hawk-keepers, and Dragon-Sea sail-callers in the ports.
- **Why the ring is so loud when the bible's magic is so quiet.** This is the one real tension, and §2 is about it. The
  Gate Basin is a **prepared place** where all four relationships overlap. For five days the lock, the House, the hearths
  and the pass winds lend strongly, as a festival offering. Away from a prepared place, the same practitioners do small,
  useful things. Ritual keepers like Mẹ Lửa think the sport **spends what should be kept**. That is an in-world opinion,
  not an error.
- **What still reads as Avatar:**
  - one element = one nation = one colour;
  - the four-nation dress;
  - the four element glyphs;
  - the show's martial-arts mapping (water tai chi, fire Northern Shaolin, earth Hung Gar, air Baguazhang);
  - pro-bending's three zones and its one-of-each 3v3;
  - fire's lightning and fire-only lightning return;
  - "Fire Jets".

  The fixes, roughly in order of how much they help:
  - add arts beyond four (Fox-fire, Root), which breaks the four-symmetry for good;
  - **separate dress from art** (team sashes over the competitor's own people's clothes);
  - new crests;
  - new movement references taken from the peoples' work;
  - a few renames;
  - the Smash layer retiring the zones (already approved).
- **Open world ↔ ring:**
  - The player meets the sport in Vạn Thủy, starting in the neighbourhood basins (today's Practice and Quick match), and
    climbs to the Flood-Rite final.
  - The arts are learned in the world from their keepers, with an obligation taken (bible rule: power creates a named
    obligation).
  - The art a character carries is the one he brings to the ring.
  - The ring keeps its pure rules: lock time is the only limit, no cues, no slows.
  - The costs live in the world.
- **Effort, honestly.**
  - The renames and strings: **S**.
  - The re-dressed Gate Basin: **L**.
  - The costumes: **L** (they hang on the clothes plan).
  - Arts in the open world (teachers, source-dependent strength, practical uses): **XL**.
  - Each new art (Fox-fire, Root): **XL** apiece. A full kit is about ten moves with guard, own clips, VFX, sounds, bot,
    balance, lessons and tests; the four current kits took four waves and a round to settle.

---

## 1. Where, when and why the sport is played

**The Gate Basin (Vạn Thủy, central lock district; L02).**
- A lock chamber on the festival side of the central lock. The court sits on the central lock itself, per L02 and the
  Vạn Thủy sheet's district map.
- Two great timber floodgates in stone towers close its ends, with blue banners hung from the towers. This matches the
  sheet's "Floodgates & Locks" panel.
- The deck is slung between the lock walls on chains and posts, timber on stone piers. The basin water around it is the
  ring-out.

**When.**
- **The Flood-Rite Days** are the year's five unnumbered days (Bible V3 calendar). Cửu Giang's accounting months stop
  for them, and the city's lock crews hold the gate game in the chamber they keep all year.
- Neighbourhood basins (small canal locks) hold "basin matches" all year. They are the ladder and the practice.
- Other festivals touch it without being it. On the Seventh Tide the nets are blessed (paintbook story 1); its lantern
  nets and bronze bell become the ring's night look and its sting.

**Why it exists (in-world, told in pieces, never as one dump).**
- It began as the lock crews' contest over **who holds the gate** at the flood-rite opening. A mixed crew had to agree
  before water moved.
- Each crew brought its own way of working the water, the stone, the fire for the pitch-pots and the wind for the gate
  vanes. The contest became a game of those ways against each other.
- The court later made it a patronage spectacle: district banners, court prizes and betting houses.
  - Palace accounts call it ancient and imperial.
  - The old quay families say the crews played it before there was a court.
  - This mirrors L02's "competing accounts". Don't settle it.
- **One Book III-consistent plant, no spoiler:** the oldest deck pier in the Gate Basin carries **two different maker
  marks**, like Two Heights Bridge (L16). It is a quiet hint of mixed authorship. It explains nothing, and the Ninth River
  is never touched.

**The rules, translated (the Smash layer reads well in-world):**
- **Stocks** become "**three tallies**". The Floodborn custom (P04) is law spoken before witnesses and "marked on durable
  tally objects". Each competitor has three tally pegs on the gate post, and a ring-out pulls one.
- **Damage %** becomes "**strain**", the number over each competitor. Knock grows with it (owner, round 3).
- **The judges are witnesses.** The Ancestor-Bound shrine houses keep "witness candles" (P08), so a match's result is
  read aloud by three witnesses from different houses. This is the bible's second-witness model in miniature. The round
  and match screens become the witnesses' reading. It is a text change only: no new screen.
- **Teams (3v3, coming):** any three arts, chosen by the crew. **Never one-of-each.** One of each element is pro-bending's
  format. Mixed crews are the point, and so is a crew of three Stone artists.

**Book I through the sport (hooks for the story planner, not decisions):**
- **Opening.** The game can open on the Flood-Rite final just before the Silence ("Year 0, early rains", H23). The
  festival is the last ordinary week, and the news that Đá Trắng has stopped reaches the stands.
- **Riverborn crews are absent this year.** Their licenses are closed (P05 role in Book I: "visible through absent guides
  and closed licenses"). Current is mostly played by Dragon-Sea lock guilds this season, and NPCs remark on the gap.
- **The Stone House crew refuses** a court order to put its stone-masters on "festival service" for the garrison. This
  mirrors Dương's refusal of compulsory Stone service (Book I act II) at street scale.
- **A Floodborn crew from the Reed Marches is barred** after the raid reports (P04 Book I: "read as raiders"). The crowd
  splits.
- **By month 5 (war named too soon)** the court suspends the basin matches and requisitions the gate crews. The sport
  going quiet is how an ordinary player feels the war begin for the wrong reason.

**The player's way in.** A new ordinary person of any people:
1. Practice at a neighbourhood basin (today's Practice and lessons).
2. Basin matches against NPC crews (today's Quick match with named NPCs).
3. Join a district crew: Grain Piers, Naval Basin, Archive Islands and the lock quarters, from the Vạn Thủy sheet's
   districts.
4. The Flood-Rite ladder.

The canon cast may watch, bet, or argue in the stands. They never compete, and they never show arts their dossiers don't
give them (§2.4).

---

## 2. The arts as relationships (and the tension with the bible)

### 2.1 The rule that makes the ring possible

The bible's rules (V3 §07, the v1 world rules):
- magic needs a real relationship or pact, a trained practitioner, and the relevant setting;
- power creates a named obligation;
- spirits are local;
- geography weakens power away from home.

Tidebreak's kits are spectacle: walls, columns, thunder. Both can be true only if:

> **The ring is a prepared place.** A festival basin is built and consecrated so that a lock's water, a House's signed
> stone, carried household coals and a named pass wind are all present and all **lent for the festival**. Outside a
> prepared place, an art works at its everyday scale: real, useful, smaller.

What that gives:
- The ring keeps its pure rules: lock time is the only limit, no meters, no cues, no slows (owner rules). Every cost is
  paid **outside** the match:
  - before it, the leave asked and the offering made;
  - after it, the stones returned and the coal carried home.

  In-ring this is only a 2-second ceremony beat during the existing countdown (each competitor takes the art from its
  source), plus RingArena.rebuild's stones going back to their sockets. That code already runs.
- It explains why there are few venues (a basin, a quarry pool, a stilt platform) and why war doesn't become fireball
  armies. Battlefields are not prepared places, so the bible's logistics-and-spears war survives.
- It gives ritual keepers a view. Mẹ Lửa (C16: "keep mountain rites useful to living households instead of becoming
  instruments of command") would call the sport a spending of what should be kept. That keeps the sport from being "the
  good use of magic".

**This needs the owner's yes (Q1).** If he wants battlefield-scale arts in the open world, the bible's war and its "no
faction is the good one" logistics fall apart, and that is a bigger decision than this plan.

### 2.2 The four arts now in the game

| Art (player-facing) | Was | Home keepers (who teach it) | The relationship | The obligation (the cost) | Weakens | Book I note |
|---|---|---|---|---|---|---|
| **Current** | Water / "Tide" | **Riverborn** channel councils (who "negotiate with river spirits", P05) and the **Dragon-Sea lock guilds** (flood control is their old prestige, P01) | Leave from the water of a **named** channel or lock. Grandmother Reed's kind are counterparties, not batteries (D04). | **What is drawn is returned.** A current is taken on loan and let go back into its channel. Never draw from a nursery: taboo (L08: water quality is habitat). Apprentices pay in dredging and repair labour. | Far from moving water; in stagnant or poisoned water (P05 limits); underground air pockets | Riverborn largely absent (closed licenses); Dragon-Sea lock crews carry it |
| **Stone** | Earth / "Stone" | The **Stone Houses** of Thạch Uyên (guild apprenticeships, P03) | Stone Hearing's contact (P03: "needs contact and practice"): feet on worked or living stone; the stone is **heard**, then moved. | **Every stone moved is signed and set back.** It is the maker's duty: "a maker signs hidden joints". Earth's catch-and-return core is that duty as play; a thrown stone is owed back. The guild apprenticeship is a debt of years. Heat stress is real. | On boards, mud, water, reeds; far from cut stone | The House crew refuses court "festival service" |
| **Hearth** | Fire / "Ember" | **Mountain Folk hearth-keepers.** Mẹ Lửa ("Mother of Fire" is an office, C16) is the senior keeper but never a competitor. | A **coal carried from a named household hearth** in a clay ember-pot, with that household's consent | **The household's fuel and its leave.** A keeper whose pot goes cold loses the art until a willing hearth rekindles it. Adoption through a shared hearth can make anyone kin (P02), which is how a player of any people gets in. | Rain and wet without a covered pot; long marches from home | Chiefs want hearth-keepers for war fires; keepers refuse (Mẹ Lửa's Book I refusal, in miniature) |
| **Wind** | Air / "Gale" | **Mountain Folk Cloud-Pass windwalkers and hawk-keepers** ("sky paths", the Mountain sheet's hawk); **Dragon-Sea sail-callers** in the ports | A **named wind** of a pass or a reach, and a hawk partner who reads it | **A wind called is let go.** Don't hold it past need. The hawk must be fed and flown daily. The pass's tolls and oath-stones (the clan waystone) bind its users. | Below ground (the Buried Kingdom); in closed streets; dead calm | Cloud-Pass is Yên Dao's clan (P02): a corridor-trade people, not raiders |

Mountain Folk keep two arts and Dragon-Sea share two. **That is deliberate.**
- Arts follow communities and places, not blood.
- A Stone Child can be adopted to a hearth.
- A Riverborn can apprentice in a Stone House.
- **No people gets a stat or art bonus** in any mode. A body trait may change a stance or a look, and never a number. This
  is the "races ≠ classes" guardrail (V3 §14: fail if race grants competence).

**Floodborn.** In this pass they play **Current**, in the marsh style: the sluice guardians of H03 and Khar-Ul. Their
crews are physically powerful, and that is a look, not a number. An own art (§3) is optional and later.

**Ancestor-Bound** get **no fighting art**, by design:
- Ancestors give testimony, not power.
- Borrowed memory is not trained muscle (V3 §07).
- Using a voice as a weapon is exactly Father Từ's institutional harm.

Their role in the sport is the **witnesses** (§1). An Ancestor-Bound player character plays any art they have
apprenticed in, like anyone.

### 2.3 Learning an art in the open world

- **One art per character** (recommended; **Q3**). Learning all four is the show's premise, and it is a chosen-one
  pattern the bible forbids.
  - A character may leave an apprenticeship and join another keeper.
  - The old relationship closes: its moves are gone, and its keepers remember that you left.
  - The ring's sport menus (Quick match, Practice) still let the player pick any art per match. That is the sport mode,
    not the character.
- **The keeper's path, one per art:**
  1. find a keeper;
  2. ask leave;
  3. take the obligation: a labour quest, an offering, a taboo;
  4. learn the moves in a fixed order through lessons.

  Today's RingLessons cards become a teacher's drills, so the lesson system is reused. Mastery grows by use (moves.json
  already has `mastery`). Round 2's first-moves-only path is the beginner state.
- **Strength by place**, one readable rule per art, shown as a small line on the art's strip ("Current: strong — moving
  water near"):
  - near the source and in prepared places: full;
  - elsewhere: reduced range and knock (proposal: 60%);
  - against the art's taboo: nothing (Current in a nursery; Hearth with the pot cold).

  This never touches the player's speed or aim (owner: no debuffs). It only scales what the art does.
- **Everyday uses** make the arts part of life, not just combat. Most of them reuse old Sway pieces:
  - Wind into a sail (the Sway's `sail_wind`, built for the frontier galleons) for the boats;
  - Stone to set a bridge stone or open a quarry face (the Form spells: wall, pillar, mend);
  - Current to move a barge through a lock or clear silt;
  - Hearth to light in the rain, smoke a hive, fire a kiln.
- **Fights in the open world** use the ring's moves at the place-scaled strength, and the owner's rules hold:
  - no target cues on NPCs;
  - getting hit never slows the player or hurts his aim.

  **Q6:** does the Smash layer's growing hitstun apply outside the ring? My recommendation is no. Outside the ring a hit
  knocks back and deals damage; there is no strain growth and no hitstun chains.

### 2.4 Canon cast and arts

The canon cast never shows an art their dossier doesn't name:
- Dương: Stone Hearing, Load Path, Anchor Forge;
- Nara: Current Memory, Deep Breath, Silt Map;
- Mẹ Lửa: Ash Rite, Ancestor Fire, Oath Smoke.

These are quiet crafts, and in-game they stay quiet: listening rods, current reading, a rite. If the owner wants a canon
character to throw a Wall, that becomes a bible decision-log entry, not a game shortcut.

---

## 3. Later arts

| Art | Keepers | Relationship and cost | Kit sketch (round 2's shared layout: Jab · Guard · Strike · Push · Dash · Wall · Heal) | Where it is strong | Effort |
|---|---|---|---|---|---|
| **Fox-fire** | **Hồ Tinh** houses (and those contracted to them) | A **witnessed contract**: the flame is lent against a named debt (H09's courts). Overuse raises **Identity Strain** (V3 §07): long play makes your own look flicker. This is cosmetic. It is never a slow or an aim penalty. | Pale flames that **lie**. Feints are the identity: a Strike that splits into a real and a false flame (the false one does nothing, and bots are fooled by it); a Dash that leaves a fox-fire double; a Guard that "takes the debt" (a shot caught and owed back later); a Wall of lanterns that hides sight from bots. **No player debuffs:** illusions fool bots and eyes, never the player's controls. | Ảo Thành, at night, under lanterns | **XL** |
| **Root** | **Mộc Tinh** groves; human grove-tenders by permission (paintbook 14-15) | **Grove permission**, and only where living roots reach (V3 §07: "Cổ Mộc loses access when severed from a remembered grove"). Cost: harvest restraint, and labour owed to the grove (story 15's ditch). | Slow, holding and growing: vines up through the deck's planks, a living-wood Wall that grows thicker the longer it stands, a root Column, a Guard that tangles a shot and drops it. **No roots on players** (round 2 cut every root and slow on a player), so the vines shove and lift, never hold. | Wooden decks and forest stages only. It is the most local art, and that is honest. | **XL** |
| **Silt** (optional) | **Floodborn** marsh reciters and guardians | Leave of the marsh's mud and sluice, kept by mooring councils | Heavy mud shots and sluice surges; a cousin of Current with Stone's weight | Reed Marches stage | **XL** |
| **Ancestors' voices** | — | **Not an art.** See §2.2. | — | — | — |

**Do not make a "Memory" art.** The Ninth River is a Book V truth.

---

## 4. What in Tidebreak still reads too close to Avatar, and the change

| # | What | Why it reads as the show | Change | Effort |
|---|---|---|---|---|
| 1 | **Four elements = four nations = four colours.** The element pick screen; "Earth / Water / Fire / Air" labels; competitor names Stone, Tide, Ember, Gale (`data/ring/elements.json`) | The show's core framing | Rename to **arts**: Current, Stone, Hearth, Wind. Each has a one-line keeper ("kept by the lock guilds and the channel councils") and a line on where it is strong. The pick reads "Your art". Competitor names: the Current, the Stone, the Hearth, the Wind. The real cure is a fifth and sixth art (§3). | S (strings) |
| 2 | **The ring dress** (`tools/asset_author/build_ring_garments.py`, catalog set `ring`, `data/npc/factions.json` element looks): earth ochre and moss tunic; water hooded blue parka with fur trim (the owner already said "too show-like"); fire red sleeveless top with high gold collar and shoulder caps; air marigold tunic with tangerine trousers | Four near-copies of the four nations' dress | **Dress ≠ art.** Competitors wear **their own people's clothes** (the clothes planner's per-people sets, from the sheets: Dragon-Sea shell and pearl and lacquer; Mountain Folk woven layers, feathers, bone; Stone Children wraps and tool belts; Riverborn lotus charms and sheer layers; Floodborn reed armour; Hồ Tinh red and black court dress; Ancestor-Bound tags and robes; Mộc Tinh bark and vine). Over them goes a **crew sash and tabard** in district colours. The art shows as a **token**: a signed stone at the belt, a clay ember-pot, a lacquer water-gourd, a hawk's jess and feather. Retire the 15 ring garments. | L (garments; depends on the clothes plan) |
| 3 | **The four glyphs** (mountain; drop over ripples; three embers; three wind strokes) in `assets/ring_kit/glyphs.*` | A set of four element emblems is the show's iconography | **District crests and maker marks** on the gate towers and banners: the Stone Children's diamond-knot maker mark (Thạch Uyên sheet), the heron (Đồng Lau banner), the lotus (Vực Sen Sâu banner), a lock-gate wheel for the Dragon-Sea guilds, and the Thủy Vân seal on the court box. All are drawn new; no sheet image is copied. | M |
| 4 | **The movement references** (`bending_design.md` Animations: water tai chi, fire Northern Shaolin, earth Hung Gar, air Baguazhang) | This is exactly the show's documented mapping | **New references from the peoples' work.** The 39 approved own clips stay; they are generic stomps, pushes and throws. New and restyled clips are taken from these sources, plus regional martial traditions as a reference only: **Stone** from mason work (setting a stone, a lever heave, a chisel strike, the wide stance under a load); **Current** from poling, rowing, casting a net (the lantern nets) and turning a lock winch; **Hearth** from bellows work, fanning a coal, tossing a pitch-pot and banking a fire; **Wind** from launching and recalling a hawk, a sling cast, and the long stride on a hanging bridge. All clips are authored our own way in Blender (AGENTS.md, animations/SOURCE.md); nothing is imported. | M (4 stances) + per new clip |
| 5 | **Pro-bending's three zones**, "knocked back a zone", and 3v3 one-of-each | The show's sport format | Already retired by the Smash layer (deck = stage; out only in the water). 3v3 is **any three arts**. Drop "zone" from strings, lessons and round reasons ("winded in the last zone", "ground held") once round 3 lands. | S (after round 3) |
| 6 | **Lightning**, Punch's partner, and "**only fire sends lightning back**" | Fire-only lightning and its redirection is one of the show's signature beats | **Keep the move** (owner rule: never change a move's identity unasked). Recommend renaming it **Thunder** and giving it a different look: a white-gold strike that **falls from above** along the aim line, called from the high passes (a Hearth-keeper's storm rite), not a fork from the fingertips. Its perfect Parry return stays as a mechanic. **Q4.** | S (rename) / M (new look) |
| 7 | **"Fire Jets"** (jet propulsion from the feet) | A show-specific technique | Rename **Updraft** and give it a heat-shimmer lift with sparks, not twin flame jets; or **Q5:** move it to Wind's kit and give Hearth the Step only. | S / M |
| 8 | **Water's whip, spear and heal**, earth's boulder catch, air's glide | Generic enough on their own | Keep. Round 2's renames (Lash, Turn, Wind Ball, Wind Guard) already help. | — |
| 9 | **"Element" everywhere on screen** (strip, HUD, menus, F1 lines, lessons' `{what}`) | Supports #1 | "Art" on screen. Code ids stay (`earth`, `water`, `fire`, `air`) so nothing breaks: a label layer only, read from `elements.json`. | S |
| 10 | **Code names** `bend*`, NpcBending, BendStrip, `bending_design.md` | Not player-facing | Leave them. Renaming the code is a big churn for no player benefit. Extend `tests/ring/test_player_words.gd` so it also scans `data/sway/moves.json` labels, `data/bending/schemes.json` and the open world's strings once arts reach the world. | S |
| 11 | **The ring's cel VFX palette** (fire orange-red, water blue, air white, stone brown) | Mild | Per-art looks that belong to the world: Hearth a gold-amber coal glow with ash flecks; Current green-blue lock water with lotus-pale foam; Stone with maker-mark cracks and chalk dust (Thạch Uyên's chalk circles); Wind with feather-and-ribbon streaks. The owner said no cel shading on the look: check the bands. | M |

---

## 5. The arena in the Vạn Thủy look (the Gate Basin)

Today's ring (`data/ring/ring.json`, RingArena, RingDressing at 1238 lines, `assets/ring_kit`) has:
- a 14 × 34 m deck over a water tank;
- stands;
- gateways, lacquered pillars, upturned eaves, paper lanterns, tile canopies;
- noon, golden and night lights.

Most of it maps straight over, so the deck numbers and the rules stay untouched.

| Part | Today | Gate Basin |
|---|---|---|
| Ends | gateways over tunnels | **Two timber floodgates** in stone towers (iron-strapped leaves, winch wheels, blue banners, as on the sheet's "Floodgates & Locks"). The ring-out end is the open water before a gate. |
| Water | a tank | **The lock chamber**: stone walls with patched canal steps, tiled drains, silt lines, eel baskets (L02's sensory anchors) |
| Deck | stone neutral, board zones | Timber and stone on piers and chains. Two maker marks on the oldest pier (§1). The Smash stage edge gets ledges you can grab (round 3), shaped as gate beams. |
| Stands | stands | The **lock walls**, plus **boats moored in the basin** as stands (the game's boats exist), with crowds of every people (the Common Folk lineup) |
| Lights | noon / golden / night | Night is the festival: **lantern nets on lines** across the chamber (paintbook story 1), blue oil lamps in doorways. Golden is the Flood-Rite afternoon. |
| Stings | gong, bell, tick (BendSounds.event, ready) | **Bronze bells** for the count and the bell (L02's "bronze bells"); a gate-winch ratchet for "go" |
| Court box | — | Above one gate tower: the court's patrons, plus the **three witnesses** at their candles reading the result |
| Water grates (Current's pools) | grates | **Sluice ports** in the deck that the lock feeds |
| Stone sockets | sockets | **Signed stones** set in the deck by the House crew before the match |
| Braziers | night braziers | **Hearth posts**: each side's ember-pot sits in a bronze cage at its end |

**Later stages** (Smash-style stages fit the regions; each is L):
- the **Thạch Uyên quarry pool** (a stone deck over a flooded quarry, cranes, kilns);
- the **Đồng Lau stilt platform** (reed and timber over blackwater, heron banners);
- the **Trường Sơn hanging-bridge deck** (a wind-strong stage);
- the **Lâm Uyên root bridge** (Root's home; later).

Each stage favours one art's source a little. That is "power is relational", made into stage choice.

**How it gets made:** the same pipeline as today. `tools/asset_author/blender/ring_kit.py` gains the floodgate, tower,
winch, lantern-net line, crest banners and mooring boats. RingDressing places them. RingLook takes the new night.

---

## 6. Review images (the owner judges by eye)

Every step ships with a lineup before anything is called done. All are built with the existing tools
(`tools/bending/vfx_lineup.gd`, the ring kit's renders, the garment contact sheets). They are scheduled **after** the
improvement loop releases the Godot and Blender lock.

1. **Arena before/after**: today's ring vs the Gate Basin, at the same three camera angles × noon, golden and night.
2. **Crest sheet**: the four old glyphs vs the district crests and maker marks.
3. **Costume lineup**: today's four element dresses next to 8 peoples × 1 crew sash, both bodies, front and back.
   Separately, the four art tokens close up.
4. **Art VFX lineup**: today's fire, water, stone and air next to Hearth, Current, Stone and Wind (from `vfx_lineup.gd`),
   plus Thunder vs today's lightning.
5. **Stance contact sheets**: the four restyled stances (mason, poler, hearth, hawk-keeper) vs today's four.
6. **Screen mock**: the art pick, the strip and the witnesses' round reading, before/after (strings only).

---

## 7. Build order (after the improvement loop's rounds 2-3 merge, to avoid fighting its files)

1. **Words**, S. Two parts:
   - The art labels and lines in `data/ring/elements.json`, `screens.json` and `lessons.json`, plus the `moves.json`
     labels Thunder and Updraft (pending Q4 and Q5).
   - The player-words test widened.
   - Vietnamese diacritics depend on the font work (another planner's part).
2. **Crests, VFX palette and Thunder look**, M, with lineups 2 and 4.
3. **The Gate Basin**, L, with lineup 1.
4. **Crew sashes, art tokens and peoples' dress on competitors**, L. Depends on the clothes planner. Lineup 3.
5. **Stances restyled**, M, with lineup 5.
6. **Arts in the open world**, XL:
   - keepers;
   - obligations;
   - one art per character;
   - place strength;
   - everyday uses through the old Sway pieces;
   - Vạn Thủy's basin ladder and crews.

   Depends on the world map and the story planner.
7. **Fox-fire**, then **Root**, XL each.

---

## 8. Owner questions

1. **Prepared places.** Is the ring's spectacle OK as a festival-scale art that only prepared places allow, with
   smaller, useful arts elsewhere? The alternative is full-power arts everywhere, which changes the bible's war.
2. **Art names.** Current, Stone, Hearth, Wind (competitors "the Current", "the Hearth"...)? For a Vietnamese name for
   Tidebreak, "Phá Triều" is a candidate, but *triều* also means "court/dynasty", which reads as "breaking the court".
   Wanted, or avoid?
3. **One art per character** in the open world? The sport menus still allow any art per match.
4. **Lightning → Thunder** that falls from above, with the perfect-Parry return kept?
5. **Fire Jets → Updraft** (renamed and re-looked), or move it to Wind?
6. **The Smash layer outside the ring.** Strain growth and hitstun only in the ring? Recommended: yes, ring only.
7. **Floodborn.** Current (marsh style) for now, with Silt as an own art later, or no art?
8. **Dress ≠ art.** Retire the 15 ring garments for peoples' dress plus crew sashes?
9. **The Book I hooks**: open at the Flood-Rite final; the Riverborn absent; the Stone crew's refusal; the Floodborn crew
   barred; the matches suspended at month 5. Pass them to the story planner?
