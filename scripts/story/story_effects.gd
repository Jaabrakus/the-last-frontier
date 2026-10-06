class_name StoryEffects
extends RefCounted
## What a mission or a step does to the world, as data (data/story/missions/*.json): `start_effects` as it begins,
## `effects` as it is done, each a list of {do: <what>, ...its fields}, done in order by StoryDirector (a dialogue's
## answers can hand some back too). The systems other work builds alongside (NpcSquad, FireSpread, Captivity) are
## called by their class names, not compiled against: one not in the game yet only warns, so a mission written ahead
## of them still plays.
##   spawn_squad      NpcSquad.spawn(level, faction, count, at, opts) at `place` (or `at` [x, z]; the player's place when
##                    neither): `faction` one of data/npc/factions.json's (french_marine, canadian_militia, militia,
##                    toughs, city_guard; `squad` is taken for it too), `count`, and the effect itself as the opts
##                    (`tag`, `attack`, `patrol`, `hold`, `waves`, ...). What it makes goes again on a retry; a save
##                    keeps how many of it are still alive, and a load puts only those back.
##   set_flag         the story's flag `flag` = `value` (true when none; null clears it)
##   give / take      `count` (1) of `item` into / out of the player's keeping: an "item." id the survival kit's
##                    (SurvivalInventory), else the pack (as StoryDialogue.give / take)
##   standing         `amount` of standing with `faction` (SurvivalEconomy.add_standing; `source` optional)
##   wonder_reveal    the sky opens, for good;  raid_night  the raid heard from far off (StoryDirector._effect)
##   burn_at          FireSpread.ignite_area(pos, radius): fire at the place over `r` m (on the level's FireSpread)
##   music            MusicDirector.story(tree, cue): `cue` (story_wonder, story_sorrow, story_home, any of
##                    audio/music/) once, over anything but a giant's fight; "" fades what plays
##   begin_captivity  Captivity.begin(player, captor, opts): the player taken (`captor`: a tag, or `captor_group`; the
##                    effect itself is the opts)
##   end_captivity    Captivity.end (`return_gear`, `parts` when given); a child slipped away with the player keeps by him
##   title_card       {text, title?}: a card before the mission's intro cards (StoryDirector.lead_cards)
##   sway_grant       {move}: SwayCaster.grant(move): the spell goes to the Tab screen's Spells list
## (The old Two Fires slice's stages, raid_staged, march, wreck_fall, rook_join, end_stages, people, cache_back and
## clear_sky, were retired with StorySlice in the 2026-10-06 cleanup: a mission that still names one only warns.)
## Any effect may carry `say`: a line shown at the top of the screen as it is done (say(): the player's notice).
## Arguments are matched to the callee's parameters by name (the effect's fields, then tree, level, player, at, r,
## count, id, d: the effect itself), else by type (a SceneTree, the player, a Vector3, a Dictionary), else its default.
## An object parameter of a class (p: FrontierPlayer) takes only an object of that class: one the story cannot fill
## (no player yet) leaves the call out, with a warning.

## Done once a mission only: not again on its retry (the pack and standing carry through it). The director keeps which
## were done (by where they are in the mission: StoryDirector.once_done), so a later step's gift is not given twice
## either.
const ONCE := ["give", "take", "standing", "cache_back"]
## Done again when a save loads in the middle of the mission (the world does not keep what they make): a save without
## the director's squads record (older ones) runs these again from the mission's and the step's start effects.
const AGAIN_ON_LOAD := ["spawn_squad"]
const ALIASES := {"scene_tree": "tree", "parent": "level", "root": "level", "scene": "level", "p": "player",
		"data": "d", "spec": "d", "options": "d", "args": "d", "params": "d", "info": "d", "effect": "d",
		"pos": "at", "position": "at", "where": "at", "point": "at", "center": "at", "centre": "at", "origin": "at",
		"radius": "r", "n": "count", "size": "count", "squad_id": "id", "kind": "id", "name": "id"}

## Stand-ins by class name (tests): a Script, or null for "not in the game".
static var stand_ins := {}
## The classes looked up by name (class name -> Script, or null when not in the game): the list is read once each.
static var _classes := {}


## Does `list`'s effects for `d`. `scope` says where the list is in the mission ("start", "s2": step 2's start effects,
## "e2": its effects, ...): with one, a ONCE effect already done in this mission (a retry) is left out, and what an
## effect makes is kept under "<scope>:<index>". Mode "load": only the AGAIN_ON_LOAD ones.
static func run(d: StoryDirector, list: Variant, mode := "", scope := "") -> void:
	if not (list is Array):
		return
	for i in (list as Array).size():
		var e: Variant = list[i]
		if not (e is Dictionary):
			continue
		var what := String(e.get("do", ""))
		if mode == "load" and not AGAIN_ON_LOAD.has(what):
			continue
		var key := "%s:%d" % [scope, i] if scope != "" else ""
		if key != "" and ONCE.has(what):
			if d.once_done(key):
				continue
			d.mark_once(key)
		do_one(d, e, key)


## Does one effect; `key` (where it is in the mission) names what it makes for the director's record.
static func do_one(d: StoryDirector, e: Dictionary, key := "") -> void:
	var tree := d.get_tree()
	var what := String(e.get("do", ""))
	match what:
		"set_flag":
			d.set_flag(String(e.get("flag", "")), e.get("value", true))
		"give":
			give(tree, String(e.get("item", "")), int(e.get("count", 1)))
		"take":
			take(tree, String(e.get("item", "")), int(e.get("count", 1)))
		"standing":
			var c := StoryObjectives._core(tree)
			if c == null:
				push_warning("Story: no survival core for standing with %s" % String(e.get("faction", "")))
			else:
				SurvivalEconomy.add_standing(c, String(e.get("faction", "")), float(e.get("amount", 0.0)), String(e.get("source", "")))
		"wonder_reveal", "raid_night":
			d._effect(what)
		"spawn_squad":
			d.keep_spawned(call_by_name("NpcSquad", "spawn", pool(d, e)), key, e)
		"burn_at":
			call_by_name("FireSpread", "ignite_area", pool(d, e))
		"music":
			MusicDirector.story(tree, String(e.get("cue", "")))
		"begin_captivity":
			call_by_name("Captivity", "begin", pool(d, e))
		"end_captivity":
			call_by_name("Captivity", "end", pool(d, e), false)
		"title_card":
			d.lead_cards.append({"title": String(e.get("title", "")), "text": String(e.get("text", ""))})
		"sway_grant":
			var gp := StoryObjectives.player(tree)
			if gp == null:
				push_warning("Story: no player to grant %s" % String(e.get("move", "")))
			else:
				SwayCaster.install(gp).grant(String(e.get("move", "")))   # (into the Spells list: readied from the hotbar)
		_:
			push_warning("Story: no effect %s" % what)
	say(tree, say_line(e))


## An effect's `say` line as shown. A sway_grant's names the spells it gave (its own line, SwayCaster.grant's, is under it):
## at {spells} when the line has it, else after its first sentence ("Your hands know something new: Earth Wall, Stone Form,
## Pillar, Mend. Tab: drag a spell to 1-9."). None with the Sway's free use (SwayCaster.free_use; the user, 2026-10-03:
## "lets make the spells free use right now"): every spell is known from the start, so a grant of spells has nothing new to
## tell (kept in the data for when the switch is off again).
static func say_line(e: Dictionary) -> String:
	var text := String(e.get("say", ""))
	if text == "" or String(e.get("do", "")) != "sway_grant":
		return text
	var names := PackedStringArray()
	for id in SwayCaster.grant_ids(String(e.get("move", ""))):
		if SwayCaster.is_spell(id):
			names.append(String(SwayMoves.move(id).get("label", id.capitalize())))
	if names.is_empty():
		return text
	if SwayCaster.free_use():
		return ""                          # (known since the start: see above)
	var list := ", ".join(names)
	if "{spells}" in text:
		return text.replace("{spells}", list)
	var cut := text.find(". ")
	if cut < 0:
		return "%s: %s" % [text.trim_suffix("."), list]
	return "%s: %s.%s" % [text.substr(0, cut), list, text.substr(cut + 1)]


## An effect's `say` (any effect may have one): its line at the top of the screen as it is done (the player's notice, over
## any line the effect itself showed; say_line). Two Fires' lock step: the Form spells granted, "Your hands know something new".
static func say(tree: SceneTree, text: String, secs := 5.0) -> void:
	if text == "":
		return
	var p := StoryObjectives.player(tree)
	var it: Variant = p.get("interactor") if p != null else null
	if it is Object and (it as Object).has_method(&"notice"):
		(it as Object).call(&"notice", text, secs)


## The arguments an effect can hand a callee: its own fields, and the world's (see the header).
static func pool(d: StoryDirector, e: Dictionary) -> Dictionary:
	var tree := d.get_tree()
	var p := StoryObjectives.player(tree)
	var at: Variant = StoryObjectives.place_point(e, d.places())
	var xz: Variant = e.get("at")
	if at == null and xz is Array and (xz as Array).size() >= 2:
		var a: Array = xz
		at = Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 \
				else Vector3(float(a[0]), FrontierTerrain.height_at(float(a[0]), float(a[1])), float(a[1]))
	if at == null:
		at = p.global_position if p else Vector3.ZERO
	var spec := e.duplicate(true)
	spec.erase("do")
	spec["at"] = at
	var captor: Node = null
	if e.has("captor") or e.has("captor_group"):
		var who := {"tag": e.captor} if e.has("captor") else {}
		if e.has("captor_group"):
			who["group"] = e.captor_group
		captor = StoryObjectives._first_living(StoryObjectives.targets(who, tree))
	var out := spec.duplicate()
	out.merge({"tree": tree, "level": tree.current_scene, "player": p, "d": spec, "opts": spec, "at": at,
			"r": float(e.get("r", 10.0)), "count": int(e.get("count", 1)), "captor": captor,
			"id": String(e.get("squad", e.get("id", "")))}, true)
	if e.has("faction") or e.has("squad"):
		out["faction"] = String(e.get("faction", e.get("squad")))     # (NpcSquad.spawn's faction; `squad` the older name)
	return out


## A class another piece of work adds (its class_name), or null while it is not in the game.
static func global_script(cls: String) -> Script:
	if stand_ins.has(cls):
		return stand_ins[cls] as Script
	if _classes.has(cls):
		return _classes[cls] as Script
	var s: Script = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			s = load(String(c.path)) as Script
			break
	_classes[cls] = s
	return s


## Calls `cls.method`: a static func, or the method of the class's node in the level (its static find(), else, when
## `make`, install()). A class or method not there, or a parameter the story cannot fill (fit_args), only warns.
## Returns what it returned (null when not called).
static func call_by_name(cls: String, method: String, args: Dictionary, make := true) -> Variant:
	var s := global_script(cls)
	if s == null:
		push_warning("Story: %s is not in the game yet (%s skipped)" % [cls, method])
		return null
	var on: Object = s
	if not s.has_method(method):
		on = null
		if s.has_method("find"):
			on = _call_fitted(cls, s, s, "find", args) as Object
		if on == null and make and s.has_method("install"):
			on = _call_fitted(cls, s, s, "install", args) as Object
		if on == null or not on.has_method(method):
			push_warning("Story: no %s.%s in the game yet" % [cls, method])
			return null
	return _call_fitted(cls, s, on, method, args)


## `on.method` (of the class `cls`) with its arguments fitted from `s`'s signature (null, and a warning, when one it
## needs is not there).
static func _call_fitted(cls: String, s: Script, on: Object, method: String, args: Dictionary) -> Variant:
	var missing := []
	var a := fit_args(s, method, args, missing)
	if not missing.is_empty():
		push_warning("Story: %s.%s skipped: nothing to give it for %s" % [cls, method, ", ".join(missing)])
		return null
	return on.callv(method, a)


## `method`'s arguments from `args`: each parameter by its name (or an alias), else by its type when it is one the
## story can give (the tree, the player, the level, a place, the effect), else its default, else by plain type.
## Defaults at the end are left to the callee (a default that is not a constant, `= []`, is reported as null). An object
## parameter of a class takes only an object of it; a required one the story has none for goes into `missing` (its name).
static func fit_args(s: Script, method: String, args: Dictionary, missing: Array = []) -> Array:
	var sig := {}
	for m: Dictionary in s.get_script_method_list():
		if String(m.get("name", "")) == method:
			sig = m
			break
	var params: Array = sig.get("args", [])
	var defaults: Array = sig.get("default_args", [])
	var first_default := params.size() - defaults.size()
	var out := []
	var given := 0                     ## the arguments up to the last one not left to its default
	for i in params.size():
		var prm: Dictionary = params[i]
		var nm := String(prm.get("name", "")).trim_prefix("p_").trim_prefix("_")
		var type := int(prm.get("type", TYPE_NIL))
		var cls := String(prm.get("class_name", ""))
		var key := String(ALIASES.get(nm, nm))
		var v: Variant = null
		var found := false
		for k in [nm, key]:
			if args.has(k) and args[k] != null and _fits(args[k], type) and (type != TYPE_OBJECT or _is_a(args[k], cls)):
				v = _coerce(args[k], type)
				found = true
				break
		if not found and type == TYPE_OBJECT:
			if cls == "SceneTree":
				v = args.get("tree")
			elif cls == "FrontierPlayer":
				v = args.get("player")
			found = v != null
		if not found and type in [TYPE_DICTIONARY, TYPE_VECTOR3]:
			v = args.get("d") if type == TYPE_DICTIONARY else args.get("at")
			found = true
		if not found and i >= first_default:
			v = defaults[i - first_default]
			if v == null and type != TYPE_OBJECT and type != TYPE_NIL:
				v = type_convert(null, type)           # (only passed when a later argument is: the type's empty value)
			out.append(v)
			continue
		given = i + 1
		if not found:
			match type:
				TYPE_OBJECT:
					v = args.get("level") if _is_a(args.get("level"), cls) else null
					if v == null:
						missing.append(nm)                 # (no player yet for a p: FrontierPlayer: the call is left out)
				TYPE_STRING, TYPE_STRING_NAME:
					v = _coerce(args.get("id", ""), type)
				TYPE_INT:
					v = int(args.get("count", 1))
				TYPE_FLOAT:
					v = float(args.get("r", 10.0))
				TYPE_NIL:
					v = args.get("d")
		out.append(v)
	return out.slice(0, given)


static func _fits(v: Variant, type: int) -> bool:
	match type:
		TYPE_NIL:
			return true
		TYPE_INT, TYPE_FLOAT:
			return v is int or v is float
		TYPE_STRING, TYPE_STRING_NAME:
			return v is String or v is StringName
		TYPE_OBJECT:
			return v is Object
		TYPE_VECTOR3:
			return v is Vector3
	return typeof(v) == type


## Whether `v` is an object of the class `cls` (an engine class, or a class_name of its script or one it extends);
## any object when `cls` is "".
static func _is_a(v: Variant, cls: String) -> bool:
	if not (v is Object) or not is_instance_valid(v):
		return false
	if cls == "":
		return true
	var o := v as Object
	if o.is_class(cls):
		return true
	var sc := o.get_script() as Script
	while sc != null:
		if String(sc.get_global_name()) == cls:
			return true
		sc = sc.get_base_script()
	return false


static func _coerce(v: Variant, type: int) -> Variant:
	match type:
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_STRING:
			return String(v)
		TYPE_STRING_NAME:
			return StringName(String(v))
	return v


# --- The pack ------------------------------------------------------------------------------------------------

## Puts `n` of `kind` into the player's keeping (a note on screen): an "item." id into the survival kit
## (SurvivalInventory), else the pack, as StoryDialogue.give does.
static func give(tree: SceneTree, kind: String, n: int) -> void:
	var p := StoryObjectives.player(tree)
	if p == null or kind == "" or n <= 0:
		return
	if kind.begins_with("item."):
		var c := StoryObjectives._core(tree)
		if c == null:
			return
		SurvivalInventory.add(c, kind, float(n))
		_toast(p, "+%d %s" % [n, c.data.item_name(kind)], "")
		return
	var inv := InventoryState.from_player(p)
	inv.add(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)
	_toast(p, "+%d %s" % [n, InventoryState.name_of(kind)], kind)


## Takes up to `n` of `kind` from the player (the survival kit's for an "item." id, else the pack's); how many there
## were to take.
static func take(tree: SceneTree, kind: String, n: int) -> int:
	var p := StoryObjectives.player(tree)
	if p == null or kind == "" or n <= 0:
		return 0
	if kind.begins_with("item."):
		var c := StoryObjectives._core(tree)
		var have := int(SurvivalInventory.count(c, kind)) if c != null else 0
		var took := mini(n, have)
		if took > 0:
			SurvivalInventory.remove(c, kind, float(took))
			_toast(p, "-%d %s" % [took, c.data.item_name(kind)], "")
		return took
	var inv := InventoryState.from_player(p)
	var got := inv.take(kind, n)
	if got > 0:
		p.inventory_pack = inv.pack.duplicate(true)
		_toast(p, "-%d %s" % [got, InventoryState.name_of(kind)], kind)
	return got


static func _toast(p: FrontierPlayer, text: String, icon: String) -> void:
	if p.hud != null and is_instance_valid(p.hud):
		p.hud.toast(text, icon if InventoryState.NAMES.has(icon) else "")      # (a story's own thing has no picture)
