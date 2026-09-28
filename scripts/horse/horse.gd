class_name Horse
extends CharacterBody3D
## Rideable horse (procedural asset from tools/horse/build_horse.py): a stocky 14.1-hand
## colonial saddle horse, 1.45 m at the withers.
##
## The horse owns the gait phase; a rider samples its riding clip at the same phase
## (rider phase = horse phase, as in the source animation graph; horse.md 1.4). Each
## horse clip has the length and frame count of the Actor_B riding clip it carries.
##
##   var horse := Horse.new()            # or instance scenes/... with this script
##   add_child(horse)
##   horse.drive(1.0, 0.0)               # throttle 0..1 (fraction of the cruise speed), steer -1..1
##   horse.set_cruise_gait(Horse.Gait.GALLOP)
##   horse.request_jump()
##   horse.get_saddle_transform()        # rider attach frame (global)
##   horse.get_mount_point(Horse.LEFT)   # where a rider stands to mount (global)
##
## Speed and gait. Every gait clip has a no-slip ground speed (stride length / stride
## time, assets/horse/horse_meta.json design_speed) and, except the sprint, a short-stride
## variant with the same timing. For a speed v the horse blends the two strides and plays
## the blend at rate = v / blended stride speed, so the planted hooves never slide: the
## stride shortens first, and only outside the stride range does the playback rate (and
## with it the rider clip) leave 1.0, within RATE_BAND (0.85-1.15; the walk goes down to
## 0.65, and below its slowest walk the horse either halts or steps off at that speed).
## Gait changes happen at UP_SHIFT / DOWN_SHIFT, which lie inside both neighbouring gaits'
## no-slip bands; a gait holds for MIN_DWELL before the next change, and meanwhile the speed
## stays inside its band. A gait change keeps the footfall phase (left-hind touchdown
## aligned) and cross-fades for GAIT_FADE seconds.
##
## Pace (revision 4). The rider clips fix the step timing (walk 1.2 s, trot 0.933 s per
## stride), and a real 14.1-hand horse's hind legs only reach so far: at the authored rate
## the walk is 1.38 m/s and the trot 3.0 m/s (1.65 m and 2.8 m strides). Faster cruise speeds
## would need a faster rider clip (a higher playback rate) or strides the legs cannot reach
## with a realistic hip swing; see horse.md 0.3.
##
## Steering: the yaw rate is limited to v / R with R the gait's minimum turn radius
## (TURN_RADIUS) or v^2 / A_LAT, whichever is larger. Every moving gait clip has curved
## variants (<clip>_tl / <clip>_tr, horse_meta.json "turning") baked on a circle with the
## hooves planted along the arc and the body leaning in; the horse blends them in by
## curvature (yaw rate x baked radius / speed), so a turning horse does not skid its hooves
## sideways. The neck also bends into the turn.
##
## Jump: a real jump. The root (this body and its collision shapes) leaves the ground on a
## ballistic arc between the clip's take-off and landing times, the clip plays at
## speed / jump design speed (JUMP_RATE band) and a request is held until the take-off
## distance to an obstacle ahead is right (take-off window from the asset's clearance
## table).
##
## Hills (user 2026-09-25): HorseTerrain (horse_terrain.gd) poses the flat-ground clips onto the
## ground every tick -- the body pitched with the slope, the downhill posture (croup lowered and
## hind legs under, neck raised) and the uphill one (neck low and forward, driving from behind),
## each hoof IK'd onto the ground under it with its toe locked while it stands -- and caps the
## speed by the slope along the heading (slower uphill, slower still downhill; the horse refuses
## ground steeper than HorseTerrain.UP_LIMIT / DOWN_LIMIT). On the ground the root follows the
## floor plane, so its horizontal speed stays the gait's no-slip speed. Stumps and logs (group
## HorseTerrain.LOW_GROUP) do not block the horse: it steps over them; saplings and shrubs have
## no colliders (they lean away from a rider in the shader, tree_common.gdshaderinc).
##
## Hauling (user 2026-09-26): HorseHaul (horse_haul.gd) hooks a load on a chain at get_hitch_point() and caps
## the speed by the pull it takes (haul_speed_cap, haul_accel_scale); HorseLead (horse_lead.gd) leads the
## horse on foot through drive().
##
## Facing: the model faces +z in its own space and the Visual node is turned 180
## degrees, so the horse moves along -basis.z like the player (FrontierPlayer).

signal gait_changed(old_gait: int, new_gait: int)
signal one_shot_finished(clip: String)
signal jumped(takeoff_position: Vector3)
signal landed(position: Vector3)

enum Gait { IDLE, WALK, TROT, CANTER, GALLOP, SPRINT }
const GAIT_CLIPS := ["idle", "walk", "trot", "canter", "gallop", "sprint"]
## Short-stride variant of each gait clip ("" = none).
const SHORT_CLIPS := ["", "walk_s", "trot_s", "canter_s", "gallop_s", ""]
## Actor_B front-rider clip per horse clip (library "actor_b").
const RIDER_CLIPS := {
	"idle": "actor_b-horse-idle", "walk": "actor_b-horse-walk-fw", "trot": "actor_b-horse-trot-fw",
	"canter": "actor_b-horse-canter-fw", "gallop": "actor_b-horse-gallop-fw",
	"sprint": "actor_b-horse-gallop-sprint", "turn_l": "actor_b-horse-idle", "turn_r": "actor_b-horse-idle",
	"jump": "actor_b-horse-gallop^jump-over",
	# Actor_B has no rear clip; tools/retarget's Actor_A -> Actor_B prototype has one.
	"rear": "actor_a_rt/actor_a-horse-rear",
}
const LEFT := 1
const RIGHT := -1
const MODEL_PATH := "res://assets/horse/horse.glb"
const HorseLook := preload("res://scripts/horse/horse_look.gd")
const META_PATH := "res://assets/horse/horse_meta.json"
const GAIT_FADE := 0.25
## Speed at full throttle per cruise gait (m/s): a walk, a working trot, a canter, a
## gallop and a flat-out run (the player sprints at 5.6 m/s on foot). The clips' speeds at
## playback rate 1 are 1.38 / 3.0 / 6.0 / 10.0 / 13.1 m/s (horse_meta design_speed).
const CRUISE := [0.0, 1.4, 3.15, 6.2, 11.0, 13.0]
## Playback-rate band per gait [min, max]: the rider clip plays within 0.85-1.15 of its
## authored speed (0.65 at the slowest walk).
const RATE_BAND := [Vector2(1.0, 1.0), Vector2(0.65, 1.15), Vector2(0.85, 1.15), Vector2(0.85, 1.15),
		Vector2(0.85, 1.15), Vector2(0.85, 1.08)]
## Speed (m/s) above which gait i hands over to gait i + 1, and below which gait i + 1
## drops back to gait i. Each lies inside both gaits' no-slip bands (see gait_band()), and
## every cruise speed lies outside the hysteresis gaps, so a cruise gait is reached from
## above as well as from below. The walk hands back to the halt just above its slowest
## no-slip speed (the horse steps off at that speed and halts from it).
const UP_SHIFT := [0.12, 1.56, 3.40, 6.8, 11.45]
const DOWN_SHIFT := [0.33, 1.46, 3.22, 6.4, 11.2]
## Seconds a gait holds before the next gait change (about half a stride); longer than
## GAIT_FADE, so a cross-fade always finishes before the next one starts.
const MIN_DWELL := 0.3
## Minimum turn radius per gait (m) and the lateral acceleration limit (m/s^2); the asset's
## values (horse_meta.json "turning") override these.
const TURN_RADIUS := [0.0, 2.0, 3.5, 5.0, 10.0, 20.0]
const A_LAT := 6.0
## Neck bend into a turn at the full yaw rate (deg, spread over the neck and head).
const TURN_BEND := 22.0
## Jump playback-rate band (speed / jump design speed).
const JUMP_RATE := Vector2(0.85, 1.15)
## Acceleration (m/s^2) with which the approach speed is brought into the jump band.
const JUMP_ADJUST := 6.0
## A jump request waits at most this long for the take-off point.
const JUMP_HOLD := 1.5
## How far ahead (m) a jump request looks for the obstacle.
const JUMP_PROBE := 16.0
## Hauling (HorseHaul, horse_haul.gd): the singletree's hook, this far behind the root and this high over the
## ground there (m).
const HITCH_BACK := 1.4
const HITCH_HEIGHT := 0.62

@export var player_input := false
## Coat: bay, brown, black, chestnut, grey or dun (HorseLook.COATS).
@export var coat := "bay":
	set(value):
		coat = value
		if visual:
			HorseLook.set_coat(visual, coat)
@export var accel := 2.5
@export var brake := 4.0
@export var steer_response := 6.0
@export var gravity := 9.81

var meta: Dictionary = {}
var visual: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var blender: HorsePhaseBlender
## Hills: ground-following posture, hoof placement and the slope speed limits (horse_terrain.gd).
var terrain: HorseTerrain
## Hauling (HorseHaul): the load on the chain caps the speed (m/s, INF: nothing hitched) and slows the pick-up.
var haul_speed_cap := INF
var haul_accel_scale := 1.0

var gait := Gait.IDLE
var cruise_gait := Gait.TROT
var speed := 0.0            ## forward speed, m/s
var target_speed := 0.0
var steer := 0.0            ## -1 (right) .. 1 (left), smoothed
var yaw_speed := 0.0        ## rad/s, + = turning left
var phase := 0.0            ## 0..1 through the current clip
var clip := "idle"          ## current horse clip
var rate := 1.0             ## clip playback rate
var stride_w := 1.0         ## weight of the full stride against the short one
var curve := 0.0           ## weight of the curved gait variants, -1 (right) .. 1 (left)
var one_shot := ""          ## "jump" / "rear" while one plays
var one_shot_time := 0.0    ## clip time of the one-shot
var airborne := false       ## the root is in the jump's flight
var jump_rate := 1.0
## Phase of the idle loop; keeps running through turns in place, whose rider clip is the
## riding idle (Actor_B has no turn-in-place clip).
var idle_phase := 0.0

var _throttle := 0.0
var _steer_in := 0.0
var _saddle_bone := -1
var _saddle_rest_inv := Transform3D()
var _attach_rest := Transform3D()
var _forced := ""
var _reins: MeshInstance3D
var _rein_mesh: ImmediateMesh
var _rein_targets: Array = []    ## [Vector3 left hand, Vector3 right hand] global, or empty
var _dwell := 0.0
var _walk_held := false
var _cruise_before_walk := Gait.TROT
var _jump_pending := 0.0         ## > 0: a jump request waiting for the take-off point
var _jump_ray: RayCast3D
var _body_shape: CollisionShape3D
var _feet_shape: CollisionShape3D
var _feet_sphere: SphereShape3D
var _body_rest_y := 0.0
var _feet_r := 0.36
var _neck_bones: Array[int] = []
var _body_bone := -1
var _hoof_bones: Array[int] = []


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if meta == null:
		push_error("Horse: cannot read %s" % META_PATH)
		meta = {}
	visual = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	visual.name = "Visual"
	visual.rotation.y = PI
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim_player = visual.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for a in anim_player.get_animation_list():
		var an := anim_player.get_animation(a)
		var loops: bool = meta.get("clips", {}).get(String(a), {}).get("loop", false)
		an.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	HorseLook.apply(visual, coat)
	_saddle_bone = skeleton.find_bone("saddle")
	var rest := skeleton.get_bone_global_rest(_saddle_bone)
	_saddle_rest_inv = rest.affine_inverse()
	_attach_rest = Transform3D(Basis(), rest.origin)
	for b in ["neck_1", "neck_2", "neck_3", "head"]:
		_neck_bones.append(skeleton.find_bone(b))
	_body_bone = skeleton.find_bone("body")
	for b in ["hoof_l", "hoof_r", "hhoof_l", "hhoof_r"]:
		_hoof_bones.append(skeleton.find_bone(b))
	blender = HorsePhaseBlender.new(anim_player, visual)
	blender.show_clip("idle", 0.0, 0.0)
	blender.update(0.0)
	_build_collision()
	terrain = HorseTerrain.new(self)
	_build_reins()
	if player_input:
		HorseInput.ensure()


func _build_collision() -> void:
	# body box, plus a sphere between the legs that carries the horse on the ground; both
	# follow the body and the legs (they lift with the tucked legs in a jump)
	var c: Dictionary = meta.get("collision", {})
	var sz: Array = c.get("box_size", [0.62, 0.95, 1.8])
	var ce: Array = c.get("box_center", [0.0, 1.025, 0.07])
	_feet_r = float(c.get("feet_radius", 0.36))
	_body_shape = CollisionShape3D.new()
	_body_shape.name = "BodyShape"
	var box := BoxShape3D.new()
	box.size = Vector3(sz[0], sz[1], sz[2])
	_body_shape.shape = box
	# the model is turned 180 degrees: model +z (forward) is body -z
	_body_shape.position = Vector3(-float(ce[0]), float(ce[1]), -float(ce[2]))
	_body_rest_y = float(ce[1])
	add_child(_body_shape)
	_feet_shape = CollisionShape3D.new()
	_feet_shape.name = "FeetShape"
	_feet_sphere = SphereShape3D.new()
	_feet_sphere.radius = _feet_r
	_feet_shape.shape = _feet_sphere
	_feet_shape.position = Vector3(0.0, _feet_r, 0.0)
	add_child(_feet_shape)
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.5
	_jump_ray = RayCast3D.new()
	_jump_ray.name = "JumpProbe"
	_jump_ray.position = Vector3(0.0, 0.45, 0.0)
	_jump_ray.target_position = Vector3(0.0, 0.0, -JUMP_PROBE)
	_jump_ray.add_exception(self)
	add_child(_jump_ray)


## Changes the coat (see `coat`).
func set_coat(c: String) -> void:
	coat = c


# ---------------------------------------------------------------------------
# Control API
# ---------------------------------------------------------------------------
## throttle: 0..1 of the cruise gait's cruise speed (1.0 = cruise), negative brakes.
## steer: -1 (right) .. 1 (left).
func drive(throttle: float, steer_input: float) -> void:
	_throttle = throttle
	_steer_in = clampf(steer_input, -1.0, 1.0)


func set_cruise_gait(g: int) -> void:
	cruise_gait = clampi(g, Gait.WALK, Gait.SPRINT)


func spur() -> void:
	set_cruise_gait(mini(cruise_gait + 1, Gait.GALLOP))


## Asks for a jump (canter or faster). With an obstacle ahead the jump starts when the
## obstacle is at the take-off distance (held up to JUMP_HOLD s); the speed is brought
## into the jump band meanwhile. Returns false when the horse cannot jump now.
func request_jump() -> bool:
	if not one_shot.is_empty() or gait < Gait.CANTER or airborne:
		return false
	_jump_pending = JUMP_HOLD
	_try_start_jump()
	return true


func request_rear() -> bool:
	if not one_shot.is_empty() or speed > 0.5:
		return false
	_start_one_shot("rear")
	return true


## No-slip speed (m/s) of a clip at playback rate 1 (meta design_speed).
func clip_speed(c: String) -> float:
	return float(meta.get("clips", {}).get(c, {}).get("design_speed", 0.0))


## Cruise speed of a gait (full throttle).
func design_speed(g: int) -> float:
	return CRUISE[g]


## No-slip speed band of a gait: [slowest, fastest] (short stride at the lowest rate,
## full stride at the highest).
func gait_band(g: int) -> Vector2:
	if g == Gait.IDLE:
		return Vector2(0.0, UP_SHIFT[0])
	var lo_clip: String = SHORT_CLIPS[g] if not SHORT_CLIPS[g].is_empty() else GAIT_CLIPS[g]
	return Vector2(RATE_BAND[g].x * clip_speed(lo_clip), RATE_BAND[g].y * clip_speed(GAIT_CLIPS[g]))


## Stride weight (full vs short stride) and playback rate that make gait g move at v
## with planted hooves: [weight of the full stride, rate].
func stride_for(g: int, v: float) -> Vector2:
	var vl := clip_speed(GAIT_CLIPS[g])
	if g == Gait.IDLE or vl <= 0.0:
		return Vector2(1.0, 1.0)
	var vs := clip_speed(SHORT_CLIPS[g]) if not SHORT_CLIPS[g].is_empty() else vl
	var w := 1.0 if vl - vs < 1e-3 else clampf((v - vs) / (vl - vs), 0.0, 1.0)
	var vc := vs + w * (vl - vs)
	return Vector2(w, clampf(v / maxf(vc, 1e-3), RATE_BAND[g].x, RATE_BAND[g].y))


## Slowest walk (m/s) at which the walk plays without slip (a little above the band's
## floor, so it stays clear of the walk -> halt shift).
func walk_min_speed() -> float:
	return maxf(gait_band(Gait.WALK).x, DOWN_SHIFT[0]) + 0.01


## Minimum turn radius (m) of gait g at speed v.
func min_turn_radius(g: int, v: float) -> float:
	var tr: Dictionary = meta.get("turning", {})
	var rmin: Dictionary = tr.get("turn_radius_min", {})
	var r0 := float(rmin.get(GAIT_CLIPS[g], TURN_RADIUS[g]))
	return maxf(r0, v * v / float(tr.get("a_lat", A_LAT)))


## Maximum yaw rate (rad/s) at speed v in gait g.
func max_yaw_rate(g: int, v: float) -> float:
	if g == Gait.IDLE:
		return deg_to_rad(float(meta.get("clips", {}).get("turn_l", {}).get("yaw_rate_deg_s", 22.5)))
	return v / maxf(min_turn_radius(g, v), 0.01)


## Radius (m) the curved variants of a gait clip are baked on (0 = none).
func curve_radius(c: String) -> float:
	return float(meta.get("clips", {}).get(c + "_tl", {}).get("turn_radius", 0.0))


## Debug / tests: hold a clip at an explicit phase (no movement). "" releases. The jump
## is shown with its root lift applied to the model, as it flies in the game.
func force_clip(clip_name: String, at_phase := 0.0, variant_w := 0.0, curve_w := 0.0) -> void:
	_forced = clip_name
	if not clip_name.is_empty():
		clip = clip_name
		phase = at_phase
		var L := clip_length(clip)
		var short := ""
		var gi := GAIT_CLIPS.find(clip)
		if gi > 0:
			short = SHORT_CLIPS[gi]
		curve = curve_w if gi > 0 else 0.0
		blender.show_clip(clip, phase * L, 0.0, 1.0, short, variant_w if not short.is_empty() else 0.0, curve)
		blender.update(0.0)
		visual.position.y = jump_root_lift(phase * L, 1.0) if clip == "jump" else 0.0
	else:
		visual.position.y = 0.0


func clip_length(c: String) -> float:
	var info: Dictionary = meta.get("clips", {}).get(c, {})
	return float(info.get("length", anim_player.get_animation(c).length if anim_player.has_animation(c) else 1.0))


## Root height above the take-off ground at jump clip time t for playback rate r
## (ballistic arc between the clip's take-off and landing times; 0 outside them).
func jump_root_lift(t: float, r := 1.0) -> float:
	var j: Dictionary = meta.get("clips", {}).get("jump", {})
	var t0 := float(j.get("takeoff_time", 0.37))
	var t1 := float(j.get("landing_time", 0.84))
	if t <= t0 or t >= t1:
		return 0.0
	var tau := t - t0
	return 0.5 * float(j.get("gravity", 9.81)) * tau * (t1 - t0 - tau) / (r * r)


## The gait clip a variant belongs to ("walk_s_tl" -> "walk").
static func base_clip(c: String) -> String:
	if c.ends_with("_tl") or c.ends_with("_tr"):
		c = c.substr(0, c.length() - 3)
	if c.ends_with("_s"):
		c = c.substr(0, c.length() - 2)
	return c


## The rider's clip for the current horse clip and its time (rider phase = horse phase).
func rider_clip() -> String:
	return RIDER_CLIPS.get(base_clip(clip), "actor_b-horse-idle")


func rider_time(rider_clip_length: float) -> float:
	return rider_phase() * rider_clip_length


## Phase at which the rider samples rider_clip(): the horse phase, except during turns in
## place, where the rider keeps playing the riding idle.
func rider_phase() -> float:
	return idle_phase if clip.begins_with("turn") else phase


## Playback rate of the rider clip (= the horse clip's rate; the riding idle during a
## turn in place plays at 1).
func rider_rate() -> float:
	return 1.0 if clip.begins_with("turn") or clip == "idle" else rate


# ---------------------------------------------------------------------------
# Sockets
# ---------------------------------------------------------------------------
## Rider attach frame (global). Its rest is attach_height (meta) above the ground under
## the horse, axes as the model (+z = the horse's forward); the Actor_B rig attaches with
## identity: the riding clips are saddle-relative.
func get_saddle_transform() -> Transform3D:
	var pose := skeleton.get_bone_global_pose(_saddle_bone)
	return skeleton.global_transform * pose * _saddle_rest_inv * _attach_rest


## Hauling: where the chain hooks on behind the horse (the singletree's middle), on the ground plane under it.
func get_hitch_point() -> Vector3:
	var p := global_transform * Vector3(0.0, 0.0, HITCH_BACK)
	var n := get_floor_normal() if is_on_floor() else Vector3.UP
	var d := p - global_position
	p.y = global_position.y - (n.x * d.x + n.z * d.z) / maxf(n.y, 0.3) + HITCH_HEIGHT
	return p


func get_bone_global(bone_name: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))


## Where a rider stands to start the mount clip on `side` (LEFT / RIGHT), facing the flank.
func get_mount_point(side: int) -> Transform3D:
	var m: Dictionary = meta.get("mount", {}).get("mount_left" if side == LEFT else "mount_right", {})
	var p: Array = m.get("pos", [0.69 * side, 0.0, 0.18])
	var yaw := deg_to_rad(float(m.get("yaw_deg", -101.0 * side)))
	return _model_frame_at_ground() * Transform3D(Basis(Vector3.UP, yaw), Vector3(p[0], p[1], p[2]))


func get_dismount_point(side: int) -> Transform3D:
	var m: Dictionary = meta.get("mount", {}).get("dismount_left" if side == LEFT else "dismount_right", {})
	var p: Array = m.get("pos", [0.55 * side, 0.0, 0.0])
	return _model_frame_at_ground() * Transform3D(Basis(), Vector3(p[0], p[1], p[2]))


## Side (LEFT / RIGHT) nearest to `pos`, and whether pos is within `reach` of its mount point.
func nearest_mount_side(pos: Vector3, reach := 1.6) -> int:
	var l := get_mount_point(LEFT).origin.distance_to(pos)
	var r := get_mount_point(RIGHT).origin.distance_to(pos)
	if minf(l, r) > reach:
		return 0
	return LEFT if l <= r else RIGHT


## The horse's model frame on the ground: origin under the saddle attach, +z forward.
func _model_frame_at_ground() -> Transform3D:
	return Transform3D(visual.global_basis, global_position)


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if player_input:
		_read_input()
	if not _forced.is_empty():
		blender.update(delta)
		_update_reins()
		return
	_update_speed(delta)
	_update_gait(delta)
	_update_steer(delta)
	if _jump_pending > 0.0:
		_jump_pending -= delta
		_try_start_jump()
	_advance_phase(delta)
	var fwd := -global_basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	_update_vertical(delta)
	rotate_y(yaw_speed * delta)
	var was_on_floor := is_on_floor()
	move_and_slide()
	# the velocity follows the floor plane (_update_vertical); where it points up (climbing, or a
	# terrain triangle's edge) move_and_slide does not snap, so the horse would hop off every
	# crest and ridge of the height field: keep it on the ground (a real drop, deeper than
	# floor_snap_length, still falls; the jump's flight has no snap)
	if was_on_floor and not airborne and not is_on_floor():
		apply_floor_snap()
	if airborne and velocity.y <= 0.0 and is_on_floor():
		_land()
	# walls: lose the speed we could not make
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if real < speed - 0.5 and speed > 1.0 and one_shot != "jump":
		speed = lerpf(speed, real, 0.5)
	blender.update(delta)
	terrain.update(delta)
	_post_pose()
	_update_collision()
	_update_reins()


func _read_input() -> void:
	var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var s := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	if Input.is_action_just_pressed("sprint"):
		spur()
	# Alt holds a walk; releasing it restores the cruise gait from before
	var walk_now := Input.is_action_pressed("walk")
	if walk_now and not _walk_held:
		_cruise_before_walk = cruise_gait
		set_cruise_gait(Gait.WALK)
	elif _walk_held and not walk_now:
		set_cruise_gait(_cruise_before_walk)
	_walk_held = walk_now
	var sprinting := Input.is_action_pressed("sprint") and cruise_gait == Gait.GALLOP and gait >= Gait.GALLOP
	if Input.is_action_just_pressed("jump"):
		if not request_jump():
			request_rear()
	var thr := f
	if sprinting and f > 0.0:
		thr = CRUISE[Gait.SPRINT] / CRUISE[cruise_gait]
	drive(thr, s)


func _update_speed(delta: float) -> void:
	if one_shot == "rear":
		target_speed = 0.0
	elif one_shot == "jump":
		# the approach strides before the take-off bring any remaining difference into the
		# clip's speed; after the take-off the speed is kept
		var j: Dictionary = meta.get("clips", {}).get("jump", {})
		if not airborne and one_shot_time < float(j.get("takeoff_time", 0.37)):
			speed = move_toward(speed, jump_rate * clip_speed("jump"), JUMP_ADJUST * delta)
		return
	elif _throttle >= 0.0:
		target_speed = _throttle * CRUISE[cruise_gait]
	else:
		target_speed = 0.0
	# hills: slower up and (more so) down, and no further than the horse can go (HorseTerrain)
	var cap: float = minf(terrain.speed_cap() if terrain else INF, haul_speed_cap)
	target_speed = minf(target_speed, cap)
	var a := accel * haul_accel_scale if target_speed > speed else (brake * (1.0 + maxf(-_throttle, 0.0)))
	if speed > cap + 0.5:
		a = maxf(a, 6.0)
	if _jump_pending > 0.0:
		# bring the approach into the jump band, a little more briskly than cruising
		var vj := clip_speed("jump")
		target_speed = clampf(target_speed, JUMP_RATE.x * vj, JUMP_RATE.y * vj)
		a = maxf(a, JUMP_ADJUST)
	speed = move_toward(speed, target_speed, a * delta)
	# while a gait is dwelling the speed stays inside its no-slip band
	if _dwell > 0.0 and gait != Gait.IDLE:
		var band := gait_band(gait)
		speed = clampf(speed, band.x, band.y)
	# a walking horse asked to move keeps at least its slowest no-slip walk (a partial
	# throttle below it does not play the rider's walk in slow motion)
	if gait == Gait.WALK and target_speed > 0.0:
		speed = maxf(speed, walk_min_speed())


func _gait_for_speed(v: float, current: int) -> int:
	var g := current
	while g < Gait.SPRINT and v > UP_SHIFT[g]:
		g += 1
	while g > Gait.IDLE and v < DOWN_SHIFT[g - 1]:
		g -= 1
	return g


func _update_gait(delta: float) -> void:
	_dwell = maxf(_dwell - delta, 0.0)
	if _dwell > 0.0 or not one_shot.is_empty():
		return
	var g := _gait_for_speed(speed, gait)
	if g != gait:
		# one gait at a time, so every change keeps its footfall mapping and fade
		g = gait + signi(g - gait)
		var old := gait
		gait = g
		if old == Gait.IDLE and g == Gait.WALK:
			speed = maxf(speed, walk_min_speed())       # step off at the slowest no-slip walk
		_dwell = MIN_DWELL
		gait_changed.emit(old, g)


func _update_steer(delta: float) -> void:
	steer = move_toward(steer, _steer_in, steer_response * delta)
	var max_rate := max_yaw_rate(gait, speed)
	if one_shot == "rear" or airborne:
		max_rate = 0.0
	yaw_speed = steer * max_rate


## The clip the horse should show now: [clip, rate, full-stride weight].
func _wanted_clip() -> Array:
	if not one_shot.is_empty():
		return [one_shot, jump_rate if one_shot == "jump" else 1.0, 1.0]
	if gait == Gait.IDLE:
		if absf(steer) > 0.2:
			return ["turn_l" if steer > 0.0 else "turn_r", absf(steer), 1.0]
		return ["idle", 1.0, 1.0]
	var sw := stride_for(gait, speed)
	return [GAIT_CLIPS[gait], sw.y, sw.x]


func _advance_phase(delta: float) -> void:
	var w := _wanted_clip()
	var want: String = w[0]
	rate = w[1]
	stride_w = w[2]
	var fade := 0.0
	if want != clip:
		phase = _map_phase(clip, phase, want)
		clip = want
		fade = GAIT_FADE
	var L := clip_length(clip)
	if not one_shot.is_empty():
		one_shot_time += delta * rate
		phase = clampf(one_shot_time / L, 0.0, 1.0)
		if one_shot == "jump":
			_jump_flight()
		if one_shot_time >= L:
			var done := one_shot
			one_shot = ""
			one_shot_finished.emit(done)
	else:
		phase = fposmod(phase + delta * rate / L, 1.0)
	if clip == "idle":
		idle_phase = phase
	elif clip.begins_with("turn"):
		idle_phase = fposmod(idle_phase + delta / clip_length("idle"), 1.0)
	var gi := GAIT_CLIPS.find(clip)
	var short: String = SHORT_CLIPS[gi] if gi > 0 else ""
	# curvature: the curved variants are baked on a circle of radius R at their own speed, so
	# the weight that matches the yaw rate is yaw rate x R / speed, whatever the stride blend
	# and the playback rate
	curve = 0.0
	var R := curve_radius(clip) if gi > 0 else 0.0
	if R > 0.0 and speed > 0.05:
		curve = clampf(yaw_speed * R / speed, -1.0, 1.0)
	blender.show_clip(clip, phase * L, fade, rate, short, 1.0 - stride_w if not short.is_empty() else 0.0, curve)


## Phase in `to` that keeps the footfalls: the left-hind touchdown of both clips aligned.
func _map_phase(from: String, p: float, to: String) -> float:
	if to == "idle":
		return idle_phase
	var cf: Dictionary = meta.get("clips", {}).get(from, {})
	var ct: Dictionary = meta.get("clips", {}).get(to, {})
	if not cf.has("touchdown_phase") or not ct.has("touchdown_phase"):
		return 0.0
	var nf := float(cf.get("strides", 1))
	var nt := float(ct.get("strides", 1))
	var since_lh := fposmod(p * nf - float(cf.touchdown_phase.LH), 1.0)
	return fposmod((float(ct.touchdown_phase.LH) + since_lh) / nt, 1.0)


func _start_one_shot(c: String) -> void:
	one_shot = c
	one_shot_time = 0.0


# ---------------------------------------------------------------------------
# Jump
# ---------------------------------------------------------------------------
## Distance from the root to the first obstacle straight ahead (m), or INF.
func obstacle_distance() -> float:
	_jump_ray.force_raycast_update()
	if not _jump_ray.is_colliding():
		return INF
	var p := _jump_ray.get_collision_point()
	var d := p - global_position
	return Vector2(d.x, d.z).dot(Vector2(-global_basis.z.x, -global_basis.z.z))


## Take-off window for playback rate r: [earliest, best, latest] distance from the root at
## the jump start to a rail (meta clearance table: best_x and the 0.6 m rail window).
func jump_window(r: float) -> Vector3:
	var cl: Dictionary = meta.get("clips", {}).get("jump", {}).get("clearance", {})
	var best := 4.55
	var lo := 3.4
	var hi := 6.4
	var bd := INF
	for k: String in cl:
		var d := absf(float(k) - r)
		if d < bd:
			bd = d
			best = float(cl[k].get("best_x", best))
			var w = cl[k].get("window_060")
			if w is Array and w.size() == 2:
				lo = float(w[0])
				hi = float(w[1])
	return Vector3(lo, best, hi)


func _try_start_jump() -> void:
	if not one_shot.is_empty() or gait < Gait.CANTER:
		return
	var vj := clip_speed("jump")
	var r := clampf(speed / maxf(vj, 0.1), JUMP_RATE.x, JUMP_RATE.y)
	var d := obstacle_distance()
	var win := jump_window(r)
	var in_band := absf(speed - r * vj) < 0.3
	# no obstacle within reach: jump when the speed is in the band (or when the hold ends)
	var go := false
	if d == INF:
		go = in_band or _jump_pending <= 0.0
	elif d <= win.y + 0.15:
		go = true                                    # at (or past) the best take-off point
	elif _jump_pending <= 0.0:
		go = true
	if not go:
		return
	_jump_pending = 0.0
	jump_rate = r
	# no speed jump: any difference to r x vj is taken up over the approach strides
	# (_update_speed, before the take-off)
	_start_one_shot("jump")


## Drives the root through the jump: launch at the clip's take-off time, ballistic flight,
## landing at its landing time (or earlier / later on uneven ground).
func _jump_flight() -> void:
	var j: Dictionary = meta.get("clips", {}).get("jump", {})
	var t0 := float(j.get("takeoff_time", 0.37))
	if not airborne and one_shot_time >= t0 and one_shot_time < float(j.get("landing_time", 0.84)) and is_on_floor():
		airborne = true
		velocity.y = float(j.get("launch_speed_rate1", 2.3)) / jump_rate
		floor_snap_length = 0.0
		jumped.emit(global_position)


func _land() -> void:
	airborne = false
	velocity.y = 0.0
	floor_snap_length = 0.5
	landed.emit(global_position)


func _update_vertical(delta: float) -> void:
	if airborne:
		velocity.y -= gravity * delta
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# along the ground: the horizontal speed stays the gait's no-slip speed on a slope too
		var n := get_floor_normal()
		velocity.y = -(n.x * velocity.x + n.z * velocity.z) / maxf(n.y, 0.3)


## The collision shapes follow the body and the legs: the body box rides with the body
## bone, the feet sphere rises with the lowest hoof (tucked legs clear a fence).
func _update_collision() -> void:
	if _body_shape == null:
		return
	var gy := skeleton.global_transform
	var rest_b := skeleton.get_bone_global_rest(_body_bone)
	var now_b := skeleton.get_bone_global_pose(_body_bone)
	# the body box rises, sinks and pitches with the body (model x = body x)
	var rel := now_b * rest_b.affine_inverse()
	var c: Dictionary = meta.get("collision", {})
	var ce: Array = c.get("box_center", [0.0, 1.025, 0.07])
	var centre_model := rel * Vector3(float(ce[0]), float(ce[1]), float(ce[2]))
	_body_shape.position = Vector3(-centre_model.x, centre_model.y, -centre_model.z)
	var pitch := atan2(rel.basis.z.y, rel.basis.z.z)
	_body_shape.rotation = Vector3(pitch, 0.0, 0.0)
	# only in the jump's flight: in the gaits the feet sphere must keep carrying the horse
	# on the ground through the suspension phases
	var low := 0.0
	if airborne:
		low = INF
		for b in _hoof_bones:
			low = minf(low, (gy * skeleton.get_bone_global_pose(b).origin).y - global_position.y)
		low = maxf(low - 0.06, 0.0)            # hoof sole below the coronet joint
	_feet_shape.position.y = _feet_r + low


# ---------------------------------------------------------------------------
# Pose additives: neck bend into turns
# ---------------------------------------------------------------------------
func _post_pose() -> void:
	var max_rate := max_yaw_rate(gait, speed)
	var k := 0.0
	if max_rate > 1e-3 and not clip.begins_with("turn") and one_shot.is_empty():
		k = clampf(yaw_speed / max_rate, -1.0, 1.0)
	if absf(k) < 1e-3:
		return
	var shares := [0.3, 0.3, 0.25, 0.15]
	for i in _neck_bones.size():
		var b := _neck_bones[i]
		if b < 0:
			continue
		var q := skeleton.get_bone_pose_rotation(b)
		# model space: +x is the horse's left; a left turn bends the neck left about the
		# bone's up axis in model space
		var parent := skeleton.get_bone_parent(b)
		var pg := skeleton.get_bone_global_pose(parent).basis
		var axis := (pg.inverse() * Vector3.UP).normalized()
		skeleton.set_bone_pose_rotation(b, Quaternion(axis, deg_to_rad(TURN_BEND) * k * shares[i]) * q)


# ---------------------------------------------------------------------------
# Reins: two sagging leather strips from the bit rings to the rider's hands (or to the
# pommel when nobody rides).
# ---------------------------------------------------------------------------
func set_rein_targets(targets: Array) -> void:
	_rein_targets = targets


func _build_reins() -> void:
	_rein_mesh = ImmediateMesh.new()
	_reins = MeshInstance3D.new()
	_reins.name = "Reins"
	_reins.mesh = _rein_mesh
	_reins.top_level = true
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.10, 0.06)
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_reins.material_override = m
	add_child(_reins)


func _update_reins() -> void:
	if _rein_mesh == null:
		return
	_rein_mesh.clear_surfaces()
	var head := get_bone_global("head")
	var hb := skeleton.get_bone_global_rest(skeleton.find_bone("head"))
	var socks: Dictionary = meta.get("sockets", {})
	var ends := []
	for key in ["rein_l", "rein_r"]:
		var a: Array = socks.get(key, [0.068, 1.19, 1.475])
		var local_rest := Vector3(a[0], a[1], a[2])
		ends.append(head * (hb.affine_inverse() * local_rest))
	var targets := _rein_targets
	if targets.size() < 2:
		var sad := get_saddle_transform()
		targets = [sad * Vector3(0.07, -0.06, 0.22), sad * Vector3(-0.07, -0.06, 0.22)]
	_rein_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 2:
		_strip(ends[i], targets[i])
	_rein_mesh.surface_end()


func _strip(a: Vector3, b: Vector3) -> void:
	var n := 10
	var sag := clampf(0.12 - 0.1 * (a.distance_to(b) - 0.6), 0.02, 0.12)
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var w := 0.009
	for i in n:
		var d := (pts[i + 1] - pts[i]).normalized()
		var side := d.cross(Vector3.UP).normalized() * w
		if side.length() < 1e-4:
			side = Vector3.RIGHT * w
		var up := d.cross(side).normalized() * 0.003
		for q in [[side, up], [up, -side]]:
			var s0: Vector3 = q[0]
			var p0 := pts[i] - s0
			var p1 := pts[i] + s0
			var p2 := pts[i + 1] + s0
			var p3 := pts[i + 1] - s0
			for v in [p0, p1, p2, p0, p2, p3]:
				_rein_mesh.surface_add_vertex(v)
