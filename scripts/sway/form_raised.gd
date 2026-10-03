class_name FormRaised
extends AnimatableBody3D
## Earth a Form cast raised (FormEffects; SwayCaster's art "form"): the earth wall (kind "wall": a slab of packed earth and stone
## width x height x thick, the player and fighters take cover behind it: NpcCover finds its box) or the pillar ("pillar": a
## column to stand on and climb). It rises out of the ground over rise_s (an AnimatableBody3D moved in the physics step: whoever
## stands on it is carried up), stands life_s, and crumbles (sinks back into the ground in a cloud of dust, its stones
## breaking off) at the end of it or after `hits_max` musket hits of at least hit_min damage (Hit.deliver finds apply_hit
## here). Mend packs a worn one again (mend(): its hits and its time back). Group GROUP.

signal crumbled(raised: FormRaised, why: String)

const GROUP := &"form_raised"

enum State { RISING, UP, CRUMBLING }

var kind := "wall"
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

var _t := 0.0
var _shape: CollisionShape3D
var _crumble_why := ""


## A raised wall or pillar at `xf` (its origin on the ground, +Y up, +Z through it) under `parent`; `d` the move's numbers.
static func raise(parent: Node, p_kind: String, xf: Transform3D, d: Dictionary, seed := 0) -> FormRaised:
	var r := FormRaised.new()
	r.name = "FormWall" if p_kind == "wall" else "FormPillar"
	r.kind = p_kind
	r.base = xf
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
	r.sync_to_physics = true
	r.set_meta(&"surface", "stone")
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
	r.mesh_instance.mesh = FormModels.wall_mesh(r.size.x, r.size.y, r.size.z, seed) if p_kind == "wall" \
			else FormModels.pillar_mesh(r.size.x * 0.5, r.size.y, seed)
	r.add_child(r.mesh_instance)
	parent.add_child(r)
	r.global_transform = r._at(0.0)
	return r


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
			var xf := _at(1.0 - u * u)
			xf.origin += xf.basis * Vector3(sin(_t * 47.0), 0.0, cos(_t * 41.0)) * 0.02
			global_transform = xf
			if u > 0.4 and _shape != null and not _shape.disabled:
				_shape.disabled = true
			if u >= 1.0:
				queue_free()


## Struck (Hit.deliver): a hit of at least hit_min counts, its chips flying; hits_max of them and it crumbles.
func apply_hit(damage: float, point: Vector3, dir: Vector3, _source: Node = null, _part := "body") -> void:
	if state == State.CRUMBLING or damage < hit_min:
		return
	hits += 1
	if is_inside_tree():
		GatherFx.stone_chips(get_tree().current_scene, point, -dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP, 10)
	if hits >= hits_max:
		crumble("shot")


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
		GatherFx.fall_dust(scn, at, maxf(size.x, size.z) * 0.5)
		for i in 3:
			GatherFx.stone_chips(scn, global_transform * Vector3((float(i) - 1.0) * size.x * 0.3, size.y * 0.6, 0.0), Vector3.UP, 8)
		FormEffects.sfx("crumble", at, -2.0, 0.8)
	crumbled.emit(self, why)
