# Procedural horse

`build_horse.py` generates the rideable horse in headless Blender: the mesh, the rig,
hair cards, 1750s tack and 32 animation clips, plus the baked coat textures. It writes
`assets/horse/horse.glb`, `assets/horse/horse_meta.json`, `assets/horse/textures/` and
`assets/horse/MANIFEST.json`. Everything is generated. The only third-party inputs are the
project's Poly Haven CC0 leather, wool and hessian textures on the tack, copied at 1024 px
into `assets/horse/textures/tack/`. The materials (coat, hair and hoof shaders, tack) are in
`assets/horse/materials/`. `scripts/horse/horse_look.gd` applies them and the coat variants.

The design and the rider-clip analysis are in
`source/graph_analysis/melee_horse_prone/horse.md`. §0.4 of that file
(revision 5) covers the skeleton below and the skinning; §0.3 (revision 4) the proportions,
the hindquarters and hind-leg motion, the pace (speeds against the rider clips' step timing),
the exported key rate and the playback checks; it supersedes the speeds and several numbers
in §0.1 and §0.2. §0.1 covers the size, rider fit, turning and the jump; §0.2 the look (coat,
hair, tack materials, coat variants, triangle budget). The reviewed first prototype is
described in `horse_prototype.md` in the same folder.

## Skeleton (revision 5)

60 bones. The legs hang from a vertebral column instead of from one rigid trunk:

- **Column.** `body` is the trunk control the gaits pitch, roll and bob (not skinned). On it:
  - `chest`: T1-T9, the withers and the front of the ribcage; the shoulder blades and the
    neck hang from it;
  - `back`: T10-T18, the saddle (`saddle`, `passenger` and the stirrups hang from it);
  - `loin` (L1-L3), then `loin_2` (L4-L6);
  - `hips`: sacrum and pelvis, turning about the lumbosacral joint; the femurs, the thigh
    helpers and the tail (`tail_1`-`tail_4`) hang from it.
  - Neck: `neck_1`-`neck_3`, `head` (ears, `bit`).
  - A flexion of the back (canter, gallop, jump) is shared 40 / 60 % by the loin_2 and
    lumbosacral joints (`anatomy.SPINE_FLEX`), so the topline bends in a curve; L1-L3 (`loin`)
    stay stiff and only bend sideways. The curved
    gait variants and the turns in place bend the trunk along the arc: the chest turns into the
    turn and the loin and pelvis the other way, up to 4 deg each end (`SPINE_BEND`,
    `Solver._bend`); the hooves stay planted on the arc.
- **Shoulder.** The shoulder blade has no joint with the trunk. `scapula_l/r` turns about a
  point 22 % of its length down from its upper border (`SCAP_PIVOT`), carrying the fore leg,
  with the same shoulder-joint travel as before. It glides 1.5 cm down the ribcage while its
  leg is unloaded (`SCAP_SLING`): early in the swing it sinks, and it rises again as the leg
  takes weight up to mid-stance.
- **Pelvis and hind leg.** Unchanged from revision 4: the pelvis pitches, rolls and yaws with
  the hind legs; hip -> stifle -> hock -> fetlock is solved with the reciprocal apparatus.
- **Joint helpers** (`anatomy.helpers()`): `shoulder`, `elbow`, `knee` (carpus), `fetlock`,
  `thigh` (hip), `hock` and `hfetlock`, left and right. Each sits on the proximal bone at the
  joint and turns half as far as the distal bone does against it. `gaits.Solver._helpers`
  poses them in the clips. `HorseTerrain` poses them again after its leg IK, from
  `horse_meta.json` `"helpers"` (helper -> [proximal, distal, fraction]). The stifle has no
  helper; one creased the stifle more than the plain blend did.

The runtime contract is by bone name: `HorseTerrain` (`LEGS`, `BONES`, and the asset's
`helpers`), `Horse` (`saddle`, `body`, `neck_1`-`neck_3`, `head`, the hooves) and
`HorseRiderLink` (`chest`, `neck_1`-`neck_3` for the crest).

**Skinning** (`skinning.py`). Blender's heat weights, which spread smoothly over the skin, with
four fixes:
- a vertex loses the other side's limb bones;
- the withers go to the chest, not to the moving tops of the shoulder blades;
- the column's share is spread smoothly along the body;
- at every helper joint, the proximal/distal blend t becomes (1-t)^2, 2t(1-t), t^2 on
  proximal, helper and distal.

At most four influences. The revision 4 hindquarter override, weights rebuilt along the limb
chains and smoothing over the junctions were all measured worse (`skin_check.py`) and dropped.

## Run

```sh
tools/horse/build_horse.sh                   # about 3 min: glb + textures + meta + manifest
tools/horse/build_horse.sh --gaits-only      # gait solver diagnostics only
tools/horse/build_horse.sh --previews DIR    # also Eevee stills (rest pose and gait frames)
python3 tools/horse/gait_check.py [--clips walk,trot_tl] [--json OUT]   # diagnostics without Blender (20 s)
python3 tools/horse/proportions.py [--json OUT]                          # conformation against a real horse (1 s)
python3 tools/horse/skin_check.py [--glb PATH] [--json OUT]              # skin deformation per region, from the glb (5 s)
tools/horse/build_horse.sh --dump-skin /tmp/skin.npz && python3 tools/horse/skin_check.py --mesh /tmp/skin.npz
                                             # the same before a build: skin + heat weights (45 s), then skinning.py + the solver
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --import
```

Then check the result. Run Godot under a time limit; a script error leaves it running.

```sh
Godot --headless --path . -s tests/horse/test_horse.gd -- out=/tmp/horse_report.json   # 194 checks, about 5 min
Godot --path . --resolution 1280x720 -s tests/horse/horse_look_shots.gd -- out=/tmp/look shots=turn,close,coats,ride   # look (opens a window)
Godot --path . --resolution 1280x720 -s tests/horse/horse_look_shots.gd -- out=/tmp/look shots=level                  # in the level
Godot --path . --resolution 1100x620 -s tests/horse/horse_strips.gd -- out=/tmp/strips stick=1   # side-view strips with footfalls (opens a window)
Godot --path . --resolution 1100x620 -s tests/horse/horse_strips.gd -- out=/tmp/strips view=closeup34 tag=fit  # rider fit
Godot --path . --resolution 1100x620 -s tests/horse/horse_strips.gd -- out=/tmp/strips clips=walk,trot,canter,gallop hind=1 view=rear34 rider=0  # quarters through the hind stance and swing
Godot --path . --resolution 1280x720 -s tests/horse/ride_demo_shots.gd -- out=/tmp/ride     # scripted ride (opens a window)
Godot --path . tests/horse/ride_demo.tscn                                                    # ride it yourself
Godot --headless --path . -s tests/horse/horse_hills.gd -- out=/tmp/hills                    # the level's hills: pitch, toes, speed caps, refusal (about 4 min)
Godot --path . --resolution 1100x620 -s tests/horse/horse_hills.gd -- out=/tmp/hills strips=1 only=steep cam=4.2   # side-view filmstrips on the hills
Godot --path . --resolution 1280x720 -s tests/horse/horse_shrub_ride.gd -- out=/tmp/shrubs   # through shrubs, saplings, stumps and logs; a trunk still blocks
Godot --path . --resolution 1280x720 -s tests/horse/horse_ride_camera.gd -- out=/tmp/ridecam # E mounts, the riding camera, hold E dismounts, no wording
```

The runtime slope layer (`scripts/horse/horse_terrain.gd`, `HorseTerrain`) needs no asset data
beyond the bone names in its `LEGS` / `BONES` tables and `horse_meta.json` `sockets.hoof_toes`
(optional): it reads the leg lengths and joint positions from the skeleton, so a rebuilt rig that
keeps those names keeps the hills.

## Files

| File | What it does |
| --- | --- |
| `sdf.py` | Small signed-distance toolkit (numpy only): ellipsoids, round cones, lofts along y, z (`LoftZ`, the thigh and gaskin) or a path, smooth CSG, `Scaled` (anisotropic stretch), surface-nets polygonisation, Newton projection onto the surface. |
| `anatomy.py` | Size (a 13-hand base stretched by K to 14.1 hands), the proportions warp (the body shortened in front of and behind the saddle, the legs moved with their girdles, the face shortened about the poll; the saddle region is not moved), the rider-derived seat and attach heights, joints (the real-proportioned hind limb), the 60-bone table (the vertebral column, the joint helpers, `helpers()`, the shoulder-blade pivot and sling), the body shape (torso loft, the quarters: croup, gluteal mass, points of hip and buttock, the thigh-gaskin loft; neck, the head in a face frame, legs with their bony and muscular landmarks), the eyeballs, the diagnostic and the render hooves (shallow sole, frog), and the tack. |
| `coat.py` | Coat textures baked with numpy from the skin SDF in the rest pose: tangent-space normal (anatomy detail, ribs, hair streaks), masks (points, dapples, countershade and dorsal stripe, white markings), detail (hair streaks, SDF ambient occlusion, mealy areas, bare skin and horn) and the hair flow. |
| `hair.py` | Hair cards (mane, forelock, tail, fetlock feathering) that follow the skin, and the strand texture. |
| `proportions.py` | Measures the skin (withers, croup, body length, point of buttock behind the hip joint, chest depth, head and mouth-to-poll, neck, forearm and cannon girth, cannon width, hooves, widths) against typical ratios for a stocky 14.1-hand horse. |
| `gaits.py` | Gait generator; details below. |
| `gait_check.py` | Ground-frame diagnostics for every clip: stance slip, teleports, skating, swing-end ground speed from the exact stance windows (the 1/30 s before touchdown and after lift-off), swing clearance, toe drag, sinking, leg reach, neck carriage, the jump's rail clearance; the hind joints' ranges (hip against the pelvis, stifle, hock, fetlock, sampled at 240 Hz), the pelvis motion, and the playback check: the clip as the engine plays the exported keys (linear interpolation) sampled at 240 Hz with the shipped hoof mesh (sinking, drift of hoof points on the ground). `build_horse.py` writes them to `horse_meta.json`, and the Godot test checks them. |
| `build_horse.py` | Blender driver: armature, meshes (faces oriented by the SDF gradient, then decimated), UVs, the coat bake and texture import settings, heat weights on the skin, then `skinning.py`; the skin's weights copied to the mane and the fetlock feathers, rigid weights on the tack; one action per clip, keyed at 120 Hz for the trot, canter, gallop, sprint and jump and 30 Hz for the rest; glTF export at 120 fps, then the 30 Hz clips cut back to their own keys and the channels that hold their bone's rest value all through dropped (as the importer's remove_immutable_tracks would); metadata (`rig`, `helpers`). `--dump-skin PATH` saves the skin and its heat weights for `skin_check.py --mesh` and stops. A build with `--out` elsewhere writes its coat textures next to it and leaves the project alone. |
| `skinning.py` | Skin weights from the heat weights (numpy; above). Runs in the build and in `skin_check.py --mesh`. |
| `skin_check.py` | Skin deformation per region (shoulder blade, point of shoulder, elbow and girth, forearm, knee, fore fetlock, hip, flank, stifle, gaskin, hock, hind fetlock, withers, back line, croup) over the clips: edge stretch, triangle area, crease sharpening, folded triangles and patch volume against the bind pose, with linear blend skinning as the engine does it. From the glb, or (`--mesh`) from a skin dump with `skinning.py` and the gait solver. |
| `blender_util.py` | Mesh, material, decimation, colour attribute and preview helpers. |
| `rider_curves.json` | Timing extract of the Actor_B riding clips: clip lengths, the saddle curve `saddle_z_norm` and pelvis bounce. It is derived from `horse_data/rider_sync.json` and holds no animation data. |
| `build_horse.sh` | Runs the build under a 10-minute time limit. |

**What `gaits.py` does:**
- Every clip has a ground frame: a straight line, a circle (curved variants and turns in place), or the jump's ballistic root lift.
- Hooves are planted in that frame during stance.
- The swing runs from lift-off to touchdown with zero ground speed at both ends. Near touchdown the hoof is carried a little ahead of its landing point and swung back onto it (swing retraction).
- Fore legs: two-bone IK with a prescribed carpus bend. Hind legs (revision 4): hip -> stifle -> hock -> fetlock with the stifle and hock flexing together (the reciprocal apparatus); the femur's swing against the pelvis is limited per gait (`hip_rom`), and the hock, the fetlock (stance sink, an early heel rise at breakover, swing flexion) and the pelvis take the rest of the reach. Then pastern and hoof angles.
- The pelvis pitches, rolls and yaws with the hind legs (`pelvis`), and the lumbosacral joint flexes at the canter and gallop (`back`).
- Skinning helpers (revision 5, `anatomy.helpers()`): each turns half as far as its distal bone.
- The column: the back's flexion shared over the loin and lumbosacral joints, the trunk bent along the arc of the curved variants; the shoulder blades turn about a pivot in their upper part and glide in the thoracic sling (above).
- Body bob comes from the rider curves; pitch comes from fore/hind loading.
- Lean and body drop for the curved variants.

## Conventions

- **Blender space:** the horse faces -y, +x is its left, and the origin is on the ground under the saddle attach.
- **Godot space:** the model faces +z. `Horse` (`scripts/horse/horse.gd`) turns its Visual node 180 degrees, so the horse moves along -z like the player.
- **Size:** a stocky 14.1-hand colonial horse (Canadian, Chickasaw or Narragansett type), 1.450 m at the withers, body length 1.05 x the height, head 0.40 x.
  - The seat is 1.371 m above the ground.
  - The **`saddle` bone** rest (the rider clips' origin) is 0.125 m above the seat, at 1.496 m, because Actor_B's breeches sit 0.125 m below the clip origin. The Actor_B rig attaches there with identity (`Horse.get_saddle_transform()`).
  - Ground-relative rider clips (mount, dismount) were fitted to a ground 1.37 m under the origin. On this horse, raise their origin by 1.496 m instead (`horse_meta.json` `clip_ground`).
- **Clip lengths:** every clip has the length and frame count of the Actor_B clip it carries, so rider phase = horse phase.
  - Idle, the gaits and their variants loop.
  - `sprint` is the ten strides of `actor_b-horse-gallop-sprint`.
- **Design speeds:** stride / stride time. At playback rate 1:

  | walk | trot | canter | gallop | sprint |
  | --- | --- | --- | --- | --- |
  | 1.38 m/s | 3.0 m/s | 6.0 m/s | 10.0 m/s | 13.07 m/s |

  `Horse` cruises at 1.4 / 3.15 / 6.2 / 11 / 13 m/s (rates 1.02 / 1.05 / 1.03 / 1.10 / 0.99). The rider clip
  plays within 0.85-1.15 of its authored speed (0.65 at the slowest walk). See horse.md §0.3 for
  the choice between these speeds and faster ones.
- **Variants:**
  - `<gait>_s` is the short stride (walk, trot, canter, gallop). `Horse` blends it with the full stride by speed at rate 1.
  - `<clip>_tl` / `<clip>_tr` are the curved (turning) variants of every moving gait clip. `Horse` blends them in by curvature.
- **Socket bones:**
  - `saddle`
  - `passenger` (0.39 m behind)
  - `stirrup_l/r` (the leathers)
  - `stirrup_iron_l/r`
  - `bit`

  `horse_meta.json` also lists each hoof's toe (`sockets.hoof_toes`).

Provenance: the gait timing comes from the bundled Actor_B riding clips. The horse
asset contains no data from those clips.

## Look

- The glTF carries named placeholder materials. `HorseLook.apply()` (called by `Horse`)
  replaces them by name with `assets/horse/materials/*.tres` and sets the coat.
- `Horse.coat` is one of `bay`, `brown`, `black`, `chestnut`, `grey` or `dun`. Each is a set
  of per-instance shader parameters (sRGB colours, `source_color`), so the materials are
  shared between horses.
- **Budget:** 45.5 k triangles at LOD0 (skin 26 k, hair 3.7 k, tack 12.5 k, hooves 2.5 k,
  eyes 0.9 k). Godot generates the LODs on import.
- **Animation:** `horse.glb` is 6.7 MB (revision 5: channels at their rest value dropped; 12.5 MB before), most of it the 120 Hz keys of the fast gaits.
  `horse.glb.import` imports the animations at 120 fps (Godot resamples on import; at 30 fps
  the fast gaits' hooves sank and slid between keys), with the AnimationPlayer's key
  optimizer off (`_subresources` `"nodes"` / `"PATH:AnimationPlayer"`: `optimizer/enabled`;
  the per-animation settings have no such switch). The optimizer dropped the keys of small
  rotations (the canter's loin_2 kept 87 of 113, the jump 5873 of 7195 rotation keys), and the
  planted hooves drifted more in the engine than in the build's playback model: canter 4.1 ->
  2.9 mm, gallop 5.4 -> 4.2 mm, jump 14.6 -> 8.5 mm with it off, the same as the build's numbers.
- The coat textures are 2048², the hair 1024² and the tack 1024². The build writes their
  `.import` settings: VRAM compressed with mipmaps, RGTC for normal maps, BPTC for the packed
  data maps, and no alpha-border fix on data alpha.
