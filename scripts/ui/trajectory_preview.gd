class_name TrajectoryPreview
extends Node3D
## While a weapon with an arc is raised: a dotted arc from the launch point to where the shot will
## land at the current draw / wind-up strength, and a ring at the landing spot (red when it lands on
## something that takes damage). The arc is simulated exactly like the projectile flies (same
## zeroed launch direction, gravity, then drag, then move, per physics step), so a full draw ends on
## the crosshair and a weak one visibly falls short. The bow's arrow and every weapon with
## trajectory_params() (the thrown weapons: {origin, velocity, gravity, drag}) use it; one arc on
## the player draws the current weapon's (THROW: ThrowableArc is only the stand-alone variant for
## thrown weapons outside the roster).
##
## The range ladder on the arc (weapons_balance_design.md 1.9, hook H12; ArcCues): the dots fade
## past the weapon's current effective range (0.5 / tan(spread)) to 25 % at twice it, and the
## landing ring's radius is the scatter at that distance, clamp(d x tan(spread), 0.18, 1.5) m.
## Spread itself is not drawn.

@export var dot_spacing := 0.7        ## Metres between dots along the arc.
@export var max_time := 4.0           ## Seconds of flight simulated.
@export var color := Color(1.0, 0.97, 0.88, 0.75)
@export var hit_color := Color(1.0, 0.35, 0.25, 0.9)
## The range-ladder cues (H12): dot fade past the effective range and the scatter ring.
@export var range_cues := true

var player: FrontierPlayer
## When set, this weapon drives the arc even if it is not the player's current weapon (tests,
## previews); otherwise the player's current weapon.
var source: Weapon

var _dots: MultiMeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
const MAX_DOTS := 160


func _ready() -> void:
	top_level = true
	# The dots are placed in world space. top_level keeps the transform the node had when it was
	# set; created after the player has moved, that would offset every dot: pin it to the origin.
	global_transform = Transform3D.IDENTITY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.disable_receive_shadows = true
	var dot := SphereMesh.new()
	dot.radius = 0.022
	dot.height = 0.044
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = MAX_DOTS
	mm.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = mm
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)
	if range_cues:
		ArcCues.enable_colors(_dots)

	_ring_mat = mat.duplicate()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.2
	torus.rings = 24
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_set_visible(false)


## The arc of weapon `w` right now: {origin, velocity, gravity, drag}, or {} when it shows none.
## Weapons with trajectory_params() give their own; the bow's drawn arrow is built here.
func params_for(w: Weapon) -> Dictionary:
	if w == null or not w.active:
		return {}
	if w.has_method("trajectory_params"):
		return w.call("trajectory_params")
	var bow := w as Bow
	if bow == null or not bow.is_drawn():
		return {}
	var origin := bow.launch_origin()
	var dir := Weapon.ballistic_dir(origin, player.get_aim_point(), bow.max_arrow_speed, bow.arrow_gravity, 0.0)
	return {"origin": origin, "velocity": dir * bow.shot_speed(), "gravity": bow.arrow_gravity, "drag": 0.0}


## The weapon whose arc is drawn (`source`, else the player's current weapon).
func current_weapon() -> Weapon:
	if source:
		return source
	return player.weapon if player else null


func _physics_process(_delta: float) -> void:
	var w := current_weapon()
	var prm := params_for(w)
	if prm.is_empty():
		_set_visible(false)
		return
	draw_arc(prm, w.spread if range_cues else 0.0)


## Draws the arc of `prm` ({origin, velocity, gravity, drag}); spread_deg > 0 adds the range cues.
func draw_arc(prm: Dictionary, spread_deg := 0.0) -> void:
	var origin: Vector3 = prm.origin
	var vel: Vector3 = prm.velocity
	var g := float(prm.get("gravity", 9.8))
	var k := float(prm.get("drag", 0.0))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var space := get_world_3d().direct_space_state
	var mm := _dots.multimesh
	var cues := range_cues and spread_deg > 0.0 and mm.use_colors
	var count := 0
	var since_dot := dot_spacing * 0.5
	var pos := origin
	var hit := {}
	var t := 0.0
	while t < max_time and count < MAX_DOTS:
		vel.y -= g * dt
		if k > 0.0:
			vel *= maxf(1.0 - k * dt, 0.0)
		var next := pos + vel * dt
		var q := PhysicsRayQueryParameters3D.create(pos, next)
		if player:
			q.exclude = [player.get_rid()]
		hit = space.intersect_ray(q)
		if hit:
			break
		since_dot += pos.distance_to(next)
		if since_dot >= dot_spacing:
			since_dot = 0.0
			mm.set_instance_transform(count, Transform3D(Basis.IDENTITY, next))
			if cues:
				mm.set_instance_color(count, ArcCues.dot_color(origin, next, spread_deg))
			count += 1
		pos = next
		t += dt
	mm.visible_instance_count = count
	_dots.visible = true
	if hit:
		var n: Vector3 = hit.normal
		var up := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var b := Basis.looking_at(up.cross(n), n) if n.length_squared() > 0.5 else Basis.IDENTITY
		if cues:
			b = ArcCues.ring_basis(b, origin.distance_to(hit.position), spread_deg)
		_ring.global_transform = Transform3D(b, hit.position + n * 0.02)
		_ring_mat.albedo_color = hit_color if FrontierHUD._is_target(hit.collider as Node) else color
		_ring.visible = true
	else:
		_ring.visible = false


func _set_visible(v: bool) -> void:
	_dots.visible = v
	_ring.visible = v
