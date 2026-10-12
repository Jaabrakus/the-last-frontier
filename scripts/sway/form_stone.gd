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
## Each looks like a stone of the ground it came out of (`matter`, FormMatter.rock_material: data/sway/moves.json
## stone_form.looks; the user, 2026-10-03: "okay the stone spike is cool okay it works but we need to work on the textures"):
## our own weathered fieldstone, its freshly broken faces lighter, the ground's stain on its foot.

const GROUP := &"form_stones"
## ROUND 2 (skills_r2 spec §2.10, earth's ammo on the deck): a LOOSE stone is one let fall (a lock called off, a hit that
## emptied it, a Wind Guard's drop, a stone off a wall hit): make_loose(s, by) marks it its maker's (meta LOOSE_META, the
## body's instance id) and keeps at most Bending.stones().loose_max of one maker's lying: a fourth sinks the oldest. Any earth
## fighter may shove a loose stone within shove_loose_m of himself (BendEffects.shove); a raised or held one is its raiser's.
const LOOSE_META := &"bend_loose_by"

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
	s.mesh_instance.mesh = FormModels.spike_mesh(s.radius, s.height, 31 + seed % 7, FormModels.BURY_M, p_matter)
	s.mesh_instance.set_instance_shader_parameter(&"seed", float(seed))
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
	s.mesh_instance.mesh = FormModels.ball_mesh(s.radius, 41 + seed % 7, p_matter)
	s.mesh_instance.set_instance_shader_parameter(&"seed", float(seed))
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
	NetSpells.tag(s)                              # (online: its name in its cast's run)
	return s


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
	var tw := create_tween()
	tw.tween_property(mesh_instance, ^"scale", Vector3.ONE * k, over_s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
				if kind == "cannonball":
					freeze = false              # (resting on the ground, in the physics: pushed, it rolls)
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
