class_name Hit
## Damage routing. A projectile hits a collider; the collider (or the first
## ancestor) with `apply_hit(damage, point, direction, source, part)` takes it.
## Colliders can carry metadata "hit_part" (e.g. "head") and
## "damage_mult" so one target can have weak spots. `head_bonus` false (a melee
## blow; user 2026-09-27: head damage "only on" shots, not melee hits): a head
## takes no more than the body would.


static func deliver(collider: Object, damage: float, point: Vector3, direction: Vector3, source: Node,
		head_bonus := true) -> bool:
	var part := "body"
	var mult := 1.0
	var node := collider as Node
	if node:
		part = node.get_meta("hit_part", part)
		mult = node.get_meta("damage_mult", mult)
		if not head_bonus and part == "head":
			mult = minf(mult, 1.0)
	while node:
		if node.has_method("apply_hit"):
			node.apply_hit(damage * mult, point, direction, source, part)
			return true
		node = node.get_parent()
	return false
