class_name SbFx
extends RefCounted
## The rebuilt Spellbreak effects on Tidebreak's moves (Spellbreak by Proletariat; provenance, the source packages and the
## licence note: res://assets/fx/spellbreak/SOURCE.md). One data-driven bridge between the moves' visual seams and SpellFx:
## what plays, where and how is data, data/bending/sb_fx/<earth|water|fire|air>.json (one entry per move/mode and role),
## the switches data/bending/sb_fx/config.json (a master switch and one per element: off, every move looks as before).
##
## Visual only. Nothing here reads or writes a spec, a hit info, a timer, a hitbox, a velocity or an aim; each call stands
## beside an old visual, which its caller skips when fire()/start() return true (the entry replaces it) or keeps
## (keep_old: the entry plays over it). Headless nothing plays (allow_headless for its own test), so every headless test
## (test_r4_looks' looks built headless too) sees today's looks, and bots and gameplay run the same either way.
##
## The seams (who calls what; the role names are the hook points' own, see data/bending/sb_fx/config.json (_doc)):
##   BendEffects     cast, heal, heal_pop, cone, hit_body, put_out, melt, dash (+ dash_began), ride, ride_spray, low,
##                   throw, flash, strike, hit, lightning_back, kick_up, slam, slam_deck, air_hit
##   BendBolt        flight / wave, trail, curve (Flowing), impact, body_extra, swing, clash
##   BendZone        zone_start, zone, zone_end, deflect, put_out, blown, entry, doused, melted, cushion, held, return
##   FormRaised      rise, stand, hit, crumble, shatter, melt
##   GustLift        flight, return_flight, hit, land, roll, drop, clash
##   FormEffects     rise, hang, launch (+ air_trail, land: watched), mend
##   SwayCaster      charge, grow (BendLooks.grow_click: grow_click), idle (Flowing), rooted idle / take_hold
##   BendMotion      dash_end (dash_trail, dash_flames stopped)
##   BendR3          pop, held (the Pop's stone)
##   BendLooks       perfect / late / whiff (guard_result), charge (Charge), charged / charge_pop (carried), prewarm
##
## A move's key is its hit info's tag ("fire_blast/punch.grown"), else "move/mode"; passives and shared rows have their
## own ("rooted", "flowing", "passive/carried_wind", "patch/patch", "mend", "clash/stone", "stone_form/drop"). Lookup
## strips suffixes one at a time ("a/b.grown" -> "a/b" -> "a") and tries the caster's element's table first, then the
## move's own element's.

const DIR := "res://data/bending/sb_fx/"
const CONFIG := DIR + "config.json"
const ELEMENTS := ["earth", "water", "fire", "air"]
## UE +X (an effect's forward) onto a frame's -Z (Godot forward); UE Z up is Godot +Y already (CascadeFx).
const UE_FWD := Basis(Vector3.UP, PI / 2.0)
## A role with no entry of its own tries these (shatter and melt look as the crumble when they have none).
const ROLE_FALLBACK := {"shatter": "crumble", "melt": "crumble", "zone_start": "", "late": "", "whiff": ""}
## A play that nothing will stop (not held, not following a node, no travel, no life of its own) of an effect that loops for
## ever is stopped after this many seconds (config.json "max_life_s" overrides it; 0 = no net): it would otherwise play for
## the rest of the session and count toward max_playing.
const MAX_LIFE_S := 4.0

static var _cfg: Dictionary = {}
static var _moves: Dictionary = {}
static var _loaded := false
## Runtime switches over config.json's (the lineup tool's old/new shots, tests): null = the file's.
static var force_on: Variant = null
static var force_elements: Dictionary = {}
## Tests: play headless too (CascadeFx simulates without a window).
static var allow_headless := false
## Tests: every play logged here as [element, key, role, effect id] while true.
static var log_plays := false
static var plays: Array = []
## owner instance id -> {slot -> Array of Handle / helper Node}
static var _held: Dictionary = {}
## "volley_id:role" -> count (volley_max)
static var _volleys: Dictionary = {}
static var _warned: Dictionary = {}


# ---------------------------------------------------------------- data
static func reload_data() -> void:
	_loaded = false
	_mat_hidden.clear()
	_load()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_cfg = _read(CONFIG)
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("sbfx="):
			force_on = a.get_slice("=", 1) != "off"      # (a run's own switch: sbfx=off draws every move as before)
	_moves = {}                                     # (an element's table is read the first time it is asked for)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return j if j is Dictionary else {}


static func config() -> Dictionary:
	_load()
	return _cfg


## Element `el`'s table: {key -> {role -> entry}}.
static func table(el: String) -> Dictionary:
	_load()
	if not _moves.has(el):
		if not el in ELEMENTS:
			return {}
		var mv: Variant = _read(DIR + el + ".json").get("moves", {})
		_moves[el] = mv if mv is Dictionary else {}
	return _moves[el]


## Whether element `el`'s moves play their Spellbreak effects now (the master switch, then the element's). A missing or
## unreadable config.json switches nothing on.
static func on(el: String) -> bool:
	if not _master():
		return false
	if not (el in ELEMENTS) or OS.has_feature("public"):
		return false                          # (a public build: only the single moves the owner picked, moves_on)
	if force_elements.has(el):
		return bool(force_elements[el])
	return bool((_cfg.get("elements", {}) as Dictionary).get(el, false))


## The master switch (a run's force_on over config.json's enabled); headless always off (today's looks, as the tests that
## count them build them).
static func _master() -> bool:
	_load()
	if not allow_headless and DisplayServer.get_name() == "headless":
		return false
	return bool(force_on) if force_on != null else bool(_cfg.get("enabled", false))


## Whether `role` of move `key` plays by itself while its element is off (config.json moves_on: {KEY: [ROLE, ...]}, a single
## move's roles the owner picked from a side-by-side; the master switch still rules). The key's chain is asked ("a/b.grown"
## is "a/b"'s too). A forced element (force_elements: the lineup's own runs) is its own answer either way.
static func move_on(key: String, role: String) -> bool:
	if key == "" or not _master():
		return false
	if force_elements.has(element_for(null, key)):
		return false
	var mo: Variant = _cfg.get("moves_on", {})
	if not (mo is Dictionary) or (mo as Dictionary).is_empty():
		return false
	for k: String in _chain(key):
		var roles: Variant = (mo as Dictionary).get(k)
		if roles is Array and role in roles:
			return true
	return false


## Whether any element, or any single move (moves_on), plays now. Every call site is per event, and with everything off they
## return here before any table lookup.
static func any_on() -> bool:
	for el: String in ELEMENTS:
		if on(el):
			return true
	if not _master():
		return false
	var mo: Variant = _cfg.get("moves_on", {})
	return mo is Dictionary and not (mo as Dictionary).is_empty()


## The key of a hit info (its tag), else move/mode.
static func key_of(info: Variant, m := "", mode := "") -> String:
	if info is Dictionary and String((info as Dictionary).get("tag", "")) != "":
		return String((info as Dictionary).tag)
	if m != "":
		return "%s/%s" % [m, mode] if mode != "" else m
	return ""


## The element whose table a key is looked up in first: the move's own (Bending.element_of), else the caster's (shared
## moves: patch, mend; passives).
static func element_for(by: Variant, key: String) -> String:
	var el := Bending.element_of(key.get_slice("/", 0).get_slice(".", 0))
	if el in ELEMENTS:
		return el
	if is_instance_valid(by) and by is Node:
		return BendPoses.element_of(by as Node)
	return ""


static func _chain(key: String) -> Array:
	var out := [key]
	var k := key
	while true:
		var slash := k.find("/")
		var dot := k.rfind(".")
		if dot > maxi(slash, 0):
			k = k.substr(0, dot)
		elif slash > 0:
			k = k.substr(0, slash)
		else:
			break
		out.append(k)
	return out


## The entry for `role` of `key` in element `el`'s table ({} none). An entry whose effect is "" stops the search (keep
## today's look for it).
static func entry(el: String, key: String, role: String) -> Dictionary:
	var t := table(el)
	for k: String in _chain(key):
		var m: Variant = t.get(k)
		if m is Dictionary and (m as Dictionary).has(role):
			var e: Variant = m[role]
			return e if e is Dictionary and String((e as Dictionary).get("effect", "")) != "" else {}
	var fb := String(ROLE_FALLBACK.get(role, ""))
	return entry(el, key, fb) if fb != "" else {}


## The entry that would play for `role` of `key` cast by `by` ({} none, or the switch off).
static func resolve(by: Variant, key: String, role: String, el := "") -> Dictionary:
	if key == "" or not any_on():
		return {}
	var els: Array = []
	if el != "":
		els.append(el)
	else:
		if is_instance_valid(by) and by is Node:
			var be := BendPoses.element_of(by as Node)
			if be in ELEMENTS:
				els.append(be)
		var me := element_for(null, key)
		if me != "" and not me in els:
			els.append(me)
	for e: String in els:
		var en := entry(e, key, role)
		if not en.is_empty():
			return en.merged({"_el": e}) if on(e) or (e == element_for(null, key) and move_on(key, role)) else {}
	return {}


## Every effect id the tables name (only the elements switched on and the single moves on; all with `all`), for the
## prewarm.
static func ids(all := false) -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for el: String in ELEMENTS:
		var whole := all or on(el)
		var t := table(el)
		for k: String in t:
			var roles: Variant = t[k]
			if not (roles is Dictionary):
				continue
			for r: String in roles:
				var e: Variant = roles[r]
				if e is Dictionary and (whole or (el == element_for(null, k) and move_on(k, r))):
					var id := String((e as Dictionary).get("effect", ""))
					if id != "" and not id in out and SpellFx.has_effect(id):
						out.append(id)
	return out


## Every listed effect made ready behind the loading screen (SpellFx.prewarm: specs, textures, meshes, materials and
## shaders, one parked node each). `progress` gets 0..1. Await it.
static func prewarm(cam: Camera3D, progress := Callable()) -> void:
	var list := ids()
	if cam == null or list.is_empty():
		if progress.is_valid():
			progress.call(1.0)
		return
	var t0 := Time.get_ticks_usec()
	await SpellFx.prewarm(Array(list), cam, progress, int(config().get("prewarm_per_frame", 4)))
	print("SBFX prewarm %d effects %.0f ms" % [list.size(), (Time.get_ticks_usec() - t0) / 1000.0])
	# (the camera may have been freed while the prewarm awaited)
	var sp: SpellFx = SpellFx.of(cam.get_tree().current_scene) if is_instance_valid(cam) and cam.is_inside_tree() else null
	if sp != null and (OS.is_stdout_verbose() or OS.get_cmdline_user_args().has("sbfx_warm_log=on")):
		var steps: Array = sp.warm_steps.duplicate()
		steps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
		for s: Array in steps.slice(0, 6):
			print("  SBFX warm step %.0f ms: %s" % [float(s[1]), ", ".join(PackedStringArray((s[0] as Array).map(func(x): return String(x).get_file())))])


# ---------------------------------------------------------------- play
## Plays `role` of move `key` (cast by `by`, any node or null) placed by `ctx`; true when it played and replaces today's
## look (the caller then skips it). ctx (all optional):
##   node: Node3D      the thing it belongs to (a bolt, a zone, a stone, a wall): at "node" follows it
##   at: Vector3       the point (a hit, the ground, a hand); to: Vector3 where a "travel" entry goes
##   dir: Vector3      forward (flight, aim, a zone's way); normal: Vector3 a hit's normal
##   size: Vector3     a zone's or wall's size (fit "width"/"height"); radius: float (fit "radius"); width: float
##   info: Dictionary  the hit info (volley_id for volley_max); el: String the element's table to use
##   life: float       stop after (s), over the entry's
static func fire(by: Variant, key: String, role: String, ctx := {}) -> bool:
	if not any_on():
		return false
	return bool(_play(by, key, role, ctx).get("replace", false))


## As fire(), held under `owner` (any object) and `slot` until stop(owner, slot) (an earlier one there stopped first).
static func start(owner: Variant, slot: String, by: Variant, key: String, role: String, ctx := {}) -> bool:
	if not _alive(owner):
		return false
	stop(owner, slot)
	if not any_on():
		return false
	var r := _play(by, key, role, ctx, true)
	var held: Array = r.get("held", [])
	if not held.is_empty():
		_hold(owner, slot, held)
	return bool(r.get("replace", false))


## As start(), but kept going while called again within `s` seconds (a passive's repeating tick): true when it plays.
## `first_role` (optional) plays once as it starts.
static func sustain(owner: Variant, slot: String, by: Variant, key: String, role: String, ctx: Dictionary, s: float,
		first_role := "") -> bool:
	if not _alive(owner):
		return false
	var d: Dictionary = _held.get((owner as Object).get_instance_id(), {})
	var live := false
	for h in d.get(slot, []):
		if h is SpellFx.Handle and (h as SpellFx.Handle).is_playing() and not (h as SpellFx.Handle).stopping:
			var sh := h as SpellFx.Handle
			sh.life = sh.age + s
			live = true
	if live:
		return true
	if not any_on():
		return false
	var c := ctx.duplicate()
	c["life"] = s
	var ok := start(owner, slot, by, key, role, c)
	if ok and first_role != "":
		fire(by, key, first_role, ctx)
	return ok


## The effects held under `owner` (`slot`, or every slot) stopped: they play out and go.
static func stop(owner: Variant, slot := "") -> void:
	if not _alive(owner):
		return                                     # (a freed owner's followed effects stop by themselves)
	var id := (owner as Object).get_instance_id()
	var d: Dictionary = _held.get(id, {})
	for s: String in d.keys():
		if slot != "" and s != slot:
			continue
		for h in d[s]:
			if h is SpellFx.Handle:
				(h as SpellFx.Handle).stop()
			elif is_instance_valid(h) and h is Node:
				(h as Node).queue_free()
		d.erase(s)
	if d.is_empty():
		_held.erase(id)


## Whether `owner` holds a playing effect in `slot`.
static func holding(owner: Variant, slot: String) -> bool:
	if not _alive(owner):
		return false
	for h in (_held.get((owner as Object).get_instance_id(), {}) as Dictionary).get(slot, []):
		if h is SpellFx.Handle and (h as SpellFx.Handle).is_playing():
			return true
	return false


## Whether `o` is an object still alive (a freed one passed in is never read).
static func _alive(o: Variant) -> bool:
	return typeof(o) == TYPE_OBJECT and is_instance_valid(o)


static func _hold(owner: Object, slot: String, things: Array) -> void:
	if _held.size() > 64:
		for id: int in _held.keys():
			var alive := false
			for s: String in _held[id]:
				for h in _held[id][s]:
					if (h is SpellFx.Handle and (h as SpellFx.Handle).is_playing()) or (is_instance_valid(h) and h is Node):
						alive = true
			if not alive:
				_held.erase(id)
	var d: Dictionary = _held.get(owner.get_instance_id(), {})
	d[slot] = things
	_held[owner.get_instance_id()] = d


## {handles: [Handle], held: [Handle and helper nodes], replace: bool}. `hold`: the caller keeps what it gets and stops it
## (start()); a play nobody holds that would never end gets a life (MAX_LIFE_S).
static func _play(by: Variant, key: String, role: String, ctx: Dictionary, hold := false) -> Dictionary:
	var out := {"handles": [], "held": [], "replace": false}
	var e := resolve(by, key, role, String(ctx.get("el", "")))
	if e.is_empty():
		return out
	var id := String(e.effect)
	if not SpellFx.has_effect(id):
		if not _warned.has(id):
			_warned[id] = true
			push_warning("SbFx: %s %s names an effect that is not imported: %s" % [key, role, id])
		return out
	var keep := bool(e.get("keep_old", false))
	if _all_hidden(e):
		return out                                 # (every emitter it has left out: nothing would show, today's look stays)
	var info: Variant = ctx.get("info", {})
	var vid := int((info as Dictionary).get("volley_id", 0)) if info is Dictionary else 0
	if vid != 0 and e.has("volley_max"):
		if _volleys.size() > 96:
			_volleys.clear()
		var vk := "%d:%s" % [vid, role]
		var n := int(_volleys.get(vk, 0)) + 1
		_volleys[vk] = n
		if n > int(e.volley_max):
			out["replace"] = not keep and String(e.get("volley_rest", "none")) == "none"
			return out
	var scene := _scene(by, ctx)
	var player := SpellFx.of(scene)
	if player == null:
		return out
	if player.playing_count() >= int(config().get("max_playing", 40)):
		return out                                 # (too many at once: this scene's player counts; today's look carries it)
	var cap := 0.0 if hold else float(config().get("max_life_s", MAX_LIFE_S))
	var helpers: Array = []
	for c: Array in _placements(e, by, role, ctx, helpers):
		var h := player.play(id, c[0], c[1])
		if h == null:
			continue
		out.handles.append(h)
		var travels: bool = c.size() > 2 and (c[2] as Vector3).is_finite()
		if travels:
			_travel(player, h, c[1].get("_from", Vector3.ZERO), c[2], float(e.get("travel_s", 0.08)))
		elif cap > 0.0 and h.life <= 0.0 and not bool(c[1].get("follow", false)) and _endless(e):
			h.life = cap                           # (nothing holds it, follows a node that would end it or travels to its end)
	for hp: Node in helpers:
		if out.handles.is_empty():
			hp.queue_free()
		else:
			var first := out.handles[0] as SpellFx.Handle
			var wr: WeakRef = weakref(hp)          # (a freed helper is never captured: its weak ref reads null)
			first.finished.connect(func() -> void:
				var n := wr.get_ref() as Node
				if n != null and not n.is_queued_for_deletion():
					n.queue_free())
	if out.handles.is_empty():
		return out
	var rep := float(e.get("repeat_s", 0.0))
	if rep > 0.0 and not ctx.has("_repeat") and is_instance_valid(ctx.get("node")) and ctx.get("node") is Node:
		var r := Repeat.new()
		r.every = rep
		r.call_play = func() -> void: _play(by, key, role, ctx.merged({"_repeat": true}, true))
		(ctx.node as Node).add_child(r)
		helpers.append(r)
	out["held"] = out.handles + helpers
	out["replace"] = not keep
	if log_plays:
		plays.append([String(e.get("_el", "")), key, role, id])
	return out


## effect id -> the "#index" of its emitters whose material config.json hide_materials names
static var _mat_hidden: Dictionary = {}


## The emitters of `id` drawn with a material config.json's hide_materials lists (a material that draws broken in the game:
## a solid disc for a fresnel ball, a square for a puff), as "#index".
static func _hidden_by_material(id: String) -> PackedStringArray:
	if _mat_hidden.has(id):
		return (_mat_hidden[id] as PackedStringArray).duplicate()
	var out := PackedStringArray()
	var mats: Array = config().get("hide_materials", [])
	if not mats.is_empty():
		var sp := SpellFx.spec(id)
		var es: Array = sp.get("emitters", [])
		for i in es.size():
			if String((es[i] as Dictionary).get("material", "")) in mats:
				out.append("#%d" % i)
	_mat_hidden[id] = out
	return out.duplicate()


## Whether entry `e`'s effect has a visible emitter that loops for ever on its own: played without a stop() it never ends.
static func _endless(e: Dictionary) -> bool:
	var es: Array = SpellFx.spec(String(e.effect)).get("emitters", [])
	var hide := _hidden_by_material(String(e.effect))
	var own: Array = e.get("hide", []) if e.get("hide") is Array else []
	for i in es.size():
		var em := es[i] as Dictionary
		if bool(em.get("enabled", false)) and CascadeFx.loops_forever(em) and not ("#%d" % i) in hide \
				and not String(em.get("name", "")) in own and not ("#%d" % i) in own:
			return true
	return false


## Whether entry `e` leaves out every enabled emitter of its effect (hide_materials and its own hide).
static func _all_hidden(e: Dictionary) -> bool:
	var es: Array = SpellFx.spec(String(e.effect)).get("emitters", [])
	var hide := _hidden_by_material(String(e.effect))
	var own: Array = e.get("hide", []) if e.get("hide") is Array else []
	for i in es.size():
		var em := es[i] as Dictionary
		if bool(em.get("enabled", false)) and not ("#%d" % i) in hide and not String(em.get("name", "")) in own \
				and not ("#%d" % i) in own:
			return false
	return true


static func _scene(by: Variant, ctx: Dictionary) -> Node:
	for n: Variant in [ctx.get("node"), by]:
		if is_instance_valid(n) and n is Node and (n as Node).is_inside_tree():
			var t := (n as Node).get_tree()
			return t.current_scene if t.current_scene != null else t.root
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null:
		return null
	return ml.current_scene if ml.current_scene != null else ml.root


## Each copy's [where, opts, travel_to] (spread: copies across the zone's width).
static func _placements(e: Dictionary, by: Variant, role: String, ctx: Dictionary, helpers: Array) -> Array:
	var body: Node3D = by as Node3D if is_instance_valid(by) and by is Node3D else null
	var node: Node3D = ctx.get("node") as Node3D if is_instance_valid(ctx.get("node")) and ctx.get("node") is Node3D else null
	var at_kind := String(e.get("at", "node" if node != null else "point"))
	var follow := bool(e.get("follow", at_kind == "node"))
	var p := Vector3.INF
	var fnode: Node3D = null
	match at_kind:
		"hand":
			p = hand_point(body)
			fnode = body
		"chest":
			p = BendCaster.wrap(body).chest() if body != null and BendCaster.wrap(body) != null else Vector3.INF
			fnode = body
		"feet", "caster":
			p = body.global_position + (Vector3.UP * 0.05 if at_kind == "feet" else Vector3.ZERO) if body != null else Vector3.INF
			fnode = body
		"node":
			if node != null:
				p = node.global_position
				fnode = node
		"ground":
			var q: Vector3 = ctx.get("at", node.global_position if node != null else (body.global_position if body != null else Vector3.INF))
			if q.is_finite():
				p = FormEffects.ground_at(body if body != null else node, q) if (body != null or node != null) else q
		_:
			p = ctx.get("at", node.global_position if node != null else Vector3.INF)
	if not (p is Vector3) or not p.is_finite():
		if ctx.get("at") is Vector3 and (ctx.at as Vector3).is_finite():
			p = ctx.at
		elif node != null:
			p = node.global_position
		elif body != null:
			p = body.global_position
		else:
			return []
	var b := _basis(String(e.get("orient", "dir")), body, fnode if fnode != null else node, ctx)
	var off: Array = e.get("offset", [0.0, 0.0, 0.0])
	var rot: Array = e.get("rot", [0.0, 0.0, 0.0])
	var rb := Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2]))))
	var sc := float(e.get("scale", 1.0)) * _fit(e, ctx)
	if e.has("body_scale") and BendLooks.struck_body(p) != null:
		sc *= float(e.body_scale)
	var opts := {"scale": sc, "one_shot": bool(e.get("one_shot", true)), "life": float(ctx.get("life", e.get("life", 0.0))),
			"time_scale": float(e.get("time_scale", 1.0))}
	var hide := _hidden_by_material(String(e.effect))
	if e.get("hide") is Array:
		hide.append_array(PackedStringArray(e.hide))
	if not hide.is_empty():
		opts["hide"] = hide
	if e.get("tint") is Array and (e.tint as Array).size() >= 3:
		var t: Array = e.tint
		opts["tint"] = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]) if t.size() > 3 else 1.0)
	var g := body if body != null else node
	if g != null and g.is_inside_tree():
		opts["ground_y"] = FormEffects.ground_at(g, p).y
	var n := maxi(int(e.get("spread", 1)), 1)
	var across := b.x.normalized()
	var w := float(e.get("spread_m", (ctx.get("size", Vector3.ONE) as Vector3).x if ctx.get("size") is Vector3 else 2.0))
	var out: Array = []
	if follow and at_kind == "hand" and body != null:
		# (a held effect at the hands follows them: an anchor that keeps to the hand point)
		var an := Anchor.new()
		an.src = body
		body.add_child(an)
		an.global_position = p
		helpers.append(an)
		fnode = an
	for i in n:
		var q := p + across * ((float(i) + 0.5) / float(n) - 0.5) * w if n > 1 else p
		var world := Transform3D(b, q) * Transform3D(Basis.IDENTITY, Vector3(float(off[0]), float(off[1]), float(off[2]))) \
				* Transform3D(UE_FWD * rb, Vector3.ZERO)
		var o := opts.duplicate()
		var to := Vector3.INF
		if follow and fnode != null and fnode.is_inside_tree():
			var fb := String(e.get("follow_basis", "node" if at_kind == "node" and String(e.get("orient", "")) == "node" else "fixed"))
			var fbasis := fnode.global_basis.orthonormalized() if fb == "node" else b
			var frame := Transform3D(fbasis, fnode.global_position)
			o["follow"] = true
			o["follow_basis"] = fb
			o["basis"] = b
			o["offset"] = frame.affine_inverse() * world
			out.append([fnode, o])
		else:
			if bool(e.get("travel", false)) and ctx.get("to") is Vector3:
				to = ctx.to
				var d := to - q
				if d.length_squared() > 1e-4:
					var tb := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT)
					world = Transform3D(tb, q) * Transform3D(UE_FWD * rb, Vector3.ZERO)
				o["_from"] = q
			out.append([world, o, to])
	return out


## The placement frame's turn (-Z forward, +Y up) for `orient`.
static func _basis(orient: String, body: Node3D, fnode: Node3D, ctx: Dictionary) -> Basis:
	var dir: Vector3 = ctx.get("dir", Vector3.ZERO)
	if dir.length_squared() < 1e-6:
		if body != null:
			var bc := BendCaster.wrap(body)
			dir = bc.facing() if bc != null else -body.global_basis.z
		else:
			dir = Vector3.FORWARD
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.FORWARD
	match orient:
		"node":
			if fnode != null:
				return fnode.global_basis.orthonormalized()
		"world":
			return Basis.IDENTITY
		"flat":
			return Basis.looking_at(flat, Vector3.UP)
		"up":
			return Basis.looking_at(Vector3.UP, flat)       # (forward straight up: an effect that shoots skyward)
		"down":
			return Basis.looking_at(Vector3.DOWN, flat)
		"normal", "normal_up":
			var nrm: Vector3 = ctx.get("normal", Vector3.UP)
			nrm = nrm.normalized() if nrm.length_squared() > 1e-6 else Vector3.UP
			if orient == "normal":
				return Basis.looking_at(nrm, Vector3.UP if absf(nrm.y) < 0.98 else flat)
			# (its up along the normal: a ground burst standing out of a wall's face)
			var f := (flat - nrm * flat.dot(nrm))
			f = f.normalized() if f.length_squared() > 1e-6 else nrm.cross(Vector3.RIGHT).normalized()
			return Basis.looking_at(f, nrm)
	var d := dir.normalized()
	return Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else flat)


## The entry's size from the thing it is fitted to (fit "width" / "height" / "radius" / "length" over fit_m), clamped.
static func _fit(e: Dictionary, ctx: Dictionary) -> float:
	var how := String(e.get("fit", ""))
	if how == "":
		return 1.0
	var v := 0.0
	var sz: Vector3 = ctx.get("size", Vector3.ZERO) if ctx.get("size") is Vector3 else Vector3.ZERO
	match how:
		"width":
			v = float(ctx.get("width", sz.x))
		"height":
			v = sz.y
		"radius":
			v = float(ctx.get("radius", sz.x * 0.5))
		"length":
			if ctx.get("to") is Vector3 and ctx.get("at") is Vector3:
				v = (ctx.at as Vector3).distance_to(ctx.to)
	if v <= 0.0:
		return 1.0
	var lim: Array = e.get("fit_clamp", [0.25, 4.0])
	return clampf(v / maxf(float(e.get("fit_m", 1.0)), 0.01), float(lim[0]), float(lim[1]))


## Moves a placed effect from `from` to `to` over `s` (a strike drawn along its line).
static func _travel(player: SpellFx, h: SpellFx.Handle, from: Vector3, to: Vector3, s: float) -> void:
	var tw := player.create_tween()
	tw.tween_method(func(f: float) -> void: h.set_position(from.lerp(to, f)), 0.0, 1.0, maxf(s, 0.01))
	tw.tween_callback(h.stop)


## The hands of `body` (the player's SwayCaster's hand point; a bot's a little before its chest).
static func hand_point(body: Node3D) -> Vector3:
	if body == null or not is_instance_valid(body):
		return Vector3.INF
	var bc := BendCaster.of(body)
	if bc is PlayerBendCaster and (bc as PlayerBendCaster).sway != null and is_instance_valid((bc as PlayerBendCaster).sway):
		var hp: Vector3 = (bc as PlayerBendCaster).sway.hand_point()
		if hp.is_finite():
			return hp
	if bc != null and bc.valid():
		return bc.chest() + bc.facing() * 0.45
	return body.global_position + Vector3.UP * 1.3


# ---------------------------------------------------------------- the dashes (BendEffects.dash, BendMotion._dash_end)
## body instance id -> the key of the dash it is in
static var _dash_keys: Dictionary = {}


## A dash began (BendEffects.dash): its trails held on the body until the dash ends.
static func dash_began(body: Node3D, key: String, dir: Vector3, info: Dictionary) -> void:
	if body == null or key == "":
		return
	stop(body, "dash")
	stop(body, "dash2")
	if not any_on():
		return
	var c := {"node": body, "dir": dir, "info": info}
	var a := start(body, "dash", body, key, "dash_trail", c)
	var b := start(body, "dash2", body, key, "dash_flames", c)
	if a or b or not resolve(body, key, "dash_end").is_empty():
		_dash_keys[body.get_instance_id()] = key


## The dash of `body` ended (BendMotion._dash_end): its trails stopped, its end (a resurface, a landing) played.
static func dash_ended(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var id := body.get_instance_id()
	stop(body, "dash")
	stop(body, "dash2")
	if not _dash_keys.has(id):
		return
	var key := String(_dash_keys[id])
	_dash_keys.erase(id)
	var v := (body as CharacterBody3D).velocity if body is CharacterBody3D else Vector3.ZERO
	fire(body, key, "dash_end", {"at": body.global_position + Vector3.UP * 0.05, "dir": v})


## A launch (Lift's run off the pillar): its trail held on the body and its landing played when it is on the floor again.
static func watch_landing(body: Node3D, key: String, trail_role: String, land_role: String) -> void:
	if body == null or not (body is CharacterBody3D) or not any_on():
		return
	var playing := start(body, "air", body, key, trail_role, {"node": body, "dir": (body as CharacterBody3D).velocity})
	if not playing and resolve(body, key, land_role).is_empty():
		return
	var w := Watch.new()
	w.key = key
	w.land_role = land_role
	body.add_child(w)


# ---------------------------------------------------------------- helpers
## A point that keeps to its source's hands every frame (a held effect at the hands follows it).
class Anchor:
	extends Node3D

	var src: Node3D

	func _ready() -> void:
		top_level = true
		process_priority = 90

	func _process(_dt: float) -> void:
		if src == null or not is_instance_valid(src):
			queue_free()
			return
		var p := SbFx.hand_point(src)
		if p.is_finite():
			global_position = p


## Plays its entry again every `every` seconds while its parent (a zone, a wall) stands.
class Repeat:
	extends Node

	var every := 1.0
	var call_play: Callable
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		if _t >= every:
			_t = 0.0
			if call_play.is_valid():
				call_play.call()


## A launched body's landing: its trail stopped and the landing played once it is on the floor again (4 s at most).
class Watch:
	extends Node

	var key := ""
	var land_role := ""
	var _left := false
	var _t := 0.0

	func _physics_process(dt: float) -> void:
		var b := get_parent() as CharacterBody3D
		_t += dt
		if b == null or _t > 4.0:
			_end(b, false)
			return
		if not b.is_on_floor():
			_left = true
		elif _left:
			_end(b, true)

	func _end(b: CharacterBody3D, landed: bool) -> void:
		if b != null:
			SbFx.stop(b, "air")
			if landed:
				SbFx.fire(b, key, land_role, {"at": b.global_position + Vector3.UP * 0.05, "dir": b.velocity})
		queue_free()
