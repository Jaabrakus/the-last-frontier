class_name ThuyVanCordon
extends Node3D
## S1's cordon round the still reach (data/world/maps/r1_grey/layers/S1.json "cordon"; plan section 2, "The Silence in
## play": soldiers and clan watchers turn people back, and what touching the water does stays unanswered in Book I):
##   ropes      a rope line across the river's corridor at each end of the reach (`ropes`: z, posts every post_m), from
##              hold_m west of the river's centre to hold_m east of it, the posts standing in the water where it is
##   watchers   people at the ropes facing out (StoryWalker in the Mountain Folk look: ThuyVanPreset), who never fight
##   held       the corridor between the ropes (within hold_m of the river's centre) is kept: someone on foot who steps
##              over a rope is held at it, and a watcher says a line (`lines`; a HUD notice once an approach); a boat
##              paddled up to it is stopped there. No push, no harm, nothing about the water.
## Only on while active (ThuyVanLevel: S1); in S0 the ropes are hidden and the watchers gone.

## How far over the rope one is held back (m), and from how far in one is put back at the rope instead (came in by a boat
## or a teleport).
const HOLD_IN_M := 0.6
const DEEP_M := 3.0
const SAY_S := 4.0
const NOTICE_S := 12.0
const POST_H := 1.25
const POST_R := 0.06
const ROPE_R := 0.018
const ROPE_SAG := 0.14
const POST_COLOR := Color(0.36, 0.27, 0.18)
const ROPE_COLOR := Color(0.62, 0.53, 0.37)

var player: FrontierPlayer
var spec := {}
var active := false
var watchers: Array[StoryWalker] = []
## Times someone was held at a rope (tests).
var held := 0
var _ropes: Array[Node3D] = []
var _lo := 0.0
var _hi := 0.0
var _hold_m := 46.0
var _line := 0
var _say_t := 0.0
var _notice_t := 0.0


func setup(p: FrontierPlayer, cordon: Dictionary) -> void:
	player = p
	spec = cordon
	var zs: Array[float] = []
	for r: Dictionary in spec.get("ropes", []):
		zs.append(float(r.get("z", 0.0)))
	zs.sort()
	if zs.size() >= 2:
		_lo = zs[0]
		_hi = zs[zs.size() - 1]
	_hold_m = float(spec.get("hold_m", 46.0))


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		for r: Dictionary in spec.get("ropes", []):
			var line := _rope_line(float(r.get("z", 0.0)), float(r.get("post_m", 7.0)))
			line.visible = active
			add_child(line)
			_ropes.append(line)


## On (S1): the ropes shown, the watchers at them, the corridor held; off (S0): none of it.
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	for r in _ropes:
		r.visible = on
	if on:
		_place_watchers()
	else:
		for w in watchers:
			if is_instance_valid(w):
				w.queue_free()
		watchers.clear()


## Whether (x, z) lies in the held corridor.
func in_corridor(pos: Vector3) -> bool:
	return _hi > _lo and pos.z > _lo and pos.z < _hi and absf(pos.x - WorldRiver.x_at(pos.z)) < _hold_m


func _physics_process(delta: float) -> void:
	_say_t -= delta
	_notice_t -= delta
	if not active or player == null or not is_instance_valid(player) or player.is_dead:
		return
	var rider := BoatRider.of(player)
	var boat: Boat = rider.get_parent() as Boat if rider != null else null
	var body: Node3D = boat if boat != null else player
	var p := body.global_position
	if not in_corridor(p):
		return
	# back over the nearer rope
	var to_hi := _hi - p.z
	var to_lo := p.z - _lo
	var z := _hi + HOLD_IN_M if to_hi <= to_lo else _lo - HOLD_IN_M
	if boat != null:
		boat.position.z = z
		boat.vel = Vector3.ZERO
	elif minf(to_hi, to_lo) > DEEP_M:
		player.global_position = Vector3(p.x, FrontierTerrain.height_at(p.x, z) + 0.05, z)
		player.velocity = Vector3.ZERO
	else:
		player.global_position.z = z
		player.velocity.z = 0.0
	held += 1
	_speak(Vector3(p.x, p.y, z))


## The nearest watcher says a line (one every SAY_S); a HUD notice once an approach.
func _speak(at: Vector3) -> void:
	if _notice_t <= 0.0 and player.interactor:
		player.interactor.notice("The watchers keep you back from the water.", 3.0)
	_notice_t = NOTICE_S
	if _say_t > 0.0 or watchers.is_empty():
		return
	_say_t = SAY_S
	var best: StoryWalker = null
	for w in watchers:
		if is_instance_valid(w) and (best == null or w.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = w
	var lines: Array = spec.get("lines", [])
	if best != null and not lines.is_empty():
		StoryBark.say(best, String(lines[_line % lines.size()]), 3.0)
		_line += 1


func _place_watchers() -> void:
	var i := 0
	for wd: Dictionary in spec.get("watchers", []):
		var z := float(wd.get("river_z", 0.0))
		var at := Vector3(WorldRiver.x_at(z) + float(wd.get("river_d", 0.0)), 0.0, z)
		# facing out of the reach: the way one comes to the rope from
		var out := 1.0 if z > (_lo + _hi) * 0.5 else -1.0
		var lk := ThuyVanPreset.look(float(wd.get("sex", 1.0)), i + 1)
		if lk.is_empty():
			lk = StoryWalker.settler_look("palatine_m_a")
		var w := StoryWalker.make(self, at, lk, {"tag": "watcher", "name": "Watcher", "node_name": "watcher_%d" % i,
				"face": at + Vector3(0.0, 0.0, out * 10.0)})
		watchers.append(w)
		i += 1


## A rope line across the corridor at z: posts every post_m (on the ground, or on the bed standing out of the water) and a
## rope sagging between their tops.
func _rope_line(z: float, post_m: float) -> Node3D:
	var line := Node3D.new()
	line.name = "Rope_%d" % int(absf(z))
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = POST_COLOR
	post_mat.roughness = 0.9
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = ROPE_COLOR
	rope_mat.roughness = 1.0
	var cx := WorldRiver.x_at(z)
	var n := maxi(int(ceil(_hold_m * 2.0 / maxf(post_m, 1.0))), 1)
	var tops: Array[Vector3] = []
	for k in n + 1:
		var x := cx - _hold_m + _hold_m * 2.0 * float(k) / float(n)
		var ground := FrontierTerrain.height_at(x, z)
		var surf := WorldRiver.surface_at(x, z)
		var top := maxf(ground + POST_H, (surf + 0.9) if surf != WorldRiver.NO_WATER else -INF)
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = POST_R
		cyl.bottom_radius = POST_R * 1.15
		cyl.height = top - ground + 0.3
		cyl.radial_segments = 6
		cyl.rings = 1
		post.mesh = cyl
		post.material_override = post_mat
		line.add_child(post)
		post.position = Vector3(x, (top + ground - 0.3) * 0.5, z)
		tops.append(Vector3(x, top - 0.08, z))
	for k in tops.size() - 1:
		var a := tops[k]
		var b := tops[k + 1]
		var mid := (a + b) * 0.5 - Vector3(0.0, ROPE_SAG, 0.0)
		for seg: Array in [[a, mid], [mid, b]]:
			line.add_child(_rope_piece(seg[0], seg[1], rope_mat))
	return line


func _rope_piece(a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = ROPE_R
	cyl.bottom_radius = ROPE_R
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 5
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the cylinder's axis (+Y) along a -> b
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	return mi
