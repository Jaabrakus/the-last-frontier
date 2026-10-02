extends SceneTree
## The wild horses (WildlifeSpecies "horse" / "stallion" on WildHorse; catching and breaking them, HorseBreaking; user
## 2026-09-28: "use the bison or deer logic to build a herd of wild horses that can be tamed, we use g to grip"), on the
## real level with its wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_wild_horses.gd -- wildlife=on
##
##   land      a band in the fort's woods (a stallion and mares, a mare leading) and herds on the open land; the
##             horse's own model, a coat each, no tack
##   gaits     a walk or a run shown as the gait for the speed (walk, trot, canter, gallop, sprint)
##   graze     grazing, the head goes down to the grass (the bit near the ground)
##   flight    one bolting, the band goes with it; running winds them (fatigue climbs), and winded a horse only trots
##   catch     G before its nose: it wheels away; behind a fresh one: it kicks; at the side of a winded one: up on its
##             back, the band bolting, one fewer in the land's numbers
##   break     ridden out (a steady rider against each throw) it is broken: the player's, rideable, bridled, no saddle;
##             kept in the save
##   thrown    a rider who sits still is thrown (knocked down, hurt) and the horse is wild again, a little gentled
##   ground    knocked down beside a winded one, G from the ground: up at once and onto its back
##   saddle    G riding alongside a wild horse: over onto its back from the saddle; G lets go
##   carcass   shot dead it goes over on its side; skinned rawhide, butchered venison, sinew, tallow and brains
## Ends with "WILD HORSE TEST PASSED (<n> checks)" or "WILD HORSE TEST FAILED (<f> of <n>)".

const OPEN_LAND := Vector2i(1, 0)
const MOVE_KEYS := ["move_left", "move_right", "move_forward", "move_back"]

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
	var band := _land()
	if band == null:
		_end()
		return
	_gaits(band)
	await _graze(band)
	await _flight(band)
	await _catch_refused(band)
	var tamed := await _break(band)
	if tamed:
		await _ride_tamed(tamed)
		_save(tamed)
	await _thrown(band)
	await _from_ground(band)
	await _from_saddle()
	await _carcass()
	_end()


func _end() -> void:
	for k in MOVE_KEYS:
		Input.action_release(k)
	Input.action_release("grip")
	if fails.is_empty():
		print("WILD HORSE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("WILD HORSE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _on(pos: Vector3) -> Vector3:
	return Vector3(pos.x, FrontierTerrain.height_at(pos.x, pos.z) + 0.1, pos.z)


func _horses() -> Array[WildHorse]:
	var out: Array[WildHorse] = []
	for a in w.animals():
		if a is WildHorse and (a as WildHorse).catchable() and not a.is_dead():
			out.append(a as WildHorse)
	return out


func _band_near_fort() -> WildGroup:
	for e in w.groups:
		var g: WildGroup = e.group
		if String(e.kind) == "horse_herd" and WorldSquares.square_at(g.home) == Vector2i.ZERO and not g.alive().is_empty():
			return g
	return null


func _land() -> WildGroup:
	var g := _band_near_fort()
	var al: Array[WildAnimal] = g.alive() if g else ([] as Array[WildAnimal])
	var stallions := al.filter(func(a: WildAnimal) -> bool: return a.species == "stallion").size()
	var lead := g.leader() if g else null
	_expect(g != null and al.size() >= 4 and stallions == 1 and lead != null and lead.species == "horse",
			"land: a band in the fort's woods, %d strong, one stallion (%d), a mare leading (%s)" % [
			al.size(), stallions, lead.species if lead else "-"])
	var open := _horses().filter(func(a: WildHorse) -> bool: return a.home_sq == OPEN_LAND).size()
	var want := int(w.land.ecology(OPEN_LAND).targets().get("horse", 0))
	_expect(want > 0 and open > 0, "land: the open land holds %d wild horses (its numbers want %d)" % [open, want])
	if g == null:
		return null
	var h := al[0] as WildHorse
	var coats := {}
	for a in al:
		coats[(a as WildHorse).coat] = true
	var saddle := h.find_children("Saddle", "MeshInstance3D", true, false)
	var body := h.find_children("HorseBody", "MeshInstance3D", true, false)
	_expect(h != null and not body.is_empty() and not saddle.is_empty() and not (saddle[0] as MeshInstance3D).visible
			and coats.size() >= 1 and _coat_ok(h.coat),
			"land: the horse's own model, no tack (the saddle hidden), coats %s" % str(coats.keys()))
	return g


static func _coat_ok(c: String) -> bool:
	return (preload("res://scripts/horse/horse_look.gd").COATS as Dictionary).has(c)


func _gaits(g: WildGroup) -> void:
	var h := g.alive()[0] as WildHorse
	var got := []
	for v in [0.0, 1.2, 3.0, 6.0, 10.0, 13.2]:
		h._speed = v
		h._play("run")
		got.append(h._anim)
	h._speed = 0.0
	_expect(got == ["idle", "walk", "trot", "canter", "gallop", "sprint"], "gaits: by speed %s" % str(got))


func _graze(g: WildGroup) -> void:
	var h := g.alive()[0] as WildHorse
	_watch(g)
	for a in g.alive():
		a.set_active(a == h)
	# (its own mind off: the clips and the pose run, nothing replays them)
	h.set_physics_process(false)
	var sk: Skeleton3D = h._skel
	var bit := sk.find_bone("bit")
	var ys := {"y": 0.0}
	var read := func() -> void:
		ys.y = (sk.global_transform * sk.get_bone_global_pose(bit).origin).y
	h._pose.modification_processed.connect(read)
	h._enter(WildAnimal.State.GRAZE, 30.0)
	h._play("graze")
	await _secs(2.5)
	var ground := FrontierTerrain.height_at(h.global_position.x, h.global_position.z)
	var low := float(ys.y) - ground
	h._head_want = Vector2.ZERO
	h._pose.neck_deg = 0.0
	h._pose.head_deg = 0.0
	await _secs(0.3)
	var up := float(ys.y) - ground
	h._pose.modification_processed.disconnect(read)
	h.set_physics_process(true)
	_expect(low < 0.4 and up > 1.0, "graze: the head down to the grass (the bit %.2f m off the ground; %.2f m head up)" % [low, up])
	for a in g.alive():
		a.set_active(true)


## The player 110 m off the band (awake within WildlifeSpawner.ACTIVE_D), far enough not to alarm it.
func _watch(g: WildGroup, off := Vector3(-110.0, 0.0, 0.0)) -> void:
	p.global_position = _on(g.centroid() + off)
	p.velocity = Vector3.ZERO
	w._lod()


func _flight(g: WildGroup) -> void:
	_watch(g)
	await _secs(1.0)
	var al := g.alive()
	for a in al:
		a.fatigue = 0.1
	al[0]._start_flee(g.centroid() + Vector3(-40.0, 0.0, 0.0))
	await _secs(2.5)
	var fleeing := al.filter(func(a: WildAnimal) -> bool: return a.state == WildAnimal.State.FLEE).size()
	var fast := 0.0
	var f0 := al[1].fatigue
	for a in al:
		fast = maxf(fast, Vector2(a.velocity.x, a.velocity.z).length())
	await _secs(2.0)
	var climbed := al[1].fatigue - f0
	_expect(fleeing >= int(al.size() * 0.7) and fast > 9.0,
			"flight: one bolting, %d of %d run (the fastest %.1f m/s)" % [fleeing, al.size(), fast])
	# winded: one run out, fleeing again, only trots
	var h := al[al.size() - 1]
	h.fatigue = 0.97
	h._start_flee(h.global_position + Vector3(-30.0, 0.0, 0.0))
	await _secs(2.5)
	var sp := Vector2(h.velocity.x, h.velocity.z).length()
	_expect(climbed > 0.03 and h.winded() > 0.95 and sp < 4.5 and sp > 1.5,
			"flight: running winds them (fatigue +%.2f in 2 s); winded (%.2f) it trots (%.1f m/s)" % [climbed, h.winded(), sp])
	await _secs(10.0)


## Till the player is on his feet again (a kick or a throw knocked him down), at most 15 s.
func _up() -> void:
	for i in int(15.0 * Engine.physics_ticks_per_second):
		if not PlayerRagdoll.of(p).is_down():
			break
		await physics_frame
	await _secs(0.5)


## A horse of the band, alone (the rest asleep), calm, and the player at `where` of it ("front", "back", "side").
func _set_up(h: WildHorse, where: String, winded := false) -> void:
	for a in w.animals():
		a.set_active(a == h)
		# (its band mates stood off: the G is for this one, the nearest)
		if a != h and a.global_position.distance_to(h.global_position) < 8.0:
			var off := a.global_position - h.global_position
			off.y = 0.0
			a.global_position = _on(h.global_position + (off.normalized() if off.length() > 0.1 else Vector3.RIGHT) * 12.0)
	h.awareness = 0.0
	h.fatigue = 0.97 if winded else 0.1
	h._enter(WildAnimal.State.IDLE, 30.0)
	h.velocity = Vector3.ZERO
	h._speed = 0.0
	var f := -h.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var r := h.global_basis.x
	var at := h.global_position
	match where:
		"front":
			at += f * 1.8
		"back":
			at -= f * 1.6
		_:
			at += r * 1.2
	p.global_position = _on(at)
	p.velocity = Vector3.ZERO
	if p.grip:
		p.grip.stamina = p.grip.stamina_max
		p.grip._cool = 0.0


func _press_g() -> void:
	Input.action_press("grip")
	await physics_frame
	await physics_frame
	Input.action_release("grip")
	await physics_frame


func _catch_refused(g: WildGroup) -> void:
	_watch(g)
	await _secs(1.0)
	var h := g.alive()[0] as WildHorse
	_set_up(h, "front")
	await physics_frame
	await _press_g()
	# (a mare bolts; the stallion, crowded, rears and strikes)
	var wheeled := h.state in [WildAnimal.State.FLEE, WildAnimal.State.ATTACK, WildAnimal.State.CHASE] and p.riding == null
	var how: String = WildAnimal.State.keys()[h.state]
	await _secs(3.0)
	await _up()
	_set_up(h, "back")
	await physics_frame
	await _press_g()
	var kicked := h.state in [WildAnimal.State.ATTACK, WildAnimal.State.FLEE] and p.riding == null
	_expect(wheeled and kicked, "catch: G before its nose, it will not have it (%s: %s); behind a fresh one, it kicks (%s)" % [
			h.species, how, kicked])
	await _secs(4.0)
	p.health = p.max_health
	for a in w.animals():
		a.set_active(true)


## Holding the rider's weight against the throw (the move keys as a steady rider would: against where the balance is
## going).
func _ride_well(b: HorseBreaking) -> void:
	var bal := b.balance + b.push * 0.3
	_key("move_left", bal.x > 0.1)
	_key("move_right", bal.x < -0.1)
	_key("move_back", bal.y > 0.1)
	_key("move_forward", bal.y < -0.1)


func _key(k: String, on: bool) -> void:
	if on:
		Input.action_press(k)
	else:
		Input.action_release(k)


func _keys_off() -> void:
	for k in MOVE_KEYS:
		Input.action_release(k)


func _break(g: WildGroup) -> Horse:
	_watch(g)
	await _secs(1.0)
	var al := g.alive()
	var h := al[al.size() - 1] as WildHorse
	var coat := h.coat
	var pop0 := float(w.land.at(h.global_position).pop.horse)
	var n0 := al.size()
	await _up()
	_set_up(h, "side", true)
	await physics_frame
	await _press_g()
	var horse := p.riding
	var b := horse.get_node_or_null(^"Breaking") as HorseBreaking if horse else null
	var pop1 := float(w.land.at(p.global_position).pop.horse)
	for a in w.animals():
		a.set_active(true)
	await _secs(1.0)
	var bolted := g.alive().filter(func(a: WildAnimal) -> bool: return a.state == WildAnimal.State.FLEE).size()
	_expect(b != null and (not is_instance_valid(h) or h.is_queued_for_deletion()),
			"catch: G at the side of a winded one, up on its back (riding %s, breaking %s)" % [horse, b != null])
	_expect(b != null and g.alive().size() == n0 - 1 and bolted >= 1 and pop1 <= pop0 - 0.99 and horse.coat == coat,
			"catch: out of its band (%d -> %d, %d bolting), one fewer in the land's numbers (%.1f -> %.1f), its coat %s" % [
			n0, g.alive().size(), bolted, pop0, pop1, horse.coat if horse else "-"])
	if b == null:
		return null
	# ridden out by a steady rider
	var t := 0.0
	var tipped := 0.0
	var leaned := 0.0
	var spirit0 := b.spirit_max
	while is_instance_valid(b) and b.outcome == "" and t < 90.0:
		_ride_well(b)
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if is_instance_valid(b):
			tipped = maxf(tipped, absf(b._pitch))
		if is_instance_valid(horse):
			leaned = maxf(leaned, absf(horse.terrain.body_pitch_deg))
	_keys_off()
	var stam := p.grip.stamina if p.grip else -1.0
	var broken: bool = is_instance_valid(horse) and horse.get_meta(&"tamed", false)
	var bridle := horse.find_children("Bridle", "MeshInstance3D", true, false) if broken else []
	var saddle := horse.find_children("Saddle", "MeshInstance3D", true, false) if broken else []
	_expect(broken and p.riding == horse and horse.get_node_or_null(^"Mount") != null and horse.get_node_or_null(^"Breaking") == null
			and horse.player_input,
			"break: ridden out in %.1f s (spirit %.0f; the body tipped up to %.0f deg, the rider leaning %.0f), stamina %.0f left: broken, his, rideable" % [
			t, spirit0, tipped, leaned, stam])
	_expect(broken and not bridle.is_empty() and (bridle[0] as MeshInstance3D).visible and not saddle.is_empty()
			and not (saddle[0] as MeshInstance3D).visible
			and horse.visual.transform.is_equal_approx(Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)),
			"break: a bridle and bit for the reins, no saddle, the body square again")
	return horse if broken else null


func _ride_tamed(h: Horse) -> void:
	await _secs(1.0)
	# (turned to the clearest way: its last spin may have left it facing a trunk)
	var best := h.rotation.y
	var clear := -1.0
	for i in 12:
		h.rotation.y = best if i == 0 else float(i) * TAU / 12.0
		await physics_frame
		var d := h.obstacle_distance()
		if d > clear:
			clear = d
			best = h.rotation.y
	h.rotation.y = best
	Input.action_press("move_forward")
	var v := 0.0
	for i in int(2.5 * Engine.physics_ticks_per_second):
		await physics_frame
		v = maxf(v, h.speed)
	Input.action_release("move_forward")
	await _secs(2.0)
	p.dismount()
	await _secs(0.5)
	_expect(v > 1.0 and p.riding == null, "break: ridden like any horse (%.1f m/s), and got off" % v)


func _save(h: Horse) -> void:
	var d := SaveParts.save_horse(current_scene)
	var list: Array = d.get("tamed", [])
	var coat := h.coat
	h.global_position += Vector3(3.0, 0.0, 0.0)
	SaveParts.load_horse(current_scene, d)
	var tamed := current_scene.find_children("*", "Horse", true, false).filter(func(x: Node) -> bool: return x.get_meta(&"tamed", false))
	var back := tamed[0] as Horse if tamed.size() == 1 else null
	_expect(list.size() == 1 and String(list[0].coat) == coat and back != null and back.coat == coat
			and back.get_node_or_null(^"Mount") != null and d.has("xf"),
			"save: the broken horse kept (%d; %s) and back as it was, the level's own horse too" % [list.size(), coat])
	# a wild one's coat and gentling
	var wild := _horses()[0]
	wild.gentled = 0.3
	var e := SaveParts._animal(wild)
	_expect(String(e.get("coat", "")) == wild.coat and absf(float(e.get("gentled", 0.0)) - 0.3) < 0.001,
			"save: a wild horse's coat and gentling (%s, %.1f)" % [String(e.get("coat", "")), float(e.get("gentled", 0.0))])
	wild.gentled = 0.0


func _thrown(g0: WildGroup) -> void:
	var g := _band_near_fort()
	if g == null or g.alive().is_empty():
		g = g0
	var h := g.alive()[0] as WildHorse
	_watch(g)
	await _secs(1.0)
	await _up()
	_set_up(h, "side", true)
	var pop0 := float(w.land.at(h.global_position).pop.horse)
	await physics_frame
	await _press_g()
	var horse := p.riding
	var b := horse.get_node_or_null(^"Breaking") as HorseBreaking if horse else null
	var caught := b != null
	var caught_at := p.global_position
	var h0 := p.health
	var t := 0.0
	var down := false
	while is_instance_valid(b) and b.outcome == "" and t < 30.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	for i in int(0.5 * Engine.physics_ticks_per_second):
		await physics_frame
		down = down or PlayerRagdoll.of(p).is_down()
	# (the one ridden: the most gentled near where it was caught)
	var back: WildHorse = null
	for a in _horses():
		if a.global_position.distance_to(caught_at) < 100.0 and a.gentled > 0.0 and (back == null or a.gentled > back.gentled):
			back = a
	var pop1 := float(w.land.at(p.global_position).pop.horse)
	_expect(caught and p.riding == null and down and p.health < h0,
			"thrown: a rider who sits still is off in %.1f s, knocked down (%s), hurt (%.0f -> %.0f)" % [t, down, h0, p.health])
	_expect(back != null and back.state == WildAnimal.State.FLEE and not is_instance_valid(horse) and absf(pop1 - pop0) < 0.01,
			"thrown: the horse wild again, bolting (%s), a little gentled (%.2f), the land's numbers as they were (%.1f, %.1f)" % [
			WildAnimal.State.keys()[back.state] if back else "-", back.gentled if back else -1.0, pop0, pop1])
	await _secs(6.0)
	p.health = p.max_health
	for a in w.animals():
		a.set_active(true)


## Knocked down beside a winded one, G from the ground: up at once and onto its back (user 2026-09-28: "grabbing while
## down should be okay to mount"); it holds (still on it a second on, the ragdoll done); G lets go.
func _from_ground(g0: WildGroup) -> void:
	var g := _band_near_fort()
	if g == null or g.alive().is_empty():
		g = g0
	await _up()
	var h := g.alive()[0] as WildHorse
	_watch(g)
	await _secs(1.0)
	_set_up(h, "side", true)
	h.set_active(false)
	p.knock_down(Vector3(0.0, 1.5, 0.0))
	await _secs(0.6)
	var was_down := PlayerRagdoll.of(p).is_down()
	await _press_g()
	var on := p.riding
	var caught := on != null and on.get_node_or_null(^"Breaking") != null
	await _secs(1.0)
	var holds := caught and is_instance_valid(on) and p.riding == on and not PlayerRagdoll.of(p).is_down() and p.kneeling == null
	await _press_g()
	await _secs(0.5)
	_expect(was_down and caught and holds and p.riding == null,
			"ground: knocked down (%s), G beside a winded one: up and onto its back (%s), still on it a second on (%s); G lets go" % [
			was_down, caught, holds])
	for a in w.animals():
		a.set_active(true)


func _from_saddle() -> void:
	var own: Horse = null
	for h: Horse in current_scene.find_children("*", "Horse", true, false):
		if not h.get_meta(&"tamed", false) and not h.has_meta(&"breaking"):
			own = h
	var wild := _horses()[0]
	if own == null or wild == null:
		_expect(false, "saddle: the level's horse and a wild one")
		return
	if wild.group:
		_watch(wild.group)
	await _secs(0.5)
	await _up()
	_set_up(wild, "side", true)
	# (held where it stands: its band may still be alarmed from the last catch)
	wild.set_active(false)
	# the level's horse alongside it, the same way, 2 m off
	var r := wild.global_basis.x
	own.global_transform = Transform3D(Basis(Vector3.UP, wild.rotation.y), _on(wild.global_position + r * 2.0) - Vector3.UP * 0.1)
	own.velocity = Vector3.ZERO
	own.speed = 0.0
	p.mount(own)
	await _secs(0.5)
	await _press_g()
	var on := p.riding
	var caught := on != null and on != own and on.get_node_or_null(^"Breaking") != null
	await _secs(0.6)
	await _press_g()
	await _secs(0.5)
	_expect(caught and p.riding == null and not is_instance_valid(on) and own.get_node_or_null(^"Mount") != null,
			"saddle: G alongside a wild horse, over onto its back (%s); G lets go (on foot: %s)" % [caught, p.riding == null])
	for a in w.animals():
		a.set_active(true)


func _carcass() -> void:
	var h := _horses()[0]
	for a in w.animals():
		a.set_active(a == h)
	p.global_position = _on(h.global_position + h.global_basis.x * 3.0)
	h.apply_hit(5000.0, h.global_position + Vector3.UP * 1.0, Vector3.RIGHT, p, "body")
	var dead := h.is_dead()
	await _secs(1.5)
	var roll := rad_to_deg(acos(clampf(h._visual.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
	var inv := InventoryState.from_player(p)
	var before := {}
	for k in ["rawhide", "venison", "sinew", "tallow", "brains"]:
		before[k] = inv.pack_count(k)
	h.set_meta("died_at", -100.0)
	var prompt := h.interact_prompt(p)
	h.finish_dress("skin", p)
	h.finish_dress("butcher", p)
	inv = InventoryState.from_player(p)
	var got := {}
	for k in before:
		got[k] = inv.pack_count(k) - int(before[k])
	_expect(dead and roll > 80.0 and prompt.begins_with("Skin the wild"), "carcass: dead, over on its side (%.0f deg); \"%s\"" % [roll, prompt])
	_expect(int(got.rawhide) == 2 and int(got.venison) >= 7 and int(got.sinew) == 3 and int(got.tallow) == 2 and int(got.brains) == 1,
			"carcass: rawhide, then venison, sinew, tallow and the brains (%s)" % str(got))
