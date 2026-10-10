class_name CascadeFx
extends Node3D
## UE4.22 Cascade runtime for one Spellbreak particle system spec (tools/reference_animation/fx_spec.py).
## Spellbreak (Proletariat) effects, rebuilt: ported from the Spellbreak FX browser's cascade.gd
## (artifacts/spellbreak_fx; provenance in assets/fx/spellbreak/SOURCE.md). Play effects through SpellFx
## (spell_fx.gd): it drives step(), follows nodes, pools and prewarms. The simulation below is the browser's,
## unchanged; the game adds only `fx_scale` (uniform size scale), `tint` (off by default), `ground_y` (the plane Collision
## bounces on), `effect_id`, particle_count(), tinted(), is_finished(), clear(), `hidden` (set_hidden), `rng` (its own dice in
## place of the global randf/randi), and (speed only, same results) the modules the per-frame path reads found once per
## emitter (Emitter.init) and a MultiMesh kept at its capacity with visible_instance_count.
##
## Units: specs are UE cm / UE axes (X forward, Y right, Z up). This node's local +X is
## UE +X; UE Y -> Godot +Z, UE Z -> Godot +Y (handedness swap); lengths x 0.01.
## Distributions are evaluated from the source's baked lookup tables.
##
## Per-instance data for materials: COLOR = particle colour (HDR) + alpha;
## INSTANCE_CUSTOM = dynamic parameters 0..3; the emitter's `extra_tex` (RGBA float,
## one texel per instance) = (sub-image + blend frac, flip bits, relative time, random).
## Sprites are oriented on the CPU: the instance basis columns 0/1 are the quad's world
## X/Y axes (already scaled), column 2 = facing normal.

## (Game) Every effect's dice (spawn counts, lifetimes, sizes, velocities, spins, sub-images): its own generator, never the
## global RNG, so playing an effect (or not: headless, switched off) leaves the game's own rolls (PlayerBendCaster's
## spread, a bot's pick) as they were under a test's seed. The same sequence the global RNG gave for the same seed (both
## are Godot's PCG): a capture that seeds it (rng.seed = hash(id)) draws what the browser draws with seed(hash(id)).
static var rng := RandomNumberGenerator.new()

const CM := 0.01
const MAX_LIGHTS := 6

var spec: Dictionary = {}
var lib                       # CascadeMaterials
var camera: Camera3D
## (Game) Emitters left out of this play, by name or "#<index in spec.emitters>" (SpellFx opts hide; a tuner's switch for an
## emitter that draws broken): they neither spawn, tick nor draw, and never hold the effect from finishing.
var hidden: PackedStringArray = []
var emitters: Array = []
var active := false
var events: Dictionary = {}   # name -> Array[Dictionary]
var comp_vel := Vector3()
var _last_comp := Vector3()
var _has_last_comp := false
var warnings: Dictionary = {}
## Game additions. Uniform scale of particle sizes, ribbon widths and light ranges (UE scales them by the
## component's scale; positions and velocities already scale with this node's basis: SpellFx sets both).
var fx_scale := 1.0
## Colour multiplier for every particle (rgb and alpha; alpha also drives the materials' erosion). Off by default.
var use_tint := false
var tint := Color(1, 1, 1, 1)
## Height of the plane the (approximated, ground-plane-only) Collision module bounces on; the browser's ground is 0.
var ground_y := 0.0
## The source package path this node plays (SpellFx's effect id).
var effect_id := ""


## (Game) A particle colour through the optional tint.
func tinted(c: Color) -> Color:
	return c * tint if use_tint else c


static func ue(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[2]), float(v[1])) * CM


static func ue_axes(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[2]), float(v[1]))


static func v3(a: PackedFloat32Array) -> Array:
	return [a[0], a[1] if a.size() > 1 else a[0], a[2] if a.size() > 2 else a[0]]


## FRawDistribution lookup: op 1 none, 2 random (lerp the two sub-entries by one
## random), 3 extreme (pick one sub-entry).
static func sample(t, time: float, rnd: float) -> PackedFloat32Array:
	if t == null or not (t is Dictionary) or not t.has("v"):
		return PackedFloat32Array([0.0, 0.0, 0.0])
	var v: Array = t.v
	var n: int = int(t.n)
	var stride: int = int(t.stride)
	var sub: int = int(t.sub)
	var op: int = int(t.op)
	var i0 := 0
	var i1 := 0
	var f := 0.0
	if n > 1:
		var x := clampf((time - float(t.tb)) * float(t.ts), 0.0, float(n - 1))
		i0 = int(floor(x))
		i1 = mini(i0 + 1, n - 1)
		f = x - float(i0)
	var out := PackedFloat32Array()
	out.resize(maxi(sub, 1))
	for k in sub:
		if i1 * stride + k >= v.size():
			break
		var a0: float = lerpf(float(v[i0 * stride + k]), float(v[i1 * stride + k]), f)
		if (op == 2 or op == 3) and i1 * stride + sub + k < v.size():
			var b0: float = lerpf(float(v[i0 * stride + sub + k]), float(v[i1 * stride + sub + k]), f)
			a0 = lerpf(a0, b0, rnd) if op == 2 else (b0 if rnd > 0.5 else a0)
		out[k] = a0
	return out


## sample(t, time, rnd)[0] without the array (the same arithmetic for the first component; most modules read one scalar).
static func s1(t, time: float, rnd: float) -> float:
	if t == null or not (t is Dictionary) or not t.has("v"):
		return 0.0
	var sub: int = int(t.sub)
	if sub < 1:
		return 0.0                      # (sample() leaves its one zero)
	var v: Array = t.v
	var n: int = int(t.n)
	var stride: int = int(t.stride)
	var i0 := 0
	var i1 := 0
	var f := 0.0
	if n > 1:
		var x := clampf((time - float(t.tb)) * float(t.ts), 0.0, float(n - 1))
		i0 = int(floor(x))
		i1 = mini(i0 + 1, n - 1)
		f = x - float(i0)
	if i1 * stride >= v.size():
		return 0.0
	var a0: float = lerpf(float(v[i0 * stride]), float(v[i1 * stride]), f)
	var op: int = int(t.op)
	if (op == 2 or op == 3) and i1 * stride + sub < v.size():
		var b0: float = lerpf(float(v[i0 * stride + sub]), float(v[i1 * stride + sub]), f)
		a0 = lerpf(a0, b0, rnd) if op == 2 else (b0 if rnd > 0.5 else a0)
	return a0


## (Game) Whether emitter spec `es` spawns by itself: a rate above 0 at the start, or a burst.
static func rate_or_bursts(es: Dictionary) -> bool:
	if es.rate and s1(es.rate, 0.0, 0.5) > 0.0:
		return true
	return not es.bursts.is_empty() and int(es.bursts[0].count) > 0


## (Game) Whether emitter spec `es` loops for ever on its own (loops 0): played without a stop() it never finishes
## (Emitter.done()). An emitter that only spawns from other emitters' events is left out: with no particles left nothing
## can send it one (is_finished()).
static func loops_forever(es: Dictionary) -> bool:
	if int(es.get("loops", 1)) != 0:
		return false
	for m: Dictionary in es.get("modules", []):
		if bool(m.get("enabled", false)) and String(m["class"]).trim_suffix("_Seeded") == "EventReceiverSpawn":
			return rate_or_bursts(es)
	return true


func setup(p_spec: Dictionary, p_lib, p_camera: Camera3D) -> void:
	for e in emitters:
		e.free_render()
	emitters.clear()
	warnings.clear()
	spec = p_spec
	lib = p_lib
	camera = p_camera
	var ei := -1
	for es: Dictionary in spec.emitters:
		ei += 1
		if not es.enabled:
			continue
		var inst := Emitter.new()
		inst.sys = self
		inst.index = ei
		inst.init(es)
		emitters.append(inst)


func warn(key: String) -> void:
	warnings[key] = int(warnings.get(key, 0)) + 1


## (Game) The emitters named in `names` ("Name" or "#index") left out of this play; [] shows them all again.
func set_hidden(names: PackedStringArray) -> void:
	hidden = names
	for e in emitters:
		e.hidden = not names.is_empty() and (String(e.s.get("name", "")) in names or ("#%d" % int(e.index)) in names)
		if e.hidden:
			e.particles.clear()
			e.spawning = false
			e.render()


func activate() -> void:
	active = true
	events.clear()
	_has_last_comp = false
	for e in emitters:
		e.reset()
		if e.hidden:
			e.spawning = false
	var warm := float(spec.get("system", {}).get("WarmupTime", 0.0))
	if warm > 0.0:
		var t := 0.0
		while t < warm:
			step(1.0 / 30.0)
			t += 1.0 / 30.0


func deactivate() -> void:
	active = false
	for e in emitters:
		e.deactivate()


## (Game) True when nothing more can appear: no particle is alive and every emitter that spawns by itself is done.
## Emitters that only spawn from other emitters' events (EventReceiverSpawn without rate or bursts) never end by
## themselves (done() stays false), so they are left out here: with no particles left nothing can send them an event.
func is_finished() -> bool:
	for e in emitters:
		if not e.particles.is_empty():
			return false
	for e in emitters:
		if e.hidden or (not e.m_receivers.is_empty() and not e._rate_or_bursts()):
			continue
		if not e.done():
			return false
	return true


## (Game) Every particle gone at once and nothing drawn (a pooled node waiting to be reused).
func clear() -> void:
	active = false
	events.clear()
	for e in emitters:
		e.particles.clear()
		e.spawning = false
	for e in emitters:
		e.render()


func particle_count() -> int:
	var n := 0
	for e in emitters:
		n += e.particles.size()
	return n


func step(dt: float) -> void:
	var here := global_position
	if _has_last_comp and dt > 0.0:
		comp_vel = (here - _last_comp) / dt
	_last_comp = here
	_has_last_comp = true
	var new_events: Dictionary = {}
	for e in emitters:
		if not e.hidden:
			e.tick(dt, new_events)
	events = new_events
	for e in emitters:
		if not e.hidden:
			e.consume_events(events)
	for e in emitters:
		if not e.hidden:
			e.render()


class Particle:
	var pos := Vector3()        # metres; component-local if local space else world
	var vel := Vector3()
	var base_vel := Vector3()
	var accel := Vector3()
	var base_size := Vector3.ONE
	var size := Vector3.ONE
	var age := 0.0
	var life := 1.0
	var rt := 0.0
	var rot := 0.0              # turns
	var base_rot_rate := 0.0
	var rot_rate := 0.0
	var mesh_rot := Vector3()   # turns (roll, pitch, yaw)
	var base_mesh_rot_rate := Vector3()
	var mesh_rot_rate := Vector3()
	var image := 0.0
	var flip := 0
	var base_color := Color(1, 1, 1, 1)
	var color := Color(1, 1, 1, 1)
	var dyn := [1.0, 1.0, 1.0, 1.0]
	var rnd := 0.0
	var trail_u := 0.0
	var collisions := 0
	var orbit_off := Vector3()
	var orbit_rot := Vector3()
	var orbit_rate := Vector3()
	var spawn_rnd := []


class Emitter:
	var sys: CascadeFx
	var s: Dictionary
	## (Game) its dice: CascadeFx.rng (never the global RNG the game's own rolls use)
	var dice: RandomNumberGenerator = CascadeFx.rng
	## (Game) its place in spec.emitters, and whether this play leaves it out (set_hidden)
	var index := -1
	var hidden := false
	var req: Dictionary
	var mods: Dictionary = {}
	var particles: Array = []
	var time := 0.0
	var loop := 0
	var delay_left := 0.0
	var duration := 1.0
	var spawning := true
	var killed := false
	var spawn_frac := 0.0
	var spu_frac := 0.0
	var bursts_fired: Array = []
	var last_loc := Vector3()
	var has_last := false
	var mm_inst: MultiMeshInstance3D
	var ribbon_inst: MeshInstance3D
	var ribbon_mesh: ImmediateMesh
	var extra_img: Image
	var extra_tex: ImageTexture
	var lights: Array = []
	var trail_len := 0.0
	var material: Material
	## (Game) The modules the per-frame path reads, found once in init() (they never change after it). all() / one() are
	## script calls, about 18 of them per particle per frame, over half the step: read these instead.
	var m_color: Array = []              # ColorOverLife
	var m_color_scale: Array = []        # ColorScaleOverLife
	var m_size_life: Array = []          # SizeMultiplyLife
	var m_size_scale: Array = []         # SizeScale
	var m_size_speed: Array = []         # SizeScaleBySpeed
	var m_vel_life: Array = []           # VelocityOverLifetime
	var m_accel_const: Array = []        # AccelerationConstant
	var m_accel_life: Array = []         # AccelerationOverLifetime
	var m_drag: Array = []               # AccelerationDrag
	var m_drag_scale: Array = []         # AccelerationDragScaleOverLife
	var m_attractor: Array = []          # AttractorPoint
	var m_gravity: Array = []            # AttractorPointGravity
	var m_dynamic: Array = []            # ParameterDynamic
	var m_rot_rate_mul: Array = []       # RotationRateMultiplyLife
	var m_rot_life: Array = []           # RotationOverLifetime
	var m_mesh_rate_mul: Array = []      # MeshRotationRateMultiplyLife
	var m_mesh_rate_life: Array = []     # MeshRotationRateOverLife
	var m_events: Array = []             # EventGenerator
	var m_receivers: Array = []          # EventReceiverSpawn
	var m_collision = null               # Collision (the first), else null
	var m_camera_offset = null           # CameraOffset
	var m_axis_lock = null               # OrientationAxisLock
	var m_mesh_rot = null                # MeshRotation
	var m_light = null                   # Light
	var has_orbit := false
	var has_subuv := false
	var has_subuv_movie := false
	## SubUV sub-images picked at random once (the method), so SubUV does not drive them over life
	var subuv_random := false
	var subuv_images := 1

	func init(spec_: Dictionary) -> void:
		s = spec_
		req = s.get("required_raw", {})
		for m: Dictionary in s.modules:
			if not m.enabled:
				continue
			var cls: String = String(m["class"]).trim_suffix("_Seeded")
			if mods.has(cls) and cls != "SubUV":
				# several modules of one class stack in UE; keep a list
				if not (mods[cls] is Array):
					mods[cls] = [mods[cls]]
				mods[cls].append(m)
				continue
			if cls == "SubUV" and mods.has("SubUV"):
				continue
			mods[cls] = m
		for k in ["VectorFieldLocal", "VectorFieldRotationRate", "VectorFieldRotation", "LocationSkelVertSurface"]:
			if mods.has(k):
				sys.warn("approximated:" + k)
		m_color = all("ColorOverLife")
		m_color_scale = all("ColorScaleOverLife")
		m_size_life = all("SizeMultiplyLife")
		m_size_scale = all("SizeScale")
		m_size_speed = all("SizeScaleBySpeed")
		m_vel_life = all("VelocityOverLifetime")
		m_accel_const = all("AccelerationConstant")
		m_accel_life = all("AccelerationOverLifetime")
		m_drag = all("AccelerationDrag")
		m_drag_scale = all("AccelerationDragScaleOverLife")
		m_attractor = all("AttractorPoint")
		m_gravity = all("AttractorPointGravity")
		m_dynamic = all("ParameterDynamic")
		m_rot_rate_mul = all("RotationRateMultiplyLife")
		m_rot_life = all("RotationOverLifetime")
		m_mesh_rate_mul = all("MeshRotationRateMultiplyLife")
		m_mesh_rate_life = all("MeshRotationRateOverLife")
		m_events = all("EventGenerator")
		m_receivers = all("EventReceiverSpawn")
		m_collision = one("Collision")
		m_camera_offset = one("CameraOffset")
		m_axis_lock = one("OrientationAxisLock")
		m_mesh_rot = one("MeshRotation")
		m_light = one("Light")
		has_orbit = mods.has("Orbit")
		has_subuv = mods.has("SubUV")
		has_subuv_movie = mods.has("SubUVMovie")
		subuv_random = String(s.get("subuv_method", "")).begins_with("PSUVIM_Random")
		subuv_images = maxi(int(s.subuv[0]) * int(s.subuv[1]), 1)
		duration = float(s.duration)
		_make_render()

	func all(cls: String) -> Array:
		if not mods.has(cls):
			return []
		return mods[cls] if mods[cls] is Array else [mods[cls]]

	func one(cls: String):
		var a := all(cls)
		return a[0] if not a.is_empty() else null

	func _make_render() -> void:
		material = sys.lib.material_for_emitter(s) if sys.lib else null
		if s.type == "ribbon" or s.type == "beam" or s.type == "anim_trail":
			ribbon_mesh = ImmediateMesh.new()
			ribbon_inst = MeshInstance3D.new()
			ribbon_inst.mesh = ribbon_mesh
			ribbon_inst.material_override = material
			ribbon_inst.top_level = true
			ribbon_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ribbon_inst.extra_cull_margin = 10000.0
			sys.add_child(ribbon_inst)
			return
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		if s.type == "mesh":
			mm.mesh = sys.lib.mesh(s.get("mesh", "")) if sys.lib else null
			if mm.mesh == null:
				sys.warn("missing mesh:" + str(s.get("mesh")))
				mm.mesh = SphereMesh.new()
		else:
			var q := QuadMesh.new()
			q.size = Vector2.ONE
			mm.mesh = q
		mm_inst = MultiMeshInstance3D.new()
		mm_inst.multimesh = mm
		mm_inst.material_override = material
		mm_inst.top_level = true
		mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm_inst.extra_cull_margin = 10000.0
		sys.add_child(mm_inst)
		extra_img = Image.create(256, 1, false, Image.FORMAT_RGBAF)
		extra_tex = ImageTexture.create_from_image(extra_img)
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("extra_tex", extra_tex)

	func free_render() -> void:
		if mm_inst:
			mm_inst.queue_free()
		if ribbon_inst:
			ribbon_inst.queue_free()
		for l in lights:
			l.queue_free()

	func reset() -> void:
		particles.clear()
		time = 0.0
		loop = 0
		delay_left = float(s.delay)
		if req.get("bEmitterDelayUseRange", false):
			delay_left = dice.randf_range(float(s.delay_low), float(s.delay))
		duration = float(s.duration)
		if req.get("bEmitterDurationUseRange", false):
			duration = dice.randf_range(float(s.duration_low), float(s.duration))
		spawning = true
		killed = false
		spawn_frac = 0.0
		spu_frac = 0.0
		bursts_fired = []
		bursts_fired.resize(s.bursts.size())
		bursts_fired.fill(false)
		has_last = false
		trail_len = 0.0

	func deactivate() -> void:
		spawning = false
		if s.kill_on_deactivate:
			particles.clear()
			killed = true

	func done() -> bool:
		return particles.is_empty() and (not spawning or killed or (int(s.loops) == 0 and not sys.active))

	func comp() -> Transform3D:
		return sys.global_transform

	func loc_now() -> Vector3:
		return comp() * CascadeFx.ue(s.origin)

	func tick(dt: float, out_events: Dictionary) -> void:
		var loc := loc_now()
		if not has_last:
			last_loc = loc
			has_last = true
		_update(dt, out_events)
		if spawning and sys.active and (m_receivers.is_empty() or _rate_or_bursts()):
			_spawn_step(dt, loc, out_events)
		last_loc = loc

	func _rate_or_bursts() -> bool:
		return CascadeFx.rate_or_bursts(s)

	func consume_events(evs: Dictionary) -> void:
		for m in m_receivers:
			var name := String(m.get("EventName", ""))
			var list: Array = evs.get(name, [])
			for ev: Dictionary in list:
				var want := String(m.get("EventGeneratorType", "EPET_Any"))
				if want != "EPET_Any" and want != String(ev.type):
					continue
				var count := int(round(CascadeFx.s1(m.get("SpawnCount"), 0.0, dice.randf())))
				for i in count:
					var p = _spawn_one(ev.pos if not m.get("bUsePSysLocation", false) else loc_now(), 0.0, {})
					if p and m.get("bInheritVelocity", false):
						var sc: PackedFloat32Array = CascadeFx.sample(m.get("InheritVelocityScale"), 0.0, dice.randf())
						p.vel += ev.vel * CascadeFx.ue_axes(CascadeFx.v3(sc))
						p.base_vel = p.vel

	func _spawn_step(dt: float, loc: Vector3, out_events: Dictionary) -> void:
		var t := dt
		if delay_left > 0.0:
			delay_left -= dt
			if delay_left > 0.0:
				return
			t = -delay_left
			delay_left = 0.0
		var t0 := time
		time += t
		var wants: Array = []
		var process_rate := true
		var spu = one("SpawnPerUnit")
		if spu != null:
			var dist_cm := loc.distance_to(last_loc) / CascadeFx.CM
			if spu.get("bIgnoreSpawnRateWhenMoving", false) and dist_cm > 0.0:
				process_rate = false
			var per := CascadeFx.s1(spu.SpawnPerUnit, t0, dice.randf())
			var acc: float = spu_frac + dist_cm / maxf(float(spu.get("UnitScalar", 50.0)), 0.001) * per
			var whole := int(floor(acc))
			spu_frac = acc - whole
			for i in whole:
				wants.append((float(i) + 1.0) / float(whole))
		if process_rate and s.rate:
			var rate := CascadeFx.s1(s.rate, t0 / maxf(duration, 1e-4), dice.randf())
			if s.rate_scale:
				rate *= CascadeFx.s1(s.rate_scale, t0 / maxf(duration, 1e-4), dice.randf())
			var count := rate * t + spawn_frac
			var whole := int(floor(count))
			spawn_frac = count - whole
			for i in whole:
				wants.append(clampf((float(i) + 1.0 - spawn_frac) / maxf(count, 1e-6), 0.0, 1.0))
		for b in s.bursts.size():
			var bt: float = float(s.bursts[b].time) * duration
			if not bursts_fired[b] and bt <= time:
				bursts_fired[b] = true
				var c: int = int(s.bursts[b].count)
				var lo: int = int(s.bursts[b].low)
				if lo >= 0:
					c = dice.randi_range(mini(lo, c), maxi(lo, c))
				if s.burst_scale:
					c = int(round(c * CascadeFx.s1(s.burst_scale, t0, dice.randf())))
				for i in c:
					wants.append(clampf((bt - t0) / maxf(t, 1e-6), 0.0, 1.0))
		for f: float in wants:
			var p = _spawn_one(lerp(last_loc, loc, f), (1.0 - f) * dt, out_events)
			if p:
				_emit_event(p, "EPET_Spawn", out_events)
		if time >= duration:
			loop += 1
			if int(s.loops) > 0 and loop >= int(s.loops):
				spawning = false
			else:
				time -= duration
				bursts_fired.fill(false)
				if not s.delay_first_only:
					delay_left = float(s.delay)

	func _emit_event(p: Particle, type: String, out_events: Dictionary) -> void:
		for m in m_events:
			for ev in m.get("Events", []):
				if not (ev is Dictionary):
					continue
				if String(ev.get("Type", "")) != type:
					continue
				var name := String(ev.get("CustomName", ""))
				if not out_events.has(name):
					out_events[name] = []
				out_events[name].append({"pos": world_pos(p), "vel": world_vel(p), "type": type})

	func _spawn_one(world_loc: Vector3, age: float, out_events: Dictionary):
		var p := Particle.new()
		p.rnd = dice.randf()
		var et := time / maxf(duration, 1e-4)
		var lp := Vector3()
		var lv := Vector3()
		var m = one("Lifetime")
		if m != null:
			var lt := CascadeFx.s1(m.Lifetime, et, dice.randf())
			# UE: a lifetime of 0 means the particle never ages out (OneOverMaxLifetime = 0)
			p.life = lt if lt > 0.0 else INF
		m = one("Size")
		if m != null:
			var sz := CascadeFx.sample(m.StartSize, et, dice.randf())
			p.base_size = Vector3(sz[0], sz[1] if sz.size() > 1 else sz[0], sz[2] if sz.size() > 2 else sz[0])
		p.size = p.base_size
		for mv in all("Velocity"):
			var v := CascadeFx.sample(mv.StartVelocity, et, dice.randf())
			var vel := CascadeFx.ue(CascadeFx.v3(v))
			if mv.get("bInWorldSpace", false):
				vel = comp().basis.inverse() * vel
			lv += vel
			var radial := CascadeFx.s1(mv.get("StartVelocityRadial"), et, dice.randf())
			if radial != 0.0:
				p.spawn_rnd.append(radial)
		for ml in all("Location"):
			lp += CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(ml.StartLocation, et, dice.randf())))
		for ms in all("LocationPrimitiveSphere"):
			var r := CascadeFx.s1(ms.StartRadius, et, dice.randf())
			var dir := Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1))
			var tries := 0
			while (dir.length_squared() > 1.0 or dir.length_squared() < 1e-6) and tries < 20:
				dir = Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1))
				tries += 1
			# axis flags (UE X, Y, Z)
			if not ms.get("Positive_X", true): dir.x = -absf(dir.x)
			if not ms.get("Negative_X", true): dir.x = absf(dir.x)
			if not ms.get("Positive_Y", true): dir.y = -absf(dir.y)
			if not ms.get("Negative_Y", true): dir.y = absf(dir.y)
			if not ms.get("Positive_Z", true): dir.z = -absf(dir.z)
			if not ms.get("Negative_Z", true): dir.z = absf(dir.z)
			var off := dir.normalized() * r if ms.get("SurfaceOnly", false) else dir * r
			var st := CascadeFx.v3(CascadeFx.sample(ms.get("StartLocation"), et, dice.randf()))
			lp += CascadeFx.ue([off.x + st[0], off.y + st[1], off.z + st[2]])
			if ms.get("Velocity", false):
				lv += CascadeFx.ue([off.x, off.y, off.z]) * CascadeFx.s1(ms.get("VelocityScale"), et, dice.randf())
		for mc in all("LocationPrimitiveCylinder"):
			var r := CascadeFx.s1(mc.StartRadius, et, dice.randf())
			var h := CascadeFx.s1(mc.StartHeight, et, dice.randf())
			var a := dice.randf() * TAU
			var rr := r if mc.get("SurfaceOnly", false) else sqrt(dice.randf()) * r
			var st := CascadeFx.v3(CascadeFx.sample(mc.get("StartLocation"), et, dice.randf()))
			var off := Vector3(cos(a) * rr, sin(a) * rr, dice.randf_range(-0.5, 0.5) * h)
			lp += CascadeFx.ue([off.x + st[0], off.y + st[1], off.z + st[2]])
			if mc.get("Velocity", false):
				var radial := Vector3(off.x, off.y, 0.0) if mc.get("RadialVelocity", true) else off
				lv += CascadeFx.ue([radial.x, radial.y, radial.z]) * CascadeFx.s1(mc.get("VelocityScale"), et, dice.randf())
		for mt in all("LocationPrimitiveTriangle"):
			var h := CascadeFx.s1(mt.get("Height"), et, dice.randf())
			var ang := deg_to_rad(CascadeFx.s1(mt.get("Angle"), et, dice.randf()))
			var u := dice.randf()
			var w := dice.randf() * u
			var off := Vector3(u * h, (w - u * 0.5) * 2.0 * tan(ang * 0.5) * h, 0.0)
			var so := CascadeFx.v3(CascadeFx.sample(mt.get("StartOffset"), et, dice.randf()))
			lp += CascadeFx.ue([off.x + so[0], off.y + so[1], off.z + so[2]])
		if mods.has("LocationSkelVertSurface"):
			var dir := Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1)).normalized()
			lp += CascadeFx.ue([dir.x * 30.0, dir.y * 30.0, dir.z * 80.0 + 90.0])
		for me in all("LocationEmitter") + all("LocationEmitterDirect"):
			var src := String(me.get("EmitterName", ""))
			for other in sys.emitters:
				if String(other.s.name) == src and not other.particles.is_empty():
					var q: Particle = other.particles[dice.randi() % other.particles.size()]
					var wpos: Vector3 = other.world_pos(q)
					lp += comp().affine_inverse() * wpos - CascadeFx.ue(s.origin)
					if me.get("InheritSourceVelocity", false) or me["class"] == "LocationEmitterDirect":
						lv += comp().basis.inverse() * other.world_vel(q)
					break
		m = one("Color")
		if m != null:
			var c := CascadeFx.sample(m.get("StartColor"), et, dice.randf())
			p.base_color = Color(c[0], c[1] if c.size() > 1 else c[0], c[2] if c.size() > 2 else c[0], CascadeFx.s1(m.get("StartAlpha"), et, dice.randf()) if m.has("StartAlpha") else 1.0)
		p.color = p.base_color
		m = one("Rotation")
		if m != null:
			p.rot = CascadeFx.s1(m.StartRotation, et, dice.randf())
		m = one("RotationRate")
		if m != null:
			p.base_rot_rate = CascadeFx.s1(m.StartRotationRate, et, dice.randf())
			p.rot_rate = p.base_rot_rate
		m = one("MeshRotation")
		if m != null:
			var r := CascadeFx.sample(m.StartRotation, et, dice.randf())
			p.mesh_rot = Vector3(r[0], r[1] if r.size() > 1 else 0.0, r[2] if r.size() > 2 else 0.0)
		m = one("MeshRotationRate")
		if m != null:
			var r := CascadeFx.sample(m.StartRotationRate, et, dice.randf())
			p.base_mesh_rot_rate = Vector3(r[0], r[1] if r.size() > 1 else 0.0, r[2] if r.size() > 2 else 0.0)
			p.mesh_rot_rate = p.base_mesh_rot_rate
		m = one("Acceleration")
		if m != null:
			var a := CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.Acceleration, et, dice.randf())))
			p.accel = a if m.get("bAlwaysInWorldSpace", false) else comp().basis * a
		m = one("Orbit")
		if m != null:
			p.orbit_off = CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.get("OffsetAmount"), et, dice.randf())))
			p.orbit_rot = CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(m.get("RotationAmount"), et, dice.randf())))
			p.orbit_rate = CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(m.get("RotationRateAmount"), et, dice.randf())))
		var images: int = int(s.subuv[0]) * int(s.subuv[1])
		if images > 1:
			var method := String(s.subuv_method)
			if method.begins_with("PSUVIM_Random"):
				p.image = float(dice.randi() % images)
			elif mods.has("SubUV"):
				p.image = CascadeFx.s1(mods.SubUV.get("SubImageIndex"), 0.0, dice.randf())
			elif mods.has("SubUVMovie"):
				p.image = CascadeFx.s1(mods.SubUVMovie.get("StartingFrame", 0), 0.0, dice.randf()) if mods.SubUVMovie.get("StartingFrame") is Dictionary else float(mods.SubUVMovie.get("StartingFrame", 0))
		match String(s.uv_flip):
			"EParticleUVFlipMode::RandomFlipUOnly": p.flip = 1 if dice.randf() < 0.5 else 0
			"EParticleUVFlipMode::RandomFlipVOnly": p.flip = 2 if dice.randf() < 0.5 else 0
			"EParticleUVFlipMode::RandomFlipUV": p.flip = dice.randi() % 4
			"EParticleUVFlipMode::FlipUOnly": p.flip = 1
			"EParticleUVFlipMode::FlipVOnly": p.flip = 2
			"EParticleUVFlipMode::FlipUV": p.flip = 3
		var c := comp()
		if s.local_space:
			p.pos = CascadeFx.ue(s.origin) + lp
			p.vel = lv
		else:
			p.pos = world_loc + c.basis * lp
			p.vel = c.basis * lv
		if not p.spawn_rnd.is_empty():
			var outward := (c.basis * lp) if lp.length_squared() > 1e-10 else c.basis.x
			for r in p.spawn_rnd:
				p.vel += outward.normalized() * float(r) * CascadeFx.CM
		m = one("VelocityInheritParent")
		if m != null:
			var sc := CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(m.get("Scale"), et, dice.randf())))
			var pv := sys.comp_vel
			if s.local_space:
				pv = c.basis.inverse() * pv
			p.vel += pv * sc
		p.base_vel = p.vel
		if s.type in ["ribbon", "beam", "anim_trail"]:
			if not particles.is_empty():
				trail_len += (particles[particles.size() - 1] as Particle).pos.distance_to(p.pos)
			p.trail_u = trail_len
		particles.append(p)
		_update_one(p, age, out_events)
		return p

	func _update(dt: float, out_events: Dictionary) -> void:
		var i := 0
		while i < particles.size():
			var p: Particle = particles[i]
			if p.age + dt >= p.life:
				_emit_event(p, "EPET_Death", out_events)
				particles.remove_at(i)
				continue
			if not _update_one(p, dt, out_events):
				particles.remove_at(i)
				continue
			i += 1

	func _update_one(p: Particle, dt: float, out_events: Dictionary) -> bool:
		p.age += dt
		p.rt = clampf(p.age / p.life, 0.0, 1.0) if p.life < INF else 0.0
		var rt := p.rt
		var et := time / maxf(duration, 1e-4)
		p.color = p.base_color
		for m in m_color:
			var c := CascadeFx.sample(m.get("ColorOverLife"), rt, 0.0)
			p.color = Color(c[0], c[1] if c.size() > 1 else c[0], c[2] if c.size() > 2 else c[0], p.color.a)
			if m.has("AlphaOverLife"):
				p.color.a = CascadeFx.s1(m.AlphaOverLife, rt, 0.0)
			if m.get("bClampAlpha", true):
				p.color.a = clampf(p.color.a, 0.0, 1.0)
		for m in m_color_scale:
			var tt := et if m.get("bEmitterTime", false) else rt
			var c := CascadeFx.sample(m.get("ColorScaleOverLife"), tt, 0.0)
			p.color.r *= c[0]
			p.color.g *= c[1] if c.size() > 1 else c[0]
			p.color.b *= c[2] if c.size() > 2 else c[0]
			if m.has("AlphaScaleOverLife"):
				p.color.a *= CascadeFx.s1(m.AlphaScaleOverLife, tt, 0.0)
		p.size = p.base_size
		for m in m_size_life:
			var k := CascadeFx.sample(m.LifeMultiplier, rt, 0.0)
			var kx := k[0]
			var ky: float = k[1] if k.size() > 1 else k[0]
			var kz: float = k[2] if k.size() > 2 else k[0]
			p.size = Vector3(p.size.x * (kx if m.get("MultiplyX", true) else 1.0), p.size.y * (ky if m.get("MultiplyY", true) else 1.0), p.size.z * (kz if m.get("MultiplyZ", true) else 1.0))
		for m in m_size_scale:
			var k := CascadeFx.sample(m.SizeScale, rt, 0.0)
			p.size = Vector3(p.base_size.x * k[0], p.base_size.y * (k[1] if k.size() > 1 else k[0]), p.base_size.z * (k[2] if k.size() > 2 else k[0]))
		for m in m_size_speed:
			var sp := world_vel(p).length() / CascadeFx.CM
			var sc: Array = m.get("SpeedScale", [1, 1])
			var mx: Array = m.get("MaxScale", [1, 1])
			p.size.x *= clampf(sp * float(sc[0]), 1.0, float(mx[0]))
			p.size.y *= clampf(sp * float(sc[1] if sc.size() > 1 else sc[0]), 1.0, float(mx[1] if mx.size() > 1 else mx[0]))
		for m in m_vel_life:
			var k := CascadeFx.sample(m.VelOverLife, rt, 0.0)
			var f := CascadeFx.ue_axes(CascadeFx.v3(k))
			if m.get("Absolute", false):
				var av := CascadeFx.ue(CascadeFx.v3(k))
				p.vel = av if s.local_space or m.get("bInWorldSpace", false) else comp().basis * av
				p.base_vel = p.vel
			elif s.local_space:
				p.vel = p.base_vel * f
			else:
				var b := comp().basis.orthonormalized()
				p.vel = b * ((b.inverse() * p.base_vel) * f)
		for m in m_accel_const:
			var a := CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.get("Acceleration"), rt, 0.5))) if m.get("Acceleration") is Dictionary else CascadeFx.ue(m.get("Acceleration", [0, 0, 0]))
			p.vel += a * dt
		p.vel += p.accel * dt
		for m in m_accel_life:
			var a := CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.AccelOverLife, rt, 0.0)))
			p.vel += (a if m.get("bAlwaysInWorldSpace", false) or s.local_space else comp().basis * a) * dt
		var drag := 0.0
		for m in m_drag:
			drag += CascadeFx.s1(m.get("DragCoefficientRaw"), rt, 0.5)
		for m in m_drag_scale:
			drag *= CascadeFx.s1(m.get("DragScaleRaw"), rt, 0.0)
		if drag != 0.0:
			p.vel -= p.vel * minf(drag * dt, 1.0)
		for m in m_attractor:
			var pt := comp() * CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.get("Position"), rt, 0.5)))
			var rng := CascadeFx.s1(m.get("Range"), rt, 0.5) * CascadeFx.CM
			var str_ := CascadeFx.s1(m.get("Strength"), rt, 0.5) * CascadeFx.CM
			var d := pt - world_pos(p)
			var dist := d.length()
			if dist < rng and dist > 1e-4:
				var k := str_ * ((1.0 - dist / rng) if m.get("StrengthByDistance", true) else 1.0)
				var acc := d / dist * k
				if s.local_space:
					acc = comp().basis.inverse() * acc
				p.vel += acc * dt
		for m in m_gravity:
			var pt := comp() * CascadeFx.ue(m.get("Position", [0, 0, 0]))
			var d := pt - world_pos(p)
			var dist := maxf(d.length(), float(m.get("Radius", 1.0)) * CascadeFx.CM)
			var g := CascadeFx.s1(m.get("Strength"), rt, 0.5) * CascadeFx.CM
			p.vel += d.normalized() * g / (dist * dist) * dt
		for m in m_dynamic:
			var dp: Array = m.get("DynamicParams", [])
			for k in mini(dp.size(), 4):
				var d: Dictionary = dp[k]
				var tt := et if d.get("bUseEmitterTime", false) else rt
				var val := CascadeFx.s1(d.value, tt, p.rnd)
				match String(d.get("method", "EDPV_UserSet")):
					"EDPV_VelocityX": val *= world_vel(p).x / CascadeFx.CM
					"EDPV_VelocityY": val *= world_vel(p).z / CascadeFx.CM
					"EDPV_VelocityZ": val *= world_vel(p).y / CascadeFx.CM
					"EDPV_VelocityMag": val *= world_vel(p).length() / CascadeFx.CM
				p.dyn[k] = val
		var rr := 1.0
		for m in m_rot_rate_mul:
			rr *= CascadeFx.s1(m.LifeMultiplier, rt, 0.0)
		p.rot_rate = p.base_rot_rate * rr
		for m in m_rot_life:
			var r := CascadeFx.s1(m.RotationOverLife, rt, 0.0)
			p.rot = p.rot * r if m.get("Scale", true) else p.rot + r * dt
		var mr := p.base_mesh_rot_rate
		for m in m_mesh_rate_mul:
			var k := CascadeFx.sample(m.LifeMultiplier, rt, 0.0)
			mr *= Vector3(k[0], k[1] if k.size() > 1 else k[0], k[2] if k.size() > 2 else k[0])
		for m in m_mesh_rate_life:
			var k := CascadeFx.sample(m.RotRate, rt, 0.0)
			var kv := Vector3(k[0], k[1] if k.size() > 1 else 0.0, k[2] if k.size() > 2 else 0.0)
			mr = mr * kv if m.get("bScaleRotRate", false) else mr + kv
		p.mesh_rot_rate = mr
		if has_subuv_movie:
			var fr := CascadeFx.s1(mods.SubUVMovie.get("FrameRate"), rt, 0.0)
			p.image = fposmod(p.image + fr * dt, float(subuv_images))
		elif has_subuv and not subuv_random:
			p.image = CascadeFx.s1(mods.SubUV.get("SubImageIndex"), rt, p.rnd)
		p.pos += p.vel * dt
		p.rot += p.rot_rate * dt
		p.mesh_rot += p.mesh_rot_rate * dt
		p.orbit_rot += p.orbit_rate * dt
		var col = m_collision
		if col != null and not s.local_space:
			var r := maxf(p.size.x, 1.0) * CascadeFx.CM * 0.5 * float(col.get("DirScalar", 0.5) if col.get("DirScalar") is float else 0.5)
			if p.pos.y < sys.ground_y + r and p.vel.y < 0.0:
				p.pos.y = sys.ground_y + r
				var damp := CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(col.get("DampingFactor"), rt, dice.randf())))
				p.vel = Vector3(p.vel.x * damp.x, -p.vel.y * damp.y, p.vel.z * damp.z)
				p.base_vel = p.vel
				p.collisions += 1
				_emit_event(p, "EPET_Collision", out_events)
				var maxc := int(CascadeFx.s1(col.get("MaxCollisions"), 0.0, dice.randf())) if col.get("MaxCollisions") is Dictionary else int(col.get("MaxCollisions", 0))
				if maxc > 0 and p.collisions >= maxc:
					match String(col.get("CollisionCompletionOption", "EPCC_Kill")):
						"EPCC_Kill":
							return false
						"EPCC_Freeze", "EPCC_FreezeTranslation", "EPCC_FreezeMovement":
							p.vel = Vector3.ZERO
							p.base_vel = Vector3.ZERO
		return true

	func world_pos(p: Particle) -> Vector3:
		var pos: Vector3 = comp() * p.pos if s.local_space else p.pos
		if has_orbit:
			var r := p.orbit_rot * TAU
			var b := Basis(Vector3.UP, -r.z) * Basis(Vector3.BACK, r.y) * Basis(Vector3.RIGHT, -r.x)
			pos += comp().basis * (b * p.orbit_off)
		return pos

	func world_vel(p: Particle) -> Vector3:
		return comp().basis * p.vel if s.local_space else p.vel

	func camera_offset(p: Particle, pos: Vector3) -> Vector3:
		var m = m_camera_offset
		if m == null or sys.camera == null:
			return pos
		var off := CascadeFx.s1(m.get("CameraOffset"), p.rt, p.rnd) * CascadeFx.CM
		return pos + (sys.camera.global_position - pos).normalized() * off

	## The particles in draw order. Read only: the unsorted case is the particle list itself (no copy per frame).
	func _sorted() -> Array:
		match String(s.sort):
			"PSORTMODE_Age_NewestFirst":
				var order: Array = particles.duplicate()
				order.reverse()
				return order
			"PSORTMODE_ViewProjDepth", "PSORTMODE_DistanceToView":
				if sys.camera:
					var order: Array = particles.duplicate()
					var cp := sys.camera.global_position
					order.sort_custom(func(a, b): return world_pos(a).distance_squared_to(cp) > world_pos(b).distance_squared_to(cp))
					return order
		return particles

	func render() -> void:
		_render_lights()
		if s.type == "ribbon" or s.type == "anim_trail":
			_render_ribbon()
			return
		if s.type == "beam":
			_render_beam()
			return
		if s.render_mode == "ERM_None" or s.render_mode == "ERM_LightsOnly":
			mm_inst.multimesh.visible_instance_count = 0
			return
		var mm := mm_inst.multimesh
		var order := _sorted()
		var n := order.size()
		if int(s.max_draw) > 0 and req.get("bUseMaxDrawCount", true):
			n = mini(n, int(s.max_draw))
		n = mini(n, 4096)
		if extra_img.get_width() < n:
			extra_img = Image.create(nextpow2(n), 1, false, Image.FORMAT_RGBAF)
			extra_tex = ImageTexture.create_from_image(extra_img)
			if material is ShaderMaterial:
				(material as ShaderMaterial).set_shader_parameter("extra_tex", extra_tex)
		# the buffer is allocated only when the count outgrows it (a power of two, 16 at least, 4096 at most): setting
		# instance_count every frame re-allocates it; visible_instance_count only limits what is drawn
		if mm.instance_count < n:
			mm.instance_count = clampi(nextpow2(n), 16, 4096)
		mm.visible_instance_count = n
		var cam := sys.camera
		for i in n:
			var p: Particle = order[i]
			var pos := camera_offset(p, world_pos(p))
			var xf: Transform3D
			if s.type == "mesh":
				xf = Transform3D(_mesh_basis(p, pos), pos)
			else:
				xf = Transform3D(_sprite_basis(p, pos, cam), pos)
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, sys.tinted(p.color))
			mm.set_instance_custom_data(i, Color(p.dyn[0], p.dyn[1], p.dyn[2], p.dyn[3]))
			extra_img.set_pixel(i, 0, Color(p.image, float(p.flip), p.rt, p.rnd))
		extra_tex.update(extra_img)

	static func nextpow2(n: int) -> int:
		var k := 1
		while k < n:
			k *= 2
		return k

	func _sprite_basis(p: Particle, pos: Vector3, cam: Camera3D) -> Basis:
		var sx := p.size.x * CascadeFx.CM * sys.fx_scale
		var sy := sx
		var align := String(s.alignment)
		if align == "PSA_Rectangle" or align == "PSA_Velocity" or align == "PSA_FacingCameraDistanceBlend":
			sy = p.size.y * CascadeFx.CM * sys.fx_scale
		var right := Vector3.RIGHT
		var up := Vector3.UP
		var to_cam := Vector3.BACK
		if cam:
			to_cam = (cam.global_position - pos).normalized()
			right = cam.global_basis.x
			up = cam.global_basis.y
		var lock = m_axis_lock
		var rotate := true
		if align == "PSA_Velocity":
			var v := world_vel(p)
			if v.length_squared() > 1e-10:
				up = v.normalized()
				right = up.cross(to_cam).normalized()
				if right.length_squared() < 1e-6:
					right = cam.global_basis.x if cam else Vector3.RIGHT
				rotate = false
		elif align == "PSA_FacingCameraPosition" and cam:
			var wu := Vector3.UP if absf(to_cam.dot(Vector3.UP)) < 0.99 else Vector3.BACK
			right = wu.cross(to_cam).normalized()
			up = to_cam.cross(right)
		if lock != null:
			var flag := String(lock.get("LockAxisFlags", "EPAL_NONE"))
			var axes := {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}
			var key := flag.right(1)
			if axes.has(key):
				var ax: Vector3 = comp().basis.orthonormalized() * CascadeFx.ue_axes(axes[key])
				if flag.contains("NEGATIVE"):
					ax = -ax
				if flag.contains("ROTATE"):
					up = ax
					right = ax.cross(to_cam).normalized()
				else:
					var ref := Vector3.UP if absf(ax.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
					right = ref.cross(ax).normalized()
					up = ax.cross(right)
		if rotate and p.rot != 0.0:
			var a := p.rot * TAU
			var r2 := right * cos(a) + up * sin(a)
			var u2 := -right * sin(a) + up * cos(a)
			right = r2
			up = u2
		var n := right.cross(up).normalized()
		return Basis(right * sx, up * sy, n)

	func _mesh_basis(p: Particle, pos: Vector3) -> Basis:
		var sc := Basis.from_scale(Vector3(p.size.x, p.size.z, p.size.y) * sys.fx_scale)
		var r := p.mesh_rot * TAU
		var rot := Basis(Vector3.UP, -r.z) * Basis(Vector3.BACK, r.y) * Basis(Vector3.RIGHT, -r.x)
		var c := comp().basis.orthonormalized()
		var align := Basis()
		var lock := String(s.get("axis_lock", "EPAL_NONE"))
		if s.alignment == "PSA_Velocity":
			var v := world_vel(p)
			if v.length_squared() > 1e-10:
				var x := v.normalized()
				var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.99 else Vector3.BACK
				var z := x.cross(up).normalized()
				align = Basis(x, z.cross(x), z)
		elif lock != "EPAL_NONE" and lock != "":
			align = c
		elif s.get("mesh_alignment", "") == "PSMA_MeshFaceCameraWithRoll" and s.alignment != "PSA_Square" and sys.camera:
			var x := (sys.camera.global_position - pos).normalized()
			var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.99 else Vector3.BACK
			var z := x.cross(up).normalized()
			align = Basis(x, z.cross(x), z)
		else:
			align = c
		var mrm = m_mesh_rot
		if mrm != null and mrm.get("bInheritParent", false):
			align = c * align if align != c else align
		return align * rot * sc

	func _render_lights() -> void:
		var m = m_light
		if m == null:
			return
		var n := mini(particles.size(), MAX_LIGHTS)
		while lights.size() < n:
			var l := OmniLight3D.new()
			l.top_level = true
			l.shadow_enabled = false
			sys.add_child(l)
			lights.append(l)
		for i in lights.size():
			var l: OmniLight3D = lights[i]
			l.visible = i < n
			if i >= n:
				continue
			var p: Particle = particles[particles.size() - 1 - i]
			var cs := CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(m.get("ColorScaleOverLife"), p.rt, 0.0)))
			var pc := sys.tinted(p.color)
			var c := Color(pc.r * cs.x, pc.g * cs.z, pc.b * cs.y)
			var mx := maxf(maxf(c.r, c.g), maxf(c.b, 1e-4))
			l.light_color = Color(c.r / mx, c.g / mx, c.b / mx)
			l.light_energy = clampf(CascadeFx.s1(m.get("BrightnessOverLife"), p.rt, 0.0) * mx * pc.a / 2000.0, 0.0, 16.0)
			l.omni_range = maxf(CascadeFx.s1(m.get("RadiusScale"), p.rt, 0.0) * p.size.x * CascadeFx.CM * sys.fx_scale, 0.1)
			l.omni_attenuation = clampf(float(CascadeFx.s1(m.get("LightExponent"), 0.0, 0.0)) / 8.0, 0.5, 4.0)
			l.global_position = world_pos(p)

	func _ribbon_up(pos: Vector3, tangent: Vector3) -> Vector3:
		var cam := sys.camera.global_position if sys.camera else pos + Vector3.BACK
		match String(s.get("ribbon", {}).get("render_axis", "Trails_CameraUp")):
			"Trails_SourceUp":
				return comp().basis.y.normalized()
			"Trails_WorldUp":
				return Vector3.UP
		return tangent.cross(cam - pos).normalized()

	func _render_ribbon() -> void:
		ribbon_mesh.clear_surfaces()
		if particles.size() < 1 or sys.camera == null or s.render_mode == "ERM_None":
			return
		# the points newest first (the head when the emitter still spawns in the world, then the particles): parallel arrays,
		# no dictionary per point per frame
		var with_head: bool = spawning and sys.active and not s.local_space
		var np := particles.size() + (1 if with_head else 0)
		if np < 2:
			return
		var pos_a := PackedVector3Array()
		pos_a.resize(np)
		var u_a := PackedFloat64Array()
		u_a.resize(np)
		var part_a: Array = []
		part_a.resize(np)
		var k := 0
		if with_head:
			var head := loc_now()
			var newest: Particle = particles[particles.size() - 1]
			pos_a[0] = head
			u_a[0] = newest.trail_u + newest.pos.distance_to(head)
			part_a[0] = newest
			k = 1
		for i in range(particles.size() - 1, -1, -1):
			var q: Particle = particles[i]
			pos_a[k] = world_pos(q)
			u_a[k] = q.trail_u
			part_a[k] = q
			k += 1
		var tiling: float = float(s.get("ribbon", {}).get("tiling", 0.0)) * CascadeFx.CM
		var total: float = maxf(u_a[0] - u_a[np - 1], 1e-4)
		ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for j in np:
			var pos: Vector3 = pos_a[j]
			var p: Particle = part_a[j]
			var prv: Vector3 = pos_a[maxi(j - 1, 0)]
			var nxt: Vector3 = pos_a[mini(j + 1, np - 1)]
			var tangent := prv - nxt
			if tangent.length_squared() < 1e-10:
				tangent = comp().basis.x
			var side := _ribbon_up(pos, tangent)
			var w := p.size.x * CascadeFx.CM * 0.5 * sys.fx_scale
			var u: float = u_a[j] / tiling if tiling > 0.0 else (u_a[0] - u_a[j]) / total
			var col := sys.tinted(p.color)
			for side_k in [1.0, -1.0]:
				ribbon_mesh.surface_set_color(col)
				ribbon_mesh.surface_set_uv(Vector2(u, 0.0 if side_k > 0.0 else 1.0))
				ribbon_mesh.surface_set_uv2(Vector2(p.rt, float(j) / float(np - 1)))
				ribbon_mesh.surface_add_vertex(pos + side * w * side_k)
		ribbon_mesh.surface_end()

	func _render_beam() -> void:
		# TypeDataBeam2: draw from the source to the target as a camera-facing strip.
		ribbon_mesh.clear_surfaces()
		if particles.is_empty() or sys.camera == null:
			return
		var td: Dictionary = s.get("type_data_raw", {})
		var src := loc_now()
		var dst := src + comp().basis.x * float(td.get("Distance", [500.0])[0] if td.get("Distance") is Array else 500.0) * CascadeFx.CM
		var bt = one("BeamTarget")
		if bt != null and bt.get("Target") is Dictionary:
			dst = comp() * CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(bt.Target, 0.0, 0.5)))
		var segs := 16
		ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var p: Particle = particles[0]
		var noise = one("BeamNoise")
		for j in segs + 1:
			var f := float(j) / segs
			var pos := src.lerp(dst, f)
			if noise != null:
				var amp := 0.15 * sin(f * PI)
				pos += Vector3(sin(f * 23.0 + p.age * 9.0), cos(f * 17.0 + p.age * 7.0), sin(f * 11.0 - p.age * 5.0)) * amp
			var side := (dst - src).cross(sys.camera.global_position - pos).normalized()
			var w := p.size.x * CascadeFx.CM * 0.5 * sys.fx_scale
			for side_k in [1.0, -1.0]:
				ribbon_mesh.surface_set_color(sys.tinted(p.color))
				ribbon_mesh.surface_set_uv(Vector2(f * float(td.get("TextureTile", 1)), 0.0 if side_k > 0.0 else 1.0))
				ribbon_mesh.surface_set_uv2(Vector2(p.rt, f))
				ribbon_mesh.surface_add_vertex(pos + side * w * side_k)
		ribbon_mesh.surface_end()
