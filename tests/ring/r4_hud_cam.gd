extends RefCounted
## Round 4 (HUD): the ring camera's two framings the strip must stay clear of, as plain numbers, and the player's body box on the
## screen under each (tests/ring/test_r4_hud.gd, tools/ring/r4_hud_shots.gd). The strip itself never reads a body (no cue): only
## this test helper does, to measure where the body falls.
##   A   round 3's camera (spec §4.8): the pivot eye_height 2.3 + 0.3 = 2.6 m over the feet, the arm 5.25 m
##   C   READ's default for round 4 (the owner's default 3: higher and centred): the pivot 3.4 m, the arm 6.0 m
## The shot aims at a chest 15 m ahead (1.3 m over the deck), as the task measures it.
##   const Cam := preload("res://tests/ring/r4_hud_cam.gd")
##   Cam.xf(feet, fwd, "A") -> the camera's Transform3D; Cam.box(points, xf, fov, size) -> the screen Rect2 of the points

const CAMS := {"A": {"pivot": 2.6, "arm": 5.25}, "C": {"pivot": 3.4, "arm": 6.0}}
const AIM_M := 15.0
const CHEST_M := 1.3


## The camera of framing `cam` ("A" | "C") behind feet `feet` looking along `fwd` (flat) through a chest AIM_M ahead.
static func xf(feet: Vector3, fwd: Vector3, cam: String) -> Transform3D:
	var c: Dictionary = CAMS.get(cam, CAMS.A)
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var piv := feet + Vector3.UP * float(c.pivot)
	var tgt := feet + f * AIM_M + Vector3.UP * CHEST_M
	var dir := (tgt - piv).normalized()
	var at := piv
	for i in 12:
		at = piv - dir * float(c.arm)
		dir = (tgt - at).normalized()
	return Transform3D(Basis.looking_at(dir, Vector3.UP), at)


## Point `p` on a screen of `size` px seen by a camera at `x` with vertical field of view `fov` (degrees; Camera3D's keep
## height); Vector2.INF behind the camera.
static func project(p: Vector3, x: Transform3D, fov: float, size: Vector2) -> Vector2:
	var l := x.affine_inverse() * p
	if l.z >= -0.01:
		return Vector2.INF
	var k := 1.0 / tan(deg_to_rad(fov) * 0.5)
	var nx := (l.x / -l.z) * k
	var ny := (l.y / -l.z) * k
	return Vector2(size.x * 0.5 + nx * size.y * 0.5, size.y * 0.5 - ny * size.y * 0.5)


## The screen box of world points `pts` (clipped to the screen).
static func box(pts: Array, x: Transform3D, fov: float, size: Vector2) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector3 in pts:
		var s := project(p, x, fov, size)
		if s == Vector2.INF:
			continue
		lo = lo.min(s)
		hi = hi.max(s)
	if lo.x == INF:
		return Rect2()
	lo = lo.clamp(Vector2.ZERO, size)
	hi = hi.clamp(Vector2.ZERO, size)
	return Rect2(lo, hi - lo)


## The corners of every mesh's box under `body` (its skinned meshes at rest, its garments: the visual body), in the world.
static func body_points(body: Node3D) -> Array:
	var out: Array = []
	for n in body.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var a := mi.get_aabb()
		if a.size.length() > 4.0:
			continue                            # (not a body part: a ground disc, an effect)
		for i in 8:
			out.append(mi.global_transform * a.get_endpoint(i))
	return out
