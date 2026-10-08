# Elemental animation reference and first polish pass

2026-10-08. Local reference review and animation presentation changes; no spell balance or networking changes.

## Delivered

The user's Spellbreak community Windows client is separately extracted at
`/Users/kiwimango/Downloads/Spellbreak_Reference_Extracts`.
Its `godot/project.godot` is a standalone searchable motion viewer, using 1,188 native
Godot AnimationLibrary resources and 205 matching source rig scenes. Interchange
GLB files are also included. The source rig hierarchy comes from cooked Skeleton
assets, not the unreliable parent placeholders in the PSA export. Removed tracks
are restored from the source rest transforms using UE Viewer's `.config` records.
Axis, quaternion, centimetre-to-metre and missing-track handling were verified
with numeric checks and a rendered human clip. These are attributed third-party
reference conversions, not Tidebreak-authored clips or retargeted Actor_B motion.

The PSA conversion preserves sampled position/rotation. Additive clips retain
their source additive-type metadata and require a suitable base pose and blending
setup; the viewer warns about this. Curves, notifies, live IK and scale animation
remain in the original reference records rather than being recreated as runtime
Godot behaviour.

The original Unreal graph remains a decoded/runtime reference, not an executable
Godot AnimationTree. Its custom orientation-warp nodes, gameplay predicates and
engine ownership require deliberate Godot equivalents; importing it wholesale
would not supply the game's movement or spell simulation.

In Tidebreak, five existing authored clips were revised and rebaked:
`earth_push`, `fire_punch`, its mirrored `fire_punch_l`, `water_wave`, `air_sweep`.
Changes are in the typed key tables in
`tools/anim_author/blender/bend_clips.py`, installed using
`tools/anim_author/install_bend.gd` into `animations_extra/Frontier_Bend.res`.
The generator reads the project rig's rest pose and the project's authored keys;
it does not read the extracted Spellbreak clips. No third-party motion was added
to the game library or relabelled as original.

Earth's hips lead its heavy push and its chest settles after impact. Fire's
rotation snaps through the punch before relaxing. Water adds a continuous,
offset torso arc. Air carries the turn through its sweeping palms. These are
broad elemental/martial movement goals inspired by the user's Avatar direction,
not recreations of specific shots or claims of an authentic martial performance.
Clip names, lengths, hold/strike/recovery times, cast masks and gameplay balance
values remain unchanged.

## Observations and lessons

| Direct observation in the local reference | Implication for Tidebreak |
| --- | --- |
| `animation_tree/Human_runtime_graph.json`: separate UpperBody, Locomotion, Stance, Jump and Fly state machines; three LayeredBoneBlend nodes | Keep movement authoritative and layer casting over it. Our SwayPose/ToolPose and airborne leg layer already follow this approach; avoid routing every cast through a whole-body grounded pose. |
| `decoded/.../Magic_BoulderAttack_R_Montage.json`: XAnimNotify_ActionPhase objects carry `Action.Phases.Active`, `Recovering`, `Ending` | Make release and recovery explicit events. Tidebreak already schedules effects from SwayPose.struck with a fallback clock; maintain that timing contract when polishing visuals. |
| `spell_logic/decoded/.../BP_Action_WeaponUse_Earth_Primary_Windup.json`, `_Hold.json`, `_Finish.json`: separately serialized actions; windup Duration 0.381356, finish 0.847458, custom-duration flags | A sustained hold should have a readable hold pose, then a distinct release and return. These are serialized defaults, not measured effective in-game durations. |
| Those action packages include GActionMutator_DurationScaleAttributed, weapon-hand montage selection and resume-action records | Keep attack-speed modifiers and left/right choices consistent across animation and spell clocks. Do not change cooldowns by merely speeding up a clip. |
| The main graph contains 20 BlendSpacePlayer and 16 OrientationWarp nodes | Directional locomotion and facing compensation deserve explicit treatment. Godot cannot inherit these custom Unreal nodes; first evaluate our locomotion blend inputs, foot planting and aim offset. |
| Earth/Fire/Ice/Wind action blueprints contain distinct aim/cancel/fire or windup/hold/finish variants | Cancellation and recovery should preserve current airborne state, not reset movement to a falling or grounded default. This is a design inference from the action records; the compiled native implementation was not recovered. |

The actionable priority is readable anticipation, release, follow-through and
return with uninterrupted movement. For our ring game, prominent launch and
knockout poses should remain separate from controllable fall/recovery motion.
Animation data alone cannot explain win rates: aim rules, collision, charge
windows, knockback, stage geometry and player skill need gameplay measurement.
No conclusion about 25% balance or copying another game's projectile behaviour
was drawn from these assets.

## Validation

- All 1,188 converted GLBs parsed in Godot 4.7.2; their animation libraries saved,
  reloaded and sampled at early/middle/late times; all hierarchy poses were finite.
- Source skeleton names were checked for ambiguity: no duplicate Skeleton asset
  names in the selected package catalogue.
- Converter regressions cover missing-track restoration, rotation/rest agreement
  and retained attribution.
- The human BoulderAimStartR reference was rendered at start, middle and end from
  different angles. This is a representative visual check, not visual approval
  of all clips, every outfit, retargeting or additive layering.
- The four revised Tidebreak casts were rendered as contact sheets from front
  three-quarter and side views at five moments.
- Existing bend-clip checks: 3,762 passed. Ring pose transitions: 12/12 passed.
  Bend casting regression passed.
- Broader R3 AIR regression: 81/82; the expected hit landing-lag discount is
  0.20 instead of 0.10 in its fixture. The identical failure occurs with the HEAD
  animation library before this polish. It remains an existing issue; the test
  was not weakened and gameplay rules were not changed to conceal it.

## Official documentation used

- [Godot Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html): dedicated bone position/rotation tracks and AnimationPlayer playback.
- [Godot Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html): bone rests, hierarchy and skeleton-relative global poses.
- [Godot 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html): glTF interchange.

The Godot skill and installed engine API were used; the local binary is
4.7.2.stable.mono.official.ed1daf0bf.

## Follow-up experiments (2026-10-08)

R3 Air's isolated landing-lag group passed all seven checks with `--fixed-fps 60`
before the new identity effects were added. The full suite then passed all 82
checks with the same setting. The earlier unrestricted-frame run failed the
hit-discount check with both the previous and polished animation libraries.
This comparison points to a timing-sensitive fixture condition; it does not
establish that changing animation art fixed a gameplay bug.

The next art experiment builds four new geometric release marks from local
mathematical paths and changes the existing garment colours. It tests the lesson
that distinct shapes and brief release feedback can communicate element identity
without adding cast delay or gameplay owners. See `docs/monsoon_identity.md` for
exact changes, rendered validation and remaining limits.
