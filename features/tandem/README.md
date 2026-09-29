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

## Solo wide upright kneel

Ctrl+N enters the wide-knee upright kneel, with arms hanging down. K plays a short dip and rise through the pelvis and thighs; B plays a forward/back pelvic tilt. Repeated presses restart the selected reaction. Backspace, Escape, or movement exits and restores normal animation and controls.

The pose is independent of the paired interactions. `--wide-kneel-preview` launches it on the clothed female base character.

Edit `tools/author_wide_kneel.gd`: `KNEE_X` is half the knee spacing (0.28 m), `HIP_BACK` controls the resting hip offset, `BOUNCE` is the rise before settling (0.015 m), and the wave uses a 2-degree pelvic tilt plus a distributed spine curl. Re-bake with Godot's headless `--script res://features/tandem/tools/author_wide_kneel.gd`. The baker preserves thigh/shin lengths and checks planted knees and ankles at every sample.

Verification: `--headless --script res://features/tandem/tools/check_wide_kneel.gd` checks actual FrontierPlayer pose ownership, grounded contacts during both reactions, visible pelvis motion, return to idle, rapid reaction switching, and movement restoration. Initial run: 0 failures. Idle pose visually inspected in the Frontier world.

## Solo reverse plank

Ctrl+Shift+N enters the face-up reverse plank; K plays the shallow pelvis dip and recovery (0.8 seconds, 4.5 cm drop). Backspace or movement exits. Ctrl+N still selects the wide kneel. The pose uses planted palms and heels, with two-bone solves preserving arm and leg lengths.

Tune `HIP_HEIGHT` and `DIP` in `tools/author_reverse_plank.gd`, then bake via Godot `--headless --script res://features/tandem/tools/author_reverse_plank.gd`. Native-player regression: `--headless --script res://features/tandem/tools/check_reverse_plank.gd`. Preview: `--reverse-plank-preview` (clothed female base character).

Pose calculations use skeleton-relative global bone poses as documented in [Godot Skeleton3D](https://docs.godotengine.org/en/latest/classes/class_skeleton3d.html); runtime verified on installed Godot 4.7.2. Native regression passed with fixed hand/ankle contacts, a 4.49 cm dip, idle recovery, immediate repeat input, and normal movement restoration.

## Wide Kneel supported by a supine partner

In Reverse Plank, I invites a clothed female Wide Kneel companion. Once she is ready, the base lowers onto her back and turns her open palms upward beneath the companion's hips. The companion's knees remain grounded on either side of the lower torso. `partner_offset` in `reverse_plank.gd` controls her position (default rig-space Z -0.02 m).

In the pair, K and B control Wide Kneel’s existing flinches. When the flinch completes and its 0.10 s return-to-idle blend settles, the lower player plays a backward upper-body stamina recoil and returns to the supported hold. Backspace or movement releases the pose and removes the preview companion. Losing the partner's pose/death also releases the support.

`--reverse-wide-preview` opens the pair in Frontier. Bake the support with `--headless --script res://features/tandem/tools/author_hip_support.gd`. Rendered native-player check: `--script res://features/tandem/tools/check_hip_support.gd` (requires a visible window; writes side/front screenshots to /private/tmp). Initial check: 0 failures, grounded upper knees, 0.27 m pelvis-center separation, normal animation restored on exit. Hand placement and the resting-back pose inspected from two angles.

Support-pose revision: upper partner shifted 0.14 m toward the base pelvis; hand targets follow at Z -0.03 m. Base feet are aligned by the heel-to-ball axis (toes up), with ankle height 0.095 m so heels rest at ground level. Updated rendered native-player check: 0 failures, including upright toes and heel clearance.

## Stamina reaction after settling

Wide Kneel emits `settled(kind)` only for the completed current flinch. Restarting a flinch cancels the previous pending completion; leaving cancels delayed notifications. The lower player reacts to that signal rather than reacting on button press. The lower pelvis stays at rest, and support hands and heels remain fixed throughout its recoil.

Upper flinch cost: 5/100; lower completed-settle reaction cost: 10/100. Both recover 3 stamina/second after 0.75 seconds of rest. Controls in the companion preview: K upper bounce, B upper wave, Backspace exit.

Native timing/lifecycle regression: Godot `--headless --script res://features/tandem/tools/check_settle_reaction.gd`. Initial result: 0 failures, no early response, one response after settling, actual stamina drain and idle recovery, immediate repeat input, and no response after exiting.

## C-shaped spine wave

B now rounds the torso forward into a C curve and releases it back to the original hold over 0.9 seconds. Extra curl at peak: spineb 6 degrees, spinec 9, spined 9, neck 8; the pelvis has a small 2-degree rocking envelope. Knees and feet remain fixed. This is baked animation; the limb solves happen during authoring, rather than live IK during play.

Rendered native check: `--script res://features/tandem/tools/check_c_spine_wave.gd`. Initial result: 0 failures; knee grounding, visible peak curvature, and return to the original resting pose verified. Screenshots: /private/tmp/wide-c-wave-0.0.png, wide-c-wave-0.45.png, wide-c-wave-0.9.png.

Entry now selects the supine hip-support hold immediately. Hands stay in that same palms-up position before joining, during the pair, after recoil, and after the partner leaves. Solo K uses the upper-body recoil while retaining support hands and grounded heels.

## Reversed Wide Kneel variant

R switches the supported Wide Kneel partner between original facing and 180-degree reversed facing while idle. The rotation preserves the world-space pelvis anchor, so the lower player's hip-support hands keep their placement. K/B retain the same flinches and delayed lower-player stamina response. R before inviting selects which facing the companion enters with.

Preview the reversed pair with `--reverse-wide-reversed-preview`; the original `--reverse-wide-preview` is retained. `partner_reversed` in `reverse_plank.gd` also selects the initial variant.

Rendered native-player regression: `--script res://features/tandem/tools/check_reversed_wide_kneel.gd`. Initial result: 0 failures; reversed entry, toggling both ways without anchor drift, grounded knees, and one delayed recoil after the reversed wave all verified. Side/front screenshots: /private/tmp/reversed-wide-kneel-side.png and reversed-wide-kneel-front.png.

## Who may take which pose

The Reverse Plank is the only pose anyone may take, a man or a woman, alone or under a partner; the one who kneels over
it (the Wide Kneel) is always a woman (the user 2026-09-29: "reverse plank is the only postion where both sexes can use
but only women can enter as a partner"). The Wide Kneel alone (Ctrl+N), the crawl and Happy Baby are led by women, as
before; a look changed to a man's mid-pose stands the Wide Kneel up. `reverse_plank.gd` `take_partner` turns a man away.

## The Reverse Plank pair in play

Like the crawl and Happy Baby pairs:
- **Joining**: in the Reverse Plank, **I** invites the companion (a woman) to kneel over you; as a woman next to someone in
  the Reverse Plank with nobody over them, **I** kneels over them (`FrontierTandem.join_nearby`).
- **Stamina**: the tandem bars (yours left, the other's right) while the pair holds. Her flinches (**K** a dip and rise,
  **B** the C-spine wave, from either of you) cost her 5 of 100 and stop when she is spent; each one, once it settles,
  makes him recoil under her at 10 of 100; both regain 3 a second after 0.75 s at rest. Spent holding her up, he gives out
  and the pose ends (as Happy Baby collapses).
- **Flinch gauge**: her flinches and his recoil play as full as the genital stat of the man in the plank gives
  (`FrontierTandem.gauge_for`; a woman there: the authored clip).
- **Checks**: either of them hurt or killed ends it (she hurt or standing up: he lies back alone); his breeches down at the
  knees while she kneels over him (`companion` / `joined` / `mode`, as FrontierPlayer._skirt_tuck reads the tandem poses).
- **Camera**: the cinematic camera (**C**) frames the pair side-on.
- **Yoga together** (scripts/companion/tandem_link.gd): the pose menu's "Wide Kneel on the Reverse Plank"; the woman
  kneels (the wife over a male player, a woman player over her husband), the
  man lies in the plank; the session, its end and the pregnancy roll after it as the other poses'.
