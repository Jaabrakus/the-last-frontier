# Player character body (Actor_B)

`actor_b_body.glb` is the player's skinned body with 18th-century frontier clothing:
linen shirt, waistcoat, a green mid-thigh hunting frock (shoulder cape, turned cuffs,
open front, a flat split back skirt with side pleats), buckskin breeches with a fall
front, wool leggings with garters, buckled shoes, a belt with crossed straps, a shot
pouch and a powder horn, a felt tricorn, and hair tied back in a queue with a ribbon.
`actor_b_body.json` holds the stats, the bind data, the helper-bone table and
constants, and reference results of the helper driver.

Regenerate both with `tools/character/build_body.sh`, which runs
`tools/character/build_body.py` in Blender on a temporary copy of the rig library.
Add `--previews DIR` to also render PNG previews (the bind pose and six game clips, with
the helper bones driven the same way as in the game). Then re-import (`Godot --headless
--path . --import`) and run the checks below.

## Meshes

The glb contains six meshes, all skinned to the armature `Actor_B`:

| Mesh | Contents | Surfaces | Triangles |
| --- | --- | --- | --- |
| Body | Skin that can be seen: head, neck above the stock, mitten hands with thumbs, wrists | 1 | 4.9k |
| Face | Eyes (sclera, iris caps, upper and lower lids), brows, lips | 5 | 1.1k |
| Hair | Hair cap, queue, ribbon | 2 | 1.9k |
| Clothes | All garments plus brass fittings | 8 | 18.0k |
| Gear | Belt, straps, pouch, powder horn | 7 | 2.4k |
| Hat | Tricorn and cockade | 3 | 1.5k |

About 29.8k triangles in total, above an 18-20k budget. The side pleats of the skirt
need about 1.5k of them. Vertices are in skeleton space (+Y up, facing +Z), with up to
4 weights per vertex.

Shapes worth knowing:

- Coat: cut around a torso whose chest, back and waist are bridged by smooth plates
  (`coat_torso_shapes`), so no pectorals, shoulder blades, lats or spine groove show
  through the wool. The skirt ends mid-thigh (hem 0.525 m at the back, 6 cm higher in
  front). Its back half flattens toward a superellipse (`SKIRT_BACK_N`), so the back
  reads as one flat panel with square hem corners, and the hem is about 6 cm wider than
  the seat. Three pleats per side sit between 96 and 134 degrees from the front
  (`SKIRT_PLEATS`). The back vent is narrow and straight. The shoulder cape has a
  straight, rounded edge blended into the coat (the scalloped step used to remesh into
  a sawtooth).
- Sleeves: the coat sleeve and its turned cuff reach 82 % of the forearm. About 2.5 cm
  of linen shows at the wrist, in a darker, warmer linen (#cbc1aa).
- Breeches: drab buckskin (#6f5a40) with a smooth fall front bridging the groin, a
  little fuller at the seat.
- Hair: a slim, even queue (2.9 to 2.1 cm thick, 12 cm below the ribbon, blunt end), a
  flat ribbon wrap at the nape and two short tails that follow the queue's surface. The
  ribbon (#2e1d14) is close to the hair in value.
- Tricorn: warmer felt (#2a2420), the crown 2.2 cm lower with a rounded top edge.

Hidden surfaces are not modelled: the skin under the clothes (torso, arms up to the
coat's cuff, legs, feet), the shirt except the stock, the front V and the cuffs, and the
waistcoat except the part in the coat's front opening are deleted. Nothing under the
coat can then show through it when the arms move. All materials are double-sided.

The Clothes mesh has vertex colours (glTF COLOR_0, an albedo multiplier). Only the coat
uses them: a darker lining, a darker band toward the hem, shaded pleat valleys, soft
back-vent edges and centre-back seam, a narrow dark band at the cape's edge, and
slightly darker turned cuffs. All other garments are white (no change).

## Weights and helper bones

Weights use the main deform bones (pelvis, legs, spine, neck, heada/headb, clavicles, arms,
palm, fingers) plus 21 helper bones of the rig that the clips never animate. The game
drives those every frame (see below):

| Helper bones (l_ and r_) | Driven as | Weighted |
| --- | --- | --- |
| shoulder_twist_a | half the shoulder's swing relative to the clavicle, no twist | the middle of the torso-to-arm blend at the armpit and shoulder cap |
| shoulder_twist_b / c / d | the swing with 0 / 1/3 / 2/3 of the upper-arm twist | along the upper arm, the shoulder bone itself near the elbow |
| forarm_twist_a / b / c | 30 / 60 / 90 % of the wrist's roll relative to the elbow | along the forearm, the wrist bone at the hand |
| upper_leg_front / thigh / rear_helper | gravity, pushed by the thigh, lifted off the floor (below) | the coat skirt's front, side and back panels |
| wrinklemaps (one bone) | a pendulum: root at the nape on the head, hanging between the torso's down and world-down | the hair queue below the ribbon, and the ribbon |

- Upper arm: the twist is up to 155 degrees in the musket and bow reloads. Linear blend
  skinning no longer blends the torso with the full twist (that collapsed the armpit), and
  the armpit bone halves the swing between neighbouring bones.
- Forearm: the roll is up to 142 degrees when aiming. It is spread along the forearm, so
  the wrist no longer twists into a thin stalk.
- Skirt: every panel hangs toward world-down, at most `SKIRT_GRAVITY_MAX_DEG` (60)
  from the pelvis, so it never goes horizontal with a tilted pelvis. The thigh only
  pushes: the front panel stays on a raised thigh (gain ramping from 0.6 to 1 over the
  first 60 degrees of flexion, so it does not bell forward over a slightly bent leg), a
  thigh going back pushes the back panel back, and the side panel sits halfway between
  them, turned half-way to gravity and pushed out by a spreading thigh. Last, when a
  panel's hem would be lower than 3 cm above the lowest foot, it swings up away from the
  body (the tails flare back and rest behind the heels in a squat). This floor lift fades
  out as the pelvis tilts 35-60 degrees (lying down: the hem cannot clear the floor
  anyway). Across the back centre line the two back panels share the weight 50/50 over
  +-4 cm except in the lowest third of the vent, so the back reads as one panel and the
  tails part only near the hem.
- Knees and elbows: the upper and lower bone are split by a plane through the joint.
  The thicker upper segment used to reach 5-7 cm down the shin and forearm.
- The garter bands, knots and ties are rigid on the shin (5-7 cm below the knee, where the
  leggings are on the shin bone too). Brass fittings are rigid per piece.
- Belt and straps: each vertex takes the coat's weights at the centre line of its band
  (the belt's mid height, the strap's centre line), without the leg and skirt bones.
  Every cross-section of the leather therefore moves as one piece and the band never
  changes width. The weights are then averaged along the band over about 6 cm, and the
  spine-chain part goes to the two chain bones around its mean before the 4-influence
  limit, so neighbouring vertices never keep different bone sets. The straps follow a
  centre line on the coat and keep their 2.6 cm width where they wrap round the side of
  the torso (a slab through the torso used to make wide flaps there).
- The hair cap copies the skin's weights, smoothed. The queue below the ribbon and the
  ribbon are on the pendulum, with a 2 cm soft root above the ribbon.

## How the game uses it

`scripts/player/character_body.gd` (`CharacterBodyMesh`) attaches the body to the
player's Actor_B `Skeleton3D`. `FrontierPlayer._build_character()` calls it when
`use_body` is on (the default) and `body_path` exists. It falls back to the capsule
`BoneMannequin` when the asset is missing; set `show_mannequin` to draw both for debugging.

`CharacterBodyMesh.attach(skeleton, anim_player)`:

- instances the glb once and adds a `Body` node under the `Skeleton3D` with an identity
  transform. It holds one MeshInstance3D per glb mesh (`skeleton = "../.."`, sharing the
  imported meshes and materials; surfaces with vertex colours get a material copy that
  uses them, because the importer does not always flag it);
- builds a new `Skin` in the same bind order as the imported one. Each bind name is
  resolved to a bone index of the game skeleton, and each bind is
  `inverse(global null-add pose)`. The pose is computed from the `actor_b/null-add` clip's
  track data at t = 0; the channels the clip does not key take the skeleton rest, which is
  also what the AnimationMixer uses for them. It never reads the live pose, so it works
  whatever the AnimationTree is doing. The rest of the keyed channels is never used, so the
  binds are the same before and after `BindRest`;
- compares the computed binds with the glb's (`report.max_bind_diff`, about 5e-6) and warns
  above 1e-3. A bone missing from the skeleton is bound rigidly to its nearest existing
  ancestor, with a warning;
- is a `SkeletonModifier3D`: every frame it sets the helper bones from the animated pose
  (`HELPERS`, the `SKIRT_*` constants, the twist wrap centres and the queue constants
  must match `helpers` in `actor_b_body.json`, which `check_body_attach.gd` verifies). It
  moves itself behind every other SkeletonModifier3D of the skeleton, so an aim
  stabiliser or IK added later runs first. Godot restores the animated pose after the
  skeleton update, so game code that reads bone poses never sees the helpers move.
  `skinning_globals()` returns the driven pose for CPU skinning in tools and tests.

Do not bind with `create_skin_from_rest_transforms`, `get_bone_global_rest` or another
rest-based method on a rig whose rest is not null-add: the mesh lands about 0.57 m off.
Do not bind with `bindpose-anim` either: its root scale of 1.0596 and +0.10 m offset make
an error of about 22 mm.

## Cloth materials (2026-09-26)

The game no longer draws the Clothes, Gear and Hat meshes with the glb's flat colours:
`PlayerAppearance.dress()` gives every surface a `ShaderMaterial` of
`shaders/cloth.gdshader` (`ClothMaterials.dress_legacy`, `scripts/customizer/cloth_materials.gd`),
tinted with the glb's own colour so the outfit keeps its colours and values:

- **Fabric kits** (`fabrics/`, made by `tools/character/make_fabrics.py` from the approved CC0
  Poly Haven scans in `assets/polyhaven/textures/clothing`): one Texture2DArray of detail
  (luminance / mean, roughness, AO) and one of normals, layers LIN, WOOL, TWILL, KNIT, SUEDE, LEA,
  FUR, HES, FLAT. Only the scans' luminance modulates the tint (design 8.2); their low
  frequencies are removed (they repeated every tile and tilted whole triangles in the mipmaps).
- **Attributes** (`tools/character/cloth_bake.py legacy`, run by `build_body.sh`): the legacy
  glb had no UVs. The bake adds grain-aligned UVs in metres (torso and skirt around the body axis,
  seam at the centre back; sleeves round the arm, seam underneath; breeches and leggings round the
  leg; shoes, gear and hat by a box projection), splitting vertices on the seams only (positions,
  weights and colours copied; triangles, skinning and every check unchanged), and per vertex:
  a piece code in UV2.x (coat 1, waistcoat 2, stock 3, cuffs 4, breeches 5, leggings 6, garters 7,
  shoes 8, belt 40, straps 41, pouch 42, horn 43, belt brass 44, hat felt 50...; brass on a piece =
  16 + its code), open-edge distance, dirt, wear, sweat, seam distance, cavity and compression-fold
  zones (CUSTOM0..2), and for the pouch and horn a push direction in TANGENT.
- **Shader**: the tinted scan (the weave fades out beyond ~1.5 m), each fabric's mid-scale
  character (fulled wool's felting clouds, linen slubs, buckskin mottle, leather grain), large-scale
  fading, wear (rubbed nap, burnished leather, polished brass), dirt from the ground up and on the
  knees, sweat at the armpits, collar and hat band, dust on what faces up, sewn seams (a groove
  whose darkening survives at a distance), turned hems, shaded fold valleys and compression folds
  at the elbows, knees and waist. `debug_view` 1 shows the masks, 2 the UV grid.

## Garments over the legacy outfit

`PlayerOutfit` (`scripts/customizer/player_outfit.gd`) puts customizer garments on the same
CharacterBodyMesh (parts `outfit:<slot>`): the look's `outfit` key, chosen on the customizer's
Outfit tab (`OutfitTab`). A garment hides the legacy pieces it replaces with the cloth shader's
`hide_mask` (a coat: the frock; moccasins: the shoes and buckles; a sash: the belt and its brass; a
hat, or the head slot's "-", takes the tricorn mesh off), the mittens hide the hands, the longest
skirt sets the helper driver's floor lift (`CharacterBodyMesh.set_skirt_hems`), a wrap or sash worn
over a coat stands out from it (`inflate`; the legacy frock counts as a coat), the legacy belt and
straps move out by the coat's extra bulk (`push_m`), fur lies flat under them, and the slung
weapons, quiver and belt items take the outfit's bulk from `data/loadout/body_fit.json` (SlingRig,
via the player's loadout). Fur surfaces use `shaders/fur_shell.gdshader` with the catalog's fur
presets and draw every second shell beyond 3 m (`lod_dist`; the kept shells cover for the missing
ones).

## Checks and screenshots

```
Godot --headless --path . -s tools/character/check_body_glb.gd      # the glb itself
Godot --headless --path . -s tools/character/check_body_attach.gd   # in-game attach, skinning, helper driver
Godot --headless --path . -s tools/character/check_body_deform.gd   # distortion over 44 gameplay and knockdown clips
Godot --path . --resolution 1280x720 -s tools/character/body_screenshots.gd -- \
    --no-capture out=/tmp/body mode=all                             # needs a window
```

- `check_body_attach.gd` also feeds the input bone globals of nine reference poses
  (`driver_reference` in the json, written by build_body.py's Python twin of the driver,
  including crouches, a sitting knockdown, a death and a hard landing) to the game's
  driver and requires the same helper globals, so the Blender previews cannot drift from
  the game.
- `check_body_deform.gd` CPU-skins every triangle (helpers included) at 8 times of 44
  clips: the gameplay clips plus the landing, knockdown and death clips the animation
  graph binds. Per material it fails when too many triangles ever collapse below 20 % of
  their bind area, turn over, or get an edge longer than 2x its bind length, or when the
  largest edge ratio exceeds a limit (limits in the script, about 25 % above the current
  asset). Rigid parts (belt, brass, pouch, horn, garters, ribbon) must stay below 1.3x;
  the straps below 2x (their cross-section is rigid, but along their length they follow
  the coat's back, about 1.6-1.75x on the lower back in deep crouches). It also fails when
  a skirt panel hangs more than 70 degrees off world-down while neither the thigh pushes
  it nor the floor lifts it. The previous asset fails it on the belt (35 % of its
  triangles over 2x, max 3.8x), the straps (3.2x) and the hair; the previous skirt driver
  had 30 panel samples standing 70-125 degrees off world-down.
- `body_screenshots.gd`: `mode=game` drives the real player through idle, walk, run,
  sprint, crouch-walk, aiming each weapon and both reloads. Each scenario waits in physics
  frames until its state is reached and held (speed range, aim >= 0.99, crouch,
  reloading); otherwise the run ends with BODY SCREENSHOTS FAILED. It renders the gameplay
  camera, four orbit views at 4.4 m and three close-ups (chest and armpits, hips and knees,
  nape and back). `mode=clips` plays single clips on a plain Actor_B. `mode=close`
  renders six close views (0.7-2 m) of the places that fail first: armpits with raised
  arms, wrists when aiming, knees and garters in crouches, the queue, the hips, the skirt
  in crouches, a hard landing, a sitting knockdown and the deaths, belt and straps in
  crouches.

## Known limitations

- Linear blend skinning without cloth: deep folds still squeeze (hip crease and crotch in a
  deep crouch, the armpit crease when the arms come forward, closing fists). They are
  hidden inside the fold. The skirt panels are rigid: in a squat the tails flare back as
  flat panels instead of pooling on the ground, a front panel stays propped on a knee
  raised while sitting back, and lying on the belly with the legs spread the seat of the
  breeches shows between the tails. The skirt folds more in the knockdown clips (coat
  flips 10 % over all 44 clips, 5.3 % over the gameplay clips alone).
- The straps lengthen with the coat's lower back in deep crouches (up to 1.75x, width
  unchanged).
- The queue is a single rigid pendulum (no simulation); it swings with the head's
  position, hanging between the torso's down direction and world-down.
- The powder horn and the pouch are rigid on the pelvis.
- Hands are mittens with thumbs.
- Small dark specks can show where the legging bottoms meet the shoes. The coat hem, the
  front opening and the stand collar edges are still slightly ragged in close views.
- About 29.8k triangles, above an 18-20k budget. The remesher stops at about 10k for the
  coat even when asked for fewer.
- Blender reports "Mesh Clothes/Hair is not valid" on export. The glb still checks clean.

## Provenance

The skeleton, bone names and bind pose come from the Actor_B rig. The body and clothing
geometry are generated procedurally by `tools/character/build_body.py`.

## Customizer parts (tools/character/build_character.sh)

The customizer's body and hair are separate glbs built by `tools/character/build_character.sh`
with the shared library `tools/character/lib` (see `tools/character/README.md`). The game
still uses `actor_b_body.glb` above until the player switches to the customizer.

| Path | Contents |
| --- | --- |
| `body/body.glb` (+ `body.json`) | full-skin `Body` with the v3 head, the MakeHuman head (CC0; tools/character/body/body_v3.py) (38 hide regions in UV2; blend shapes `sex`, `sex_head`, `blink` and 30 `face_*` features) and `Face` (eyeballs; brow and lash cards); `body.json`: regions, face features, skin tones and undertones, iris colours, helper table, driver reference poses |
| `body/peoples.json` | 35 peoples in 9 groups (face feature means and spread, skin, eye and hair frequencies, period styles, the men's facial hair where customary), 172 presets and 312 stylized presets; generated by `tools/character/body/peoples.py` |
| `hair/<id>.glb` (+ `<id>.json`) | 17 hair styles (cap, tails, braids, wraps, rows, strand cards), shapes `sex`, `sex_head`, the face features that reach the hairline and `hat_fit` (hair under a hat band pressed to 6.5 mm off the scalp), hair zones for hats; the `.json` is the catalog fragment |
| `hair/hair_colors.json` | hair colour presets (melanin model) |
| `catalog.json` | merged catalog of every part (generated; never edit by hand) |
| `shaders/` | `skin.gdshader` (melanin, undertone, haemoglobin, flush, mucosa, cavity, freckles, stubble), `eye.gdshader`, `face_hair.gdshader` (brows, lashes), `hair.gdshader`, `hair_cards.gdshader`, `hair_common.gdshaderinc` (character shaders live here, not in `shaders/`) |

The player wears the customizer head, hands and hair today (`PlayerAppearance`, see
`tools/character/README.md`) over the legacy outfit of `actor_b_body.glb`, whose Body,
Face and Hair meshes it hides; O opens the customizer.

All customizer glbs carry the full 291-joint armature in rig order, so
`CharacterBodyMesh.attach_parts()` binds them with one shared Skin. Their `.import` files
turn off LOD and shadow-mesh generation: both would merge vertices across region borders
and break the hide mask.
