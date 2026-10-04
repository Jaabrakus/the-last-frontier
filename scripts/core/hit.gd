class_name Hit
## Damage routing. A projectile hits a collider; the collider (or the first
## ancestor) with `apply_hit(damage, point, direction, source, part)` takes it.
## Colliders can carry metadata "hit_part" (e.g. "head") and
## "damage_mult" so one target can have weak spots. `head_bonus` false (a melee
## blow; user 2026-09-27: head damage "only on" shots, not melee hits): a head
## takes no more than the body would.
## The coarse colliders only catch the round: the body it lands in works out its path through its fitted body (Anatomy,
## BodyModel; the user, 2026-10-03: hit detection off "a perfect skeleton mesh"), from what struck it: `shot` {kind ("ball",
## "arrow", "dart", "spear", "tomahawk", "blade", "blunt"), speed (m/s), mass (kg, optional)}, read as Hit.shot while
## apply_hit runs. A blow (head_bonus false) without one is a blade's; anything else without one, a ball of its damage.

## What is being delivered now ({} outside a delivery, or when the caller did not say).
static var shot: Dictionary = {}


static func deliver(collider: Object, damage: float, point: Vector3, direction: Vector3, source: Node,
		head_bonus := true, p_shot := {}) -> bool:
	var part := "body"
	var mult := 1.0
	var node := collider as Node
	if node:
		part = node.get_meta("hit_part", part)
		mult = node.get_meta("damage_mult", mult)
		if not head_bonus and part == "head":
			mult = minf(mult, 1.0)
	var was := shot
	shot = p_shot if not p_shot.is_empty() else ({"kind": "blade"} if not head_bonus else {})
	var took := false
	while node:
		if node.has_method("apply_hit"):
			node.apply_hit(damage * mult, point, direction, source, part)
			took = true
			break
		node = node.get_parent()
	shot = was
	return took
