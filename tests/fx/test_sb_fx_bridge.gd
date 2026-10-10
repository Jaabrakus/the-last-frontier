extends SceneTree
## The Spellbreak effects bridge (SbFx, scripts/fx/cascade/sb_fx.gd; data/bending/sb_fx), headless (SbFx.allow_headless: the
## Cascade runtime simulates without a window; nothing is drawn):
##   data        config.json and the four element files load; every entry names an imported effect, a known seam role, a
##               placement the bridge knows (at, orient, follow_basis) and numbers where numbers go; every key's move is
##               a move of moves.json (or a passive / shared row); every hide_materials material and every entry's hide
##               name exists in some imported effect; every "unwired" row says why
##   dormant     the shipped switches as config.json has them (no force): every element switched off there resolves and
##               plays nothing (and makes no player), and the prewarm list leaves its effects out; a missing or unreadable
##               config.json switches nothing on
##   resolve     a move's own element's table; patch and mend by the caster's (earth 86, fire 843); ".grown" falls back to
##               the move's roles it does not override; the switches: an element off and the master off play nothing
## From "resolve" on, every element is forced on (SbFx.force_on, force_elements): the bridge's own logic is tested whatever
## config.json's switches say (the owner switched every element off on 2026-10-09).
##   bolts       a fire punch's bolt plays its flight (the old body not made when the flight replaces it, made when the
##               switch is off) and its impact; the same flight, on and off, ends on the same frame at the same place
##               (visual only: gameplay unchanged); a volley plays volley_max flights
##   zones       a fire wall's zone holds its effect (three across the wall) until it ends, then lets it go
##   held        a grow at the hands holds an anchor under the caster until stopped; a dash's trails stop at its end and its
##               end plays
##   prewarm     every listed effect built and parked (SpellFx idle pool); a camera freed meanwhile ends it without an error
##   dice        the effects draw their randomness from CascadeFx.rng only, never the game's global RNG (a caster's rolls
##               stay the same under a test's seed whether the effects play or not)
##   lifecycle   everything played ends: nothing playing, no orphan nodes left, the scene's node count back to its start
## Last line "SB FX BRIDGE PASSED" or "SB FX BRIDGE FAILED"; exit 0 only on a pass.
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_sb_fx_bridge.gd

const NAME := "SB FX BRIDGE"
const WATCHDOG_S := 240.0
const ROLES := ["cast", "flight", "wave", "trail", "curve", "impact", "body_extra", "hit_body", "swing", "zone", "zone_start",
		"zone_end", "deflect", "put_out", "blown", "entry", "doused", "melted", "cushion", "held", "return_flight", "perfect",
		"late", "whiff", "rise", "stand", "hit", "crumble", "shatter", "melt", "hang", "land", "roll", "drop", "clash", "dash",
		"dash_trail", "dash_flames", "dash_end", "grow", "grow_click", "charge", "idle", "take_hold", "slam", "slam_deck",
		"air_hit", "pop", "cone", "heal", "heal_pop", "mend", "throw", "low", "flash", "strike", "lightning_back", "kick_up",
		"launch", "air_trail", "ride", "ride_spray", "charged", "charge_pop"]
const ATS := ["hand", "chest", "feet", "caster", "node", "point", "ground"]
const ORIENTS := ["dir", "flat", "node", "normal", "normal_up", "up", "down", "world"]
const OWN_KEYS := ["rooted", "flowing", "passive/carried_wind", "patch/patch", "mend", "clash/stone", "stone_form/drop"]
## Every element forced on (the bridge's logic under test, whatever config.json's switches say).
const ALL_ON := {"earth": true, "water": true, "fire": true, "air": true}
## The four files held 152 entries when the tables were tuned (2026-10-09); fewer than this means one was emptied by accident.
const MIN_ENTRIES := 140

var checks := 0
var fails: Array[String] = []
var stage: Node3D
var cam: Camera3D
var fire_body: CharacterBody3D
var earth_body: CharacterBody3D


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	SbFx.allow_headless = false
	SbFx.force_on = null
	SbFx.force_elements = {}
	SbFx.log_plays = false
	BendLooks.build_headless = false
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	_data()
	_stage()
	_dormant()
	SbFx.force_on = true
	SbFx.force_elements = ALL_ON.duplicate()
	await _frames(3)
	var n0 := _count(stage)
	var orphans0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var kids0 := stage.get_children().map(func(n: Node) -> String: return String(n.name))
	_resolve()
	await _bolts()
	await _zones()
	await _held()
	await _prewarm()
	await _dice()
	await _lifecycle(n0, orphans0, kids0)
	_end()


# ---------------------------------------------------------------- data
func _data() -> void:
	var cfg := SbFx.config()
	_expect(bool(cfg.get("enabled", false)) and (cfg.get("elements", {}) as Dictionary).size() == 4,
			"config.json: the master switch on, one switch per element")
	var bad: Array[String] = []
	var entries := 0
	var mats_all := {}
	var names_all := {}
	for id in SpellFx.effect_ids():
		for em in SpellFx.spec(id).get("emitters", []):
			mats_all[String((em as Dictionary).get("material", ""))] = true
			names_all[String((em as Dictionary).get("name", ""))] = true
	for el: String in SbFx.ELEMENTS:
		var doc := SbFx._read(SbFx.DIR + el + ".json")
		_expect(String(doc.get("element", "")) == el and doc.get("moves") is Dictionary, "%s.json loads (element %s, moves)" % [el, el])
		for u in doc.get("unwired", []):
			if String((u as Dictionary).get("why", "")) == "":
				bad.append("%s unwired row with no why" % el)
		var t := SbFx.table(el)
		for key: String in t:
			var mv := key.get_slice("/", 0).get_slice(".", 0)
			if SwayMoves.move(mv).is_empty() and not key in OWN_KEYS and not key.begins_with("passive/"):
				bad.append("%s key %s: no move %s" % [el, key, mv])
			var roles: Dictionary = t[key]
			for r: String in roles:
				if r.begins_with("_"):
					continue
				var e: Variant = roles[r]
				entries += 1
				if not (e is Dictionary):
					bad.append("%s %s %s: not an entry" % [el, key, r])
					continue
				var d := e as Dictionary
				if not r in ROLES:
					bad.append("%s %s: unknown role %s" % [el, key, r])
				if not SpellFx.has_effect(String(d.get("effect", ""))):
					bad.append("%s %s %s: effect not imported %s" % [el, key, r, d.get("effect")])
				if not String(d.get("at", "point")) in ATS:
					bad.append("%s %s %s: at %s" % [el, key, r, d.get("at")])
				if not String(d.get("orient", "dir")) in ORIENTS:
					bad.append("%s %s %s: orient %s" % [el, key, r, d.get("orient")])
				if not String(d.get("follow_basis", "node")) in ["node", "fixed", "motion"]:
					bad.append("%s %s %s: follow_basis %s" % [el, key, r, d.get("follow_basis")])
				for k in ["offset", "rot"]:
					if d.has(k) and not (d[k] is Array and (d[k] as Array).size() == 3):
						bad.append("%s %s %s: %s not [x, y, z]" % [el, key, r, k])
				for k in ["scale", "life", "travel_s", "repeat_s", "fit_m", "body_scale"]:
					if d.has(k) and not (d[k] is float or d[k] is int):
						bad.append("%s %s %s: %s not a number" % [el, key, r, k])
				for h in d.get("hide", []):
					if not String(h).begins_with("#") and not names_all.has(String(h)):
						bad.append("%s %s %s: hide names no emitter %s" % [el, key, r, h])
	for m in cfg.get("hide_materials", []):
		if not mats_all.has(String(m)):
			bad.append("hide_materials: no imported effect uses %s" % m)
	for b in bad.slice(0, 20):
		print("    " + b)
	_expect(bad.is_empty(), "every entry valid (%d entries, %d problems)" % [entries, bad.size()])
	_expect(entries >= MIN_ENTRIES, "the four files hold the moves' roles (%d entries, at least %d)" % [entries, MIN_ENTRIES])


# ---------------------------------------------------------------- the stage
func _stage() -> void:
	stage = Node3D.new()
	stage.name = "SbFxStage"
	root.add_child(stage)
	current_scene = stage
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	ground.add_child(cs)
	stage.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	var wall := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var bx2 := BoxShape3D.new()
	bx2.size = Vector3(6, 4, 0.5)
	cs2.shape = bx2
	wall.add_child(cs2)
	wall.name = "TargetWall"
	stage.add_child(wall)
	wall.global_position = Vector3(0, 1.5, -12)
	fire_body = _body("fire", Vector3(0, 0, 0))
	earth_body = _body("earth", Vector3(4, 0, 0))


func _body(el: String, at: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.name = "Caster_" + el
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cs.shape = cap
	cs.position = Vector3.UP * 0.9
	b.add_child(cs)
	stage.add_child(b)
	b.global_position = at
	Bending.of(b).element = el
	return b


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


# ---------------------------------------------------------------- the shipped switches (dormant)
## config.json's own switches, nothing forced: an element switched off there plays nothing at any seam and its effects are
## not prewarmed (the shipped state: the owner turned every element off on 2026-10-09; this holds for any mix).
func _dormant() -> void:
	SbFx.force_on = null
	SbFx.force_elements = {}
	var cfg := SbFx.config()
	var master := bool(cfg.get("enabled", false))
	var off: Array[String] = []
	var on_els: Array[String] = []
	for el: String in SbFx.ELEMENTS:
		var el_on := master and bool((cfg.get("elements", {}) as Dictionary).get(el, false))
		_expect(SbFx.on(el) == el_on, "as shipped: %s is %s (config.json)" % [el, "on" if el_on else "off"])
		if el_on:
			on_els.append(el)
		else:
			off.append(el)
	_expect(SbFx.any_on() == (not on_els.is_empty()), "as shipped: any_on() says whether any element is on")
	var wanted := _named_effects(on_els)
	var ids := SbFx.ids()
	_expect(ids.size() == wanted.size() and Array(ids).all(func(id: String) -> bool: return wanted.has(id)),
			"as shipped: the prewarm lists only the switched-on elements' effects (%d listed, %d wanted; off: %s)" % [ids.size(), wanted.size(), off])
	SbFx.log_plays = true
	SbFx.plays.clear()
	var leaks: Array[String] = []
	var tried := 0
	for el: String in off:
		var body := fire_body if el == "fire" else earth_body
		var t := SbFx.table(el)
		for k: String in t:
			for r: String in t[k]:
				if r.begins_with("_"):
					continue
				tried += 1
				if SbFx.fire(body, k, r, {"at": Vector3(0, 1, -3), "el": el}) or not SbFx.resolve(body, k, r, el).is_empty():
					leaks.append("%s %s %s" % [el, k, r])
	for l in leaks.slice(0, 10):
		print("    plays while off: " + l)
	_expect(leaks.is_empty() and SbFx.plays.is_empty(),
			"as shipped: every role of the switched-off elements resolves and plays nothing (%d tried, %d played)" % [tried, SbFx.plays.size()])
	SbFx.log_plays = false
	if on_els.is_empty():
		var owner := Node.new()
		stage.add_child(owner)
		var kids0 := fire_body.get_child_count()
		var started := SbFx.start(owner, "s", fire_body, "fire_blast/punch.grown", "flight", {"node": owner})
		var sustained := SbFx.sustain(owner, "s2", fire_body, "rooted", "idle", {"el": "earth"}, 1.0, "take_hold")
		SbFx.dash_began(fire_body, "fire_jets/jets", Vector3.FORWARD, {})
		SbFx.watch_landing(fire_body, "fire_jets/jets", "air_trail", "land")
		_expect(not started and not sustained and not SbFx.holding(owner, "s") and stage.get_node_or_null("SpellFx") == null
				and fire_body.get_child_count() == kids0,
				"as shipped: start, sustain, dash_began and watch_landing hold nothing, make no player and add no node")
		owner.queue_free()
	# a missing or unreadable config.json switches nothing on (the shipped state is every element off, never "on by default")
	var shipped_cfg := SbFx._cfg
	SbFx._cfg = {}
	_expect(not SbFx.any_on() and not SbFx.on("fire") and SbFx.resolve(fire_body, "fire_blast/punch", "flight").is_empty()
			and not SbFx.fire(fire_body, "fire_blast/punch", "flight", {}), "no config.json: nothing is on, nothing resolves or plays")
	SbFx._cfg = shipped_cfg


## The effects (imported ones) the tables of `elements` name.
func _named_effects(elements: Array) -> Dictionary:
	var named := {}
	for el: String in elements:
		var t := SbFx.table(el)
		for k: String in t:
			for r: String in t[k]:
				var e: Variant = (t[k] as Dictionary)[r]
				if e is Dictionary and String((e as Dictionary).get("effect", "")) != "" and SpellFx.has_effect(String(e.effect)):
					named[String(e.effect)] = true
	return named


# ---------------------------------------------------------------- resolve and switches
func _resolve() -> void:
	var pe := SbFx.resolve(earth_body, "patch/patch", "heal")
	var pf := SbFx.resolve(fire_body, "patch/patch", "heal")
	_expect(String(pe.get("_el", "")) == "earth" and int(pe.get("map", 0)) == 86, "Patch by an earth caster: earth's (86)")
	_expect(String(pf.get("_el", "")) == "fire" and int(pf.get("map", 0)) == 843, "Patch by a fire caster: fire's (843)")
	var g := SbFx.resolve(fire_body, "fire_blast/punch.grown", "cast")
	_expect(int(g.get("map", 0)) == int(SbFx.resolve(fire_body, "fire_blast/punch", "cast").get("map", -1)) and not g.is_empty(),
			"the Fireball's cast falls back to the punch's (.grown keeps the roles it does not override)")
	_expect(roundi(float(SbFx.resolve(fire_body, "fire_blast/punch.grown", "flight").get("scale", 0.0)) * 10.0) == 17,
			"the Fireball's own flight (1.7x)")
	SbFx.force_elements = {"earth": true, "water": true, "fire": false, "air": true}
	_expect(SbFx.resolve(fire_body, "fire_blast/punch", "flight").is_empty() and not SbFx.resolve(earth_body, "stone_form/spike", "rise").is_empty(),
			"fire switched off: fire's moves resolve nothing, earth's still play")
	SbFx.force_elements = ALL_ON.duplicate()
	SbFx.force_on = false
	_expect(not SbFx.fire(fire_body, "fire_blast/punch", "cast", {}), "the master switch off: nothing plays (fire() false)")
	SbFx.force_on = true
	var mh := SbFx._hidden_by_material("g3/Content/VFX/Quests/Shared/SmkObscureM_FxP")
	_expect("#0" in mh and "#6" in mh, "hide_materials leaves SmkObscureM's Ring (#0) and shock sphere (#6) out")


# ---------------------------------------------------------------- bolts
func _punch_spec() -> Dictionary:
	return {"kind": "fire", "mps": 30.0, "range_m": 20.0, "radius_m": 0.2, "damage": 10.0,
			"_info": {"tag": "fire_blast/punch", "move": "fire_blast", "mode": "punch"}}


func _bodies_of(n: Node) -> int:
	var c := 0
	for k in n.find_children("*", "GeometryInstance3D", true, false):
		c += 1
	return c


func _bolts() -> void:
	SbFx.log_plays = true
	SbFx.plays.clear()
	BendLooks.build_headless = true                # (today's body is made headless too: whether the flight replaced it shows)
	var b := BendBolt.launch(fire_body, Vector3(0, 1.4, 0), Vector3.FORWARD, _punch_spec())
	var played := SbFx.plays.filter(func(p: Array) -> bool: return String(p[2]) == "flight")
	_expect(played.size() == 1 and int(SbFx.resolve(fire_body, "fire_blast/punch", "flight").get("map", 0)) == 112
			and String(played[0][3]).ends_with("Fireball_Base_Projectile01_FxP"), "the punch's bolt plays its flight (112)")
	_expect(_bodies_of(b) == 0, "the flight replaces today's body and trail: none made (%d drawn nodes)" % _bodies_of(b))
	var on_end := await _flight_end(b)
	_expect(SbFx.plays.any(func(p: Array) -> bool: return String(p[2]) == "impact"), "its hit plays its impact")
	SbFx.force_on = false
	var b2 := BendBolt.launch(fire_body, Vector3(0, 1.4, 0), Vector3.FORWARD, _punch_spec())
	_expect(_bodies_of(b2) > 0, "switched off: today's body made (%d drawn nodes)" % _bodies_of(b2))
	var off_end := await _flight_end(b2)
	SbFx.force_on = true
	BendLooks.build_headless = false
	print("    flight on: %s   off: %s" % [on_end, off_end])
	_expect(on_end[0] == off_end[0] and (on_end[1] as Vector3).distance_to(off_end[1]) < 1e-4 and on_end[2] == off_end[2],
			"gameplay unchanged: the same bolt ends on the same frame, at the same place, the same way, on or off")
	# a volley: volley_max flights
	SbFx.plays.clear()
	var vs := _punch_spec()
	vs["_info"] = {"tag": "fire_jab/embers", "move": "fire_jab", "mode": "embers", "volley_id": 99001, "volley_n": 7}
	vs["range_m"] = 3.0
	for i in 7:
		BendBolt.launch(fire_body, Vector3(0, 1.4, 0), Vector3.FORWARD.rotated(Vector3.UP, 0.05 * i), vs)
	var vmax := int(SbFx.resolve(fire_body, "fire_jab/embers", "flight").get("volley_max", 0))
	var vf := SbFx.plays.filter(func(p: Array) -> bool: return String(p[2]) == "flight").size()
	_expect(vmax > 0 and vf == vmax, "Embers' seven bolts play %d flights (volley_max %d)" % [vf, vmax])
	await _frames(40)
	SbFx.log_plays = false


## [physics frames until the bolt ended, where it was then, why]
func _flight_end(b: BendBolt) -> Array:
	var st := {"why": "", "at": Vector3.INF}
	b.ended.connect(func(w: String) -> void:
		st.why = w
		st.at = b.global_position)
	var n := 0
	while st.why == "" and n < 300:
		await physics_frame
		n += 1
	return [n, st.at, st.why]


# ---------------------------------------------------------------- zones
func _zones() -> void:
	var sp := SpellFx.of(stage)
	var before := sp.playing_count()
	var keep := BendR3.cur
	BendLooks.build_headless = true                # (a zone's look, and its Spellbreak effect, are made where looks are drawn)
	BendR3.cur = {"tag": "fire_wall/wall", "move": "fire_wall", "mode": "wall"}
	var z := BendZone.make(fire_body, "fire_wall", Vector3(0, 0, -5), {"width_m": 4.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 30.0},
			Vector3.BACK)
	BendR3.cur = keep
	var spread := int(SbFx.resolve(fire_body, "fire_wall/wall", "zone").get("spread", 1))
	_expect(SbFx.holding(z, "zone") and sp.playing_count() - before == spread,
			"a fire wall holds its zone effect (%d across it; %d playing)" % [spread, sp.playing_count() - before])
	await _frames(30)
	z.end()
	BendLooks.build_headless = false
	await _frames(2)
	_expect(not is_instance_valid(z) or not SbFx.holding(z, "zone"), "its end lets its effect go")
	_expect(not SbFx.holding(z, "zone"), "a freed owner reads as holding nothing (never an error)")


# ---------------------------------------------------------------- held effects
func _held() -> void:
	var owner := Node.new()
	stage.add_child(owner)
	var ok := SbFx.start(owner, "grow", fire_body, "fire_blast/punch.grown", "grow", {})
	var anchors := fire_body.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is SbFx.Anchor)
	_expect(ok and SbFx.holding(owner, "grow") and anchors.size() == 1, "a grow at the hands holds an anchor under the caster")
	SbFx.stop(owner)
	await _frames(240)
	var left := fire_body.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is SbFx.Anchor)
	_expect(not SbFx.holding(owner, "grow") and left.is_empty(), "stopped: the grow plays out and its anchor goes")
	owner.queue_free()
	SbFx.log_plays = true
	SbFx.plays.clear()
	SbFx.dash_began(fire_body, "fire_jets/jets", Vector3.FORWARD, {})
	_expect(SbFx.holding(fire_body, "dash") and SbFx.holding(fire_body, "dash2"), "Jets' dash holds its trail and its flames")
	await _frames(20)
	SbFx.dash_ended(fire_body)
	_expect(not SbFx.holding(fire_body, "dash") and SbFx.plays.any(func(p: Array) -> bool: return String(p[2]) == "dash_end"),
			"the dash's end stops them and plays its end")
	SbFx.log_plays = false


# ---------------------------------------------------------------- prewarm
func _prewarm() -> void:
	var ids := SbFx.ids()
	var named := _named_effects(SbFx.ELEMENTS)
	await SbFx.prewarm(cam)
	var sp := SpellFx.of(stage)
	var parked := 0
	for id in ids:
		if (sp._idle.get(id, []) as Array).any(func(f): return is_instance_valid(f)):
			parked += 1
	_expect(ids.size() == named.size() and not ids.is_empty() and parked == ids.size(),
			"prewarm builds and parks every listed effect (%d of %d; the tables name %d)" % [parked, ids.size(), named.size()])
	# a camera freed while it awaits: it ends without an error (the tail reads the camera only while it is valid). The pool
	# emptied first, so there is something to build and await.
	for id in sp._idle:
		for fx in sp._idle[id]:
			if is_instance_valid(fx):
				fx.free()
	sp._idle.clear()
	var cam2 := Camera3D.new()
	stage.add_child(cam2)
	var done := [false]
	var runner := func() -> void:
		await SbFx.prewarm(cam2)
		done[0] = true
	runner.call()
	await process_frame
	cam2.free()
	var guard := 0
	while not done[0] and guard < 600:
		await process_frame
		guard += 1
	_expect(done[0], "prewarm with its camera freed meanwhile still ends (%d frames)" % guard)


# ---------------------------------------------------------------- dice
## (CascadeFx rolls its own RandomNumberGenerator, CascadeFx.rng: playing an effect never moves the global RNG the game's
## rolls use (PlayerBendCaster's spread, a bot's pick))
func _dice() -> void:
	seed(99)
	var base := [randi(), randi()]
	seed(99)
	var st := CascadeFx.rng.state
	SbFx.log_plays = true
	SbFx.plays.clear()
	SbFx.fire(fire_body, "fire_blast/punch", "cast", {"dir": Vector3.FORWARD})
	SbFx.fire(fire_body, "fire_blast/punch", "impact", {"at": Vector3(0, 1.2, -6), "normal": Vector3.BACK})
	SbFx.fire(earth_body, "stone_form/drop", "drop", {"at": Vector3(4, 0, -2), "el": "earth"})
	var n := SbFx.plays.size()
	SbFx.log_plays = false
	await _frames(20)
	var got := [randi(), randi()]
	_expect(n >= 3 and got == base and CascadeFx.rng.state != st,
			"%d effects played 20 frames rolling their own dice (CascadeFx.rng moved: %s), never the game's (%s, %s)" % [n,
			CascadeFx.rng.state != st, got, base])


# ---------------------------------------------------------------- lifecycle
func _lifecycle(n0: int, orphans0: float, kids0: Array) -> void:
	var sp := SpellFx.of(stage)
	var t := 0
	while sp.playing_count() > 0 and t < 60 * 12:
		await physics_frame
		t += 1
	_expect(sp.playing_count() == 0, "everything played ends (%d still playing after %.1f s)" % [sp.playing_count(), t / 60.0])
	await _frames(3)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_expect(orphans <= orphans0, "no orphan nodes left (%d, %d at the start)" % [orphans, orphans0])
	# (the stage's own nodes back: the SpellFx player (its idle pool) and today's looks' own pool (ToonFxPool, kept for
	# the match) are the only additions)
	var n := _count(stage)
	var extra: Array = []
	for k in stage.get_children():
		if not String(k.name) in kids0:
			n -= _count(k)
			extra.append(String(k.name))
	print("    added under the stage: %s" % [extra])
	_expect(n == n0 and extra.all(func(s: String) -> bool: return s in ["SpellFx", "ToonFxPool"]),
			"the stage's node count back to its start (%d, %d at the start; added: %s)" % [n, n0, extra])
