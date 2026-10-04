class_name PerchBranches
extends Node3D
## A branch to sit on at the top of every climbable trunk near the player (user 2026-09-27: "allow the ability to sit on
## branchs to regain stamina"). The tree models' own branches are not where a climber comes out at the top of the
## trunk (the trunk collider ends where the crown starts), so each sturdy tree within RADIUS of the player gets one
## bark branch there: out from the trunk on a side of its own (a hash of the tree), rising a little, thick enough to sit
## on, with a small level floor on it (PerchFloor, a StaticBody3D) for a crouching climber's feet. Built as the player
## comes near and freed as they go (out of sight, among the crowns). PlayerGrip asks for the perch of the trunk it holds
## (perch_at), pulls the climber up onto it and leaves them crouched there (user: "no feet dangling more like a
## crouch"), weapons in hand. A felled tree's branches go with it (VegHarvest.remove_tree calls forget_tree; user
## 2026-09-28: "when we fell a tree, the climbable branches are still there"). A tree is climbed from branch to branch with E
## (user 2026-10-03; TreeClimb, PlayerGrip.climb_up / climb_down: perch_tier, has_branches, branch_mesh), and the floors are left
## out of the camera's spring arm (a climber hanging under one had the view pulled in onto their back).

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const GROUP := &"perch_branches"
const BARK_TEX := "res://assets/polyhaven/textures/structures/bark_brown_02/bark_brown_02_"
const RADIUS := 40.0
const KEEP := 48.0
const MIN_TRUNK_R := 0.18                ## thinner trunks get no branch (too slight to sit up in)
const LENGTH := 1.7
const R_BASE := 0.12
const R_TIP := 0.045
const RISE_DEG := 9.0
## The branch's root below the collider's top (the crown's start).
const DROP := 0.2
## The branches above the first: one every TIER_STEP m up the crown, at most MAX_TIERS, none within TOP_ROOM m of the top.
const TIER_STEP := 1.8
const MAX_TIERS := 5
const TOP_ROOM := 1.5

var player: FrontierPlayer
var _veg: Node
var _trees: Array = []               ## [{"i", "axis": Vector3 (ground), "r", "top", "dir": Vector3}] every sturdy tree
var _by_tree := {}                   ## a tree's layout index -> its entries of _trees (every tier: E's climb asks every frame)
var _live := {}                      ## tree index -> MeshInstance3D
var _t := 0.0
var _mat: Material
var _mat_birch: Material


static func install(p: FrontierPlayer) -> PerchBranches:
	var b := PerchBranches.new()
	b.name = "PerchBranches"
	b.player = p
	p.add_child.call_deferred(b)
	return b


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mat = _bark(Color(0.62, 0.52, 0.42))
	_mat_birch = _bark(Color(1.35, 1.3, 1.22))


func _bark(tint: Color) -> Material:
	var m := ORMMaterial3D.new()
	if ResourceLoader.exists(BARK_TEX + "diffuse_2k.jpg"):
		m.albedo_texture = load(BARK_TEX + "diffuse_2k.jpg")
		m.normal_enabled = true
		m.normal_texture = load(BARK_TEX + "nor_gl_2k.jpg")
		m.orm_texture = load(BARK_TEX + "arm_2k.jpg")
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	return m


## Every sturdy tree's trunk (as vegetation.gd sizes its collider), once the level's vegetation is there.
func _gather() -> bool:
	var lvl := get_tree().current_scene
	_veg = lvl.get("vegetation") if lvl else null
	if _veg == null or _veg.get("layout") == null:
		return false
	var lay = _veg.layout
	var hv := VegHarvest.of(_veg as FrontierVegetation)
	for i in lay.tree_pos.size():
		if lay.tree_collider[i] == 0 or (hv and hv.felled.has(i)):
			continue
		var info := Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		var s: float = lay.tree_scale[i]
		var r := clampf(float(info.get("trunk_radius", 0.3)) * s * 0.92, 0.1, 0.75)
		if r < MIN_TRUNK_R:
			continue
		var h := maxf(float(info.get("collider_height", 6.0)) * s, 3.3)
		var pos: Vector3 = lay.tree_pos[i]
		var a := float(hash(i * 7919 + 17) % 3600) / 3600.0 * TAU
		var birch := str(info.get("name", "")).begins_with("birch")
		# three branches round the trunk (a climber coming up anywhere is at most 60 degrees from one); (the collider's
		# top: vegetation.gd sinks it 0.3 m, and lengthens it by what it sinks more on a slope)
		var mine: Array = []
		for k in 3:
			var ak := a + TAU * float(k) / 3.0
			mine.append({"i": i * 16 + k, "tree": i, "tier": 0, "axis": pos, "r": r, "top": pos.y + h - 0.3 + 0.12 * float(k - 1),
					"dir": Vector3(sin(ak), 0.0, cos(ak)), "birch": birch})
		# higher up, a branch every TIER_STEP m through the crown (user 2026-10-01: "add more branches to allow us to climb higher"),
		# each round the trunk from the one under it, thinner as the trunk thins, to TOP_ROOM under the tree's top
		var full := float(info.get("height", h + 4.0)) * s
		var top0 := pos.y + h - 0.3
		for t in range(1, MAX_TIERS + 1):
			var y := top0 + TIER_STEP * float(t)
			if y > pos.y + full - TOP_ROOM:
				break
			var at := a + TAU * 0.38 * float(t)
			mine.append({"i": i * 16 + 2 + t, "tree": i, "tier": t, "axis": pos, "r": maxf(r * (1.0 - 0.14 * float(t)), 0.1), "top": y,
					"dir": Vector3(sin(at), 0.0, cos(at)), "birch": birch})
		_trees.append_array(mine)
		_by_tree[i] = mine
	return true


## Tree `tree` (a layout index) is gone: its branches and their floors with it, now and for good.
func forget_tree(tree: int) -> void:
	var keep: Array = []
	for tr: Dictionary in _trees:
		if int(tr.tree) != tree:
			keep.append(tr)
		elif _live.has(tr.i):
			_drop(_live[tr.i])
			_live.erase(tr.i)
	_trees = keep
	_by_tree.erase(tree)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	if _trees.is_empty() and not _gather():
		return
	var at := player.global_position
	for tr: Dictionary in _trees:
		var d := Vector2(tr.axis.x - at.x, tr.axis.z - at.z).length()
		var i: int = tr.i
		if d < RADIUS and not _live.has(i):
			_live[i] = [_build(tr), _floor(tr)]
		elif d > KEEP and _live.has(i):
			_drop(_live[i])
			_live.erase(i)


## A branch and its floor freed (the floor off the camera's list again).
func _drop(nodes: Array) -> void:
	var arm: SpringArm3D = player.spring_arm if player != null and is_instance_valid(player) else null
	for n: Node in nodes:
		if arm and n is CollisionObject3D:
			arm.remove_excluded_object((n as CollisionObject3D).get_rid())
		n.queue_free()


func _build(tr: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R_TIP
	cm.bottom_radius = R_BASE
	cm.height = LENGTH
	cm.radial_segments = 10
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = _mat_birch if bool(tr.birch) else _mat
	var dir := _way(tr)
	var base := _base(tr)
	# the cylinder's axis is its Y: along the branch, from its root (in the trunk) to its tip
	var y := dir
	var x := Vector3.UP.cross(y).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), base + y * (LENGTH * 0.5))
	add_child(mi)
	return mi


## The floor a crouching climber stands on: level, along the branch round the seat, its top on the branch's top.
func _floor(tr: Dictionary) -> StaticBody3D:
	var pr := _perch(tr)
	var b := StaticBody3D.new()
	b.name = "PerchFloor"
	b.set_meta(&"surface", "wood")
	b.set_meta(&"perch", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.08, 0.5)
	cs.shape = box
	b.add_child(cs)
	add_child(b)
	var d: Vector3 = tr.dir
	b.global_transform = Transform3D(Basis(d, Vector3.UP, d.cross(Vector3.UP)), (pr.seat as Vector3) - Vector3.UP * 0.04)
	# the camera's spring arm goes through it: a climber hanging under a branch (E's reach, the climb down) had the view pulled in
	# onto their back by the floor over their head (2026-10-03)
	if player != null and player.spring_arm != null:
		player.spring_arm.add_excluded_object(b.get_rid())
	return b


static func _way(tr: Dictionary) -> Vector3:
	var d: Vector3 = tr.dir
	return (d * cos(deg_to_rad(RISE_DEG)) + Vector3.UP * sin(deg_to_rad(RISE_DEG))).normalized()


## The branch's root: on the trunk's axis at the crown's start (a little in, so it grows out of the bark).
static func _base(tr: Dictionary) -> Vector3:
	var a: Vector3 = tr.axis
	return Vector3(a.x, float(tr.top) - DROP, a.z)


## The perch on the trunk whose axis is nearest `point` (the grip's anchor): of its branches the one on the side `point`
## is on; {} when none is near:
##   seat   the top of the branch `out` along it from the axis (world): where a crouching climber stands
##   dir    the branch's way out (level), "side" the level axis across it
##   floor  the PerchFloor on it
func perch_at(point: Vector3, out := -1.0) -> Dictionary:
	var best := {}
	var bd := INF
	for tr: Dictionary in _trees:
		if not _live.has(tr.i):
			continue
		var rel := Vector2(point.x - tr.axis.x, point.z - tr.axis.z)
		var d := rel.length()
		if d > float(tr.r) + 0.6:
			continue
		# the branches at the point's height (the first set for a climber at the trunk's top)
		var dy := absf(point.y - float(tr.top))
		if dy > TIER_STEP * 0.6:
			continue
		# nearest trunk first, then the branch most toward the point
		var dir: Vector3 = tr.dir
		var score := d - 0.1 * rel.normalized().dot(Vector2(dir.x, dir.z)) + 0.2 * dy
		if score < bd:
			bd = score
			best = tr
	if best.is_empty():
		return {}
	var pr := _perch(best, out)
	pr["floor"] = (_live[best.i] as Array)[1]
	return pr


static func _perch(tr: Dictionary, out := -1.0) -> Dictionary:
	var o := out if out > 0.0 else float(tr.r) + 0.42
	var way := _way(tr)
	var along := o / cos(deg_to_rad(RISE_DEG))
	var t := clampf(along / LENGTH, 0.0, 1.0)
	var rad := lerpf(R_BASE, R_TIP, t)
	var seat := _base(tr) + way * along + Vector3.UP * rad
	var dir: Vector3 = tr.dir
	return {"seat": seat, "dir": dir, "side": Vector3.UP.cross(dir).normalized(), "axis": tr.axis, "r": tr.r,
			"tree": tr.i, "tree_index": int(tr.tree), "tier": int(tr.get("tier", 0))}


## The branch `step` tiers up (or down, `step` < 0) from tier `tier` on tree `tree_index` (a layout index), as perch_at gives
## it ({} when that tree has none there, or it is not built near the player). Tier 0 is the first set (the branch most toward
## `toward` of its three).
func perch_tier(tree_index: int, tier: int, step: int, toward := Vector3.ZERO) -> Dictionary:
	var want := tier + step
	if want < 0:
		return {}
	var best := {}
	var bs := -INF
	for tr: Dictionary in _by_tree.get(tree_index, []):
		if int(tr.get("tier", 0)) != want or not _live.has(tr.i):
			continue
		var dir: Vector3 = tr.dir
		var s := dir.dot(toward)
		if s > bs:
			bs = s
			best = tr
	if best.is_empty():
		return {}
	var pr := _perch(best)
	pr["floor"] = (_live[best.i] as Array)[1]
	return pr


## Whether tree `tree_index` (a layout index) has branches to climb (a sturdy tree's, built near the player or not).
func has_branches(tree_index: int) -> bool:
	return _by_tree.has(tree_index)


## The bark branch of a perch (perch_at / perch_tier's dict), for E's highlight of the branch to climb to (null when it is not built).
func branch_mesh(pr: Dictionary) -> MeshInstance3D:
	var l: Array = _live.get(int(pr.get("tree", -1)), [])
	return l[0] as MeshInstance3D if not l.is_empty() and is_instance_valid(l[0]) else null
