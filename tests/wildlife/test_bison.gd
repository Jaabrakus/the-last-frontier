extends SceneTree
## The plains bison (WildlifeSpecies "bison"; user 2026-09-28: "lets work on the bison so we can reuse a lot of the animal
## things for different animals"), on the real level with its wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_bison.gd -- wildlife=on
##
##   land      the open land east of the fort (square 1,0) holds its herds, to its numbers (WildlifeLand); none in the
##             fort's woods, whose deer, buck, foxes and pack are stocked as ever
##   model     the rigged bison: its bones for the hit zones, a bull's build (~1.97 m at the hump, 3.3 m long), the cows
##             smaller, every one bigger than the horse
##   herd      grazing, a herd keeps its room (spread round its leader, not piled up) and its land (its square)
##   stampede  one bolting, the herd goes with it, the same way
##   charge    shot and hurt with the hunter close, a bison turns and charges him: the butt hurts and throws him down
##   carcass   a dead bison is six deer of meat: skinned it gives a buffalo robe, butchered 14 venison, the tongue, tallow,
##             sinew and brains, and the remains are left for the scavengers
##   wolves    a sound bison is no wolf's prey; a weak one is
## Ends with "BISON TEST PASSED (<n> checks)" or "BISON TEST FAILED (<f> of <n>)".

const PLAINS := Vector2i(1, 0)

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var p: FrontierPlayer


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	p = current_scene.get_node("Player") as FrontierPlayer
	_expect(w != null, "the level has its wildlife (wildlife=on)")
	if w == null:
		_end()
		return
	p.ignore_mouse_capture = true
	w._restock_t = 1e9
	await _secs(1.0)
	_land()
	var herd := _herd()
	if herd == null:
		_end()
		return
	_model(herd)
	await _grazing(herd)
	await _stampede(herd)
	await _charge(herd)
	_carcass(herd)
	_wolves(herd)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("BISON TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BISON TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _bison() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for a in w.animals():
		if a.species == "bison" and not a.is_dead():
			out.append(a)
	return out


func _on(pos: Vector3) -> Vector3:
	return Vector3(pos.x, FrontierTerrain.height_at(pos.x, pos.z) + 0.1, pos.z)


func _land() -> void:
	var bs := _bison()
	var want := int(w.land.ecology(PLAINS).targets().get("bison", 0))
	var on_plains := bs.filter(func(a: WildAnimal) -> bool: return a.home_sq == PLAINS).size()
	var herds := w.groups.filter(func(e: Dictionary) -> bool: return String(e.kind) == "bison_herd")
	_expect(want > 0 and on_plains >= int(want * 0.7) and on_plains == bs.size() and herds.size() >= 2,
			"land: the open land holds %d bison in %d herds (its numbers want %d), none elsewhere" % [on_plains, herds.size(), want])
	var fort := {}
	for e in w.groups:
		if (e.group as WildGroup).home.length() < 400.0:
			fort[String(e.kind)] = int(fort.get(String(e.kind), 0)) + 1
	_expect(int(fort.get("deer_herd", 0)) == 4 and int(fort.get("lone_buck", 0)) == 1 and int(fort.get("fox", 0)) == 3
			and int(fort.get("wolf_pack", 0)) == 1 and not fort.has("bison_herd"),
			"land: the fort's woods stocked as ever (%s)" % str(fort))


func _herd() -> WildGroup:
	var best: WildGroup = null
	for e in w.groups:
		var g: WildGroup = e.group
		if String(e.kind) == "bison_herd" and (best == null or g.alive().size() > best.alive().size()):
			best = g
	_expect(best != null and best.alive().size() >= 6, "herd: a herd of %d" % (best.alive().size() if best else 0))
	return best


## The rigged bison at a bull's build (user 2026-09-28: "make the bisons accurate make them bigger they can not be smaller
## than the horse"): the bulls ~1.97 m at the hump and 3.3 m long, the cows smaller; every one taller and longer than the
## horse (1.43 m at the withers, 2.4 m long).
func _model(g: WildGroup) -> void:
	var a := g.alive()[0]
	var sk := a.find_children("*", "Skeleton3D", true, false)
	var hs: Array[float] = []
	var ls: Array[float] = []
	var bulls := 0
	for b in g.alive():
		var h := 0.0
		var l := 0.0
		for m: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
			var sc := m.global_basis.get_scale()
			h = maxf(h, m.get_aabb().size.y * sc.y)
			l = maxf(l, m.get_aabb().size.z * sc.z)
		hs.append(h)
		ls.append(l)
		if b.size > 0.95:
			bulls += 1
	_expect(not sk.is_empty() and (sk[0] as Skeleton3D).find_bone("Torso3") >= 0 and (sk[0] as Skeleton3D).find_bone("Head") >= 0
			and hs.max() > 1.85 and hs.max() < 2.1 and ls.max() > 3.1 and ls.max() < 3.6,
			"model: the rigged bison, its hit zones' bones there, a bull's build (%.2f m at the hump, %.2f m long)" % [hs.max(), ls.max()])
	_expect(hs.min() > 1.55 and ls.min() > 2.6 and bulls >= 1 and bulls < g.alive().size(),
			"model: bulls (%d) and cows (%d), the smallest %.2f m tall and %.2f m long, all bigger than the horse (1.43, 2.4)" % [
			bulls, g.alive().size() - bulls, hs.min(), ls.min()])


## The player 110 m off the herd (it is awake within WildlifeSpawner.ACTIVE_D), downwind-agnostic: far enough not to
## alarm it.
func _watch(g: WildGroup, off := Vector3(-110.0, 0.0, 0.0)) -> void:
	p.global_position = _on(g.centroid() + off)
	p.velocity = Vector3.ZERO
	w._lod()


func _grazing(g: WildGroup) -> void:
	_watch(g)
	await _secs(40.0)
	var al := g.alive()
	var nn := 0.0
	var far := 0.0
	var c := g.centroid()
	for a in al:
		var best := INF
		for b in al:
			if b != a:
				best = minf(best, a.global_position.distance_to(b.global_position))
		nn += best
		far = maxf(far, a.global_position.distance_to(c))
	nn /= maxf(al.size(), 1.0)
	var rg := WildlifeSpawner.range_of(PLAINS, true)
	var inside := al.all(func(a: WildAnimal) -> bool:
		var o := a.global_position - (rg[0] as Vector3)
		return absf(o.x) <= float(rg[1]) + 5.0 and absf(o.z) <= float(rg[1]) + 5.0)
	_expect(nn > 2.5 and far < 70.0 and inside,
			"herd: grazing, each keeps its room (nearest %.1f m), the herd together (%.0f m across its middle), on its land" % [nn, far])


func _stampede(g: WildGroup) -> void:
	var al := g.alive()
	var c := g.centroid()
	al[0]._start_flee(c + Vector3(-40.0, 0.0, 0.0))
	await _secs(2.5)
	var fleeing := 0
	var sum := Vector3.ZERO
	for a in al:
		if a.state == WildAnimal.State.FLEE:
			fleeing += 1
		var v := Vector3(a.velocity.x, 0.0, a.velocity.z)
		if v.length() > 0.5:
			sum += v.normalized()
	var together := sum.length() / maxf(al.size(), 1.0)
	_expect(fleeing >= int(al.size() * 0.7) and together > 0.6,
			"stampede: one bolting, %d of %d run, the same way (%.2f of one line)" % [fleeing, al.size(), together])
	await _secs(12.0)


func _charge(g: WildGroup) -> void:
	# one bison, calm again, the hunter 11 m before it; shot through the haunch from where he stands
	var a: WildAnimal = g.alive()[g.alive().size() - 1]
	for b in g.alive():
		if b != a:
			b.set_active(false)
	a.awareness = 0.0
	a._enter(WildAnimal.State.IDLE, 5.0)
	var fwd := -a.global_basis.z
	p.global_position = _on(a.global_position + fwd * 11.0)
	p.velocity = Vector3.ZERO
	var h0 := p.health
	var dir := (a.global_position - p.global_position).normalized()
	a.apply_hit(160.0, a.global_position + Vector3.UP * 1.1 - fwd * 0.9, dir, p, "body")
	var charged := false
	var thrown := false
	for i in int(6.0 * Engine.physics_ticks_per_second):
		await physics_frame
		charged = charged or a.state == WildAnimal.State.CHASE
		thrown = thrown or PlayerRagdoll.of(p).is_down()
		if p.health < h0 and thrown:
			break
	_expect(charged and p.health < h0 and thrown,
			"charge: hurt (%s, %.0f of %.0f), it charges the hunter (%s), the butt hurts him (%.0f -> %.0f) and throws him (%s)" % [
			a.last_wound, a.health, float(a.data.health), charged, h0, p.health, thrown])
	for b in g.alive():
		b.set_active(true)
	# up again, whole, away from it
	await _secs(6.0)
	p.health = 100.0


func _carcass(g: WildGroup) -> void:
	var a: WildAnimal = g.alive()[0]
	a.apply_hit(5000.0, a.global_position + Vector3.UP * 1.1, Vector3.RIGHT, p, "body")
	var dead := a.is_dead()
	var meat := a.meat_left
	var inv := InventoryState.from_player(p)
	var before := {}
	for k in ["bison_robe", "venison", "tongue", "tallow", "sinew", "brains"]:
		before[k] = inv.pack_count(k)
	a.set_meta("died_at", -100.0)
	var prompt := a.interact_prompt(p)
	a.finish_dress("skin", p)
	var prompt2 := a.interact_prompt(p)
	a.finish_dress("butcher", p)
	inv = InventoryState.from_player(p)
	var got := {}
	for k in before:
		got[k] = inv.pack_count(k) - int(before[k])
	_expect(dead and absf(meat - 6.0) < 0.01 and prompt.begins_with("Skin the bison") and prompt2.begins_with("Butcher the bison"),
			"carcass: dead, six deer of meat (%.1f); \"%s\", then \"%s\"" % [meat, prompt, prompt2])
	_expect(int(got.bison_robe) == 1 and int(got.venison) == 14 and int(got.tongue) == 1 and int(got.tallow) == 3
			and int(got.sinew) == 4 and int(got.brains) == 1 and a.meat_left <= WildAnimal.REMAINS_MEAT * 6.0 + 0.01
			and a.meat_left > 0.5,
			"carcass: a buffalo robe, then 14 venison, the tongue, 3 tallow, 4 sinew, the brains (%s); %.1f left for the scavengers" % [
			str(got), a.meat_left])


func _wolves(g: WildGroup) -> void:
	w._refresh_lists()
	var sound := g.alive().filter(func(a: WildAnimal) -> bool: return not a.weak())
	var any_sound_prey := sound.any(func(a: WildAnimal) -> bool: return a in w.live_prey)
	var weak: WildAnimal = sound[0] if not sound.is_empty() else null
	if weak:
		weak.health = float(weak.data.health) * 0.4
	w._refresh_lists()
	_expect(not any_sound_prey and weak != null and weak in w.live_prey,
			"wolves: no sound bison is their prey; one gone weak is")
