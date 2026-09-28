class_name WildPlanner
extends RefCounted
## The animals' planning brain (user 2026-09-26: "lets do the real brains thing ... routines memory herd roles and food
## chain"): a small utility AI run for each group once a second (WildlifeSpawner). It scores what the group needs and
## sets its activity and destination (WildGroup); the members carry it out (WildAnimal).
##
##   herd    FEED (hunger, more at dawn and dusk) against BED (fatigue, more at midday and when the herd is jumpy after
##           danger); feeding places are open ground, bedding places thick cover (or the open: WildlifeSpecies "beds"),
##           both chosen away from the places the herd remembers danger (WildlifeSpawner.find_place). A change needs a
##           clear margin (no dithering). The brain is the species' (WildlifeSpecies "brain": herd, pack, fox).
##   pack    TRACK a wounded animal's blood when the land is short of deer (below), EAT a carcass it finds (free meat,
##           when hungry), else HUNT a herd when hungry and it is dusk, night or dawn (or when very hungry), the prey
##           picked by WildlifeSpawner.pick_prey (the nearest, the wounded first); a kill becomes the pack's carcass. Else
##           BED by day and PATROL its range at dusk / night. It howls at dusk, at night and after a meal (the recorded
##           chorus, WildlifeSpawner.sound).
##   fox     EAT at a carcass when no wolf is at it and the player is not near; else FEED (mousing) in the open, BED by
##           day when tired.

const HOWL_EVERY := Vector2(200.0, 420.0)
## Hungry for want of deer (WildlifeEcology.wolf_hunger over DRIFT_HUNGER), a pack's range creeps toward the fort at
## DRIFT_MPS, no nearer than FORT_RANGE m from its middle (20 m outside its clearing, WildlifeSpawner.FORT_CLEAR: the
## people, their stock, their scraps); fed again, back.
const DRIFT_HUNGER := 0.4
const DRIFT_MPS := 0.5
const FORT_RANGE := 80.0
## Blood trails (user 2026-09-27: "wolves shouldnt steal if deer life is abundent if food sources are scares then it hunts
## and tracks", "also wolves will protect the kill try to hunt me"). The land short of deer (WildlifeEcology.wolf_hunger
## TRACK_HUNGER or more), a hungry pack that crosses a wounded animal's fresh blood (a member within
## WildAnimal.BLOOD_SMELL_R of a drop no older than BLOOD_FRESH_S) follows it (TRACK) at a trot, the leader to the newest
## drop within TRACK_SCENT_M of it (the scent lost TRACK_LOST_S, it gives up). Up with the animal (TRACK_SEE_M): alive,
## they hunt it (HUNT: the chase, the pull-down); dead, it is their kill (EAT), guarded (WildAnimal._predator: the player
## within 12 m of it is set on). The player at it (KILL_GUARD_M): hungry, they wait off it (TRACK_WAIT_S at most) till he
## goes, then eat what he left; starving (STARVE_HUNGER), they take it and come for him. Its meat gone with him (butchered,
## or hauled off on a rope): starving, they come after him (AFTER_PLAYER_S, till they are fed); hungry, they give it up.
## Deer plenty, they leave his game alone (WildlifeSpawner.pick_prey / nearest_carcass) and take up no trail.
const TRACK_HUNGER := 0.4
const STARVE_HUNGER := 0.75
const TRACK_SCENT_M := 25.0
const TRACK_SEE_M := 30.0
const TRACK_LOST_S := 20.0
const TRACK_WAIT_S := 150.0
## Where they wait: this far off the kill, on its far side from him (inside TRACK_SEE_M: they keep it in view).
const TRACK_WAIT_M := 25.0
const KILL_GUARD_M := 20.0
const AFTER_PLAYER_S := 90.0
## A trail given up is not taken up again for this long (s).
const TRAIL_LEFT_S := 300.0


static func plan(g: WildGroup, sp: WildlifeSpawner) -> void:
	if g.alive().is_empty():
		return
	match WildlifeSpecies.brain(g.species):
		"pack":
			_pack(g, sp)
		"fox":
			_fox(g, sp)
		_:
			_herd(g, sp)
	g.update_sentry(sp.now, sp.rng_for(g.home))


## Mean hunger (x) and fatigue (y) of the living members.
static func needs(g: WildGroup) -> Vector2:
	var s := Vector2.ZERO
	var al := g.alive()
	for m in al:
		s += Vector2(m.hunger, m.fatigue)
	return s / maxf(al.size(), 1.0)


static func _assign(g: WildGroup, sp: WildlifeSpawner, act: WildGroup.Activity, dest: Vector3) -> void:
	if g.activity != act:
		g.activity = act
		g.activity_since = sp.now
	g.dest = dest
	g.dest_set = dest != Vector3.INF
	if not g.dest_set:
		g.dest = g.centroid()
		g.dest_set = true


# --- Herds ---------------------------------------------------------------------------------------

static func _herd(g: WildGroup, sp: WildlifeSpawner) -> void:
	var n := needs(g)
	var h := sp.hour()
	var dawn_dusk := 1.0 if (h >= 5.0 and h <= 9.0) or (h >= 16.0 and h <= 20.5) else 0.0
	var midday := 1.0 if h > 10.0 and h < 15.0 else 0.0
	var jumpy := g.nerves(sp.now) - 1.0
	var feed := n.x + 0.3 * dawn_dusk - 0.2 * jumpy
	var bed := n.y + 0.3 * midday + 0.4 * jumpy
	var want := WildGroup.Activity.FEED if feed >= bed else WildGroup.Activity.BED
	if want != g.activity and (sp.now - g.activity_since > 25.0 or absf(feed - bed) > 0.3):
		g.activity = want
		g.activity_since = sp.now
		g.dest_set = false
	if not g.dest_set:
		# (bedding where the species beds: thick cover, or the open for the plains' bison)
		var beds := String(WildlifeSpecies.get_data(g.species).get("beds", "cover"))
		_assign(g, sp, g.activity, sp.find_place(g, "open" if g.activity == WildGroup.Activity.FEED else beds))


# --- Wolves --------------------------------------------------------------------------------------

static func _pack(g: WildGroup, sp: WildlifeSpawner) -> void:
	var n := needs(g)
	var bold := sp.boldness()
	# fed, they want nothing more of him for the kill he took (WildAnimal.FED)
	if n.x < WildAnimal.FED:
		g.after_player_until = -1e9
	# a kill: the prey died (the pack pulled it down, or someone else did): eat it
	if g.activity == WildGroup.Activity.HUNT and g.prey != null and is_instance_valid(g.prey) and g.prey.is_dead():
		g.carcass = g.prey
		g.prey = null
		_assign(g, sp, WildGroup.Activity.EAT, g.carcass.global_position)
		return
	# eating: go on while there is meat and hunger; then a howl and a rest near by
	if g.activity == WildGroup.Activity.EAT:
		if g.carcass != null and is_instance_valid(g.carcass) and g.carcass.meat_left > 0.05 and n.x > 0.05:
			return
		g.carcass = null
		if sp.sun_elevation() < 25.0:
			_howl(g, sp)
		_assign(g, sp, WildGroup.Activity.BED, sp.find_place(g, "cover"))
		return
	# hunting: on while the prey lives and the hunt is young
	if g.activity == WildGroup.Activity.HUNT and g.prey != null and is_instance_valid(g.prey) and sp.now - g.activity_since < 90.0:
		g.dest = g.prey.global_position
		return
	if g.activity == WildGroup.Activity.HUNT:
		g.prey = null
	# after the player for the kill he took: on his heels till it wears off (WildAnimal._predator hunts him)
	if sp.now < g.after_player_until and sp.player != null and not sp.player.is_dead:
		_assign(g, sp, WildGroup.Activity.PATROL, sp.player.global_position)
		return
	# a blood trail: on it while it holds; else one crossed, the land short of deer
	if g.activity == WildGroup.Activity.TRACK:
		if _track(g, sp):
			return
		if is_instance_valid(g.trail_of):
			g.trails_left[g.trail_of.get_instance_id()] = sp.now + TRAIL_LEFT_S
		g.trail_of = null
		g.trail_wait = -1.0
		g.dest_set = false
		g.activity = WildGroup.Activity.PATROL
	elif n.x > 0.35 and sp.ecology.wolf_hunger() >= TRACK_HUNGER and not g.is_routed(sp.now):
		var at: Array = []
		for m in g.alive():
			at.append(m.global_position)
		for id in g.trails_left.keys():
			if sp.now > float(g.trails_left[id]):
				g.trails_left.erase(id)
		var b := sp.fresh_trail(at, WildAnimal.BLOOD_SMELL_R, WildAnimal.BLOOD_FRESH_S, g.trails_left)
		if not b.is_empty():
			g.trail_of = b.who
			g.trail_seen = sp.now
			g.trail_wait = -1.0
			_assign(g, sp, WildGroup.Activity.TRACK, b.pos)
			return
	# hungry: free meat first, then a hunt
	if n.x > 0.35:
		var c := sp.nearest_carcass(g.centroid(), 300.0, "wolf")
		if c != null:
			g.carcass = c
			_assign(g, sp, WildGroup.Activity.EAT, c.global_position)
			return
	if n.x > 0.55 and (bold > 0.6 or n.x > 0.85):
		var prey := sp.pick_prey(g.centroid(), 350.0)
		if prey != null:
			g.prey = prey
			g.hunt_since = sp.now
			_assign(g, sp, WildGroup.Activity.HUNT, prey.global_position)
			return
	_drift(g, sp)
	# rest by day (or tired), patrol the range at dusk / night
	var want := WildGroup.Activity.BED if bold < 0.6 or n.y > 0.7 else WildGroup.Activity.PATROL
	var arrived := g.dest_set and g.centroid().distance_to(g.dest) < 12.0
	if want != g.activity or not g.dest_set or (want == WildGroup.Activity.PATROL and arrived and sp.now - g.activity_since > 40.0):
		_assign(g, sp, want, sp.find_place(g, "cover" if want == WildGroup.Activity.BED else "any"))
		g.activity_since = sp.now
	# (hungry, they howl more: up to twice as often)
	if sp.sun_elevation() < 25.0 and sp.now - g.last_howl > sp.rng_for(g.home).randf_range(HOWL_EVERY.x, HOWL_EVERY.y) \
			* (1.0 - 0.5 * sp.ecology.wolf_hunger()):
		_howl(g, sp)


## On the blood trail (TRACK): whether the pack keeps to it (false: it gives it up).
static func _track(g: WildGroup, sp: WildlifeSpawner) -> bool:
	var who := g.trail_of
	var lead := g.leader()
	if who == null or not is_instance_valid(who) or who.is_queued_for_deletion() or lead == null:
		return false
	var at := lead.global_position
	if not who.is_dead():
		if at.distance_to(who.global_position) < TRACK_SEE_M:
			# up with it: the hunt (the chase, the pull-down)
			g.trail_of = null
			g.prey = who
			g.hunt_since = sp.now
			_assign(g, sp, WildGroup.Activity.HUNT, who.global_position)
			return true
	else:
		var end := sp.trail_end(who)
		var at_end := end.is_empty() or at.distance_to(end.pos as Vector3) < 8.0
		if at.distance_to(who.global_position) < TRACK_SEE_M or at_end:
			return _found_kill(g, sp, who)
	# on along the trail
	var b := sp.trail_ahead(who, at, TRACK_SCENT_M, WildAnimal.BLOOD_FRESH_S)
	if not b.is_empty():
		g.trail_seen = sp.now
		g.dest = b.pos
		g.dest_set = true
		return true
	return sp.now - g.trail_seen < TRACK_LOST_S


## The trail's end, the animal dead: the pack's kill, or the player's to wait him out for or come after him for.
static func _found_kill(g: WildGroup, sp: WildlifeSpawner, who: WildAnimal) -> bool:
	var p := sp.player
	var starving := sp.ecology.wolf_hunger() >= STARVE_HUNGER
	var here := g.leader().global_position.distance_to(who.global_position) < TRACK_SEE_M
	var roped: bool = who.get_meta(&"on_chain", false)
	var meat: bool = here and not roped and who.meat_left > 0.1 and not who.get_meta("bones", false)
	var him := p != null and not p.is_dead
	var he_is_at := him and p.global_position.distance_to(who.global_position) < KILL_GUARD_M
	# its meat gone with him: butchered (in his pack) or on his horse's rope (or moved off, not where the trail ends)
	var taken := him and who.killed_by == "player" and (who.dress_step >= 2 or roped or not here)
	if taken and starving and not he_is_at:
		g.after_player_until = sp.now + AFTER_PLAYER_S
		g.trail_of = null
		_assign(g, sp, WildGroup.Activity.PATROL, p.global_position)
		return true
	if not meat:
		return false
	if he_is_at and not starving:
		# his: off it, on the far side, till he goes
		if g.trail_wait < 0.0:
			g.trail_wait = sp.now
		if sp.now - g.trail_wait > TRACK_WAIT_S:
			return false
		var off := who.global_position - p.global_position
		off.y = 0.0
		off = off.normalized() if off.length_squared() > 0.01 else Vector3.FORWARD
		var wait := who.global_position + off * TRACK_WAIT_M
		g.dest = Vector3(wait.x, FrontierTerrain.height_at(wait.x, wait.z), wait.z)
		g.dest_set = true
		return true
	# theirs (starving, with him at it: they turn on him, WildAnimal._predator)
	if he_is_at:
		g.after_player_until = sp.now + AFTER_PLAYER_S
	g.trail_of = null
	g.trail_wait = -1.0
	g.carcass = who
	_assign(g, sp, WildGroup.Activity.EAT, who.global_position)
	return true


## The pack's range with its hunger (once a plan: a second): toward the fort while the land is short of deer, back to
## where it was when not.
static func _drift(g: WildGroup, sp: WildlifeSpawner) -> void:
	if g.home0 == Vector3.INF:
		g.home0 = g.home
	var target := g.home0
	if sp.ecology.wolf_hunger() > DRIFT_HUNGER:
		var out := Vector3(g.home0.x, 0.0, g.home0.z)
		target = out.normalized() * minf(FORT_RANGE, out.length()) if out.length() > 0.1 else g.home0
	var flat := Vector3(g.home.x, 0.0, g.home.z).move_toward(Vector3(target.x, 0.0, target.z), DRIFT_MPS)
	g.home = Vector3(flat.x, g.home.y, flat.z)


static func _howl(g: WildGroup, sp: WildlifeSpawner) -> void:
	g.last_howl = sp.now
	sp.sound(&"wild_rec_wolf_chorus", g.centroid() + Vector3.UP * 0.8)


# --- Foxes ---------------------------------------------------------------------------------------

static func _fox(g: WildGroup, sp: WildlifeSpawner) -> void:
	var n := needs(g)
	if g.activity == WildGroup.Activity.EAT:
		if g.carcass != null and is_instance_valid(g.carcass) and g.carcass.meat_left > 0.05 and n.x > 0.05 \
				and sp.safe_for_fox(g.carcass):
			return
		g.carcass = null
		g.dest_set = false
		g.activity = WildGroup.Activity.FEED
	if n.x > 0.3:
		var c := sp.nearest_carcass(g.centroid(), 180.0, "fox")
		if c != null:
			g.carcass = c
			_assign(g, sp, WildGroup.Activity.EAT, c.global_position)
			return
	var want := WildGroup.Activity.BED if sp.sun_elevation() > 25.0 and n.y > 0.5 else WildGroup.Activity.FEED
	if want != g.activity or not g.dest_set:
		_assign(g, sp, want, sp.find_place(g, "cover" if want == WildGroup.Activity.BED else "open"))
