class_name NpcBall
extends Projectile
## A fighter's musket ball (NpcFighter): the game's own ball (Projectile: stepped by rays, the drop, the drag, the damage
## falling off with lost speed, Hit.deliver into whatever it meets, the near-miss whizz past the listener, the impact's sound
## and dust), but it does not tell the player's HUD of its hits: the hit marker is for the player's own shots, and one fighter
## striking another is no hit of the player's.


func _init() -> void:
	kind = Kind.BALL


func _on_impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var speed := velocity.length()
	Sfx.impact(kind, collider, point, normal, speed)
	var dmg := damage * clampf(speed / _start_speed, 0.35, 1.0)
	if not is_instance_valid(shooter):
		shooter = null                  # (the shooter gone while the ball flew: the hit is no one's)
	if speed >= min_damage_speed and not ghost:
		Hit.deliver(collider, dmg, point, velocity.normalized(), shooter)
	hit.emit(collider, point)
	# (no dust from flesh: the body bleeds)
	if DisplayServer.get_name() != "headless" \
			and not (collider is Node and (collider as Node).get_meta(&"surface", "") == "flesh"):
		Fx.dust_puff(get_tree().current_scene, point, normal)
	queue_free()
