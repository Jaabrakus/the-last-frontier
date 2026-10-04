class_name Projectile
extends Node3D
## Raycast-stepped ballistic projectile, used for arrows and lead balls.
## It moves by velocity each physics tick and raycasts along the step, so fast
## shots never tunnel through thin geometry. Arrows stick where they land;
## balls kick up a puff of dust and disappear.

enum Kind { ARROW, BALL }

signal hit(collider: Object, point: Vector3)

var kind := Kind.ARROW
var velocity := Vector3.ZERO
var gravity := 4.0
var drag := 0.0            ## Fraction of speed lost per second (round balls slow down fast).
var damage := 50.0
var min_damage_speed := 15.0
var exclude: Array[RID] = []
var shooter: Node
var max_life := 20.0
## Another player's shot as this machine sees it (NetSession): it flies, sounds and sticks, but hurts nothing here
## (the shooter's machine decides its hits) and shows no hit marker.
var ghost := false

var _stuck := false
var _life := 0.0
var _start_speed := 1.0
var _whoosh: AudioStreamPlayer3D   ## Arrow flight sound (scripts/audio/sfx.gd).
var _whizzed := false

static var _mats := {}


func _ready() -> void:
	_start_speed = maxf(velocity.length(), 0.01)
	if kind == Kind.ARROW:
		_build_arrow()
		_start_whoosh.call_deferred()   # After the launcher has placed us at the muzzle.
	else:
		_build_ball()


func _start_whoosh() -> void:
	if not _stuck and is_inside_tree():
		_whoosh = Sfx.attach(&"arrow_whoosh", self, linear_to_db(clampf(velocity.length() / 62.0, 0.2, 1.2)))


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > max_life:
		queue_free()
		return
	if _stuck:
		return

	velocity.y -= gravity * delta
	velocity *= maxf(1.0 - drag * delta, 0.0)
	var from := global_position
	var to := from + velocity * delta
	if kind == Kind.BALL and not _whizzed and _life > 0.08:
		_whizzed = Sfx.flyby(from, to)   # Near miss past the listener (not your own shot).
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if result:
		_on_impact(result.collider, result.position, result.normal)
		return

	global_position = to
	if velocity.length_squared() > 0.01:
		var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT
		look_at(global_position + velocity, up)


func _on_impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var speed := velocity.length()
	Sfx.impact(kind, collider, point, normal, speed)
	if is_instance_valid(_whoosh):     # It frees itself when it has played out.
		Sfx.stop(_whoosh, 0.03)
	_whoosh = null
	# Damage falls off with lost speed, so long lobbed shots hit softer.
	var dmg := damage * clampf(speed / _start_speed, 0.35, 1.0)
	if speed >= min_damage_speed and not ghost:
		# (what struck, for the body it lands in to work out its path: Anatomy, the user 2026-10-03)
		Hit.deliver(collider, dmg, point, velocity.normalized(), shooter, true, {"kind": "ball" if kind == Kind.BALL else "arrow", "speed": speed})
	hit.emit(collider, point)
	if shooter and not ghost:
		shooter.get_tree().call_group("hit_listeners", "on_projectile_hit", collider, point)

	if kind == Kind.ARROW:
		_stuck = true
		global_position = point + velocity.normalized() * 0.08
		# (in an animal: on its bone there, ThrownProjectile.stuck_parent)
		var carrier := ThrownProjectile.stuck_parent(collider, global_position)
		if carrier != null and carrier.is_inside_tree():
			reparent(carrier)
		_life = 0.0
		if ghost or not (shooter is FrontierPlayer):
			max_life = 30.0
		else:
			_keep_for_pickup()
	else:
		# (no dust from an animal: the wildlife bleeds, WildAnimal)
		if not (collider is Node and (collider as Node).get_meta(&"surface", "") == "flesh"):
			Fx.dust_puff(get_tree().current_scene, point, normal)
		queue_free()


## A player's arrow stuck where it landed stays to be picked up again (the user, 2026-10-03: "have the ability to pick up
## arrows"): a ThrownPickup of the "arrow" kind on its shaft (E, PlayerInteractor; it goes back into the shooter's Bow's
## quiver, every arrow within ThrownPickup.ARROW_BUNDLE_M with it). It stays STUCK_LIFE_S; past MAX_STUCK arrows in the
## world the oldest goes first. Another player's shot as this machine sees it (ghost) stays 30 s with none: its own
## machine has the pickup.
const STUCK_LIFE_S := 900.0
const MAX_STUCK := 60
static var _stuck_arrows: Array = []


func _keep_for_pickup() -> void:
	max_life = STUCK_LIFE_S
	var pk := ThrownPickup.new()
	pk.kind = ThrownPickup.ARROW
	pk.item = self
	pk.require_interact = true
	pk.interact_radius = 2.5
	add_child(pk)
	pk.position = Vector3(0.0, 0.0, 0.36)      # (mid-shaft: the tip is the origin, the shaft runs back along +Z)
	_stuck_arrows = _stuck_arrows.filter(func(a: Variant) -> bool: return is_instance_valid(a) and not (a as Node).is_queued_for_deletion())
	_stuck_arrows.append(self)
	while _stuck_arrows.size() > MAX_STUCK:
		(_stuck_arrows.pop_front() as Node).queue_free()


static func _mat(key: String, color: Color, metallic := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = 0.6
		_mats[key] = m
	return _mats[key]


func _build_arrow() -> void:
	# The origin is the tip; the shaft extends back along +Z (forward is -Z).
	add_child(WeaponModels.build_arrow())


func _build_ball() -> void:
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.009
	s.height = 0.018
	s.radial_segments = 8
	s.rings = 4
	ball.mesh = s
	ball.material_override = _mat("lead", Color(0.35, 0.35, 0.38), 0.8)
	add_child(ball)
