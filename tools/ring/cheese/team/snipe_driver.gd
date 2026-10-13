extends "res://tools/ring/cheese/team/team_driver.gd"
## Cheese hunt, lens "team": the fire player who only snipes with Lightning (key 1 tapped twice, then a right click: the
## lock fills and it goes), from his own end, keeping away from the fight (team_driver.gd's expert otherwise: his mouse, his
## recovery, his guard when nothing is charging). Key and mouse actions only.
##   snipe       at the opponent in play who is NOT on him (a bot whose coached target is someone else: busy with his
##               team-mate), the nearest such; when every one is on him, the nearest
##   snipe_any   at the nearest opponent in play, whoever he is on
## Books: lt (one entry a released Lightning: {t, watching: the target bot was on him at the release, d: metres}).

var lt: Array = []
var _ready_at := -1.0
var _click_at := -1.0
var _lt_tgt: Node3D = null
var _hooked := false
## The right button held through the lock (a charge he lets go when its bot stands still, or 0.5 s after it is full).
var _holding := false
var _hold_began := 0.0


func _physics_process(dt: float) -> void:
	if not way.begins_with("snipe"):
		super._physics_process(dt)
		return
	_t += dt
	if player == null or not is_instance_valid(player) or mode == null or not is_instance_valid(mode):
		return
	_hook()
	_hook_cast()
	_untap()
	if mode.phase != "FIGHT":
		_let_go()
		_launch = {}
		_ready_at = -1.0
		_click_at = -1.0
		_holding = false
		return
	var rm := RingMoves.of(player)
	if rm == null or (_rules != null and _rules.is_away(player)):
		_let_go()
		return
	_books(rm)
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_holding = false
		_thrown(rm)
		return
	_hold(&"jump", false)
	var foe := _snipe_pick()
	var sc := SwayCaster.of(player)
	if sc != null and sc.state != SwayCaster.State.IDLE and _lt_tgt != null and is_instance_valid(_lt_tgt) and mode.in_play(_lt_tgt):
		foe = _lt_tgt                     # (the charge stays on the bot it began on)
	target = foe
	if foe != null:
		_mouse(foe, dt)
	_snipe_feet(foe)
	_snipe_hands(foe)


func _hook_cast() -> void:
	if _hooked:
		return
	var sc := SwayCaster.of(player)
	if sc == null:
		return
	_hooked = true
	sc.cast_released.connect(func(m: String, md: String) -> void:
		if m != "fire_arc" or mode == null or mode.phase != "FIGHT":
			return
		var tg: Node3D = _lt_tgt if _lt_tgt != null and is_instance_valid(_lt_tgt) else null
		if tg == null and target != null and is_instance_valid(target):
			tg = target
		var watching := false
		var d := -1.0
		if tg != null and tg is NpcFighter and (tg as NpcFighter).brain != null:
			watching = (tg as NpcFighter).brain.target == player
		if tg != null and is_instance_valid(tg):
			d = player.global_position.distance_to(tg.global_position)
		lt.append({"t": snappedf(_t, 0.01), "watching": watching, "d": snappedf(d, 0.1), "md": md,
				"id": tg.get_instance_id() if tg != null and is_instance_valid(tg) else 0, "ally_in_line": _ally_in_line(tg)}))


## Whether a team-mate stands in the line from his chest to `tg`'s (within 0.6 m of it, between them).
func _ally_in_line(tg: Node3D) -> bool:
	if tg == null or not is_instance_valid(tg):
		return false
	var a := player.global_position + Vector3.UP * 1.3
	var b := tg.global_position + Vector3.UP * 1.1
	for m in mode.rules.sides[0]:
		if m == player or not (m is Node3D) or not is_instance_valid(m) or not mode.in_play(m):
			continue
		var c := (m as Node3D).global_position + Vector3.UP * 1.0
		var ab := b - a
		var k := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if k > 0.02 and k < 0.98 and (a + ab * k).distance_to(c) < 0.6:
			return true
	return false


## The bot he snipes (see the header).
func _snipe_pick() -> Node3D:
	var rules := mode.rules
	if rules == null:
		return null
	var best: Node3D = null
	var bd := INF
	var any_best: Node3D = null
	var any_d := INF
	for o in rules.sides[1]:
		if not (o is Node3D) or not is_instance_valid(o) or not mode.in_play(o) or rules.is_safe(o as Node):
			continue
		var d := player.global_position.distance_to((o as Node3D).global_position)
		if d > 42.0:
			continue
		if d < any_d:
			any_d = d
			any_best = o as Node3D
		var on_me := o is NpcFighter and (o as NpcFighter).brain != null and (o as NpcFighter).brain.target == player
		if not on_me and d < bd:
			bd = d
			best = o as Node3D
	if way == "snipe_any" or best == null:
		return any_best
	return best


## His feet: back at his own end (8 m in from its lip, on the middle line), away from anyone closer than 8 m.
func _snipe_feet(_foe: Node3D) -> void:
	var ring := mode.ring
	var sg := RingArena.side_sign(mode.player_end)
	var home := Vector2(sg * (ring.half_l() - 8.0), 0.0)
	var me := ring.to_local(player.global_position)
	var p := Vector2(me.x, me.z)
	var push := Vector2.ZERO
	for o in mode.rules.sides[1]:
		if not (o is Node3D) or not is_instance_valid(o) or not mode.in_play(o):
			continue
		var ol := ring.to_local((o as Node3D).global_position)
		var q := Vector2(ol.x, ol.z)
		if p.distance_to(q) < 8.0:
			push += (p - q).normalized() * (8.0 - p.distance_to(q))
	var sc := SwayCaster.of(player)
	var locking := sc != null and sc.state != SwayCaster.State.IDLE
	if push.length() > 0.5 and not locking:
		var goal := p + push.normalized() * 3.0
		goal.x = clampf(goal.x, -ring.half_l() + 3.0, ring.half_l() - 3.0)
		goal.y = clampf(goal.y, -ring.half_w() + 3.0, ring.half_w() - 3.0)
		_walk_to(goal, 0.2)
	elif not locking:
		_walk_to(home, 1.0)
	else:
		_hold_world(Vector3.ZERO)


## His hands: key 1, key 1 again (Lightning readied), a right click (the lock fills, it goes); again when it has gone.
func _snipe_hands(foe: Node3D) -> void:
	var sc := SwayCaster.of(player)
	if sc == null:
		return
	if _ready_at > 0.0:
		if _t >= _ready_at:
			_ready_at = -1.0
			_key(&"weapon_1")
			_click_at = _t + 0.12
		return
	if _holding:
		if sc.state == SwayCaster.State.FULL:
			var still := true
			if _lt_tgt != null and is_instance_valid(_lt_tgt) and _lt_tgt is CharacterBody3D:
				var v := (_lt_tgt as CharacterBody3D).velocity
				still = Vector2(v.x, v.z).length() < 1.2
			if still or sc.full_t >= 0.5:
				player.controls.set_held(&"aim", false)
				_holding = false
		elif sc.state == SwayCaster.State.IDLE and _t - _hold_began > 0.3:
			player.controls.set_held(&"aim", false)
			_holding = false
		return
	if _click_at > 0.0:
		if _t >= _click_at:
			_click_at = -1.0
			if foe != null and sc.state == SwayCaster.State.IDLE:
				_lt_tgt = foe
				player.controls.set_held(&"aim", true)
				_holding = true
				_hold_began = _t
				casts += 1
		return
	if foe == null or sc.state != SwayCaster.State.IDLE or _t < _attack_at:
		if foe != null and sc.state == SwayCaster.State.IDLE:
			_guard(foe)
		return
	_key(&"weapon_1")
	_ready_at = _t + 0.1
	_attack_at = _t + 0.6
