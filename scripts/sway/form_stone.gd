class_name FormStone
extends RigidBody3D
## A stone Stone Form left (FormEffects.stone_form; data/sway/moves.json stone_form; docs/main_story.md 11.10): our own shapes
## (FormModels).
##   spike       kind "spike": a jagged spike burst up out of the ground at the circle in rise_s (FormSpikes strikes whoever
##               stands there), standing in the earth (frozen, kinematic): cover to stand behind, a lance for Gust to hurl
##   cannonball  kind "cannonball": a round stone ball (radius_m, about 0.5 m across) that rises out of the ground in rise_s and
##               rests on it, in the physics (mass_kg): Gust pushes it, it rolls
## Both are stones Gust lifts and hurls (GustLift; group GROUP, meta sway_stone). Each lies life_s untouched and then
## sinks back into the ground in sink_s; one lifted begins its time again where it comes to rest (rest_again()).
## Online (NetStones): named as it is made; the host's physics rolls it and its state goes to the others, whose own stay still
## and follow the host's word.
## Each looks like a stone of the ground it came out of (`matter`, FormMatter.rock_material: data/sway/moves.json
## stone_form.looks; the user, 2026-10-03: "okay the stone spike is cool okay it works but we need to work on the textures"):
## our own weathered fieldstone, its freshly broken faces lighter, the ground's stain on its foot.

const GROUP := &"form_stones"
## ROUND 2 (skills_r2 spec §2.10, earth's ammo on the deck): a LOOSE stone is one let fall (a lock called off, a hit that
## emptied it, a Wind Guard's drop, a stone off a wall hit): make_loose(s, by) marks it its maker's (meta LOOSE_META, the
## body's instance id) and keeps at most Bending.stones().loose_max of one maker's lying: a fourth sinks the oldest. Any earth
## fighter may shove a loose stone within shove_loose_m of himself (BendEffects.shove); a raised or held one is its raiser's.
const LOOSE_META := &"bend_loose_by"
## A stone another element's guard made of both as it swung it back (BendZone._lift_swing; the owner, 2026-10-12: where two
## elements meet in a guard what goes back is made of both): "magma" (a Spike or a Boulder a Parry melted), "mud" (one a Turn
## swung round in water). Its look (pack_look) and its flight's (magma burns, mud slows) by it, kept should an earth Catch take
## it (E throws it so: BendZone.return_stone, mud as a mud wave); told the others with the stone (NetStones.MARKS).
const PACK_META := &"bend_pack"
## Round 2: the cel stone is drawn this much wider than its body (a look: the hit and the collision are the body's own).
const DRAW_K := 1.3
## The smear on the release: its drawn body stretched along its flight, 1.9 times at the start and back over SMEAR_S.
const SMEAR_K := 1.9
const SMEAR_S := 0.07

## Loose stones in the order they were let fall: maker's instance id -> [FormStone].
static var _loose := {}

enum State { RISING, RESTING, HELD, SINKING }

var kind := "spike"
var radius := 0.26
var height := 1.75
var rise_s := 0.12
var life_s := 45.0
var sink_s := 1.0
var state := State.RISING
var age := 0.0
## The ground it came out of ("earth", "mud", "stone", "snow": FormMatter), its look.
var matter := "stone"
## Where it stands risen (world): the spike's foot on the ground, its point up; the ball's middle.
var base := Transform3D.IDENTITY
var mesh_instance: MeshInstance3D
## Its mesh's seed (spike(), ball()): cel_dress draws the same stone's shape from it.
var look_seed := 0

var _t := 0.0
var _sink_from := Transform3D.IDENTITY


## A spike of `d` (stone_form.spike) standing at `foot` (on the ground) under `parent`, leaning a little away from `way`, a
## stone of `matter`'s ground.
static func spike(parent: Node, foot: Vector3, way: Vector3, d: Dictionary, seed := 0, p_matter := "stone") -> FormStone:
	var s := _make("spike", d)
	s.matter = p_matter
	s.radius = float(d.get("radius_m", 0.26))
	s.height = float(d.get("height_m", 1.75))
	s.mass = 30.0
	var flat := Vector3(way.x, 0.0, way.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.FORWARD
	var side := Vector3.UP.cross(flat).normalized()
	var lean := Basis(side, deg_to_rad(9.0)) * Basis(flat, deg_to_rad(5.0 * (1.0 if seed % 2 == 0 else -1.0)))
	s.base = Transform3D(lean, foot)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cy := CylinderShape3D.new()
	cy.radius = s.radius * 0.6
	cy.height = s.height * 0.85 + FormModels.BURY_M
	cs.shape = cy
	cs.position = Vector3(0.0, (s.height * 0.85 - FormModels.BURY_M) * 0.5, 0.0)
	s.add_child(cs)
	s.mesh_instance = MeshInstance3D.new()
	s.mesh_instance.name = "Mesh"
	s.look_seed = seed
	s.mesh_instance.mesh = FormModels.spike_mesh(s.radius, s.height, 31 + seed % 7, FormModels.BURY_M, p_matter)
	FxParams.put(s.mesh_instance, &"seed", float(seed))
	s.add_child(s.mesh_instance)
	parent.add_child(s)
	s.global_transform = s._risen(0.0)
	return s


## A cannonball of `d` (stone_form.cannonball) rising out of the ground at `foot` under `parent`, a stone of `matter`'s ground.
static func ball(parent: Node, foot: Vector3, d: Dictionary, seed := 0, p_matter := "stone") -> FormStone:
	var s := _make("cannonball", d)
	s.matter = p_matter
	s.radius = float(d.get("radius_m", 0.26))
	s.height = s.radius * 2.0
	s.mass = float(d.get("mass_kg", 45.0))
	s.base = Transform3D(Basis.IDENTITY, foot + Vector3.UP * s.radius)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sp := SphereShape3D.new()
	sp.radius = s.radius
	cs.shape = sp
	s.add_child(cs)
	s.mesh_instance = MeshInstance3D.new()
	s.mesh_instance.name = "Mesh"
	s.look_seed = seed
	s.mesh_instance.mesh = FormModels.ball_mesh(s.radius, 41 + seed % 7, p_matter)
	FxParams.put(s.mesh_instance, &"seed", float(seed))
	s.add_child(s.mesh_instance)
	parent.add_child(s)
	s.global_transform = s._risen(0.0)
	return s


static func _make(p_kind: String, d: Dictionary) -> FormStone:
	var s := FormStone.new()
	s.name = "FormSpike" if p_kind == "spike" else "FormCannonball"
	s.kind = p_kind
	s.rise_s = float(d.get("rise_s", 0.12 if p_kind == "spike" else 0.6))
	s.life_s = float(d.get("life_s", 45.0))
	s.sink_s = float(d.get("sink_s", 1.0))
	s.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	s.freeze = true
	s.continuous_cd = true
	s.linear_damp = 0.15
	s.angular_damp = 0.8
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.rough = true
	pm.bounce = 0.12
	s.physics_material_override = pm
	s.set_meta(&"surface", "stone")
	s.set_meta(&"sway_stone", true)
	s.add_to_group(GROUP)
	NetStones.made(s)                             # (online: named in its cast's run, or the host's decision's: NetStones)
	return s


func _ready() -> void:
	# (the ring's stones are drawn in the cel style whoever made them: a cast's, a catch's, a kicked-up one, the deck's own)
	if matter in ["earth", "stone"] and BendLooks.live() and RingArena.find(get_tree()) != null:
		cel_dress()


## The stone drawn as earth in the show's cel style (2026-10-16; the owner: "as close to Anime Style Avatar: The Last Airbender as
## possible"): a bold faceted rock of three flat tones with a pale rim on its sun side and a dark drawn line round it (ToonFx
## "rock", BendLooks.outline), in place of the weathered fieldstone. A look only: its body, its size and its collision are as
## they were. Done in _ready for the stones of the ring; once.
func cel_dress() -> void:
	if mesh_instance == null or has_meta(&"cel_rock") or not BendLooks.live():
		return
	# (drawn bolder than its body, DRAW_K: from the player's camera 4 m off a 0.26 m stone read small; its collision is as it was)
	if kind == "spike":
		mesh_instance.mesh = ToonFx.spike_cel_mesh(radius * DRAW_K, height, look_seed % 5, FormModels.BURY_M)
	else:
		mesh_instance.mesh = ToonFx.boulder_mesh(radius * DRAW_K, look_seed % 5)
	mesh_instance.material_override = ToonFx.mat("rock")
	BendLooks.outline(mesh_instance, mesh_instance.mesh)
	set_meta(&"cel_rock", true)


## The smear (round 2: the show draws the thrown thing stretched along its way on the frame it leaves the hand): the drawn body
## stretched `k` times along the world direction `dir`, 1 giving it back whole. A look only (the body is untouched).
func smear(dir: Vector3, k: float) -> void:
	if mesh_instance == null or not has_meta(&"cel_rock"):
		return
	if not has_meta(&"smear_base"):
		set_meta(&"smear_base", mesh_instance.basis)
	var base: Basis = get_meta(&"smear_base")
	if k <= 1.001:
		mesh_instance.basis = base
		remove_meta(&"smear_base")
		return
	var d := (global_basis.inverse() * dir).normalized()
	var f := k - 1.0
	# (I + (k - 1) d d^T, column by column)
	var sb := Basis(Vector3(1.0, 0.0, 0.0) + d * (d.x * f), Vector3(0.0, 1.0, 0.0) + d * (d.y * f), Vector3(0.0, 0.0, 1.0) + d * (d.z * f))
	mesh_instance.basis = sb * base


## Grown in the hands (FormEffects.grow_raised: a Spike or a Boulder held on past its lock): its body `k` x its size at once,
## its look swelling to it over `over_s` (a little past and back).
func grow(k: float, over_s := 0.25) -> void:
	radius *= k
	height *= k
	var cs := get_node_or_null(^"Shape") as CollisionShape3D
	if cs != null and cs.shape != null:
		var sh := cs.shape.duplicate() as Shape3D
		if sh is SphereShape3D:
			(sh as SphereShape3D).radius *= k
		elif sh is CylinderShape3D:
			(sh as CylinderShape3D).radius *= k
			(sh as CylinderShape3D).height *= k
		cs.shape = sh
		cs.position *= k
	if mesh_instance == null:
		return
	if over_s <= 0.0 or not is_inside_tree():
		mesh_instance.scale = Vector3.ONE * k
		return
	# (it swells on twos, 12 a step a second, a little past its size and back, the shape changing in steps)
	var from := mesh_instance.scale
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(mesh_instance):
			var u := floorf(t * 12.0) / 12.0 / maxf(over_s, 0.01)
			var e := 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)
			mesh_instance.scale = from.lerp(Vector3.ONE * k, clampf(e, 0.0, 1.4)), 0.0, over_s, over_s)


## Its place `u` (0..1) of the way out of the ground.
func _risen(u: float) -> Transform3D:
	var e := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
	var down := (height + 0.1) * (1.0 - e)
	return Transform3D(base.basis, base.origin - Vector3.UP * down)


func is_risen() -> bool:
	return state != State.RISING


## Gust holds it up (GustLift): its own time stops.
func take() -> void:
	state = State.HELD
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## Come to rest again after Gust held it (where it fell, stuck or rolled): its time begins again.
func rest_again() -> void:
	state = State.RESTING
	age = 0.0


func _physics_process(dt: float) -> void:
	_t += dt
	NetStones.check(self, dt)                     # (online, the host's: its state told the others when it changes)
	match state:
		State.RISING:
			var u := _t / maxf(rise_s, 0.01)
			var xf := _risen(u)
			if kind == "cannonball":
				xf.basis = Basis(Vector3.UP, u * 1.3) * Basis(Vector3.RIGHT, u * 0.6)
				xf.origin += Vector3(sin(_t * 57.0), 0.0, cos(_t * 49.0)) * 0.01 * (1.0 - clampf(u, 0.0, 1.0))
			global_transform = xf
			if u >= 1.0:
				state = State.RESTING
				age = 0.0
				if kind == "cannonball" and NetSpells.decides():
					freeze = false              # (resting on the ground, in the physics: pushed, it rolls; online the host's)
					sleeping = false
		State.RESTING:
			age += dt
			if life_s > 0.0 and age >= life_s:
				sink()
		State.SINKING:
			var u := clampf(_t / maxf(sink_s, 0.01), 0.0, 1.0)
			global_transform = Transform3D(_sink_from.basis, _sink_from.origin - Vector3.UP * (height + 0.15) * u * u)
			if u >= 1.0:
				queue_free()


## Stone `s` shown as what it was packed of (PACK_META; on every machine; made again when it changes: a mud stone a Parry
## turns to magma): pebbles a fist of small stones in place of its own body, magma molten rock glowing with a warm light, mud
## wet earth. Nothing to show: as it is.
static func pack_look(s: FormStone) -> void:
	if s == null or not is_instance_valid(s) or s.mesh_instance == null:
		return
	var pack := String(s.get_meta(PACK_META, ""))
	var old := s.get_node_or_null(^"Pack")
	if old != null:
		if String(old.get_meta(&"pack", "")) == pack:
			return
		s.remove_child(old)
		old.queue_free()
		s.mesh_instance.visible = true
		s.mesh_instance.material_override = ToonFx.mat("rock") if s.has_meta(&"cel_rock") else null
	if pack == "":
		return
	var holder := Node3D.new()
	holder.name = "Pack"
	holder.set_meta(&"pack", pack)
	s.add_child(holder)
	match pack:
		"magma", "mud":
			# (our dripping mud blob in the matter's liquid look in place of the rock, a spike's the mud spear stood up along
			# it, its foot at the stone's; the rock tinted when the meshes are missing)
			var mm := BendLooks.mud_mesh("mud_spear" if s.kind == "spike" else "mud_blob")
			if mm != null:
				s.mesh_instance.visible = false
				var mi := MeshInstance3D.new()
				mi.name = "Mud"
				mi.mesh = mm
				mi.material_override = ToonFx.mat(pack)
				FxParams.put(mi, &"seed", float(s.get_instance_id() % 97) * 0.13)
				if s.kind == "spike":
					mi.rotation.x = PI / 2.0                 # (its point, -Z, up the spike)
					mi.scale = Vector3(s.radius * 3.6, s.radius * 3.6, s.height * 0.85)
					mi.position = Vector3(0.0, s.height * 0.5, 0.0)
				else:
					mi.scale = Vector3.ONE * s.radius * 2.15
				holder.add_child(mi)
			else:
				s.mesh_instance.material_override = ToonFx.mat(pack)
			if pack == "magma" and BendLooks.live():
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.5, 0.15)
				l.light_energy = 1.6
				l.omni_range = 2.2
				l.shadow_enabled = false
				holder.add_child(l)


## Stone `s` lies loose, `by`'s (null: no one's, uncapped): past loose_max of `by`'s the oldest sinks. It is held by no one.
static func make_loose(s: Node3D, by: Node) -> void:
	if s == null or not is_instance_valid(s):
		return
	for k: StringName in [&"bend_held_by", &"bend_raised_by"]:
		if s.has_meta(k):
			s.remove_meta(k)
	if by == null or not is_instance_valid(by):
		s.set_meta(LOOSE_META, 0)
		return
	var id := by.get_instance_id()
	s.set_meta(LOOSE_META, id)
	var list: Array = (_loose.get(id, []) as Array).filter(func(x: Variant) -> bool:
		return is_instance_valid(x) and int((x as Node).get_meta(LOOSE_META, -1)) == id and not (x is FormStone and (x as FormStone).state == State.SINKING))
	list.erase(s)
	list.append(s)
	var cap := int(Bending.stones().get("loose_max", 3))
	while cap > 0 and list.size() > cap:
		var old: Node = list.pop_front()
		if old is FormStone:
			(old as FormStone).sink()
		else:
			old.queue_free()
	_loose[id] = list


## The loose stones `by` let fall that still lie (oldest first).
static func loose_of(by: Node) -> Array:
	if by == null or not is_instance_valid(by):
		return []
	var id := by.get_instance_id()
	return (_loose.get(id, []) as Array).filter(func(x: Variant) -> bool:
		return is_instance_valid(x) and int((x as Node).get_meta(LOOSE_META, -1)) == id and not (x is FormStone and (x as FormStone).state == State.SINKING))


## Back into the ground (its time over).
func sink() -> void:
	if state == State.SINKING:
		return
	state = State.SINKING
	_t = 0.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_sink_from = global_transform
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	if is_inside_tree():
		GatherFx.fall_dust(get_tree().current_scene, global_position, radius * 2.0)
		FormEffects.sfx("crumble", global_position, -6.0, 1.1)


func _exit_tree() -> void:
	NetStones.gone(self)                          # (online, the host's: its end told the others)
