class_name ToolRacks
extends RefCounted
## The fort's weapon racks and spear barrels (WeaponRack, with the PlacedWeapons standing in them) as the household's store of
## the tool pool's rack kinds (data/companion/tools.json store "rack"): ChestStock hands its rack kinds here. One unit of a kind
## is one PlacedWeapon of the kind's rack_key, with its state (a musket's charge, a spear's count). A weapon taken leaves its slot;
## one put back is built again (the player's own weapon model when the level has the player, else the model of its kind) and
## stands in the nearest free slot, in a rack of the kind's preferred style first.


static func racks(tree: SceneTree, home: Vector3) -> Array:
	var out := []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group(WeaponRack.GROUP):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(home) < b.global_position.distance_squared_to(home))
	return out


static func _key(kind: String) -> String:
	return String(ToolPool.kind_row(kind).get("rack_key", kind))


## The weapons of `kind` standing in `rack`.
static func in_rack(rack: WeaponRack, kind: String) -> Array:
	var out := []
	var key := _key(kind)
	for w in rack.held():
		var pw := w as PlacedWeapon
		if pw != null and pw.key == key and not pw.is_queued_for_deletion():
			out.append(pw)
	return out


static func count(tree: SceneTree, kind: String) -> int:
	var n := 0
	for r: WeaponRack in racks(tree, Vector3.ZERO):
		n += in_rack(r, kind).size()
	return n


## Up to `n` weapons of `kind` out of the racks (the nearest to `home` first): [{"state": the weapon's state}].
static func take(tree: SceneTree, home: Vector3, kind: String, n: int) -> Array:
	var out := []
	for r: WeaponRack in racks(tree, home):
		for pw: PlacedWeapon in in_rack(r, kind):
			if out.size() >= n:
				return out
			out.append({"state": (pw.state as Dictionary).duplicate(true)})
			r.free_slot(pw.rack_slot)
			pw.rack = null
			pw.remove_from_group(PlacedWeapon.GROUP)
			if pw.get_parent() != null:
				pw.get_parent().remove_child(pw)
			pw.queue_free()
	return out


## `n` plain units (no state of their own: the kind's default state is used).
static func plain_units(n: int) -> Array:
	var out := []
	for i in n:
		out.append({})
	return out


## Puts the units ({"state"} or {}) back in free slots; how many stand again.
static func put(tree: SceneTree, home: Vector3, kind: String, units: Array) -> int:
	var row := ToolPool.kind_row(kind)
	var style := String(row.get("rack_style", ""))
	var put_n := 0
	for u: Variant in units:
		var st: Dictionary = (u as Dictionary).get("state", {}) if u is Dictionary else {}
		if st.is_empty():
			st = (row.get("state", {}) as Dictionary).duplicate(true)
		var best: WeaponRack = null
		var slot := -1
		var bs := INF
		for r: WeaponRack in racks(tree, home):
			var s := r.free_slot_near(r.global_position)
			if s < 0:
				continue
			var score := r.global_position.distance_squared_to(home) + (0.0 if style == "" or r.style == style else 1.0e6)
			if score < bs:
				bs = score
				best = r
				slot = s
		if best == null:
			break
		var pw := make(tree, _key(kind), st)
		if pw == null:
			break
		var scene := tree.current_scene if tree.current_scene != null else tree.root
		scene.add_child(pw)
		best.place(pw, slot)
		put_n += 1
	return put_n


## The rack or barrel to walk to: the nearest one holding `kind` (fetching) or with a free slot (putting back).
static func spot(tree: SceneTree, home: Vector3, kind: String, fetch: bool) -> Node3D:
	var style := String(ToolPool.kind_row(kind).get("rack_style", ""))
	var best: Node3D = null
	var bs := INF
	for r: WeaponRack in racks(tree, home):
		if fetch:
			if in_rack(r, kind).is_empty():
				continue
		elif r.free_slot_near(r.global_position) < 0:
			continue
		var s := r.global_position.distance_squared_to(home) + (0.0 if fetch or style == "" or r.style == style else 1.0e6)
		if s < bs:
			bs = s
			best = r
	return best


## A weapon of `key` in the state `st`, as the racks hold it (not yet in the tree).
static func make(tree: SceneTree, key: String, st: Dictionary) -> PlacedWeapon:
	var pw: PlacedWeapon = null
	var h := Household.find(tree)
	var w: Weapon = null
	if h != null and is_instance_valid(h.player):
		w = h.player.get("weapons").get(key) as Weapon if h.player.get("weapons") is Dictionary else null
	if w != null:
		pw = PlacedWeapon.from_weapon(w, key)
	else:
		pw = PlacedWeapon.new()
		pw.name = "Placed_" + key
		pw.key = key
		var m: Node3D = ThrowableModels.build(key) if key in ["spear", "tomahawk", "atlatl"] else WeaponModels.build(key)
		if m != null:
			m.transform = Transform3D.IDENTITY
			m.visible = true
			pw.model = m
			pw.add_child(m)
		for k: String in ToolPool.kinds():
			if String(ToolPool.kind_row(k).get("rack_key", "")) == key:
				pw.display_name = ToolPool.name_of(k)
	pw.state = st.duplicate(true)
	return pw
