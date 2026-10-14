class_name CastGuide
extends MeshInstance3D
## Where a skill being aimed will go (the owner, 2026-10-13: "for drag to cast do we want to add guide lines and guide cast on
## where it should be", then "lets implement for mobile and non mobile"): drawn for the local player only, only while one of
## his skills locks or is held on the aim or the quick button (its wind-up, a charge, a finger dragged on touch), in its
## element's bright colour (Callouts.color_of: earth's gold, water's blue, fire's orange, air's white) over a dark edge (so that
## it reads on the light deck and the dark water alike), by the skill's shape:
##   shot     a line from where it leaves to where it meets the world or its reach ends, a ring there (none on a fighter)
##            (bolts, throws, the Spike, Lightning): its flight simulated as BendBolt flies it (its speed, its drop)
##   lobbed   the same dashed, a drop of LOBBED_G or more (the Boulder, the Ice Tomahawk), the ring where it lands
##   wave     a lane on the deck its width along his facing to its reach (the Fissure, the Kick's wave, the Gust)
##   cone     a wedge on the deck its reach and angle (Breath, the Wave, the Palm)
##   circle   a ring on the deck where it rises (the Column, the Geyser: FormEffects.place_point within its reach)
##   wall     a wall's footprint across his aim where it stands (the Earth, Fire, Ice and Wind Walls)
## Never a mark on a fighter (no target cues: the owner's rule): the line follows the crosshair's line (the caster's
## flight_point), not the aim's help, which stays unseen; nothing changes colour on a body. The jab, the guard and key 3 draw
## nothing. MatchSetup.cast_guides(): "always" (the default), "touch" (only with the touch layer up), "off".
## shown, shape and points (world) say what it drew this frame (the tests).

const LINE_W := 0.08
const EDGE_W := 0.17
const EDGE := Color(0.04, 0.05, 0.08, 0.5)
const DASH_M := 0.4
const RING_R := 0.32
const LIFT_M := 0.05
const STEP_S := 1.0 / 60.0
## A dropping shot's flight in at most this many raycast segments (the browser's physics is slow: 2026-10-14, "aiming on the
## web browser when casting it slowed": the Spike's 82 rays a frame cost 0.3 ms natively and several times that in a browser).
const SEG_MAX := 24
const LINE_A := 0.8
const FILL_A := 0.2
const LOBBED_G := 4.0
const NODE_NAME := &"CastGuide"

var player: FrontierPlayer
var shown := false
var shape := ""
var points := PackedVector3Array()
var _im: ImmediateMesh
var _cam_at := Vector3.ZERO


## The local player's guide (null when he has one already).
static func attach(p: FrontierPlayer) -> CastGuide:
	if p == null or p.get_node_or_null(NodePath(String(NODE_NAME))) != null:
		return null
	var g := CastGuide.new()
	g.name = NODE_NAME
	g.player = p
	p.add_child(g)
	return g


## Whether guides are drawn for `p` now (MatchSetup.cast_guides).
static func wanted(p: Node) -> bool:
	match MatchSetup.cast_guides():
		"off":
			return false
		"touch":
			return TouchControls.up(p)
	return true


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_im = ImmediateMesh.new()
	mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 10
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


func _process(_dt: float) -> void:
	_im.clear_surfaces()
	shown = false
	shape = ""
	points = PackedVector3Array()
	if player == null or not is_instance_valid(player) or not player.is_inside_tree() or not player.is_local or not wanted(player):
		return
	var c := SwayCaster.of(player)
	if c == null or c.state == SwayCaster.State.IDLE or not c.lock_src in [SwayCaster.SRC_AIM, SwayCaster.SRC_QUICK]:
		return
	var m := c.move
	if m == "" or BendR3.is_jab(m, c.mode_of(m)):
		return
	var bc := BendCaster.of(player)
	if bc == null or not bc.valid():
		return
	var cam := get_viewport().get_camera_3d()
	_cam_at = cam.global_position if cam != null else player.global_position + Vector3.UP * 3.0
	var el := Bending.element_of(m)
	var col := Callouts.color_of(el) if el != "" else SwayMoves.art_color(String(SwayMoves.move(m).get("art", "")))
	_build(c, bc, m, c.mode_of(m), col)


# ---------------------------------------------------------------- what it draws
func _build(c: SwayCaster, bc: BendCaster, m: String, md: String, col: Color) -> void:
	var d := SwayMoves.move(m)
	var facing := bc.facing()
	facing.y = 0.0
	facing = facing.normalized() if facing.length_squared() > 1e-6 else Vector3.FORWARD
	var p := player.global_position
	if m == "stone_form":
		# (the Spike, the Boulder: thrown from the stone carried before his hands, on the throw's arc for its drop)
		var hd: Dictionary = ((d.get("throw", {}) as Dictionary).get("hurl", {}) as Dictionary).get(md, {})
		var mps: Array = hd.get("mps", [30.0, 30.0])
		var g := float(hd.get("gravity", 4.0))
		var th := FormEffects.raised_of(player)
		var ex: Array = []
		var from := bc.launch_point(facing)
		if th != null and th.stone != null and is_instance_valid(th.stone):
			from = th.stone.global_position
			ex = [th.stone.get_rid()]
		var aim := bc.flight_point(ex)
		if aim == Vector3.INF:
			return
		var to := th._arced(aim) if th != null and th.lift != null and is_instance_valid(th.lift) else aim
		_shot(bc, from, (to - from).normalized() * float(mps[mps.size() - 1]), g, 45.0, col, g >= LOBBED_G, ex)
		return
	if m == "earth_wall":
		var wd: Dictionary = d.get("wall", {})
		var at := FormEffects.place_point(bc, {"min_m": 1.0, "max_m": maxf(float(d.get("range_m", 3.2)), 1.0)})
		_wall(at, p, float(wd.get("width_m", 3.0)), float(wd.get("thick_m", 0.6)), col)
		return
	var b: Variant = (d.get("bend", {}) as Dictionary).get(md)
	if not (b is Dictionary):
		return
	var spec := b as Dictionary
	if c.grown and spec.get("grow") is Dictionary:
		spec = spec.merged(spec.grow as Dictionary, true)       # (held on: the grown one's numbers, the Fireball's)
	var reach := float(spec.get("range_m", 16.0))
	match String(spec.get("do", "")):
		"bolt", "throw":
			var from := bc.launch_point(facing)
			var aim := bc.flight_point()
			if aim == Vector3.INF:
				return
			var g := float(spec.get("gravity", 0.0))
			_shot(bc, from, (aim - from).normalized() * float(spec.get("mps", 30.0)), g, reach, col, g >= LOBBED_G)
		"lightning":
			var from := bc.launch_point(facing)
			var aim := bc.flight_point()
			if aim == Vector3.INF:
				return
			_shot(bc, from, (aim - from).normalized() * 600.0, 0.0, reach, col, false)
		"floor_wave", "wind_wave":
			_lane(p + facing * 0.7, facing, float(spec.get("width_m", 2.2)), reach, col)
		"cone":
			_cone(p, facing, reach, float(spec.get("deg", 60.0)), col)
		"column", "spout":
			var at := FormEffects.place_point(bc, {"min_m": 0.5, "max_m": reach})
			_circle(at, float(spec.get("radius_m", 1.3)), col)
		"zone", "ice_wall", "wind_wall":
			if not spec.has("place") and String(spec.get("do", "")) == "zone":
				return                                    # (a zone that is not placed: a guard, a burn round him)
			var at := FormEffects.place_point(bc, spec.get("place", {}))
			_wall(at, p, float(spec.get("width_m", 3.0)), float(spec.get("thick_m", 0.6)), col)


## A shot's flight from `from` at `v` under drop `g` until it meets the world or has gone `reach`: drawn (dashed when lobbed)
## with a ring where it ends.
func _shot(bc: BendCaster, from: Vector3, v: Vector3, g: float, reach: float, col: Color, lobbed: bool, ex: Array = []) -> void:
	var space := player.get_world_3d().direct_space_state
	var exl: Array[RID] = bc.exclude()
	for r: Variant in ex:
		if r is RID:
			exl.append(r)
	var pts := PackedVector3Array([from])
	var normal := Vector3.ZERO
	var on_body := false
	var speed := maxf(v.length(), 0.1)
	# (a straight shot: one ray; a dropping one: its flight's own curve, from + v t - g t^2 / 2, at most SEG_MAX rays)
	var dt := (reach / speed) if g < 0.01 else maxf(STEP_S, reach / speed / float(SEG_MAX))
	var pos := from
	var went := 0.0
	for i in SEG_MAX * 3:
		var t := dt * float(i + 1)
		var q := from + v * t + Vector3.DOWN * (0.5 * g * t * t)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, q, 0xFFFFFFFF, exl))
		if not hit.is_empty():
			pts.append(hit.position)
			normal = hit.normal
			on_body = hit.collider is CharacterBody3D
			break
		went += pos.distance_to(q)
		pts.append(q)
		pos = q
		if went >= reach or pos.y < -40.0:
			break
	shape = "lobbed" if lobbed else "shot"
	points = pts
	shown = true
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c_line := Color(col.r, col.g, col.b, LINE_A)
	var end := pts[pts.size() - 1]
	var up := normal if normal != Vector3.ZERO else (_cam_at - end).normalized()
	var segs := PackedVector3Array()                   # (the pieces drawn, a pair each: the path's segments, or its dashes)
	if lobbed:
		var acc := 0.0
		for j in pts.size() - 1:
			acc = _dashes(pts[j], pts[j + 1], acc, segs)
	else:
		for j in pts.size() - 1:
			segs.append(pts[j])
			segs.append(pts[j + 1])
	for pass_i in 2:                                   # (the dark edge under, then the colour over it)
		var cc := EDGE if pass_i == 0 else c_line
		var w := EDGE_W if pass_i == 0 else LINE_W
		for k in range(0, segs.size(), 2):
			_ribbon(segs[k], segs[k + 1], cc, w)
		if not on_body:                                # (never a ring on a fighter: no target cues)
			_ring_on(end + up * 0.02, up, RING_R, cc, w)
	_im.surface_end()


## A lane on the deck from `at` along `way`, `w` wide and `reach` long.
func _lane(at: Vector3, way: Vector3, w: float, reach: float, col: Color) -> void:
	var y := FormEffects.ground_at(player, at).y + LIFT_M
	var side := Vector3.UP.cross(way).normalized() * w * 0.5
	var a := Vector3(at.x, y, at.z)
	var b := a + way * reach
	var quad := [a - side, a + side, b + side, b - side]
	shape = "wave"
	points = PackedVector3Array(quad)
	shown = true
	_fill_outline(quad, col)


## A wedge on the deck from `at` along `way`, `reach` long, `deg` wide.
func _cone(at: Vector3, way: Vector3, reach: float, deg: float, col: Color) -> void:
	var y := FormEffects.ground_at(player, at).y + LIFT_M
	var o := Vector3(at.x, y, at.z)
	var poly := [o]
	var half := deg_to_rad(deg) * 0.5
	for k in 13:
		var a := lerpf(-half, half, float(k) / 12.0)
		poly.append(o + way.rotated(Vector3.UP, a) * reach)
	shape = "cone"
	points = PackedVector3Array(poly)
	shown = true
	_fill_outline(poly, col)


## A ring on the deck at `at` of radius `r` (where a placed skill rises).
func _circle(at: Vector3, r: float, col: Color) -> void:
	if at == Vector3.INF:
		return
	var y := FormEffects.ground_at(player, at).y + LIFT_M
	var o := Vector3(at.x, y, at.z)
	var poly := []
	for k in 32:
		poly.append(o + Vector3(cos(TAU * k / 32.0), 0.0, sin(TAU * k / 32.0)) * r)
	shape = "circle"
	points = PackedVector3Array(poly)
	shown = true
	_fill_outline(poly, col)


## A wall's footprint at `at`, across the way from `from` to it: `w` long, `t` thick.
func _wall(at: Vector3, from: Vector3, w: float, t: float, col: Color) -> void:
	if at == Vector3.INF:
		return
	var way := at - from
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 1e-6 else Vector3.FORWARD
	var across := Vector3.UP.cross(way).normalized()
	var y := FormEffects.ground_at(player, at).y + LIFT_M
	var o := Vector3(at.x, y, at.z)
	var quad := [o - across * w * 0.5 - way * t * 0.5, o + across * w * 0.5 - way * t * 0.5,
			o + across * w * 0.5 + way * t * 0.5, o - across * w * 0.5 + way * t * 0.5]
	shape = "wall"
	points = PackedVector3Array(quad)
	shown = true
	_fill_outline(quad, col)


# ---------------------------------------------------------------- the mesh
## A flat shape on the deck (its points round it in order): filled faintly, its edge a line.
func _fill_outline(poly: Array, col: Color) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c_fill := Color(col.r, col.g, col.b, FILL_A)
	var o: Vector3 = poly[0]
	for k in range(1, poly.size() - 1):
		_im.surface_set_color(c_fill)
		_im.surface_add_vertex(o)
		_im.surface_set_color(c_fill)
		_im.surface_add_vertex(poly[k])
		_im.surface_set_color(c_fill)
		_im.surface_add_vertex(poly[k + 1])
	var c_line := Color(col.r, col.g, col.b, LINE_A)
	for k in poly.size():
		_flat_ribbon(poly[k], poly[(k + 1) % poly.size()], EDGE, EDGE_W)
	for k in poly.size():
		_flat_ribbon(poly[k], poly[(k + 1) % poly.size()], c_line, LINE_W)
	_im.surface_end()


## A lobbed shot's dashes (DASH_M on, DASH_M off) along its path from `a` to `b`, `acc` metres of the path laid before `a`,
## put into `out` a pair each: the metres laid after `b`.
func _dashes(a: Vector3, b: Vector3, acc: float, out: PackedVector3Array) -> float:
	var seg := a.distance_to(b)
	if seg < 1e-4:
		return acc
	var d := 0.0
	while d < seg:
		var into := fmod(acc + d, DASH_M * 2.0)
		var run := minf((DASH_M - into) if into < DASH_M else (DASH_M * 2.0 - into), seg - d)
		if into < DASH_M:
			out.append(a.lerp(b, d / seg))
			out.append(a.lerp(b, (d + run) / seg))
		d += maxf(run, 1e-3)
	return acc + seg


## A line from `a` to `b` facing the camera, `w` wide.
func _ribbon(a: Vector3, b: Vector3, col: Color, w := LINE_W) -> void:
	var along := b - a
	if along.length_squared() < 1e-8:
		return
	var side := along.cross(_cam_at - a)
	if side.length_squared() < 1e-8:
		return
	side = side.normalized() * w * 0.5
	_quad(a - side, a + side, b + side, b - side, col)


## A line from `a` to `b` lying flat on the deck, `w` wide.
func _flat_ribbon(a: Vector3, b: Vector3, col: Color, w := LINE_W) -> void:
	var along := b - a
	along.y = 0.0
	if along.length_squared() < 1e-8:
		return
	var side := Vector3.UP.cross(along).normalized() * w * 0.5
	_quad(a - side, a + side, b + side, b - side, col)


## A ring of radius `r` at `at` facing `up`, its line `w` wide.
func _ring_on(at: Vector3, up: Vector3, r: float, col: Color, w := LINE_W) -> void:
	var u := up.normalized() if up.length_squared() > 1e-6 else Vector3.UP
	var x := u.cross(Vector3.UP if absf(u.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := u.cross(x).normalized()
	var prev := at + x * r
	for k in range(1, 25):
		var a := TAU * k / 24.0
		var nxt := at + (x * cos(a) + z * sin(a)) * r
		var side := u.cross(nxt - prev).normalized() * w * 0.5
		_quad(prev - side, prev + side, nxt + side, nxt - side, col)
		prev = nxt


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_im.surface_set_color(col)                         # (the colour holds for the vertices after it)
	_im.surface_add_vertex(a)
	_im.surface_add_vertex(b)
	_im.surface_add_vertex(c)
	_im.surface_add_vertex(a)
	_im.surface_add_vertex(c)
	_im.surface_add_vertex(d)
