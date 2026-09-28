class_name FelledTree
extends Node3D
## A tree cut through above its stump (GatherTools, VegHarvest.remove_tree): it topples away from the axe,
## lies where it came down, and is bucked into logs where it lies.
##
## The fall is a rigid pole pivoting on the hinge the last cuts left (the stump's top): trunk and crown as a
## uniform pole with a share of the mass in the crown (gathering.json felling.crown_mass), so
##   theta'' = k * g / L * sin(theta),   k = (m_pole / 2 + m_crown * 0.7) / (m_pole / 3 + m_crown * 0.49)
## integrated every physics tick from a small lean and push (fall_start_deg, fall_push): it creaks over slowly,
## then comes down fast, in about 3-5 s for a 15-25 m tree. It comes to rest where the trunk or the crown meets
## the ground (a ray down at points along it; other trunks do not hold it up), with a small bounce. Anyone it
## sweeps through on the way down is hit once (Hit / apply_hit: felling.hurt_* by the speed of the pole there,
## half as much under the crown). It is a scripted rigid-body fall, not a PhysicsServer body: it cannot tumble
## or roll off a slope, and it can pass through the palisade and buildings.
##
## Down, it has a trunk collider (the bole, to the crown) and takes bucking: every `cut_work` of stroke power
## cuts one log off (logs_total, one per log_length_m of the clear bole); after the last log the crown is limbed
## into firewood and branches and the tree sinks away. The fallen tree stays whole to the eye while it is bucked
## (the logs go straight to the pack).
##
## Headless (tests) it has no mesh; the fall, the landing, the hits and the bucking are the same.

signal landed(felled: FelledTree)
## A hit on someone under the fall: the node hit and the damage.
signal struck(target: Node, damage: float)
## About LAND_LEAD_S before it meets the ground (its crash sound starts with the crown rushing down).
signal landing_soon(felled: FelledTree)

const LAND_LEAD_S := 0.43

const GROUP := &"felled_trees"
const G := 9.8

enum State { FALLING, SETTLING, DOWN, GONE }

var info := {}                 ## VegHarvest.describe() of the tree
var hinge := Vector3.ZERO      ## the pivot (the stump's top)
var fall_dir := Vector3.FORWARD
var length := 18.0             ## pivot to the top (m)
var theta := 0.0
var omega := 0.0
var state := State.FALLING
var logs_total := 1
var logs_left := 1
var cut_work := 3.0            ## stroke power per log
var work := 0.0                ## stroke power into the current cut
var hardness := 1.0
var trunk_body: StaticBody3D

var _k := 1.47
var _hit := {}                 ## instance id -> true (struck once)
var _settle_t := 0.0
var _cfg := {}
var _visual: MultiMeshInstance3D
var _sink_t := -1.0
var _warned := false
var _stump_h := 0.45


## Builds a falling tree for `d` (VegHarvest.describe of a felled tree) toppling toward `dir` (horizontal).
static func create(d: Dictionary, dir: Vector3, cfg: Dictionary, visuals: bool) -> FelledTree:
	var t := FelledTree.new()
	t.name = "FelledTree_%d" % int(d.get("i", 0))
	t.info = d
	t._cfg = cfg
	var stump_h := float(cfg.get("stump_height_m", 0.45))
	t._stump_h = stump_h
	var p: Vector3 = d.pos
	t.hinge = p + Vector3.UP * stump_h
	t.fall_dir = Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 1e-4 else Vector3.FORWARD
	t.length = maxf(float(d.get("height", 18.0)) - stump_h, 2.0)
	var mc := clampf(float(cfg.get("crown_mass", 0.35)), 0.0, 0.9)
	t._k = ((1.0 - mc) * 0.5 + mc * 0.7) / ((1.0 - mc) / 3.0 + mc * 0.49)
	t.theta = deg_to_rad(float(cfg.get("fall_start_deg", 1.5)))
	t.omega = float(cfg.get("fall_push", 0.12))
	var clear := float(d.get("height", 18.0)) * float(cfg.get("clear_frac", 0.5))
	t.logs_total = clampi(roundi(clear / float(cfg.get("log_length_m", 2.4))), 1, int(cfg.get("max_logs", 6)))
	t.logs_left = t.logs_total
	t.add_to_group(GROUP)
	t.position = t.hinge
	if visuals:
		t._build_visual(stump_h)
	t._apply_pose()
	return t


func _build_visual(stump_h: float) -> void:
	var Assets := VegHarvest.Assets
	var mesh := Assets.tree_mesh(int(info.kind), int(info.variant), 0)
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	var s := float(info.get("scale", 1.0))
	mm.set_instance_transform(0, Transform3D(Basis.from_euler(Vector3(0, float(info.get("yaw", 0.0)), 0)).scaled(Vector3.ONE * s),
			Vector3(0, -stump_h, 0)))
	var c: Color = info.get("custom", Color(0.5, 0.5, 0.5, 0.0))
	mm.set_instance_custom_data(0, c)
	_visual = MultiMeshInstance3D.new()
	_visual.name = "Tree"
	_visual.multimesh = mm
	_visual.material_override = Assets.tree_material(int(info.kind))
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_visual.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# a felled tree left lying is a full-detail tree: not drawn from afar (the forest's own LODs end ~100 m)
	_visual.visibility_range_end = 140.0
	_visual.visibility_range_end_margin = 10.0
	add_child(_visual)


## The pole's unit axis (hinge to top) at the current angle.
func axis() -> Vector3:
	return (Vector3.UP * cos(theta) + fall_dir * sin(theta)).normalized()


func top() -> Vector3:
	return hinge + axis() * length


func _apply_pose() -> void:
	# +Y (the pole) turned toward fall_dir about UP x fall_dir
	basis = Basis(Vector3.UP.cross(fall_dir).normalized(), theta)
	position = hinge
	if _visual:
		# the tree's mesh starts at the ground, the pivot is the cut: over the first 12 deg the butt slides up
		# the pole onto the stump, so no stub of trunk swings out behind the stump as it goes over
		var slide := _stump_h * smoothstep(0.0, deg_to_rad(12.0), theta)
		var xf := _visual.multimesh.get_instance_transform(0)
		xf.origin = Vector3(0, -_stump_h + slide, 0)
		_visual.multimesh.set_instance_transform(0, xf)


func is_down() -> bool:
	return state == State.DOWN


func _physics_process(delta: float) -> void:
	match state:
		State.FALLING:
			omega += _k * G / length * sin(theta) * delta
			theta += omega * delta
			if not _warned and omega > 0.3 and (PI * 0.5 - theta) / omega < LAND_LEAD_S:
				_warned = true
				landing_soon.emit(self)
			var tc := _contact_angle()
			if tc >= 0.0 and theta >= tc:
				theta = tc
				omega = -omega * 0.12
				state = State.SETTLING
				_settle_t = 0.0
				landed.emit(self)
			_strike()
			_apply_pose()
		State.SETTLING:
			_settle_t += delta
			omega += _k * G / length * sin(theta) * delta
			theta += omega * delta
			var tc := _contact_angle()
			if tc >= 0.0 and theta >= tc:
				theta = tc
				omega = -omega * 0.2
			if _settle_t > 0.6 or (absf(omega) < 0.02 and _settle_t > 0.2):
				if tc >= 0.0:
					theta = tc
				omega = 0.0
				state = State.DOWN
				_make_trunk_body()
			_apply_pose()
		State.GONE:
			if _sink_t >= 0.0:
				_sink_t += delta
				position = hinge + Vector3.DOWN * minf(_sink_t, 1.2) * 0.6
				if _sink_t >= 1.2:
					queue_free()


## The smallest angle (from upright) at which a point along the pole or its crown meets what is under it at
## this tree's heading: sampled points, each tested at the current angle (so a slope or a rock ahead stops it
## early); -1 while nothing is under it yet.
func _contact_angle() -> float:
	var r := float(info.get("radius", 0.3))
	var cb := float(info.get("crown_bottom", length * 0.4))
	var cr := float(info.get("crown_radius", 3.0))
	var best := -1.0
	for f: float in [0.3, 0.45, 0.6, 0.75, 0.9, 1.0]:
		var u := length * f
		var p := hinge + axis() * u
		var clear := r * (1.0 - 0.6 * f) if u < cb else cr * 0.25
		var g := _ground_under(p)
		if p.y - clear <= g:
			# the angle where this point would just touch: cos(t) = (g + clear - hinge.y) / u
			var c := clampf((g + clear - hinge.y) / u, -1.0, 1.0)
			var t := acos(c)
			best = t if best < 0.0 else minf(best, t)
	return best


func _ground_under(p: Vector3) -> float:
	var h := FrontierTerrain.height_at(p.x, p.z)
	if not is_inside_tree():
		return h
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0)
	if trunk_body:
		q.exclude = [trunk_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return h
	var col := hit.collider as Node
	if col and (col.is_in_group(&"trees") or col is CharacterBody3D):
		return h
	return maxf((hit.position as Vector3).y, h)


## Hits anyone the falling tree sweeps through (once each).
func _strike() -> void:
	if omega < 0.35 or not is_inside_tree():
		return
	var r := float(info.get("radius", 0.3))
	var cb := float(info.get("crown_bottom", length * 0.4))
	var cr := float(info.get("crown_radius", 3.0))
	var a := axis()
	for n in get_tree().get_nodes_in_group(&"player"):
		var body := n as Node3D
		if body == null or _hit.has(body.get_instance_id()) or not body.has_method("apply_hit"):
			continue
		var c := body.global_position + Vector3.UP * 0.9
		var u := clampf((c - hinge).dot(a), 0.0, length)
		var near := hinge + a * u
		var d := near.distance_to(c)
		var in_bole := u < cb and d < r + 0.4
		var in_crown := u >= cb and d < cr * 0.55
		if not (in_bole or in_crown):
			continue
		_hit[body.get_instance_id()] = true
		var v := omega * u
		var dmg := clampf(v * float(_cfg.get("hurt_per_mps", 7.0)), float(_cfg.get("hurt_min", 15.0)), float(_cfg.get("hurt_max", 110.0)))
		if in_crown:
			dmg *= 0.5
		var dir := (fall_dir * cos(theta) - Vector3.UP * sin(theta)).normalized()
		body.apply_hit(dmg, near, dir, self, "body")
		struck.emit(body, dmg)


func _make_trunk_body() -> void:
	if trunk_body or not is_inside_tree():
		return
	var r := maxf(float(info.get("radius", 0.3)) * 0.9, 0.08)
	var bole := clampf(float(info.get("crown_bottom", length * 0.4)), 1.0, length)
	trunk_body = StaticBody3D.new()
	trunk_body.name = "Trunk"
	trunk_body.set_meta(&"surface", "wood")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = bole
	cs.shape = cyl
	cs.position = Vector3(0, bole * 0.5, 0)   # local +Y is the pole's axis
	trunk_body.add_child(cs)
	add_child(trunk_body)


# --- Bucking ---------------------------------------------------------------------------------------

## Point on the bole nearest `p` (for the swing's aim and the chips), between the butt and the crown.
func bole_point(p: Vector3) -> Vector3:
	var a := axis()
	var bole := clampf(float(info.get("crown_bottom", length * 0.4)), 1.0, length)
	var u := clampf((p - hinge).dot(a), 0.4, bole)
	return hinge + a * u


## Point on the crown's stem nearest `p` (from the crown's bottom to the top): where its limbs are.
func crown_point(p: Vector3) -> Vector3:
	var a := axis()
	var cb := clampf(float(info.get("crown_bottom", length * 0.4)), 1.0, length)
	var u := clampf((p - hinge).dot(a), cb, length)
	return hinge + a * u


## Horizontal distance from `p` to the bole's surface.
func distance_from(p: Vector3) -> float:
	var q := bole_point(p)
	return Vector2(q.x - p.x, q.z - p.z).length() - float(info.get("radius", 0.3))


## A bucking stroke of `power`: returns {"logs": n cut by it, "limbed": true when the last log came off (the
## crown is then limbed and the tree goes)}.
func buck(power: float) -> Dictionary:
	var out := {"logs": 0, "limbed": false}
	if state != State.DOWN:
		return out
	work += power
	while work >= cut_work and logs_left > 0:
		work -= cut_work
		logs_left -= 1
		out.logs = int(out.logs) + 1
	if logs_left <= 0:
		out.limbed = true
		state = State.GONE
		_sink_t = 0.0
		if trunk_body:
			trunk_body.queue_free()
			trunk_body = null
	return out


## Firewood and branches the crown gives when it is limbed (gathering.json felling.*_per_crown_m).
func crown_yield() -> Dictionary:
	var cr := float(info.get("crown_radius", 3.0))
	return {"firewood": maxi(1, roundi(cr * float(_cfg.get("firewood_per_crown_m", 0.5)))),
			"branches": maxi(1, roundi(cr * float(_cfg.get("branches_per_crown_m", 0.8))))}


## "white pine": the species' name for the prompts.
func species_name() -> String:
	return String(info.get("name", String(info.get("species", "tree")).replace("_", " ")))


# --- The stump -------------------------------------------------------------------------------------

## The stump a felled tree leaves (GatherModels.stump: the trunk's bark and the fresh cut) with a wood collider
## low enough for a horse to step over.
static func make_stump(d: Dictionary, stump_h: float, visuals: bool) -> StaticBody3D:
	var r := float(d.get("radius", 0.3))
	var p: Vector3 = d.pos
	var body := StaticBody3D.new()
	body.name = "Stump_%d" % int(d.get("i", 0))
	body.add_to_group(FrontierVegetation.LOW_GROUP)
	body.set_meta(&"surface", "wood")
	body.position = p
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(r * 1.05, 0.08)
	cyl.height = stump_h + 0.3
	cs.shape = cyl
	cs.position = Vector3(0, (stump_h - 0.3) * 0.5, 0)
	body.add_child(cs)
	if visuals:
		var m := GatherModels.stump(r, stump_h, String(d.get("species", "")))
		m.rotation = Vector3(0, float(d.get("yaw", 0.0)), 0)
		for gi in m.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 70.0   # the vegetation's props end there too
		body.add_child(m)
	return body
