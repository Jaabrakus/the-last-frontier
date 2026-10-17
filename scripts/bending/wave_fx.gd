extends Node3D
## The Wave drawn as a wave (the anime pass, 2026-10-16; the owner: water "as close to Anime Style Avatar: The Last Airbender as
## possible"): one body of water that swells out of the deck before the caster, a back that climbs gently to a crest and a lip
## that curls forward over a hollow, a white foam lip along the crest, travelling out along `dir` at the cone's own speed
## (BendEffects.cone's travel_mps: its hits land as this front reaches them) and BREAKING at its reach: the lip falls, the
## body collapses, a crown of foam and drops stands up where it fell. Never hanging: it is gone a beat after its reach.
## Our own mesh, rebuilt every frame (ImmediateMesh, a profile swept along an arc), in ToonFx's cel water (water_crest).
## Looks only: BendEffects.cone made the hits; nothing here is a hitbox.
##   BendLooks.wave_front(at, dir, deg, reach, mps, tall)    makes one (loaded by its path, as GEYSER_FX)

const SEG := 24
const R0 := 0.7
const GROW_S := 0.18
const BREAK_S := 0.34
## The profile, local (x across the wave's thickness, forward +, in units of its thickness; y up, in units of its height):
## the back foot, the back climbing, the top, the lip (the curl moves it forward and down), the hollow under it, the front foot.
## The y of its first and last are on the deck.
const PROFILE_N := 9

var foot := Vector3.ZERO
var dir := Vector3.FORWARD
var span := 1.5
var reach := 5.0
var mps := 12.0
var tall := 1.2
var _t := 0.0
var _im := ImmediateMesh.new()
var _mi: MeshInstance3D
var _r := R0
var _broke := false
var _spray_t := 0.0
var _seed := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mi = MeshInstance3D.new()
	_mi.mesh = _im
	_mi.material_override = ToonFx.mat("water_crest")
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 4.0
	add_child(_mi)
	_seed = ToonFx.vis_rng.randf() * 6.0
	_draw(0.0, 0.2)


## The profile at `curl` (0 a swell .. 1 a lip fully over, 1.4 falling): [x, y] points.
static func profile(curl: float) -> Array[Vector2]:
	return [Vector2(-1.0, 0.0), Vector2(-0.72, 0.16), Vector2(-0.4, 0.46), Vector2(-0.08, 0.84), Vector2(0.28, 1.0),
			Vector2(0.55 + 0.5 * curl, 0.92 - 0.55 * curl), Vector2(0.3 + 0.3 * curl, 0.58 - 0.2 * curl), Vector2(0.18, 0.28),
			Vector2(0.08, 0.0)]


func _process(dt: float) -> void:
	_t += dt
	var moving := _r < reach and not _broke
	if moving:
		_r = minf(R0 + mps * _t, reach)
		var prog := clampf((_r - R0) / maxf(reach - R0, 0.1), 0.0, 1.0)
		var h := tall * smoothstep(0.0, GROW_S, _t) * (0.82 + 0.18 * sin(PI * prog))
		_draw(h, lerpf(0.15, 0.7, prog))
		_spray_t -= dt
		if _spray_t <= 0.0:
			_spray_t = 0.07
			_spray(h)
		if _r >= reach:
			_broke = true
			_t = 0.0
		return
	# breaking: the lip falls, the body sinks into the deck, a crown stands up where it fell
	var e := clampf(_t / BREAK_S, 0.0, 1.0)
	if e < 1.0:
		_r += mps * 0.18 * dt
		_draw(tall * (1.0 - e * e) * 0.9, lerpf(0.7, 1.45, e))
	if _t < dt * 1.5:
		_crown()
	if e >= 1.0:
		queue_free()


## The wave at radius `_r` from the foot, `h` high, its lip curled by `curl`: a closed profile swept along the arc, its normals
## the profile's (smooth), UV.x along the arc and UV.y along the profile (the foam lip: its crest).
func _draw(h: float, curl: float) -> void:
	_im.clear_surfaces()
	if h < 0.02:
		return
	var pr := profile(curl)
	var n := pr.size()
	var thick := clampf(h * 0.8, 0.3, 1.2)
	var fwd := Vector3(dir.x, 0.0, dir.z).normalized()
	var base_ang := atan2(fwd.x, fwd.z)
	# (the profile's outward normals, from its neighbours; the loop's closing edge is the deck)
	var nrm: Array[Vector2] = []
	for i in n:
		var a := pr[maxi(i - 1, 0)]
		var b := pr[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var c := Vector2(t.y, -t.x)
		nrm.append(c if c.dot(Vector2(pr[i].x, pr[i].y - 0.4)) >= 0.0 else -c)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in SEG:
		var u0 := float(s) / SEG
		var u1 := float(s + 1) / SEG
		for i in n - 1:
			var corners := []
			for q in 4:
				var us: float = u1 if q % 2 == 1 else u0
				var pi_: int = i + (1 if q >= 2 else 0)
				var ang := base_ang + (us - 0.5) * span
				var radial := Vector3(sin(ang), 0.0, cos(ang))
				# (taller in the middle of its arc, a ragged crest)
				var mid := 0.62 + 0.38 * cos((us - 0.5) * PI)
				var rag := 1.0 + 0.1 * sin(us * 31.0 + _seed) * pr[pi_].y
				var p := foot + radial * (_r + pr[pi_].x * thick) + Vector3.UP * (pr[pi_].y * h * mid * rag)
				var nm := radial * nrm[pi_].x + Vector3.UP * nrm[pi_].y
				corners.append([p, nm.normalized(), Vector2(us, float(pi_) / float(n - 1))])
			for tri: Array in [[0, 2, 1], [1, 2, 3]]:
				var a: Array = corners[tri[0]]
				var b: Array = corners[tri[1]]
				var c: Array = corners[tri[2]]
				var order: Array = tri
				# (front faces wind clockwise seen from outside: the cross points inward)
				if ((b[0] - a[0]) as Vector3).cross((c[0] - a[0]) as Vector3).dot(a[1] as Vector3) > 0.0:
					order = [tri[0], tri[2], tri[1]]
				for k in order:
					var v: Array = corners[k]
					_im.surface_set_normal(v[1])
					_im.surface_set_uv(v[2])
					_im.surface_add_vertex(v[0])
	_im.surface_end()


## Spray thrown off the lip as it runs.
func _spray(h: float) -> void:
	var pool := ToonFxPool.of(get_tree().current_scene) if is_inside_tree() else null
	if pool == null:
		return
	var fwd := Vector3(dir.x, 0.0, dir.z).normalized()
	var ang := atan2(fwd.x, fwd.z) + (ToonFx.vis_rng.randf() - 0.5) * span * 0.8
	var at := foot + Vector3(sin(ang), 0.0, cos(ang)) * (_r + 0.3) + Vector3.UP * h * 0.95
	var out := Vector3(sin(ang), 0.5, cos(ang))
	pool.shoot("drop", at, 3, out, 40.0, Vector2(1.5, 3.5), Vector2(0.06, 0.12), 0.55, Vector3(0, -10, 0), 0.0)
	if ToonFx.vis_rng.randf() < 0.5:
		pool.shoot("foam", at, 1, out, 50.0, Vector2(0.8, 2.0), Vector2(0.22, 0.4), 0.4, Vector3(0, -3, 0), 1.5)


## Where it broke: a crown of foam standing up along the arc's end and drops falling, a ripple running out.
func _crown() -> void:
	var pool := ToonFxPool.of(get_tree().current_scene) if is_inside_tree() else null
	if pool == null:
		return
	var fwd := Vector3(dir.x, 0.0, dir.z).normalized()
	var at := foot + fwd * _r
	var half := sin(span * 0.5) * _r
	pool.play("crown", Transform3D(Basis.looking_at(fwd, Vector3.UP), foot + Vector3.UP * 0.02), 0.5, _r * 0.96, _r * 1.0, BendLooks.WATER,
			BendLooks.FOAM, ToonFx.band_arc_mesh(1.0, 1.1, 0.8, span))
	pool.shoot("foam", at + Vector3.UP * 0.3, 10, fwd + Vector3.UP, 70.0, Vector2(1.0, 3.0), Vector2(0.3, 0.6), 0.6, Vector3(0, -2, 0), 1.0,
			{"r": half})
	pool.shoot("drop", at + Vector3.UP * 0.4, 16, fwd + Vector3.UP, 80.0, Vector2(2.0, 5.0), Vector2(0.07, 0.14), 0.7, Vector3(0, -10, 0), 0.0,
			{"r": half})
