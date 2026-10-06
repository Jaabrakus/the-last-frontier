# Thủy Vân: the peoples as characters (creator, NPCs, bodies, dress, names, fonts)

Planning only. Nothing in any repository was edited. Sources: bible V3 §01 (D02, D03, D04, D12, D13), §04 (P01-P08),
§06 (naming), §07 (limits); the series bible v1 §4-5; the paintbook's paint cues; the concept sheets (the peoples' sheets,
Common Folk lineup, the bible's two group sheets); the code on branch worktree-spellcraft (which contains all of main:
`git log HEAD..main` is empty).

Effort scale: S = up to 1 agent-day, M = 2-4 days, L = 1-2 weeks, XL = 3+ weeks. Each size includes the owner's
review round (he judges by eye), not the waiting.

---

## 1. What the game has today (measured, not assumed)

| Piece | What it is | What it means for Thủy Vân |
|---|---|---|
| Skeleton | `Actor_B`, 291 bones (`tools/character/rig/actor_b_skeleton.json`). Deform bones and twist/skirt helpers, plus facial joints (jaw, lids, brows) the clips don't play. **No tail, ear or extra bones.** | Every human-shaped people uses it as-is. Tails, fox ears and vines need *extension bones* (§3). |
| Body | `assets/character/body/body.glb`: body v4 = the MakeHuman base mesh (CC0), fitted to Actor_B. The head is the v3 MakeHuman head with 30 `face_*` shapes plus `sex`, `sex_head` and `blink`. 38 hide regions (`catalog.json` regions; the hide mask has 64 bits, so 26 are free). | Fine for Dragon-Sea People, Mountain Folk, Ancestor-Bound, Riverborn and Stone Children. **A MakeHuman head can't become a crocodile snout or a bark face.** Floodborn and Mộc Tinh need new bodies and heads. |
| Proportions | `stature` exists in looks, but the player's body doesn't use it (docs/peoples_world.md). `ChildProportion` (`scripts/companion/child_proportion.gd`) is a full proportion system: it bakes per-part scales into the body, hair and garment meshes and their binds, then moves bone offsets after the animation. Rotations are untouched, so **every clip still works**. | Generalise it into a per-people proportion step: the Stone Children's broad, dense build, the Floodborn's bulk, the Mộc Tinh's slender height. |
| Skin | `skin.gdshader`: melanin along 12 human anchors, undertone, haemoglobin, freckles, weathering. `people_trait.gdshaderinc` adds a world people's mark (keelstone flecks, Form veins). The tattoo system takes 8 tattoos per body from a 4x4 atlas. | The trait include is the right place for scale patches, mineral plates and gill shading. Blue-grey Riverborn skin and slate Stone Children skin are not on the melanin line, so they need a "pigment" skin mode. |
| Peoples data | `assets/character/body/peoples.json` holds 35 real peoples. `data/customizer/world_peoples.json` is the invented-peoples test (Downbelowers, Driftborn, Keelfolk, the Etched), read by `CharacterPeoples` (`world_listed`), with emblems in `people_emblem.gd`. Rule (2026-10-02/04): **every real face stays a face of every invented people.** | This test machinery is the template. Thủy Vân's eight replace the four, and the 35 real peoples leave the creator but keep their faces. |
| NPCs | `NpcBody` puts the same Actor_B in a look (`NpcFactions.look_for` takes a peoples preset and dresses it in a faction outfit). Its clips come from `animations/Actor_B.res` and `animations_extra/Frontier_Own.res`. | Human-shaped NPC peoples come almost free once their presets exist. Non-human NPCs need their body kit first. |
| Garments (cloth2) | 60 recipes in `tools/character/cloth2/garments`. Recipe types: shirt, coat, waistcoat, apron, neckwear, caps, rigid hats, leggings, straps, plus the peoples' types from 2026-10-03: **robe (crossed), tunic, trousers, wrap_skirt, drape, cloak, head_wrap, lathe_hat, hose, wound sash**. 15 slots. Garments are fitted to the female reference body and transferred to `sex` by wrap. Skirts hang on 3 helper bones. Builds run in Blender 5.2 on the rig copies (memory: reference_cloth2-rig-source; one Blender at a time). | Most Thủy Vân everyday dress can be built from these types: crossed robes, wrap skirts, wide trousers, sashes, and the conical hat as a `lathe_hat`. Missing: leg wraps, a feather/fringe mantle, hanging tags/tassels/jade, sheer layered over-robes with long sleeves, reed/net armour, tail openings. |
| Tidebreak dress | The `ring` set: `ring_water_parka` (fur-collared hooded parka), `ring_fire_top` (high gold collar), `ring_air_tunic` (split knee tunic), `ring_earth_tunic` (crossed wrap tunic). | These read as the show's four nations. Under the "no show words or nations" rule they should be **replaced by peoples' dress** (Riverborn/Dragon-Sea for water, Stone Children/Mountain Folk for earth). |
| Fonts | **The project ships no font files.** `hud.gd`, `how_to.gd`, `lesson_card.gd` and `first_hints.gd` use `SystemFont` lists (Baskerville, Hoefler Text, Georgia...; Avenir Next, Helvetica Neue...). Every other control uses Godot's built-in default font. | See §6. On this Mac, Baskerville, Georgia, Avenir Next, Helvetica Neue, Times and Arial cover every Vietnamese letter in the bible's names. **Hoefler Text is missing 22 of 28** (it is second in the HUD's serif list), and Menlo is missing 6. The default font's coverage was not checked (needs Godot). |
| Swimming | None (only fishing). | The Riverborn and Floodborn water traits, and the Stone Children's poor buoyancy, have nothing to attach to until a swim/wade system exists (traversal workstream). |

Reference gaps in the sheets folder: individual sheets exist for Dragon-Sea, Mountain Folk, Riverborn, Floodborn and
Ancestor-Bound. **Stone Children and Hồ Tinh have no single sheet** (only the group sheets and the Common Folk lineup),
and the Mộc Tinh sheet is an **incomplete download** (`New Folder With Items/image-gen-5.png.download/`, the bottom 60 %
black; a copy is in this folder as `ref_moc_tinh_partial_sheet.png`). The numbering (image-gen-1, 2, 6, 7, 8) suggests
image-gen-3 and -4 were the Stone Children and Hồ Tinh sheets.

---

## 2. Creator structure the bible asks for

D03: the eight peoples are **a historical social classification, not eight species**. Record **ancestry, culture,
faction and supernatural condition separately**. Ancestor-Bound is a human lineage and condition, and unbound humans
exist. D12: no racial key, because skills can be taught. P02: Mountain Folk have *no innate climbing mastery*. So:

- **People** (ancestry and body): the eight, grouped by homeland. It sets the body kit, skin and eye ranges, face pool,
  dress and name tables. **It gives no stat bonus** (no races = classes).
- **Raised in** (culture and home region): Cửu Giang Delta / Vạn Thủy (L01-02), Trường Sơn (L04), Thạch Uyên (L05),
  the Reed Marches / Khar-Ul (L06-07), the Deep Lotus Reaches (L08), Ảo Thành (L09), Lâm Uyên (L10), the Southern Delta
  Provinces (L12). It defaults to the people's homeland, but a Dragon-Sea fisher raised in the Reed Marches is valid. It
  sets the starting place, the first teacher (which art you are offered first) and the everyday clothes. It never locks
  an art: any people can learn any art from a teacher (D12), and the arts weaken away from their home (§07).
- **Condition** (only where it applies): human lineages get *Bound / Unbound* (Ancestor-Bound). Hồ Tinh get *features
  shown / hidden in public* (§4.6).
- **Mixed ancestry**: keep the existing "Mix with" for the human-shaped peoples (Dragon-Sea, Mountain, Ancestor-House,
  Riverborn, Stone Children: skin, scale or mineral amount blend). **Mixing across body kits (Floodborn, Mộc Tinh) is
  an owner question.** It also decides what the household's `ChildLook.from_parents` does.
- **Body type 1 / 2** as now, for every people (Sira-Khan, Sha-Ra and the Root Mother show that women exist in every
  people).
- Spirits (Grandmother Reed, the White Stag, the Lantern Child) and Hollow composites (the Quiet Woman, the
  Thousand-Mouth) are **not creator options** (D04). The Root Mother is a rooted elder, so she is a **set piece**, not
  an Actor_B body.

Player-facing text must not spoil: no Ninth River or Memory as a river, no Hollow Tide by name in Book I notes, no
"first guardians" truth, no Drowned King verdict. The map sheet's legend lists "Sông Kỳ — Memory, the Ninth River". Any
in-game map or lineup made from it must drop that line for Book I.

---

## 3. Shared engineering the non-human bodies need (build once)

1. **Extension bones.** A `BodyExtensions` step adds named bones to the Actor_B `Skeleton3D` (`add_bone`) *before*
   `CharacterBodyMesh` builds its Skin. Today a bind to a missing bone falls back to the nearest ancestor with a
   warning, so the order matters. Sets: `tail_01..08` (Floodborn), `fox_ear_l/r` (Hồ Tinh), `fox_tail_<k>_01..05` for
   1-9 tails (Hồ Tinh), `vine_<k>_01..04` (Mộc Tinh). Clips never key them, so the whole animation library plays
   unchanged. Check that the AnimationTree caches its tracks after the bones exist.
2. **Secondary motion.** Use Godot 4.7's built-in `SpringBoneSimulator3D` (in Godot since 4.4) or the project's own
   pendulum driver (`wrinklemaps` queue). Add a pose-driven layer (tail lifts in a crouch, counter-swings in turns,
   curls when idle, rests on the ground when lying; ears perk and flatten) and collision (ground ray, the climbing
   wall's plane, seats). LOD like `NpcBody`: frozen past a distance, stepped off-screen.
3. **Proportions.** Generalise `ChildProportion` into `PeopleProportion`, with per-people group scales from data. It
   bakes into the body, hair and **garments** (it already does garments), so the clothes follow.
4. **Regions.** New hide/occupy regions in the 26 free bits: `tail_root`, `tail`, `fox_ears`, `snout`, `crest`. A
   garment declares a tail opening, and the hide mask stops skin showing through it.
5. **Per-kit creator rows.** Face sliders, brows, beards, earrings and nose rings belong to the MakeHuman head
   (`FaceExtras` landmarks). A non-human kit lists its own rows (snout length, crest, scute pattern; crown size, bloom),
   so `CreatorOptions` must ask the kit which rows exist.
6. **World clearance.** Floodborn bulk and Mộc Tinh branch crowns (30-50 cm above the head on the sheet) meet doors,
   beds, chairs, boats, horse saddles and climbing walls. Agree a doorway standard with the world/building workstream,
   and cap crown height in the creator.

---

## 4. The eight peoples

Visual notes are from the sheets. Written canon governs (the bible's appendix says the sheets are reference only).

### 4.1 Dragon-Sea People (P01): playable, phase 1
- **English title / Vietnamese:** "Dragon-Sea People, People of the Estuaries". The sheets disagree on the Vietnamese
  (*Dân Hải Tộc* on the people's sheet, *Dân Biển Rồng* on the lineup), so the owner picks.
  Homeland: Cửu Giang Delta and Vạn Thủy, Capital of the Waters.
- **Body:** human (the existing body). Features (P01: "some carry scales, reflective eyes, or slight webbing"; the
  paintbook: "the absence of scale pattern along the wrists" marks a human):
  - **Scale patches**: a new trait kind (iridescent scales at the wrists, shoulders, temples and cheekbones), with an
    *amount* row from None (most commoners) to Marked (court houses). No row is tied to rank.
  - **Reflective eyes**: an eye-shader option (a tapetum-like glint at night).
  - **Slight webbing**: the Riverborn web shape (§4.5) at 20-30 %.
  - **Fin ears**: the sheet's finned ear may be an ornament (the same shape is drawn on the Riverborn). Owner
    question. If real fins, they are an ear attachment shared with the Riverborn kit.
- **Skin / hair / eyes:** light to medium, cool or neutral undertones; long black hair (buns, topknots, loose); grey,
  brown or gold eyes.
- **Everyday dress** (Common Folk: dock workers, fishers, floodgate clerks): a crossed short robe or tunic (`tunic`),
  wide trousers or a wrap skirt, a sash, rope and net gear, the conical hat (`lathe_hat`), sandals or bare feet; shell
  and pearl ornaments.
- **Formal dress** (the people's sheet): layered sheer silk over-robes with long trailing sleeves and hems, a lacquered
  waist plate, shell and pearl tassels, a fin-shaped hair crown. The **sheer, trailing layers clip badly in action
  clips**, so they are NPC, court and cutscene dress first. For the player, a shortened variant.
- **Names:** Vietnamese order, family name then given name (Lạc Thiên, Trần Yên, Phạm Dực, Tạ Quang, Bùi Khánh, Mai
  Sương). Titles in English before the name (Prince, Admiral, Chancellor, Lieutenant). D13: rank is earned, so a player
  starts untitled.
- **Lifespan in play:** 80-110. Nothing changes in Book I's five months. Age is an appearance choice.
- **Limits in play:** no universal underwater breathing, no fire breath, no royal spell competence (P01). No trait bonus.
- **Needs:** a trait kind (S), an eye-shader option (S), garments (L), names (S).

### 4.2 Mountain Folk (P02): playable, phase 1
- **Title:** "Mountain Folk, People of the High Places" (*Sơn Dân* / *Dân Núi*). Homeland: Trường Sơn, the Endless
  Range. Clans are institutions, not peoples: Stone-Ridge, Cloud-Pass, High-Pine (P02).
- **Body:** human; a leaner, wiry build through `PeopleProportion` (light). No innate climbing bonus (P02).
- **Skin / hair / eyes:** medium to deep, warm and weathered (more `weathering`); long black hair, topknots, braids,
  feathers worked into the hair (a hair accent).
- **Marks:** **clan tattoos** (face, arms, chest: "marks of clans, journeys, and ancestors"). These are our own designs
  in the tattoo system. The atlas needs more than 16 cells (a 4x8 or second atlas), plus face placements (space 3).
  Design them as our own motifs. Do not copy real highland peoples' brocade or tattoo patterns (the bible: "none
  describes a real population").
- **Everyday dress** (hunters, herders, porters): a woven geometric wrap or tunic, a fringed shoulder mantle, a wrap
  skirt or short trousers, **leg wraps** (new recipe), a carrying basket and pack, bone and tooth necklaces, feathers.
- **Formal dress** (oath gatherings): the full feather-fringe mantle over a layered woven robe, a bronze disc, tassels.
  The fringe mantle needs a new recipe (strips on the skirt helpers; `fringe.gdshader` exists).
- **Names:** often one syllable (Hạc, Tấn, Nhạn, Khiêm) or two (Kha Vũ, Yên Dao, Bạc Sơn). Shown as "Kha Vũ of
  Stone-Ridge". Office titles are not names: *Mẹ Lửa, Mother of Fire* is "an office and form of address". Adoption
  through a shared hearth makes a clan member (P02), so the player's clan can be chosen, not only inherited.
- **Lifespan in play:** 70-95. **Limits:** none innate. Cold and falls hurt like anyone.
- **Needs:** proportions (S once §3.3 exists), tattoo designs and atlas (M), garments incl. leg wraps and fringe mantle
  (L), feathers as hair accents (S-M).

### 4.3 Stone Children (P03): playable, phase 1
- **Title:** "Stone Children, Mountain-Descended" (*Nhi Thạch*). Homeland: Thạch Uyên, the Stone Valleys. Stone Houses
  are guilds, and "Stone Children is not a clan synonym".
- **Body:** human-shaped, "dense bodies and mineralized skin patches, not living invulnerable rock". A broad, heavy
  build through `PeopleProportion` (wider trunk, thicker limbs, bigger hands). It reads like the sheets without a new
  mesh.
  - **Mineral skin**: a new trait kind (polygonal plates with fine cracks, a little jade or quartz in the seams, matte
    and stone-like), with an amount row (patches to most of the body).
  - **Skin palette**: slate, grey, sandstone and ochre. This needs the **pigment skin mode** (a base colour plus
    variation, not melanin), shared with the Riverborn.
  - Eyes: jade green, grey, amber.
- **Everyday dress** (masons, quarry hands): a sturdy crossed tunic over trousers, a leather apron, leg wraps,
  chisels in red cord, carved jade pendants.
- **Formal dress** (guild regalia): a layered robe with a carved jade plaque belt, the House's maker's mark woven
  in (Thạch Uyên sheet: "A Maker's Mark").
- **Names:** two Vietnamese syllables with craft or mineral sense (Dương Sắt "iron", Lệ Thạch "stone", Tạc "carve").
  "Tạc of House <name>". Titles: Stone-Matron, Master, apprentice.
- **Lifespan in play:** 160-240. A 70-year-old Stone Child is young, so the creator shows "age" per people.
- **Limits in play:** **poor buoyancy** ("many require more buoyancy on boats": they sink, so they need a float, a
  boat, or wading). **Heat stress** (express it as stamina recovery, never speed). **Stone Hearing** is an art that
  needs contact and practice: touch a wall or ground to read **structural stress, seams and hollows**. It must never
  show enemies (no target cues).
- **Needs:** proportions (S-M), mineral trait (M), pigment skin mode (M, shared), garments (L), Stone Hearing hook (M,
  depends on the arts workstream).

### 4.4 Floodborn (P04): NPC in phase 1 (Book I needs them), playable phase 2-3
- **Title:** "Floodborn, of River and Mountain" (the sheets give *Nước Sinh Tộc* and *Trạch Sinh*; the people's sheet
  uses the same Hán 水生 as the Riverborn sheet, so pick one). Homeland: Đồng Lau, the Reed Marches; Khar-Ul, the Old
  River Hold.
- **Why they are needed early:** Book I's role is "read as raiders", and the war begins for the wrong reason. The
  player meets Floodborn in Book I even if they cannot be one yet.
- **Body (new):** a crocodilian humanoid, "not humans in costumes". Plantigrade clawed feet on the sheet, a long heavy
  tail to the ground, a long snout with teeth, yellow slit-pupil eyes, a crest of spines in place of hair, scutes on the
  back, shoulders and limbs, a paler belly, scars ("each mark a story"). Air-breathing and amphibious.
  - **Approach:** keep the Actor_B skeleton (all clips), add the tail chain (§3.1) and use the `jaw` bone for the snout.
    Generate the mesh with the project's own procedural anatomy approach (the precedent is `tools/horse/build_horse.py`
    with the bison's `anatomy.py`), or author it AI-assisted in Blender. Skin it to Actor_B plus the tail. No
    downloaded models.
  - **Head:** new, with its own rows (snout length and width, crest height, scute pattern, scars, eye colour). The
    MakeHuman face sliders, brows, beards and ear jewellery don't apply.
  - **Hands:** the rig's five fingers, with heavier knuckles and rigid claw caps.
  - **Material:** a scale shader (a scute normal map in UV, colour bands from dark olive to a pale belly, a wet sheen
    that rises after swimming).
- **Animation (the snout and tail change it):**
  - A **posture overlay** (a little forward lean, a heavier stance) so human clips don't read human.
  - **Tail:** procedural plus pose-driven (counterbalance, crouch lift, lying flat, ground collision).
  - **Hand-to-face clips** collide with the snout: eating, drinking, the bow's anchor at the cheek, hood or hat
    gestures. They need Floodborn variants or IK offsets (the bow anchor moves to the jaw's side).
  - Sitting, lying and beds need a tail-aside variant. Riding a horse is an owner question (see questions). Climbing
    needs the snout turned aside on the wall.
  - A jaw idle (breathing, an open-mouth threat) uses `jaw`.
  - New clips come from `tools/anim_author` (own Blender clips), recorded in `animations/SOURCE.md` like the bending
    clips.
- **Dress (their own garment set, fitted to their body):** reed and net "living armour", cured hides, a bronze disc,
  shell, bone and river-stone tassels, red sashes, **front and side skirt panels with the back open for the tail**.
  Human garments do not refit; tail openings and thick limbs make a separate set. Everyday dress for ferrymen and
  reed-workers: a net vest, a waist wrap, baskets.
- **Names:** hyphenated hard syllables (Ruk-Khan, Sira-Khan, Mok-Ra, Sha-Ra, Kor-Va, Tal-Kesh) or one word (Urok).
  "Khan" stays a Floodborn naming element and is not glossed as a real-world institution (bible §06). Affiliation:
  "of <name> Mooring" (mooring citizenship, §06).
- **Lifespan in play:** 100-150. **Limits:** air-breathing with **trained** long breath-holds; **dry marches damage
  skin** (the shared *wetness* need: a slow cost to health or recovery while dry, refilled by water); **cold slows
  activity**. Under the owner's rule this should be **stamina and art strength, never movement or aim**. Owner
  question. They need substantial food (survival hooks).
- **Effort:** XL for body, head, tail, material and garment set. Plus L for animation adaptations before it is
  *playable*. **An NPC-only first cut is still L-XL** (body, tail, posture, a small clip set: idle, walk, run, the
  spear, hits, deaths).

### 4.5 Riverborn (P05): playable, phase 1
- **Title:** "Riverborn, Descendants of Water Spirits" (*Thủy Sinh Dân*). Homeland: Vực Sen Sâu, the Deep Lotus
  Reaches. In Book I they are mostly visible "through absent guides and closed licenses": rare, licensed navigators.
- **Body:** human with features:
  - **Skin:** blue-grey, teal and silver ("luminous skin", "silver skin tones" in the paintbook). This needs the
    **pigment skin mode** (§4.3), plus a subtle sheen and iridescent scale patches (the scale trait).
  - **Gills:** slits along the neck. A neck shape key on the body and shading in the trait include, with a slow
    shader flutter while breathing water.
  - **Webbed, long fingers** with dark nails. MakeHuman's hand has no web faces, so the body build adds web geometry
    between the fingers, hidden by a shape key at 0. Gloves are disallowed for webbed hands, or get their own fit.
  - **Fin ears** (an ear attachment; the jewellery landmarks move to the fin).
  - Eyes gold or amber.
- **Everyday dress** (lotus gatherers, pilots): a light crossed tunic and wrap skirt, a sash, the **conical hat with
  lotus** (`lathe_hat` plus an ornament), bare feet, lotus and pearl charms, a basket.
- **Formal dress:** layered sheer green-grey robes, lotus belt charms, a pearl lantern. Same caution as Dragon-Sea
  formal (NPC first).
- **Names:** short (Nara, Lụa). "Nara of <channel>". Channel rights are their political unit (§06).
- **Lifespan in play:** 90-130. **Limits:** gills work only in **oxygenated** water. **Stagnant or poisoned water
  suffocates**. **Dry travel needs moisture and suitable clothing** (the same wetness need as the Floodborn, a
  different curve). Needs the swim system.
- **Needs:** pigment skin (M, shared), gills (M), webbed hands (M-L: the body build), fin ears (S-M), garments (L).

### 4.6 Hồ Tinh (P06): NPCs in human form in phase 1; playable phase 1b-2 (the cheapest non-human kit)
- **Title:** "Hồ Tinh, the Fox-Blooded". Homeland: Ảo Thành, the City of Illusions. Courts (H09) are institutions.
- **Book I fit:** "hidden brokerage". They pass among others, so in Book I most Hồ Tinh NPCs **are drawn in human
  form**, which costs nothing beyond presets. Their true form is a reveal.
- **Body:** human, plus **fox ears** (fur attachments on `fox_ear_l/r`, procedural perk and flatten) and **1-9 fox
  tails** (fur strips or the existing `fur_shell.gdshader`, on spring chains). P06: "Tail number is not a simple power
  level", so tail count is a **cosmetic choice**, never a stat. Eyes amber or gold, fox-like eyeliner; human skin
  range.
- **Condition row:** *Features shown / hidden in public*. The bible's shapeshifting is appearance only. It "does not
  grant another person's memories or skills", and "repeated identities can strain self-recognition". In play, a hidden
  form or a disguise as another human-shaped people builds **Identity Strain** (bible §07, a 0-10 track). Strain shows
  as social tells (ears or a tail slipping into view, NPCs noticing), **never as a movement or aim penalty**. It needs
  rest or an "external anchor" (a trusted NPC).
- **Animation:** tails clip the legs when running and the seat when sitting. They need collision capsules against the
  thighs and seats, and a lifted pose in sprint and crouch. The ears flatten under hats (an `ears_flat` shape or
  hat ear slots).
- **Everyday dress** (market brokers, messengers, performers): a shawl, a crossed robe, a skirt with a **tail
  opening**, a basket, contract letters, talismans, a fox mask.
- **Formal dress:** red-black court silk with gold embroidery, a folding fan, hanging talisman tags, hair ornaments.
- **Names:** three uses, *public, contracted, private* (P06). The creator sets the public name, and the private name
  is stored and never shown to NPCs. The names are poetic (Minh Nguyệt "bright moon", Tuyết Lan "snow orchid",
  Bạch "white"). Titles Lady and Lord. Meals begin by naming suspended debts (a social ritual hook).
- **Lifespan in play:** centuries possible, but "violence and spiritual debt still kill". Apparent age is chosen.
- **Effort:** L (ears, tails, springs, fur, tail-opening garments, the shown/hidden row). Identity Strain is M and
  belongs to the systems workstream.

### 4.7 Mộc Tinh (P07): NPC phase 2, playable phase 3 (as a young mobile spirit)
- **Title:** "Mộc Tinh, the Tree Spirits" (the bible says "forest beings"). Homeland: Lâm Uyên, the Verdant Deep.
- **Book I fit:** "forest symptoms appear without explanation". Cổ Mộc is first met in Book II. Book I needs almost
  no Mộc Tinh NPCs, so this kit can wait.
- **Body (new):** woodlike tissue, bark skin, a **branch crown**, moss, white flowers, hanging vines, living sap,
  root-like toes. Slender and elongated (`PeopleProportion`). The face is bark with knot eyes (green-gold). It is a new
  mesh on Actor_B plus vine bones, and a **bark material** (bark normal and colour, moss in cavities, flower and leaf
  cards like hair strips).
  - **Age changes form** (P07). "Some young spirits choose smaller bodies and mortal timescales", which is the
    canon-clean reason a **playable Mộc Tinh is a young mobile spirit**. Elders root and become set pieces (the Root
    Mother).
  - "A sapling from a dead elder is not proof of the same consciousness returning" (death stays final).
- **Animation:** human clips on a bark body are acceptable for motion, but **idle and stand clips should be slower and
  stiller** (own clips: a rooted stance, a slow head turn). Vines on springs. The crown hits doorways and hats, so cap
  crown height and offer no hats.
- **Dress:** **not human clothing** (the guardrail "do not explain spirits as humans with different cosmetics"). Grove
  tokens, a woven sash, hanging tags, a cloth wrap given by mortals, a walking staff, a basket (the Common Folk sheet:
  grove-tenders, herb gatherers). Formal is the bark and bloom state itself (a creator *bloom* row) plus grove regalia.
- **Names:** "Mộc" names (Cổ Mộc, Mộc Chi, Kha Mộc in the paintbook). Titles describe a network position (the Root
  Mother). Affiliation "of <grove>".
- **Limits in play:** **fire** is a real threat (damage taken, never a slow). **Drought** and **root shock**. **Arts
  weaken away from the grove** (§07: "Cổ Mộc loses access when severed from a remembered grove"). Travel decisions are
  made with the sustaining grove (a story hook).
- **Effort:** XL (body, head, material, vines, crown clearance, own idle clips, grove dress).

### 4.8 Ancestor-Bound (P08): playable, phase 1
- **Title:** "Ancestor-Bound, Bearers of Many Spirits" (*Tổ Hồn Tộc* or *Tổ Linh Tộc*; the sheets differ). Home: the
  Ancestor Halls (in Vạn Thủy and along the rivers) and the Ancestor Roads (L11).
- **Body:** ordinary human (P08). Listed as a people because the sheets and the owner list eight, but built as **a
  human lineage (Ancestor House) plus the Condition row Bound / Unbound** (Vệ is unbound). Faces, skin and hair are the
  human range.
- **Ancestors in play:** voices are "partial continuing relationships, not omniscient souls". Testimony, not playback.
  They stop where the ancestor's own experience stopped. They give diegetic audio lines and the ghost figures of the
  sheet (a VFX drawn from the **household's own dead**: the family records the household system keeps).
  - **No quest markers or target cues** from voices.
  - **The player can refuse a voice** (P08: "a living keeper should be able to refuse a voice"), so a mute or refuse
    action exists.
  - Overload builds Identity Strain (§07). The player is **not** An Tâm, and the eighth voice is hers (no chosen one).
- **Everyday dress** (shrine keepers, record keepers): a dark crossed robe with red bands, hanging paper and wood
  spirit tags, jade discs, a book, a lantern pole.
- **Formal dress:** layered ceremonial robes "woven with lineage" (a crane motif on the sheet), a **tall ritual hat**
  (a `lathe_hat` variant with hanging tags), a staff with bells.
- **Names:** Vietnamese names (An Tâm, Vệ, Liên Khởi); religious titles Father, Brother, Sister, Novice; "of House
  <name>".
- **Lifespan:** human. **Limits:** "Borrowed memory is not trained muscle". A voice cannot give a skill.
- **Needs:** condition row (S), tags and tassel hardware (M, shared), garments (L), voice system (M, systems/story
  workstream), ghost VFX (M).

---

## 5. Garments: what to build, in what order

Everyday dress first. It is what an ordinary person (the player) wears, and the Common Folk sheet is its brief.
Formal dress is NPC, court and cutscene first.

| Need | Recipe | Status |
|---|---|---|
| Crossed short and long robes, tunics | `robe` (crossed), `tunic` | exists |
| Wide trousers, wrap skirts | `trousers`, `wrap_skirt` | exists |
| Sashes, belts | `wound_sash`, `belt` | exists |
| Conical hat (Dragon-Sea, Riverborn) and tall ritual hat (Ancestor-Bound) | `lathe_hat` | exists; add ornaments and hanging tags |
| Shawls, mantles | `drape`, `cloak` | exists |
| Leg wraps (Mountain, Stone) | new: a strap wound along the shin (like `ring_trousers_wrapped`'s wrap) | M |
| Fringe and feather mantle (Mountain) | new: strips on the skirt helpers, `fringe.gdshader` | M-L |
| Hanging tags, tassels, jade discs, shell and pearl strings (everyone) | new: hardware on straps (cloth2 `hardware.py`), small spring chains | M |
| Sheer layered over-robes with long trailing sleeves (Dragon-Sea, Riverborn formal) | new: alpha layers on the skirt helpers; the long sleeves need their own helpers | L, clipping risk |
| Tail-opening variants (Hồ Tinh) | slit at the back over `tail_root` (`dress.slit_weights`) | M |
| Floodborn set (net vest, reed armour, panel skirt open at the back, hide wraps) | fitted to the Floodborn body | L |
| Mộc Tinh grove tokens and sash | fitted to the Mộc body | M |

Rough count: about 6-10 everyday pieces per people for the five phase-1 peoples, so **35-50 garments: XL** (one Blender
at a time). The palette needs Thủy Vân dyes and materials (indigo, lacquer red, lotus pink, jade, bronze, pearl, shell,
reed) in `tools/character/cloth2/palette.json`. The fabric kits are CC0 Poly Haven scans; silk, sheer and reed weave
need new kit layers.

Retire or restyle: the frontier, colonial, militia, regulars, woodlands, highland, middle_east, africa, spanish and
southeast_asia sets leave the creator with the 1765 world (they stay in git). The **ring set is restyled into
peoples' dress** (§1).

---

## 6. Fonts with Vietnamese diacritics

**Today:** no font files ship. Four UI scripts use `SystemFont` name lists. Everything else uses Godot's built-in
default font.

**Measured on this Mac** (a cmap check against every non-ASCII letter of the bible's names, 28 letters):

| Font | Result |
|---|---|
| Baskerville, Georgia, Avenir Next, Helvetica Neue, Times New Roman, Arial | full |
| Hoefler Text | missing 22 (in `hud.gd`'s serif list) |
| Menlo | missing 6 (debug overlay only) |

On Windows and Linux players the lists fall through to Georgia, Times or Arial, or DejaVu/Liberation, which cover
Vietnamese in their current versions. Appearance then differs per OS. The built-in default font's coverage has to be
checked in Godot (`Font.has_char`), which this plan did not run.

**Recommendation:**

1. **Ship two fonts with full Vietnamese** as the project default (`gui/theme/custom_font`) and in the UI scripts: one
   serif for titles and names (the sheets' classical caps), one sans for the UI. Candidates under the SIL Open Font
   License: *Be Vietnam Pro* (sans, made for Vietnamese), *Noto Serif* / *Noto Sans*, *EB Garamond*, *Cormorant
   Garamond*, *Alegreya*, *Lora*. **This is a download of third-party files**, so the owner must approve it (the
   own-assets rule). OFL requires shipping the licence. Note: `NOTICE.txt` points at a `CREDITS.md` that does not exist
   in the tree.
2. **Zero-download fallback:** keep `SystemFont` and put Vietnamese-complete names first. Drop Hoefler Text from the
   serif list and Menlo from the debug list (or add Georgia and SF Mono ahead of them). Keep
   `allow_system_fallback` on.
3. **A coverage test** (`tests/ui/test_vietnamese_glyphs.gd`): collect every string in `data/` and the UI text, then
   assert `has_char` for each character on every font the UI uses. Render a proof sheet of the uppercase stacked marks
   (THỦY VÂN, TRƯỜNG SƠN, ẢO THÀNH, Ẫ, Ỗ, Ặ), because stacked accents on capitals clip under tight line spacing.
4. **Text hygiene:** store all data in **NFC**. The bible text is NFC with no combining marks (checked). The creator's
   name field (24 characters) must accept a Vietnamese IME (test on macOS). Saves and `NetSession` are UTF-8 already: no
   ASCII-only calls were found in `scripts/`.
5. Hán characters (the sheets' 龍海族 etc.): showing them needs a CJK font (large). Recommendation: no in-game Hán text
   in phase 1. Use them only as painted art in emblems or banners. Owner question.

Effort: S (fallback lists plus the test) to M (shipped fonts, theme, proof sheet).

---

## 7. Phase plan for the peoples

| Phase | Playable | NPC | Why |
|---|---|---|---|
| 1 | Dragon-Sea People, Mountain Folk, Stone Children, Riverborn, Ancestor-Bound (plus unbound humans) | the same, plus **Floodborn** (first-cut body, small clip set) and Hồ Tinh in human form | All human-shaped, so they reuse the body, clips and garments. Book I's visible cast is Dragon-Sea, Mountain, Stone, Ancestor and Floodborn ("read as raiders"). |
| 1b / 2 | **Hồ Tinh** (ears, tails, shown/hidden form) | Hồ Tinh true form at reveals | The cheapest non-human kit (attachments on the human body). |
| 2-3 | **Floodborn** (full animation adaptations) | Mộc Tinh grove NPCs | Floodborn need posture, tail, snout-safe clips and world clearance. |
| 3 | **Mộc Tinh** (young mobile spirit) | Root Mother as a set piece | New body; Book I barely needs them. |

The owner's decision says the player can be any people. This plan treats that as the destination, not phase 1, and
asks the owner to confirm (question 1).

---

## 8. Review images the owner should see (he judges by eye)

1. **The Common Folk lineup rebuilt in game:** eight figures in the sheet's order, next to the sheet. Use
   `creator_shots.gd` / `world_peoples_shots.gd`, extended. This is the headline review for every phase.
2. **Per-people turnarounds** (front, 3/4, side, back) in everyday and formal dress, next to crops of the people's
   sheet. Both body types.
3. **Feature lineups with variants A/B/C/D**, bold not subtle: scale amount, mineral amount, Riverborn skin hue, gill
   size, web size, fox tail count and size, crest height, snout length, crown height.
4. **Grey-box first** for Floodborn and Mộc Tinh: an untextured silhouette lineup next to a human before the full
   build.
5. **Motion strips:** tail in walk, run, crouch, sit, lie and climb; fox tails in a sprint; Floodborn eating and bow
   anchor; vines in a turn.
6. **Font proof sheet** (§6.3).

---

## 9. Risks

- Human clips on a crocodile body read as "a human in a costume", which breaks the bible's guardrail. Mitigation:
  posture overlay, tail, own idles, and a grey-box review before the build.
- Sheer, trailing formal dress clips in action clips. Keep it NPC and cutscene first.
- Tails, crowns and snouts collide with doors, beds, chairs, boats, horses and climbing walls. World clearance has to
  be agreed with the world/building workstream.
- Cost: spring chains (up to 9 tails), fur shells and sheer alpha layers on many NPCs. Needs LOD from day one.
- The face-pool rule ("keep every face") against the sheets' look. Owner choice.
- Real-culture resemblance: Mountain Folk tattoos, feathers and woven geometry echo real highland peoples. Draw our
  own motifs.
- Show-nation echoes in the Tidebreak ring dress, and in any "bender" wording in data.
- Spoilers in player-facing people notes and in the map sheet's legend (Memory as the Ninth River).
- Incomplete references: no Stone Children or Hồ Tinh single sheet; the Mộc Tinh sheet is a partial download; the
  peoples' Vietnamese names differ between sheets.
- Concurrency: the creator and body code are worked on in main by other sessions. Build in worktrees, merge in turn.
- Fonts are third-party downloads. They need the owner's OK and a credits file (`CREDITS.md` is missing although
  `NOTICE.txt` cites it).

---

## 10. Questions for the owner

1. Is phase 1 the five human-shaped peoples playable, with Floodborn as NPCs and Hồ Tinh next? Or must all eight be
   playable from the start (Floodborn and Mộc Tinh add months)?
2. Faces: keep "every face for every people", or Thủy Vân face pools that follow the sheets (the Vietnamese, Thai,
   Malay and Chinese showcase faces first)?
3. Which Vietnamese name per people (the sheets differ: Dân Hải Tộc vs Dân Biển Rồng; Sơn Dân vs Dân Núi; Nước Sinh
   Tộc vs Trạch Sinh, which reuses the Riverborn's 水生; Tổ Hồn Tộc vs Tổ Linh Tộc; Nhi Thạch)? Should Hán characters
   appear in game?
4. Fonts: may we ship OFL fonts (a download, with licence and credits), or use system fonts only?
5. Floodborn: size next to a human, plantigrade as drawn, horses or not, chairs and beds, both body types? Can a
   Floodborn and a human have a child in the household system?
6. Hồ Tinh: tail count 1-9 as a free cosmetic? Can the player hide ears and tails and pass as human (with Identity
   Strain as the cost)?
7. Dragon-Sea and Riverborn finned ears: real fins or ornaments? Where do Dragon-Sea scales show, and how many?
8. Mộc Tinh: playable as a young mobile spirit with a smaller body? A crown height cap?
9. Limits: may cold, dryness, heat and fire cost stamina, health or art strength, and never movement or aim (as with
   wounds)?
10. Arts: can any people learn any art from a teacher, with the people giving only the starting home and first
    teacher (D12)?
11. Ancestor-Bound: listed as one of the eight (as on the sheets) but built as a human lineage with Bound/Unbound (as
    the bible says). OK?
12. The two missing single sheets (Stone Children, Hồ Tinh) and the full Mộc Tinh sheet: can you re-export them?
