class_name WorkerOrders
extends Node3D
## POINT AND CLICK (user 2026-09-30: "we do need to implement for npc like a point and click direction to go to"; the leader
## queues an action, the path finder sees it): L on a worker (the crosshair on her, or on the ground within PICK_M of her)
## picks her, a ring at her feet; L on the ground sends her there, Shift+L adds the place after the ones she has (Spouse
## .orders); L on her again lets her go. Her way there is planned once and walked with rays adjusting it (WalkPath): the
## plan is drawn on the ground in blue while she walks it, the places still to go to as posts.
## Before the click, with a worker picked and the crosshair on the ground, the ways there are drawn (WalkGrid.routes): the
## best in blue, one that goes round in green, a different way in orange, one over something in purple, each with its length;
## L sends her by the best, Ctrl+L by the second, Alt+L by the third. One in the level (ensure()), made by the first worker.

const ACTION := "order"
const KEY := KEY_L
## Reach of the crosshair (m), and how near a worker the ground may be picked to pick her.
const REACH_M := 160.0
const PICK_M := 1.3
const LINE_UP := 0.08
const BLUE := Color(0.3, 0.6, 1.0)
const RED := Color(1.0, 0.18, 0.15)
const KIND_COLOR := {"best": Color(0.3, 0.6, 1.0), "around": Color(0.35, 0.85, 0.4), "other": Color(1.0, 0.6, 0.2), "over": Color(0.75, 0.4, 1.0)}
## The preview is made again when the crosshair has moved this far on the ground (m), at most every PREVIEW_S.
const PREVIEW_MOVE_M := 2.0
const PREVIEW_S := 0.4
## The alternatives are shown for places within this of the worker (m): planning three ways takes 60-130 ms on a long trip.
const ALTERNATIVES_M := 120.0

var picked: Spouse = null
## The job the next place sent is for ("" just go there): set by the Talk tab's "Send her out to", spent by the click.
var next_act := ""
var _hint: Label3D
var _ring: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _posts: Array[MeshInstance3D] = []
## The routes to where the crosshair is: [{kind, way, len, cost, over}], for which point and picked worker.
var routes: Array = []
var _routes_at := Vector3.INF
var _routes_t := 0.0
## RouteDecision's answer for the same point: {} with a way, else {at, why} where the straight line is stopped (drawn in red).
var blocked: Dictionary = {}
var _refuse_t := 0.0
var _blocked_label: Label3D
var _routes_mesh: ImmediateMesh
var _routes_node: MeshInstance3D
var _labels: Array[Label3D] = []


static func ensure(tree: SceneTree) -> WorkerOrders:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var w := scene.get_node_or_null("WorkerOrders") as WorkerOrders
	if w != null:
		return w
	w = WorkerOrders.new()
	w.name = "WorkerOrders"
	scene.add_child.call_deferred(w)
	return w


func _ready() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var e := InputEventKey.new()
		e.physical_keycode = KEY
		InputMap.action_add_event(ACTION, e)
	if DisplayServer.get_name() == "headless":
		return
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 32
	_ring.mesh = tm
	_ring.material_override = _mat(Color(1.0, 0.85, 0.3))
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)
	_routes_mesh = ImmediateMesh.new()
	_routes_node = MeshInstance3D.new()
	_routes_node.mesh = _routes_mesh
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.no_depth_test = true            # (the leader's plan is seen through the crowns and the walls)
	rm.render_priority = 10
	_routes_node.material_override = rm
	_routes_node.top_level = true
	add_child(_routes_node)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = _mat(BLUE)
	_line.top_level = true
	add_child(_line)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed(ACTION):
		var pick := 2 if Input.is_key_pressed(KEY_ALT) else (1 if Input.is_key_pressed(KEY_CTRL) else 0)
		click(Input.is_key_pressed(KEY_SHIFT), pick)
	if picked != null and not is_instance_valid(picked):
		picked = null
	_preview(dt)
	_draw()


## The ways to the point under the crosshair while a worker is picked (made again when it has moved, and not too often).
func _preview(dt: float) -> void:
	_routes_t -= dt
	_refuse_t = maxf(_refuse_t - dt, 0.0)
	if picked == null or _routes_node == null:
		routes = []
		blocked = {}
		_routes_at = Vector3.INF
		return
	if _routes_t > 0.0:
		return
	var a := aim()
	if a.is_empty() or a.get("worker") != null:
		routes = []
		blocked = {}
		_routes_at = Vector3.INF
		return
	var p: Vector3 = a.pos
	if _routes_at != Vector3.INF and Vector2(p.x - _routes_at.x, p.z - _routes_at.z).length() < PREVIEW_MOVE_M:
		return
	_routes_t = PREVIEW_S
	_routes_at = p
	routes = _decided(picked, p, routes_for(picked, p))


## The ways put in the order RouteDecision would take them (the one it picks first: what L sends her by), or none and `blocked`
## says where the straight line is stopped.
func _decided(w: Spouse, p: Vector3, rs: Array) -> Array:
	var d := RouteDecision.decide(w, p, rs)
	blocked = {} if bool(d.ok) else (d.blocked as Dictionary)
	if not bool(d.ok):
		return []
	var out: Array = (d.routes as Array).duplicate()
	var pk := int(d.pick)
	if pk > 0:
		var first: Variant = out[pk]
		out.remove_at(pk)
		out.push_front(first)
	return out


## The ways for `w` to `p`: WalkGrid.routes with what she can do.
static func routes_for(w: Spouse, p: Vector3) -> Array:
	var g := WalkGrid.of(w.get_tree())
	var far := Vector2(p.x - w.global_position.x, p.z - w.global_position.z).length() > ALTERNATIVES_M
	return g.routes(w.global_position, p, w.nav.radius if w.nav != null else 0.3, w.abilities, not far) if g != null else []


## The crosshair's point and what it is on: {pos, worker} ({} when it points at nothing).
func aim() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH_M
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var ex: Array[RID] = []
	var player := get_tree().current_scene.get_node_or_null("Player") as CollisionObject3D
	if player:
		ex.append(player.get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position
	var w := _worker_of(hit.collider as Node)
	if w == null:
		var bd := PICK_M
		for n in get_tree().get_nodes_in_group(Spouse.KEEP):
			var s := n as Spouse
			if s != null and Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() < bd:
				bd = Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length()
				w = s
	return {"pos": p, "worker": w}


static func _worker_of(n: Node) -> Spouse:
	while n != null:
		if n is Spouse:
			return n as Spouse
		n = n.get_parent()
	return null


## L: pick the worker under the crosshair (again: let her go), or send the picked one to the ground under it (`queue`:
## after the places she has).
func click(queue := false, pick := 0) -> void:
	var a := aim()
	if a.is_empty():
		return
	var w: Spouse = a.get("worker")
	if w != null:
		picked = null if w == picked else w
		next_act = ""
		return
	if picked == null:
		return
	var act := next_act
	if not queue:
		next_act = ""
	var fresh := routes.is_empty() or _routes_at == Vector3.INF or Vector2(a.pos.x - _routes_at.x, a.pos.z - _routes_at.z).length() > PREVIEW_MOVE_M
	var rs := _decided(picked, a.pos, routes_for(picked, a.pos)) if fresh else routes
	if rs.is_empty():
		# no way there: the order is not given; the red line stays up a moment with what stops it
		_refuse_t = 2.5
		_routes_at = a.pos
		return
	var way := PackedVector3Array()
	if not rs.is_empty():
		way = (rs[mini(pick, rs.size() - 1)] as Dictionary).way
	order(picked, a.pos, queue, way, act)


## The Talk tab's "Send her out to <job>": picks her, and the next place pointed at (L) is where she does it.
func ask(w: Spouse, job: String) -> void:
	picked = w
	next_act = job


## Sends `w` to `p` (after the places she has, with `queue`), to do `act` there ("": only go).
static func order(w: Spouse, p: Vector3, queue := false, way := PackedVector3Array(), act := "") -> void:
	if not queue:
		w.orders.clear()
		w.order_ways.clear()
		w.order_acts.clear()
		w._order_set = false
		if w.nav != null:
			w.nav.reset()
	w.orders.append(p)
	w.order_ways.append(way)
	w.order_acts.append(act)


func _draw() -> void:
	if _ring == null:
		return
	_draw_routes()
	_ring.visible = picked != null
	_draw_hint()
	if picked == null:
		_line_mesh.clear_surfaces()
		for m in _posts:
			m.visible = false
		return
	var gp := picked.global_position
	_ring.global_position = gp + Vector3.UP * 0.05
	_line_mesh.clear_surfaces()
	var way := PackedVector3Array()
	if picked.nav != null and picked.nav.walk != null and not picked.orders.is_empty():
		way = picked.nav.walk.way
	if way.size() >= 2:
		# (a ribbon along the ground from where she is along the rest of the plan)
		var pts := PackedVector3Array([gp])
		var nb := WalkPath._nearest(way, gp)
		for i in range(int(nb[0]) + 1, way.size()):
			pts.append(way[i])
		_line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in pts.size() - 1:
			_ribbon(pts[i], pts[i + 1], 0.07)
		_line_mesh.surface_end()
	while _posts.size() < picked.orders.size():
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 1.2
		m.mesh = cm
		m.material_override = _mat(BLUE)
		m.top_level = true
		var tl := Label3D.new()
		tl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tl.no_depth_test = true
		tl.fixed_size = true
		tl.pixel_size = 0.0011
		tl.font_size = 36
		tl.outline_size = 8
		tl.modulate = BLUE
		tl.position = Vector3(0, 0.9, 0)
		m.add_child(tl)
		add_child(m)
		_posts.append(m)
	for i in _posts.size():
		_posts[i].visible = i < picked.orders.size()
		if _posts[i].visible:
			var o: Vector3 = picked.orders[i]
			_posts[i].global_position = Vector3(o.x, FrontierTerrain.height_at(o.x, o.z) + 0.6, o.z)
			var act := String(picked.order_acts[i]) if i < picked.order_acts.size() else ""
			var tag := _posts[i].get_child(0) as Label3D if _posts[i].get_child_count() > 0 else null
			if tag != null:
				tag.visible = act != ""
				tag.text = JobBook.name_of(act) if act != "" else ""


## Over the picked worker while a job waits for its place: what to do, and to point at where (L).
func _draw_hint() -> void:
	if _hint == null:
		_hint = Label3D.new()
		_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hint.no_depth_test = true
		_hint.fixed_size = true
		_hint.pixel_size = 0.0011
		_hint.font_size = 40
		_hint.outline_size = 10
		_hint.modulate = BLUE
		_hint.top_level = true
		add_child(_hint)
	_hint.visible = picked != null and next_act != ""
	if _hint.visible:
		_hint.text = "%s: point where (L)" % JobBook.name_of(next_act)
		_hint.global_position = picked.global_position + Vector3.UP * 2.3


## A flat strip from `a` to `b` over the ground (its points each set on the ground a metre apart).
func _ribbon(a: Vector3, b: Vector3, half: float) -> void:
	var d := b - a
	d.y = 0.0
	var n := maxi(ceili(d.length()), 1)
	var side := d.normalized().cross(Vector3.UP) * half if d.length() > 1e-3 else Vector3.RIGHT * half
	for i in n:
		var p0 := a + d * (float(i) / n)
		var p1 := a + d * (float(i + 1) / n)
		p0.y = FrontierTerrain.height_at(p0.x, p0.z) + LINE_UP
		p1.y = FrontierTerrain.height_at(p1.x, p1.z) + LINE_UP
		_line_mesh.surface_add_vertex(p0 - side)
		_line_mesh.surface_add_vertex(p1 - side)
		_line_mesh.surface_add_vertex(p1 + side)
		_line_mesh.surface_add_vertex(p0 - side)
		_line_mesh.surface_add_vertex(p1 + side)
		_line_mesh.surface_add_vertex(p0 + side)


## No way to the crosshair: a red ribbon from her to where the straight line is stopped, and what stops it.
func _draw_blocked() -> void:
	if _blocked_label == null:
		_blocked_label = Label3D.new()
		_blocked_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_blocked_label.no_depth_test = true
		_blocked_label.fixed_size = true
		_blocked_label.pixel_size = 0.0011
		_blocked_label.font_size = 40
		_blocked_label.outline_size = 10
		_blocked_label.modulate = RED
		_blocked_label.top_level = true
		add_child(_blocked_label)
	var show := picked != null and not blocked.is_empty() and routes.is_empty()
	_blocked_label.visible = show
	if not show:
		return
	var at: Vector3 = blocked.at
	_routes_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(picked.global_position, at, 0.22, RED)
	_routes_mesh.surface_end()
	_blocked_label.text = "No way: %s" % String(blocked.why)
	_blocked_label.global_position = Vector3(at.x, at.y + 1.6, at.z)


## The ways to the crosshair, each a coloured ribbon on the ground with its length over it.
func _draw_routes() -> void:
	_routes_mesh.clear_surfaces()
	_draw_blocked()
	if picked == null or routes.is_empty():
		for l in _labels:
			l.visible = false
		return
	_routes_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in routes.size():
		var r: Dictionary = routes[i]
		var kind := String(r.kind)
		if bool(r.over) and kind != "around":
			kind = "over" if kind != "best" or routes.size() > 1 else "best"
		var col: Color = KIND_COLOR.get(kind, BLUE)
		col.a = 1.0
		var way: PackedVector3Array = r.way
		var half := 0.28 if i == 0 else 0.2
		for k in way.size() - 1:
			_strip(way[k], way[k + 1], half, col)
	_routes_mesh.surface_end()
	while _labels.size() < routes.size():
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true                 # (the same size on the screen near or far)
		l.pixel_size = 0.0011
		l.font_size = 40
		l.outline_size = 10
		l.top_level = true
		add_child(l)
		_labels.append(l)
	for i in _labels.size():
		_labels[i].visible = i < routes.size()
		if _labels[i].visible:
			var r2: Dictionary = routes[i]
			var way2: PackedVector3Array = r2.way
			var mid := way2[way2.size() / 2]
			var tag: String = {"best": "fastest", "around": "round", "other": "or this way", "over": "over"}.get(String(r2.kind), "")
			if bool(r2.over):
				tag = "over"
			elif not (r2.get("doors", []) as Array).is_empty():
				tag = "through %s" % ("the door" if (r2.doors as Array).size() == 1 else "%d doors" % (r2.doors as Array).size())
			_labels[i].text = "%s  %d m%s" % [tag, roundi(float(r2.len)), "" if i == 0 else ("  (Ctrl+L)" if i == 1 else "  (Alt+L)")]
			_labels[i].modulate = KIND_COLOR.get(String(r2.kind), BLUE)
			_labels[i].global_position = Vector3(mid.x, FrontierTerrain.height_at(mid.x, mid.z) + 1.6 + 0.35 * i, mid.z)


func _strip(a: Vector3, b: Vector3, half: float, col: Color) -> void:
	var d := b - a
	d.y = 0.0
	var n := maxi(ceili(d.length()), 1)
	var side := d.normalized().cross(Vector3.UP) * half if d.length() > 1e-3 else Vector3.RIGHT * half
	for i in n:
		var p0 := a + d * (float(i) / n)
		var p1 := a + d * (float(i + 1) / n)
		p0.y = FrontierTerrain.height_at(p0.x, p0.z) + LINE_UP + 0.02
		p1.y = FrontierTerrain.height_at(p1.x, p1.z) + LINE_UP + 0.02
		for v: Vector3 in [p0 - side, p1 - side, p1 + side, p0 - side, p1 + side, p0 + side]:
			_routes_mesh.surface_set_color(col)
			_routes_mesh.surface_add_vertex(v)
