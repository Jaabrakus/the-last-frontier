# Character tools

Two generators share one library (`lib/`, see `lib/README.md`):

| Generator | Output | Status |
| --- | --- | --- |
| `build_body.sh` (`build_body.py`) | `assets/character/actor_b_body.glb` + `.json`: the in-game body with the colonial outfit (legacy, one glb) | used by the game today (`FrontierPlayer.body_path`) |
| `build_character.sh` (`build_character.py`) | the customizer parts: `assets/character/body/body.glb` (+ `.json`), `assets/character/hair/<id>.glb` (+ catalog fragment `.json`), `assets/character/garments/<set>/<id>.glb`, `assets/character/catalog.json` | body and 17 hair styles built; garments come from the garment workstreams |

Both run Blender 5.2 headless on a temporary copy of `Actor_B_001.blend` and never write
into `Player_Animation_Project`. `build_body.py` now imports the generic code from `lib/`;
the refactor was checked against the shipped glb: every mesh except the coat is identical,
and the coat differed run to run already (see `lib/remesh.py untangle`).

```
tools/character/build_character.sh --body [--previews DIR]      # full-skin body + the body cache
tools/character/build_character.sh --hair all [--previews DIR]  # hair styles (need the body cache)
tools/character/build_character.sh --garments <set|id,id|all>
tools/character/build_character.sh --all
Godot --headless --path . --import                              # after any build
```

`tools/character/cache/body_v1.npz` is the body cache (vertices, triangles, weights,
regions, shape deltas) that hair and garment builds read for weights, regions and the
`sex` wrap transfer. Rebuild the body first after a lib change.

## Head v3: the MakeHuman head (`body/body_v3.py`, `body/mh.py`; 2026-09-27)

`build_character.sh --body` now runs `body/body_v3.py`. The user asked for a polished realistic
head (Red Dead / Assassin's Creed style) and a realistic-only creator, so the v2 anatomical head
below (`lib/face.py`, still built by `body/body.py`, which body_v3 reuses for everything else) is
replaced above the neck seam by the MakeHuman base head (CC0; the base mesh and 119 targets are
vendored in `tools/character/makehuman`, see its README):

- Shapes: the female base is MakeHuman's young female at average build (the ethnic macros at its
  neutral 1/3 each); `sex` its young male with the v2 male fit (`face.FACE_MALE` in feature units,
  `mh.male_features()`) on top, since MakeHuman's men are much softer; `face_<feature>` the 30
  creator features mapped onto MakeHuman's face targets (`mh.MAP`, linear: the increase and the
  decrease target averaged; `mh.CALIB` scales each so weight 1 moves the face as far as the v2
  feature did); `blink` the lids rotated about the eye centres until the margins meet
  (`mh.lid_blink`). No stylized shapes.
- Fit: each sex scaled to the v2 head's height (crown to menton, `mh.OUR_HEAD`) with MakeHuman's own
  proportions, the eyes at the v2 face plane; the scalp pulled 1 mm under the v2 cranium (the body
  SDF) so every hair style and hat still fits; the MakeHuman game topology (no subdivision: 8.3k
  head triangles, the body 20k).
- Seam: the head's faces above the neck seam plane, the lowest row slid onto it, its ring pulled
  onto the SDF body's cut ring (blended over 5 cm) and bridged; `sex` joins the body's over 2 cm.
- Face mesh: the eyeballs at MakeHuman's eye centres, sized to its lids (they move and shrink with
  `sex` and `sex_head`, the creator's head-only fit); brows ray-cast onto the head from the v2 brow
  line moved with the eyes; lashes along MakeHuman's eyelash helper rows (each follows its root and
  turns with it in the blink).
- Skin colours (`mh.head_colors`): flush at the cheeks, ears, lids and nose tip, mucosa on the
  lips (where MakeHuman's lip targets act) and the lid rims, ray-cast cavity occlusion, the beard
  mask below the cheeks.
- Facial hair, marks, jewellery on the new face (step 2): the regions and marks of
  `face_detail.gdshaderinc` were drawn on the v2 head's landmarks. The build measures the v3
  head's (menton, lip borders, stomion, subnasale, eye, brow; mouth corner, cheek, ear front) in
  face coordinates into body.json `face.warp`, and the shaders (`face_coords()`) and FaceExtras
  (`BodyMaterials.warp_face_coords`) warp the new face onto the v2 layout piecewise-linearly;
  body.json `face.landmarks` gives FaceExtras the ear lobes and rims, septum and nostril.
- Checks: `tests/customizer/test_head_v3.gd`; preview: `tools/character/face_preview.gd`.

## Body (`body/body.py`, the v2 build)

- One full-skin mesh `Body` (surface `skin`) for both sexes and the `Face` mesh (surfaces
  `eye`: sclera and iris under a corneal bulge; `face_hair`: brow and lash cards). The body
  below the jaw is the legacy body shape (`BodyParams()` reproduces `build_body.py`
  exactly); the head is the v2 anatomical head (`lib/face.py`, below). The male fit is the
  `sex` shape key: the base vertices projected onto the male SDF (`BodyParams.male()`:
  broader deltoids and chest, flat pectorals, wider waist, narrower hips, thicker neck,
  hands +8 % girth; `face.FACE_MALE`: heavier brow ridge, jaw and chin, larger nose,
  thinner lips). `sex_head` is the head part of `sex` alone, for outfits built on the
  female body (the legacy actor_b_body.glb the player wears). Same topology, same weights,
  same skeleton. Height is not a shape: it is the stature scale of the Actor_B instance at
  runtime (female 1.00, male 1.07, 0.95-1.10; design §3.3).
- Mesh: the body on a 3 mm grid, the head on a 1 mm grid, stitched below the jaw (a
  tilted plane from the throat to the nape, bridged and remeshed); about 25k triangles
  (head about 13.5k: lid margins 1.4 mm, lips 1.6 mm, nose 2.3 mm, ears 3 mm, face 4.2 mm,
  cranium 8.5 mm). The broad skin of the head is smoothed (masked Taubin, `face.taubin`);
  the shapes go through the same linear smoothing.
- 38 hide regions with planar borders (neck at z 1.345 / 1.27, torso bands 1.18 / 1.03 /
  0.93, front / side / back at 40 / 120 degrees around the spine, pelvis centre |x| < 0.10,
  forearm at 0 / 0.5 / 0.78 / 0.9 / 1.0 of elbow -> wrist, thigh at 0.3, shin at 0.12 /
  0.55 / 0.85, foot at z 0.075). The arm / torso and leg / pelvis borders follow the body
  parts (not cut).
- Head v2 (`lib/face.py`): the v1 cranium (hair caps and hats fit), eyelids as a shell
  over the eyeball cut by the palpebral fissure (margins, canthi, canthal tilt, upper-lid
  crease and fold) with a pocket the eyeball sits in, a nose with dorsum, lobule, alae,
  columella and nostrils, lips on the dental arch with philtral columns, a mouth seam and
  commissures, brow ridge, zygoma, malar pad, mandible and chin, ears with helix, scapha,
  concha, tragus and lobe. Landmarks are the rig's facial joints at null-add (which sit a
  few mm under the skin); surface targets follow facial anthropometry (see the docstrings).
- Faces: 30 `face_*` shape keys, anthropometric features (face breadth, lower face
  height, cheekbones, midface, cheek fullness, prognathism, jaw breadth and angle, chin
  projection / breadth / height, brow ridge, eye depth, canthal tilt, eye opening, lid
  crease, upper-lid fullness, epicanthic fold, under-eye, nasal root, bridge, hump, nose
  width / length / tip / tip angle, upper and lower lip, mouth width, ears). Most are the
  base projected onto the head with one parameter changed (`face.FACE_FEATURES`); the lid
  opening features and `blink` are warps that rotate the lid skin about the eye centre
  (margins never split, lids never cross the eyeball); mouth width is a warp along the
  dental arch, and prognathism a warp that moves the muzzle forward (`face.prognathism_warp`;
  projected, the vertices by the mouth seam landed on the wrong lip and folded the
  vermilion). The lid margins, the eye pocket and the nostrils are masked out of the
  projected shapes. Every projected shape and the male fit are then relaxed where a
  triangle of the face front (mouth, nose, cheeks; not the lids or the hairline) turns
  over at weight +-1 (`shapes.relax_folds`: the delta is smoothed only around the fold).
- Peoples (`body/peoples.py` -> `assets/character/body/peoples.json`, also runnable with
  plain python3): 35 peoples in 9 groups (Europe: English, Scots-Irish, French, Palatine
  German, Dutch, Spanish; Eastern Woodlands: Haudenosaunee, Lenape, Shawnee, Wabanaki; Africa:
  West African, Central African, African American, Ethiopian; East Asia: Japanese, Chinese,
  Korean; South Asian; Southeast Asia: Filipino, Vietnamese, Thai (Siamese), Malay, Pacific
  Islander; Middle East: Levantine, Ottoman Turkish, Persian, Arab, Armenian, Kurdish; North
  Africa: North African (the Amazigh), Moorish (Morocco), Egyptian; mixed: French and Native
  (Metis), African and Native, European and African). The men's faces of the Middle Eastern
  and North African peoples (Levantine and North African excepted) carry the moustache or
  beard their men wore (`facial_hair`, a creator.json id; `CharacterPeoples.preset_look` puts
  it on the look), and face 1 of those peoples has the people's commonest hair colour. A
  people is a distribution (mean feature weights from published anthropometry, a within-group
  spread, skin melanin range, undertone and haemoglobin, eye and hair colour frequencies, hair
  texture and period styles); 4 presets per people are example individuals (mean + an
  individual offset; 12 for the Vietnamese, Thai and Malay, below). No preset is the face of a
  people; peoples overlap. `CharacterPeoples.random_look()` draws new individuals, optionally
  of two peoples mixed. The East, South and Southeast Asian peoples carry a `licence_note`
  (rare in the 1750s northeast: artistic licence), shown under the people's note.
- Vietnamese, Thai and Malay (2026-09-26): face means between the East Asian and the island
  Southeast Asian ones (Vietnamese 0.55 / 0.45, Thai 0.4 / 0.6 with a slightly broader nose,
  Malay 0.15 / 0.85 with the upper-lid crease a little more often present), skin Tone 3-7
  (Vietnamese), 4-7 (Thai), 4-8 (Malay), dark eyes and hair, straight hair. Period hair:
  Vietnamese men and women long hair in a bun (topknot, low bun), Siamese men and women short
  (`hair_siamese_crop`, `hair_siamese_short_f`), Malay long hair knotted (topknot, low bun); the
  headcloths (the Vietnamese khan, the Malay tengkolok) are not made yet. Six faces per body type
  in both face styles: stylized (`SHOWCASE`, as the other East and Southeast Asian peoples) and
  realistic (`REALISTIC_SHOWCASE`: two showcase faces tuned for n07's head, then presets A, B and
  C, D from `EXTRA_PLAN`); the other peoples keep n07's two realistic presets per body type.
  Emblems: rice seedlings in a paddy, a stilt house by the river, bamboo-shoot triangles
  (pucuk rebung). Vietnamese and Malay men offer no earrings (a note says the women wore them).
- Skin: `assets/character/shaders/skin.gdshader`: `melanin` 0..1 along 12 anchors ("Tone
  1-12"), `undertone` (Oklab a/b: cool, neutral, warm, olive), `haemoglobin` (blood seen
  through the epidermis, screened by melanin), `freckles`, `weathering` of the exposed
  regions, `stubble`; COLOR_0 r = flush, g = mucosa (vermilion, inner lid rims), b = cavity
  occlusion baked from the SDF, a = beard mask; SSS, pore detail that fades with distance,
  `hide_mask`. `eye.gdshader`: iris with fibres, crypts and collarette, limbal ring, sclera
  vessels, clear-coat cornea, lid shadow. `face_hair.gdshader`: brows (thickness, arch,
  density) and lashes as alpha-scissor strands that fade to coverage at a distance. The
  skin keeps its shading normal facing the camera and fades the specular at grazing view,
  so a crease that face-shape combinations still fold (alar groove, mouth corners) does not
  catch the sky as white flecks.
- Weights: `body_weights` + the twist / armpit helpers, plus 12 extra smoothing passes over
  the trunk (spine, neck and hip transitions), because the whole skin can now be seen, and
  16 over the neck and jaw line below the rigid head (`NAPE_SMOOTH`: the v2 head meshes the
  neck 2-3x finer, so the trunk passes alone blended headb into the neck over too short a
  distance; the nape stretched in head pitches and the hair caps, which copy these weights,
  frayed). The face and the Face mesh are rigid on headb (the source clips' facial joints
  are not played by the graph); `FaceBlink` blinks with the `blink` shape.

## Hair styles (`hair/*.py`)

**Hair v3 recipes (2026-09-28).** The user found the v1 styles (an opaque SDF cap with painted
strands) looked like helmets and the MakeHuman hairs of v2 plastic, and asked for every style in our
own hair, true to the period, with "a procedure system to make it easy". A style module keeps its
SPEC and a short RECIPE (`hair/_recipe.py`, documented at its top): where the hair grows (the drawn
hairline of `hair/_strands.Domain`, a crown patch for a plucked head), how it is combed (back to the
tie, parted, out from the crown whorl, up to a knot, one way), its layers (presets `combed`,
`loose`, `crop`, `coily`, or explicit strips), loose hair falling past the head, a tail (queue,
braid, club, flat club, lock), a bun, plaited rows, hand-placed locks and the accents (ribbon bow,
bands, wraps, silver plates). `hair/_strands.py` grows the strands over the v3 head and lays strips
of the strand atlas (`tools/character/hair_atlas.py`, drawn strand by strand, the project's own)
along them; each style bakes a scalp mask (`assets/character/hair/tex/<id>_scalp.png`, the head's
MakeHuman UV space) that tints the skin under its hair. One command builds and previews styles:

    tools/character/hair_make.sh hair_braid_f haudenosaunee /tmp/braid dz=-0.13 half=0.25 fov=26

| id | Style | For | Evidence | Rig |
| --- | --- | --- | --- | --- |
| `hair_queue_ribbon` | queue, black ribbon bow | men, B / D / A | A [M17] | pendulum |
| `hair_club_ribbon` | clubbed: the tail folded up and tied | men, B / D | A [M17] | pendulum |
| `hair_loose_tied` | long, tied at the nape with a thong, the tail hanging loose | men, A / C | B [M17][P1] | pendulum |
| `hair_cropped_1758` | cropped to about an inch (1758) | men | A [M1] | head |
| `hair_natural_short` | Afro-textured, short and natural (coily texture) | any | A [M15] | head |
| `hair_crown_lock_braided` | plucked head, braided crown lock with a beaded garter | Eastern Woodlands men | A [P1][R2] | rigid on the head |
| `hair_crown_lock_silver` | plucked head, crown lock set with silver plates | Eastern Woodlands men | A [P1][R2] | rigid on the head |
| `hair_club_wrapped_f` | parted, flat club about 4 inches wide, wrapped (skin, cloth, ribbon or silver) | Eastern Woodlands women | A [R1] | pendulum |
| `hair_braid_f` | parted, long single braid, tied | Eastern Woodlands women, habitantes | B [R1][R2] | pendulum |
| `hair_pinned_capped` | parted, pinned up at the back (for the linen cap) | colonial women | A [R13][M16] | head |
| `hair_bun_low` | parted, gathered into a low bun at the nape | women of many peoples | B [R13] | head |
| `hair_long_loose` | long, straight, parted, loose down the back | Eastern Woodlands men and women, any | B [P1][R1] | pendulum, lying on the back |
| `hair_topknot` | combed up into a knot on the crown, tied with a cord | East, South and Southeast Asian men | C (licence note) | head |
| `hair_siamese_crop` | about an inch on the crown standing up like a brush, the sides and nape cut close | Siamese men | C (licence note) | head |
| `hair_siamese_short_f` | short and round, combed up and back from the forehead, a flat lock at each temple tucked behind the ear | Siamese women | C (licence note) | head |
| `hair_coily_rounded` | Afro-textured, grown out, combed round | any | B [M15] | head |
| `hair_cornrows` | plaited in rows flat to the scalp | any | B [M15] | head |
| `hair_bag_wig` | powdered, a rolled curl above each ear, the queue in a black silk bag with a bow | officers and gentlemen | A [M17] | pendulum (bag), head (rolls) |
| `hair_qing_queue` | the front shaved above the temples, one long braid to the small of the back | Chinese men | B (licence note) | pendulum |
| `hair_chonmage` | the pate shaved, the sides and back drawn up and folded forward over it | Japanese men | B (licence note) | head |
| `hair_shimada_f` | dressed up: full side locks, a projection at the nape, a knot on top with a pin | Japanese women | B (licence note) | head |
| `hair_jjok_f` | parted, a low chignon held with a long pin (binyeo) | Korean married women | B (licence note) | head |
| `hair_shaved` | shaved, a few days' stubble (the scalp's tint), worn under a turban or cap | Ottoman, Persian, Egyptian, Moorish, Levantine and Arab men | B | head |
| `hair_shikha` | shaved but for a knotted tuft at the crown | South Asian men | B (licence note) | head |
| `hair_bedouin_braids` | parted, a braid at each side falling in front of the shoulders | Arab men | B | body |
| `hair_shuruba_f` | fine braided rows from the forehead to the crown, free and full behind | Ethiopian women | B | head |

- Shapes: `sex`, `sex_head` and the face features, by wrap transfer from the body, and
  `hat_fit` (the hair above the hat band plane pressed toward the scalp so the hats sit on every
  style); `PlayerAppearance` sets it while a hat is worn.
- Strips: surface `<id>_tex` (`hair_tex.gdshader`), a dense base, clumps and fine strands; each
  strip tapers at its root and tip and its edges are feathered (hair json `edge_feather`).
  Tails, clubs and braids hang from `helpers.QUEUE_ROOT` on the pendulum bone that
  `CharacterBodyMesh` drives; a crown lock is rigid on the head. The strips copy the weights of the
  nearest body point (hair lying on the back: the torso's).
- Accents: surface `<id>` (`hair.gdshader` zones 1 and 2), rigid on the pendulum or the head.
- Zones: 0 hair, 1 accent (ribbon, cord, wrap, garter), 2 metal (silver). Hair zones for
  hats: crown (above the hat band plane), sides, back, queue, lock.
- Colour: `hair_tex.gdshader` and `hair.gdshader` (shared `hair_common.gdshaderinc`):
  `eumelanin` 0..8 (flaxen to blue-black anchors), `pheomelanin` 0..4 (red tint), `grey`
  (share of white strands), `powder`, accent colour (metal flag for a silver wrap).
  Presets: `assets/character/hair/hair_colors.json` (bible §1.3).
- No feathers, no war paint, nothing from the bible's exclusion list; the small dyed plume
  is a separate accessory for the garment workstream.

## Runtime helpers

- `CharacterBodyMesh.attach_parts(sk, ap, {tag: glb})`, `add_part`, `remove_part`,
  `set_blend_shape` (`scripts/player/character_body.gd`): several glbs on one skeleton,
  one shared Skin, one helper driver. `attach()` (the legacy glb) is unchanged.
- `BodyMaterials` (`scripts/customizer/body_materials.gd`): skin, eye, brow / lash and hair
  materials, `apply_look(body, look, parts)` (sex and `outfit_fit`, face preset or weights,
  tone, undertone, haemoglobin, freckles, weathering, stubble, iris, brows, hair style and
  colour, hide regions, hat hair zones), `face_weights()`, `hide_mask(names)`,
  `tone_color()` and `hair_color()` for UI swatches.
- `CharacterPeoples` (`scripts/customizer/peoples.gd`): peoples.json, presets,
  `preset_look()`, `random_look(people, sex, rng, mix_people, mix)`.
- `PlayerAppearance` (`scripts/customizer/player_appearance.gd`, installed by
  `FrontierPlayer._build_character()`, export `use_appearance`): the customizer head, hands
  and hair on the player's legacy outfit (the legacy Body / Face / Hair hidden, the male fit
  on the head only; under the tricorn the hair keeps its crown and is pressed flat by
  `hat_fit`), `FaceBlink`, O opens the character creator (below; offered by itself at the first launch).
- `CustomizerOverlay` (`scripts/customizer/customizer_overlay.gd`, the creator's Fine-tune): People (group,
  people with a note, presets, New individual, Mix with), Face (feature sliders), Skin,
  Eyes, Hair tabs with a live preview (studio or frontier light); Apply saves
  `user://appearance/current.json` (`AppearanceStore`; `--appearance=default|preset:<id>|
  <path>` on the command line).

## Cloth: fabric kits, cloth attributes, winter garments (2026-09-26)

| Command | What |
| --- | --- |
| `python3 tools/character/make_fabrics.py` | `assets/character/fabrics/` from the approved CC0 Poly Haven clothing scans (read only): detail and normal Texture2DArrays (1024 px, one layer per fabric code), `fabrics.json` |
| `python3 tools/character/cloth_bake.py legacy\|garments\|all\|<glb>` | the cloth shader's attributes in the glbs (see `assets/character/README.md`); `build_body.sh` and `build_character.sh --garments` run it |
| `Godot --path . --resolution 1280x720 -s tools/character/outfit_shots.gd -- out=DIR [light=game\|studio] [outfit=<slot>:<id>:<colour>,..] [looks=<json>] [views=..] [compare=1] [debug=1\|2] [bench=N]` | turnarounds of the outfit on the player in the game's light (compare=1: each view also with the glb's old flat materials, same frame), mask and UV debug views, render-cost bench |
| `Godot --headless --path . -s tests/customizer/test_clothing.gd` | fabric arrays, the baked attributes of the legacy glb and every garment, cloth materials on the player (arrays bound), the winter outfit on and off (parts, hidden pieces, hands, skirt hems, gear push, fur flatten, wrap inflate, SlingRig bulk), save / load, the Outfit tab |

Winter garments of the frontier set (`garments/frontier/`), built like the others:

| id | Slot | Grade | From |
| --- | --- | --- | --- |
| `capot_fur_trim` | outer | B | `capot_blanket`'s coat, hood and ties with fur shells on the collar and turned cuffs (a fur facing down the front read as a zigzag stripe and was dropped) |
| `fur_mantle` | accessories.wrap | A | `ew_matchcoat`'s drape (hips wrapped and belted, over the left shoulder, right arm free) as a robe of skins, fur outside |
| `mittens_fur` | accessories.hands | B | the body's hand shape with the middle, ring and little fingers in one pocket (weighted to the middle finger's chain), a separate trigger finger and thumb, a flared gauntlet; fur on the cuff and the back of the hand |
| `moccasins_winter` | feet | B | `moccasins_puckered` with the hair left on, fur shells on the turned-down flaps |

The existing `fur_coat_tailored` (grade C, artistic licence), `capot_blanket` and `fur_cap` are
worn the same way. Deformation (check_body_deform, 44 clips): the capot and the robe scan like the
garments they derive from (capot_blanket collapse 4.2 %, flip 15.9 %; ew_matchcoat 7.6 / 13.7 %);
the mittens collapse 5.8 % and flip 12.5 % of their triangle-samples, mostly the palm of a closing
fist (skin:hands 2.9 / 5.2 %).

## Checks

| Command | What |
| --- | --- |
| `Godot --headless --path . -s tools/character/check_body_glb.gd [-- glb=all\|customizer\|<paths>]` | binds = inverse(null-add), LBS at bind, 4 influences; customizer parts also: 291 joints in rig order, valid region codes, no triangle across a region border, `sex` / `face_*` shapes |
| `... -s tools/character/check_body_attach.gd [-- parts=legacy\|customizer\|all] [sex=0,1]` | in game (legacy player), and on a fresh Actor_B: one shared Skin, skinning at null-add with the blend shapes, limb test on 10 clips, helper table vs `body.json`, live driver |
| `... -s tools/character/check_body_deform.gd [-- parts=customizer sex=0\|1 face=<preset>]` | distortion over 44 clips x 8; the body per region group, hair per style (limits in the script, 25 % above the current scan) |
| `Godot --path . --resolution 1280x720 -s tools/character/body_preview.gd -- out=DIR [only=bodies,tones,faces,hair,colors,regions,poses]` | preview renders (window; keeps itself on top) |
| `Godot --path . --resolution 1280x720 -s tools/character/face_portraits.gd -- out=DIR [light=studio\|game] [mode=presets\|hair\|anim]` then `python3 tools/character/face_sheets.py DIR` | portraits of every peoples preset (front, 3/4, profile) in a studio or in the game's light, hair styles with and without the hat, the face in gameplay clips and blinking; contact sheets per people |
| `Godot --headless --path . -s tests/customizer/test_faces.gd` | shapes and surfaces of body.glb, peoples.json consistency, random / mixed individuals, the look on the player (legacy head hidden, head-only male fit, hair under the hat), every preset, blink, save / load, O binding, overlay pause |
| `Godot --path . --resolution 1280x720 -s tests/customizer/test_customizer_ui.gd [-- shots=DIR]` (or `--headless`) | the creator's Fine-tune (the detailed customizer) driven by key and mouse events: preset, tone, a face slider, a hair style, Apply back to the creator, Accept (player look, head material, hair part, saved file), reopen, Esc, the inventory doll; restores the saved look |
| `Godot --headless --path . -s tests/customizer/test_sea_peoples.gd` (or windowed with `-- shots=DIR`) | the Vietnamese, Thai and Malay peoples: data (group, licence notes, skin, eyes, hair, means between the Chinese and Filipino means), six faces per body type in both face styles with the showcase faces first (shared features only), the Siamese hair styles (catalog, licence, budget, offered first), the creator rows (first face, 10 faces, jewellery), every face and hair style dressed on a body in both styles, save / restore, the creator's people buttons and note; restores the saved look |
| `Godot --headless --path . -s tests/customizer/test_new_peoples.gd` (or windowed with `-- shots=DIR`) | the peoples added 2026-09-27 (Spanish; Ottoman Turkish, Persian, Arab, Armenian, Kurdish in the Middle East group with the Levantine; Moorish (Morocco) and Egyptian in North Africa with the North African; Ethiopian): groups and members, data, the men's moustache or beard carried onto the look and the Facial hair row, face 1's hair colour, emblems, jewellery (nose rings for Arab, Kurdish and Egyptian women), every face and hair style dressed in both styles, save / restore, the creator's people panel fitting six to a row and its longest note; restores the saved look |
| `Godot --headless --path . -s tests/customizer/test_head_v3.gd` | the v3 head: body.glb shapes (sex, sex_head, blink, the 30 features, each moving the head 0.5-12 mm; no stylized shapes), triangle budgets, the Face mesh's shapes (the eyes move alike with sex and sex_head), provenance; realistic only (rows, a stylized save loads realistic, the default look); the face warp (knots, each landmark onto the v2 one, on the skin material) and landmarks; the look's weights and sex on a body, a full beard within the fur budget, FaceExtras at the new landmarks, the blink |
| `Godot --headless --path . -s tests/customizer/test_creator.gd` (or windowed with `-- shots=DIR`) | the character creator: option data per people (ids, ranges, documented customs, emblems), every row of every people cycled, every choice of four peoples dressed on a body and read back (skin, face shapes, hair, beard shells and painted style, brows, iris, marks, jewellery), randomize, save / restore, keys and clicks, Back / Accept, O in game, the first-launch offer; restores the saved look |
| `Godot --path . --resolution 1280x720 -s tools/character/creator_shots.gd -- out=DIR [peoples=..] [set=peoples\|styles\|emblems\|clothing\|all]` | screenshots of the creator: peoples x body types framed on body and face, facial hair styles front and 3/4, markings, jewellery, the emblem sheet, the Clothing view |

## Character creator (2026-09-26)

O opens `CharacterCreator` (`scripts/customizer/character_creator.gd`), a creator in the flow of
MMO character creators (inspiration only: every asset, emblem and name is the project's own):

- **Stage** (`creator_stage.gd`): the player's Actor_B (legacy outfit, `PlayerAppearance.dress`,
  hat off) idling (`relax-idle`) on a plank dais in a dark room, AgX and the u10 grade LUT, a
  near-white key (a warm key turned every skin orange), a cool rim, a low fill, a dim sky for
  reflections only, TAA (the beard shells' dither needs it). The camera eases between the face
  (face rows), the upper body (skin) and the whole figure (people, body type); drag, Q / E or
  the right stick turn the figure; the wheel moves between face and body. The game world's 3D
  is switched off while the creator is open (`Viewport.disable_3d`).
- **Left**: the people, grouped by region, each with an original emblem (`people_emblem.gd`:
  a plant, landscape or craft of the homeland, one ink colour on the same roundel for every
  people; no flags, heraldry, religious or sacred symbols, clan emblems, wampum or regalia;
  `tools/character/creator_shots.gd set=emblems` draws the sheet), the people's note, Body
  type 1 (male fit) / 2 (female fit).
- **Right**: rows `< Label  value  N/M >` (`creator_options.gd`, data in
  `data/customizer/creator.json`): Skin colour (the people's melanin range widened by 0.08,
  about 10 steps x its undertones), Face (the people's 2 presets + 8 generated individuals,
  deterministic), Hair style (the people's period styles first, then every style made for the
  body type), Hair colour (the people's by frequency, then grizzled / grey / white), Facial hair
  (body type 1; Eastern Woodlands men: plucked or light stubble, costume bible 3.4; the rest:
  clean-shaven ... full beard, with period notes), Eyebrows (9 shapes), Eye colour (the
  people's), Markings (freckles, smallpox scars, three scars; vermilion cheek spots for
  Eastern Woodlands and mixed Native women only, bible 3.6; no tattoos, clan marks or
  scarification until designed with the peoples concerned), Jewellery (per people and body
  type where documented: trade-silver ear bobs and nose jewels, pearl, garnet and jade drops,
  gold and silver hoops, studs, a nose stud or ring; none for Edo Japan and Joseon Korea).
  A click on the value opens every choice (swatches for colours); the focused choice's period
  note shows below; Fine-tune opens `CustomizerOverlay` on the same look; Clothing swaps the
  rows for the garment rows (`OutfitTab`, the Outfit tab of the customizer) on a wider panel,
  the camera on the whole figure with its hat on (the other rows show the figure bare-headed:
  the legacy tricorn hidden and the outfit's head slot set to "-").
- **Top**: the name (`look.name`, 24 characters). **Bottom**: Back, Randomize (a new
  individual of the people: face, skin, eyes and hair from its ranges and frequencies, its own
  hair styles, style rows weighted toward the plain choice), Accept (applies and saves).
- **Keys / gamepad**: up / down rows (people and body type first), left / right change, R / Y
  randomize, Enter / Start accept, Esc / B back, Page up / down and the shoulders the people,
  X the body type.
- **First launch**: without `user://appearance/current.json` (and not in a tool run, headless,
  `--appearance` or `--no-creator`) the creator opens by itself ("New character"); Back keeps
  the default look and saves it, so it is offered once.

Rendering (`BodyMaterials.apply_look` calls `FaceExtras.apply`):

- Facial hair: the style's regions (moustache, chin, jaw and cheeks, side whiskers; head UV
  coordinates, `assets/character/shaders/face_detail.gdshaderinc`, landmarks measured on
  body.glb) are painted by `skin.gdshader` (short hair and the skin under a beard) and given
  volume by shells (`beard_shell.gdshader`): copies of the head triangles in the style's
  regions with the head's skin weights and face shapes (`FaceExtras.shell_mesh`, cached per
  style), 4 shells for short styles and 6 for long ones (full beard about 30k triangles, every
  2nd shell dropped beyond 5 m), no shadows.
- Markings: `skin.gdshader` `mark_scar` (brow, cheek, lip), `mark_pox`, `mark_paint`; freckles
  as before.
- Jewellery: small meshes (silver, gold, brass; pearl, garnet, jade) rigid on headb, placed at
  the ear lobes, lobe and helix rim, septum or left ala of the head as its face shapes are now
  (`FaceExtras.landmarks`: the landmark vertices with their shape offsets), rebuilt on every
  apply; parts `facial_hair` and `jewellery` of the CharacterBodyMesh.

## Stylized faces (2026-09-26; retired 2026-09-27 with the v3 head: the creator is realistic only)

The creator's Face style row offers **Stylized** (the default) and **Realistic** (n07's faces,
unchanged). The stylized look takes inspiration from hand-painted MMO characters; every form,
texture and name is the project's own. One rule for everybody: the stylization is the same for
every face of every people, and no face feature is scaled, amplified or smoothed away.

- **Head** (`lib/stylize.py`, body.glb shapes `style`, `style_male`, `blink_style`): one fixed
  delta for every face. The base head is projected onto a stylized target: the same SDF head of
  `lib/face.py` built with one set of parameter changes (`STYLE_PARAMS`: a shorter lower face with
  the chin up and forward, the muzzle a little back, a tapering jaw on a slimmer mandible, clearer
  cheekbones and brow, shallower orbits (open, clear eyes rather than sunken ones), slightly fuller
  lips, tidy nostrils) and structural constants (`STYLE_STRUCT`: leaner lower-face masses, a clean
  plane under the chin and jaw, the hollow in front of the ear filled, crisper blends at the lids,
  nose and lips). Brushes then level the lumps of the blended masses: `fair` (mean curvature flow
  with the rim fixed, a few mm at most) over the cheek, the side of the face and under the jaw,
  `smooth` (Taubin, volume kept) over the cheek and jaw line, and an under-eye fairing (the lower
  lid's roll and the tear trough relaxed down to the cheek; the lid margins kept). Last, the eye
  region is scaled 1.15 across the view (1.04 in depth) about the eye centre with a gentle falloff
  to 3 cm (eyeball, lids and lashes together, so each person's lid shape is kept; `blink_style`
  closes the larger lids), the lids open 1 degree more, and the ears are scaled 0.88 about their
  root and tucked 30 % closer to the head (`ear_delta`, the ear told from the head by the SDF built
  without ears). The field fades out 1.2 cm below the hair caps' hairline plane and down the neck,
  so hair caps, hats and garments fit unchanged (the caps are carved round the larger realistic
  ears: a smaller ear only shows a little more skin). `style_male` adds the male fit's squarer jaw
  and stronger chin and brow at the look's sex weight. The face features (`face_*`) keep their
  weights: what differs between two people, and between two peoples, is exactly what differs in
  the realistic set. `tools/character/head_lab.py` renders the head from the body cache with plain
  python3 (`--style new` recomputes the shape from the source, `--heat` colours its displacement).
- **Painted skin** (`painted_skin.gdshader`, maps from `lib/paint.py`: `paint_head.png`,
  `paint_lines.png`; re-bake with `python3 tools/character/paint_bake.py`): the realistic skin tone
  (melanin, undertone, blood: identical in both styles) modulated in Oklab by a painted value (a
  soft light from above and in front, the small hollows of the eyes, nose, mouth and ears, a bold
  painted lash line and a mouth line; no pores), a blush on the apples of the cheeks and a rosy
  nose and ears, a faint cool lower third (a whisper on body type 2), painted highlights (nose
  bridge and tip, forehead, brow, cheekbones, chin, lips), rosy painted lips (the upper lip a shade
  darker), and (Complexion row: Smooth, Lined, Weathered) painted lines and more contrast. The
  zones shift the hue by a share of the skin's own chroma, so every tone is painted alike. Diffuse
  light is wrapped (`diffuse_lambert_wrap`): the game's lights still model the forms, but the small
  hollows no longer turn into dark patches. The realistic head's baked cavity occlusion
  (COLOR_0.b) darkens only the deep creases, and not round the eyes outside the lids
  (`paint_lines.png` B, `paint.cavity_mask`), where the stylized head has smoothed the realistic
  creases away. The neck and hands take the same painted value per vertex (body.glb UV2.y).
- **Eyes, brows, lashes, hair, beards** (`stylized` 1 in their shaders): a painted iris with a
  clean gradient, limbal ring and one painted catch light under a satin cornea (a mirror cornea
  reflected the game's sky over the iris); one clean, bold brow shape; the upper lashes a short
  band hugging the lid (the lower lashes are painted, COLOR_0.g = 0 on their cards); painted hair
  locks about 2.2 cm across with dark grooves, lit crests and a painted sheen band, coily hair in
  soft rounded clumps. On the caps the lock count follows the caps' own mapping
  (`cap_across_scale`, smooth), halving toward the point the strands leave, where the locks fade
  into one smooth tone (the per-triangle estimate read as shards at the parting). The parting
  groove is painted from the hairline back, without sheen. Beard shells in fewer, chunkier strands;
  the jewellery a third larger with simpler forms and a painted metal.
- **Faces** (`body/peoples.py` `STYLIZED`, `SHOWCASE` -> peoples.json `stylized_presets`): four
  stylized individuals per body type for every people (the same offsets for everybody, only on the
  features every face shares: jaw, chin, cheekbones, cheek fullness, face length and breadth, brow,
  eye opening, under-eye, lips, mouth width; `stylized_shared`), six for the East and Southeast
  Asian peoples (Japanese, Chinese, Korean, Filipino, Vietnamese, Thai, Malay): their two
  showcase faces first, tuned one by
  one (men: a longer, cleaner face, a strong forward chin over a clean jaw angle, clear cheekbones
  and brow, bold straight brows; women: a longer, finer face tapering to a neat chin, high
  cheekbones, open eyes, full lips, soft full brows), each with a chosen hair style, colour, brows
  and a clean shave; the user asked for these to be the most handsome faces of the set. The nose,
  lids, epicanthus, midface and mouth projection keep the people's mean, and an offset toward a
  people's own tendency shrinks with it, so no feature is pushed toward the end of its range. The
  Face row lists them first, then the people's presets and generated individuals. The
  Vietnamese, Thai and Malay also have two realistic showcase faces (`REALISTIC_SHOWCASE`, the
  same rule), first in the Realistic Face row.
- Checks: `tests/customizer/test_stylized.gd` (removed with the v3 head); portraits: `face_portraits.gd set=stylized hat=0`
  (`light=game` for the frontier light, `style=realistic` for n07's look; `ssao=0`, `ssil=0`,
  `shadows=0` to tell the lighting apart) and `creator_shots.gd set=facestyle`.

## Known limitations (v1)

- Bare skin shows linear-blend-skinning faults the clothes used to hide: the lower back and
  hip crease in deep crouches, the back of the neck in crouch walks with the head up, the
  armpits with both arms overhead, closing fists. The deform limits record today's values.
- The arm / torso and leg / pelvis region borders follow the body parts and are jagged.
- Hair tails are one rigid pendulum below a soft root: in a forward-leaning pose a long
  tail keeps the torso's angle and stands a little off the back; its root stretches when
  the head turns hard against the torso. A second pendulum bone would fix both.
- The facial rig is not used: the face is rigid on headb (no expressions, no jaw); blinks
  come from the `blink` shape. Brows and lashes are cards; lashes translate with the lid
  margin in a blink (they do not rotate).
- The player keeps the legacy outfit: the male fit changes the head only (`sex_head`), so
  a man's neck and hands keep the outfit's (female-base) size until the player wears the
  customizer's garments.
- The head is about 13.5k triangles (body.glb 25.4k in all); the budget of design §12.3
  counted 11.9k for the whole body.

## Provenance

The skeleton, bone names and bind pose come from the Actor_B rig, converted from
extracted game animation data (owner-stated authorization:
`Player_Animation_Project/ASSET_AUTHORIZATION.md`). All meshes are generated procedurally
by these scripts; no animation data or asset ids are changed.
