class_name BendStatus
extends RefCounted
## What a bent element does to whom it reaches (BendEffects, BendBolt, BendZone): hurts (Hit.deliver as a blunt blow: all of
## it now, no wound to bleed), knocks back (the player off his feet when it is hard, a fighter shoved), roots, slows, and the
## caster's own guards (anchor: no knockback). Timed effects are kept as metas with their end (ends_at) and undone when they
## run out, only when still the bend's own (a duel's countdown hold or a wheelbarrow's cap is left alone).

## A knock this hard (m/s) or more throws the player off his feet; under it he is pushed.
const KNOCK_DOWN_MPS := 9.0
## A slowed man's pace (m/s).
const SLOW_MPS := 1.6


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Whom the bend can reach: the player and fighters (not dead), the wild, props; not `caster`.
static func can_take(n: Node, caster: Node) -> bool:
	if n == null or not is_instance_valid(n) or n == caster:
		return false
	if n is FrontierPlayer:
		return not (n as FrontierPlayer).is_dead
	if n is NpcFighter:
		return not (n as NpcFighter).is_dead()
	if n is WildAnimal:
		return not (n as WildAnimal).is_dead()
	return n is RigidBody3D and not (n is FormStone)


## Everyone within `r` of `at` (flat, and within 3 m up or down) the bend can reach: [node, flat distance].
static func near(caster: Node, at: Vector3, r: float) -> Array:
	var out: Array = []
	var tree := caster.get_tree() if caster != null and caster.is_inside_tree() else null
	if tree == null:
		return out
	var pool: Array = []
	pool.append_array(tree.get_nodes_in_group(NpcFighter.GROUP))
	pool.append_array(tree.get_nodes_in_group(&"players"))
	var p := tree.current_scene.get_node_or_null("Player") if tree.current_scene else null
	if p != null and not pool.has(p):
		pool.append(p)
	for n in pool:
		if not can_take(n, caster):
			continue
		var q := (n as Node3D).global_position
		var d := Vector2(q.x - at.x, q.z - at.z).length()
		if d <= r and absf(q.y - at.y) < 3.0:
			out.append([n, d])
	return out


## `dmg` to `n` from `by` at `at` going `dir`: a blunt blow (no anatomy wound; the striker's damage_kind meta for the hit).
static func hurt(n: Node, dmg: float, at: Vector3, dir: Vector3, by: Node) -> void:
	if dmg <= 0.0 or not can_take(n, by):
		return
	var had: Variant = by.get_meta(&"damage_kind") if by != null and by.has_meta(&"damage_kind") else null
	if by != null:
		by.set_meta(&"damage_kind", "blunt")
	if n.has_method(&"apply_hit"):
		n.apply_hit(dmg, at, dir, by, "body")
	if by != null and is_instance_valid(by):
		if had == null:
			by.remove_meta(&"damage_kind")
		else:
			by.set_meta(&"damage_kind", had)


## `n` knocked along `v` (m/s; its up part lifts the player) by `by`. An anchored one (anchor) is not moved.
static func knock(n: Node, v: Vector3, by: Node) -> void:
	if v.length_squared() < 1e-4 or not can_take(n, by) or until(n, &"bend_anchor") > 0.0:
		return
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		if v.length() >= KNOCK_DOWN_MPS and p.knock_down(v):
			return
		p.velocity += v
	elif n is NpcFighter:
		SwayEffects.shove_fighter(n as NpcFighter, Vector3(v.x, 0.0, v.z), by)
		if v.y > 4.0 and (n as NpcFighter).is_on_floor():
			(n as NpcFighter).velocity.y = v.y * 0.6
	elif n is WildAnimal:
		SwayEffects.shove_animal(n as WildAnimal, Vector3(v.x, 0.0, v.z), (by as Node3D).global_position if by is Node3D else Vector3.ZERO)
	elif n is RigidBody3D:
		SwayEffects.push_prop(n as RigidBody3D, v, (n as Node3D).global_position, 400.0)


## Seconds left of timed effect `key` on `n` (0: none).
static func until(n: Node, key: StringName) -> float:
	if n == null or not is_instance_valid(n) or not n.has_meta(key):
		return 0.0
	return maxf(float(n.get_meta(key)) - now(), 0.0)


## `n` held where it stands for `s` (the player can't move; a fighter's mind still, NpcFighter.held).
static func root(n: Node, s: float) -> void:
	_timed(n, &"bend_root", s, 0.0)


## `n` slowed to SLOW_MPS for `s`.
static func slow(n: Node, s: float) -> void:
	_timed(n, &"bend_slow", s, SLOW_MPS)


## The caster can't be knocked back for `s`.
static func anchor(n: Node, s: float) -> void:
	if n != null:
		n.set_meta(&"bend_anchor", now() + s)


## A little health back (the player's, a fighter's), up to its most.
static func heal(n: Node, amount: float) -> void:
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		p.health = minf(p.health + amount, p.max_health)
	elif n is NpcFighter:
		var f := n as NpcFighter
		f.health = minf(f.health + amount, f.health_max)


static func _timed(n: Node, key: StringName, s: float, cap: float) -> void:
	if not can_take(n, null) or s <= 0.0:
		return
	var end := now() + s
	n.set_meta(key, maxf(end, float(n.get_meta(key, 0.0))))
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		if p.drag_speed_cap > cap:
			p.drag_speed_cap = cap
	elif n is NpcFighter:
		var f := n as NpcFighter
		if key == &"bend_root":
			if not f.held:
				f.held = true
				f.set_meta(&"bend_held", true)
		else:
			if not f.has_meta(&"bend_limp"):
				f.set_meta(&"bend_limp", f.limp)        # (his own limp, a broken leg's, back after)
			f.limp = minf(f.limp, 0.6)
	n.get_tree().create_timer(s + 0.02, false).timeout.connect(_end_timed.bind(n, key, cap))


static func _end_timed(n: Node, key: StringName, cap: float) -> void:
	if n == null or not is_instance_valid(n) or until(n, key) > 0.0:
		return
	n.remove_meta(key)
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		if is_equal_approx(p.drag_speed_cap, cap):
			p.drag_speed_cap = INF if until(n, &"bend_root") <= 0.0 and until(n, &"bend_slow") <= 0.0 else p.drag_speed_cap
	elif n is NpcFighter:
		var f := n as NpcFighter
		if key == &"bend_root" and f.has_meta(&"bend_held"):
			f.remove_meta(&"bend_held")
			f.held = false
		elif key == &"bend_slow" and f.has_meta(&"bend_limp"):
			f.limp = float(f.get_meta(&"bend_limp"))
			f.remove_meta(&"bend_limp")
