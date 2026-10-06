class_name RingArena
extends Node3D
## The Tidebreak ring (the owner, 2026-10-04: "switch to a elemental avatar the last airbender type of game", the sport named
## Tidebreak; docs/bending_design.md, "knockback wins. A hit pushes the enemy back through the three zones, and off the edge
## into the water wins the round"): a raised deck over a tank of water, every number in data/ring/ring.json. RingLevel
## (scenes/ring.tscn) puts it at the origin; the match (RingMode, RingRules) asks it where things are.
##   deck      deck_w x deck_l m, its top at deck_y, a solid stone plinth from there down to the tank's floor (so whatever
##             an earth move raises from under the deck rises inside stone, never seen from the water; under the ring-out
##             drop its foot stands plinth_out_m wider all round, so a wall raised at the very edge rises inside it too, its
##             rough stones and all). Each part of it is
##             its own layer-1 StaticBody3D (meta ring_deck, form_matter "earth": an Earth Wall raised from it has the
##             earth's strength; surface "stone" or "wood" for the footsteps, as the part is laid)
##   zones     the long axis is local X: side 0 at -X, side 1 at +X. The middle is a neutral strip neutral_m deep; behind it
##             each side has `zones` zones of zone_m. NO painted or lit lines (the owner, 2026-10-04: no marker of any kind;
##             "zones must read from the deck's own build"): each zone is laid in its own stone or wood (ring.json looks):
##             the neutral strip in pale sandstone slabs, zone 1 in honey planks across the deck, zone 2 in blue-grey slate
##             slabs, zone 3 in dark tarred planks along it; the change of stone or wood is the line
##   grates    grates_per_line iron grates over water on each zone line of each side (the lines between the neutral strip,
##             zone 1, zone 2 and zone 3), each a Node3D in Bending.POOLS (meta reach_m): a waterbender draws water there
##   ropes     three strands rope_h high on posts along both long sides, a solid rail behind them (StaticBody3D): the
##             open ends behind each side are the only way off
##   sockets   stones sitting in iron collars in the deck (ring.json sockets; open rules too), FormStone cannonballs in
##             FormStone.GROUP: Shove, Gust lift and the cushion have something to work on whatever the foe's element; one
##             taken away, another rises refill_s later; rebuild() puts every one back. A deck stone shoved or lifted flies
##             with ring.json sockets.hurl, not the open world's Gust numbers (_ring_hurls)
##   water     RingWater: the tank (its walls and floor, stone), its water, the splash of a fall into it, ring-out by water
##   round it  a flagged walk at the deck's height, timber stands of tiers along both long sides, a stone wall across each
##             end: our own fort kit (StructureMeshKit, StructureMaterials, the fort's own textures), so the eye stays in
##             the arena (headless: the colliders only, as the fort's structures)
## The API (world positions; side 0 or 1):
##   center(), axis() (unit, toward side 1), deck_y()
##   spawn(side, slot := 0) -> Transform3D   in the middle of zone spawn_zone, facing the centre (slots across the deck)
##   s_of(pos, side)                         metres back from the centre into that side (negative: on the other half)
##   zone_of(pos, side)                      0 the neutral strip (or the other half), 1..zones, zones + 1 past the end
##   line_s(side, k)                         the s of the line behind zone k (k 0: the neutral strip's edge; zones: the end)
##   on_deck(pos)                            over the deck and not dropped below it
##   is_out(pos)                             rung out: below deck_y - out_drop_m (in the tank), or out on the walk round it
##   is_ring_out(body)                       is_out at its position, or in the tank's water (RingWater.holds)
##   pools() -> Array[Node3D]                the grates
##   rect_for(side, min_zone, max_zone)      the deck from zone min_zone to max_zone (0 the neutral strip), up to 3 m
##                                           over it: AABB
##   rebuild()                               the round's reset: the stones back in their sockets
##   clear_dropped()                         what the fight left in the ring and the tank taken away (the count)
## ROUND 3 (smash_r3 spec §5, §7.2, §14.3; SEAMS, PERCENT's after):
##   nearest_lip(pos) -> {point, normal, out_m, side, along}   the deck's top outer rectangle's nearest edge (LIP_* side)
##   lip_y()                                 the lip's height (the deck top, world)
##   spout_at(side, slot) -> Vector3         where a respawn spout rises: the grate on that end's last grate line (s 12 m)
##   wall_place_ok(pos) -> Vector3           a wall's place kept off the lip (as given until PERCENT clamps it)

const DATA_PATH := "res://data/ring/ring.json"
const GROUP := &"ring_arena"
## Meta on each deck body (its part: "neutral", "s0_z1" ...).
const DECK_META := &"ring_deck"
## nearest_lip's sides: the open end at -X (side 0's), at +X (side 1's), the long side at -Z, at +Z.
const LIP_END_0 := 0
const LIP_END_1 := 1
const LIP_LONG_NEG := 2
const LIP_LONG_POS := 3
## What clear_dropped takes away reaches this far past the tank (m).
const CLEAR_MARGIN := 4.0
## On a GustLift flight once _ring_hurls has looked at it.
const RING_HURL_META := &"ring_hurl"

static var _data := {}

var visuals := true
var water: RingWater
var decks: Array[StaticBody3D] = []
var grates: Array[Node3D] = []
## [{at: Vector3 (world, on the deck), stone: FormStone or null, wait: s until one rises again}]
var sockets: Array[Dictionary] = []
var mats := {}
var _stones: Node3D


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = d if d is Dictionary else {}
	return _data


static func num(key: String, def := 0.0) -> float:
	return float(data().get(key, def))


static func make(parent: Node, xf := Transform3D.IDENTITY) -> RingArena:
	var a := RingArena.new()
	a.name = "RingArena"
	a.transform = xf
	parent.add_child(a)
	return a


static func find(tree: SceneTree) -> RingArena:
	return tree.get_first_node_in_group(GROUP) as RingArena if tree != null else null


func _ready() -> void:
	add_to_group(GROUP)
	visuals = DisplayServer.get_name() != "headless"
	if visuals:
		_materials()
	_stones = Node3D.new()
	_stones.name = "Stones"
	add_child(_stones)
	_deck()
	_ropes()
	_grates()
	_collars()
	_surround()
	water = RingWater.new()
	water.name = "RingWater"
	add_child(water)
	water.setup(self)
	_catch_floor()
	rebuild()


func _exit_tree() -> void:
	mats.clear()


# ---------------------------------------------------------------- the numbers
func half_l() -> float:
	return num("deck_l", 34.0) * 0.5


func half_w() -> float:
	return num("deck_w", 14.0) * 0.5


func top() -> float:
	return num("deck_y", 0.0)


## The plinth's foot (under plinth_step_y), half its length and width (local): the deck's and plinth_out_m more. Its
## step is below the ring-out drop, so a body come to rest on it is out; an earth move raised at the deck's very edge rises
## inside it.
func foot_half() -> Vector2:
	var po := num("plinth_out_m", 0.18)
	return Vector2(half_l() + po, half_w() + po)


## The tank's inside, half its length and width (local).
func tank_half() -> Vector2:
	var m := num("tank_margin", 6.0)
	return Vector2(half_l() + m, half_w() + m)


static func side_sign(side: int) -> float:
	return -1.0 if side % 2 == 0 else 1.0


# ---------------------------------------------------------------- the API
func center() -> Vector3:
	return to_global(Vector3(0.0, top(), 0.0))


func axis() -> Vector3:
	return global_basis.x.normalized()


func deck_y() -> float:
	return center().y


func spawn(side: int, slot := 0) -> Transform3D:
	var sg := side_sign(side)
	var s := num("neutral_m", 4.0) * 0.5 + num("zone_m", 5.0) * (num("spawn_zone", 1.0) - 0.5)
	var slots: Array = data().get("slot_z", [0.0])
	var z := float(slots[posmod(slot, slots.size())]) if not slots.is_empty() else 0.0
	var at := to_global(Vector3(sg * s, top(), z))
	var face := global_basis * Vector3(-sg, 0.0, 0.0)
	return Transform3D(Basis.looking_at(Vector3(face.x, 0.0, face.z).normalized(), Vector3.UP), at)


func s_of(pos: Vector3, side: int) -> float:
	return to_local(pos).x * side_sign(side)


func zone_of(pos: Vector3, side: int) -> int:
	var s := s_of(pos, side)
	var h := num("neutral_m", 4.0) * 0.5
	if s <= h:
		return 0
	var n := int(num("zones", 3.0))
	return mini(ceili((s - h) / num("zone_m", 5.0)), n + 1)


func line_s(_side: int, k: int) -> float:
	return num("neutral_m", 4.0) * 0.5 + num("zone_m", 5.0) * float(k)


func on_deck(pos: Vector3) -> bool:
	var l := to_local(pos)
	return absf(l.x) <= half_l() and absf(l.z) <= half_w() and l.y >= top() - num("out_drop_m", 0.6)


func is_out(pos: Vector3) -> bool:
	var l := to_local(pos)
	if l.y < top() - num("out_drop_m", 0.6):
		return true
	var t := tank_half()
	return (absf(l.x) > t.x or absf(l.z) > t.y) and l.y < top() + 2.0


func is_ring_out(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return is_out(body.global_position) or (water != null and water.holds(body))


func pools() -> Array[Node3D]:
	return grates


# ---------------------------------------------------------------- round 3: the lip and the spout (SEAMS; PERCENT's)
## The deck's lip nearest `pos` (pure geometry, the deck's top outer rectangle; world): {point (on the lip, at lip_y),
## normal (outward, flat, unit), out_m (metres out past the lip, flat; negative inside the deck), side (LIP_END_0,
## LIP_END_1, LIP_LONG_NEG, LIP_LONG_POS), along (metres along that lip from its middle: local z on an end, local x on a long
## side)}. Outside a corner the side is the one it is further out past.
func nearest_lip(pos: Vector3) -> Dictionary:
	var l := to_local(pos)
	var hl := half_l()
	var hw := half_w()
	var ex := absf(l.x) - hl                    # (past the end's lip: +, inside: -)
	var ez := absf(l.z) - hw
	var side := LIP_END_0
	var out_m := 0.0
	var p := Vector3(l.x, top(), l.z)
	if ex <= 0.0 and ez <= 0.0:
		# (on the deck: the nearer lip)
		if ex >= ez:
			side = LIP_END_1 if l.x > 0.0 else LIP_END_0
			p.x = hl if side == LIP_END_1 else -hl
		else:
			side = LIP_LONG_POS if l.z > 0.0 else LIP_LONG_NEG
			p.z = hw if side == LIP_LONG_POS else -hw
		out_m = maxf(ex, ez)
	else:
		# (off it: the nearest point of the rectangle and its distance)
		p.x = clampf(l.x, -hl, hl)
		p.z = clampf(l.z, -hw, hw)
		out_m = Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length()
		if ex >= ez:
			side = LIP_END_1 if l.x > 0.0 else LIP_END_0
		else:
			side = LIP_LONG_POS if l.z > 0.0 else LIP_LONG_NEG
	var n := Vector3(0.0, 0.0, 1.0)
	match side:
		LIP_END_0:
			n = Vector3(-1.0, 0.0, 0.0)
		LIP_END_1:
			n = Vector3(1.0, 0.0, 0.0)
		LIP_LONG_NEG:
			n = Vector3(0.0, 0.0, -1.0)
	var along := p.z if side <= LIP_END_1 else p.x
	var wn := global_basis * n
	wn.y = 0.0
	return {"point": to_global(p), "normal": wn.normalized(), "out_m": out_m, "side": side, "along": along}


## The lip's height (the deck top, world).
func lip_y() -> float:
	return deck_y()


## Where a respawn spout rises for deck end `side`: the grate on its last grate line (the line behind zone zones - 1: s 12 m),
## at grate_z[slot] (world, on the deck).
func spout_at(side: int, slot := 0) -> Vector3:
	var zs: Array = data().get("grate_z", [4.0, -4.0])
	var z := float(zs[posmod(slot, zs.size())]) if not zs.is_empty() else 0.0
	var s := line_s(side, int(num("zones", 3.0)) - 1)
	return to_global(Vector3(side_sign(side) * s, top(), z))


## A wall's place kept off the lip (spec §5.2: PERCENT clamps it wall_lip_clear_m inside); as given until then.
func wall_place_ok(pos: Vector3) -> Vector3:
	return pos


func rect_for(side: int, min_zone: int, max_zone: int) -> AABB:
	var h := num("neutral_m", 4.0) * 0.5
	var zm := num("zone_m", 5.0)
	var n := int(num("zones", 3.0))
	var s0 := -h if min_zone <= 0 else h + zm * float(mini(min_zone, n) - 1)
	var s1 := h if max_zone <= 0 else h + zm * float(mini(max_zone, n))
	var sg := side_sign(side)
	var box := AABB()
	var first := true
	for s: float in [s0, s1]:
		for z: float in [-half_w(), half_w()]:
			for y: float in [top(), top() + 3.0]:
				var p := to_global(Vector3(sg * s, y, z))
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


## The ring and the tank (local, grown by CLEAR_MARGIN), from under the tank's floor to well over the deck.
func in_bounds(pos: Vector3) -> bool:
	var l := to_local(pos)
	var t := tank_half() + Vector2.ONE * CLEAR_MARGIN
	return absf(l.x) <= t.x and absf(l.z) <= t.y and l.y > num("floor_y", -3.4) - 6.0 and l.y < top() + 40.0


func rebuild() -> void:
	for sk: Dictionary in sockets:
		var st: Variant = sk.get("stone")
		if st is FormStone and is_instance_valid(st) and not (st as FormStone).is_queued_for_deletion():
			(st as FormStone).queue_free()
	sockets.clear()
	var sd: Dictionary = data().get("sockets", {})
	var i := 0
	for side in 2:
		for e: Variant in sd.get("at", []):
			var a := e as Array
			var at := to_global(Vector3(side_sign(side) * float(a[0]), top(), float(a[1]) * side_sign(side)))
			var sk := {"at": at, "stone": null, "wait": 0.0, "seed": 7 + i * 13}
			sockets.append(sk)
			_raise_stone(sk)
			i += 1


func clear_dropped() -> int:
	var n := 0
	var tree := get_tree()
	if tree == null:
		return 0
	var seated := {}
	for sk: Dictionary in sockets:
		var st: Variant = sk.get("stone")
		if st is Node and is_instance_valid(st):
			seated[(st as Node).get_instance_id()] = true
	var groups: Array[StringName] = [FormRaised.GROUP, FormHollow.GROUP, FormCircle.GROUP, FormStone.GROUP, BendBolt.GROUP,
			BendZone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP, NpcBending.FLIGHT_GROUP]
	for g: StringName in groups:
		for x: Node in tree.get_nodes_in_group(g):
			if x.is_queued_for_deletion() or seated.has(x.get_instance_id()):
				continue
			var at: Variant = null
			if x is Node3D:
				at = (x as Node3D).global_position
			else:
				var st: Variant = x.get("stone")
				if st is Node3D and is_instance_valid(st):
					at = (st as Node3D).global_position
			if at == null or in_bounds(at):
				x.queue_free()
				n += 1
	var scn := tree.current_scene
	if scn != null:
		for x: Node in scn.get_children():
			if x.is_queued_for_deletion() or not (x is Node3D) or not in_bounds((x as Node3D).global_position):
				continue
			if x is Projectile or x is NpcLoot:
				x.queue_free()
				n += 1
	return n


# ---------------------------------------------------------------- the sockets
func _physics_process(dt: float) -> void:
	var sd: Dictionary = data().get("sockets", {})
	var away := float(sd.get("away_m", 0.9))
	for sk: Dictionary in sockets:
		var st: Variant = sk.get("stone")
		if st != null:
			var gone := not is_instance_valid(st) or (st as FormStone).is_queued_for_deletion()
			if not gone:
				var s := st as FormStone
				var flat := s.global_position - (sk.at as Vector3)
				flat.y = 0.0
				gone = s.state == FormStone.State.HELD or s.state == FormStone.State.SINKING or flat.length() > away
				if gone and s.state != FormStone.State.SINKING:
					# (loose now: it lies its while and sinks, as any stone)
					s.life_s = float(sd.get("loose_life_s", 25.0))
					s.age = 0.0
			if gone:
				sk["stone"] = null
				sk["wait"] = float(sd.get("refill_s", 8.0))
			continue
		sk["wait"] = float(sk.get("wait", 0.0)) - dt
		if float(sk.wait) <= 0.0:
			_raise_stone(sk)
	_ring_hurls()


func _raise_stone(sk: Dictionary) -> void:
	var sd: Dictionary = (data().get("sockets", {}) as Dictionary).get("stone", {})
	var seed_ := int(sk.get("seed", 0))
	sk["seed"] = seed_ + 1
	sk["stone"] = FormStone.ball(_stones, sk.at as Vector3, sd, seed_, String(data().get("deck_matter", "earth")))
	sk["wait"] = 0.0


## Every stone flight on the deck thrown with the open world's Gust hurl numbers (moves.json gust.stone.hurl: a Shove of a
## loose stone, a socket's cannonball, a dropped spike or a kicked-up stone; BendEffects._throw_stone) given ring.json
## sockets.hurl's for its stone's kind instead, once, its Shove's grow (its knock's share over Gust's) kept: deck stones are
## ammo for knock-backs, not 45-110 blows (KITS round 2's soak: earth won on shoved cannonballs, 395 a match). A Stone Form
## cast keeps its own numbers (stone_form.throw.hurl) and a caught stone sent back its own (BendZone.return_stone: the
## catch never weaker); the open world's Gust is untouched. Its data copied, never the shared moves.json.
func _ring_hurls() -> void:
	var rh: Dictionary = (data().get("sockets", {}) as Dictionary).get("hurl", {})
	if rh.is_empty():
		return
	var gust: Dictionary = (SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {})
	for g in get_tree().get_nodes_in_group(GustLift.GROUP):
		var l := g as GustLift
		if l == null or l.has_meta(RING_HURL_META) or l.phase == GustLift.Phase.DONE:
			continue
		l.set_meta(RING_HURL_META, true)
		var hurls: Dictionary = l.d.get("hurl", {})
		var hd: Dictionary = hurls.get(l.kind, {})
		var base: Dictionary = gust.get(l.kind, {})
		var mine: Dictionary = rh.get(l.kind, rh.get("stone", {}))
		if base.is_empty() or mine.is_empty() or hd.get("damage") != base.get("damage") or hd.get("mps") != base.get("mps"):
			continue                                 # (not Gust's numbers: a Stone Form cast's, a return's)
		var km := float(hd.get("knock_mps", GustLift.KNOCK_MPS)) / float(base.get("knock_mps", GustLift.KNOCK_MPS))
		var nd: Dictionary = l.d.duplicate(true)
		var nh: Dictionary = mine.duplicate(true)
		nh["knock_mps"] = float(mine.get("knock_mps", GustLift.KNOCK_MPS)) * km
		(nd["hurl"] as Dictionary)[l.kind] = nh
		l.d = nd


# ---------------------------------------------------------------- the build: materials
## Our own copies of the fort's materials (the fort's textures; StructureMaterials.get_material, only those used): the deck's
## stone and boards without the ground's dirt and moss (the deck is not on the ground), the tank's stone with a green
## waterline, the walk's flags.
func _materials() -> void:
	var low := num("floor_y", -3.4) - 2.0
	var deck_stone := StructureMaterials.get_material(&"stone").duplicate() as ShaderMaterial
	deck_stone.set_shader_parameter(&"ground_y", low)
	deck_stone.set_shader_parameter(&"moss_strength", 0.06)
	deck_stone.set_shader_parameter(&"lichen", 0.12)
	deck_stone.set_shader_parameter(&"streak_strength", 0.0)
	deck_stone.set_shader_parameter(&"normal_strength", 0.8)
	mats[&"ring_stone"] = deck_stone
	var boards := StructureMaterials.get_material(&"boards").duplicate() as ShaderMaterial
	boards.set_shader_parameter(&"ground_y", low)
	boards.set_shader_parameter(&"moss_strength", 0.0)
	boards.set_shader_parameter(&"lichen", 0.08)
	boards.set_shader_parameter(&"streak_strength", 0.05)
	boards.set_shader_parameter(&"bleach_strength", 0.12)
	mats[&"ring_boards"] = boards
	var wall := StructureMaterials.get_material(&"stone").duplicate() as ShaderMaterial
	wall.set_shader_parameter(&"ground_y", num("water_y", -1.4) - 0.25)
	wall.set_shader_parameter(&"dirt_height", 0.55)
	wall.set_shader_parameter(&"dirt_strength", 0.75)
	wall.set_shader_parameter(&"dirt_tint", Color(0.3, 0.36, 0.26))
	wall.set_shader_parameter(&"moss_strength", 0.25)
	mats[&"ring_wall"] = wall
	var walk := StructureMaterials.get_material(&"stone").duplicate() as ShaderMaterial
	walk.set_shader_parameter(&"ground_y", top())
	walk.set_shader_parameter(&"dirt_height", 0.12)
	walk.set_shader_parameter(&"moss_strength", 0.2)
	mats[&"ring_walk"] = walk


func _commit(parent: Node3D, kit: StructureMeshKit, nm: String) -> MeshInstance3D:
	if not visuals or kit.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = kit.commit(mats)
	parent.add_child(mi)
	return mi


static func _tint(a: Variant, def := Color.WHITE) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return def


## A box (centre, size; local) under `key` with world-projected UVs, uv_m metres a tile, shifted by uv_off; tinted; its
## lowest edges darkened a little (StructureGeometry._stone_box's, with a key, a tint and a shift). skip: the faces left out
## (1 +X, 2 -X, 4 +Y, 8 -Y, 16 +Z, 32 -Z).
static func wbox(kit: StructureMeshKit, key: StringName, ctr: Vector3, size: Vector3, uv_m: float, tint := Color.WHITE,
		skip := 0, uv_off := Vector2.ZERO, kind := StructureMeshKit.KIND_TEX) -> void:
	var ts := 1.0 / maxf(uv_m, 0.01)
	var h := size * 0.5
	var faces := [[Vector3.RIGHT, 1], [Vector3.LEFT, 2], [Vector3.UP, 4], [Vector3.DOWN, 8], [Vector3.BACK, 16], [Vector3.FORWARD, 32]]
	for f: Array in faces:
		if skip & int(f[1]):
			continue
		var n: Vector3 = f[0]
		var u := Vector3.UP.cross(n) if absf(n.y) < 0.5 else Vector3.RIGHT
		var v := n.cross(u)
		var ext_u := absf(u.dot(h))
		var ext_v := absf(v.dot(h))
		var c := ctr + n * absf(n.dot(h))
		var pts := [c - u * ext_u - v * ext_v, c + u * ext_u - v * ext_v, c + u * ext_u + v * ext_v, c - u * ext_u + v * ext_v]
		var uvs := []
		for p: Vector3 in pts:
			var uu := p.dot(u) * ts + uv_off.x
			var vv := (p.y if absf(n.y) < 0.5 else p.dot(v)) * ts + uv_off.y
			uvs.append(Vector2(uu, -vv))
		var ao := 0.75 if n.y < -0.5 else 1.0
		var cols := PackedColorArray()
		for p: Vector3 in pts:
			cols.append(Color(tint.r, tint.g, tint.b, ao * (0.8 if p.y < ctr.y - h.y + 0.05 else 1.0)))
		kit.quad(key, pts[0], pts[1], pts[2], pts[3], uvs[0], uvs[1], uvs[2], uvs[3], tint, kind, 0.0, cols)


## Rect `r` with the holes taken out of it: the pieces left (axis-aligned; x and z of the deck).
static func cut(r: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var parts: Array[Rect2] = [r]
	for hole in holes:
		var next: Array[Rect2] = []
		for p in parts:
			if not p.intersects(hole):
				next.append(p)
				continue
			var i := p.intersection(hole)
			if i.position.x > p.position.x + 0.001:
				next.append(Rect2(p.position.x, p.position.y, i.position.x - p.position.x, p.size.y))
			if i.end.x < p.end.x - 0.001:
				next.append(Rect2(i.end.x, p.position.y, p.end.x - i.end.x, p.size.y))
			if i.position.y > p.position.y + 0.001:
				next.append(Rect2(i.position.x, p.position.y, i.size.x, i.position.y - p.position.y))
			if i.end.y < p.end.y - 0.001:
				next.append(Rect2(i.position.x, i.end.y, i.size.x, p.end.y - i.end.y))
		parts = next
	return parts


# ---------------------------------------------------------------- the build: the deck
## The parts of the deck along X: [name, x0, x1, look key] (local).
func deck_parts() -> Array:
	var h := num("neutral_m", 4.0) * 0.5
	var zm := num("zone_m", 5.0)
	var out := [["neutral", -h, h, "neutral"]]
	for side in 2:
		var sg := side_sign(side)
		for k in int(num("zones", 3.0)):
			var a := sg * (h + zm * k)
			var b := sg * (h + zm * (k + 1))
			out.append(["s%d_z%d" % [side, k + 1], minf(a, b), maxf(a, b), "zone_%d" % (k + 1)])
	return out


## The grates' holes in the deck (local x, z): on each zone line of each side, grates_per_line of them at grate_z.
func grate_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var gw := num("grate_w", 1.0)
	var gl := num("grate_l", 2.0)
	var zs: Array = data().get("grate_z", [4.0, -4.0])
	var per := int(num("grates_per_line", 2.0))
	for side in 2:
		for k in int(num("zones", 3.0)):
			var x := side_sign(side) * line_s(side, k)
			for j in mini(per, zs.size()):
				out.append(Rect2(x - gw * 0.5, float(zs[j]) - gl * 0.5, gw, gl))
	return out


func _deck() -> void:
	var y := top()
	var floor_y := num("floor_y", -3.4)
	var hw := half_w()
	var looks: Dictionary = data().get("looks", {})
	var matter := String(data().get("deck_matter", "earth"))
	var root := Node3D.new()
	root.name = "Deck"
	add_child(root)
	var holes := grate_rects()
	var kit := StructureMeshKit.new() if visuals else null
	var rng := RandomNumberGenerator.new()
	rng.seed = 1750
	for part: Array in deck_parts():
		var x0 := float(part[1])
		var x1 := float(part[2])
		var look: Dictionary = looks.get(String(part[3]), {})
		var wood := String(look.get("kind", "stone")) == "boards"
		var b := StaticBody3D.new()
		b.name = "Deck_" + String(part[0])
		b.collision_layer = 1
		b.collision_mask = 0
		b.set_meta(DECK_META, String(part[0]))
		b.set_meta(&"form_matter", matter)
		b.set_meta(&"surface", "wood" if wood else String(data().get("deck_surface", "stone")))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(x1 - x0, y - floor_y, hw * 2.0)
		cs.shape = box
		cs.position = Vector3((x0 + x1) * 0.5, (y + floor_y) * 0.5, 0.0)
		b.add_child(cs)
		root.add_child(b)
		decks.append(b)
		if kit != null:
			_lay(kit, Rect2(x0, -hw, x1 - x0, hw * 2.0), look, holes, rng)
	# the plinth's foot: from the step (under the ring-out drop) down, plinth_out_m wider all round
	var fh := foot_half()
	var step := top() + num("plinth_step_y", -0.65)
	var foot := StaticBody3D.new()
	foot.name = "PlinthFoot"
	foot.collision_layer = 1
	foot.collision_mask = 0
	foot.set_meta(&"form_matter", matter)
	foot.set_meta(&"surface", "stone")
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(fh.x * 2.0, step - floor_y, fh.y * 2.0)
	fcs.shape = fbox
	fcs.position = Vector3(0.0, (step + floor_y) * 0.5, 0.0)
	foot.add_child(fcs)
	root.add_child(foot)
	if kit != null:
		# the plinth: masonry from the tank's floor to under the deck's laying, a coursed band just under its edge
		var tt := num("tile_thick", 0.1)
		var hl := half_l()
		var pt := _tint((looks.get("plinth", {}) as Dictionary).get("tint"), Color(0.72, 0.7, 0.66))
		var py0 := floor_y - 0.3
		var py1 := y - tt
		wbox(kit, &"ring_wall", Vector3(0.0, (step + py1) * 0.5, 0.0), Vector3(hl * 2.0, py1 - step, hw * 2.0), 1.6, pt, 4 | 8)
		wbox(kit, &"ring_wall", Vector3(0.0, (py0 + step) * 0.5, 0.0), Vector3(fh.x * 2.0, step - py0, fh.y * 2.0), 1.6, pt * 0.95, 8)
		wbox(kit, &"ring_wall", Vector3(0.0, y - tt - 0.13, 0.0), Vector3(hl * 2.0 + 0.16, 0.24, hw * 2.0 + 0.16), 1.2, pt * 0.92, 4 | 8)
		# the dark under the laying (the joints, the grates' wells)
		for r in cut(Rect2(-hl, -hw, hl * 2.0, hw * 2.0), holes):
			_flat(kit, r, y - 0.03, StructureMeshKit.KIND_VOID)
		_commit(root, kit, "DeckMesh")


## Part `r` of the deck laid as `look` says (ring.json looks), round the holes.
func _lay(kit: StructureMeshKit, r: Rect2, look: Dictionary, holes: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var y := top()
	var tt := num("tile_thick", 0.1)
	var tint := _tint(look.get("tint"))
	var jit := float(look.get("jitter", 0.06))
	if String(look.get("kind", "stone")) == "boards":
		var pw := float(look.get("plank_w", 0.24))
		var bm := float(look.get("board_m", 3.0))
		var along_x := String(look.get("grain", "z")) == "x"
		var span := r.size.y if along_x else r.size.x                      # across the planks
		var run := r.size.x if along_x else r.size.y                       # along them
		var rows := ceili(span / pw - 0.01)
		for i in rows:
			var a0 := float(i) * pw
			var a1 := minf(a0 + pw, span)
			var off := fposmod(float(i) * 1.37 + rng.randf() * 0.4, bm)
			var t0 := -off
			while t0 < run:
				var b0 := maxf(t0, 0.0)
				var b1 := minf(t0 + bm, run)
				t0 += bm
				if b1 - b0 < 0.05:
					continue
				var piece := Rect2(r.position.x + b0, r.position.y + a0, b1 - b0, a1 - a0) if along_x \
						else Rect2(r.position.x + a0, r.position.y + b0, a1 - a0, b1 - b0)
				var k := 1.0 + rng.randf_range(-jit, jit)
				var col := Color(tint.r * k, tint.g * k, tint.b * k)
				var row := rng.randi_range(0, StructureMeshKit.ROWS - 1)
				var u0 := rng.randf() * 4.0
				for p in cut(piece, holes):
					var gap := 0.008
					# (a joint between boards end to end, a wider one between the rows)
					var sz := Vector3(p.size.x - (gap if along_x else gap * 2.0), tt, p.size.y - (gap * 2.0 if along_x else gap))
					if sz.x <= 0.01 or sz.z <= 0.01:
						continue
					var c := Vector3(p.get_center().x, y - tt * 0.5 + rng.randf_range(-0.003, 0.0), p.get_center().y)
					kit.box(&"ring_boards", Transform3D(Basis(), c), sz, StructureMeshKit.GRAIN_X if along_x else StructureMeshKit.GRAIN_Z,
							row, u0, col, StructureMeshKit.KIND_ENDGRAIN, 8, 0.25)
		return
	var sm := float(look.get("slab_m", 1.0))
	var uv_m := float(look.get("uv_m", 5.0))
	var nx := ceili(r.size.x / sm - 0.01)
	var nz := ceili(r.size.y / sm - 0.01)
	for i in nx:
		for j in nz:
			var s := Rect2(r.position.x + i * sm, r.position.y + j * sm, minf(sm, r.size.x - i * sm), minf(sm, r.size.y - j * sm))
			var k := 1.0 + rng.randf_range(-jit, jit)
			var col := Color(tint.r * k, tint.g * k * (1.0 + rng.randf_range(-0.02, 0.02)), tint.b * k)
			var off := Vector2(rng.randf() * 7.0, rng.randf() * 7.0)
			var lift := rng.randf_range(-0.004, 0.0)
			for p in cut(s, holes):
				var g := 0.014
				if p.size.x <= g * 2.0 or p.size.y <= g * 2.0:
					continue
				wbox(kit, &"ring_stone", Vector3(p.get_center().x, y - tt * 0.5 + lift, p.get_center().y),
						Vector3(p.size.x - g, tt, p.size.y - g), uv_m, col, 8, off)


## A flat quad over rect `r` (x, z) at height y, face up, of `kind` (the void: the dark).
func _flat(kit: StructureMeshKit, r: Rect2, y: float, kind: float) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	kit.quad(&"ring_stone", a, b, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, kind, 0.0,
			PackedColorArray(), Vector3.UP)


## An iron box (StructureMeshKit's wrought iron on every face).
func _iron(kit: StructureMeshKit, ctr: Vector3, size: Vector3) -> void:
	wbox(kit, &"ring_stone", ctr, size, 1.0, Color.WHITE, 0, Vector2.ZERO, StructureMeshKit.KIND_IRON)


# ---------------------------------------------------------------- the build: the grates
func _grates() -> void:
	var y := top()
	var reach := num("grate_reach_m", 1.5)
	var wy := y - num("grate_water_m", 0.3)
	var well := num("grate_well_m", 0.75)
	var root := Node3D.new()
	root.name = "Grates"
	add_child(root)
	var kit := StructureMeshKit.new() if visuals else null
	var water_kit := PackedVector3Array()
	var i := 0
	for r in grate_rects():
		var g := Node3D.new()
		g.name = "Grate_%d" % i
		i += 1
		g.position = Vector3(r.get_center().x, y, r.get_center().y)
		g.set_meta(&"reach_m", reach)
		g.add_to_group(Bending.POOLS)
		root.add_child(g)
		grates.append(g)
		if kit == null:
			continue
		var x0 := r.position.x
		var x1 := r.end.x
		var z0 := r.position.y
		var z1 := r.end.y
		var fw := 0.07
		# the well's walls (dark), its frame, its bars across the short way
		wbox(kit, &"ring_stone", Vector3(r.get_center().x, y - well * 0.5, z0 + 0.01), Vector3(r.size.x, well, 0.02), 1.0, Color.WHITE, 0,
				Vector2.ZERO, StructureMeshKit.KIND_VOID)
		wbox(kit, &"ring_stone", Vector3(r.get_center().x, y - well * 0.5, z1 - 0.01), Vector3(r.size.x, well, 0.02), 1.0, Color.WHITE, 0,
				Vector2.ZERO, StructureMeshKit.KIND_VOID)
		wbox(kit, &"ring_stone", Vector3(x0 + 0.01, y - well * 0.5, r.get_center().y), Vector3(0.02, well, r.size.y), 1.0, Color.WHITE, 0,
				Vector2.ZERO, StructureMeshKit.KIND_VOID)
		wbox(kit, &"ring_stone", Vector3(x1 - 0.01, y - well * 0.5, r.get_center().y), Vector3(0.02, well, r.size.y), 1.0, Color.WHITE, 0,
				Vector2.ZERO, StructureMeshKit.KIND_VOID)
		_iron(kit, Vector3(r.get_center().x, y - 0.02, z0 + fw * 0.5), Vector3(r.size.x, 0.04, fw))
		_iron(kit, Vector3(r.get_center().x, y - 0.02, z1 - fw * 0.5), Vector3(r.size.x, 0.04, fw))
		_iron(kit, Vector3(x0 + fw * 0.5, y - 0.02, r.get_center().y), Vector3(fw, 0.04, r.size.y - fw * 2.0))
		_iron(kit, Vector3(x1 - fw * 0.5, y - 0.02, r.get_center().y), Vector3(fw, 0.04, r.size.y - fw * 2.0))
		var bars := int((r.size.y - fw * 2.0) / 0.09)
		for k in bars:
			var bz := z0 + fw + (float(k) + 0.5) * (r.size.y - fw * 2.0) / float(bars)
			_iron(kit, Vector3(r.get_center().x, y - 0.025, bz), Vector3(r.size.x - fw * 2.0, 0.05, 0.025))
		_iron(kit, Vector3(r.get_center().x, y - 0.04, r.get_center().y), Vector3(0.03, 0.035, r.size.y - fw * 2.0))
		# the well's stone floor under its water (the water reads shallow and clear over it, as a drain's)
		wbox(kit, &"ring_wall", Vector3(r.get_center().x, y - well - 0.05, r.get_center().y), Vector3(r.size.x, 0.1, r.size.y), 1.0,
				Color(0.55, 0.6, 0.55), 8)
		water_kit.append_array([Vector3(x0, wy, z0), Vector3(x1, wy, z0), Vector3(x1, wy, z1), Vector3(x0, wy, z1)])
	if kit != null:
		_commit(root, kit, "GratesMesh")
		# the water under them (the tank's own water material, set when RingWater has made it)
		var wells := MeshInstance3D.new()
		wells.name = "GrateWater"
		wells.mesh = RingWater.quads(water_kit, Vector2(1.0, 0.0))
		wells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wells)


## Each socket's collar: an iron frame let into the deck round where its stone sits (ring.json sockets.at, both sides).
func _collars() -> void:
	if not visuals:
		return
	var kit := StructureMeshKit.new()
	var y := top()
	var h := 0.36
	var bw := 0.07
	for side in 2:
		for e: Variant in (data().get("sockets", {}) as Dictionary).get("at", []):
			var a := e as Array
			var c := Vector3(side_sign(side) * float(a[0]), y + 0.012, float(a[1]) * side_sign(side))
			_iron(kit, c + Vector3(0.0, 0.0, -h), Vector3(h * 2.0 + bw, 0.024, bw))
			_iron(kit, c + Vector3(0.0, 0.0, h), Vector3(h * 2.0 + bw, 0.024, bw))
			_iron(kit, c + Vector3(-h, 0.0, 0.0), Vector3(bw, 0.024, h * 2.0 - bw))
			_iron(kit, c + Vector3(h, 0.0, 0.0), Vector3(bw, 0.024, h * 2.0 - bw))
	var root := Node3D.new()
	root.name = "Collars"
	add_child(root)
	_commit(root, kit, "CollarsMesh")


# ---------------------------------------------------------------- the build: the ropes
func _ropes() -> void:
	var y := top()
	var hl := half_l()
	var hw := half_w()
	var rh := num("rope_h", 1.1)
	var root := Node3D.new()
	root.name = "Ropes"
	add_child(root)
	for sz: float in [-1.0, 1.0]:
		var b := StaticBody3D.new()
		b.name = "RopeRail_%s" % ("n" if sz < 0.0 else "s")
		b.collision_layer = 1
		b.collision_mask = 0
		b.set_meta(&"surface", "wood")
		b.set_meta(&"ring_rope", true)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(hl * 2.0, rh + 0.1, 0.12)
		cs.shape = box
		cs.position = Vector3(0.0, y + (rh + 0.1) * 0.5, sz * (hw - 0.06))
		b.add_child(cs)
		root.add_child(b)
	if not visuals:
		return
	var kit := StructureMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1751
	var posts := maxi(int(num("rope_posts", 9.0)), 2)
	for sz: float in [-1.0, 1.0]:
		for i in posts:
			var x := lerpf(-hl + 0.1, hl - 0.1, float(i) / float(posts - 1))
			var c := Vector3(x, y + (rh + 0.15) * 0.5, sz * (hw - 0.09))
			kit.box(&"ring_boards", Transform3D(Basis(), c), Vector3(0.13, rh + 0.15, 0.13), StructureMeshKit.GRAIN_Y, rng.randi_range(0, 3),
					rng.randf(), Color(0.36, 0.28, 0.22), StructureMeshKit.KIND_ENDGRAIN, 8, 0.3)
			_iron(kit, Vector3(x, y + rh + 0.17, sz * (hw - 0.09)), Vector3(0.17, 0.05, 0.17))
			_iron(kit, Vector3(x, y + 0.03, sz * (hw - 0.09)), Vector3(0.2, 0.06, 0.2))
	_commit(root, kit, "PostsMesh")
	var rope := CylinderMesh.new()
	rope.top_radius = num("rope_r", 0.035)
	rope.bottom_radius = rope.top_radius
	rope.height = hl * 2.0
	rope.radial_segments = 8
	rope.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = _tint(data().get("rope_color"), Color(0.56, 0.45, 0.31))
	m.roughness = 0.95
	rope.material = m
	for sz: float in [-1.0, 1.0]:
		for ry: Variant in data().get("rope_strands", [0.42, 0.76, 1.1]):
			var mi := MeshInstance3D.new()
			mi.name = "Rope"
			mi.mesh = rope
			mi.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, y + float(ry), sz * (hw - 0.09)))
			root.add_child(mi)


# ---------------------------------------------------------------- the build: round it
## The walk round the tank, the stands along the long sides, the walls across the ends: colliders always, the meshes when
## drawn.
func _surround() -> void:
	var sd: Dictionary = data().get("surround", {})
	var looks: Dictionary = data().get("looks", {})
	var y := top()
	var t := tank_half()
	var wt := num("tank_wall_m", 0.8)
	var ps := float(sd.get("plaza_side", 3.0))
	var pe := float(sd.get("plaza_end", 4.0))
	var tiers := int(sd.get("tiers", 6))
	var td := float(sd.get("tier_d", 0.9))
	var th := float(sd.get("tier_h", 0.5))
	var back_h := float(sd.get("back_h", 1.4))
	var ewh := float(sd.get("end_wall_h", 4.6))
	var ewt := float(sd.get("end_wall_t", 1.0))
	var ox := t.x + wt + pe                       # the end walls' inner face
	var oz := t.y + wt + ps                       # the stands' front
	var back := oz + td * float(tiers)            # the stands' back
	var root := Node3D.new()
	root.name = "Surround"
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "SurroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", "stone")
	root.add_child(body)
	var stands := StaticBody3D.new()
	stands.name = "Stands"
	stands.collision_layer = 1
	stands.collision_mask = 0
	stands.set_meta(&"surface", "wood")
	root.add_child(stands)
	var walk: Array[AABB] = [
		AABB(Vector3(-ox, y - 0.4, t.y + wt), Vector3(ox * 2.0, 0.4, ps)),
		AABB(Vector3(-ox, y - 0.4, -oz), Vector3(ox * 2.0, 0.4, ps)),
		AABB(Vector3(t.x + wt, y - 0.4, -(t.y + wt)), Vector3(pe, 0.4, (t.y + wt) * 2.0)),
		AABB(Vector3(-ox, y - 0.4, -(t.y + wt)), Vector3(pe, 0.4, (t.y + wt) * 2.0)),
	]
	var walls: Array[AABB] = [
		AABB(Vector3(ox, y, -back - 0.1), Vector3(ewt, ewh, (back + 0.1) * 2.0)),
		AABB(Vector3(-ox - ewt, y, -back - 0.1), Vector3(ewt, ewh, (back + 0.1) * 2.0)),
	]
	for a in walk + walls:
		_box_shape(body, a)
	for sz: float in [-1.0, 1.0]:
		for i in tiers:
			var z0 := oz + td * float(i)
			var z1 := back
			var a := AABB(Vector3(-ox, y, minf(sz * z0, sz * z1)), Vector3(ox * 2.0, th * float(i + 1), z1 - z0))
			_box_shape(stands, a)
		var bw := AABB(Vector3(-ox, y, minf(sz * back, sz * (back + 0.2))), Vector3(ox * 2.0, th * float(tiers) + back_h, 0.2))
		_box_shape(stands, bw)
	if not visuals:
		return
	var kit := StructureMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1752
	var pt := _tint((looks.get("plaza", {}) as Dictionary).get("tint"), Color(0.78, 0.76, 0.72))
	for a in walk:
		wbox(kit, &"ring_walk", a.get_center(), a.size, 1.6, pt, 8)
	var et := _tint((looks.get("tank", {}) as Dictionary).get("tint"), Color(0.5, 0.52, 0.5)) * 1.25
	for a in walls:
		wbox(kit, &"ring_walk", a.get_center(), a.size, 1.6, et, 8)
		# its cap: a coursed band over it
		wbox(kit, &"ring_walk", Vector3(a.get_center().x, a.end.y + 0.12, a.get_center().z), Vector3(a.size.x + 0.2, 0.24, a.size.z),
				1.2, et * 0.9)
	var st := _tint((looks.get("stands", {}) as Dictionary).get("tint"), Color(0.86, 0.74, 0.6))
	for sz: float in [-1.0, 1.0]:
		for i in tiers:
			var z0 := oz + td * float(i)
			var top_y := y + th * float(i + 1)
			# the seat: planks along the stands; the riser: planks on edge
			var planks := 3
			for k in planks:
				var pz := sz * (z0 + td * (float(k) + 0.5) / float(planks))
				_long_planks(kit, Vector3(0.0, top_y - 0.03, pz), Vector3(ox * 2.0, 0.06, td / float(planks) - 0.012), st, rng)
			for k in 2:
				var ry := top_y - th * (float(k) + 0.5) / 2.0
				_long_planks(kit, Vector3(0.0, ry, sz * (z0 + 0.025)), Vector3(ox * 2.0, th / 2.0 - 0.01, 0.05), st * 0.9, rng)
		# the back: planks on edge to over the top tier
		var hb := th * float(tiers) + back_h
		var courses := int(hb / 0.26)
		for k in courses:
			var ry := y + (float(k) + 0.5) * hb / float(courses)
			_long_planks(kit, Vector3(0.0, ry, sz * (back + 0.1)), Vector3(ox * 2.0, hb / float(courses) - 0.01, 0.2), st * 0.82, rng)
	_commit(root, kit, "SurroundMesh")
	# the ground outside the arena (seen from up in the stands): packed earth to the haze, round the walls and stands
	var gk := StructureMeshKit.new()
	var gx := ox + ewt
	var gz := back + 0.2
	var far := 400.0
	var gy := y - 0.02
	for r: Rect2 in [Rect2(-far, -far, far * 2.0, far - gz), Rect2(-far, gz, far * 2.0, far - gz), Rect2(-far, -gz, far - gx, gz * 2.0),
			Rect2(gx, -gz, far - gx, gz * 2.0)]:
		var a := Vector3(r.position.x, gy, r.position.y)
		var b := Vector3(r.end.x, gy, r.position.y)
		var c := Vector3(r.end.x, gy, r.end.y)
		var d := Vector3(r.position.x, gy, r.end.y)
		gk.quad(&"ring_ground", a, b, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE,
				StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), Vector3.UP)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = _tint((looks.get("ground", {}) as Dictionary).get("tint"), Color(0.34, 0.31, 0.24))
	gm.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = gk.commit({&"ring_ground": gm})
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)


## Planks end to end along X over `size` (centre c), board by board (3-5.5 m), each its own row of the texture and shade.
func _long_planks(kit: StructureMeshKit, c: Vector3, size: Vector3, tint: Color, rng: RandomNumberGenerator) -> void:
	var x := c.x - size.x * 0.5
	var end := c.x + size.x * 0.5
	while x < end - 0.05:
		var l := minf(rng.randf_range(3.0, 5.5), end - x)
		var k := 1.0 + rng.randf_range(-0.07, 0.07)
		kit.box(&"ring_boards", Transform3D(Basis(), Vector3(x + l * 0.5, c.y, c.z)), Vector3(l - 0.01, size.y, size.z), StructureMeshKit.GRAIN_X,
				rng.randi_range(0, 3), rng.randf() * 4.0, Color(tint.r * k, tint.g * k, tint.b * k), StructureMeshKit.KIND_ENDGRAIN, 0, 0.3)
		x += l


func _box_shape(b: StaticBody3D, a: AABB) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = a.size
	cs.shape = box
	cs.position = a.get_center()
	b.add_child(cs)


## A floor far under everything (nothing falls forever, wherever it is thrown).
func _catch_floor() -> void:
	var b := StaticBody3D.new()
	b.name = "CatchFloor"
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	cs.position = Vector3(0.0, num("floor_y", -3.4) - 3.0, 0.0)
	b.add_child(cs)
	add_child(b)
