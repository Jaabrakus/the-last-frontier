class_name StoryObjectives
extends RefCounted
## The world checks behind a mission's steps (data/story/missions/*.json, `_kinds`). Each kind is a pair: begin() notes
## what the world holds when the step starts (so a step counts only what the player does after it), and check()
## returns {done, have, need, at} from the world as it is now. The world keeps the memory (the felled trees in
## VegHarvest, the pieces in BuildWorld, the dead in the carcasses group, the date in the survival core); a step only
## reads it. `at` is the point the marker shows (Vector3, or null for none).


## What the step's check measures from: called once when the step starts (and again after a load).
static func begin(step: Dictionary, tree: SceneTree) -> Dictionary:
	match String(step.get("kind", "")):
		"fell":
			var h := VegHarvest.find(tree)
			return {"felled": h.felled.size() if h else 0}
		"kill":
			var ids := []
			for n in tree.get_nodes_in_group(&"carcasses"):
				ids.append(_animal_key(n))
			return {"dead": ids}
	return {}


static func check(step: Dictionary, base: Dictionary, tree: SceneTree, places: Dictionary) -> Dictionary:
	var at: Variant = place_point(step, places)
	match String(step.get("kind", "")):
		"go_to":
			var p := _player(tree)
			if p == null or at == null:
				return {"done": false, "at": at}
			var d := _flat(p.global_position).distance_to(_flat(at))
			return {"done": d <= float(step.get("r", 10.0)), "at": at, "dist": d}
		"fell":
			var h := VegHarvest.find(tree)
			var have := (h.felled.size() if h else 0) - int(base.get("felled", 0))
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": at}
		"build":
			var have := _pieces_near(tree, step, at).size()
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": at}
		"fire_lit":
			var w := BuildWorld.of(tree, false)
			var r := float(step.get("r", 30.0))
			if w:
				for pc in w.pieces():
					if at != null and _flat(pc.global_position).distance_to(_flat(at)) > r:
						continue
					for c in pc.find_children("*", "Campfire", true, false):
						if (c as Campfire).is_lit():
							return {"done": true, "at": at}
			return {"done": false, "at": at}
		"kill":
			var want: Array = step.get("species", [])
			var seen: Array = base.get("dead", [])
			var have := 0
			var last: Variant = null
			for n in tree.get_nodes_in_group(&"carcasses"):
				var a := n as WildAnimal
				if a == null or (not want.is_empty() and not want.has(a.species)):
					continue
				if seen.has(_animal_key(a)):
					continue
				have += 1
				last = a.global_position
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": last}
		"wait_for":
			var b := SurvivalBridge.find(tree)
			if b == null or b.core == null:
				return {"done": false, "at": null}
			var c := b.core
			var w_ok := SurvivalClock.in_window(c, step.get("window", []))
			var hrs: Array = step.get("hours", [])
			var h_ok := true
			if hrs.size() == 2:
				var h := SurvivalClock.hour(c)
				var a := float(hrs[0])
				var z := float(hrs[1])
				h_ok = (h >= a and h < z) if a <= z else (h >= a or h < z)
			return {"done": w_ok and h_ok, "window_ok": w_ok, "at": null}
	return {"done": false, "at": at}


## The step's place as a point on the ground (null when it names none).
static func place_point(step: Dictionary, places: Dictionary) -> Variant:
	var name := String(step.get("place", ""))
	if name == "" or not places.has(name):
		return null
	var xz: Array = places[name]
	var x := float(xz[0])
	var z := float(xz[1])
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


static func _pieces_near(tree: SceneTree, step: Dictionary, at: Variant) -> Array:
	var out := []
	var w := BuildWorld.of(tree, false)
	if w == null:
		return out
	var types: Array = step.get("types", [])
	var r := float(step.get("r", 30.0))
	for pc in w.pieces():
		if not types.is_empty() and not types.has(pc.type):
			continue
		if at != null and _flat(pc.global_position).distance_to(_flat(at)) > r:
			continue
		out.append(pc)
	return out


## A dead animal's key (its instance: a dragged carcass stays the same one; a load begins the step again).
static func _animal_key(n: Node) -> int:
	return n.get_instance_id()


static func _player(tree: SceneTree) -> FrontierPlayer:
	return tree.get_first_node_in_group("player") as FrontierPlayer


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
