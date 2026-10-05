class_name FormSpikes
extends Node3D
## Stone Form's spike bursting out of the ground (FormEffects.stone_form, mode spike; SwayCaster's art "form"): at the circle
## the ground breaks (stone chips, dust, its sound), `shards` small spikes (shard_m high) come up round the great one (the
## FormStone that stays) and sink again after a few seconds (no colliders). Whoever stands within hit_r of it as it comes up is
## struck once (Hit.deliver with `damage`, from the ground up) and knocked off their feet: a fighter thrown aside people_mps and
## up_mps and kept staggering down_s (NpcFighter's hit reaction held), an animal shoved animal_mps and put to flight. The caster
## is never struck (any caster: a SwayCaster, a BendCaster, a body, BendCaster.wrap; its own bodies, a fighter's hit parts
## too, left out). Group GROUP.

signal struck(target: Node, damage: float)

const GROUP := &"form_spikes"
const SHARDS_LIFE_S := 5.0
const SHARD_SINK_S := 0.8

var caster: BendCaster
var d := {}
var at := Vector3.ZERO
var dir := Vector3.FORWARD
var shards: Array[MeshInstance3D] = []
## Who has been struck (instance ids).
var hit := {}
## The great spike that stays (a FormStone).
var stone: FormStone

var _feet: Array[Vector3] = []
var _heights: Array[float] = []
var _lean: Array[Basis] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


## The burst at `p_at` (on the ground) round the great spike `s`, the caster's flat way `way`, under `parent`: the strike now.
static func burst(parent: Node, c: Variant, p_at: Vector3, way: Vector3, p_d: Dictionary, s: FormStone = null) -> FormSpikes:
	var b := FormSpikes.new()
	b.name = "FormSpikes"
	b.caster = BendCaster.wrap(c)
	b.d = p_d
	b.at = p_at
	b.stone = s
	b.dir = Vector3(way.x, 0.0, way.z).normalized() if Vector2(way.x, way.z).length() > 1e-4 else Vector3.FORWARD
	b.add_to_group(GROUP)
	parent.add_child(b)
	b.global_position = p_at
	b._rng.seed = absi(hash(Vector3i(roundi(p_at.x * 10.0), roundi(p_at.y * 10.0), roundi(p_at.z * 10.0))))
	b._lay()
	b._erupt()
	return b


func _lay() -> void:
	var n := int(d.get("shards", 4))
	var hr: Array = d.get("shard_m", [0.35, 0.7])
	var r0 := float(d.get("radius_m", 0.26))
	for i in n:
		var a := TAU * (float(i) + _rng.randf_range(-0.25, 0.25)) / maxf(n, 1)
		var off := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(r0 + 0.12, r0 + 0.38)
		var p := FormEffects.ground_at(self, at + off)
		var h := _rng.randf_range(float(hr[0]), float(hr[1]))
		var mi := MeshInstance3D.new()
		mi.name = "Shard%d" % i
		mi.mesh = FormModels.spike_mesh(_rng.randf_range(0.07, 0.11), h, 50 + i, FormModels.BURY_M, stone.matter if stone != null else "stone")
		mi.set_instance_shader_parameter(&"seed", float(i * 13))
		add_child(mi)
		# (each leans out from the great spike)
		var out := Vector3(off.x, 0.0, off.z).normalized()
		var tilt := Basis(Vector3.UP.cross(out).normalized(), deg_to_rad(_rng.randf_range(14.0, 28.0)))
		_feet.append(p)
		_heights.append(h)
		_lean.append(tilt)
		shards.append(mi)
		mi.global_transform = Transform3D(tilt, p - Vector3.UP * (h + 0.1))


func _physics_process(dt: float) -> void:
	_t += dt
	var rise := maxf(float(d.get("rise_s", 0.12)), 0.01)
	for i in shards.size():
		var t0 := 0.03 * i
		var u := clampf((_t - t0) / rise, 0.0, 1.0)
		if _t >= SHARDS_LIFE_S:
			u = 1.0 - clampf((_t - SHARDS_LIFE_S - 0.05 * i) / SHARD_SINK_S, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 3.0)
		shards[i].global_transform = Transform3D(_lean[i], _feet[i] - Vector3.UP * (_heights[i] + 0.1) * (1.0 - e))
	if _t >= SHARDS_LIFE_S + SHARD_SINK_S + 0.05 * shards.size():
		queue_free()


## The ground breaks: chips, dust, its sound, and whoever stands by it struck.
func _erupt() -> void:
	var scn := get_tree().current_scene
	GatherFx.stone_chips(scn, at, Vector3.UP, 16)
	GatherFx.soil(scn, at, Vector3.UP, 12)
	GatherFx.fall_dust(scn, at, 0.9)
	FormEffects.sfx("spike", at, -2.0, 0.8)
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = float(d.get("hit_r", 0.85))
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.7)
	q.collision_mask = 0xFFFFFFFF
	q.collide_with_areas = false
	var ex: Array[RID] = []
	if caster != null and caster.valid():
		ex.append_array(caster.exclude())
	if stone != null:
		ex.append(stone.get_rid())
	q.exclude = ex
	for h: Dictionary in space.intersect_shape(q, 24):
		var col := h.get("collider") as Node
		var who := taker(col, caster)
		if who == null or hit.has(who.get_instance_id()):
			continue
		hit[who.get_instance_id()] = true
		_strike(who, col)


## The one that takes a blow through `col` (the first up its parents with apply_hit), never the caster (`c`: a BendCaster, a
## SwayCaster, a body, null none; its body and anything under it, a fighter's hit parts, are never taken).
static func taker(col: Node, c: Variant) -> Node:
	var me := _body_of(c)
	var n := col
	while n != null:
		if me != null and n == me:
			return null
		if n.has_method(&"apply_hit"):
			return n
		n = n.get_parent()
	return null


func _strike(who: Node, col: Node) -> void:
	var dmg := float(d.get("damage", 30.0))
	var w := (who as Node3D).global_position if who is Node3D else at
	var away := w - at
	away.y = 0.0
	if away.length_squared() < 1e-4:
		away = Vector3.UP.cross(dir)
	away = away.normalized()
	var by := _body_of(caster)
	Hit.deliver(col, dmg, w + Vector3.UP * 0.6, (Vector3.UP * 0.8 + away).normalized(), by)
	struck.emit(who, dmg)
	if who is NpcFighter:
		var f := who as NpcFighter
		if f.is_dead():
			return
		SwayEffects.shove_fighter(f, away * float(d.get("people_mps", 4.0)), by)
		f.velocity.y = float(d.get("up_mps", 2.5))
		if f.action == "flinch":
			f._act_t = maxf(f._act_t, float(d.get("down_s", 1.4)))
	elif who is WildAnimal:
		var a := who as WildAnimal
		if not a.is_dead():
			SwayEffects.shove_animal(a, away * float(d.get("animal_mps", 4.0)), at)


## The body of caster `c` (a BendCaster's, a SwayCaster's player, a body itself; null none).
static func _body_of(c: Variant) -> Node:
	if c == null or not is_instance_valid(c):
		return null
	if c is BendCaster:
		var b := (c as BendCaster).body
		return b if b != null and is_instance_valid(b) else null
	if c is SwayCaster:
		return (c as SwayCaster).player
	return c as Node
