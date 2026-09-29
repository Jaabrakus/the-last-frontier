extends SceneTree
## Loadout body-fit survey (headless, read-only; writes one JSON file).
##
##   Godot --headless --path <Frontier> -s tools/loadout/measure_body_fit.gd -- \
##       out=/abs/path/raw_fit.json [samples=6] [candidates=res://tools/loadout/candidates.json]
##       [only=<clip substring>] [debug_points="x,y,z;x,y,z"] [debug_pose=1]
##
## candidates=none skips the stow capsules (first pass, before make_candidates.py). only=
## restricts the clip list; debug_points prints the signed distance and nearest outer
## vertices at the bind pose and exits; debug_pose prints every posed candidate capsule.
## tools/loadout/build_fit_data.py turns the output into data/loadout/*.json.
##
## A fresh Actor_B rig (characters/Actor_B.tscn, rest = null-add) with the legacy body
## (CharacterBodyMesh.attach, assets/character/actor_b_body.glb) is posed clip by clip.
## Poses are evaluated here, channel by channel, exactly like the deterministic mixer:
## every bone starts at its rest (= null-add), a full-body clip overwrites the channels it
## keys, a partial ("--part" / "--arm-r") overwrites its channels on top of a base clip,
## and an additive twin ("--add") composes as base * rest^-1 * add (the game's Add2).
## The helper bones are driven by CharacterBodyMesh.skinning_globals(), as in game, and the
## Clothes + Gear meshes are skinned on the CPU.
##
## Everything is in rig (skeleton) space: +Y up, character faces +Z, character right = -X.
## Angles around the torso: 0 = front, 90 = character right, 180 = back, 270 = left.
##
## Measured (sections of the JSON):
##  bind      joints, holster bones, gear parts (belt, straps, pouch, horn) at null-add;
##            outer-surface radius map around the torso axis; full-skin body radius map
##            (the customizer's body.glb, as the skin proxy under the legacy outfit);
##            limb capsule radii; belt band ring.
##  holsters  per clip: the rig stow bones relative to pelvis / spineb / root, their drift
##            from the bind relation, their signed distance to the outer surface.
##  draws     per draw / stow / grab clip and key: hand prop bones, distance to each stow
##            bone, the grab key and the prop-in-holster transform there.
##  grid      points 3 cm outside the outer surface (every 5 cm of height x 15 deg), carried
##            by the skin weights of their surface vertex: per clip category the closest
##            limb capsule (arm / hand / thigh / shin / head sweeps), and per attach bone
##            the drift of a rigid attachment from the skinned surface point.
##  items     weapon / throwable model sizes and markers (WeaponModels / ThrowableModels).
##  candidates (optional) stow capsules from candidates.json, carried rigidly by a bone, by
##            the skin weights of their surface vertex ("skin") or by two skinned anchors
##            ("skin2"): surface clearance and limb sweeps per category and per clip
##            (by_clip), pairwise gaps split into play and traversal clips, drawing reach.
##
## Revision options (loadout design revision 2):
##   extra=1        also samples EXTRA_CLIPS: the draw / grab / holster clips of every draw set
##                  (stand and crouch, 20 Hz; category "draw" / "draw_c"), the riding clips and the
##                  retargeted mount (category "ride" / "mount"; library actor_b_from_a is loaded
##                  from animations_extra/Actor_B_from_A.res) and prone proxies (crawl, get-down, the
##                  face-down cinematic segment; category "prone"). Keys of these clips are
##                  "<category>:<clip>" so a clip over two bases stays apart. No grid / holster
##                  sampling for them.
##   pose_dump=path per sample of the DUMP_CATS categories: bone globals, limb segments, the posed
##                  endpoints of every candidate with "dump": true, the lowest body point (prone
##                  ground estimate) and, for clips matching dump_torso= (substring), a subsample of
##                  the posed outer surface with normals.
##   A candidate may list "cats": it is sampled only in those categories (and pairs only when
##   both are sampled).
##   A candidate may set "yield": <max deg> (revision 3): an item hanging from a hook or a strap swings
##   about its origin (the hook) away from a limb that would pass into it, by the smallest angle (5 deg
##   steps, 8 directions) that clears every limb, at most max deg, and never deeper into the body
##   surface than it already is. The yielded pose is the one measured, paired and dumped. For the categories in DETAIL_CATS the per-limb minimum per clip is kept
##   ("by_clip_limb"): the hand / forearm checks of the draws read it.

const LIB := "actor_b/"
const SURF_Y := Vector2(0.42, 1.58)
const GRID_Y := Vector2(0.50, 1.50)
const GRID_DY := 0.05
const GRID_DA := 15.0
const GRID_OFF := 0.03
const CELL := 0.05
const ATTACH_BONES := ["root", "pelvis", "spinea", "spineb", "spinec", "spined"]
## Clip categories of ordinary play (the rest are traversal: jump, land, vault, climb, ladder, ledge).
const LOCO_CATS := ["idle", "walk", "run", "sprint", "crouch", "aim", "throw", "carry", "reload"]
const HOLSTERS := ["holster_pistol", "holster_melee", "holster_long"]
const PROPS := ["r_hand_prop_attachment", "l_hand_prop_attachment"]
## Limb capsules: [from bone, to bone, radius-sample bone prefixes].
const LIMBS := {
	"r_upper_arm": ["r_shoulder", "r_elbow", ["r_shoulder"]],
	"r_forearm": ["r_elbow", "r_wrist", ["r_elbow", "r_forarm"]],
	"r_hand": ["r_wrist", "r_middlea", ["r_wrist", "r_palm", "r_index", "r_middle", "r_ring", "r_pinky", "r_thumb"]],
	"l_upper_arm": ["l_shoulder", "l_elbow", ["l_shoulder"]],
	"l_forearm": ["l_elbow", "l_wrist", ["l_elbow", "l_forarm"]],
	"l_hand": ["l_wrist", "l_middlea", ["l_wrist", "l_palm", "l_index", "l_middle", "l_ring", "l_pinky", "l_thumb"]],
	"r_thigh": ["r_upper_leg", "r_knee", ["r_upper_leg"]],
	"r_shin": ["r_knee", "r_ankle", ["r_knee"]],
	"l_thigh": ["l_upper_leg", "l_knee", ["l_upper_leg"]],
	"l_shin": ["l_knee", "l_ankle", ["l_knee"]],
	"head": ["neck", "headb", ["neck", "heada", "headb"]],
}
## Vertices dominated by these bone-name prefixes are limbs, not torso surface.
const LIMB_PREFIX := ["l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_forarm", "r_forarm", "l_wrist", "r_wrist",
		"l_palm", "r_palm", "l_index", "r_index", "l_middle", "r_middle", "l_ring", "r_ring", "l_pinky", "r_pinky",
		"l_thumb", "r_thumb", "heada", "headb", "neck", "wrinklemaps", "l_knee", "r_knee", "l_ankle", "r_ankle",
		"l_heel", "r_heel", "l_ball", "r_ball"]
## [clip, category, base clip ("" = full body), additive twin ("" = none)].
const CLIPS := [
	["actor_b-p-stealth-idle", "idle", "", ""],
	["actor_b-p-idle-gesture", "idle", "", ""],
	["actor_b-p-walk-fw", "walk", "", ""],
	["actor_b-p-walk-bw", "walk", "", ""],
	["actor_b-p-walk-fw-lt", "walk", "", ""],
	["actor_b-p-run-fw", "run", "", ""],
	["actor_b-p-run-bw-lt", "run", "", ""],
	["actor_b-p-run-fw-rt", "run", "", ""],
	["actor_b-p-sprint-fw", "sprint", "", ""],
	["actor_b-p-sprint-fw-lt", "sprint", "", ""],
	["actor_b-p-crouch-idle", "crouch", "", ""],
	["actor_b-p-crouch-walk-fw", "crouch", "", ""],
	["actor_b-p-crouch-walk-bw-lt", "crouch", "", ""],
	["actor_b-p-crouch-walk-fw-rt", "crouch", "", ""],
	["actor_b-p-rifle-idle-aim", "aim", "", ""],
	["actor_b-p-rifle-aim-walk-fw", "aim", "", ""],
	["actor_b-p-rifle-aim-crouch-idle", "aim", "", ""],
	["actor_b-p-rifle-aim-crouch-walk-fw", "aim", "", ""],
	["actor_b-p-pistol-aim-idle", "aim", "", ""],
	["actor_b-p-pistol-aim-walk-fw", "aim", "", ""],
	["actor_b-p-pistol-aim-crouch-walk-fw", "aim", "", ""],
	["actor_b-p-bow-aim-idle", "aim", "", ""],
	["actor_b-p-bow-aim-walk-fw", "aim", "", ""],
	["actor_b-p-bow-aim-crouch-idle", "aim", "", ""],
	["actor_b-p-1h-aim-throw-idle", "aim", "", ""],
	["actor_b-p-1h-aim-crouch-throw-idle", "aim", "", ""],
	["actor_b-p-1h-aim-throw-release-start", "throw", "", ""],
	["actor_b-p-1h-aim-throw-release-end", "throw", "", ""],
	["actor_b-p-rifle-run-arms", "carry", "actor_b-p-run-fw", ""],
	["actor_b-p-bow-move--arms", "carry", "actor_b-p-run-fw", ""],
	["actor_b-p-1h-arm--part", "carry", "actor_b-p-run-fw", ""],
	["actor_b-p-rifle-idle-aim-reload-mid--part", "reload", "actor_b-p-rifle-idle-aim", ""],
	["actor_b-p-rifle-idle-aim-reload-over--part", "reload", "actor_b-p-rifle-idle-aim", ""],
	["actor_b-p-pistol-rev-reload-mid--part", "reload", "actor_b-p-pistol-aim-idle", ""],
	["actor_b-p-bow-reload--part", "reload", "actor_b-p-stealth-idle", ""],
	["actor_b-p-idle^jump-1-5m", "jump", "", ""],
	["actor_b-p-jump-long", "jump", "", ""],
	["actor_b-p-jump-rfoot-1-5m", "jump", "", ""],
	["actor_b-p-jump-down-2m", "jump", "", ""],
	["actor_b-p-fall", "jump", "", ""],
	["actor_b-p-drop-down^fall", "jump", "", ""],
	["actor_b-p-land-hard^idle", "land", "", ""],
	["actor_b-p-land-hard^run", "land", "", ""],
	["actor_b-p-land-med^crouch-idle", "land", "", ""],
	["actor_b-p-idle^vault-over-1m", "vault", "", ""],
	["actor_b-p-idle^vault-over-2m", "vault", "", ""],
	["actor_b-p-crouch-run^vault-over-1m", "vault", "", ""],
	["actor_b-p-sprint-vault-1", "vault", "", ""],
	["actor_b-p-sprint-vault-2", "vault", "", ""],
	["actor_b-p-sprint-vault-3", "vault", "", ""],
	["actor_b-p-sprint-vault-4", "vault", "", ""],
	["actor_b-p-idle-jump-up-1m^ledge", "climb", "", ""],
	["actor_b-p-idle-jump-up-1-5m^ledge", "climb", "", ""],
	["actor_b-p-idle-jump-up-2m^ledge-chest-begin", "climb", "", ""],
	["actor_b-p-idle-jump-up-2m^ledge-chest-mid", "climb", "", ""],
	["actor_b-p-idle-jump-up-2m^ledge-chest-end", "climb", "", ""],
	["actor_b-p-idle-jump-up-3m^ledge-hang-begin", "climb", "", ""],
	["actor_b-p-idle-jump-up-3m^ledge-hang-mid", "climb", "", ""],
	["actor_b-p-idle-jump-up-3m^ledge-hang-end", "climb", "", ""],
	["actor_b-p-ledge-hang-climb-up^ledge-knee", "climb", "", ""],
	["actor_b-p-fall-ledge-grab", "climb", "", ""],
	["actor_b-p-ledge-grab-knee^idle", "climb", "", ""],
	["actor_b-p-ledge-knee-climb-up^idle", "climb", "", ""],
	["actor_b-p-ledge-chest-climb-up^idle", "climb", "", ""],
	["actor_b-climb-on-1-5m-up^run-enter", "climb", "", ""],
	["actor_b-climb-on-1-5m-up^idle-exit", "climb", "", ""],
	["actor_b-p-ladder-climb-up", "ladder", "", ""],
	["actor_b-p-ladder-climb-up-fast--a", "ladder", "", ""],
	["actor_b-p-ladder-idle", "ladder", "", ""],
	["actor_b-p-ladder-mount-top", "ladder", "", ""],
	["actor_b-p-ladder-dismount--top-end", "ladder", "", ""],
	["actor_b-p-ledge-idle", "ledge", "", ""],
	["actor_b-p-ledge-idle^walk-r", "ledge", "", ""],
	["actor_b-p-ledge-idle-r-enter", "ledge", "", ""],
]
## Extra clip sets (extra=1): [key suffix, clip ("lib/clip" or an actor_b clip), category, base,
## additive twin, t0, t1 (-1 = clip end), rate Hz, max samples].
const STAND := "actor_b-p-stealth-idle"
const CROUCH := "actor_b-p-crouch-idle"
const EXTRA_CLIPS := [
	# draw sets (loadout design section 5): grab, draw (the holster is the draw reversed: same poses)
	["grab_no_pack", "actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "draw", STAND, "actor_b-p-stealth-idle^p-grab--add--no-pack", 0.0, -1.0, 20.0, 30],
	["draw_no_pack", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "draw", STAND, "actor_b-p-stealth-draw-p^idle--add--no-pack", 0.0, -1.0, 20.0, 30],
	["grab_default", "actor_b-p-crouch-idle^p-grab--arm-r", "draw", STAND, "actor_b-p-crouch-idle^p-grab--add", 0.0, -1.0, 20.0, 30],
	["draw_default", "actor_b-p-stealth-draw-p^idle--arm-r", "draw", STAND, "actor_b-p-crouch-draw-p^idle--add", 0.0, -1.0, 20.0, 30],
	["flashlight", "actor_b-fist-ambi-flashlight-draw--part", "draw", STAND, "actor_b-fist-ambi-flashlight-draw--add", 0.0, -1.0, 20.0, 30],
	["molotov_grab", "actor_b-p-molotov-idle^draw--part", "draw", STAND, "actor_b-p-molotov-idle^draw--add", 0.0, -1.0, 20.0, 30],
	["molotov_draw", "actor_b-p-molotov-draw^idle--part", "draw", STAND, "actor_b-p-molotov-draw^idle--add", 0.0, -1.0, 20.0, 30],
	["lg_grab", "actor_b-lg-stealth-idle^grab--arm-r", "draw", STAND, "actor_b-lg-stealth-idle^grab--add", 0.0, -1.0, 20.0, 30],
	["lg_draw", "actor_b-lg-stealth-draw^idle--arm-r", "draw", STAND, "actor_b-lg-stealth-draw^idle--add", 0.0, -1.0, 20.0, 30],
	["lg_stow", "actor_b-lg-stealth-stow^idle--arm-r", "draw", STAND, "actor_b-lg-stealth-stow^idle--add", 0.0, -1.0, 20.0, 30],
	["bow_grab", "actor_b-p-bow-draw-idle^grab--part", "draw", STAND, "actor_b-p-bow-draw-idle^grab--add", 0.0, -1.0, 20.0, 30],
	["bow_draw", "actor_b-p-bow-draw-grab^idle--part", "draw", STAND, "actor_b-p-bow-draw-grab^idle--add", 0.0, -1.0, 20.0, 30],
	["reach_arrow", "actor_b-p-bow-reload--part", "draw", STAND, "", 0.0, -1.0, 20.0, 30],
	["switch_hands", "actor_b-p-switch-hands-knife", "draw", STAND, "", 0.0, -1.0, 20.0, 30],
	["grab_no_pack", "actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "draw_c", CROUCH, "actor_b-p-stealth-idle^p-grab--add--no-pack", 0.0, -1.0, 20.0, 30],
	["draw_no_pack", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "draw_c", CROUCH, "actor_b-p-stealth-draw-p^idle--add--no-pack", 0.0, -1.0, 20.0, 30],
	["stow_no_pack", "actor_b-p-stealth-stow-p^idle--arm-r--no-pack", "draw_c", CROUCH, "actor_b-p-stealth-stow-p^idle--add--no-pack", 0.0, -1.0, 20.0, 30],
	["grab_default", "actor_b-p-crouch-idle^p-grab--arm-r", "draw_c", CROUCH, "actor_b-p-crouch-idle^p-grab--add", 0.0, -1.0, 20.0, 30],
	["draw_default", "actor_b-p-stealth-draw-p^idle--arm-r", "draw_c", CROUCH, "actor_b-p-crouch-draw-p^idle--add", 0.0, -1.0, 20.0, 30],
	["flashlight", "actor_b-fist-ambi-flashlight-draw--part", "draw_c", CROUCH, "actor_b-fist-ambi-flashlight-draw--add", 0.0, -1.0, 20.0, 30],
	["molotov_grab", "actor_b-p-molotov-idle^draw--part", "draw_c", CROUCH, "actor_b-p-molotov-idle^draw--add", 0.0, -1.0, 20.0, 30],
	["molotov_draw", "actor_b-p-molotov-draw^idle--part", "draw_c", CROUCH, "actor_b-p-molotov-draw^idle--add", 0.0, -1.0, 20.0, 30],
	["lg_grab", "actor_b-lg-stealth-idle^grab--arm-r", "draw_c", CROUCH, "actor_b-lg-stealth-idle^grab--add", 0.0, -1.0, 20.0, 30],
	["lg_draw", "actor_b-lg-stealth-draw^idle--arm-r", "draw_c", CROUCH, "actor_b-lg-stealth-draw^idle--add", 0.0, -1.0, 20.0, 30],
	["bow_grab", "actor_b-p-bow-draw-idle^grab--part", "draw_c", CROUCH, "actor_b-p-bow-draw-idle^grab--add", 0.0, -1.0, 20.0, 30],
	["bow_draw", "actor_b-p-bow-draw-grab^idle--part", "draw_c", CROUCH, "actor_b-p-bow-draw-grab^idle--add", 0.0, -1.0, 20.0, 30],
	["reach_arrow", "actor_b-p-crouch-bow-reload--part", "draw_c", CROUCH, "", 0.0, -1.0, 20.0, 30],
	["switch_hands", "actor_b-p-switch-hands-knife-crouch", "draw_c", CROUCH, "", 0.0, -1.0, 20.0, 30],
	# riding (Actor_B's own rider clips: the skeleton origin is the saddle attach point) and the
	# retargeted Actor_A mount (horse design section 1.7)
	["idle", "actor_b-horse-idle", "ride", "", "", 0.0, -1.0, 1.0, 8],
	["walk", "actor_b-horse-walk-fw", "ride", "", "", 0.0, -1.0, 4.0, 8],
	["trot", "actor_b-horse-trot-fw", "ride", "", "", 0.0, -1.0, 10.0, 8],
	["canter", "actor_b-horse-canter-fw", "ride", "", "", 0.0, -1.0, 10.0, 8],
	["gallop", "actor_b-horse-gallop-fw", "ride", "", "", 0.0, -1.0, 12.0, 8],
	["sprint", "actor_b-horse-gallop-sprint", "ride", "", "", 0.0, -1.0, 3.0, 10],
	["jump", "actor_b-horse-gallop^jump-over", "ride", "", "", 0.0, -1.0, 6.0, 10],
	["duck", "actor_b-horse-duck-under", "ride", "", "", 0.0, -1.0, 6.0, 8],
	["dismount", "actor_b-horse-dismount-left", "mount", "", "", 0.0, -1.0, 4.0, 12],
	["mount", "actor_b_from_a/actor_a-horse-mount-left", "mount", "", "", 0.0, -1.0, 4.0, 14],
	# prone proxies: crawl (retargeted Actor_A downed set), get-down, and the face-down segment of an
	# Actor_B cinematic (melee_prone.md section 5.1: 11.8-14.6 s)
	["crawl", "actor_b_from_a/downed-crawl-fw", "prone", "", "", 0.0, -1.0, 6.0, 8],
	["crawl_start", "actor_b_from_a/downed-idle^crawl-fw", "prone", "", "", 0.0, -1.0, 6.0, 8],
	["get_down", "actor_b_from_a/co-op-stunned-enter", "prone", "", "", 0.0, -1.0, 6.0, 10],
	["flat", "igc-stream-sub4-sniper-holygrail-w2-react--actor_b", "prone", "", "", 11.8, 14.6, 2.0, 7],
]
## Categories with per-limb minima per clip, and the categories of the pose dump.
const DETAIL_CATS := ["draw", "draw_c", "ride", "mount", "prone"]
const DUMP_CATS := ["idle", "crouch", "aim", "draw", "draw_c", "ride", "mount", "prone", "climb", "ladder", "ledge"]
const DUMP_BONES := ["root", "pelvis", "spinea", "spineb", "spinec", "spined", "neck", "headb", "r_hand_prop_attachment",
		"l_hand_prop_attachment", "r_wrist", "l_wrist", "r_upper_leg", "l_upper_leg", "r_knee", "l_knee", "r_ankle", "l_ankle"]

## Draw / stow / grab clips: [clip, base, additive twin, weapon, kind].
const DRAWS := [
	["actor_b-p-stealth-draw-p^idle--arm-r", "actor_b-p-stealth-idle", "actor_b-p-crouch-draw-p^idle--add", "pistol", "draw"],
	["actor_b-p-stealth-stow-p^idle--arm-r", "actor_b-p-stealth-idle", "actor_b-p-crouch-stow-p^idle--add", "pistol", "stow_finish"],
	["actor_b-p-crouch-idle^p-grab--arm-r", "actor_b-p-stealth-idle", "actor_b-p-crouch-idle^p-grab--add", "pistol", "grab"],
	["actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "actor_b-p-stealth-idle", "actor_b-p-stealth-draw-p^idle--add--no-pack", "pistol", "draw_no_pack"],
	["actor_b-p-stealth-stow-p^idle--arm-r--no-pack", "actor_b-p-stealth-idle", "actor_b-p-stealth-stow-p^idle--add--no-pack", "pistol", "stow_finish_no_pack"],
	["actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "actor_b-p-stealth-idle", "actor_b-p-stealth-idle^p-grab--add--no-pack", "pistol", "grab_no_pack"],
	["actor_b-p-stealth-draw-p^idle--arm-r", "actor_b-p-crouch-idle", "actor_b-p-crouch-draw-p^idle--add", "pistol", "draw_crouch"],
	["actor_b-p-crouch-idle^p-grab--arm-r", "actor_b-p-crouch-idle", "actor_b-p-crouch-idle^p-grab--add", "pistol", "grab_crouch"],
	["actor_b-pistol-pack-holster--part", "actor_b-p-stealth-idle", "actor_b-pistol-pack-holster--add", "pistol", "pack_holster"],
	["actor_b-pistol-pack-unholster--part", "actor_b-p-stealth-idle", "actor_b-pistol-pack-unholster--add", "pistol", "pack_unholster"],
	["actor_b-lg-stealth-draw^idle--arm-r", "actor_b-p-stealth-idle", "actor_b-lg-stealth-draw^idle--add", "musket", "draw"],
	["actor_b-lg-stealth-stow^idle--arm-r", "actor_b-p-stealth-idle", "actor_b-lg-stealth-stow^idle--add", "musket", "stow_finish"],
	["actor_b-lg-stealth-idle^grab--arm-r", "actor_b-p-stealth-idle", "actor_b-lg-stealth-idle^grab--add", "musket", "grab"],
	["actor_b-lg-stealth-draw^idle--arm-r", "actor_b-p-crouch-idle", "actor_b-lg-stealth-draw^idle--add", "musket", "draw_crouch"],
	["actor_b-p-bow-draw-grab^idle--part", "actor_b-p-stealth-idle", "actor_b-p-bow-draw-grab^idle--add", "bow", "draw"],
	["actor_b-p-bow-stow-grab^idle--part", "actor_b-p-stealth-idle", "actor_b-p-bow-stow-grab^idle--add", "bow", "stow_finish"],
	["actor_b-p-bow-draw-idle^grab--part", "actor_b-p-stealth-idle", "actor_b-p-bow-draw-idle^grab--add", "bow", "grab"],
	["actor_b-p-bow-reload--part", "actor_b-p-stealth-idle", "", "arrows", "reach_arrow"],
	["actor_b-p-crouch-bow-reload--part", "actor_b-p-crouch-idle", "", "arrows", "reach_arrow_crouch"],
	["actor_b-p-molotov-draw^idle--part", "actor_b-p-stealth-idle", "actor_b-p-molotov-draw^idle--add", "throwable", "draw"],
	["actor_b-p-molotov-idle^draw--part", "actor_b-p-stealth-idle", "actor_b-p-molotov-idle^draw--add", "throwable", "put_away"],
	["actor_b-p-switch-hands-knife", "actor_b-p-stealth-idle", "", "knife", "switch_hands"],
]

var args := {}
var sk: Skeleton3D
var ap: AnimationPlayer
var body: CharacterBodyMesh
var bind_g: Array = []          ## null-add globals (skeleton space) per bone
var track_cache := {}           ## Animation -> Array of [track, bone, type]
## Surface subset (outer torso / hips / thighs: Clothes + Gear, outward normals only).
var sv := PackedVector3Array()  ## bind positions
var sn := PackedVector3Array()  ## bind normals
var sbo := PackedInt32Array()   ## 4 skin bind indices per vertex
var sw := PackedFloat32Array()  ## 4 weights per vertex
var slab := PackedStringArray() ## material label per vertex
var sskin: Array = []           ## Skin per vertex group (index into skins)
var sskin_i := PackedInt32Array()
var skins: Array = []
## posed surface of the current sample
var pv := PackedVector3Array()
var pn := PackedVector3Array()
var grid_hash := {}
var limb_r := {}
var bone_i := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var t0 := Time.get_ticks_msec()
	var ok: bool = await _run()
	print("MEASURE %s in %.1f s" % ["DONE" if ok else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if ok else 1)


func _run() -> bool:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.active = false
	body = CharacterBodyMesh.attach(sk, ap)
	if body == null:
		push_error("no body")
		return false
	# the skeleton only updates its global poses inside the tree (not during _initialize)
	await process_frame
	await process_frame
	for b in sk.get_bone_count():
		bone_i[sk.get_bone_name(b)] = b
	var nulladd := ap.get_animation(LIB + "null-add")
	bind_g = CharacterBodyMesh.bind_pose_globals(sk, nulladd)
	var out := {"meta": {"tool": "tools/loadout/measure_body_fit.gd", "space": "rig/skeleton space: +Y up, faces +Z, character right = -X",
			"angles": "0 front, 90 character right, 180 back, 270 left", "body": CharacterBodyMesh.DEFAULT_PATH,
			"bind": "null-add", "grid_offset_m": GRID_OFF, "provenance": "Rig, clips and bind pose: Actor_B. Body geometry: tools/character/build_body.py."}}
	_collect_surface()
	out["bind"] = _bind_section()
	out["items"] = _items_section()
	# sanity: manual poses reach the skinning globals (crouch lowers the pelvis)
	_pose("actor_b-p-crouch-idle", 0.0, "", "")
	var gc := body.skinning_globals()
	print("sanity: pelvis y bind %.3f, crouch %.3f" % [(bind_g[bone_i["pelvis"]] as Transform3D).origin.y, (gc[bone_i["pelvis"]] as Transform3D).origin.y])
	if args.has("debug_points"):
		sk.reset_bone_poses()
		var gd := body.skinning_globals()
		_skin_surface(gd)
		for ps: String in String(args.debug_points).split(";"):
			var q := ps.split(",")
			var pt := Vector3(float(q[0]), float(q[1]), float(q[2]))
			var r := _sdist(pt)
			print("DEBUG point ", pt, " sdist ", r)
			var best: Array = []
			for i in sv.size():
				best.append([pv[i].distance_to(pt), i])
			best.sort_custom(func(a, b) -> bool: return a[0] < b[0])
			for k in 6:
				var i: int = best[k][1]
				print("   v ", pv[i], " n ", pn[i], " lab ", slab[i], " d ", snappedf(best[k][0], 0.0001), " plane ", snappedf((pt - pv[i]).dot(pn[i]), 0.0001))
		return true
	var samples := int(args.get("samples", "6"))
	var grid := _make_grid()
	var cands := _load_candidates()
	var hol := {}
	var clip_meta := {}
	for spec: Array in CLIPS:
		var clip: String = spec[0]
		if args.has("only") and not clip.contains(String(args.only)):
			continue
		if not ap.has_animation(LIB + clip):
			clip_meta[clip] = {"missing": true}
			continue
		var anim := ap.get_animation(LIB + clip)
		var L := anim.length
		var n := 1 if L < 0.05 else mini(samples, maxi(2, int(round(L / 0.1)) + 1))
		clip_meta[clip] = {"category": spec[1], "length": snappedf(L, 0.001), "samples": n, "base": spec[2],
				"keys_holsters": _keyed(anim, HOLSTERS)}
		for j in n:
			var t := L * j / maxf(1.0, float(n - 1)) if n > 1 else 0.0
			_pose(clip, t, spec[2], spec[3])
			var g := body.skinning_globals()
			_skin_surface(g)
			_holster_sample(hol, clip, spec[1], t, g)
			_grid_sample(grid, clip, spec[1], g)
			_cand_sample(cands, clip, spec[1], t, g)
			_dump_sample(clip, clip, spec[1], t, g, cands)
	if String(args.get("extra", "0")) == "1":
		_sample_extra(clip_meta, cands)
	out["clips"] = clip_meta
	out["holsters"] = hol
	out["grid"] = _grid_out(grid)
	out["candidates"] = _cand_out(cands)
	out["draws"] = _draws_section()
	if args.has("pose_dump"):
		var lr := {}
		for ln in limb_r:
			lr[ln] = snappedf(float(limb_r[ln]), 0.0001)
		var bb := {}
		for bn: String in DUMP_BONES:
			bb[bn] = _m12(bind_g[bone_i[bn]])
		var df := FileAccess.open(String(args.pose_dump), FileAccess.WRITE)
		if df == null:
			push_error("cannot write " + String(args.pose_dump))
			return false
		df.store_string(JSON.stringify({"meta": {"tool": "tools/loadout/measure_body_fit.gd pose_dump", "space": "rig/skeleton space",
				"bones": "12 floats: basis columns x, y, z then origin", "limbs": "segment endpoints a, b (6 floats)",
				"cands": "posed capsule endpoints a, b of the candidates flagged dump", "ground": "lowest posed outer-surface vertex y and lowest joint y",
				"torso": "posed outer-surface subsample: x, y, z, nx, ny, nz"},
				"limb_r": lr, "bind_bones": bb, "samples": _dump}))
		df.close()
		print("wrote pose dump ", args.pose_dump, " (", _dump.size(), " samples)")
	var path: String = args.get("out", "user://raw_fit.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return false
	f.store_string(JSON.stringify(out, " ", false))
	f.close()
	print("wrote ", path)
	return true


# --- posing ---------------------------------------------------------------------

func _tracks(anim: Animation) -> Array:
	if not track_cache.has(anim):
		var tr: Array = []
		for t in anim.get_track_count():
			if not anim.track_is_enabled(t):
				continue
			var bn := str(anim.track_get_path(t).get_concatenated_subnames())
			if not bone_i.has(bn):
				continue
			tr.append([t, int(bone_i[bn]), anim.track_get_type(t)])
		track_cache[anim] = tr
	return track_cache[anim]


func _keyed(anim: Animation, bones: Array) -> Array:
	var res: Array = []
	for e: Array in _tracks(anim):
		var bn := sk.get_bone_name(e[1])
		if bn in bones and not bn in res:
			res.append(bn)
	return res


func _apply(anim: Animation, t: float, additive: bool) -> void:
	for e: Array in _tracks(anim):
		var tr: int = e[0]
		var b: int = e[1]
		match int(e[2]):
			Animation.TYPE_POSITION_3D:
				var p := anim.position_track_interpolate(tr, t)
				if additive:
					sk.set_bone_pose_position(b, sk.get_bone_pose_position(b) + (p - sk.get_bone_rest(b).origin))
				else:
					sk.set_bone_pose_position(b, p)
			Animation.TYPE_ROTATION_3D:
				var q := anim.rotation_track_interpolate(tr, t).normalized()
				if additive:
					var rq := sk.get_bone_rest(b).basis.get_rotation_quaternion()
					sk.set_bone_pose_rotation(b, (sk.get_bone_pose_rotation(b) * (rq.inverse() * q)).normalized())
				else:
					sk.set_bone_pose_rotation(b, q)
			Animation.TYPE_SCALE_3D:
				if not additive:
					sk.set_bone_pose_scale(b, anim.scale_track_interpolate(tr, t))


## Rest (= null-add), then the base clip at t = 0 (partials) or the clip itself at t.
func _pose(clip: String, t: float, base: String, add: String) -> void:
	sk.reset_bone_poses()
	if base.is_empty():
		_apply(ap.get_animation(_an(clip)), t, false)
	else:
		_apply(ap.get_animation(_an(base)), 0.0, false)
		_apply(ap.get_animation(_an(clip)), t, false)
		if not add.is_empty() and ap.has_animation(_an(add)):
			var an := ap.get_animation(_an(add))
			_apply(an, minf(t, an.length), true)


## Full animation name: "lib/clip" as given, otherwise a clip of the actor_b library.
static func _an(clip: String) -> String:
	return clip if "/" in clip else LIB + clip


## The EXTRA_CLIPS sets (extra=1): draw sets at 20 Hz, riding, mount, prone proxies.
func _sample_extra(clip_meta: Dictionary, cands: Array) -> void:
	var lib_path := "res://animations_extra/Actor_B_from_A.res"
	if not ap.has_animation_library("actor_b_from_a") and ResourceLoader.exists(lib_path):
		ap.add_animation_library("actor_b_from_a", load(lib_path))
	for spec: Array in EXTRA_CLIPS:
		var clip: String = spec[1]
		var cat: String = spec[2]
		var key := "%s:%s" % [cat, clip]
		if clip_meta.has(key):
			continue
		if not ap.has_animation(_an(clip)):
			clip_meta[key] = {"category": cat, "missing": true, "clip": clip}
			continue
		var anim := ap.get_animation(_an(clip))
		var t0: float = spec[5]
		var t1: float = anim.length if float(spec[6]) < 0.0 else minf(float(spec[6]), anim.length)
		var span := maxf(t1 - t0, 0.0)
		var n := clampi(int(round(span * float(spec[7]))) + 1, 2, int(spec[8]))
		clip_meta[key] = {"category": cat, "clip": clip, "length": snappedf(anim.length, 0.001), "window": [snappedf(t0, 0.01), snappedf(t1, 0.01)],
				"samples": n, "base": spec[3], "add": spec[4], "set": spec[0]}
		for j in n:
			var t := t0 + span * j / float(n - 1)
			_pose(clip, t, spec[3], spec[4])
			var g := body.skinning_globals()
			_skin_surface(g)
			_mats_cache = _skin_mats(g)
			_cand_sample(cands, key, cat, t, g)
			_dump_sample(key, clip, cat, t, g, cands)


var _dump: Array = []


## One pose-dump record (pose_dump=): bone globals, limb segments, flagged candidates, ground.
func _dump_sample(key: String, clip: String, cat: String, t: float, g: Array, cands: Array) -> void:
	if not args.has("pose_dump") or not cat in DUMP_CATS:
		return
	var bones := {}
	for bn: String in DUMP_BONES:
		bones[bn] = _m12(g[bone_i[bn]])
	var segs := _limb_segs(g)
	var limbs := {}
	for ln: String in segs:
		limbs[ln] = _v(segs[ln][0]) + _v(segs[ln][1])
	var cs := {}
	var yposed := _yield_pass(cands, cat, g, segs)
	for c: Dictionary in cands:
		if not c.get("dump", false):
			continue
		if c.has("cats") and not cat in c.cats:
			continue
		var ab: Array = yposed[c.id] if yposed.has(c.id) else _cand_pose(c, g)
		cs[c.id] = _v(ab[0]) + _v(ab[1])
	var low := INF
	for i in pv.size():
		low = minf(low, pv[i].y)
	var jlow := INF
	for bn in ["r_ankle", "l_ankle", "r_knee", "l_knee", "r_wrist", "l_wrist", "headb", "pelvis"]:
		jlow = minf(jlow, (g[bone_i[bn]] as Transform3D).origin.y)
	var rec := {"key": key, "clip": clip, "cat": cat, "t": snappedf(t, 0.001), "bones": bones, "limbs": limbs, "cands": cs,
			"ground": [snappedf(low, 0.001), snappedf(jlow, 0.001)]}
	var want_torso := false
	for tm: String in String(args.get("dump_torso", "")).split(",", false):
		want_torso = want_torso or clip.contains(tm)
	if want_torso and cat.begins_with("draw"):
		var tor: Array = []
		var step := int(args.get("dump_torso_step", "12"))
		for i in range(0, pv.size(), step):
			tor.append(_v(pv[i]) + _v(pn[i]))
		rec["torso"] = tor
	_dump.append(rec)


static func _m12(t: Transform3D) -> Array:
	var b := t.basis
	return [snappedf(b.x.x, 0.0001), snappedf(b.x.y, 0.0001), snappedf(b.x.z, 0.0001), snappedf(b.y.x, 0.0001), snappedf(b.y.y, 0.0001),
			snappedf(b.y.z, 0.0001), snappedf(b.z.x, 0.0001), snappedf(b.z.y, 0.0001), snappedf(b.z.z, 0.0001), snappedf(t.origin.x, 0.0001),
			snappedf(t.origin.y, 0.0001), snappedf(t.origin.z, 0.0001)]


# --- surface ----------------------------------------------------------------------

func _is_limb_bone(bn: String) -> bool:
	for p: String in LIMB_PREFIX:
		if bn.begins_with(p):
			return true
	return false


func _mat_label(mi: MeshInstance3D, s: int) -> String:
	var mat := mi.mesh.surface_get_material(s)
	if mat and not mat.resource_name.is_empty():
		return mat.resource_name
	return "%s_%d" % [mi.name, s]


## Clothes + Gear vertices of the torso, hips and thighs whose normal points away from the
## torso axis (outer surfaces; the skirt lining and hidden inner faces are dropped).
func _collect_surface() -> void:
	for mi in body.meshes:
		if not String(mi.name) in ["Clothes", "Gear"]:
			continue
		var am := mi.mesh as ArrayMesh
		var skin_idx := skins.find(mi.skin)
		if skin_idx < 0:
			skins.append(mi.skin)
			skin_idx = skins.size() - 1
		for s in am.get_surface_count():
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			var label := _mat_label(mi, s)
			var skin: Skin = mi.skin
			for i in v.size():
				var p := v[i]
				if p.y < SURF_Y.x or p.y > SURF_Y.y:
					continue
				var best := 0
				for k in nb:
					if w[i * nb + k] > w[i * nb + best]:
						best = k
				var dom := sk.get_bone_name(skin.get_bind_bone(bo[i * nb + best]))
				if _is_limb_bone(dom):
					continue
				var c := _axis_at(p.y)
				var rad := Vector3(p.x - c.x, 0.0, p.z - c.z)
				if rad.length() > 0.01 and nr[i].dot(rad.normalized()) < -0.2:
					continue
				# thin bands (belt, straps): only their outer faces; their edge vertices carry
				# sideways normals (split for sharp edges) that spoil the plane distance
				if label in ["belt", "strap"] and rad.length() > 0.01 and absf(nr[i].dot(rad.normalized())) < 0.5:
					continue
				sv.append(p)
				sn.append(nr[i])
				slab.append(label)
				sskin_i.append(skin_idx)
				var ws := 0.0
				for k in 4:
					if k < nb:
						sbo.append(bo[i * nb + k])
						sw.append(w[i * nb + k])
						ws += w[i * nb + k]
					else:
						sbo.append(0)
						sw.append(0.0)
				if ws > 0.0 and absf(ws - 1.0) > 1e-3:
					for k in 4:
						sw[sw.size() - 4 + k] /= ws
	pv.resize(sv.size())
	pn.resize(sv.size())
	print("surface vertices: ", sv.size())


## Torso axis (x, z) at height y, from the bind joints: pelvis, spinea..spined, neck.
func _axis_at(y: float) -> Vector3:
	var chain := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck"]
	var pts: Array = []
	for bn: String in chain:
		pts.append((bind_g[bone_i[bn]] as Transform3D).origin)
	if y <= pts[0].y:
		return pts[0]
	for i in range(1, pts.size()):
		if y <= pts[i].y:
			var a: Vector3 = pts[i - 1]
			var b: Vector3 = pts[i]
			return a.lerp(b, (y - a.y) / maxf(b.y - a.y, 1e-6))
	return pts[pts.size() - 1]


func _skin_mats(g: Array) -> Array:
	var res: Array = []
	for skin: Skin in skins:
		var m: Array[Transform3D] = []
		for b in skin.get_bind_count():
			m.append((g[skin.get_bind_bone(b)] as Transform3D) * skin.get_bind_pose(b))
		res.append(m)
	return res


func _skin_surface(g: Array) -> void:
	var mats := _skin_mats(g)
	grid_hash.clear()
	for i in sv.size():
		var m: Array = mats[sskin_i[i]]
		var acc := Vector3.ZERO
		var an := Vector3.ZERO
		for k in 4:
			var wk := sw[4 * i + k]
			if wk > 0.0:
				var mk: Transform3D = m[sbo[4 * i + k]]
				acc += (mk * sv[i]) * wk
				an += (mk.basis * sn[i]) * wk
		pv[i] = acc
		pn[i] = an.normalized()
		var key := Vector3i(floori(acc.x / CELL), floori(acc.y / CELL), floori(acc.z / CELL))
		if grid_hash.has(key):
			(grid_hash[key] as Array).append(i)
		else:
			grid_hash[key] = [i]


## [signed distance to the outer surface, label of the nearest vertex, euclidean distance].
## The signed distance is the median of the plane distances (p - v) . n of the 5 nearest outer
## vertices: one or two edge vertices of thin parts (straps, belt edges) with tangential
## normals do not flip it. `skip` lists material labels to ignore (e.g. the old horn).
func _sdist(p: Vector3, skip: Array = []) -> Array:
	var c := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
	for ring in [1, 2, 3, 5]:
		var near_i: Array = []
		var near_d: Array = []
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				for dz in range(-ring, ring + 1):
					var key := c + Vector3i(dx, dy, dz)
					if not grid_hash.has(key):
						continue
					for i: int in grid_hash[key]:
						if not skip.is_empty() and slab[i] in skip:
							continue
						var d := p.distance_squared_to(pv[i])
						if near_d.size() < 5 or d < float(near_d[near_d.size() - 1]):
							var at := near_d.bsearch(d)
							near_d.insert(at, d)
							near_i.insert(at, i)
							if near_d.size() > 5:
								near_d.pop_back()
								near_i.pop_back()
		if not near_i.is_empty() and sqrt(float(near_d[0])) <= ring * CELL:
			var pd: Array = []
			for i: int in near_i:
				pd.append((p - pv[i]).dot(pn[i]))
			pd.sort()
			return [float(pd[pd.size() / 2]), slab[near_i[0]], sqrt(float(near_d[0]))]
	return [9.99, "", 9.99]


# --- bind section -------------------------------------------------------------------

func _bind_section() -> Dictionary:
	var res := {}
	var joints := {}
	for bn in ["root", "pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb", "l_clavicle", "r_clavicle",
			"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist", "l_upper_leg", "r_upper_leg", "l_knee", "r_knee",
			"l_ankle", "r_ankle", "r_hand_prop_attachment", "l_hand_prop_attachment"] + HOLSTERS:
		if bone_i.has(bn):
			joints[bn] = _xf((bind_g[bone_i[bn]] as Transform3D))
	res["joints"] = joints
	res["holster_parents"] = {}
	for h: String in HOLSTERS:
		res["holster_parents"][h] = sk.get_bone_name(sk.get_bone_parent(bone_i[h]))
	# gear parts: AABB and centroid per material label (all Gear vertices, bind)
	var parts := {}
	for mi in body.meshes:
		if String(mi.name) != "Gear":
			continue
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var v: PackedVector3Array = am.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var label := _mat_label(mi, s)
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			var cen := Vector3.ZERO
			for p in v:
				lo = lo.min(p)
				hi = hi.max(p)
				cen += p
			var e := {"verts": v.size(), "min": _v(lo), "max": _v(hi), "centroid": _v(cen / maxf(v.size(), 1))}
			# per side (left x > 0 / right x < 0) for the paired straps and fittings
			var sides := {}
			for side in [1.0, -1.0]:
				var lo2 := Vector3(INF, INF, INF)
				var hi2 := -lo2
				var n := 0
				for p in v:
					if p.x * side > 0.0:
						lo2 = lo2.min(p)
						hi2 = hi2.max(p)
						n += 1
				if n > 0:
					sides["left" if side > 0.0 else "right"] = {"verts": n, "min": _v(lo2), "max": _v(hi2)}
			e["sides"] = sides
			parts[label] = e
	res["gear_parts"] = parts
	# belt band ring: centre of the belt vertices per 15 deg
	res["belt_ring"] = _ring_of("belt", 15.0)
	# outer radius map (legacy outfit) and skin radius map (customizer body.glb)
	res["outer_map"] = _radius_map(sv, slab, true)
	res["outer_fine_nogear"] = _fine_map(["horn", "wood", "horn_tip", "pouch"])
	res["skin_map"] = _skin_map()
	# limb capsule radii (90th percentile distance of their dominated vertices from the segment)
	res["limb_radius"] = _limb_radii()
	return res


func _ring_of(label: String, step: float) -> Array:
	var bins := {}
	for i in sv.size():
		if slab[i] != label:
			continue
		var p := sv[i]
		var c := _axis_at(p.y)
		var a := _ang(p - c)
		var k := int(round(a / step)) % int(360.0 / step)
		if not bins.has(k):
			bins[k] = [Vector3.ZERO, 0, 0.0, INF, -INF]
		bins[k][0] += p
		bins[k][1] += 1
		bins[k][2] = maxf(bins[k][2], Vector2(p.x - c.x, p.z - c.z).length())
		bins[k][3] = minf(bins[k][3], p.y)
		bins[k][4] = maxf(bins[k][4], p.y)
	var res: Array = []
	var keys := bins.keys()
	keys.sort()
	for k in keys:
		var b: Array = bins[k]
		res.append({"angle": k * step, "centre": _v(b[0] / float(b[1])), "outer_radius": snappedf(b[2], 0.0001),
				"y_min": snappedf(b[3], 0.0001), "y_max": snappedf(b[4], 0.0001), "verts": b[1]})
	return res


## Angle around the torso axis of a horizontal offset: 0 front (+Z), 90 right (-X).
static func _ang(d: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(-d.x, d.z)), 360.0)


static func _dir(angle_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(-sin(a), 0.0, cos(a))


## {y: {angle: [max radius, label of the outermost vertex]}} for heights GRID_Y step GRID_DY.
func _radius_map(verts: PackedVector3Array, labels: PackedStringArray, with_label: bool) -> Dictionary:
	var res := {}
	var y := GRID_Y.x
	while y <= GRID_Y.y + 1e-6:
		var row := {}
		var c := _axis_at(y)
		for i in verts.size():
			var p := verts[i]
			if absf(p.y - y) > GRID_DY * 0.5:
				continue
			var d := Vector3(p.x - c.x, 0.0, p.z - c.z)
			var k := int(round(_ang(d) / GRID_DA)) % int(360.0 / GRID_DA)
			var r := d.length()
			if not row.has(k) or r > float(row[k][0]):
				row[k] = [r, labels[i] if with_label else ""]
		var o := {}
		for k in row:
			o[str(int(k * GRID_DA))] = [snappedf(float(row[k][0]), 0.0001), row[k][1]] if with_label else snappedf(float(row[k][0]), 0.0001)
		res["%.2f" % y] = o
		y += GRID_DY
	return res


## Fine outer-radius map without the listed gear objects (the old horn and pouch), for
## placing candidates: {"y": {"angle": radius}} every 2.5 cm and 5 deg, y 0.45..1.55.
func _fine_map(skip: Array) -> Dictionary:
	var rows := {}
	for i in sv.size():
		if slab[i] in skip:
			continue
		var p := sv[i]
		var r := int(round((p.y - 0.45) / 0.025))
		if r < 0 or r > 44:
			continue
		var c := _axis_at(0.45 + r * 0.025)
		var d := Vector3(p.x - c.x, 0.0, p.z - c.z)
		var k := int(round(_ang(d) / 5.0)) % 72
		var key := "%.3f" % (0.45 + r * 0.025)
		if not rows.has(key):
			rows[key] = {}
		var row: Dictionary = rows[key]
		if not row.has(str(k * 5)) or d.length() > float(row[str(k * 5)]):
			row[str(k * 5)] = snappedf(d.length(), 0.0001)
	var axis := {}
	for r in 45:
		var y := 0.45 + r * 0.025
		var c := _axis_at(y)
		axis["%.3f" % y] = [snappedf(c.x, 0.0001), snappedf(c.z, 0.0001)]
	return {"rows": rows, "axis": axis, "skipped": skip}


func _skin_map() -> Dictionary:
	var path := "res://assets/character/body/body.glb"
	if not ResourceLoader.exists(path):
		return {"missing": path}
	var scene := load(path) as PackedScene
	if scene == null:
		return {"missing": path}
	var tmp := scene.instantiate()
	var verts := PackedVector3Array()
	var labs := PackedStringArray()
	for n in tmp.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var v: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for p in v:
				if p.y < SURF_Y.x or p.y > SURF_Y.y:
					continue
				# torso only: drop the hanging arms (A-pose) by distance from the axis
				var c := _axis_at(p.y)
				if Vector2(p.x - c.x, p.z - c.z).length() > 0.26:
					continue
				verts.append(p)
				labs.append("")
	tmp.free()
	var m := _radius_map(verts, labs, false)
	m["note"] = "Full-skin customizer body (default shape), torso within 0.26 m of the axis; arms hang close to the ribs in the A-pose, so side values above y 0.95 can include the inner arm."
	return m


func _limb_radii() -> Dictionary:
	var res := {}
	for ln: String in LIMBS:
		var spec: Array = LIMBS[ln]
		var a := (bind_g[bone_i[spec[0]]] as Transform3D).origin
		var b := (bind_g[bone_i[spec[1]]] as Transform3D).origin
		var ds := PackedFloat32Array()
		for mi in body.meshes:
			if not String(mi.name) in ["Clothes", "Body", "Gear"]:
				continue
			var am := mi.mesh as ArrayMesh
			var skin: Skin = mi.skin
			for s in am.get_surface_count():
				var arr := am.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var nb := bo.size() / maxi(v.size(), 1)
				for i in v.size():
					var best := 0
					for k in nb:
						if w[i * nb + k] > w[i * nb + best]:
							best = k
					var dom := sk.get_bone_name(skin.get_bind_bone(bo[i * nb + best]))
					var hit := false
					for p: String in spec[2]:
						if dom.begins_with(p) and not dom.contains("helper"):
							hit = true
					if hit:
						var ab := b - a
						var tt := (v[i] - a).dot(ab) / maxf(ab.length_squared(), 1e-9)
						if tt >= 0.2 and tt <= 0.8:
							ds.append(_seg_dist(v[i], a, b))
		ds.sort()
		res[ln] = {"from": spec[0], "to": spec[1], "length": snappedf(a.distance_to(b), 0.001),
				"radius_p90": snappedf(ds[int(ds.size() * 0.9)] if ds.size() > 0 else 0.05, 0.001),
				"radius_p50": snappedf(ds[int(ds.size() * 0.5)] if ds.size() > 0 else 0.05, 0.001), "verts": ds.size()}
		limb_r[ln] = float(res[ln]["radius_p90"])
	return res


# --- items ---------------------------------------------------------------------------

func _items_section() -> Dictionary:
	var res := {}
	var kinds := [["musket", "w"], ["pistol", "w"], ["bow", "w"], ["arrow", "a"], ["spear", "t"], ["tomahawk", "t"],
			["tomahawk_pipe", "t"], ["atlatl", "t"], ["atlatl_dart", "t"]]
	for kd: Array in kinds:
		var model: Node3D
		match kd[1]:
			"w":
				model = WeaponModels.build(kd[0])
			"a":
				model = WeaponModels.build_arrow()
			_:
				model = ThrowableModels.build(kd[0])
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for n in model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var xf := _rel(mi, model)
			var bb := mi.mesh.get_aabb()
			for c in 8:
				var p := xf * bb.get_endpoint(c)
				lo = lo.min(p)
				hi = hi.max(p)
		var markers := {}
		for n in model.find_children("*", "Node3D", true, false):
			if n is Marker3D or String(n.name) in ["Muzzle", "Tip", "COM", "Butt", "Head", "Spur", "Nock", "Pan", "Edge", "Blade", "Mouthpiece", "NockPoint", "StringTop", "StringBottom"]:
				markers[String(n.name)] = _v(_rel(n as Node3D, model).origin)
		res[kd[0]] = {"aabb_min": _v(lo), "aabb_max": _v(hi), "size": _v(hi - lo), "markers": markers,
				"glb": WeaponModels.has_glb(kd[0]) if kd[1] == "w" else (ThrowableModels.has_glb(kd[0]) if kd[1] == "t" else true)}
		model.free()
	return res


## Transform of `n` relative to its ancestor `top` (no scene tree needed).
static func _rel(n: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# --- holsters -------------------------------------------------------------------------

func _holster_sample(hol: Dictionary, clip: String, cat: String, t: float, g: Array) -> void:
	for h: String in HOLSTERS:
		var gh: Transform3D = g[bone_i[h]]
		var sd := _sdist(gh.origin)
		var sd_nohorn := _sdist(gh.origin, ["horn", "wood", "horn_tip"])
		if not hol.has(h):
			hol[h] = {}
		if not hol[h].has(clip):
			hol[h][clip] = {"category": cat, "surf_min": INF, "surf_max": -INF, "surf_label": {}, "rel": {}}
		var e: Dictionary = hol[h][clip]
		e.surf_min = minf(e.surf_min, sd_nohorn[0])
		e.surf_max = maxf(e.surf_max, sd_nohorn[0])
		e.surf_label[sd[1]] = true
		for bn in ["root", "pelvis", "spinea", "spineb", "spined"]:
			var gb: Transform3D = g[bone_i[bn]]
			var rel := gb.affine_inverse() * gh
			var rel0 := (bind_g[bone_i[bn]] as Transform3D).affine_inverse() * (bind_g[bone_i[h]] as Transform3D)
			var drift := rel.origin.distance_to(rel0.origin)
			var turn := rad_to_deg(rel.basis.get_rotation_quaternion().angle_to(rel0.basis.get_rotation_quaternion()))
			if not e.rel.has(bn):
				e.rel[bn] = {"drift_max": 0.0, "turn_max": 0.0, "first": _xf(rel)}
			e.rel[bn].drift_max = maxf(e.rel[bn].drift_max, drift)
			e.rel[bn].turn_max = maxf(e.rel[bn].turn_max, turn)
		if t == 0.0:
			e["global_t0"] = _xf(gh)


# --- grid (sweep map + attach drift) --------------------------------------------------

func _make_grid() -> Array:
	var pts: Array = []
	var rows := {}
	for i in sv.size():
		var r := int(round((sv[i].y - GRID_Y.x) / GRID_DY))
		if not rows.has(r):
			rows[r] = []
		(rows[r] as Array).append(i)
	var y := GRID_Y.x
	while y <= GRID_Y.y + 1e-6:
		var c := _axis_at(y)
		var row: Array = rows.get(int(round((y - GRID_Y.x) / GRID_DY)), [])
		var a := 0.0
		while a < 360.0 - 1e-6:
			var d := _dir(a)
			# outermost surface vertex in this bin
			var best := -1
			var br := -1.0
			for i: int in row:
				var p := sv[i]
				if absf(p.y - y) > GRID_DY * 0.5:
					continue
				var dd := Vector3(p.x - c.x, 0.0, p.z - c.z)
				if dd.length() < 1e-4:
					continue
				var da := absf(wrapf(_ang(dd) - a, -180.0, 180.0))
				if da > GRID_DA * 0.5:
					continue
				if dd.length() > br:
					br = dd.length()
					best = i
			if best >= 0:
				var p0 := Vector3(c.x, y, c.z) + d * (br + GRID_OFF)
				pts.append({"y": y, "a": a, "r": br, "label": slab[best], "v": best, "p": p0, "min": {}, "drift": {}})
			a += GRID_DA
		y += GRID_DY
	print("grid points: ", pts.size())
	return pts


func _lbs_point(g_mats: Array, vi: int, p: Vector3) -> Vector3:
	var m: Array = g_mats[sskin_i[vi]]
	var acc := Vector3.ZERO
	for k in 4:
		var wk := sw[4 * vi + k]
		if wk > 0.0:
			acc += ((m[sbo[4 * vi + k]] as Transform3D) * p) * wk
	return acc


var _mats_cache: Array = []


## Limb capsule segments of the pose `g`. The thigh starts LIMB_TRIM of the way down from
## the hip joint: its rounded top would otherwise stick up into the pelvis and flag items at
## the hips even standing still (the hip itself is part of the measured outer surface).
const LIMB_TRIM := {"r_thigh": 0.25, "l_thigh": 0.25}


func _limb_segs(g: Array) -> Dictionary:
	var segs := {}
	for ln: String in LIMBS:
		var spec: Array = LIMBS[ln]
		var a := (g[bone_i[spec[0]]] as Transform3D).origin
		var b := (g[bone_i[spec[1]]] as Transform3D).origin
		segs[ln] = [a.lerp(b, float(LIMB_TRIM.get(ln, 0.0))), b]
	return segs


func _grid_sample(grid: Array, clip: String, cat: String, g: Array) -> void:
	_mats_cache = _skin_mats(g)
	var segs := _limb_segs(g)
	for pt: Dictionary in grid:
		var p := _lbs_point(_mats_cache, pt.v, pt.p)
		var bestd := INF
		var bestl := ""
		for ln: String in segs:
			var d := _seg_dist(p, segs[ln][0], segs[ln][1]) - float(limb_r[ln])
			if d < bestd:
				bestd = d
				bestl = ln
		var mn: Dictionary = pt.min
		if not mn.has(cat) or bestd < float(mn[cat][0]):
			mn[cat] = [bestd, bestl, clip]
		# rigid attachment drift per bone
		for bn: String in ATTACH_BONES:
			var b: int = bone_i[bn]
			var rp := (g[b] as Transform3D) * ((bind_g[b] as Transform3D).affine_inverse() * (pt.p as Vector3))
			var dr := rp.distance_to(p)
			var key := bn + ("|loco" if cat in LOCO_CATS else "|trav")
			pt.drift[key] = maxf(float(pt.drift.get(key, 0.0)), dr)
			pt.drift[bn + "|any"] = maxf(float(pt.drift.get(bn + "|any", 0.0)), dr)


func _grid_out(grid: Array) -> Array:
	var res: Array = []
	for pt: Dictionary in grid:
		var mn := {}
		for c in pt.min:
			mn[c] = [snappedf(float(pt.min[c][0]), 0.001), pt.min[c][1], pt.min[c][2]]
		var dr := {}
		for k in pt.drift:
			dr[k] = snappedf(float(pt.drift[k]), 0.001)
		res.append({"y": snappedf(pt.y, 0.001), "a": pt.a, "outer_r": snappedf(pt.r, 0.0001), "surface": pt.label,
				"p": _v(pt.p), "limb_min": mn, "drift": dr})
	return res


# --- candidates -----------------------------------------------------------------------

## candidates.json: {"points": [{"id", "group", "bone", "origin": [x,y,z] (bind skeleton space),
##   "axis": [x,y,z] (item long axis, grip -> tip), "up": [x,y,z] (optional), "length": m,
##   "grip_at": fraction of length from the origin end (0), "radius": m, "skip_labels": [..]}]}
## The item is a capsule from origin to origin + axis * length, carried rigidly by `bone`
## (or by the skin weights of the nearest surface vertex when bone == "skin").
func _load_candidates() -> Array:
	var path: String = args.get("candidates", "res://tools/loadout/candidates.json")
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("bad candidates file")
		return []
	var res: Array = []
	for c: Dictionary in d.get("points", []):
		var o := _vec(c.origin)
		var ax := _vec(c.axis).normalized()
		var e := {"nopair": c.get("nopair", false), "id": c.id, "group": c.get("group", ""), "bone": c.bone, "o": o, "ax": ax, "len": float(c.length),
				"rad": float(c.radius), "skip": c.get("skip_labels", []), "min": {}, "surf": {}, "pair": {}, "v": -1,
				"grip": o + ax * float(c.length) * float(c.get("grip_at", 0.0)), "dump": c.get("dump", false)}
		if c.has("cats"):
			e["cats"] = c.cats
		e["yield"] = float(c.get("yield", 0.0))
		if c.bone == "skin":
			e.v = _nearest_sv(o)
		elif c.bone == "skin2":
			# two anchors along the item follow the skin near them (a strap holds it there)
			var an: Array = c.get("anchors", [0.2, 0.8])
			e["ta"] = float(an[0])
			e["tb"] = float(an[1])
			e["pa"] = o + ax * float(c.length) * e.ta
			e["pb"] = o + ax * float(c.length) * e.tb
			e["va"] = _nearest_sv(e.pa)
			e["vb"] = _nearest_sv(e.pb)
		res.append(e)
	print("candidates: ", res.size())
	return res


func _nearest_sv(p: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in sv.size():
		var dd := sv[i].distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = i
	return best


func _cand_pose(c: Dictionary, g: Array) -> Array:
	var a: Vector3 = c.o
	var b: Vector3 = c.o + c.ax * c.len
	var gp: Vector3 = c.grip
	if c.bone == "skin2":
		var pa := _lbs_point(_mats_cache, c.va, c.pa)
		var pb := _lbs_point(_mats_cache, c.vb, c.pb)
		var d := (pb - pa).normalized()
		var L: float = c.len
		var o := pa - d * L * float(c.ta)
		var gt := ((c.grip as Vector3) - (c.o as Vector3)).length() / maxf(L, 1e-6)
		return [o, o + d * L, o + d * L * gt]
	if c.bone == "skin":
		return [_lbs_point(_mats_cache, c.v, a), _lbs_point(_mats_cache, c.v, b), _lbs_point(_mats_cache, c.v, gp)]
	var bi: int = bone_i[c.bone]
	var m := (g[bi] as Transform3D) * (bind_g[bi] as Transform3D).affine_inverse()
	return [m * a, m * b, m * gp]


func _cand_sample(cands: Array, clip: String, cat: String, t: float, g: Array) -> void:
	if cands.is_empty():
		return
	var segs := _limb_segs(g)
	var posed := {}
	var yposed := _yield_pass(cands, cat, g, segs)
	var detail := cat in DETAIL_CATS
	for c: Dictionary in cands:
		if c.has("cats") and not cat in c.cats:
			continue
		var ab: Array = yposed[c.id] if yposed.has(c.id) else _cand_pose(c, g)
		posed[c.id] = ab
		if args.has("debug_pose"):
			print("POSE %s %s t=%.2f  a %s  b %s" % [clip, c.id, t, ab[0], ab[1]])
		# surface clearance along the capsule (5 samples): signed distance - radius
		var worst := INF
		var wl := ""
		var wk := 0
		for k in 5:
			var p: Vector3 = (ab[0] as Vector3).lerp(ab[1], k / 4.0)
			var sd := _sdist(p, c.skip)
			if float(sd[0]) - c.rad < worst:
				worst = float(sd[0]) - c.rad
				wl = "%s@k%d(%.2f,%.2f,%.2f)" % [sd[1], k, p.x, p.y, p.z]
				wk = k
		var sf: Dictionary = c.surf
		if not sf.has(cat) or worst < float(sf[cat][0]):
			sf[cat] = [worst, wl, clip, t]
		if not sf.has("max") or worst > float(sf["max"][0]):
			sf["max"] = [worst, wl, clip, t]
		# limbs (capsule-capsule)
		var mn: Dictionary = c.min
		if not c.has("by_clip"):
			c["by_clip"] = {}
		var bc: Dictionary = c.by_clip
		if not bc.has(clip):
			bc[clip] = [INF, "", INF]
		bc[clip][2] = minf(float(bc[clip][2]), worst)
		if detail and not c.has("by_clip_limb"):
			c["by_clip_limb"] = {}
		for ln: String in segs:
			var d: float = _seg_seg(ab[0], ab[1], segs[ln][0], segs[ln][1]) - float(c.rad) - float(limb_r[ln])
			var key := cat + "|" + ln
			if not mn.has(key) or d < float(mn[key][0]):
				mn[key] = [d, clip, t]
			if d < float(bc[clip][0]):
				bc[clip][0] = d
				bc[clip][1] = ln
			if detail:
				var bl: Dictionary = c.by_clip_limb
				if not bl.has(clip):
					bl[clip] = {}
				if not bl[clip].has(ln) or d < float(bl[clip][ln][0]):
					bl[clip][ln] = [d, t]
		# right-hand reach: grip distance from the right shoulder joint
		var rs := (g[bone_i["r_shoulder"]] as Transform3D).origin
		var reach := (ab[2] as Vector3).distance_to(rs)
		if not c.has("reach") or reach > float(c.reach[0]):
			c["reach"] = [reach, clip, t]
	# pairwise gaps (ordinary play and traversal clips only; both candidates sampled here)
	if detail:
		return
	for i in cands.size():
		for j in range(i + 1, cands.size()):
			var a: Dictionary = cands[i]
			var b: Dictionary = cands[j]
			if a.get("nopair", false) or b.get("nopair", false):
				continue
			if not (posed.has(a.id) and posed.has(b.id)):
				continue
			var pa: Array = posed[a.id]
			var pb: Array = posed[b.id]
			var d: float = _seg_seg(pa[0], pa[1], pb[0], pb[1]) - float(a.rad) - float(b.rad)
			var key: String = b.id
			var grp := "loco" if cat in LOCO_CATS else "trav"
			if not a.pair.has(key):
				a.pair[key] = {}
			var pe: Dictionary = a.pair[key]
			if not pe.has(grp) or d < float(pe[grp][0]):
				pe[grp] = [d, clip, t]


const YIELD_LIMBS := ["r_upper_arm", "r_forearm", "r_hand", "l_upper_arm", "l_forearm", "l_hand", "r_thigh", "l_thigh", "r_shin",
		"l_shin"]


func _limb_clear(a: Vector3, b: Vector3, rad: float, segs: Dictionary) -> float:
	var w := INF
	for ln: String in YIELD_LIMBS:
		if segs.has(ln):
			w = minf(w, _seg_seg(a, b, segs[ln][0], segs[ln][1]) - rad - float(limb_r[ln]))
	return w


func _surf_min(a: Vector3, b: Vector3, c: Dictionary) -> float:
	var w := INF
	for k in [0.5, 0.75, 1.0]:
		w = minf(w, float(_sdist(a.lerp(b, k), c.skip)[0]) - float(c.rad))
	return w


## Revision 3 "yield": every item (capsules sharing the id prefix before ':') whose capsules set
## "yield" swings as one rigid body about the origin of its first capsule (the hook) away from the limbs.
## Returns {capsule id: [a, b, grip]} for the yielding capsules of this pose.
func _yield_pass(cands: Array, cat: String, g: Array, segs: Dictionary) -> Dictionary:
	var groups := {}
	for c: Dictionary in cands:
		if float(c.get("yield", 0.0)) <= 0.0 or (c.has("cats") and not cat in c.cats):
			continue
		var key := String(c.id).get_slice(":", 0)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c)
	var out := {}
	for key: String in groups:
		var mem: Array = groups[key]
		var ab := {}
		for c: Dictionary in mem:
			ab[c.id] = _cand_pose(c, g)
		var pivot: Vector3 = ab[mem[0].id][0]
		var base := INF
		var s0 := INF
		for c: Dictionary in mem:
			base = minf(base, _limb_clear(ab[c.id][0], ab[c.id][1], float(c.rad), segs))
			s0 = minf(s0, _surf_min(ab[c.id][0], ab[c.id][1], c))
		var best_axis := Vector3.ZERO
		var best_ang := 0.0
		var best_c := base
		if base < 0.0:
			var u: Vector3 = ((ab[mem[0].id][1] as Vector3) - pivot).normalized()
			var p := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized()
			var q := u.cross(p)
			var ang := 5.0
			while ang <= float(mem[0]["yield"]) + 0.01:
				for k in 8:
					var az := TAU * float(k) / 8.0
					var axis := (p * cos(az) + q * sin(az)).normalized()
					var cl := INF
					for c: Dictionary in mem:
						var e: Array = ab[c.id]
						cl = minf(cl, _limb_clear(pivot + ((e[0] as Vector3) - pivot).rotated(axis, deg_to_rad(ang)),
								pivot + ((e[1] as Vector3) - pivot).rotated(axis, deg_to_rad(ang)), float(c.rad), segs))
					if cl <= best_c + 0.002:
						continue
					var sf := INF
					for c: Dictionary in mem:
						var e: Array = ab[c.id]
						sf = minf(sf, _surf_min(pivot + ((e[0] as Vector3) - pivot).rotated(axis, deg_to_rad(ang)),
								pivot + ((e[1] as Vector3) - pivot).rotated(axis, deg_to_rad(ang)), c))
					if sf >= minf(s0, 0.0) - 0.005:
						best_c = cl
						best_axis = axis
						best_ang = ang
				if best_c >= 0.0:
					break
				ang += 5.0
		for c: Dictionary in mem:
			var e: Array = ab[c.id]
			if best_ang > 0.0:
				var r := deg_to_rad(best_ang)
				e = [pivot + ((e[0] as Vector3) - pivot).rotated(best_axis, r), pivot + ((e[1] as Vector3) - pivot).rotated(best_axis, r),
						pivot + ((e[2] as Vector3) - pivot).rotated(best_axis, r)]
			out[c.id] = e
	return out

func _cand_out(cands: Array) -> Array:
	var res: Array = []
	for c: Dictionary in cands:
		var surf := {}
		for k in c.surf:
			surf[k] = [snappedf(float(c.surf[k][0]), 0.001), c.surf[k][1], c.surf[k][2], snappedf(float(c.surf[k][3]), 0.01)]
		var limbs := {}
		for k in c.min:
			limbs[k] = [snappedf(float(c.min[k][0]), 0.001), c.min[k][1], snappedf(float(c.min[k][2]), 0.01)]
		var pair := {}
		for k in c.pair:
			var pe := {}
			for grp in c.pair[k]:
				var v: Array = c.pair[k][grp]
				pe[grp] = [snappedf(float(v[0]), 0.001), v[1], snappedf(float(v[2]), 0.01)]
			pair[k] = pe
		var byc := {}
		for k in c.get("by_clip", {}):
			var v: Array = c.by_clip[k]
			byc[k] = [snappedf(float(v[0]), 0.001), v[1], snappedf(float(v[2]), 0.001)]
		var bcl := {}
		for k in c.get("by_clip_limb", {}):
			var e := {}
			for ln in c.by_clip_limb[k]:
				var v: Array = c.by_clip_limb[k][ln]
				e[ln] = [snappedf(float(v[0]), 0.001), snappedf(float(v[1]), 0.001)]
			bcl[k] = e
		res.append({"id": c.id, "group": c.group, "bone": c.bone, "surface": surf, "limbs": limbs, "pairs": pair, "by_clip": byc,
				"by_clip_limb": bcl,
				"reach_max": [snappedf(float(c.reach[0]), 0.001), c.reach[1], snappedf(float(c.reach[2]), 0.01)] if c.has("reach") else null})
	return res


# --- draw clips -----------------------------------------------------------------------

func _draws_section() -> Array:
	var res: Array = []
	for spec: Array in DRAWS:
		var clip: String = spec[0]
		var e := {"clip": clip, "base": spec[1], "add": spec[2], "weapon": spec[3], "kind": spec[4]}
		if not ap.has_animation(LIB + clip):
			e["missing"] = true
			res.append(e)
			continue
		if not spec[2].is_empty() and not ap.has_animation(LIB + spec[2]):
			e["add_missing"] = true
		var anim := ap.get_animation(LIB + clip)
		var L := anim.length
		e["length"] = snappedf(L, 0.001)
		e["keys_holsters"] = _keyed(anim, HOLSTERS)
		e["keys_props"] = _keyed(anim, PROPS)
		var keyed := {}
		for tr: Array in _tracks(anim):
			keyed[sk.get_bone_name(tr[1])] = true
		e["keyed_bones"] = keyed.size()
		var n := maxi(2, int(round(L / 0.1)) + 1)
		var frames: Array = []
		var best := {}
		for j in n:
			var t := L * j / float(n - 1)
			_pose(clip, t, spec[1], spec[2] if ap.has_animation(LIB + spec[2]) else "")
			var g := body.skinning_globals()
			_skin_surface(g)
			var pel: Transform3D = g[bone_i["pelvis"]]
			var fr := {"t": snappedf(t, 0.001)}
			for pr: String in PROPS:
				var gp: Transform3D = g[bone_i[pr]]
				var side := pr.left(1)
				fr[side + "_prop"] = _v(gp.origin)
				fr[side + "_prop_zdir"] = _v(gp.basis.orthonormalized().z)
				fr[side + "_prop_ydir"] = _v(gp.basis.orthonormalized().y)
				fr[side + "_wrist"] = _v((g[bone_i[side + "_wrist"]] as Transform3D).origin)
				fr[side + "_wrist_surf"] = snappedf(float(_sdist((g[bone_i[side + "_wrist"]] as Transform3D).origin)[0]), 0.001)
				fr[side + "_prop_pelvis"] = _v(pel.affine_inverse() * gp.origin)
				fr[side + "_surf"] = snappedf(float(_sdist(gp.origin)[0]), 0.001)
				for h: String in HOLSTERS:
					var gh: Transform3D = g[bone_i[h]]
					var d := gp.origin.distance_to(gh.origin)
					fr[side + "_to_" + h] = snappedf(d, 0.001)
					var key := side + "|" + h
					if not best.has(key) or d < float(best[key].d):
						best[key] = {"d": d, "t": t, "prop_in_holster": _xf(gh.affine_inverse() * gp),
								"holster_global": _xf(gh), "prop_global": _xf(gp),
								"holster_in_pelvis": _xf(pel.affine_inverse() * gh), "holster_in_spineb": _xf((g[bone_i["spineb"]] as Transform3D).affine_inverse() * gh),
								"prop_surface_dist": snappedf(float(_sdist(gp.origin)[0]), 0.001)}
			for h: String in HOLSTERS:
				fr[h] = _v((g[bone_i[h]] as Transform3D).origin)
			frames.append(fr)
		var bo := {}
		for k in best:
			var bb: Dictionary = best[k]
			bb.d = snappedf(float(bb.d), 0.001)
			bb.t = snappedf(float(bb.t), 0.001)
			bo[k] = bb
		e["closest"] = bo
		e["frames"] = frames
		res.append(e)
	return res


# --- math / json helpers ------------------------------------------------------------------

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-12 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-12 and e <= 1e-12:
		return p1.distance_to(p2)
	if a <= 1e-12:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-12:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-12 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)]


static func _vec(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## {origin, x, y, z (basis columns)} rounded.
static func _xf(t: Transform3D) -> Dictionary:
	var b := t.basis.orthonormalized()
	return {"origin": _v(t.origin), "x": _v(b.x), "y": _v(b.y), "z": _v(b.z)}
