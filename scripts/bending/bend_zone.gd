class_name BendZone
extends Node3D
## A bent thing that lasts a while in the world (BendEffects; docs/bending_design.md), by `kind`:
##   barriers    bubble (a sphere of water round its owner: fire dies in it as steam, air and water are stopped, stone and
##               ice pass), air_shield (round its owner: fire, water, ice and air sent back at who sent them; stone passes),
##               water_wall (a wall of water: fire dies in it, water is drunk in; fire walls it stands in go out),
##               fire_wall (burns whoever stands in it; ice melts going through, air takes its flame, water puts it out)
##   the ground  burn (the ground alight: as a fire wall, low), ice_patch (slows whoever is on it), smoke / dust / spray
##               (a cloud that hides: drawn only)
##   moving      tornado (goes on along its way, lifting and carrying whoever it meets), vacuum (the air pulled out round a
##               place: whoever is in it slowed)
##   guards      on its owner for a moment (window_s): catch (a stone flying at him caught and held before him: Earth Shove
##               sends it back), deflect (a stone knocked aside), cushion (a stone slowed to a stop and dropped): a GustLift
##               throw, a bot's spike (NpcBending.Flight) or a stone bolt (BendBolt kind "stone": the disc, the pebbles, a
##               shoved chunk; caught or cushioned it is a FormStone again); redirect (water and ice sent back), return (Air
##               Redirect: light bolts, fire, water, ice and air, sent back at who sent them), parry (fire knocked aside),
##               spin (light bolts knocked aside), absorb (water drunk in: a little health)
## put_out (spec.put_out: the spray): what burns in it goes out as it is made and while it stands (fire walls, burning ground,
## campfires, torches not in its owner's hand).
## The tornado keeps to the ground under it (FormEffects.ground_at: a deck, a raised floor; the terrain where there is none).
## Whom it reaches: BendCaster.near (the player found through his group). Its owner any Node3D (the player, a bot).
## on_bolt(b): what it does to bolt `b` passing (true: it acted). Group GROUP.

const GROUP := &"bend_zones"
const LIGHT := ["fire", "water", "ice", "air"]
const GUARDS := ["catch", "deflect", "cushion", "redirect", "return", "parry", "spin", "absorb"]
## The earth guards: they take stones.
const STONE_GUARDS := ["catch", "deflect", "cushion"]

var kind := "bubble"
var owner_node: Node3D
var follow := false
## Round: radius; a wall or a patch: size (x across, y up, z through), standing on its origin.
var radius := 2.0
var size := Vector3(4.0, 2.0, 0.5)
var life_s := 3.0
var damage_s := 0.0
var way := Vector3.FORWARD
var speed := 0.0
var t := 0.0
## What a guard took (stones caught, bolts sent back), for the tests.
var took := 0
## What burns in it goes out (the spray); how many it has put out.
var put_out := false
var put_out_n := 0
## The stones a guard caught or dropped from stone bolts (FormStone), for the tests.
var stones: Array[FormStone] = []

var _tick := 0.0
var _fx: Array[Node] = []


static func make(by: Node3D, p_kind: String, at: Vector3, spec: Dictionary, p_way := Vector3.FORWARD) -> BendZone:
	var z := BendZone.new()
	z.name = "BendZone_" + p_kind
	z.kind = p_kind
	z.owner_node = by
	z.follow = p_kind in ["bubble", "air_shield"] or p_kind in GUARDS
	z.radius = float(spec.get("radius_m", 2.0))
	z.size = Vector3(float(spec.get("width_m", 4.0)), float(spec.get("height_m", 2.0)), float(spec.get("thick_m", 0.6)))
	z.life_s = float(spec.get("life_s", spec.get("window_s", 3.0)))
	z.damage_s = float(spec.get("damage_s", 0.0))
	z.speed = float(spec.get("mps", 0.0))
	z.put_out = bool(spec.get("put_out", false))
	var w := Vector3(p_way.x, 0.0, p_way.z)
	z.way = w.normalized() if w.length_squared() > 1e-6 else Vector3.FORWARD
	z.add_to_group(GROUP)
	by.get_tree().current_scene.add_child(z)
	var x := Vector3.UP.cross(z.way).normalized()
	z.global_transform = Transform3D(Basis(x, Vector3.UP, z.way), at)
	z._look()
	return z


## Its look (BendLooks' cel style, ToonFx): the meshes under a "Look" node that grows in, the lasting emitters in _fx.
##   bubble       a wobbling sphere of water, a pale rim and foam streaks flowing round it, drops at its foot
##   air_shield   three translucent wind bands turning round its owner at different tilts and speeds, dust at his feet
##   water_wall   a standing sheet of water flowing up, foam and spray along its crest and its foot
##   fire_wall    standing flame sheets (one MultiMesh of tongues facing the camera) on a scorch, embers, a warm light;
##   burn         the same low over its strip of ground
##   ice_patch    a frost sheet on the ground, sparkles
##   tornado      stacked wind rings widening upward, each turning, rock debris and dust whirled up round it
##   vacuum       wind bands drawing in, air
##   smoke/dust/spray  cel puffs
func _look() -> void:
	if not BendLooks.live():
		return
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	match kind:
		"bubble":
			var mi := _part(look, ToonFx.sphere(24), ToonFx.mat("bubble"))
			mi.scale = Vector3.ONE * radius
			mi.position = Vector3.UP * 1.0
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "water", Vector3(radius * 0.7, 0.05, radius * 0.7), 14, 0.6, 1.6, 0.12))
			_grow(look, Vector3.ONE * 0.05)
		"air_shield":
			for i in 3:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.9, 0.45), ToonFx.mat(["wind_band", "wind_band_slow", "wind_band_fast"][i]))
				b.scale = Vector3.ONE * radius * (1.0 - i * 0.07)
				b.position = Vector3.UP * (0.3 + i * 0.62)
				b.rotation = Vector3(0.24 * (1.0 if i % 2 == 0 else -1.0), i * 1.1, 0.12 * i)
				b.set_instance_shader_parameter(&"seed", i * 0.37)
			_fx.append(BendLooks.emitter(self, "dust", Vector3(radius * 0.9, 0.05, radius * 0.9), 14, 0.7, 0.6, 0.35))
			_grow(look, Vector3.ONE * 0.2)
		"water_wall":
			var bm := BoxMesh.new()
			bm.size = Vector3(size.x, size.y, size.z * 0.7)
			bm.subdivide_width = 16
			bm.subdivide_height = 10
			var mi := _part(look, bm, ToonFx.mat("water_wall"))
			mi.position = Vector3.UP * size.y * 0.5
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			var crest := BendLooks.emitter(self, "water", Vector3(size.x * 0.48, 0.05, size.z * 0.3), 40, 0.6, 2.4, 0.12)
			var foam := BendLooks.emitter(self, "foam", Vector3(size.x * 0.48, 0.05, size.z * 0.35), 22, 0.45, 0.8, 0.32)
			var foot := BendLooks.emitter(self, "foam", Vector3(size.x * 0.5, 0.05, size.z * 0.5), 18, 0.6, 0.4, 0.4)
			for e: GPUParticles3D in [crest, foam]:
				e.position = Vector3.UP * size.y
			_fx.append_array([crest, foam, foot])
			_grow(look, Vector3(1.0, 0.02, 1.0))
		"fire_wall", "burn":
			_flames(look)
			var h := size.y if kind == "fire_wall" else 0.5
			var em := BendLooks.emitter(self, "embers", Vector3(size.x * 0.5, 0.1, size.z * 0.5), int(10 * maxf(size.x, size.z)),
					1.0, h * 1.6, 0.05)
			em.position = Vector3.UP * h * 0.4
			_fx.append(em)
			var sc := _part(look, ToonFx.plane(), ToonFx.mat("mark_scorch"))
			sc.scale = Vector3(size.x * 0.62, 1.0, size.z * 0.5 + 0.5)
			sc.position = Vector3.UP * 0.02
			sc.set_instance_shader_parameter(&"t", 0.25)
			sc.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.55, 0.2)
			l.light_energy = 2.0
			l.omni_range = maxf(size.x, size.z)
			l.position = Vector3.UP * 1.0
			l.shadow_enabled = false
			add_child(l)
		"ice_patch":
			var fr := _part(look, ToonFx.plane(), ToonFx.mat("mark_frost"))
			fr.scale = Vector3(radius, 1.0, radius)
			fr.position = Vector3.UP * 0.03
			fr.set_instance_shader_parameter(&"t", 0.2)
			fr.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "sparkle", Vector3(radius * 0.7, 0.05, radius * 0.7), 10, 0.8, 0.3, 0.12))
			_grow(look, Vector3(0.1, 1.0, 0.1))
		"smoke", "dust", "spray":
			_fx.append(BendLooks.emitter(self, "smoke" if kind == "smoke" else ("dust" if kind == "dust" else "foam"),
					Vector3(radius, 0.8, radius), 40, 2.2, 0.6, 1.6))
		"tornado":
			var rings := 6
			for i in rings:
				var f := float(i) / (rings - 1)
				var b := _part(look, ToonFx.band_mesh(1.0, 1.12, 0.55), ToonFx.mat("wind_funnel" if i % 2 == 0 else "wind_band_fast"))
				b.scale = Vector3.ONE * radius * (0.32 + 0.55 * f)
				b.position = Vector3(sin(i * 1.7) * 0.1 * f, 0.05 + i * 0.38, cos(i * 1.3) * 0.1 * f)
				b.rotation = Vector3(0.08 * sin(i * 2.1), i * 0.9, 0.08 * cos(i * 1.4))
				b.set_instance_shader_parameter(&"seed", i * 0.29)
			var pivot := Node3D.new()
			pivot.name = "Whirl"
			add_child(pivot)
			var tw := pivot.create_tween().set_loops()
			tw.tween_property(pivot, "rotation:y", TAU, 0.75).from(0.0)
			var debris := BendLooks.emitter(pivot, "debris", Vector3.ONE * 0.1, 18, 1.5, 3.5, 0.18)
			var dust := BendLooks.emitter(pivot, "dust", Vector3.ONE * 0.1, 22, 1.1, 1.2, 0.6)
			for e: GPUParticles3D in [debris, dust]:
				var pm := e.process_material as ParticleProcessMaterial
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
				pm.emission_ring_axis = Vector3.UP
				pm.emission_ring_height = 0.3
				pm.emission_ring_radius = radius * (0.85 if e == debris else 0.7)
				pm.emission_ring_inner_radius = radius * 0.4
				pm.gravity = Vector3(0, -1.5, 0) if e == debris else Vector3.ZERO
			_fx.append_array([debris, dust])
			_grow(look, Vector3(0.3, 0.05, 0.3))
		"vacuum":
			for i in 2:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.7, 0.4), ToonFx.mat("wind_band_fast"))
				b.scale = Vector3.ONE * radius * (1.0 - i * 0.35)
				b.position = Vector3.UP * (0.3 + i * 0.5)
				b.set_instance_shader_parameter(&"seed", i * 0.5)
			_fx.append(BendLooks.emitter(self, "air", Vector3(radius, 0.6, radius), 24, 0.6, -1.0, 0.35))


func _part(under: Node3D, m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	under.add_child(mi)
	return mi


## The look grows from `from` (its scale) to whole in a quarter second.
func _grow(look: Node3D, from: Vector3) -> void:
	look.scale = from
	var tw := look.create_tween()
	tw.tween_property(look, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The flames of a fire wall (tall sheets in two staggered rows along it) or burning ground (low, scattered over its strip):
## one MultiMesh of flame quads facing the camera, raised from nothing.
func _flames(look: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3i(global_position * 10.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var xs: Array[Transform3D] = []
	if kind == "fire_wall":
		var n := maxi(int(size.x / 0.42), 3)
		for row in 2:
			for i in n:
				var x := (float(i) + 0.5 + (0.5 if row == 1 else 0.0) * 0.9) / n - 0.5
				var h := size.y * rng.randf_range(0.7, 1.15) * (1.0 if row == 0 else 0.8)
				var w := rng.randf_range(0.75, 1.05)
				var z := (row - 0.5) * size.z * 0.5
				xs.append(Transform3D(Basis(Vector3.RIGHT * w, Vector3.UP * h, Vector3.BACK), Vector3(x * size.x, 0.0, z)))
	else:
		var n := maxi(int(size.x * size.z * 2.2), 4)
		for i in n:
			var p := Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0.0, rng.randf_range(-0.5, 0.5) * size.z)
			var h := rng.randf_range(0.35, 0.75)
			xs.append(Transform3D(Basis(Vector3.RIGHT * rng.randf_range(0.45, 0.7), Vector3.UP * h, Vector3.BACK), p))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Flames"
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame" if kind == "fire_wall" else "flame_low")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 1.0
	mmi.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	mmi.set_instance_shader_parameter(&"grow", 0.0)
	look.add_child(mmi)
	var tw := mmi.create_tween()
	tw.tween_method(func(v: float) -> void: mmi.set_instance_shader_parameter(&"grow", v), 0.0, 1.0, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(dt: float) -> void:
	t += dt
	if follow and owner_node != null and is_instance_valid(owner_node):
		global_position = owner_node.global_position
	if kind == "tornado":
		global_position += way * speed * dt
		global_position.y = FormEffects.ground_at(self, global_position).y      # (a deck's, not the terrain's under it)
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.25
		_every(0.25)
	if kind in ["catch", "deflect", "cushion"]:
		_stones()
	if t >= life_s:
		end()


## Who it holds now: everyone within it (round) or in its box.
func inside(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	if kind in ["bubble", "air_shield", "ice_patch", "smoke", "dust", "spray", "tornado", "vacuum"] or kind in GUARDS:
		return Vector2(l.x, l.z).length() <= radius and l.y > -1.0 and l.y < 3.5
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 + 0.3 and l.y > -0.5 and l.y < size.y + 0.3


## Its lasting effects on whom it holds, each `dt` s.
func _every(dt: float) -> void:
	var r := maxf(radius, size.x * 0.6)
	if put_out:
		put_out_fires()
	for e in BendCaster.near(owner_node, global_position, r + 1.0):
		var n: Node3D = e[0]
		if not inside(n.global_position):
			continue
		match kind:
			"fire_wall", "burn":
				BendStatus.hurt(n, damage_s * dt, n.global_position + Vector3.UP, way, owner_node)
			"ice_patch", "vacuum":
				BendStatus.slow(n, 0.6)
			"tornado":
				BendStatus.hurt(n, damage_s * dt, n.global_position + Vector3.UP, way, owner_node)
				BendStatus.knock(n, way * speed * 1.2 + Vector3.UP * 3.0, owner_node)
	if kind == "water_wall":
		# (a fire wall it stands in goes out)
		for z in get_tree().get_nodes_in_group(GROUP):
			var o := z as BendZone
			if o != self and o.kind in ["fire_wall", "burn"] and inside(o.global_position):
				BendLooks.burst(o.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				o.end()


## Bolt `b` passing it (see the header); true when it acted on it.
func on_bolt(b: BendBolt) -> bool:
	if b.spent or b.caster == owner_node or not inside(b.global_position):
		return false
	match kind:
		"bubble":
			if b.kind == "fire":
				BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
				b.end("steam")
				return true
			if b.kind in ["air", "water"]:
				BendLooks.burst(b.global_position, "water", 12)
				b.end("bubble")
				return true
		"water_wall":
			if b.kind == "fire":
				BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
				b.end("steam")
				return true
			if b.kind == "water":
				b.end("drunk")
				return true
		"air_shield":
			if b.kind in LIGHT:
				_send_back(b)
				return true
		"fire_wall", "burn":
			if b.kind == "ice":
				BendLooks.burst(b.global_position, "water", 12)
				b.end("melted")
				return true
			if b.kind == "water":
				BendLooks.burst(global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				b.end("steam")
				end()
				return true
			if b.kind == "air" and not b.burning:
				b.burning = true
				return true
		"redirect":
			if b.kind in ["water", "ice"]:
				_send_back(b)
				return true
		"return":
			if b.kind in LIGHT:
				_send_back(b)
				return true
		"catch", "deflect", "cushion":
			if b.kind == "stone":
				_take_bolt(b)
				return true
		"parry":
			if b.kind == "fire":
				_aside(b)
				return true
		"spin":
			if b.kind in LIGHT:
				_aside(b)
				return true
		"absorb":
			if b.kind == "water":
				BendStatus.heal(owner_node, 6.0)
				b.end("absorbed")
				took += 1
				return true
	return false


func _send_back(b: BendBolt) -> void:
	var to := (b.caster as Node3D).global_position + Vector3.UP * 1.2 if b.caster != null and is_instance_valid(b.caster) \
			else b.global_position - b.velocity
	b.redirect(to - b.global_position, owner_node)
	BendLooks.burst(b.global_position, b.kind, 10)
	took += 1


func _aside(b: BendBolt) -> void:
	var bc := BendCaster.of(owner_node)
	var r := bc.rand_f() if bc != null else randf()
	var side := b.velocity.cross(Vector3.UP).normalized() * (1.0 if r < 0.5 else -1.0)
	b.redirect(side + b.velocity.normalized() * 0.3, owner_node)
	took += 1


## A stone bolt met by an earth guard: deflect knocks it aside; catch and cushion end it, a FormStone of its size left in its
## place (caught: held before the owner for Earth Shove; cushioned: dropped where it was).
func _take_bolt(b: BendBolt) -> void:
	if kind == "deflect":
		_aside(b)
		BendLooks.burst(b.global_position, "stone", 10)
		return
	var at := b.global_position
	var v := b.velocity
	var rad := clampf(b.radius, 0.12, 0.45)
	b.end("caught" if kind == "catch" else "cushioned")
	var s := FormStone.ball(get_tree().current_scene, at - Vector3.UP * rad, {"radius_m": rad, "mass_kg": 20.0, "rise_s": 0.01,
			"life_s": 30.0, "sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, at)
	s.global_transform = s.base
	s.set_meta(&"bend_shape", b.shape)
	stones.append(s)
	_take_stone(s, v)


## What burns in it goes out: fire walls and burning ground (steam), campfires, torches not in its owner's hand. How many.
func put_out_fires() -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group(GROUP):
		var o := z as BendZone
		if o != null and o != self and o.kind in ["fire_wall", "burn"] and not o.is_queued_for_deletion() \
				and (inside(o.global_position) or o.global_position.distance_to(global_position) <= radius + 1.0):
			BendLooks.burst(o.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
			o.end()
			n += 1
	var r := maxf(radius, size.x * 0.5) + 0.5
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		if f is Campfire and (f as Campfire).is_lit() and (f as Node3D).global_position.distance_to(global_position) <= r:
			(f as Campfire).smother()
			n += 1
	for f in get_tree().get_nodes_in_group(TorchFire.GROUP):
		var tf := f as TorchFire
		if tf == null or tf.state == null or not tf.state.lit or tf.global_position.distance_to(global_position) > r:
			continue
		if owner_node != null and is_instance_valid(owner_node) and owner_node.is_ancestor_of(tf):
			continue                              # (its owner's own torch)
		SwayEffects.snuff(tf)
		n += 1
	put_out_n += n
	return n


## The body of a stone's caster (a GustLift's: a SwayCaster's player, a BendCaster's body).
static func _body_of(c: Object) -> Node:
	if c == null or not is_instance_valid(c):
		return null
	var b: Variant = c.get(&"body")
	if b is Node:
		return b as Node
	b = c.get(&"player")
	return b as Node if b is Node else null


## Stones flying at its owner (a guard: catch, deflect, cushion): a Stone Form or Gust throw (GustLift), a bender's spike
## (NpcBending.Flight). (Stone bolts: on_bolt.)
func _stones() -> void:
	var me := owner_node.global_position + Vector3.UP * 1.0
	for l in get_tree().get_nodes_in_group(GustLift.GROUP):
		var lift := l as GustLift
		if lift == null or lift.phase != GustLift.Phase.FLIGHT or lift.stone == null or not is_instance_valid(lift.stone):
			continue
		if _body_of(lift.caster) == owner_node:
			continue
		if lift.stone.global_position.distance_to(me) <= radius:
			var s := lift.stone as Node3D
			var v := lift.velocity
			lift.drop(false)
			_take_stone(s, v)
	for f in get_tree().get_nodes_in_group(NpcBending.FLIGHT_GROUP):
		var fl := f as NpcBending.Flight
		if fl == null or fl.stone == null or not is_instance_valid(fl.stone) or fl.shooter == owner_node:
			continue
		if fl.stone.global_position.distance_to(me) <= radius:
			var s := fl.stone as Node3D
			var v := fl.velocity
			fl.queue_free()
			_take_stone(s, v)


func _take_stone(s: Node3D, v: Vector3) -> void:
	took += 1
	var rb := s as RigidBody3D
	match kind:
		"catch":
			# held before its owner: Earth Shove (push) sends it back
			var front := owner_node.global_position + Vector3(-v.x, 0.0, -v.z).normalized() * 1.3 + Vector3.UP * 1.1
			if rb != null:
				rb.freeze = true
			s.global_position = front
			s.set_meta(&"bend_held_by", owner_node.get_instance_id())
			if s is FormStone:
				(s as FormStone).rest_again()
			BendLooks.burst(front, "stone", 14)
			BendLooks.sound("stone", "hit", front, -2.0)
		"deflect":
			if rb != null:
				rb.freeze = false
				rb.linear_velocity = v.cross(Vector3.UP).normalized() * v.length() * 0.5 + Vector3.UP * 2.0
			if s is FormStone:
				(s as FormStone).rest_again()
			BendLooks.burst(s.global_position, "stone", 10)
		"cushion":
			if rb != null:
				rb.freeze = false
				rb.linear_velocity = v * 0.05
			if s is FormStone:
				(s as FormStone).rest_again()
			BendLooks.burst(s.global_position, "air", 18)


func end() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(GROUP)
	for e in _fx:
		if e is GPUParticles3D and is_instance_valid(e):
			BendLooks.stop_trail(e as GPUParticles3D)
	queue_free()
