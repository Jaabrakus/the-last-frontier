extends SceneTree
## Wildlife (scripts/wildlife) in the real level, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_wildlife.gd -- wildlife=on
##
## Stocking (every species, the range herd at the lane's end, on the ground, awake near the player), prey flight
## (a gunshot; the herd runs together and gets away), a vitals shot (the deer drops, the carcass is skinned with
## the interactor's hook and the pack gets the venison and the hide), a wound (it bleeds, leaves drops and dies),
## wolves (they stalk, close in and bite a player outside the fort; a lit fire keeps them off). Ends with
## "WILDLIFE TEST PASSED <n>" or "WILDLIFE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var player: FrontierPlayer
var shot_at := Vector3.ZERO
var range_herd: WildGroup


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## Physics runs at 120 Hz in this project (a "60 frame" wait is half a second).
func seconds(t: float) -> void:
	await frames(int(t * Engine.physics_ticks_per_second))


func _run() -> void:
	for i in 10:
		await process_frame
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	player = current_scene.get_node("Player") as FrontierPlayer
	check(w != null, "the level has a Wildlife node (wildlife=on)")
	if w == null:
		_end()
		return
	await seconds(1.0)
	# --- stocking
	var by := {}
	for a in w.animals():
		by[a.species] = int(by.get(a.species, 0)) + 1
	for sp in ["deer", "stag", "fox", "wolf"]:
		check(int(by.get(sp, 0)) > 0, "stocked: %s" % sp)
	# the wolf pack waits far off until its own section (it hunts a player it sees at dusk)
	var pack := w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf")
	for a: WildAnimal in pack:
		var q := Vector3(285.0 - randf() * 6.0, 0.0, 285.0 - randf() * 6.0)
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.awareness = 0.0
	var lane := w.animals().filter(func(a: WildAnimal) -> bool: return a.global_position.distance_to(WildlifeSpawner.RANGE_HERD_HOME) < 15.0)
	check(lane.size() >= 3, "the range herd grazes at the lane's end (%d)" % lane.size())
	var bad_y := 0
	for a in w.animals():
		if absf(a.global_position.y - FrontierTerrain.height_at(a.global_position.x, a.global_position.z)) > 0.6:
			bad_y += 1
	check(bad_y == 0, "every animal stands on the ground (%d off)" % bad_y)
	# --- a gunshot: the range herd bolts together and gets away from the shot
	player.global_position = Vector3(0, FrontierTerrain.height_at(0, -120) + 0.1, -120)
	await seconds(0.5)
	var herd: Array = lane
	var start := {}
	for a: WildAnimal in herd:
		start[a] = a.global_position.distance_to(player.global_position)
	var aw_before := {}
	for a: WildAnimal in pack:
		aw_before[a] = a.awareness
	w.shot(player.global_position, WildlifeSpawner.SHOT_LOUD_M)
	shot_at = player.global_position
	range_herd = (w.groups[0].group as WildGroup)
	var called := 0
	for a: WildAnimal in pack:
		if a.awareness >= 0.5 and float(aw_before[a]) < 0.5:
			called += 1
	check(called == 0, "a shot at dusk does not call the wolves in (%d woke)" % called)
	await seconds(0.3)
	var fleeing := herd.filter(func(a: WildAnimal) -> bool: return a.state == WildAnimal.State.FLEE).size()
	check(fleeing == herd.size(), "the whole herd bolts at the shot (%d/%d)" % [fleeing, herd.size()])
	await seconds(4.0)
	var gained := 0
	for a: WildAnimal in herd:
		if a.global_position.distance_to(player.global_position) > float(start[a]) + 15.0:
			gained += 1
	check(gained >= herd.size() - 1, "the herd runs away from the shot (%d/%d gained 15 m in 4 s)" % [gained, herd.size()])
	# --- a vitals shot: the deer drops; skinning fills the pack
	var deer := _nearest("deer")
	check(deer != null, "a deer to shoot")
	if deer:
		deer.set_active(true)
		var zone: StaticBody3D = deer.get_node("Hit_vitals")
		check(zone != null and zone.get_meta("hit_part") == "vitals", "the deer has a vitals zone")
		Hit.deliver(zone, 120.0, zone.global_position, Vector3(0, 0, -1), player)
		check(deer.is_dead(), "a musket ball in the vitals kills (health %.0f)" % deer.health)
		check(deer.is_in_group(PlacedWeapon.GROUP), "the carcass is an interactable")
		await seconds(1.3)
		check(deer.interact_prompt(player) == "Skin the deer", "prompt: Skin the deer ('%s')" % deer.interact_prompt(player))
		var fd := w.dressing
		check(fd != null and fd.has_knife(), "the player starts with a skinning knife")
		# skin: the player kneels over it while the bar fills
		player.global_position = deer.global_position + Vector3(1.2, 0.3, 0)
		await seconds(0.3)
		deer.interact(player)
		check(fd.working and player.kneeling == fd, "E starts skinning: the player kneels")
		await seconds(0.5)
		check(deer.interact_prompt(player) == "Stop", "while working the prompt is Stop ('%s')" % deer.interact_prompt(player))
		var hide0 := _pack_count("deer_hide")
		await seconds(float(deer.data.skin_s) + 1.5)
		check(_pack_count("deer_hide") == hide0 + 1, "skinning gives the deer hide")
		check(deer.dress_step == 1, "the carcass is skinned")
		await seconds(2.0)
		check(not fd.working and player.kneeling == null, "the player gets up after the work")
		check(deer.interact_prompt(player) == "Butcher the deer", "then: Butcher the deer ('%s')" % deer.interact_prompt(player))
		# butcher, stopped half way by moving: the progress is kept
		deer.interact(player)
		await seconds(1.5 + float(deer.data.butcher_s) * 0.4)
		Input.action_press("move_forward")
		await seconds(0.2)
		Input.action_release("move_forward")
		await seconds(2.0)
		check(not fd.working and player.kneeling == null, "moving stops the work")
		check(deer.dress_progress > 0.1 and deer.dress_progress < 0.9, "the progress is kept (%.2f)" % deer.dress_progress)
		check(deer.interact_prompt(player).begins_with("Butcher the deer ("), "the prompt shows it ('%s')" % deer.interact_prompt(player))
		var ven0 := _pack_count("venison")
		deer.interact(player)
		await seconds(1.5 + float(deer.data.butcher_s) + 1.0)
		check(_pack_count("venison") == ven0 + 4, "butchering gives 4 venison (%d)" % (_pack_count("venison") - ven0))
		check(not is_instance_valid(deer) or deer.interact_prompt(player) == "", "nothing left to take")
		await seconds(3.0)
		check(is_instance_valid(deer) and deer.meat_left <= WildAnimal.REMAINS_MEAT + 0.001 and deer.is_in_group(&"carcasses"),
				"the butchered remains stay for the scavengers (meat %.2f)" % (deer.meat_left if is_instance_valid(deer) else -1.0))
		# no knife: it cannot be skinned
		var other := _nearest("deer")
		if other:
			var z2: StaticBody3D = other.get_node("Hit_vitals")
			Hit.deliver(z2, 150.0, z2.global_position, Vector3(0, 0, -1), player)
			await seconds(1.3)
			var inv := InventoryState.from_player(player)
			inv.take(FieldDressing.KNIFE, 9)
			player.inventory_pack = inv.pack.duplicate(true)
			check(not fd.has_knife(), "the knife is out of the pack")
			check(other.interact_prompt(player).ends_with("(needs a knife)"), "without a knife: needs a knife ('%s')" % other.interact_prompt(player))
			other.interact(player)
			check(not fd.working, "no knife, no skinning")
			inv = InventoryState.from_player(player)
			inv.add(FieldDressing.KNIFE, 1)
			player.inventory_pack = inv.pack.duplicate(true)
	# --- a wound: it bleeds out, leaving a trail
	var hurt := _nearest("deer")
	if hurt:
		hurt.set_active(true)
		var drops0 := w._drops.size()
		Hit.deliver(hurt, 55.0, hurt.global_position + Vector3.UP * 0.6, Vector3(1, 0, 0), player)
		check(not hurt.is_dead() and hurt.state == WildAnimal.State.FLEE, "a wounded deer runs")
		var t := 0
		var hz := Engine.physics_ticks_per_second
		while t < hz * 90 and not hurt.is_dead():
			await physics_frame
			t += 1
		check(hurt.is_dead(), "the wounded deer bleeds out (%.0f s)" % (float(t) / hz))
		check(w._drops.size() > drops0 + 5, "it leaves a blood trail (%d drops)" % (w._drops.size() - drops0))
	# --- wolves: a player outside the fort at the golden hour is stalked and bitten
	var wolves := w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf" and not a.is_dead())
	check(wolves.size() >= 3, "a wolf pack (%d)" % wolves.size())
	if wolves.size() > 0:
		if player.is_dead:
			player.respawn()
		var spot := Vector3(90, 0, 90)
		spot.y = FrontierTerrain.height_at(spot.x, spot.z) + 0.1
		player.global_position = spot
		player.health = player.max_health
		var i := 0
		for a: WildAnimal in wolves:
			var p := Vector3(spot.x + 18.0 + i * 2.0, 0, spot.z + 6.0 * i)
			a.global_position = Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + 0.02, p.z)
			a.set_active(true)
			a.awareness = 1.0
			a.threat_pos = spot
			i += 1
		var stalked := false
		var t := 0
		var hz := Engine.physics_ticks_per_second
		while t < hz * 40 and player.health >= player.max_health:
			await physics_frame
			t += 1
			for a: WildAnimal in wolves:
				if a.state in [WildAnimal.State.STALK, WildAnimal.State.CHASE]:
					stalked = true
		if not stalked:
			for a: WildAnimal in wolves:
				print("    wolf ", a.name, " state=", WildAnimal.State.keys()[a.state], " aw=", snappedf(a.awareness, 0.01), " d=", snappedf(a.global_position.distance_to(player.global_position), 0.1), " active=", a.active, " losses=", a.group.losses)
		check(stalked, "the wolves stalk and chase")
		check(player.health < player.max_health, "a wolf bites the player (health %.0f after %.0f s)" % [player.health, float(t) / hz])
		# a lit fire at the player: the pack keeps off (the bite's bleeding closed first: PlayerWounds)
		player.health = player.max_health
		if player.wounds:
			player.wounds.clear()
		if player.is_dead:
			player.respawn()
		var fire_node := Node3D.new()
		current_scene.add_child(fire_node)
		fire_node.global_position = player.global_position + Vector3.UP * 0.5
		var tf := TorchFire.new()
		fire_node.add_child(tf)
		await seconds(3.0)       # the pack breaks off and backs away from the fire
		player.health = player.max_health
		if player.wounds:
			player.wounds.clear()
		var closest := INF
		for k in Engine.physics_ticks_per_second * 10:
			await physics_frame
			for a: WildAnimal in wolves:
				if is_instance_valid(a) and not a.is_dead():
					closest = minf(closest, a.global_position.distance_to(player.global_position))
		check(closest > 5.0, "a lit fire keeps the wolves off (closest %.1f m)" % closest)
		check(player.health >= player.max_health - 0.1, "no bites by the fire (health %.0f)" % player.health)
		fire_node.queue_free()
	await _brains()
	_end()


## The brains: herd roles, a routine (feed in the open, bed in cover), memory of danger, the food chain (a hungry pack
## runs down a wounded deer and eats it), the ravens at the kill, the calls.
func _brains() -> void:
	if player.is_dead:
		player.respawn()
	player.health = player.max_health
	var herd: WildGroup = null
	for e: Dictionary in w.groups:
		var g: WildGroup = e.group
		if e.kind == "deer_herd" and g != range_herd and g.alive().size() >= 3:
			herd = g
			break
	check(herd != null, "a deer herd of three or more for the brain checks")
	if herd == null:
		return
	# the player well off to the side, still: the herd goes about its day
	var hc := herd.centroid()
	var side := hc + (hc - Vector3.ZERO).normalized().cross(Vector3.UP) * 95.0
	player.global_position = Vector3(side.x, FrontierTerrain.height_at(side.x, side.z) + 0.1, side.z)
	for m in herd.alive():
		m.awareness = 0.0
	herd.alarm_time = -1e9
	await seconds(8.0)
	check(herd.leader() != null and herd.leader().species == "deer", "the herd has a leading doe")
	check(herd.activity == WildGroup.Activity.FEED and herd.dest_set, "it feeds at a chosen place (%s)" % WildGroup.Activity.keys()[herd.activity])
	check(herd.sentry != null and herd.alive().has(herd.sentry), "one of it stands sentry while it feeds")
	var feed_cover := w.cover(herd.dest.x, herd.dest.z)
	# tired: it goes to bed down in cover
	w.time_scale = 20.0
	for m in herd.alive():
		m.fatigue = 0.95
		m.hunger = 0.0
	herd.activity_since = -1e9
	await seconds(3.0)
	check(herd.activity == WildGroup.Activity.BED, "tired, the herd goes to bed down (%s)" % WildGroup.Activity.keys()[herd.activity])
	var bed_cover := w.cover(herd.dest.x, herd.dest.z)
	check(bed_cover > feed_cover + 0.1, "its bed is in thicker cover than its pasture (%.2f vs %.2f)" % [bed_cover, feed_cover])
	var rested := false
	for k in 60:
		await seconds(1.0)
		# (fed and tired all the way there: at twenty times the clock a walk of 40 m or more to the bed, from a pasture
		# the forage decides, would make them hungry again before they lie down)
		for m in herd.alive():
			m.hunger = 0.0
			m.fatigue = maxf(m.fatigue, 0.95)
			if m.state == WildAnimal.State.REST:
				rested = true
		if rested:
			break
	check(rested, "they lie up there (REST)")
	w.time_scale = 1.0
	# memory
	if range_herd:
		check(range_herd.danger_at(shot_at, w.now) > 0.3, "the range herd remembers where the shot came from (%.2f)" % range_herd.danger_at(shot_at, w.now))
		check(range_herd.nerves(w.now) > 1.05, "and is jumpier for it (%.2f)" % range_herd.nerves(w.now))
	# the food chain: a hungry pack and a wounded deer
	var pack: WildGroup = null
	for e: Dictionary in w.groups:
		if e.kind == "wolf_pack" and (e.group as WildGroup).alive().size() >= 2:
			pack = e.group
	check(pack != null, "a wolf pack for the food chain")
	var victim: WildAnimal = null
	for m in herd.alive():
		if not herd.is_leader(m):
			victim = m
	if pack == null or victim == null:
		return
	pack.losses = 0
	var vp := victim.global_position
	var i := 0
	for m in pack.alive():
		var q := vp + Vector3(45.0 + i * 3.0, 0.0, 8.0 * i)
		m.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		m.hunger = 1.0
		m.awareness = 0.0
		m.health = float(m.data.health)
		m.set_active(true)
		i += 1
	pack.activity = WildGroup.Activity.PATROL
	pack.prey = null
	pack.dest_set = false
	victim.apply_hit(60.0, victim.global_position + Vector3.UP * 0.6, Vector3(1, 0, 0), null, "body")
	var chased := false
	var ate := false
	var meat0 := -1.0
	for k in 150:
		await seconds(1.0)
		for m in pack.alive():
			if m.state == WildAnimal.State.CHASE:
				chased = true
		if pack.activity == WildGroup.Activity.EAT and is_instance_valid(pack.carcass):
			if meat0 < 0.0:
				meat0 = pack.carcass.meat_left
			elif pack.carcass.meat_left < meat0 - 0.01:
				ate = true
				break
	check(chased, "the hungry pack runs the deer down")
	check(victim.is_dead(), "the deer is down (%s)" % (victim.killed_by if victim.is_dead() else "alive"))
	check(ate, "the pack eats it (meat %.2f -> %.2f)" % [meat0, pack.carcass.meat_left if is_instance_valid(pack.carcass) else -1.0])
	# ravens come to the kill
	var carcass := victim
	var ravens := 0
	for k in 90:
		await seconds(1.0)
		ravens = 0
		for r in get_nodes_in_group(&"ravens"):
			if (r as Raven).carcass == carcass:
				ravens += 1
		if ravens >= 2:
			break
	check(ravens >= 1, "ravens come to the kill (%d)" % ravens)
	var calls := {}
	for e: Array in w.sound_log:
		calls[e[0]] = int(calls.get(e[0], 0)) + 1
	check(calls.has("wild_rec_wolf_chorus"), "the wolves howl (%s)" % str(calls))
	for k in 30:
		if calls.has("wild_rec_raven_call"):
			break
		await seconds(1.0)
		for e: Array in w.sound_log:
			calls[e[0]] = int(calls.get(e[0], 0)) + 1
	check(calls.has("wild_rec_raven_call"), "the ravens call")
	# the player walks up: the ravens take off
	if ravens > 0 and is_instance_valid(carcass):
		for k in 40:
			var there := false
			for r in get_nodes_in_group(&"ravens"):
				if (r as Raven).carcass == carcass and (r as Raven).mode in [Raven.Mode.CIRCLE, Raven.Mode.LAND, Raven.Mode.PECK]:
					there = true
			if there:
				break
			await seconds(1.0)
		var cp := carcass.global_position + Vector3(4.0, 0.0, 0.0)
		player.global_position = Vector3(cp.x, FrontierTerrain.height_at(cp.x, cp.z) + 0.1, cp.z)
		await seconds(1.5)
		var up := 0
		for r in get_nodes_in_group(&"ravens"):
			if (r as Raven).carcass == carcass and (r as Raven).mode == Raven.Mode.FLEE:
				up += 1
		check(up >= 1, "the ravens take off when the player comes close (%d)" % up)


func _nearest(sp: String) -> WildAnimal:
	var best: WildAnimal = null
	var bd := INF
	for a in w.animals():
		if a.species == sp and not a.is_dead():
			var d := a.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = a
	return best


func _pack_count(kind: String) -> int:
	var n := 0
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == kind:
			n += int(e.get("count", 0))
	return n


func _end() -> void:
	if fails.is_empty():
		print("WILDLIFE TEST PASSED %d" % checks)
	else:
		print("WILDLIFE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
