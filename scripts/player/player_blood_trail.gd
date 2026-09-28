class_name PlayerBloodTrail
extends Node
## A bleeding player leaves a trail (user 2026-09-27: "bleeding on humans should also leave trails as well for other
## people to find"): while a wound bleeds (PlayerWounds.pool) a drop of blood falls every DROP_M walked, or every DROP_S
## standing, more often and larger the harder it bleeds. The drops are the wildlife's (WildlifeSpawner.player_blood_drop:
## decals on the ground, the oldest going past its limit), and they are the player's own: a wolf that comes on a fresh
## one has his scent (WildAnimal._sense_player). No trail without the wildlife.

const DROP_M := 1.1
const DROP_S := 2.5
## The pool (health still to lose) at which it bleeds hardest.
const HEAVY_POOL := 30.0

var player: FrontierPlayer
## Drops left so far (tests).
var drops := 0
var _last := Vector3.INF
var _walked := 0.0
var _t := 0.0


static func install(p: FrontierPlayer) -> PlayerBloodTrail:
	var t := p.get_node_or_null(^"BloodTrail") as PlayerBloodTrail
	if t == null:
		t = PlayerBloodTrail.new()
		t.name = "BloodTrail"
		t.player = p
		p.add_child(t)
	return t


func _physics_process(dt: float) -> void:
	if player == null or player.is_dead or player.wounds == null or player.wounds.pool <= 0.0:
		_last = Vector3.INF
		_t = 0.0
		return
	var at := player.global_position
	if _last != Vector3.INF:
		_walked += Vector2(at.x - _last.x, at.z - _last.z).length()
	_last = at
	_t += dt
	var heavy := clampf(player.wounds.pool / HEAVY_POOL, 0.0, 1.0)
	if _walked < DROP_M * (1.0 - 0.4 * heavy) and _t < DROP_S * (1.0 - 0.5 * heavy):
		return
	_walked = 0.0
	_t = 0.0
	var sp := player.get_tree().current_scene.get_node_or_null(^"Wildlife") as WildlifeSpawner if player.get_tree().current_scene else null
	if sp == null:
		return
	sp.player_blood_drop(at + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25)), 0.8 + 0.6 * heavy)
	drops += 1
