class_name ArcCues
## The range ladder on the aiming arc (weapons_balance_design.md section 1.9, hooks H12 and
## H15). Pure helpers: the arc owners (TrajectoryPreview for the bow, ThrowableArc for the
## throwables) call them; nothing here changes a control.
##
##   1. Fade past the current effective range: dots are full strength up to
##      d_eff = 0.5 / tan(spread), then fade linearly to 25 % at 2 x d_eff. `spread` is the
##      weapon's live cone, so the fade moves in when the player walks, undercharges or trembles.
##   2. The landing ring shows the scatter: radius clamp(d_hit x tan(spread), 0.18, 1.5) m.
##   Fallback (if 1-2 are not taken): the red "on a target" ring's alpha is scaled by the
##   torso-hit chance min(1, 0.25 / (d_hit tan(spread))).
##   H15 (optional, `show_blade_cue`): a tomahawk ring drawn grey at 40 % when the spin puts
##   the haft, not the blade, into the target.
##
## Hook H12, TrajectoryPreview (ThrowableArc inherits _ready; use its weapon `w` for `spread`):
##   _ready(), after the MultiMesh is made:     ArcCues.enable_colors(_dots)
##   dot loop, after set_instance_transform:    mm.set_instance_color(count, ArcCues.dot_color(origin, next, bow.spread))
##   ring placement:                            _ring.global_transform = Transform3D(ArcCues.ring_basis(b, origin.distance_to(hit.position), bow.spread), hit.position + n * 0.02)

const FADE_FLOOR := 0.25            ## Dot alpha factor at 2 x d_eff and beyond.
const RING_MIN := 0.18              ## m; TrajectoryPreview's torus (inner 0.16, outer 0.2) has this mid radius.
const RING_MAX := 1.5
const RING_MESH_RADIUS := 0.18
const HAFT_ALPHA := 0.4
const HAFT_GREY := Color(0.62, 0.62, 0.62)


## Lets the arc's MultiMesh carry a colour per dot (its alpha is the fade) and makes the dot
## material use it. Call once, after the MultiMesh and its mesh material exist.
static func enable_colors(dots: MultiMeshInstance3D) -> void:
	if dots == null or dots.multimesh == null:
		return
	var mm := dots.multimesh
	if not mm.use_colors:
		var n := mm.instance_count
		var visible_n := mm.visible_instance_count
		mm.instance_count = 0          # use_colors can only change while there are no instances
		mm.use_colors = true
		mm.instance_count = n
		mm.visible_instance_count = visible_n
		for i in n:
			mm.set_instance_color(i, Color.WHITE)
	var mat: Material = null
	if mm.mesh is PrimitiveMesh:
		mat = (mm.mesh as PrimitiveMesh).material
	elif mm.mesh and mm.mesh.get_surface_count() > 0:
		mat = mm.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).vertex_color_use_as_albedo = true


## Distance (m) up to which half the shots hit the torso disc with this cone.
static func effective_range(spread_deg: float) -> float:
	return BallisticsUtil.effective_range(spread_deg)


## Dot strength (0.25..1) at `dist` metres from the launch point.
static func dot_alpha(dist: float, spread_deg: float) -> float:
	var d_eff := effective_range(spread_deg)
	if dist <= d_eff:
		return 1.0
	return lerpf(1.0, FADE_FLOOR, clampf((dist - d_eff) / d_eff, 0.0, 1.0))


## Per-dot instance colour (white, alpha = the fade; the material keeps the arc colour).
static func dot_color(origin: Vector3, pos: Vector3, spread_deg: float) -> Color:
	return Color(1.0, 1.0, 1.0, dot_alpha(origin.distance_to(pos), spread_deg))


## Scatter ring radius (m) at the landing point `d_hit` metres from the launch point.
static func ring_radius(d_hit: float, spread_deg: float) -> float:
	return clampf(d_hit * tan(deg_to_rad(maxf(spread_deg, 0.0))), RING_MIN, RING_MAX)


## `b` (the ring's surface basis, torus Y along the normal) scaled in its own plane to the ring
## radius.
static func ring_basis(b: Basis, d_hit: float, spread_deg: float) -> Basis:
	var s := ring_radius(d_hit, spread_deg) / RING_MESH_RADIUS
	return b * Basis.from_scale(Vector3(s, 1.0, s))


## Fallback cue: `hit_color` with its alpha scaled by the torso-hit chance at `d_hit`.
static func hit_tint(hit_color: Color, d_hit: float, spread_deg: float) -> Color:
	var c := hit_color
	c.a *= BallisticsUtil.hit_chance(d_hit, spread_deg)
	return c


## H15: true when a tomahawk spinning at `spin_rate` rad/s (ThrowableTomahawk.spin_for) arrives
## after `t` seconds with the blade within `window_deg` of its launch attitude (blade first).
static func blade_first(spin_rate: float, t: float, window_deg := 50.0) -> bool:
	var a := fposmod(spin_rate * t, TAU)
	return rad_to_deg(minf(a, TAU - a)) <= window_deg


## H15 ring colour: `ring` unchanged for a blade hit, grey at 40 % for a haft hit.
static func blade_tint(ring: Color, spin_rate: float, t: float, window_deg := 50.0) -> Color:
	if blade_first(spin_rate, t, window_deg):
		return ring
	var c := HAFT_GREY
	c.a = HAFT_ALPHA
	return c
