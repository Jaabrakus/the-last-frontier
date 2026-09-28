class_name ThrowableAtlatl
extends Throwable
## Atlatl (spear-thrower) with darts: a special, legendary item. The atlatl is
## anachronistic for the 1750s eastern woodlands; there it had given way to the bow
## more than a thousand years earlier (Late Woodland, c. 500-1000 CE; design doc
## section 1). In the game it is an heirloom or relic weapon, not period kit.
##
## The board stays in the hand; a dart lies along it with its butt in the hook
## (Spur). The cast is an overhand throw ending in a wrist flick that swings the hook
## end up and over, which is where the extra speed comes from: darts leave at up to
## ~32 m/s (measured atlatl darts mostly stay under 35 m/s), flatter and farther than
## a hand-thrown spear. Five darts are carried; fitting the next one takes a second.

@export var flick_deg := 100.0

## The dart lying on the board (hidden once it is thrown).
var dart: Node3D


func _init() -> void:
	super()
	display_name = "Atlatl (legendary)"
	ammo_kind = "atlatl_dart"
	model_kind = "atlatl"
	projectile_kind = "atlatl_dart"
	equip_time = 0.5
	move_speed_mult = 1.0
	windup_time = 0.6
	min_windup = 0.15
	release_time = 0.26
	follow_time = 0.572        # release_time * 2.2 (Throwable.throw_anim_rate).
	draw_time = 1.0
	min_speed = 18.0
	max_speed = 32.0
	flight_gravity = 9.8
	flight_drag = 0.008
	min_damage = 70.0         # THROW2: the atlatl dart out-damages the spear (60-130); = data/weapons/ballistics.json
	max_damage = 150.0
	count = 5
	max_count = 5
	spread_base = 0.3
	spread_move = 3.0
	spread_undercharge = 3.0
	carry_rot_deg = Vector3(-35.0, 0.0, 0.0)   # Board and dart angled down along the leg.
	aim_tilt_deg = 0.0
	clips["draw"] = "actor_b-p-bow-reload--part"          # Reach back for a dart, fit it to the hook.
	clips["equip"] = "actor_b-p-bow-draw-grab^idle--part"


func _configure_projectile(p: ThrownProjectile, _origin: Vector3, _dir: Vector3, _speed: float) -> void:
	p.flight = ThrownProjectile.Flight.POINT_FIRST
	p.stick_speed = 6.0
	p.stick_depth = 0.12
	p.stick_depth_wood = 0.05        # Stone point: a shallow bite in timber.
	p.stick_max_incidence_deg = 68.0
	p.blunt_damage = 8.0
	p.whoosh_pitch = 0.75
	p.impact_gain = 2.0


func _setup_model() -> void:
	if dart != null or model == null:
		return
	dart = ThrowableModels.build("atlatl_dart")
	dart.name = "LoadedDart"
	model.add_child(dart)
	dart.top_level = true
	dart.visible = false


func _thrown_node() -> Node3D:
	return dart


## The board stays in the hand with no dart on it: a switch always holsters it.
func holster_shows_model() -> bool:
	return true


## The board stays in a dead player's hand, like the firearms (the dart is hidden with the weapon put away).
func death_shows_model() -> bool:
	return true


## The hook end swings up and over in the last part of the cast (a whip, so the
## angle grows with the square of the progress).
func _release_swing_deg(u: float) -> float:
	var k := clampf(u, 0.0, 1.0)
	return -flick_deg * k * k


func _update_visibility() -> void:
	if model:
		model.visible = active
	if dart:
		dart.visible = active and _object_in_hand()


## The dart is seated rigidly on the board: same axes as the atlatl (both -Z forward,
## +Y up), Nock on the Spur, no relative rotation, so it cannot hinge into the grip or
## the bannerstone (the seated gap is only ~3 mm) while the board is raised, lowered or
## rolled by the hand. Only during the release flick does it keep its own line: the board
## swings hook-up-and-over about the hand while the dart, pushed by the hook, stays on the
## throw line (the flick is undone for the dart, so the two separate, never intersect).
func _place_held() -> void:
	super()
	if dart == null or model == null or not active or not model.is_inside_tree():
		return
	var spur := model.global_transform * ThrowableModels.marker_pos(model, "Spur")
	var b := model.global_basis.orthonormalized()
	if state == State.RELEASING:
		var swing := _release_swing_deg(1.0 - _phase_left / maxf(_phase_len, 1e-3)) * clampf(aim, 0.0, 1.0)
		if swing != 0.0:
			# Same axis Throwable._place_held tilts the aimed pose about.
			var cb := _char_basis()
			var d := _aim_dir if _aim_dir.length_squared() > 0.5 else -cb.z
			var right := d.cross(Vector3.UP)
			right = right.normalized() if right.length_squared() > 1e-4 else cb.x
			b = Basis(right, deg_to_rad(-swing)) * b
	var nock := ThrowableModels.marker_pos(dart, "Nock")
	# Dart space: tip at the origin, nock at +Z; put the nock on the hook.
	dart.global_transform = Transform3D(b, spur - b * nock)
