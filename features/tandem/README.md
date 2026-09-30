# Frontier in-world tandem poses

Implemented only in `Frontier_wt/tandem-animations`, branch `codex/tandem-animations`,
based on main commit `e41ed2e`. Main has not been merged or edited.
This worktree uses its own `Frontier_tandem_worktree` save/settings directory.

## In the game

Run Frontier normally from this worktree and enter the fort.

**Two roles.** The *lead* is in the crawl or Happy Baby: women only. The customizer look's `sex` decides
(`CreatorOptions.is_male`); a player with no customizer look wears the legacy female base body and counts
as a woman. For a male look **N** / **Shift+N** do nothing (the key is not consumed), and a look changed to
male mid-pose stands the lead up. The *partner* (kneeling behind the crawl, in the plank over Happy Baby)
is open to anyone, of any look.

**Joining a tandem.** Walk up to a woman who is in a pose (within 3 m) and press **I**: you become her
partner, whatever your look. In Happy Baby she must be holding the pose. As the partner: **Enter** dips
(Happy Baby), **K** reacts (crawl), **C** the camera, **Backspace** / **N** / **Esc** / move stands you up
(she stays in her pose). Only one partner at a time. There is no on-screen text or key prompt; the keys
here are the only guide.

- **N** enters crawl. **Shift+N** enters Happy Baby.
- **I** invites the local companion (as the lead; as anyone next to a posing woman, **I** joins her: see below). She appears beside you and joins by herself as soon as both of you are
  ready (in Happy Baby, once you are holding the pose); **Enter** joins at once. An invitation nobody can
  answer (no flat ground) is dropped after 12 s.
- Crawl, as the lead: **B** her own backward flinch. **K** is the paired flinch (see Flinches).
- **C** turns the cinematic camera off and on. Once both are in the pose the camera settles side-on to the pair,
  a little above, and drifts slowly; on leaving it goes back to the normal camera.
- In crawl: **K** triggers repeatable paired flinches and **B** the lead's own backward flinch. These are the
  crawl's only two flinches.
- In Happy Baby (about 4 s to enter): invite, then **Enter** triggers plank dips; the lead flinches as each
  dip bottoms out.
- **Backspace**, **N**, **Escape**, movement or jump stands up and restores normal play.
- Crawl reactions cost stamina; both participants recover slowly while idle.

The companion is a real nonlocal FrontierPlayer with the game's rig and the current body (body v4, a female
`CharacterPeoples` preset, `COMPANION_LOOK`). Clothes follow whatever the game dresses the body in.
The invitation is answered by that local companion. This is not a network
multiplayer implementation; remote invitations/replication still need networking.

**Joining and leaving.** The partner walks into the pose over 0.6 s. An NPC partner (the companion) walks out
of it again to where she stood; a player stands up where she is and walks off. The pair share the spot in Happy
Baby, so the collision exception between them is lifted only once they are apart (lifting it on top of each
other threw the player across the map).

**Stamina bars.** Two bars, bottom centre, while a pair is in the pose (no text): yours on the left with a
small marker under it, the other's on the right; green, amber, red, pulsing when nearly out. Both poses.
- Crawl: both keep their own pool of 100 (modelled on `PlayerGrip`, not shared with it: it is not the climb /
  melee stamina, `player.grip.stamina`). Holding is free; every flinch costs 10 (K, B), and the partner's K
  costs her 5. Regains slowly while idle.
- Happy Baby: the lead holds for 120 s (the bar drains 1 a second, she shakes in the last quarter, and collapses
  at zero: she stands up). Each dip costs the partner 25 of 100 (about four in a row, then a pause: she
  regains 3 a second after 0.75 s) and strains the lead 3 s of her hold. `YOGA_*` / `PLANK_*` / `DIP_*` at the
  top of `frontier_tandem.gd`.

**Crawl arm hold (IK).** The partner's right hand holds the crawler's right bicep, and her right arm is held up.
`tandem_arm_lift.gd` (on the crawler) aims her right upper arm about 40 deg above level, back and a little out, and
her forearm on from it almost straight (`upper_dir` / `fore_dir`), rolls her torso 30 deg about its own long axis so her chest opens toward her right and her right side comes up
(`chest_roll`), with a further 14 deg turn (`twist`) and
moves her right shoulder joint 4 cm toward her left (`shoulder_left`) and up about 4 cm by rolling the
clavicle 15 deg (`shoulder_up`, on top of the torso roll), all eased in as the partner moves in.
`tandem_arm_hold.gd` (a `PalmReachIK`, on the partner) puts the partner's right palm on that upper arm every frame,
leaning his spine forward if the reach needs it (35 deg at most; with her arm raised it needs none), so the hold
follows her through K, B and the backward recoil. Both are removed when either stands up. **B** also makes the
partner rock back (`kneel_backward_flinch.tres`, baked by `tools/author_kneel_backward.gd`), 0.15 s after her, at
the flinch gauge. The cinematic camera takes both poses from her right side (`CINE_SIDE`).

**Flinches.** Crawl: **B** the lead's own backward flinch, **K** (either partner) a paired flinch, answered by
the lead 0.15 s later. No other keys flinch. Happy Baby: each dip makes the lead flinch (`yoga_hold_controller.flinch()`, 0.33 s in).

**Flinch gauge.** How full a flinch plays comes from the male partner's genital stat (the look's `genital`,
-1..1, the customizer's body slider): **1** plays the authored flinch, **0** half of it, **-1** a quarter, linear
between (`GAUGE_AT_*` in `frontier_tandem.gd`). It scales the partner's own K flinch and the lead's answer
(a K in the crawl, a dip in Happy Baby); the lead's own **B** is always as authored. A partner who is not a man
has no such stat and flinches as authored. The scaled clips are made once from the authored ones (each key moved
that fraction of the way from the clip's first pose; `TandemClips.variant`, steps of 5 %) and kept in the
AnimationPlayer's library as `<clip>@<percent>`. The stat comes from the look, so a preset's value is whatever
`peoples.json` gives it; set `genital` on a look to change it.

## Ownership and integration

`frontier_tandem.gd` installs through the player construction in
`scripts/world/frontier_level.gd`. It uses FrontierPlayer.begin_kneel/end_kneel
for the existing animation, movement, weapon and modifier handoff. The normal
PlayerAnim is suspended while a pose controller owns the canonical skeleton.
Polling building, interaction, equipment and weapon subsystems pause for the pose
and restore on exit. Damage, death, exhaustion and teardown cancel the pair.

`frontier_tandem_clips.gd` duplicates and remaps imported animation tracks by bone
name to the existing rig. Shared locomotion resources are not modified. Partner
placement follows the rig's facing (+Z) relative to FrontierPlayer's facing (-Z).
Each participant keeps its CharacterBody3D. Ground level is checked when joining;
the two bodies temporarily ignore one another while holding the close pose.

Current crawl rig offset is `(0, 0, -0.30)`; the crawling response follows K by
0.15 seconds. The authored backward clip keeps hands and knees planted.

## Focused verification

The native-player check creates actual FrontierPlayer instances and verifies crawl,
canonical pelvis height, invite/accept, native partner alignment, backward reaction,
Happy Baby entry, plank dip, and restoration of the normal animation owner on exit.
These checks passed with zero failures. The standalone rapid-input and grounded
backward-recoil checks also passed after packaging.

For visual review, run the real `scenes/main.tscn` with a user argument (add `--no-creator` on a first launch):
`--tandem-preview` (a crawl pair) or `--tandem-preview-yoga` (a Happy Baby pair) sets up the pair at the normal
spawn and lets the cinematic camera frame it; `--two-pose-preview` puts two NPC women in front of the spawn, one in Happy Baby and one
crawling, and leaves you free to walk up and press **I**. The ordinary game remains manually controlled without these arguments.

## Original prototype scenes

`crawl_demo.tscn` and `demo.tscn` remain available with F6 for comparison, using
mannequins and separate `tandem_` actions. Their controls are shown on screen.
`tools/author_crawl_backward.gd` reproduces the baked recoil resource.
`source_manifest.json` records the original standalone source and packaged files.

## The two tandem poses in the game (the rest were taken out: user 2026-09-30)

**Happy Baby** (Shift+N, a woman leads; anyone joins with I; the yoga-together menu offers it) and the **puppy** (Ctrl+P, a crawl-derived
solo pose; I invites an upright kneeling partner behind). Happy Baby has the updated motions (`happy_baby_motion.gd`,
`kneeling_plank.gd`, `happy_baby_brace.gd`, `tandem_eye_contact.gd`, `tandem_thigh_alignment.gd`, started from `frontier_tandem.gd`
`_install_happy_motions`). The crawl, the Wide Kneel and the Reverse Plank (and the pairs of them) are no longer reachable: `start_pose`
only starts "yoga", and `wide_kneel.gd` / `reverse_plank.gd` and their clips and tools are gone. The old crawl and upright-crawl code is
dormant in `frontier_tandem.gd`.

## Solo puppy pose

Ctrl+P enters a crawl-derived puppy pose with hips above the knees, lowered chest, and arms extended forward. Backspace or movement exits. Pose shaping constants live in `tools/author_puppy.gd`; run that script to rebuild `puppy_idle.tres`. Use `--puppy-preview` to preview in Frontier.

Puppy reference update: deeper chest lowering (55 degrees), a 65 degree neck counter rotation for the forward chin, near-straight arms and flatter hands. Knees and feet keep the crawl ground anchors. Tune `CHEST_DROP_DEG`, `NECK_LIFT_DEG`, and `HAND_FLATTEN_DEG` in `tools/author_puppy.gd`.

Puppy saddle update: knees spread to 0.56 m, hips lowered geometrically to keep the knees planted without stretching the thighs. The torso lowering is reduced to 45 degrees to give the chest more forward reach. Tune `KNEE_HALF_WIDTH` to adjust the stance width.

Wide puppy reference update: lower legs flare outward by 20 degrees and the ankles/toes relax backward close to the floor. A gentle upper back extension lengthens the chest reach. Tune `SHIN_FLARE_DEG`, `ANKLE_HEIGHT`, `TOE_DROP`, and `UPPER_BACK_EXTENSION_DEG` in the authoring script.

Lower-back arch: `LOWER_BACK_ARCH_DEG` adds a downward arch at the pelvis-to-`spinea` connection by rotating `upper_base` and its spine subtree around the fixed low torso anchor beside the pelvis. `spineb` compensates to maintain the chest angle. Bone lengths remain unchanged, and hands are solved back to ground height.

Pelvis apex adjustment: `PELVIS_TILT_DEG` tilts the pelvis at the peak of the torso/thigh V. The grounded legs are re-solved after the tilt; the stronger waist-only arch is reduced.

Puppy forward flinch: press K while holding puppy. Hips and upper body advance 4.5 cm, peak after 0.12 s and return by 0.55 s. Knees and every bone below them keep their idle world transforms; the thighs re-solve without stretching. Repeated K restarts the flinch. Tune `FLINCH_FORWARD`, `FLINCH_LENGTH`, and `FLINCH_PEAK_TIME` in `tools/author_puppy.gd`.

## Puppy + upright kneel tandem

Ctrl+P enters puppy; I invites an upright kneeling companion behind the lead. K starts the kneeling flinch, followed by the puppy forward flinch after 0.15 seconds. Backspace/movement exits and releases the companion. Both use their grounded lower-leg animations. In `pose_test.tscn`, button/key 4 selects the pair; `--puppy-tandem-test` starts the test with it. Placement is adjustable with `partner_offset` in `puppy_tandem.gd`.

### Puppy and upright kneel wave/sway

While in puppy, press O for a pelvic wave or U for a side-to-side sway. With a partner, these move both players on one clock. Ctrl+O/U moves only puppy; Shift+O/U moves only upright kneel. The isolated pose test offers the same choices in its Motion dropdown. Each press plays one 1.8-second cycle and settles back into the existing hold. Flinch cancels the motion, and leaving removes the modifiers. These are procedural skeleton animations after the base clips, with knees/shins/feet fixed and thigh lengths constrained. Tune duration and offsets in `yoga_motion.gd`.

