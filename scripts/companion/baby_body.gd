class_name BabyBody
extends Node3D
## The baby's body: THE GAME'S OWN (no head or body geometry of its own). A small instance of the game's character: Actor_B's
## skeleton and body v4 (assets/character/body/body.glb) dressed by the face engine from the child's look (ChildLook.infant: the
## parents' face nudged toward a newborn's; ChildLook.body_for_stage: the flat asexual child body) in a little linen shift, its
## proportions a newborn's (ChildProportion, baked into this baby's own copies of the meshes: a round head, big eyes, a short neck, a
## chubby barrel of a trunk, short thick arms and legs, small hands and feet; baby.json body.form), its skin the game's made smooth and
## soft on its own material (ChildSkin at the stage's smoothness). It blinks (the face engine's `blink`), breathes and opens its mouth
## (the `breath` and `mouth_open` shapes made by the bake, a dark mouth inside the lips). The animations (assets/baby/baby_anims.res,
## tools/baby/make_baby_anims.gd) are added to Actor_B's AnimationPlayer as the library "baby".
##   var b := BabyBody.create(look); b.play("cry"); b.set_frame(false); b.set_eyes(1.0); b.set_mouth(0.8)
## `frame` holds the model: lying on its back (head +x, front +y, left +z: the baby frame BabyHold carries) or upright (`ground`).
## Made with `async` the proportions are baked off the main thread (ChildProportion.shape_async): the body stays hidden until they are
## on (`shaped`, ready_body), a few frames from the caches, two or three seconds for a look and stage never baked before.

signal shaped   ## the async bake is on (the body shows)

const ACTOR := "res://characters/Actor_B.tscn"
const ANIMS := "res://assets/baby/baby_anims.res"
const LIB := "baby"

## Tests and shots: off shows the game's adult skin; no round_head leaves the head its own shape.
static var soften := true
static var round_head := true

var frame: Node3D
var model: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var body: CharacterBodyMesh
var props: ChildProportion
var mouth_node: MeshInstance3D
var mouth_attachment: BoneAttachment3D
var ground := false
var ready_body := true
var stage := "newborn"
var look := {}
var _eyes := 0.0
var _last_lid := -1.0
var _mouth := -1.0
var _mouth_size := Vector3(0.02, 0.012, 0.012)
var _breath := -1.0
var _t := 0.0
var _next := 3.0
var _rng := RandomNumberGenerator.new()


static func cfg() -> Dictionary:
	return (BabyCare.cfg().get("body", {}) as Dictionary)


## The body dressed with `look` (the child's look; infant() and the child body are applied here). Null if the game's character is missing.
static func create(lk: Dictionary, stage_id := "newborn", async := false) -> BabyBody:
	var scene := BackgroundLoad.take(ACTOR) as PackedScene
	if scene == null or not ResourceLoader.exists(BodyMaterials.BODY_GLB):
		return null
	var b := BabyBody.new()
	b.name = "BabyBody"
	b.stage = stage_id
	b.frame = Node3D.new()
	b.frame.name = "Frame"
	b.add_child(b.frame)
	b.model = scene.instantiate() as Node3D
	b.frame.add_child(b.model)
	b.sk = b.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := b.model.find_children("*", "AnimationPlayer", true, false)
	b.ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	b.body = CharacterBodyMesh.attach_parts(b.sk, b.ap, {"head": BodyMaterials.BODY_GLB})
	if b.body == null:
		b.free()
		return null
	b._rng.randomize()
	b._next = b._rng.randf_range(2.0, 5.0)
	b.dress(lk, async)
	b._load_anims()
	b.set_frame(false)
	return b


func _load_anims() -> void:
	if ap == null or not ResourceLoader.exists(ANIMS):
		return
	var lib := load(ANIMS) as AnimationLibrary
	if lib != null and not ap.has_animation_library(LIB):
		ap.add_animation_library(LIB, lib)


func has_anim(n: String) -> bool:
	return ap != null and ap.has_animation("%s/%s" % [LIB, n])


func anim_length(n: String) -> float:
	return ap.get_animation("%s/%s" % [LIB, n]).length if has_anim(n) else 0.0


func play(n: String, blend := 0.25) -> bool:
	if not has_anim(n):
		return false
	ap.play("%s/%s" % [LIB, n], blend)
	return true


## The look the baby's body is dressed with: the infant face, the flat child body, a little shift, no hat.
static func baby_look(lk: Dictionary, stage_id := "newborn") -> Dictionary:
	var sex := float(lk.get("sex", 0.0))
	var out := ChildLook.dress_look(ChildLook.body_for_stage(ChildLook.infant(lk), stage_id), sex, stage_id)
	out["hat_fit"] = 0.0
	return out


func dress(lk: Dictionary, async := false) -> void:
	look = lk.duplicate(true)
	PlayerAppearance.dress(body, AppearanceStore.validate(baby_look(lk, stage)))
	var form := ChildLook.stage_form(stage)
	var rk := ChildLook.roundness(lk, stage) if round_head else 0.0
	if async:
		ready_body = false
		visible = false
		props = ChildProportion.shape_async(body, form, rk, _on_shaped)      # (from memory: on before this returns)
	else:
		props = ChildProportion.shape(body, form, rk)
		ChildSkin.apply(body, ChildLook.skin_smooth(stage) if soften else 0.0)
		_after_shape()


func _on_shaped(p: ChildProportion) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	props = p
	ChildSkin.apply(body, ChildLook.skin_smooth(stage) if soften else 0.0)
	_after_shape()
	set_frame(ground)
	ready_body = true
	visible = true
	shaped.emit()


func _after_shape() -> void:
	_add_mouth()
	_mouth = -1.0
	_breath = -1.0
	_last_lid = -1.0


## Lying on its back in the baby frame (BabyHold's: head +x, front +y, left +z, the neck's base at neck_at), or upright (`ground`:
## the front toward -x, the origin on the floor).
func set_frame(is_ground: bool) -> void:
	ground = is_ground
	var s0 := float(cfg().get("scale", 0.3))
	if ground:
		frame.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(Vector3.ONE * s0), Vector3.ZERO)
		return
	var map := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))     # adult x -> baby z, y -> x, z -> y
	var m := map * Basis.from_scale(Vector3.ONE * s0)
	var na: Array = cfg().get("neck_at", [0.1, 0.0, 0.0])
	var neck_p := props.bind_global("neck").origin if props != null else Vector3(0, 1.3, 0)
	frame.transform = Transform3D(m, Vector3(float(na[0]), float(na[1]), float(na[2])) - m * neck_p + Vector3(0, float(cfg().get("lying_y", 0.0)), 0))


## The dark of the mouth inside the lips (shown when it opens), on the head bone where this baby's lips are.
func _add_mouth() -> void:
	if mouth_attachment != null and is_instance_valid(mouth_attachment):
		mouth_attachment.queue_free()
	var c: Dictionary = cfg().get("mouth", {})
	var hb := sk.find_bone("headb")
	if hb < 0:
		return
	mouth_attachment = BoneAttachment3D.new()
	mouth_attachment.name = "MouthAttachment"
	mouth_attachment.bone_name = "headb"
	sk.add_child(mouth_attachment)
	mouth_node = MeshInstance3D.new()
	mouth_node.name = "Mouth"
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 16
	sph.rings = 8
	mouth_node.mesh = sph
	var mat := StandardMaterial3D.new()
	var col: Array = c.get("color", [0.3, 0.1, 0.1])
	mat.albedo_color = Color(float(col[0]), float(col[1]), float(col[2]))
	mat.roughness = 0.8
	mouth_node.material_override = mat
	var pos: Array = c.get("pos", [0.0, 1.411, 0.112])
	var p := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	if props != null and props.lip_y > 0.0:
		p.y = props.lip_y - 0.003
	var hg := props.bind_global("headb") if props != null else sk.get_bone_global_rest(hb)
	var at := props.map_face("headb", p) if props != null else p
	var sz: Array = c.get("size", [0.02, 0.012, 0.012])
	_mouth_size = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
	var a: Basis = props._a[hb] if props != null and hb < props._a.size() else Basis()
	var holder := Node3D.new()
	holder.name = "MouthAt"
	holder.transform = Transform3D(hg.basis.inverse() * a, hg.affine_inverse() * at)
	mouth_attachment.add_child(holder)
	mouth_node.visible = false
	holder.add_child(mouth_node)


## The lids' floor, 0 open .. 1 shut. Up to a soft half-lid they still blink (every 2 to 6 s through the face engine's `blink` shape),
## shut they are held.
func set_eyes(closed: float) -> void:
	_eyes = closed
	_last_lid = -1.0


func _process(dt: float) -> void:
	if body == null:
		return
	_t += dt
	var env := 0.0
	var s := _t - _next
	if s >= 0.0:
		if s < 0.07:
			env = s / 0.07
		elif s < 0.18:
			env = 1.0 - (s - 0.07) / 0.11
		else:
			_t = 0.0
			_next = _rng.randf_range(2.0, 6.0)
	var v := maxf(_eyes, env) if _eyes < 0.6 else _eyes
	if not is_equal_approx(v, _last_lid):
		_last_lid = v
		set_blink(v)


func set_blink(v: float) -> void:
	_shape(&"blink", v)


## The mouth: 0 shut .. 1 wide open (the jaw dropped, the dark inside), `width` its share of the full width of the dark.
func set_mouth(open: float, width := 1.0) -> void:
	open = clampf(open, 0.0, 1.0)
	if not is_equal_approx(open, _mouth):
		_mouth = open
		_shape(&"mouth_open", open)
	if mouth_node == null:
		return
	mouth_node.visible = open > 0.12
	if mouth_node.visible:
		mouth_node.scale = _mouth_size * Vector3(lerpf(0.6, 1.0, width), clampf(open * 1.2, 0.25, 1.0), 1.0)


## The breath: 0 out .. 1 in (the chest and belly swell).
func set_breath(v: float) -> void:
	if absf(v - _breath) > 0.01:
		_breath = v
		_shape(&"breath", v)


func _shape(n: StringName, v: float) -> void:
	if not ready_body:
		return
	for mi: MeshInstance3D in body.meshes:
		if is_instance_valid(mi) and mi.mesh and mi.visible:
			var i := mi.find_blend_shape_by_name(n)
			if i >= 0:
				mi.set_blend_shape_value(i, v)
