class_name PackDrop
extends Node3D
## The pack a player dropped where they died (DeathRule; user 2026-09-27: "drop the pack"): a leather bundle on the
## ground holding what was in the pack (InventoryState pack entries) and the torches carried. E: "Take back your pack
## (N things)": everything goes back into the pack. Food left lying is found by scavengers: after SAFE_H game hours,
## a handful or a pound of it goes each SCAVENGE_H (the survival clock; real time scaled the same way without it).
## Marked on screen by DeathRule. The model is the project's own.

const GROUP := &"pack_drops"
const SAFE_H := 2.0
const SCAVENGE_H := 1.0
## Game minutes per real second when there is no survival clock (2.4 real minutes a game hour).
const FALLBACK_MIN_PER_S := 1.0 / 2.4

var items: Array = []
var torches: Array = []
## The game minute it was dropped (the survival clock) and the minutes scavenged up to.
var dropped_min := 0.0
var scavenged_to := 0.0
var interact_reach := 2.4
var _fallback_min := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	if DisplayServer.get_name() != "headless":
		_build_model()


func count() -> int:
	var n := torches.size()
	for e in items:
		n += int((e as Dictionary).get("count", 1))
	return n


func _now_min() -> float:
	var b := SurvivalBridge.find(get_tree())
	return b.core.state.minutes if b and b.core else _fallback_min


func _process(delta: float) -> void:
	_fallback_min += delta * FALLBACK_MIN_PER_S
	var now := _now_min()
	var from := maxf(scavenged_to, dropped_min + SAFE_H * 60.0)
	while now - from >= SCAVENGE_H * 60.0:
		from += SCAVENGE_H * 60.0
		_scavenge_one()
	scavenged_to = maxf(scavenged_to, from)


## A unit of the food lying here goes (the richest food first: what a wolf or a raven takes).
func _scavenge_one() -> void:
	var foods := SurvivalBridge.load_items()
	var best := -1
	for i in items.size():
		var k := String((items[i] as Dictionary).get("kind", ""))
		if foods.has(k) and int((items[i] as Dictionary).get("count", 0)) > 0:
			best = i
			if k in ["venison", "jerky"]:
				break
	if best < 0:
		return
	var e: Dictionary = items[best]
	e["count"] = int(e.count) - 1
	if int(e.count) <= 0:
		items.remove_at(best)


func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.2


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	return "Take back your pack (%d thing%s)" % [count(), "" if count() == 1 else "s"] if count() > 0 else "Your pack, emptied by scavengers"


func highlight_targets() -> Array:
	return find_children("*", "MeshInstance3D", true, false)


func interact(p: Node) -> bool:
	var inv := InventoryState.from_player(p)
	for e in items:
		var d: Dictionary = e
		inv.add(String(d.get("kind", "")), int(d.get("count", 1)))
	p.set("inventory_pack", inv.pack.duplicate(true))
	var pt: Variant = p.get("torch")
	if pt is PlayerTorch:
		for b in torches:
			(pt as PlayerTorch).pack.append(float(b))
	var n := count()
	items.clear()
	torches.clear()
	var it: Node = p.get("interactor")
	if it and it.has_method(&"notice"):
		it.call(&"notice", "You take back your pack (%d thing%s)" % [n, "" if n == 1 else "s"] if n > 0 else "The pack is empty: scavengers had the food")
	remove_from_group(PlacedWeapon.GROUP)
	remove_from_group(GROUP)
	queue_free()
	return true


func to_dict() -> Dictionary:
	return {"xf": SaveParts.xf(global_transform), "items": SaveParts.plain(items), "torches": torches.duplicate(),
			"dropped_min": dropped_min, "scavenged_to": scavenged_to}


static func from_dict(d: Dictionary) -> PackDrop:
	var pd := PackDrop.new()
	pd.name = "PackDrop"
	pd.items = (d.get("items", []) as Array).duplicate(true)
	pd.torches = (d.get("torches", []) as Array).duplicate()
	pd.dropped_min = float(d.get("dropped_min", 0.0))
	pd.scavenged_to = float(d.get("scavenged_to", 0.0))
	pd.transform = SaveParts.to_xf(d.get("xf"))
	return pd


## A leather bundle: the bag, its flap and a strap.
func _build_model() -> void:
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.36, 0.24, 0.14)
	leather.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.14, 0.08)
	dark.roughness = 0.85
	var bag := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.3
	bag.mesh = sm
	bag.scale = Vector3(1.2, 0.85, 0.9)
	bag.position = Vector3(0, 0.13, 0)
	bag.material_override = leather
	add_child(bag)
	var flap := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.03, 0.22)
	flap.mesh = bm
	flap.position = Vector3(0, 0.25, 0.04)
	flap.rotation = Vector3(deg_to_rad(-12.0), 0, 0)
	flap.material_override = dark
	add_child(flap)
	var strap := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.22
	strap.mesh = tm
	strap.position = Vector3(0, 0.05, -0.12)
	strap.rotation = Vector3(deg_to_rad(80.0), 0, 0)
	strap.material_override = dark
	add_child(strap)
