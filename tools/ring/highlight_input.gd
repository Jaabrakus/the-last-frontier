extends "res://tools/ring/newcomer_sim.gd"
## Film player: ordinary Full-control key/mouse inputs, with varied attacks and
## space for finishers. No fighter state or combat values are written here.

var attack_n := 0
var finishers := 0
var _attack_at := 0.0
var _second_at := -1.0
var camera_aim := true


func _mouse(foe: Node3D, dt: float) -> void:
	if not camera_aim:
		super._mouse(foe, dt)
		return
	# Place the actual crosshair on the opponent as a mouse player would. The
	# newcomer's body-origin estimate aims above close targets with the high camera.
	var to := foe.global_position + Vector3.UP * 1.1 - player.camera.global_position
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, maxf(Vector2(to.x, to.z).length(), 0.1))
	var k := 1.0 - exp(-8.0 * dt)
	player.yaw += wrapf(want_yaw - player.yaw, -PI, PI) * k
	player.pitch = lerpf(player.pitch, clampf(want_pitch, -1.2, 1.2), k)


func _feet(foe: Node3D) -> void:
	var d := _flat_d(foe)
	var pct := mode.rules.pct_of(foe)
	var wanted := 5.0 if pct >= 65.0 else 3.0
	var caster := SwayCaster.of(player)
	var commit := caster != null and caster.state != SwayCaster.State.IDLE
	var foe_moves := RingMoves.of(foe)
	var away := foe_moves != null and foe_moves.off_deck()
	var g := RingMoves.arena_geo(mode.ring)
	var local: Vector3 = (g.xf as Transform3D).affine_inverse() * player.global_position
	var near_edge := absf(local.x) > float(g.hl) - 1.6 or absf(local.z) > float(g.hw) - 1.2
	_hold(&"move_forward", not commit and not away and not near_edge and d > wanted + 0.6)
	_hold(&"move_back", not commit and d < wanted - 0.5 and not near_edge)
	_hold(&"move_left", false)
	_hold(&"move_right", false)


func _hands(foe: Node3D) -> void:
	if _second_at > 0.0:
		if _t >= _second_at:
			_second_at = -1.0
			_key(&"weapon_1")
			_tap(&"aim", 0.08)
		return
	if _t < _attack_at:
		return
	var caster := SwayCaster.of(player)
	if caster == null or caster.state != SwayCaster.State.IDLE or player.controls.pressed(&"aim"):
		return
	var pct := mode.rules.pct_of(foe)
	var close := _flat_d(foe) < 3.8
	var finishing := pct >= 65.0
	attack_n += 1
	if not finishing and close and attack_n % 4 in [0, 1]:
		_tap(&"fire", 0.06)
		clicks += 1
		_attack_at = _t + 0.45
		return
	var el := String(player.arena_element)
	var secondary := (finishing and attack_n % 2 == 0) or attack_n % 5 == 0
	var push := attack_n % 2 == 1
	var hold := 0.08
	if finishing:
		finishers += 1
		# Full controls: key1 twice selects Wind Ball/Boulder/Spear. Fire's
		# first strike grows into Fireball when right-click stays held.
		if el == "fire":
			push = false
			secondary = false
			hold = 1.65
		elif push:
			hold = 1.65
	_key(&"weapon_2" if push else &"weapon_1")
	if not push and secondary:
		_second_at = _t + 0.10
	else:
		_tap(&"aim", hold)
	casts += 1
	_attack_at = _t + (2.0 if hold > 1.0 else 1.35)


func _guard(foe: Node3D) -> void:
	# Commit to the chosen cast instead of cancelling each charge to guard.
	if player.controls.pressed(&"aim") or _second_at > 0.0:
		return
	super._guard(foe)
