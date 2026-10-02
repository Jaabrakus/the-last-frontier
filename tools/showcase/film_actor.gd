class_name FilmActor
extends Node3D
## A person for the films (user 2026-10-01: the trailer's ambush: "people in trees as a hunting party walks by and shoots them"):
## Actor_B dressed as the sparring stand-ins are (SparringPartner), played by the film's script, not by AI. It walks, runs, crouches,
## carries a musket and aims it as a household hunter does (HuntAim), fires through the game's own ball (Projectile, Fx.muzzle_blast,
## the shot's sound), and is a body to hit: struck it flinches and goes down (the player's death clips). Faces its +Z.
signal died(actor: FilmActor)

const LIB := "actor_b"
const OWN_LOOK := "scots_irish_m_a"
const PROP := "r_hand_prop_attachment"
const BODY := "res://assets/character/actor_b_body.glb"
const BALL_SPEED := 180.0
const WALK := "actor_b-p-walk-fw"
const RUN := "actor_b-p-run-fw"
const IDLE := "actor_b-p-relax-idle"
const CROUCH := "actor_b-p-crouch-idle"
const AIM := "actor_b-p-rifle-idle-aim"

var look := OWN_LOOK
var sk: Skeleton3D
var ap: AnimationPlayer
var aim: HuntAim
var gun: Node3D
var alive := true
var hits := 0
var loaded := true
var _att: BoneAttachment3D
var _torso: StaticBody3D
var _head: StaticBody3D
var _clip := ""


func _ready() -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	add_child(n)
	sk = n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if not aps.is_empty() else null
	var body := CharacterBodyMesh.attach(sk, ap, BODY)
	if body:
		PlayerAppearance.dress(body, AppearanceStore.validate(CharacterPeoples.preset_look(look)))
	aim = HuntAim.attach(sk)
	_att = BoneAttachment3D.new()
	_att.bone_name = PROP
	sk.add_child(_att)
	_torso = _part("body", 1.0, _capsule(0.2, 0.7))
	_head = _part("head", 2.0, _sphere(0.13))
	play(IDLE)


func _part(part: String, mult: float, shape: Shape3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Hit_" + part
	b.top_level = true
	b.set_meta("hit_part", part)
	b.set_meta("damage_mult", mult)
	b.set_meta("surface", "flesh")
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	add_child(b)
	return b


static func _capsule(r: float, h: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	return c


static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


## The torso along the spine and the head on the head bone: what a ball meets.
func _physics_process(_dt: float) -> void:
	if sk == null or _torso == null:
		return
	var g := sk.global_transform
	var a := g * sk.get_bone_global_pose(sk.find_bone("pelvis")).origin
	var b := g * sk.get_bone_global_pose(sk.find_bone("neck")).origin
	var up := (b - a).normalized()
	var x := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.95 else up.cross(Vector3.RIGHT)
	x = x.normalized()
	_torso.global_transform = Transform3D(Basis(x, up, x.cross(up).normalized()), (a + b) * 0.5)
	var hd := g * sk.get_bone_global_pose(sk.find_bone("heada")).origin
	_head.global_transform = Transform3D(Basis.IDENTITY, hd + up * 0.08)


## A clip of the library, looped, from `blend` s.
func play(clip: String, blend := 0.2, speed := 1.0) -> void:
	if ap == null:
		return
	var full := "%s/%s" % [LIB, clip]
	if not ap.has_animation(full):
		return
	ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = speed
	ap.play(full, blend)
	_clip = clip


## A one-shot clip (a flinch, a death): played once and held on its last frame.
func play_once(clip: String, blend := 0.1) -> float:
	if ap == null:
		return 0.0
	var full := "%s/%s" % [LIB, clip]
	if not ap.has_animation(full):
		return 0.0
	ap.get_animation(full).loop_mode = Animation.LOOP_NONE
	ap.speed_scale = 1.0
	ap.play(full, blend)
	_clip = clip
	return ap.get_animation(full).length


## A musket in the hand (carried; aim_at puts it to the shoulder).
func give_gun(kind := "musket") -> void:
	gun = WeaponModels.build(kind)
	_att.add_child(gun)


## The musket to the shoulder and laid on `p` (HuntAim), in the aim clip.
func aim_at(p: Vector3) -> void:
	if gun == null:
		return
	if _clip != AIM:
		play(AIM, 0.25)
	gun.top_level = true
	aim.gun = gun
	aim.target = p
	aim.want = true


## The musket down again, carried.
func lower(clip := IDLE) -> void:
	aim.want = false
	if gun != null:
		gun.top_level = false
		gun.transform = Transform3D.IDENTITY
	play(clip, 0.3)


## A shot at `at`: the ball from the muzzle, the flash, the smoke and the report; the musket is empty after (a clean shot only
## from a loaded one).
func fire(at: Vector3, damage := 70.0) -> void:
	if gun == null or not loaded:
		return
	loaded = false
	var m := gun.get_node_or_null("Muzzle") as Node3D
	var origin := m.global_position if m else gun.global_position - gun.global_basis.z * 0.8
	var dir := (at - origin).normalized()
	var scene := get_tree().current_scene
	var p := Projectile.new()
	p.kind = Projectile.Kind.BALL
	p.velocity = dir * BALL_SPEED
	p.gravity = 4.0
	p.drag = 0.0
	p.damage = damage
	p.shooter = self
	scene.add_child(p)
	p.global_position = origin
	p.look_at(origin + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	var xf := Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT), origin)
	Fx.muzzle_blast(scene, xf, 1.0)
	Sfx.play_3d(&"musket_shot", origin)


func reload() -> void:
	loaded = true


## Faces the point (level).
func face(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


## Struck (Hit.deliver): it flinches, the blood, and goes down, a hit through the body or the head for good.
func apply_hit(damage: float, point: Vector3, dir: Vector3, _source: Node, part: String) -> void:
	if not alive:
		return
	hits += 1
	var scene := get_tree().current_scene
	if scene != null:
		BloodFx.hit(scene, point, dir, -dir, 1.0, self)
	if damage >= 40.0 or part == "head":
		_go_down(dir)


func _go_down(dir: Vector3) -> void:
	alive = false
	aim.want = false
	var from := -dir
	var behind := from.dot(global_basis.z) < 0.0
	var clip := "actor_b-p-death-back" if not behind else "actor_b-p-death-front"
	# (struck from the front it falls backward, from behind it falls on its face)
	var front := dir.dot(global_basis.z) < 0.0
	clip = "actor_b-p-death-back" if front else "actor_b-p-death-front"
	play_once(clip, 0.08)
	died.emit(self)
