class_name FormRaised
extends AnimatableBody3D
## Earth a Form cast raised (FormEffects; SwayCaster's art "form"): the earth wall (kind "wall": a slab of what it was raised
## from, width x height x thick, the player and fighters take cover behind it: NpcCover finds its box, whatever its matter)
## or the pillar ("pillar": a column to stand on and climb). It rises out of the ground over rise_s (an AnimatableBody3D moved
## in the physics step: whoever stands on it is carried up), stands life_s, and crumbles at the end of it or after `hits_max`
## musket hits of at least hit_min damage (Hit.deliver finds apply_hit here). Mend packs a worn one again (mend(): its hits
## and its time back). Group GROUP.
## Its matter (`matter`, FormMatter; the user, 2026-10-03: "it should be earth wall where if the terrain is mud its a mud wall
## if its a tree i can make a tree wall you know"; data/sway/moves.json earth_wall.wall.materials) sets its look, its
## strength and how it goes (`crumble`):
##   earth  packed earth and fieldstones, turf on top ("dust": it sinks back in a cloud of dust, its stones breaking off)
##   mud    wet mud, smoothed and slumped, weaker ("slump": it sags and spreads as it sinks, mud thrown off)
##   stone  grey fieldstones packed, stronger ("rubble": it breaks and drops, its stones tumbling out round its foot)
##   snow   packed snow over the earth, weaker ("snow": it sinks in a white cloud)
##   wood   a palisade section of split logs from a tree, a medium strength ("splinters": it leans back as it sinks, the
##          wood splintering off)
## A shot that counts throws off its own matter (stone chips, clods, splinters, snow).
## Never over water (the ring: a deck over a tank, "into the water wins the round"): a wall raised across an edge with water
## under part of it is cut to the part that stands on dry ground (dry_span: its line sampled every SAMPLE_M, the ground under
## each and whether that ground is under water, TorchState.under_water), set across that part's middle; less than MIN_W_M of
## it dry and it is not raised at all (drowned: gone the next step, never seen, in no group). The stones a stone wall falls
## into drop to the ground under where they fall, into the water and onto its bed where there is water (floor_under), not
## onto the terrain's height under a deck.

## The ring's walls are capped per caster (data/ring/rules.json max_walls; the owner, 2026-10-05: walls are spammable, cap
## them as data): count_wall(r) on each earth or ice wall a caster raises (FormEffects.earth_wall, BendEffects.ice_wall and
## freeze_water) crumbles that caster's oldest standing ones past the cap ("capped"). Only where a RingArena stands; the
## open world keeps its cover walls uncapped. The look (LOOK-B): BendLooks.rise as a wall comes up, BendLooks.shatter when
## one is shot down.
## Round 4 (LOOKS): your own (its meta bend_by your player) standing between the camera and your head, or within 2.5 m of
## the camera, is drawn at 35% in a screen-door (OwnFade; data/bending/fx_looks.json own_wall). A look only: it still stops
## shots, bodies and the bots' sight; one in front of you is cover and stays whole.

signal crumbled(raised: FormRaised, why: String)

const GROUP := &"form_raised"
## A wall's line is sampled this often (m) for the ground under it; less than MIN_W_M of it on dry ground: not raised.
const SAMPLE_M := 0.25
const MIN_W_M := 0.6

enum State { RISING, UP, CRUMBLING }

var kind := "wall"
## What it is made of: "earth", "mud", "stone", "snow", "wood" (FormMatter).
var matter := "earth"
## How it goes: "dust", "slump", "rubble", "snow", "splinters".
var crumble_style := "dust"
## Over the ground: x across, y up, z through (the wall); the pillar's x and z its diameter.
var size := Vector3(3.0, 2.0, 0.6)
var rise_s := 0.7
var life_s := 60.0
var hits_max := 4
var hit_min := 10.0
var crumble_s := 1.4
var hits := 0
var age := 0.0
## Its rise eased in and out (the pillar: whoever stands on it is carried up and set down at the top without a throw;
## the wall bursts up and slows).
var ease_smooth := false
var state := State.RISING
## Where its base stands (world; the ground), and how it faces.
var base := Transform3D.IDENTITY
var mesh_instance: MeshInstance3D
## What mend says packing it again ("The earth packed again").
var mended_line := "The earth packed again"

var _t := 0.0
var _shape: CollisionShape3D
var _crumble_why := ""
## Raised over water entirely (dry_span: none of it dry): never seen, gone the next step.
var drowned := false
## The width it was asked for before the water cut it (m).
var asked_w := 0.0

## The walls counted (count_wall), in the order raised.
static var _wall_n := 0


## A raised wall or pillar at `xf` (its origin on the ground, +Y up, +Z through it) under `parent`; `d` the move's numbers
## with its matter's over them (FormMatter.numbers: matter, crumble, surface, mended; for a wall from a tree, species).
static func raise(parent: Node, p_kind: String, xf: Transform3D, d: Dictionary, seed := 0) -> FormRaised:
	var r := FormRaised.new()
	r.name = "FormWall" if p_kind == "wall" else "FormPillar"
	r.kind = p_kind
	r.base = xf
	r.matter = String(d.get("matter", "earth"))
	r.crumble_style = String(d.get("crumble", "dust"))
	r.mended_line = String(d.get("mended", r.mended_line))
	if p_kind == "wall":
		r.size = Vector3(float(d.get("width_m", 3.0)), float(d.get("height_m", 2.0)), float(d.get("thick_m", 0.6)))
	else:
		var rr := float(d.get("radius_m", 0.55))
		r.size = Vector3(rr * 2.0, float(d.get("height_m", 3.0)), rr * 2.0)
	r.rise_s = float(d.get("rise_s", 0.7))
	r.life_s = float(d.get("life_s", 60.0))
	r.hits_max = int(d.get("hits", 4))
	r.hit_min = float(d.get("hit_min", 10.0))
	r.crumble_s = float(d.get("crumble_s", 1.4))
	r.ease_smooth = p_kind == "pillar"
	r.asked_w = r.size.x
	if p_kind == "wall" and xf.basis.y.normalized().dot(Vector3.UP) > 0.9:
		# (never over water: cut to the dry part of its line, or none)
		var span := dry_span(parent, xf, r.size.x)
		if span.y - span.x < MIN_W_M:
			r.drowned = true
		elif span.y - span.x < r.size.x - 0.01:
			var across := xf.basis.x.normalized()
			xf.origin += across * (span.x + span.y) * 0.5
			r.size.x = span.y - span.x
			r.base = xf
	r.sync_to_physics = true
	r.set_meta(&"surface", String(d.get("surface", "stone")))
	if not r.drowned:
		r.add_to_group(GROUP)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bury := FormModels.BURY_M
	if p_kind == "wall":
		var bx := BoxShape3D.new()
		bx.size = Vector3(r.size.x, r.size.y + bury, r.size.z)
		cs.shape = bx
	else:
		var cy := CylinderShape3D.new()
		cy.radius = r.size.x * 0.5
		cy.height = r.size.y + bury
		cs.shape = cy
	cs.position = Vector3(0.0, (r.size.y - bury) * 0.5, 0.0)
	r._shape = cs
	r.add_child(cs)
	r.mesh_instance = MeshInstance3D.new()
	r.mesh_instance.name = "Mesh"
	if p_kind == "pillar":
		r.mesh_instance.mesh = FormModels.pillar_mesh(r.size.x * 0.5, r.size.y, seed, bury, r.matter)
	elif r.matter == "wood":
		r.mesh_instance.mesh = FormModels.palisade_mesh(r.size.x, r.size.y, float(d.get("log_r", r.size.z * 0.45)), seed,
				String(d.get("species", "")), bury)
	else:
		r.mesh_instance.mesh = FormModels.wall_mesh(r.size.x, r.size.y, r.size.z, seed, bury, r.matter)
	r.mesh_instance.set_instance_shader_parameter(&"seed", float(seed % 97))
	r.add_child(r.mesh_instance)
	# (round 4 LOOKS: your own wall or pillar between the camera and your head, or by the camera, drawn faded; it blocks
	# all the same: OwnFade, form_matter's fade)
	OwnFade.attach(r, [r.mesh_instance], AABB(Vector3(-r.size.x * 0.5, 0.0, -r.size.z * 0.5), r.size), &"fade")
	parent.add_child(r)
	r.global_transform = r._at(0.0)
	if p_kind == "wall" and not r.drowned and r.matter != "wood" and r.is_inside_tree():
		BendLooks.rise(r.base.origin, r.size, r.base.basis.z.normalized(), "ice" if r.matter == "snow" else "earth")
	if r.drowned:
		r.visible = false
		cs.disabled = true
		r.state = State.CRUMBLING
		r.crumble_s = 0.0
		r._crumble_why = "water"
	return r


## The dry part of a wall's line at `xf` (its origin the middle of its foot, +X across) `width` m across, as [from, to] along
## its +X (m from its middle; to < from: none): sampled about every SAMPLE_M, a sample dry when the ground under it
## (FormEffects.ground_at, 8 m down) is not under water (TorchState.under_water just over it); a dry run ends half a step short
## of the first wet sample; the longest run, the one nearest the middle on a tie. The whole line when nothing is water.
static func dry_span(parent: Node, xf: Transform3D, width: float) -> Vector2:
	var half := width * 0.5
	var tree := parent.get_tree() if parent != null and parent.is_inside_tree() else null
	if tree == null or tree.get_nodes_in_group(TorchState.WATER_GROUP).is_empty():
		return Vector2(-half, half)
	var world := (parent as Node3D).get_world_3d() if parent is Node3D else parent.get_viewport().find_world_3d()
	var n := maxi(3, ceili(width / SAMPLE_M) + 1)
	var step := width / float(n - 1)
	var across := xf.basis.x.normalized()
	var dry: Array[bool] = []
	var any_wet := false
	for i in n:
		var p := xf.origin + across * (-half + step * i)
		var g := FormEffects.ground_at(parent, p, 8.0)
		var wet := TorchState.under_water(world, tree, g + Vector3.UP * 0.1)
		dry.append(not wet)
		any_wet = any_wet or wet
	if not any_wet:
		return Vector2(-half, half)
	var best := Vector2(1.0, -1.0)
	var i := 0
	while i < n:
		if not dry[i]:
			i += 1
			continue
		var j := i
		while j + 1 < n and dry[j + 1]:
			j += 1
		var run := Vector2(-half + step * i - (step * 0.5 if i > 0 else 0.0), -half + step * j + (step * 0.5 if j < n - 1 else 0.0))
		var bw := best.y - best.x
		if run.y - run.x > bw + 1e-4 or (absf(run.y - run.x - bw) <= 1e-4 and absf(run.x + run.y) < absf(best.x + best.y)):
			best = run
		i = j + 1
	return best


## The height a thing falling at `at` comes to rest on (world y): the ground under it (FormEffects.ground_at, 12 m down: a
## deck, a raised floor, the bed of the water round it), never the terrain's height under a deck; `n` any node in the world.
static func floor_under(n: Node, at: Vector3) -> float:
	return FormEffects.ground_at(n, at, 12.0).y


## Its place `u` (0..1) of the way up.
func _at(u: float) -> Transform3D:
	var e := smoothstep(0.0, 1.0, u) if ease_smooth else 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.4)
	var down := (size.y + 0.08) * (1.0 - e)
	return Transform3D(base.basis, base.origin - base.basis.y * down)


## The top (world), where one stands on a pillar.
func top() -> Vector3:
	return global_transform * Vector3(0.0, size.y, 0.0)


func is_up() -> bool:
	return state == State.UP


func _physics_process(dt: float) -> void:
	_t += dt
	match state:
		State.RISING:
			var u := _t / maxf(rise_s, 0.01)
			var shake := Vector3(sin(_t * 61.0), 0.0, cos(_t * 53.0)) * 0.012 * (1.0 - u) if u < 1.0 else Vector3.ZERO
			var xf := _at(u)
			xf.origin += xf.basis * shake
			global_transform = xf
			if u >= 1.0:
				state = State.UP
				global_transform = _at(1.0)
				age = 0.0
		State.UP:
			age += dt
			if life_s > 0.0 and age >= life_s:
				crumble("time")
		State.CRUMBLING:
			var u := clampf(_t / maxf(crumble_s, 0.01), 0.0, 1.0)
			_crumbling(u)
			if u > 0.4 and _shape != null and not _shape.disabled:
				_shape.disabled = true
			if u >= 1.0:
				queue_free()


## How it goes, `u` (0..1) of the way (crumble_style; see the header).
func _crumbling(u: float) -> void:
	var shake := Vector3(sin(_t * 47.0), 0.0, cos(_t * 41.0)) * 0.02
	var xf: Transform3D
	match crumble_style:
		"slump":
			# (it sags and spreads, sinking slower: mud going back to the ground)
			xf = _at(1.0 - u * u * 0.85)
			if mesh_instance != null:
				mesh_instance.scale = Vector3(1.0 + 0.22 * u, 1.0 - 0.55 * smoothstep(0.0, 0.8, u), 1.0 + 0.45 * u)
			shake *= 0.3
		"rubble":
			# (it breaks and drops fast, its stones tumbling out: Rubble)
			xf = _at(1.0 - smoothstep(0.0, 0.7, u))
			shake *= 2.0
		"splinters":
			# (it leans back, away from the caster, as it sinks)
			xf = _at(1.0 - u * u)
			xf.basis = xf.basis * Basis(Vector3.RIGHT, deg_to_rad(24.0) * smoothstep(0.0, 1.0, u))
		_:
			xf = _at(1.0 - u * u)
	xf.origin += xf.basis * shake
	global_transform = xf


## Struck (Hit.deliver): a hit of at least hit_min counts, its matter thrown off; hits_max of them and it crumbles.
func apply_hit(damage: float, point: Vector3, dir: Vector3, _source: Node = null, _part := "body") -> void:
	if state == State.CRUMBLING or damage < hit_min:
		return
	if has_meta(&"bend_brace"):
		remove_meta(&"bend_brace")            # (mended or braced: this hit is taken free; round 2's Mend)
		return
	hits += 1
	if is_inside_tree():
		_chips(get_tree().current_scene, point, -dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP, 10)
	if hits >= hits_max:
		crumble("shot")


## Its matter thrown off at `point` along `normal`.
func _chips(scn: Node, point: Vector3, normal: Vector3, n: int) -> void:
	match matter:
		"wood":
			GatherFx.wood_chips(scn, point, normal, n + 4)
		"mud":
			GatherFx._dust(scn, point + normal * 0.04, normal, n, Vector2(0.05, 0.16), 0.7, Color(0.16, 0.11, 0.07, 0.75))
		"snow":
			GatherFx._dust(scn, point + normal * 0.04, normal, n + 4, Vector2(0.06, 0.2), 0.9, Color(0.9, 0.93, 0.97, 0.7))
		"earth":
			GatherFx.stone_chips(scn, point, normal, n / 2)
			GatherFx.soil(scn, point, normal, n)
		_:
			GatherFx.stone_chips(scn, point, normal, n)


## Worn by shot (mend can pack it again).
func worn() -> bool:
	return state != State.CRUMBLING and hits > 0


## Packed again (mend): its hits gone, its time begun again.
func mend() -> void:
	hits = 0
	age = 0.0


func crumble(why: String) -> void:
	if state == State.CRUMBLING:
		return
	state = State.CRUMBLING
	_t = 0.0
	_crumble_why = why
	if is_inside_tree():
		var scn := get_tree().current_scene
		var at := global_transform.origin
		var wide := maxf(size.x, size.z) * 0.5
		match crumble_style:
			"snow":
				GatherFx._dust(scn, at + Vector3.UP * 0.3, Vector3.UP, 30, Vector2(0.3, 0.8), 1.8, Color(0.9, 0.93, 0.97, 0.45))
			"slump":
				for i in 3:
					GatherFx._dust(scn, global_transform * Vector3((float(i) - 1.0) * size.x * 0.3, size.y * 0.4, 0.0), Vector3.UP, 10,
							Vector2(0.06, 0.18), 0.9, Color(0.16, 0.11, 0.07, 0.7))
			"splinters":
				GatherFx.fall_dust(scn, at, wide)
				for i in 4:
					GatherFx.wood_chips(scn, global_transform * Vector3((float(i) - 1.5) * size.x * 0.25, size.y * 0.55, 0.0), global_basis.z, 14)
			"rubble":
				GatherFx.fall_dust(scn, at, wide)
				for i in 3:
					GatherFx.stone_chips(scn, global_transform * Vector3((float(i) - 1.0) * size.x * 0.3, size.y * 0.6, 0.0), Vector3.UP, 10)
				Rubble.spill(scn, self)
			_:
				GatherFx.fall_dust(scn, at, wide)
				for i in 3:
					GatherFx.stone_chips(scn, global_transform * Vector3((float(i) - 1.0) * size.x * 0.3, size.y * 0.6, 0.0), Vector3.UP, 8)
		if why == "shot" and kind == "wall" and matter != "wood":
			BendLooks.shatter(at, size, global_basis.z.normalized(), "ice" if matter == "snow" else "earth")
		FormEffects.sfx("splinter" if matter == "wood" else "crumble", at, -2.0, 0.8)
	crumbled.emit(self, why)


## Wall `r` (raised by the caster in its meta bend_by) counted against the ring's cap: past max_walls of that caster's
## standing walls (earth and ice alike), the oldest crumble ("capped"). Returns how many went.
static func count_wall(r: FormRaised) -> int:
	if r == null or not is_instance_valid(r) or r.drowned or r.kind != "wall" or not r.has_meta(&"bend_by") \
			or not r.is_inside_tree():
		return 0
	_wall_n += 1
	r.set_meta(&"wall_n", _wall_n)
	var cap := wall_cap(r.get_tree())
	if cap <= 0:
		return 0
	var by := int(r.get_meta(&"bend_by"))
	var mine: Array[FormRaised] = []
	for n in r.get_tree().get_nodes_in_group(GROUP):
		var w := n as FormRaised
		if w != null and w.state != State.CRUMBLING and w.has_meta(&"wall_n") and int(w.get_meta(&"bend_by", 0)) == by:
			mine.append(w)
	mine.sort_custom(func(a: FormRaised, b: FormRaised) -> bool: return int(a.get_meta(&"wall_n")) < int(b.get_meta(&"wall_n")))
	var gone := 0
	while mine.size() > cap:
		mine.pop_front().crumble("capped")
		gone += 1
	return gone


## The walls a caster may have standing at once: rules.json max_walls where a ring stands (0: no cap).
static func wall_cap(tree: SceneTree) -> int:
	if tree == null or RingArena.find(tree) == null:
		return 0
	return int(RingRules.num("max_walls", 0.0))


## The stones a stone wall (or pillar) falls into (drawn only): fieldstone lumps tumbling out of it to its foot on both sides,
## lying a moment, then sinking back into the ground. No physics: each a simple fall with a bounce, one node for them all.
class Rubble:
	extends Node3D

	const N := 9
	const LIE_S := 2.4
	const SINK_S := 1.2
	const G := 9.8

	var _pieces: Array[MeshInstance3D] = []
	var _vel: Array[Vector3] = []
	var _spin: Array[Vector3] = []
	var _floor: Array[float] = []
	var _t := 0.0

	static func spill(parent: Node, r: FormRaised) -> void:
		if DisplayServer.get_name() == "headless" or parent == null:
			return
		var ru := Rubble.new()
		ru.name = "FormRubble"
		parent.add_child(ru)
		var rng := RandomNumberGenerator.new()
		rng.seed = r.get_instance_id()
		var mesh := FormModels.chunk_mesh(0.17, 7, "stone")
		for i in N:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.set_instance_shader_parameter(&"seed", float(i * 7))
			var lp := Vector3(rng.randf_range(-0.45, 0.45) * r.size.x, rng.randf_range(0.3, 0.9) * r.size.y, 0.0)
			var side := 1.0 if i % 2 == 0 else -1.0
			ru.add_child(mi)
			mi.global_position = r.global_transform * lp
			mi.scale = Vector3.ONE * rng.randf_range(0.7, 1.35)
			mi.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
			var out := r.global_basis.z * side * rng.randf_range(1.0, 2.4) + r.global_basis.x * rng.randf_range(-0.6, 0.6)
			ru._pieces.append(mi)
			ru._vel.append(out + Vector3.UP * rng.randf_range(0.5, 1.8))
			ru._spin.append(Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-6.0, 6.0)))
			var at := mi.global_position + out * 0.6
			ru._floor.append(FormRaised.floor_under(parent, at))           # (into the water round a deck, onto its bed)

	func _process(dt: float) -> void:
		_t += dt
		for i in _pieces.size():
			var mi := _pieces[i]
			if _t < LIE_S:
				var v := _vel[i]
				v.y -= G * dt
				var p := mi.global_position + v * dt
				var fy := _floor[i] + 0.08 * mi.scale.x
				if p.y < fy:
					p.y = fy
					v = Vector3(v.x * 0.45, absf(v.y) * 0.25, v.z * 0.45)
					_spin[i] *= 0.5
				_vel[i] = v
				mi.global_position = p
				mi.rotation += _spin[i] * dt
			else:
				mi.global_position.y -= dt * 0.35 / SINK_S
		if _t >= LIE_S + SINK_S:
			queue_free()
