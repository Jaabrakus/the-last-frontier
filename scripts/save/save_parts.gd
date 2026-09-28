class_name SaveParts
extends RefCounted
## What each system of the level puts in a save and how it comes back (SaveGame writes and reads them). The level is
## always built fresh (the forest, the fort and the rest from their seeds); a save holds only what changed since, and
## loading applies it on top. Each part is a pair of static functions, save_<part>(level) -> Dictionary and
## load_<part>(level, d); a system added later adds its own pair and a line in SaveGame.PARTS.
##
##   survival    the survival core through its bridge (needs, conditions, the date and hour, the kit, skills of the
##               core): SurvivalBridge.save_state / load_state. Time lives in the core (it drives the sky).
##   sky         the sky's weather (WeatherSystem: the spell, its hours, the wind, the next spell, its random stream);
##               the sky clock too when there is no survival core to drive it
##   player      where and how the player stands, health, the worn gear (Loadout), the pack, which weapons are carried,
##               each weapon's state (charge, spare cartridges, count), the torches, the gathering skills
##   vegetation  trees felled (hidden, their stumps back), saplings cut, rocks quarried (and their work so far), the felled
##               trees lying down (with the logs left in them), loose boles (and the barricade logs laid, LogPull) and log
##               piles. Tied to the forest's layout by a signature: a save of another layout skips this part (and
##               forage), saying so
##   building    every built piece in the order it was built (type, place, what it rests on, its id), doors open or
##               shut, the campfires and hearth fires (lit, the wood in them, the coals), what is in each chest, the
##               wood on each woodpile, a smokehouse's larder, its smudge and how smoked its venison is. With the survival core, a campfire's fuel and a
##               drying rack's venison are the core's records, tagged by the piece's id (CampLink), saved in its part:
##               the pieces keep their ids, so they find them again
##   fort        the pieces chopped out of the palisade and the gate, in order; those since repaired; the covers and
##               doors hung in openings; the gate open or shut
##   items       weapons put down (on the ground or in a rack, a built one by its piece's id, with their state), thrown
##               weapons lying or stuck, dropped torches (still burning, or not)
##   wildlife    every herd and pack (kind, home, what it is doing) and each animal (where, how hurt, hungry and tired);
##               carcasses with the meat left and how far they are dressed; every square's numbers (WildlifeLand)
##   horse       where the horse stands (a load on its chain is left lying where it is)
##   wheelbarrow where it stands, the pack things in it, and what rode in it (a carcass or a log, saved where they lay:
##               taken back into the bed)
##   cart        the horse cart (HorseCart): where it stands, the goods in it, whether the horse is in its shafts, and
##               what rides in the bed (the deer and logs saved where they lay, the wheelbarrow by its own part: each
##               taken back in)
##   forage      each wild plant patch's stock, dug plants (and when: they come back), browse and the deer's last visit
##   death       the respawn place (where the player last slept) and the pack drops (DeathRule)

const FORMAT := "frontier-save"
const VERSION := 1


# --- Helpers -----------------------------------------------------------------------------------------------

static func v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func to_v3(a: Variant, def := Vector3.ZERO) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() == 3 else def


static func xf(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func to_xf(a: Variant) -> Transform3D:
	if not (a is Array) or (a as Array).size() != 12:
		return Transform3D.IDENTITY
	var f: Array = a
	return Transform3D(Basis(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8])), Vector3(f[9], f[10], f[11]))


## JSON-safe copy of a value (Vector3 / Transform3D / packed arrays become arrays; dictionaries and arrays deep).
static func plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_VECTOR3:
			return v3(v)
		TYPE_TRANSFORM3D:
			return xf(v)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return Array(v)
		TYPE_ARRAY:
			var out := []
			for e in v:
				out.append(plain(e))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = plain(v[k])
			return d
		TYPE_OBJECT:
			return null
	return v


## A script object's plain variables (bool, int, float, String, Vector2, Vector3; not the private "_" ones unless
## `private`): the sky's weather and other small state objects.
static func vars_of(o: Object, private := false) -> Dictionary:
	var d := {}
	for p in o.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n := String(p.name)
		if n.begins_with("_") and not private:
			continue
		var t := int(p.type)
		if t in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3]:
			d[n] = plain(o.get(n))
	return d


static func set_vars(o: Object, d: Dictionary) -> void:
	for n: String in d:
		var cur: Variant = o.get(n)
		var v: Variant = d[n]
		match typeof(cur):
			TYPE_VECTOR2:
				o.set(n, Vector2(float(v[0]), float(v[1])))
			TYPE_VECTOR3:
				o.set(n, to_v3(v))
			TYPE_INT:
				o.set(n, int(v))
			TYPE_FLOAT:
				o.set(n, float(v))
			TYPE_BOOL:
				o.set(n, bool(v))
			TYPE_STRING:
				o.set(n, String(v))


static func _scene(level: Node) -> Node:
	return level


static func _player(level: Node) -> FrontierPlayer:
	return level.get_node_or_null("Player") as FrontierPlayer


# --- Survival ----------------------------------------------------------------------------------------------

static func save_survival(level: Node) -> Dictionary:
	var b := SurvivalBridge.find(level.get_tree())
	return {"doc": b.save_state()} if b else {}


static func load_survival(level: Node, d: Dictionary) -> void:
	var b := SurvivalBridge.find(level.get_tree())
	if b and d.has("doc"):
		b.load_state(d.doc)


# --- Sky ---------------------------------------------------------------------------------------------------

static func _day_night(level: Node) -> DayNight:
	var rig: Variant = level.get("environment_rig")
	return (rig as EnvironmentRig).clock_driver if rig is EnvironmentRig else null


static func save_sky(level: Node) -> Dictionary:
	var dn := _day_night(level)
	if dn == null:
		return {}
	var out := {"clock": {"year": dn.clock.year, "day": dn.clock.day_of_year, "hour": dn.clock.hour}}
	if dn.weather:
		out["weather"] = vars_of(dn.weather, true)
		out["weather_rng"] = [str(dn.weather.rng.seed), str(dn.weather.rng.state)]
	return out


static func load_sky(level: Node, d: Dictionary) -> void:
	var dn := _day_night(level)
	if dn == null:
		return
	if SurvivalBridge.find(level.get_tree()) == null and d.has("clock"):
		dn.clock.year = int(d.clock.year)
		dn.clock.set_date(float(d.clock.day))
		dn.clock.set_time(float(d.clock.hour))
	if dn.weather and d.has("weather"):
		set_vars(dn.weather, d.weather)
		if d.has("weather_rng"):
			dn.weather.rng.seed = int(String(d.weather_rng[0]))
			dn.weather.rng.state = int(String(d.weather_rng[1]))


# --- Player ------------------------------------------------------------------------------------------------

static func save_player(level: Node) -> Dictionary:
	var p := _player(level)
	if p == null:
		return {}
	var ws := {}
	for k in p.weapons:
		ws[k] = plain(WeaponState.capture(p.weapons[k]))
	var torch := {}
	if p.torch:
		var pack: Array = Array(p.torch.pack)
		if p.torch.held != null:
			pack.append(p.torch.held.burn_left)       # a torch in the hand goes back into the pack
		torch = {"pack": pack}
	var skills := {}
	if p.gather and p.gather.skills:
		skills = (p.gather.skills.points as Dictionary).duplicate()
	var at := p.global_position
	if p.riding != null:
		at = p.riding.global_position + p.riding.global_basis.x * 1.2
	return {"pos": v3(at), "yaw": p.yaw, "pitch": p.pitch, "health": p.health,
			"loadout": plain(p.loadout.to_dict()) if p.loadout else {}, "pack": plain(p.inventory_pack),
			"carried": plain(p.carried), "weapons": ws, "weapon_key": p.weapon_key, "hands_free": p.hands_free,
			"torch": torch, "skills": skills}


static func load_player(level: Node, d: Dictionary) -> void:
	var p := _player(level)
	if p == null or d.is_empty():
		return
	if p.riding != null and p.has_method("dismount"):
		p.dismount()
	p.global_position = to_v3(d.pos, p.global_position)
	p.velocity = Vector3.ZERO
	p.yaw = float(d.get("yaw", p.yaw))
	p.rotation.y = p.yaw
	p.pitch = float(d.get("pitch", p.pitch))
	p.health = float(d.get("health", p.max_health))
	for k in d.get("weapons", {}):
		if p.weapons.has(k):
			WeaponState.apply(p.weapons[k], d.weapons[k])
	var carried: Dictionary = d.get("carried", {})
	for k in carried:
		p.carried[k] = bool(carried[k])
	var lo: Dictionary = d.get("loadout", {})
	if not lo.is_empty():
		p.apply_loadout(Loadout.from_dict(lo), d.get("pack", []))
	else:
		p.inventory_pack = d.get("pack", [])
	if p.torch and d.get("torch", {}).has("pack"):
		var tp: Array[float] = []
		for b in d.torch.pack:
			tp.append(float(b))
		p.torch.pack = tp
	if p.gather and p.gather.skills and not (d.get("skills", {}) as Dictionary).is_empty():
		for k in d.skills:
			p.gather.skills.points[k] = float(d.skills[k])
	var key := String(d.get("weapon_key", ""))
	if bool(d.get("hands_free", false)):
		if not p.hands_free and p.has_method("toggle_hands_free"):
			p.toggle_hands_free()
	elif key != "" and p.is_usable(key) and key != p.weapon_key:
		p.switch_weapon(key)


# --- Vegetation --------------------------------------------------------------------------------------------

## A signature of the forest's layout: a save of another layout (another chat's change to the forest) must not fell
## trees by index.
static func layout_signature(level: Node) -> String:
	var veg: Variant = level.get("vegetation")
	var lay: Variant = veg.layout if veg else null
	if lay == null:
		return ""
	var s := "%d:%d:%d" % [lay.tree_pos.size(), lay.prop_pos.size(), lay.plant_pos.size()]
	for arr in [lay.tree_pos, lay.prop_pos]:
		var a: PackedVector3Array = arr
		for i in [0, a.size() / 3, a.size() / 2, a.size() - 1]:
			if i >= 0 and i < a.size():
				s += ":%.2f,%.2f" % [a[i].x, a[i].z]
	return s.sha256_text().substr(0, 16)


static func save_vegetation(level: Node) -> Dictionary:
	var h := VegHarvest.find(level.get_tree())
	var p := _player(level)
	var out := {"sig": layout_signature(level)}
	if h:
		out["felled"] = h.felled.keys()
		out["cut"] = h.cut.keys()
		out["rocks"] = plain(h.rock_size)
	if p and p.gather:
		out["rock_work"] = plain(p.gather.get("_rock"))
	var trees := []
	var loose := []
	var piles := []
	for n in level.get_tree().get_nodes_in_group(FelledTree.GROUP):
		var ft := n as FelledTree
		if ft == null or ft.is_queued_for_deletion() or ft.state == FelledTree.State.GONE:
			continue
		if ft is SkidLoad:
			var s := ft as SkidLoad
			if s is CarcassLoad or s.bundle > 0:
				continue
			loose.append({"info": plain(s.info), "front": v3(s.front), "back": v3(s.back), "r0": s.r_front, "r1": s.r_back,
					"logs_total": s.logs_total, "logs_left": s.logs_left, "work": s.work, "cut_work": s.cut_work,
					"hardness": s.hardness, "laid": s.laid})
			continue
		if ft.state != FelledTree.State.DOWN and ft.state != FelledTree.State.SETTLING and ft.state != FelledTree.State.FALLING:
			continue
		trees.append({"info": plain(ft.info), "dir": v3(ft.fall_dir), "theta": ft.theta if ft.state == FelledTree.State.DOWN else PI * 0.5,
				"logs_total": ft.logs_total, "logs_left": ft.logs_left, "work": ft.work, "down": ft.state == FelledTree.State.DOWN})
	for n in level.get_tree().current_scene.find_children("*", "LogPile", true, false):
		var lp := n as LogPile
		piles.append({"xf": xf(lp.global_transform), "count": lp.count, "len": lp.log_length, "r": lp.log_radius, "species": lp.species})
	out["trees"] = trees
	out["loose"] = loose
	out["piles"] = piles
	return out


static func load_vegetation(level: Node, d: Dictionary, notes: Array) -> void:
	if String(d.get("sig", "")) != layout_signature(level):
		notes.append("The forest has changed since this save: its felled trees, stumps and quarried rocks are not restored")
		return
	var h := VegHarvest.find(level.get_tree())
	var p := _player(level)
	var cfg := GatherData.get_default().felling
	var visuals := DisplayServer.get_name() != "headless"
	var scene := level.get_tree().current_scene
	if h:
		for i in d.get("felled", []):
			var desc := h.remove_tree(int(i))
			if not desc.is_empty():
				scene.add_child(FelledTree.make_stump(desc, float(cfg.get("stump_height_m", 0.45)), visuals))
		for key in d.get("cut", []):
			var parts := String(key).split(":")
			if parts.size() == 2:
				h.remove_sapling(parts[0], int(parts[1]))
		var rocks: Dictionary = d.get("rocks", {})
		for i in rocks:
			h.shrink_rock(int(i), float(rocks[i]))
	if p and p.gather and d.has("rock_work"):
		var rw := {}
		for k in d.rock_work:
			rw[int(k)] = d.rock_work[k]
		p.gather.set("_rock", rw)
	for t in d.get("trees", []):
		var info: Dictionary = t.info
		info["pos"] = to_v3(info.get("pos"))
		var ft := FelledTree.create(info, to_v3(t.dir, Vector3.FORWARD), cfg, visuals)
		scene.add_child(ft)
		ft.logs_total = int(t.logs_total)
		ft.logs_left = int(t.logs_left)
		ft.work = float(t.work)
		if bool(t.get("down", true)):
			ft.theta = float(t.theta)
			ft.omega = 0.0
			ft.state = FelledTree.State.DOWN
			ft._apply_pose()
			ft._make_trunk_body()
		else:
			ft.theta = PI * 0.5 - 0.05           # was falling: it comes down again, the last bit of the way
	for t in d.get("loose", []):
		scene.add_child(_loose_bole(t, cfg, visuals))
	for t in d.get("piles", []):
		var lp := LogPile.new()
		lp.name = "LogPile"
		lp.count = int(t.count)
		lp.log_length = float(t.len)
		lp.log_radius = float(t.r)
		lp.species = String(t.species)
		lp.transform = to_xf(t.xf)
		lp._build(visuals)
		scene.add_child(lp)


## A loose bole (SkidLoad) as it lay: its ends, radii and the logs left in it.
static func _loose_bole(t: Dictionary, felling: Dictionary, visuals: bool) -> SkidLoad:
	var s := SkidLoad.new()
	var info: Dictionary = t.info
	info["pos"] = to_v3(info.get("pos"))
	s.name = "SkidLog_%d" % int(info.get("i", 0))
	s.info = info
	s._cfg = felling
	s.cfg = HorseHaul.data()
	s._log_len = float(felling.get("log_length_m", 2.4))
	s._visuals = visuals
	s.cut_work = float(t.get("cut_work", 3.0))
	s.hardness = float(t.get("hardness", 1.0))
	s.logs_total = int(t.logs_total)
	s.logs_left = int(t.logs_left)
	s.work = float(t.get("work", 0.0))
	s.state = FelledTree.State.DOWN
	s.r_front = float(t.r0)
	s.r_back = float(t.r1)
	s.front = to_v3(t.front)
	s.back = to_v3(t.back)
	s._setup(s.front.distance_to(s.back))
	s.laid = bool(t.get("laid", false))        # a barricade log stays exactly where it was put
	return s


# --- Building ----------------------------------------------------------------------------------------------

static func save_building(level: Node) -> Dictionary:
	var w := BuildWorld.of(level.get_tree(), false)
	if w == null:
		return {}
	var ps := []
	var pieces := w.pieces()
	pieces.sort_custom(func(a: BuiltPiece, b: BuiltPiece) -> bool: return a.piece_id < b.piece_id)
	for p in pieces:
		var e := {"id": p.piece_id, "type": p.type, "xf": xf(p.global_transform), "grounded": p.grounded,
				"supports": Array(p.supports), "ground": Array(p.ground)}
		if p.door:
			e["open"] = p.door.is_open
		for c in p.find_children("*", "Campfire", true, false):
			var cf := c as Campfire
			e["fire"] = {"lit": cf.state.lit, "left": cf.state.burn_left, "total": cf.state.burn_total, "coals": cf._coals}
			break
		var chest := p.get_node_or_null("Chest") as StorageChest
		if chest:
			e["chest"] = chest.to_save()
		var pile := p.get_node_or_null("Woodpile") as Woodpile
		if pile:
			e["woodpile"] = pile.to_save()
		var smoke := p.get_node_or_null("Smokehouse") as Smokehouse
		if smoke:
			e["smokehouse"] = smoke.to_save_all()
		ps.append(e)
	return {"pieces": ps, "next_id": w.next_id}


static func load_building(level: Node, d: Dictionary) -> void:
	var ps: Array = d.get("pieces", [])
	if ps.is_empty():
		return
	var w := BuildWorld.of(level.get_tree(), true)
	for e in ps:
		w.next_id = int(e.id)
		var g := PackedFloat32Array()
		for x in e.get("ground", []):
			g.append(float(x))
		var p := w.add_piece(String(e.type), to_xf(e.xf), bool(e.grounded), -1, g)
		var sup: Array[int] = []
		for x in e.get("supports", []):
			sup.append(int(x))
		p.supports = sup
		if e.has("open") and p.door:
			p.door.set_open(bool(e.open), true)
		if e.has("fire"):
			_restore_fire.call_deferred(p, e.fire)
		if e.has("chest") and p.get_node_or_null("Chest") is StorageChest:
			(p.get_node("Chest") as StorageChest).from_save(e.chest)
		if e.has("woodpile") and p.get_node_or_null("Woodpile") is Woodpile:
			(p.get_node("Woodpile") as Woodpile).from_save(int(e.woodpile))
		if e.has("smokehouse") and p.get_node_or_null("Smokehouse") is Smokehouse:
			(p.get_node("Smokehouse") as Smokehouse).from_save_all(e.smokehouse)
	w.next_id = maxi(w.next_id, int(d.get("next_id", w.next_id)))


static func _restore_fire(p: BuiltPiece, f: Dictionary) -> void:
	if not is_instance_valid(p):
		return
	for c in p.find_children("*", "Campfire", true, false):
		var cf := c as Campfire
		if cf.state == null:
			continue
		cf.state.burn_left = float(f.left)
		cf.state.burn_total = float(f.total)
		cf._coals = float(f.get("coals", 0.0))
		if bool(f.lit) and not cf.state.lit:
			cf.light()
		elif not bool(f.lit) and cf.state.lit:
			cf.state.snuff("snuffed")
		break


# --- Fort --------------------------------------------------------------------------------------------------

static func save_fort(level: Node) -> Dictionary:
	var out := {}
	var wc := WallCuts.find(level.get_tree())
	if wc:
		var cuts := []
		for win in wc.windows:
			var base := float((wc.frame(int(win.wall))[0] as Vector3).y)
			cuts.append({"wall": int(win.wall), "k": int(win.k), "h0": float(win.y0) - base, "h1": float(win.y1) - base,
					"rect": [float(win.u0), float(win.u1), float(win.y0) - base, float(win.y1) - base]})
		var holes := []
		for wi in wc.walls.size():
			holes.append(plain((wc.walls[wi] as Dictionary).holes))
		var fills := []
		for f in wc.fills:
			var e := {"kind": String(f.kind), "wall": int(f.wall), "rect": plain(f.rect)}
			if f.door != null and is_instance_valid(f.door):
				e["away"] = v3(-(f.door as Node3D).global_basis.z)
				e["open"] = (f.door as BuildDoor).is_open
			fills.append(e)
		out = {"cuts": cuts, "holes": holes, "fills": fills}
	var gate := FortGate.find(level.get_tree())
	if gate:
		out["gate_open"] = gate.open
	return out


static func load_fort(level: Node, d: Dictionary) -> void:
	var wc := WallCuts.find(level.get_tree())
	if wc and d.has("cuts"):
		for c in d.cuts:
			if int(c.wall) < wc.walls.size():
				wc.cut(int(c.wall), int(c.k), float(c.h0), float(c.h1))
		# holes since repaired: the ones cut that are no longer open and not covered or doored
		var saved_holes: Array = d.get("holes", [])
		var filled := []
		for f in d.get("fills", []):
			filled.append([int(f.wall), f.rect])
		for c in d.cuts:
			var wi := int(c.wall)
			if wi >= saved_holes.size():
				continue
			var open := false
			for h in saved_holes[wi]:
				if _same_rect(h, c.rect):
					open = true
			var covered := filled.any(func(e: Array) -> bool: return e[0] == wi and _same_rect(e[1], c.rect))
			if not open and not covered:
				wc.repair({"wall": wi, "rect": c.rect})
		for f in d.get("fills", []):
			var op := {"wall": int(f.wall), "rect": f.rect}
			if String(f.kind) == "cover":
				wc.cover(op)
			elif String(f.kind) == "door":
				op["away"] = to_v3(f.get("away"), Vector3.FORWARD)
				var door := wc.add_door(op)
				if door and bool(f.get("open", false)):
					door.set_open(true, true)
	var gate := FortGate.find(level.get_tree())
	if gate and d.has("gate_open"):
		gate.set_open(bool(d.gate_open), true)


static func _same_rect(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array) or (a as Array).size() != 4 or (b as Array).size() != 4:
		return false
	for i in 4:
		if absf(float(a[i]) - float(b[i])) > 0.01:
			return false
	return true


# --- Items -------------------------------------------------------------------------------------------------

static func save_items(level: Node) -> Dictionary:
	var tree := level.get_tree()
	var placed := []
	for n in tree.get_nodes_in_group(PlacedWeapon.GROUP):
		var pw := n as PlacedWeapon
		if pw == null or pw.is_queued_for_deletion():
			continue
		var e := {"key": pw.key, "xf": xf(pw.global_transform), "state": plain(pw.state)}
		if pw.rack != null and is_instance_valid(pw.rack):
			var bp := (pw.rack as Node).get_parent() as BuiltPiece
			if bp:
				e["piece"] = bp.piece_id          # a built rack (its node is "Rack" in every one)
			else:
				e["rack"] = String((pw.rack as Node).name)
			e["slot"] = pw.rack_slot
		placed.append(e)
	var thrown := []
	for n in tree.current_scene.find_children("*", "ThrownProjectile", true, false):
		var tp := n as ThrownProjectile
		if tp.collected or tp.is_queued_for_deletion() or not (tp.phase in [ThrownProjectile.Phase.STUCK, ThrownProjectile.Phase.LYING]):
			continue
		thrown.append({"kind": tp.kind, "model": tp.model_kind, "flight": int(tp.flight), "phase": int(tp.phase), "xf": xf(tp.global_transform)})
	var torches := []
	for n in tree.current_scene.find_children("*", "DroppedTorch", true, false):
		var dt := n as DroppedTorch
		if dt.is_queued_for_deletion() or dt.state == null:
			continue
		torches.append({"xf": xf(dt.global_transform), "state": plain(dt.state.to_dict())})
	return {"placed": placed, "thrown": thrown, "torches": torches}


static func load_items(level: Node, d: Dictionary) -> void:
	var tree := level.get_tree()
	var scene := tree.current_scene
	var p := _player(level)
	# the demo racks come back with the level: the saved ones replace what they hold
	for n in tree.get_nodes_in_group(PlacedWeapon.GROUP):
		if n is PlacedWeapon:
			var pw := n as PlacedWeapon
			if pw.rack != null and is_instance_valid(pw.rack):
				(pw.rack as WeaponRack).free_slot(pw.rack_slot)
			pw.get_parent().remove_child(pw)
			pw.queue_free()
	for e in d.get("placed", []):
		var w: Weapon = p.weapons.get(String(e.key)) if p else null
		if w == null:
			continue
		var pw := PlacedWeapon.from_weapon(w, String(e.key))
		pw.state = e.state
		scene.add_child(pw)
		var rack: Node = null
		if e.has("piece"):
			var bw := BuildWorld.of(tree, false)
			var bp := bw.by_id(int(e.piece)) if bw else null
			rack = bp.get_node_or_null("Rack") if bp else null
		elif e.has("rack"):
			rack = scene.find_child(String(e.rack), true, false)
		if rack is WeaponRack:
			(rack as WeaponRack).place(pw, int(e.slot))
		else:
			pw.global_transform = to_xf(e.xf)
	for e in d.get("thrown", []):
		var tp := ThrownProjectile.new()
		tp.kind = String(e.kind)
		tp.model_kind = String(e.model)
		tp.flight = int(e.get("flight", 0)) as ThrownProjectile.Flight
		tp.whoosh = false
		tp.phase = int(e.phase) as ThrownProjectile.Phase
		scene.add_child(tp)
		tp.global_transform = to_xf(e.xf)
		tp._hang_trim()
		tp._make_pickup()
	for e in d.get("torches", []):
		var dt := DroppedTorch.spawn(scene, to_xf(e.xf), Vector3.ZERO, Vector3.ZERO, TorchState.from_dict(e.state))
		dt.freeze = true


# --- Wildlife ----------------------------------------------------------------------------------------------

static func _spawner(level: Node) -> WildlifeSpawner:
	return level.get_node_or_null("Wildlife") as WildlifeSpawner


static func save_wildlife(level: Node) -> Dictionary:
	var sp := _spawner(level)
	if sp == null:
		return {}
	var groups := []
	var in_group := {}
	for e in sp.groups:
		var g: WildGroup = e.group
		var ms := []
		for a in g.members:
			if is_instance_valid(a):
				ms.append(_animal(a))
				in_group[a.get_instance_id()] = true
		groups.append({"kind": String(e.kind), "species": g.species, "home": v3(g.home), "activity": int(g.activity),
				"losses": g.losses, "members": ms})
	var loose := []
	for a in sp.animals():
		if not in_group.has(a.get_instance_id()):
			loose.append(_animal(a))
	return {"now": sp.now, "groups": groups, "loose": loose, "ecology": sp.land.to_dict()}


static func _animal(a: WildAnimal) -> Dictionary:
	var e := {"species": a.species, "xf": xf(a.global_transform), "health": a.health, "hunger": a.hunger,
			"fatigue": a.get("fatigue"), "dead": a.is_dead()}
	if a.is_dead():
		e["meat"] = a.meat_left
		e["dress"] = a.dress_step
		e["progress"] = a.dress_progress
		e["died_at"] = float(a.get_meta("died_at", 0.0))
		e["killed_by"] = String(a.get("killed_by"))
		# its clean-up clock (WildlifeSpawner._sweep_carcasses): last hauled and touched; on a rope now, as let go now
		var sp_now := float(a.spawner.get(&"now")) if a.spawner else 0.0
		if a.get_meta(&"on_chain", false):
			e["hauled_at"] = sp_now
		elif a.has_meta(&"hauled_at"):
			e["hauled_at"] = float(a.get_meta(&"hauled_at"))
		if a.has_meta(&"touched_at"):
			e["touched_at"] = float(a.get_meta(&"touched_at"))
	return e


static func load_wildlife(level: Node, d: Dictionary) -> void:
	var sp := _spawner(level)
	if sp == null or not d.has("groups"):
		return
	# the fresh level's animals go; so do the ravens (they come to carcasses on their own) and the spawner's lists of
	# the living (refreshed below: nothing may point at a freed animal)
	for r in sp.get_tree().get_nodes_in_group(&"ravens"):
		r.get_parent().remove_child(r)
		r.free()
	for a in sp.animals():
		a.get_parent().remove_child(a)
		a.free()
	sp.groups.clear()
	sp.live_wolves.clear()
	sp.live_prey.clear()
	sp.now = float(d.get("now", sp.now))
	for ge in d.groups:
		var g := WildGroup.new()
		g.species = String(ge.species)
		g.home = to_v3(ge.home)
		g.activity = int(ge.get("activity", 0)) as WildGroup.Activity
		g.activity_since = sp.now
		g.losses = int(ge.get("losses", 0))
		for m in ge.members:
			var a := _make_animal(sp, g, m)
			if a:
				g.members.append(a)
		sp.groups.append({"kind": String(ge.kind), "group": g})
	for m in d.get("loose", []):
		_make_animal(sp, null, m)
	if sp.has_method("_refresh_lists"):
		sp._refresh_lists()
	# the land's numbers as they were (after the animals: their deaths replayed above do not count twice); a save from
	# before them: as many as came back alive
	if d.has("ecology"):
		sp.land.from_dict(d.ecology)
	else:
		var live := sp.live_counts()
		for s: String in ["deer", "wolf", "fox"]:
			sp.ecology.pop[s] = float(live.get(s, 0))
	sp.set("_eco_day", -1.0)


static func _make_animal(sp: WildlifeSpawner, g: WildGroup, m: Dictionary) -> WildAnimal:
	var a := WildAnimal.new()
	sp.set("_serial", int(sp.get("_serial")) + 1)
	a.name = "%s_%d" % [String(m.species).capitalize(), int(sp.get("_serial"))]
	a.setup(String(m.species), sp, g, 1765 + int(sp.get("_serial")) * 7919)
	sp.add_child(a)
	a.global_transform = to_xf(m.xf)
	a.health = float(m.health)
	a.hunger = float(m.get("hunger", a.hunger))
	if m.get("fatigue") != null:
		a.set("fatigue", float(m.fatigue))
	if bool(m.get("dead", false)):
		a.lie_dead(String(m.get("killed_by", "")))       # lying as it fell, not falling again
		a.meat_left = float(m.get("meat", 1.0))
		a.dress_step = int(m.get("dress", 0))
		a.dress_progress = float(m.get("progress", 0.0))
		a.set_meta("died_at", float(m.get("died_at", sp.now)))
		if m.has("hauled_at"):
			a.set_meta(&"hauled_at", float(m.hauled_at))
		if m.has("touched_at"):
			a.set_meta(&"touched_at", float(m.touched_at))
		if a.dress_step >= 1 and a.has_method("_show_skinned"):
			a._show_skinned()
		if a._next_step().is_empty():
			a.remove_from_group(PlacedWeapon.GROUP)
	return a


# --- Horse -------------------------------------------------------------------------------------------------

static func save_horse(level: Node) -> Dictionary:
	var hs := level.find_children("*", "Horse", true, false)
	if hs.is_empty():
		return {}
	var h := hs[0] as Horse
	return {"xf": xf(h.global_transform)}


static func load_horse(level: Node, d: Dictionary) -> void:
	var hs := level.find_children("*", "Horse", true, false)
	if hs.is_empty() or not d.has("xf"):
		return
	var h := hs[0] as Horse
	var haul := h.get_node_or_null("Haul") as HorseHaul
	if haul and haul.load != null:
		haul.unhitch()
	var lead := h.get_node_or_null("Lead") as HorseLead
	if lead and lead.leading:
		lead.stop()
	h.global_transform = to_xf(d.xf)
	h.velocity = Vector3.ZERO
	h.speed = 0.0


# --- Forage ------------------------------------------------------------------------------------------------

static func save_wheelbarrow(level: Node) -> Dictionary:
	var w := Wheelbarrow.find(level.get_tree())
	return w.save_data() if w else {}


static func load_wheelbarrow(level: Node, d: Dictionary) -> void:
	var w := Wheelbarrow.find(level.get_tree())
	if w and d.has("xf"):
		w.load_data(d)


static func save_cart(level: Node) -> Dictionary:
	var c := HorseCart.find(level.get_tree())
	return c.save_data() if c else {}


static func load_cart(level: Node, d: Dictionary) -> void:
	var c := HorseCart.find(level.get_tree())
	if c and d.has("xf"):
		c.load_data(d)


static func save_forage(level: Node) -> Dictionary:
	var f := ForageField.find(level.get_tree())
	if f == null:
		return {}
	var ps := []
	for pa in f.patches:
		var st := []
		var gone := []
		var dug := []
		for pl in pa.plants:
			st.append(snappedf(float(pl.stock), 0.001))
			gone.append(bool(pl.gone))
			dug.append(f.now - float(pl.get("dug_t", f.now)) if pl.gone else 0.0)
		ps.append({"stock": st, "gone": gone, "dug_ago": dug, "browse": float(pa.browse), "deer_ago": f.now - float(pa.deer_t),
				"t_ago": f.now - float(pa.t)})
	return {"sig": layout_signature(level), "patches": ps}


static func load_forage(level: Node, d: Dictionary) -> void:
	var f := ForageField.find(level.get_tree())
	if f == null or String(d.get("sig", "")) != layout_signature(level):
		return
	var ps: Array = d.get("patches", [])
	if ps.size() != f.patches.size():
		return
	for i in ps.size():
		var pa: Dictionary = f.patches[i]
		var e: Dictionary = ps[i]
		var pl: Array = pa.plants
		if (e.stock as Array).size() != pl.size():
			continue
		var dug: Array = e.get("dug_ago", [])
		for k in pl.size():
			pl[k].stock = float(e.stock[k])
			pl[k].gone = bool(e.gone[k])
			if pl[k].gone and k < dug.size():
				pl[k].dug_t = f.now - float(dug[k])
		pa.browse = float(e.browse)
		pa.deer_t = f.now - float(e.deer_ago)
		pa.t = f.now - float(e.t_ago)
		f._refresh_patch(i)
