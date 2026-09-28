class_name PlacedWeapon
extends Node3D
## A weapon put down in the world (user 2026-09-25: drop or set items "on ground walls rocks and trees", in
## racks and bins, "for quick equip without reloading"): a copy of the weapon's model at its resting pose
## that keeps the weapon's state (WeaponState: the charge and spare cartridges, the quiver, the count).
##
## E (PlayerInteractor) on it: a player who does not carry this kind of weapon TAKES it (it becomes the
## player's again, with its state, and is drawn); a player who carries one SWAPS: the carried weapon's
## state stays here, this one's goes to the player (the loaded musket from the rack for the empty one).
## Interactable contract (group "interactables"): interact_prompt(), interact_point(), interact(),
## highlight_targets().

const GROUP := &"interactables"

## Roster key of the weapon kind ("musket", "bow", "pistol", "spear", "tomahawk", "atlatl").
var key := ""
var display_name := ""
var state := {}
var model: Node3D
## The rack this sits in (its slot is freed when taken), or null.
var rack: Node = null
var rack_slot := -1


func _ready() -> void:
	add_to_group(GROUP)


## Builds a placed weapon of `w`'s kind and state, with a copy of its model.
static func from_weapon(w: Weapon, roster_key: String) -> PlacedWeapon:
	var p := PlacedWeapon.new()
	p.name = "Placed_" + roster_key
	p.key = roster_key
	p.display_name = w.display_name
	p.state = WeaponState.capture(w)
	var m := build_model(w, roster_key)
	if m:
		p.model = m
		p.add_child(m)
	return p


## A fresh model of the weapon's kind (as the player builds them; a copy of the in-hand model trips over its
## run-time children).
static func build_model(w: Weapon, roster_key: String) -> Node3D:
	var m: Node3D = null
	if w is Throwable:
		m = ThrowableModels.build((w as Throwable).model_kind)
	else:
		m = WeaponModels.build(roster_key)
	if m:
		m.transform = Transform3D.IDENTITY
		m.visible = true
	return m


## Extent of the model along its own Z (min = the muzzle / point end, max = the butt), in the model's frame.
static func z_extent(model: Node3D) -> Vector2:
	var lo := INF
	var hi := -INF
	if model == null:
		return Vector2(-0.5, 0.5)
	for gi in model.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		var xf := model.global_transform.affine_inverse() * g.global_transform if model.is_inside_tree() else _rel(model, g)
		var bb := xf * g.get_aabb()
		lo = minf(lo, bb.position.z)
		hi = maxf(hi, bb.end.z)
	if lo == INF:
		return Vector2(-0.5, 0.5)
	return Vector2(lo, hi)


static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func interact_prompt(player: Node) -> String:
	var desc := WeaponState.describe(key, state)
	var what := display_name + (" (" + desc + ")" if desc != "" else "")
	if _carries(player):
		return ("Take " if key in ["spear", "tomahawk", "atlatl"] else "Swap for ") + what
	return "Take " + what


## A point on the weapon for targeting (its middle).
func interact_point() -> Vector3:
	var ext := z_extent(model)
	return global_transform * Vector3(0, 0, (ext.x + ext.y) * 0.5)


## Distance from `p` to the weapon along its length.
func distance_from(p: Vector3) -> float:
	var ext := z_extent(model)
	var a := global_transform * Vector3(0, 0, ext.x)
	var b := global_transform * Vector3(0, 0, ext.y)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func highlight_targets() -> Array:
	return model.find_children("*", "GeometryInstance3D", true, false) if model else []


func interact(player: Node) -> bool:
	var pl := player as FrontierPlayer
	if pl == null or not pl.weapons.has(key):
		return false
	var w: Weapon = pl.weapons[key]
	if w is Throwable:
		# thrown weapons add up (a spear from the barrel joins the ones carried) instead of swapping
		var t := w as Throwable
		var n := int(state.get("count", 1))
		var took := t.add_items(n) if _carries(pl) else n
		if not _carries(pl):
			t.count = n
			pl.set_carried(key, true)
			pl.switch_weapon(key)
		if took <= 0:
			return false
		if w.has_signal(&"sfx"):
			w.emit_signal(&"sfx", &"pickup", global_position)
		state.count = n - took
		if int(state.count) > 0:
			return true
		if rack and rack.has_method("free_slot"):
			rack.free_slot(rack_slot)
		remove_from_group(GROUP)
		queue_free()
		return true
	if _carries(pl):
		# swap: the carried weapon's state stays here, this one's goes to the player
		var mine := WeaponState.capture(w)
		WeaponState.apply(w, state)
		state = mine
		if pl.weapon_key != key:
			pl.switch_weapon(key)
		if w.has_signal(&"sfx"):
			w.emit_signal(&"sfx", &"pickup", global_position)
		return true
	WeaponState.apply(w, state)
	pl.set_carried(key, true)
	pl.switch_weapon(key)
	if rack and rack.has_method("free_slot"):
		rack.free_slot(rack_slot)
	remove_from_group(GROUP)
	queue_free()
	return true


func _carries(player: Node) -> bool:
	return player != null and player.has_method("is_carried") and player.is_carried(key)
