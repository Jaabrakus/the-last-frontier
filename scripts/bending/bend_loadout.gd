class_name BendLoadout
extends RefCounted
## A worn loadout made live in a match (the Character Advancement window's phases B1 and B2: artifacts/ui_audit/advancement/
## plan.md section 7; docs/tidebreak/loadouts_live.md has the whole picture). Two things go live, each per body (the player's;
## a test or the soak may give a bot the same), and nothing else does:
##   B1  a fighting style's clips (data/bending/style_poses.json): the body's meta `fighting_style`, which BendPoses.pick reads
##       (animation only: a style's pick is timed as the element's own pick for that move and mode, BendPoses._timed_as, so a
##       cast, its hit and a rooted caster's recovery take exactly the Classic time)
##   B2  the node numbers that only change numbers that exist today (the plan's eight; data/bending/loadout_apply.json `live`): read from
##       data/sway/skill_tree.json changes[] (the one place the numbers live), resolved once into an overlay the body keeps
##       as meta `loadout_overlay`:
##         spec   {"move/mode": {nested spec keys}}  merged after the resolved spec in BendEffects.apply, before the grow merge
##         lock   {"move/mode": seconds}             the mode's lock (SwayCaster._lock_time; NpcBending.lock_for for a bot)
##         wall   {hits, width_m, rise_s, ...}       Earth Wall's numbers (FormEffects.earth_wall, tree_wall; a bot's wall)
##         ice    {hits, rise_s, materials{snow}}    Ice Wall's numbers (BendEffects.ice_wall)
##       A node whose change touches a number nothing reads per wearer is refused whole (never half applied), and so is one whose
##       data drifted from its `from` (the move was retuned after the tree was written).
## Classic (nothing worn) is no meta at all: every reader asks `overlay_of(body)` first and gets {} (the same dictionaries it
## read before), so a body that wears nothing reads exactly today's numbers. A hit's cost (the `_lock_s` a blow carries, the
## victim's lock set-back) stays the move's own data lock: a talent changes its wearer's lock, never what a blow costs whom it hits.
##   wear_player(body, element)    RingMode.restart: the loadout worn for `element` (AdvancementStore, read only: the match never
##                                 writes the save) onto the player's body
##   wear(body, picks, style, el)  any body (tests, the soak): the live picks' overlay and the live style
##   overlay_of(body), picks_of(body), style_meta(body), clear(body)
##   spec(body, m, mode, spec), lock(body, m, mode, base), wall_numbers(body, kind, base, matter)   the readers' seams
##   enabled(), live_ids(), live_styles(), why_not(id), resolve(id), style_ok(style, element)
## Tests: `config_override` is merged over the file, `read_store_in_scripts` lets a script run read the store.

const APPLY_PATH := "res://data/bending/loadout_apply.json"
const TREE_PATH := "res://data/sway/skill_tree.json"
const STYLES_PATH := "res://data/bending/fighting_styles.json"
## The Advancement save (scripts/ui/advancement/advancement_store.gd), loaded by path and called by name: the window's scripts are
## another task's, and a compile error in them (work in flight) must leave the match playing Classic, not break every script that
## names BendLoadout.
const STORE_SCRIPT := "res://scripts/ui/advancement/advancement_store.gd"
const STYLE_META := &"fighting_style"
const PICKS_META := &"loadout_picks"
const OVERLAY_META := &"loadout_overlay"
const FormMatter := preload("res://scripts/sway/form_matter.gd")

## Tests only: merged over the file (enabled, live, styles_live replace; nodes merge by id).
static var config_override: Dictionary = {}
## Tests and tools only: let RingMode.restart read the store in a script run (-s). A script run's store file is the test file
## (AdvancementStore.TEST_PATH), never the player's own: left off, every test and tool plays Classic whatever that file holds.
static var read_store_in_scripts := false

static var _cfg: Dictionary = {}
static var _tree: Dictionary = {}                ## id -> the skill tree's node
static var _styles: Dictionary = {}              ## fighting_styles.json "styles"
static var _resolved: Dictionary = {}            ## id -> resolve()
static var _lib_exists: Dictionary = {}          ## library path -> whether the file is there (asked once)


# ---------------------------------------------------------------- the switches
static func config() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(APPLY_PATH)) if FileAccess.file_exists(APPLY_PATH) else null
		_cfg = d if d is Dictionary else {"enabled": false, "nodes": {}, "live": [], "styles_live": []}
	if config_override.is_empty():
		return _cfg
	var out := _cfg.duplicate(true)
	for k: String in config_override:
		if k == "nodes" and config_override[k] is Dictionary:
			var nd: Dictionary = (out.get("nodes", {}) as Dictionary).duplicate()
			nd.merge(config_override[k], true)
			out["nodes"] = nd
		else:
			out[k] = config_override[k]
	return out


## Forget what was read (the next call reads the files again). Not named reload: called on the class that name is the script's
## own Script.reload.
static func reload_data() -> void:
	_cfg = {}
	_tree = {}
	_styles = {}
	_resolved = {}
	_lib_exists = {}


## The master switch (data/bending/loadout_apply.json "enabled"): off, no style and no number applies.
static func enabled() -> bool:
	return bool(config().get("enabled", false))


## Why node `id` is not live now ("" live): the master switch, the live list, its own switch, or the reason it was refused.
static func why_not(id: String) -> String:
	var c := config()
	if not bool(c.get("enabled", false)):
		return "the master switch is off"
	if not id in (c.get("live", []) as Array):
		return "not in the live list"
	if not bool((c.get("nodes", {}) as Dictionary).get(id, true)):
		return "switched off"
	var r := resolve(id)
	return "" if bool(r.ok) else String(r.why)


## The nodes live now, in the live list's order (switches on and the numbers resolved).
static func live_ids() -> Array[String]:
	var out: Array[String] = []
	for v: Variant in (config().get("live", []) as Array):
		if why_not(String(v)) == "":
			out.append(String(v))
	return out


## The styles live now: in styles_live, animated (fighting_styles.json), with poses (style_poses.json) and their library.
static func live_styles() -> Array[String]:
	var out: Array[String] = []
	if not enabled():
		return out
	for v: Variant in (config().get("styles_live", []) as Array):
		var st := String(v)
		if style_ok(st, String(_style_def(st).get("element", ""))):
			out.append(st)
	return out


static func _style_def(style: String) -> Dictionary:
	if _styles.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLES_PATH)) if FileAccess.file_exists(STYLES_PATH) else null
		_styles = (d as Dictionary).get("styles", {}) if d is Dictionary else {}
		if _styles.is_empty():
			_styles = {"_none": {}}
	var s: Variant = _styles.get(style, {})
	return s if s is Dictionary else {}


## Whether `style` plays for a body that casts as `element`: master switch on, in styles_live, animated (never parked or
## coming: Capoeira is parked), of that element, with poses in style_poses.json and its library on disk.
static func style_ok(style: String, element: String) -> bool:
	if style == "" or element == "" or not enabled():
		return false
	if not style in (config().get("styles_live", []) as Array):
		return false
	var def := _style_def(style)
	if String(def.get("state", "")) != "animated" or String(def.get("element", "")) != element:
		return false
	var sd := BendPoses.style_data(style)
	if sd.is_empty() or String(sd.get("element", "")) != element:
		return false
	var lib := String(sd.get("library", ""))
	if not _lib_exists.has(lib):
		_lib_exists[lib] = ResourceLoader.exists(lib)
	return bool(_lib_exists[lib])


# ---------------------------------------------------------------- a node's numbers
static func _node(id: String) -> Dictionary:
	if _tree.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH)) if FileAccess.file_exists(TREE_PATH) else null
		_index(d)
		if _tree.is_empty():
			_tree = {"_none": {}}
	var n: Variant = _tree.get(id, {})
	return n if n is Dictionary else {}


static func _index(o: Variant) -> void:
	if o is Dictionary:
		var dd := o as Dictionary
		if dd.get("id") is String and dd.get("kind") is String and dd.has("ring_legal"):
			_tree[String(dd.id)] = dd
		for k: Variant in dd:
			_index(dd[k])
	elif o is Array:
		for v: Variant in (o as Array):
			_index(v)


static func _refused(why: String) -> Dictionary:
	return {"ok": false, "why": why}


## What node `id` changes, as an overlay part: {ok, why, el, spec, lock, wall, ice}. Every change in the node's changes[] must be
## a number this applies per wearer, and the data it reads must still hold the change's `from`; else the node is refused whole.
## The node must be ring-legal and not held. Cached.
static func resolve(id: String) -> Dictionary:
	if not _resolved.has(id):
		_resolved[id] = _resolve(id)
	return _resolved[id]


static func _resolve(id: String) -> Dictionary:
	var n := _node(id)
	if n.is_empty():
		return _refused("not in the skill tree")
	if not bool(n.get("ring_legal", false)) or n.get("held") != null:
		return _refused("not ring-legal or held")
	var changes: Variant = n.get("changes", [])
	if not (changes is Array) or (changes as Array).is_empty():
		return _refused("changes no number")
	var el := id.get_slice(".", 0)
	var out := {"ok": true, "why": "", "el": el, "spec": {}, "lock": {}, "wall": {}, "ice": {}}
	for c: Variant in (changes as Array):
		if not (c is Dictionary):
			return _refused("a change is not a dictionary")
		var why := _take(out, n, c as Dictionary)
		if why != "":
			return _refused(why)
	return out


## One change into `out` ("" taken, else why not).
static func _take(out: Dictionary, n: Dictionary, c: Dictionary) -> String:
	var path := String(c.get("path", ""))
	var kind := path.get_slice(":", 0)
	var rest := path.substr(kind.length() + 1)
	var to: Variant = c.get("to")
	var from: Variant = c.get("from")
	if not (to is float or to is int) or not (from is float or from is int):
		return "%s: not a number" % path
	if kind == "spec":
		# spec:<move>/<mode>.<key>[.<key>...]: a key of the move's bend spec for that mode
		var mv := rest.get_slice("/", 0)
		var keys: Array = Array(rest.substr(mv.length() + 1).split("."))
		if keys.size() < 2:
			return "%s: malformed" % path
		var mode := String(keys[0])
		var sub: Array = keys.slice(1)
		var bend: Variant = SwayMoves.move(mv).get("bend", {})
		var sd: Variant = (bend as Dictionary).get(mode) if bend is Dictionary else null
		if not (sd is Dictionary):
			return "%s: no such spec" % path
		var cur: Variant = _dig(sd, sub)
		if cur == null or not is_equal_approx(float(cur), float(from)):
			return "%s: the data holds %s, the node says from %s" % [path, str(cur), str(from)]
		if not _consumed(mv, mode, sub):
			return "%s: no code reads this number" % path
		return _put(out.spec as Dictionary, ["%s/%s" % [mv, mode]] + sub, to)
	if kind != "move":
		return "%s: unknown kind" % path
	# move:<move>.<key>...: the move's own data
	var parts: Array = Array(rest.split("."))
	var mv2 := String(parts[0])
	var mdata := SwayMoves.move(mv2)
	var tail: Array = parts.slice(1)
	if tail.is_empty() or mdata.is_empty():
		return "%s: malformed" % path
	if tail[0] == "lock_s" and tail.size() == 1:
		# the move's lock, scoped to the node's own mode (Step's lock is not Hop's)
		var md := String(n.get("mode", ""))
		var mlk: Variant = mdata.get("mode_lock_s", {})
		if md == "" or (mlk is Dictionary and (mlk as Dictionary).has(md)):
			return "%s: no single base lock for mode %s" % [path, md]
		if not is_equal_approx(float(mdata.get("lock_s", -1.0)), float(from)):
			return "%s: the data holds %s, the node says from %s" % [path, str(mdata.get("lock_s")), str(from)]
		return _put(out.lock as Dictionary, ["%s/%s" % [mv2, md]], to)
	if tail[0] == "mode_lock_s" and tail.size() == 2:
		var mlk2: Variant = mdata.get("mode_lock_s", {})
		if not (mlk2 is Dictionary) or not (mlk2 as Dictionary).has(tail[1]) or not is_equal_approx(float((mlk2 as Dictionary)[tail[1]]), float(from)):
			return "%s: the data does not hold from %s" % [path, str(from)]
		return _put(out.lock as Dictionary, ["%s/%s" % [mv2, tail[1]]], to)
	if mv2 == "earth_wall" and tail[0] == "wall":
		# Earth Wall's numbers, or (rise_s, snow hits) Ice Wall's: the node's element says which builder reads them
		var cur2: Variant = _dig(mdata, tail)
		if cur2 == null or not is_equal_approx(float(cur2), float(from)):
			return "%s: the data holds %s, the node says from %s" % [path, str(cur2), str(from)]
		var sub2: Array = tail.slice(1)
		var bucket := "wall" if String(out.el) == "earth" else "ice" if String(out.el) == "water" else ""
		var allowed: Array = ["hits", "width_m", "rise_s"] if bucket == "wall" else ["rise_s"]
		if bucket == "":
			return "%s: no wall builder of this element reads it per wearer" % path
		if sub2.size() == 1 and sub2[0] in allowed:
			return _put(out[bucket] as Dictionary, sub2, to)
		if bucket == "ice" and sub2.size() == 3 and sub2[0] == "materials" and sub2[1] == "snow" and sub2[2] == "hits":
			return _put(out.ice as Dictionary, sub2, to)
		return "%s: no builder reads this per wearer" % path
	return "%s: no code reads this number per wearer" % path


## Whether game code reads spec key path `sub` of move `mv` at `mode` for the wearer's own cast (BendEffects.apply merges the
## overlay in before anything reads the spec). The Skate's puddles are in the data but nothing makes them: the node that sets
## them is refused (its other change alone would be a pure slowdown).
static func _consumed(_mv: String, _mode: String, sub: Array) -> bool:
	return String(sub[0]) != "puddles"


static func _dig(d: Variant, keys: Array) -> Variant:
	var cur: Variant = d
	for k: Variant in keys:
		if not (cur is Dictionary) or not (cur as Dictionary).has(String(k)):
			return null
		cur = (cur as Dictionary)[String(k)]
	return cur


## Value `v` at nested `keys` in `into` ("" put, else why not: a key already set).
static func _put(into: Dictionary, keys: Array, v: Variant) -> String:
	var cur := into
	for i in keys.size() - 1:
		var k := String(keys[i])
		if not (cur.get(k) is Dictionary):
			cur[k] = {}
		cur = cur[k]
	var last := String(keys[keys.size() - 1])
	if cur.has(last):
		return "%s is set twice" % ".".join(PackedStringArray(keys))
	cur[last] = v
	return ""


# ---------------------------------------------------------------- the overlay of a set of picks
## The overlay of `picks` for a body that casts as `element` (""): {spec, lock, wall, ice, ids (applied), refused {id: why}}. A pick
## that is not live, of another element, or that sets a number another already set, applies nothing.
static func overlay_for(picks: Array, element := "") -> Dictionary:
	var out := {"spec": {}, "lock": {}, "wall": {}, "ice": {}, "ids": [], "refused": {}}
	for v: Variant in picks:
		var id := String(v)
		var why := why_not(id)
		var r := resolve(id) if why == "" else {}
		if why == "" and element != "" and String(r.el) != element:
			why = "another element's"
		if why == "" and id in (out.ids as Array):
			why = "twice"
		if why != "":
			(out.refused as Dictionary)[id] = why
			continue
		var trial := {"spec": (out.spec as Dictionary).duplicate(true), "lock": (out.lock as Dictionary).duplicate(true),
				"wall": (out.wall as Dictionary).duplicate(true), "ice": (out.ice as Dictionary).duplicate(true)}
		var clash := ""
		for part: String in ["spec", "lock", "wall", "ice"]:
			clash = _fold(trial[part] as Dictionary, r[part] as Dictionary)
			if clash != "":
				break
		if clash != "":
			(out.refused as Dictionary)[id] = clash
			continue
		for part: String in ["spec", "lock", "wall", "ice"]:
			out[part] = trial[part]
		(out.ids as Array).append(id)
	return out


## `src` folded into `into` (a number set twice is a clash: returns where, else "").
static func _fold(into: Dictionary, src: Dictionary) -> String:
	for k: String in src:
		if src[k] is Dictionary:
			if into.has(k) and not (into[k] is Dictionary):
				return k
			if not into.has(k):
				into[k] = {}
			var why := _fold(into[k], src[k])
			if why != "":
				return "%s.%s" % [k, why]
		elif into.has(k):
			return k
		else:
			into[k] = src[k]
	return ""


# ---------------------------------------------------------------- a body's loadout
## `body` wears `picks` (node ids) and `style`, as a caster of `element`: its overlay and its fighting_style meta set (what is not
## live applies nothing; nothing live, no meta at all). Returns the overlay (with the refusals).
static func wear(body: Node, picks: Array, style := "", element := "") -> Dictionary:
	var ov := overlay_for(picks, element)
	if body == null or not is_instance_valid(body):
		return ov
	if (ov.ids as Array).is_empty():
		clear_numbers(body)
	else:
		body.set_meta(OVERLAY_META, ov)
		body.set_meta(PICKS_META, (ov.ids as Array).duplicate())
	if style_ok(style, element):
		body.set_meta(STYLE_META, style)
	elif body.has_meta(STYLE_META):
		body.remove_meta(STYLE_META)
	return ov


static func clear_numbers(body: Node) -> void:
	for m: StringName in [OVERLAY_META, PICKS_META]:
		if body.has_meta(m):
			body.remove_meta(m)


## `body` back to Classic: no numbers, no style.
static func clear(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	clear_numbers(body)
	if body.has_meta(STYLE_META):
		body.remove_meta(STYLE_META)


## The overlay `body` wears ({} Classic: nothing worn, or nothing of it live).
static func overlay_of(body: Object) -> Dictionary:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(OVERLAY_META):
		return {}
	var ov: Variant = (body as Node).get_meta(OVERLAY_META)
	return ov if ov is Dictionary else {}


## The node ids `body` wears live (the applied picks).
static func picks_of(body: Object) -> Array:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(PICKS_META):
		return []
	return ((body as Node).get_meta(PICKS_META) as Array).duplicate()


## The fighting style `body` is set to ("" none), as the meta has it: BendPoses.style_of also asks style_ok.
static func style_meta(body: Object) -> String:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(STYLE_META):
		return ""
	return String((body as Node).get_meta(STYLE_META))


# ---------------------------------------------------------------- the match start
## Whether the match may read the store now: in the game (the player's own save), not in a script run (-s: the store would be the
## test file) unless a test or tool says so.
static func store_readable() -> bool:
	if read_store_in_scripts:
		return true
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


## What is worn for `element`: {picks, style, slot}. Classic (nothing worn, a broken slot, the master switch off, a script run) is
## no picks and no style: its class (AdvancementStore.set_style with Classic worn) is not played unless loadout_apply.json
## says classic_style. The store is only read.
static func worn(element: String) -> Dictionary:
	var none := {"picks": [], "style": "", "slot": -1}
	if not enabled() or not store_readable() or not element in Bending.ELEMENTS:
		return none
	var store := load(STORE_SCRIPT) as GDScript
	if store == null or not store.can_instantiate():
		return none
	var i := int(store.call(&"worn_index", element))
	var slot_ok := i >= 0 and String(store.call(&"slot_state", element, i)) == "worn"
	if not slot_ok and not bool(config().get("classic_style", false)):
		return none
	var lo: Variant = store.call(&"worn_loadout", element)          # (an AdvancementLoadout: picks, style)
	if not (lo is Object):
		return none
	var ps: Variant = (lo as Object).get(&"picks")
	return {"picks": (ps as Array).duplicate() if slot_ok and ps is Array else [], "style": String((lo as Object).get(&"style")),
			"slot": i if slot_ok else -1}


## RingMode.restart: the player's body takes what is worn for `element`.
static func wear_player(body: Node, element: String) -> void:
	if body == null:
		return
	var w := worn(element)
	wear(body, w.picks, String(w.style), element)


# ---------------------------------------------------------------- the readers' seams
## Spec `base` of move `m` at `mode`, with the wearer's numbers over it (`base` itself for Classic: no copy). Nested keys are
## merged (a spec's grow, fwd, back and side keep their other keys); `base` is never changed.
static func spec(body: Object, m: String, mode: String, base: Dictionary) -> Dictionary:
	var ov := overlay_of(body)
	if ov.is_empty():
		return base
	var over: Variant = (ov.get("spec", {}) as Dictionary).get("%s/%s" % [m, mode])
	return _merged(base, over as Dictionary) if over is Dictionary else base


static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k: String in over:
		if over[k] is Dictionary and out.get(k) is Dictionary:
			out[k] = _merged(out[k], over[k])
		else:
			out[k] = over[k]
	return out


## Move `m`'s lock at `mode` for `body`: `base` (the data's, before the stretch, the tier and lock_mult) or the wearer's own.
static func lock(body: Object, m: String, mode: String, base: float) -> float:
	var ov := overlay_of(body)
	if ov.is_empty():
		return base
	return float((ov.get("lock", {}) as Dictionary).get("%s/%s" % [m, mode], base))


## FormMatter.numbers for a wall of `matter` raised from `base` (earth_wall.wall) by `body`: kind "wall" is Earth Wall (the Wall
## mode), "ice" Ice Wall; the wearer's numbers over the base and, for snow, over the matter's own (materials.snow.hits).
static func wall_numbers(body: Object, kind: String, base: Dictionary, matter: String) -> Dictionary:
	var entry := FormMatter.entry("earth_wall", matter)
	var ov: Variant = overlay_of(body).get(kind)
	if not (ov is Dictionary) or (ov as Dictionary).is_empty():
		return FormMatter.numbers(base, entry, matter)
	var o := ov as Dictionary
	var b := base.duplicate()
	for k: String in o:
		if k != "materials":
			b[k] = o[k]
	var mats: Variant = o.get("materials")
	if mats is Dictionary and (mats as Dictionary).get(matter) is Dictionary:
		for k: String in (mats as Dictionary)[matter]:
			entry[k] = (mats as Dictionary)[matter][k]
	return FormMatter.numbers(b, entry, matter)
