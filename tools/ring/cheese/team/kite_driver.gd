extends "res://tools/ring/cheese/team/team_driver.gd"
## Cheese hunt, lens "team": the player who RUNS (way=kite): never attacks, keeps away from every opponent in play (of 16
## ways on the deck, the one whose point 2.5 m on stays farthest from the nearest of them, never within 3.5 m of a lip nor
## into a raised piece), his camera on the nearest one, his guard (E) on what flies at him, his dash (3) when one comes within
## 4.5 m. His team-mates fight; he keeps his lives for the bell (more lives wins). Key and mouse actions only; his recovery is
## the expert's. Books: alone_s (seconds he was his side's last one in), near_min (the closest any opponent came, m).

var alone_s := 0.0
var near_min := INF
var _dash_t := -INF
var _pick_t := 0.0
var _way := Vector3.ZERO


func _physics_process(dt: float) -> void:
	if way != "kite":
		super._physics_process(dt)
		return
	_t += dt
	if player == null or not is_instance_valid(player) or mode == null or not is_instance_valid(mode):
		return
	_hook()
	_untap()
	if mode.phase != "FIGHT":
		_let_go()
		_launch = {}
		return
	var rm := RingMoves.of(player)
	if rm == null or (_rules != null and _rules.is_away(player)):
		_let_go()
		return
	var mates_in := 0
	for b in mode.rules.sides[0]:
		if b != player and is_instance_valid(b) and not mode.rules.is_gone(b as Node):
			mates_in += 1
	if mates_in == 0:
		alone_s += dt
	_books(rm)
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	_hold(&"jump", false)
	var foe := _pick()
	target = foe
	if foe == null:
		_hold_world(Vector3.ZERO)
		return
	_mouse(foe, dt)
	_guard(foe)
	var d_near := _flat_d(foe)
	near_min = minf(near_min, d_near)
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 0.2
		_way = _flee_way()
	_hold_world(_way)
	if d_near < 4.5 and _t - _dash_t > 1.5 and _way != Vector3.ZERO:
		_dash_t = _t
		_key(&"weapon_3")


## The flat world way (unit) of the 16 whose point 2.5 m on is farthest from the nearest opponent in play, kept 3.5 m inside
## every lip and off the raised pieces (ZERO: staying is best).
func _flee_way() -> Vector3:
	var ring := mode.ring
	var me := ring.to_local(player.global_position)
	var foes: Array[Vector2] = []
	for o in mode.rules.sides[1]:
		if o is Node3D and is_instance_valid(o) and mode.in_play(o):
			var l := ring.to_local((o as Node3D).global_position)
			foes.append(Vector2(l.x, l.z))
	if foes.is_empty():
		return Vector3.ZERO
	var best_score := _score(Vector2(me.x, me.z), foes)
	var best := Vector2.ZERO
	for i in 16:
		var a := TAU * float(i) / 16.0
		var dv := Vector2(cos(a), sin(a))
		var q := Vector2(me.x, me.z) + dv * 2.5
		var sc := _score(q, foes)
		if sc > best_score + 0.2:
			best_score = sc
			best = dv
	if best == Vector2.ZERO:
		return Vector3.ZERO
	var w := ring.global_basis * Vector3(best.x, 0.0, best.y)
	w.y = 0.0
	return w.normalized()


func _score(q: Vector2, foes: Array[Vector2]) -> float:
	var ring := mode.ring
	var near := INF
	for f in foes:
		near = minf(near, q.distance_to(f))
	var lip := minf(ring.half_l() - absf(q.x), ring.half_w() - absf(q.y))
	var s := near
	if lip < 3.5:
		s -= (3.5 - lip) * 6.0
	if not ring.piece_at(ring.to_global(Vector3(q.x, 0.0, q.y)), 0.8).is_empty():
		s -= 20.0
	return s
