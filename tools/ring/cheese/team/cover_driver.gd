extends "res://tools/ring/cheese/team/team_driver.gd"
## Cheese hunt, lens "team": the player who fights from behind a broken wall of the Ruins (way=cover): of the raised pieces
## of kind "wall" (and the pillar), the one nearest to him on his own half; he stands 1.4 m behind it on the side away from
## the nearest opponent in play (re-picked every 0.5 s, round the wall's ends as it turns), and casts as the expert does only
## when the line from his chest to that opponent's clears the piece (he steps out to see him past an end), his guard (E) on
## what flies at him. Key and mouse actions only. Books: cover_s (seconds behind a piece with an opponent's line through it),
## shots_clear (casts begun with a clear line).

var cover_s := 0.0
var shots_clear := 0
var _spot := Vector2.INF
var _spot_t := 0.0
var _piece := {}


func _physics_process(dt: float) -> void:
	if way != "cover":
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
	_spot_t -= dt
	if _spot_t <= 0.0 or _spot == Vector2.INF:
		_spot_t = 0.5
		_choose(foe)
	var blocked := _blocked(foe)
	if blocked:
		cover_s += dt
	var sc := SwayCaster.of(player)
	var locking := sc != null and sc.state != SwayCaster.State.IDLE
	if not locking:
		_walk_to(_spot, 0.35)
	else:
		_hold_world(Vector3.ZERO)
	if not blocked:
		var before := casts + clicks
		_hands(foe)
		if casts + clicks > before:
			shots_clear += 1


## The piece and the spot behind it (away from `foe`).
func _choose(foe: Node3D) -> void:
	var ring := mode.ring
	var me := ring.to_local(player.global_position)
	var f := ring.to_local(foe.global_position)
	var sg := RingArena.side_sign(mode.player_end)
	var best := {}
	var bd := INF
	for pc: Dictionary in ring.pieces():
		if not String(pc.kind) in ["wall", "pillar"]:
			continue
		var c: Vector2 = (pc.rect as Rect2).get_center()
		if signf(c.x) != sg:
			continue
		var d := Vector2(me.x, me.z).distance_to(c)
		if d < bd:
			bd = d
			best = pc
	_piece = best
	if best.is_empty():
		_spot = Vector2(me.x, me.z)
		return
	var r: Rect2 = best.rect
	var c2 := r.get_center()
	var away := (c2 - Vector2(f.x, f.z)).normalized()
	var half := maxf(r.size.x, r.size.y) * 0.5
	var spot := c2 + away * (minf(r.size.x, r.size.y) * 0.5 + 1.4)
	# (a long wall: stay behind its middle; the spot kept on the deck, 2 m in from every lip)
	spot.x = clampf(spot.x, -ring.half_l() + 2.0, ring.half_l() - 2.0)
	spot.y = clampf(spot.y, -ring.half_w() + 2.0, ring.half_w() - 2.0)
	if half < 0.0:
		spot = c2
	_spot = spot


## Whether the piece stands in the line from his chest to `foe`'s (flat, and lower than the piece's top).
func _blocked(foe: Node3D) -> bool:
	if _piece.is_empty():
		return false
	var ring := mode.ring
	var a := ring.to_local(player.global_position)
	var b := ring.to_local(foe.global_position)
	if float(_piece.h) < 1.3:
		return false
	return _seg_hits(Vector2(a.x, a.z), Vector2(b.x, b.z), (_piece.rect as Rect2).grow(0.15))
