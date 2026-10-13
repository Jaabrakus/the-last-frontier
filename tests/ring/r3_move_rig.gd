extends RefCounted
## The round-3 MOVE tests' rig (tests/ring/test_ring_moves.gd, test_ring_edge.gd; not a test itself): the bare ring
## (scenes/ring.tscn without a match: its player, his caster, no RingMode) and, far from it, a test deck of the % ring's
## shape (ring.json's 34 x 14 m rectangle, its top at y 0, a solid stone block 9 m deep with the water's level 6 m under the
## lip and the curtain 10 m out: RingMoves.geo_override), the player on it with a RingMoves and keyboard-free controls
## (PlayerControls set_held), bots spawned there with theirs.
##   var rig := Rig.new(tree); await rig.setup()
##   rig.at(x_in_from_end, z, y)      a place on the test deck (x from the -X end's lip inward; negative: past it)
##   rig.place(body, pos, yaw)        a body put there, still
##   rig.hold(action, on) / rig.tap(action)   the player's keys (tap: pressed this physics frame, let go the next)
##   await rig.secs(s) / rig.ticks(n) / rig.until(cond, limit)

## (high over the bare ring's catch floor, RingArena's, so the face runs 9 m down clear of it)
const D := Vector3(0.0, 20.0, 420.0)
var tree: SceneTree
var p: FrontierPlayer
var pm: RingMoves
var deck: StaticBody3D
var geo := {}
var _taps: Array[StringName] = []


func _init(t: SceneTree) -> void:
	tree = t


func setup(el := "water") -> bool:
	MatchSetup.element = el
	tree.change_scene_to_file("res://scenes/ring.tscn")
	for i in 12:
		await tree.process_frame
	var lvl := tree.current_scene as RingLevel
	p = lvl.player if lvl != null else null
	if p == null:
		return false
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	p.fall_safe_m = 1000.0
	for i in 60:
		await tree.physics_frame
		if p.arena_element != "" and SwayCaster.of(p) != null:
			break
	_build_deck()
	# (as the stock ring has it, PERCENT's RingMode: one gravity, no ragdoll off a knock)
	BendKnock.ragdoll_mps = INF
	geo = RingMoves.box_geo(D, 6.0, 10.0)
	RingMoves.geo_override = geo
	pm = RingMoves.install(p)
	place(p, at(8.0, 0.0), 0.0)
	tree.physics_frame.connect(_untap)
	await secs(0.3)
	return pm != null


func _build_deck() -> void:
	deck = StaticBody3D.new()
	deck.name = "R3TestDeck"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(RingArena.num("deck_l", 34.0), 9.0, RingArena.num("deck_w", 14.0))
	cs.shape = bx
	deck.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	deck.add_child(mi)
	tree.current_scene.add_child(deck)
	deck.global_position = D + Vector3(0.0, -4.5, 0.0)


## A place on the test deck: `x_in` m in from the -X end's lip (negative: out past it), `z` across, `y` up (feet).
func at(x_in: float, z := 0.0, y := 0.0) -> Vector3:
	return D + Vector3(-float(geo.get("hl", 17.0)) + x_in if not geo.is_empty() else -17.0 + x_in, y, z)


## The -X end's lip point at `z` (world).
func lip(z := 0.0) -> Vector3:
	return D + Vector3(-17.0, 0.0, z)


## `b` put at `pos` facing `yaw` (the player: his camera's too), still.
func place(b: Node3D, pos: Vector3, yaw := 0.0) -> void:
	b.global_position = pos
	if b is FrontierPlayer:
		var fp := b as FrontierPlayer
		fp.yaw = yaw
		fp.rotation.y = yaw
		fp.velocity = Vector3.ZERO
	elif b is CharacterBody3D:
		b.rotation.y = yaw
		(b as CharacterBody3D).velocity = Vector3.ZERO
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
		kn.lying_t = 0.0
	var m := RingMoves.of(b)
	if m != null:
		m.placed()


## `b` moved to `pos`, still, its move state kept (a nudge, not a reset).
func place_keep(b: Node3D, pos: Vector3) -> void:
	b.global_position = pos
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = Vector3.ZERO


## The yaw that faces from `from` toward `to` (flat).
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func hold(action: StringName, on: bool) -> void:
	p.controls.set_held(action, on)


## `action` pressed this physics frame, let go at the next.
func tap(action: StringName) -> void:
	p.controls.set_held(action, true)
	_taps.append(action)


func _untap() -> void:
	var keep: Array[StringName] = []
	for a in _taps:
		if int(p.controls._down_at.get(a, -1)) == Engine.get_physics_frames():
			keep.append(a)
		else:
			p.controls.set_held(a, false)
	_taps = keep


func release_all() -> void:
	p.controls.release_all()
	_taps.clear()


func ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


func secs(s: float) -> void:
	await ticks(int(round(s * Engine.physics_ticks_per_second)))


func until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await tree.physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


## A bot of `el` on the test deck at `pos`, held from thinking (its mind never moves it: the tests drive its pad), with a
## RingMoves.
func bot(el: String, pos: Vector3, yaw := 0.0) -> NpcFighter:
	var sq := NpcSquad.spawn(tree.current_scene, String(RingMode.FACTIONS[1]) if not NpcFactions.get_faction(String(RingMode.FACTIONS[1])).is_empty() else RingMode.FALLBACK_FACTION,
			1, pos, {"face": pos + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 5.0, "tag": "ring", "tactics": "bend", "element": el,
			"weapon": "", "sidearm": "", "seed": 1750, "y": pos.y})
	for i in 4:
		await tree.physics_frame
	var f: NpcFighter = sq.members[0] if sq != null and not sq.members.is_empty() else null
	if f == null:
		return null
	f.flees = false
	f.calm_s = INF
	f.no_death = true
	f.set(&"element", el)
	Bending.of(f).element = el
	f._think_t = 1e9
	RingMoves.install(f)
	place(f, pos, yaw)
	await ticks(2)
	return f


## Feet height over the deck's top.
func h(b: Node3D) -> float:
	return b.global_position.y - D.y
