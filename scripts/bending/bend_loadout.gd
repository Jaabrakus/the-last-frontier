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
##         pose   {"move/mode": clip}                a twist's own cast pose (a change pose:<move>/<mode>, from the element's
##                                                   clip to the twist's: the Lightning Pistol, the owner 2026-10-11 "have this
##                                                   or that and each has it perks and cons"); BendPoses.pick reads it for the
##                                                   wearer (pose_of) before his fighting style
##         tune   {path: number}                     a guard rule, passive, % ring rule or move number per wearer
##                                                   (TUNE_PATHS; tune(body, path, base) at each seam that reads it)
##         class  {tag: {d, base, growth, angle, set_stun, volley_n}}   the % ring numbers of the wearer's own hits with that
##                                                   tag (a change class:<tag>+<variant>.<key>, rules.json stock.classes; the
##                                                   owner 2026-10-11 on the tree: "fix it"): RingRules.on_hit puts them over
##                                                   the class when the hitter wears them (hit_class). The hit keeps its tag:
##                                                   staling, the range exemption and every other reader of a tag see the move
##                                                   it is (the tree's variant tags fold back to their base, as its
##                                                   proposed_classes ask); volley_n only beside the node's own spec count
##         class_when {flag: {tag: {key: number}}}   the same, only on the wearer's hits whose info carries `flag` (a class
##                                                   change with "when": <flag>, a behaviour node's own hits): beat, a cast let
##                                                   go on the Beat (Heave's Column); avalanche, the Avalanche's three rolling
##                                                   stones (never the Boulder's own hit before it lands)
##       A node whose change touches a number nothing reads per wearer is refused whole (never half applied), and so is one whose
##       data drifted from its `from` (the move was retuned after the tree was written), and one that requires a node that is
##       not live itself (Mud Lash's numbers without the Mud set's mud would be half the node). Picks worn together follow
##       the tree (2026-10-11, earth p2): its excludes refuse a pick either way; two that change one number the same way from
##       the same base multiply their ratios, a set twist's number final (overlay_for: _fold_n, _stack); the other way is refused.
##       A node whose switch (loadout_apply.json nodes) names another node is live only while that one is: a behaviour talent
##       that only acts on matter that node makes (Washout's and Cleanse's gas, earth's Sulphur set's), else its trade alone.
## Classic (nothing worn) is no meta at all: every reader asks `overlay_of(body)` first and gets {} (the same dictionaries it
## read before), so a body that wears nothing reads exactly today's numbers. A hit's cost (the `_lock_s` a blow carries, the
## victim's lock set-back) stays the move's own data lock: a talent changes its wearer's lock, never what a blow costs whom it hits.
##   wear_player(body, element)    RingMode.restart: the loadout worn for `element` (AdvancementStore, read only: the match never
##                                 writes the save) onto the player's body
##   wear(body, picks, style, el)  any body (tests, the soak): the live picks' overlay and the live style
##   overlay_of(body), picks_of(body), style_meta(body), clear(body)
##   spec(body, m, mode, spec), lock(body, m, mode, base), wall_numbers(body, kind, base, matter), hit_class(body, cls)
##                                 the readers' seams
##   modes_added(body, m), new_mode(body, m, mode), new_spec(body, m, mode), new_mode_label(m, mode)
##                                 a new mode a worn behaviour talent adds (its "new:<what>.spec": Mire on water's 4)
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
## What a body that wears nothing reads (shared and read-only: the readers never change what overlay_of gives them).
const NONE := {}
## The overlay's parts (a number or a pose a node changes per wearer).
const PARTS := ["spec", "lock", "wall", "ice", "pose", "class", "tune", "class_new", "class_when"]
## THE BEHAVIOUR TALENTS (2026-10-11, the owner: "make sure all the talents work and they work in game"): a node whose effect is
## new code (its changes hold a "new" or "new:<what>.<key>" entry, or a class:<tag>+<variant> with a whole new class) applies only
## once its id is in loadout_apply.json `behaviour` ({id: where the code is}): the game's code then asks wears(body, id) at the place
## the behaviour happens, and reads the node's own numbers through tune(body, "new:<what>.<key>", base) (a "new:" change with a
## number) or new_class(body, "<tag>+<variant>") (a whole class the node adds). A node not in the map is refused ("new behaviour
## not built"): it never half-applies. Classic (nothing worn) never reaches any of it.
## The keys of a hit's class a node may change for its wearer (what RingRules.on_hit reads off the class it is handed); the
## others (set, jab, pop, pull, dir, ...) are what a hit is, not how much.
const CLASS_KEYS := ["d", "base", "growth", "angle", "set_stun", "volley_n"]
## Spec keys a node may add where Classic's spec has none (its change's `from` is null): the code reads each as off when it is
## absent. bind_s: the skill tree's binds (BendR3.info_for puts it on the hit, RingRules.on_hit holds the feet: BendStatus.bind);
## prison_s: Wind Prison (BendZone: the Wind Wall holds whoever it catches in the air); drench_s: Drenching Wave (the hit carries
## it, RingRules.on_hit soaks him: BendStatus.drench).
const NEW_SPEC_KEYS := ["bind_s", "prison_s", "drench_s"]
## The tune part (2026-10-11, the owner: "make sure all the talents work and they work in game"): a guard rule, a passive, a %
## ring rule or a move's own number the wearer reads where the game reads it for him (tune(body, path, base); each path here has
## that seam, any other is refused). The change's path is the key: rules:guard_rules.<key> (Bending.rule), rules:passives.<el>.<key>
## (Bending.passive), stock:<key> or stock:<block>.<key> (rules.json stock), move:<move>.<key>... (moves.json; a rule a move may
## carry of its own, sputter_s or release_s, else the global rule).
const TUNE_PATHS := ["rules:guard_rules.perfect_mult", "rules:guard_rules.return_lock_s", "rules:guard_rules.rally_step",
		"rules:guard_rules.rally_clean_step", "stock:return_mult", "stock:rally.step", "stock:rally.clean",
		"rules:passives.earth.knock_mult", "rules:passives.earth.fill_mult", "stock:rooted_base", "stock:guard_perfect_s",
		"stock:late_mult", "rules:passives.water.steer_dps", "rules:passives.water.steer_max_deg", "rules:passives.water.steer_s",
		"rules:passives.air.after_s", "rules:passives.air.knock_mult", "stock:carried_mult", "move:stone_form.sputter_s",
		"move:stone_form.release_s", "move:stone_form.throw.hurl.spike.mps", "move:stone_form.throw.hurl.cannonball.mps",
		"move:stone_form.cannonball.radius_m",
		"rules:passives.fire.moving_mult",      # (fire's Footwork on the move: Hot Feet, Dancing Feet; SwayCaster._moving_mult)
		"set:magma.seam_life_s",                # (the Magma set's seams: Forge; FireTalents.seam_life)
		"stock:patch.lock_s"] + EARTH_TUNE_PATHS   # (Patch's ring lock, rules.json stock.patch: Cauterize's trade; FireTalents.patch_lock)
## Earth's (pass 1, 2026-10-11): the % ring's full-catch time (Juggle: RingRules.guard_outcome reads it for the guard's owner;
## that is the spec's reference answer, which no game code calls today: the game's own Catch ends its full catches at the spec's
## window_s, which the same node sets, so the per-wearer number here only keeps the reference agreeing with the game),
## and a skill set's own rule (set:<set>.<key>, the tree's skill_sets.<set>.zone: Sulphur's clouds, read by BendGas for the
## gas's owner; set_base).
const EARTH_TUNE_PATHS := ["stock:guard_catch_s", "set:sulphur.cloud_life_s", "set:sulphur.cloud_radius_m"]

## Tests only: merged over the file (enabled, live, styles_live replace; nodes merge by id).
static var config_override: Dictionary = {}
## Tests and tools only: let RingMode.restart read the store in a script run (-s). A script run's store file is the test file
## (AdvancementStore.TEST_PATH), never the player's own: left off, every test and tool plays Classic whatever that file holds.
static var read_store_in_scripts := false

static var _cfg: Dictionary = {}
static var _tree: Dictionary = {}                ## id -> the skill tree's node
static var _tree_root: Dictionary = {}           ## the skill tree as read (its beat, its skill sets)
static var _styles: Dictionary = {}              ## fighting_styles.json "styles"
static var _resolved: Dictionary = {}            ## id -> resolve()
static var _lib_exists: Dictionary = {}          ## library path -> whether the file is there (asked once)
static var _ok_memo: Dictionary = {}             ## style -> element -> style_ok, made under _ok_memo_cfg
static var _ok_memo_cfg: Variant = null          ## the config_override the memo was made under
static var _new_labels: Dictionary = {}          ## "move/mode" -> a new mode's label (new_mode_label)


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
	_tree_root = {}
	_styles = {}
	_resolved = {}
	_lib_exists = {}
	_ok_memo = {}
	_ok_memo_cfg = null
	_new_labels = {}


## The master switch (data/bending/loadout_apply.json "enabled"): off, no style and no number applies.
static func enabled() -> bool:
	return bool(config().get("enabled", false))


## Why node `id` is not live now ("" live): the master switch, the live list, its own switch, the reason it was refused, or a
## node it requires that is not live.
static func why_not(id: String) -> String:
	return _why_not(id, 0)


static func _why_not(id: String, depth: int) -> String:
	var c := config()
	if not bool(c.get("enabled", false)):
		return "the master switch is off"
	if not id in (c.get("live", []) as Array):
		return "not in the live list"
	var sw: Variant = (c.get("nodes", {}) as Dictionary).get(id, true)
	if sw is String:
		# (a node's switch that names another node: on while that node is live. A behaviour talent that only acts on matter
		# that node makes (Washout's and Cleanse's gas: earth's Sulphur set) would be its trade alone in a match without it)
		var ws := _why_not(String(sw), depth + 1) if depth < 4 else "too deep"
		if ws != "":
			return "waits for %s (%s)" % [String(sw), ws]
	elif not bool(sw):
		return "switched off"
	var r := resolve(id)
	if not bool(r.ok):
		return String(r.why)
	for q: Variant in _requires(id):
		var w := _why_not(String(q), depth + 1) if depth < 4 else "required too deep"
		if w != "":
			return "needs %s, which is not live (%s)" % [String(q), w]
	return ""


## The nodes node `id` must be worn with (its requires).
static func _requires(id: String) -> Array:
	var rq: Variant = _node(id).get("requires", [])
	return rq as Array if rq is Array else []


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
	if style == "" or element == "":
		return false
	# (asked every frame for a styled body's stance and held guard: answered once per config, then looked up; a new
	# config_override, as a test sets one, or reload_data asks again)
	if not is_same(_ok_memo_cfg, config_override):
		_ok_memo = {}
		_ok_memo_cfg = config_override
	var by: Variant = _ok_memo.get(style)
	if by is Dictionary and (by as Dictionary).has(element):
		return bool((by as Dictionary)[element])
	var ok := _style_ok(style, element)
	if not (by is Dictionary):
		by = {}
		_ok_memo[style] = by
	(by as Dictionary)[element] = ok
	return ok


static func _style_ok(style: String, element: String) -> bool:
	if not enabled():
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
		_tree_root = d if d is Dictionary else {}
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


## What node `id` changes, as an overlay part: {ok, why, el, spec, lock, wall, ice, pose, class}. Every change in the node's changes[] must be
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
	var out := {"ok": true, "why": "", "el": el, "spec": {}, "lock": {}, "wall": {}, "ice": {}, "pose": {}, "class": {}, "tune": {},
			"class_new": {}, "class_when": {}, "beat": false, "beat_on": [], "from": {},
			"final": String(n.get("set", "")) != "" and String(n.get("kind", "")) != "skill_set"}
	for c: Variant in (changes as Array):
		if not (c is Dictionary):
			return _refused("a change is not a dictionary")
		var why := _take(out, n, c as Dictionary)
		if why != "":
			return _refused(why)
	# (a built behaviour node whose new code is the Beat's: the held casts of its own move it pays on, beat_paid)
	out["beat_on"] = _beat_on(n)
	out["beat"] = not (out.beat_on as Array).is_empty()
	return out


## The held casts ("move/mode") Beat technique `n` pays on when let go on the Beat: loadout_apply.json `beat_on`[its id] when
## that names them (Quarry: the Fissure it lets go into its wall; Return to Sender: none, its Beat is the Catch's E again,
## BendZone.beat_return), else the node's own move and mode (Heave: "A Column let go on the Beat"; every "A <move> let go on the
## Beat" technique of the tree). [] for a node that is no Beat technique (not built, or none of its new changes says Beat): its
## wearer's other casts never pay, flash or carry info.beat (the tree's beat.pays: "only techniques").
static func _beat_on(n: Dictionary) -> Array:
	var id := String(n.get("id", ""))
	if not id in behaviour():
		return []
	var says := false
	for c: Variant in (n.get("changes", []) as Array):
		if c is Dictionary and String((c as Dictionary).get("path", "")).begins_with("new") \
				and (String((c as Dictionary).get("what", "")) + String((c as Dictionary).get("where", ""))).contains("Beat"):
			says = true
	if not says:
		return []
	var bo: Variant = config().get("beat_on")
	var named: Variant = (bo as Dictionary).get(id) if bo is Dictionary else null
	if named is Array:
		return (named as Array).duplicate()
	var mv := String(n.get("extends_move", ""))
	return ["%s/%s" % [mv, String(n.get("mode", ""))]] if mv != "" else []


## One change into `out` ("" taken, else why not).
static func _take(out: Dictionary, n: Dictionary, c: Dictionary) -> String:
	var path := String(c.get("path", ""))
	var kind := path.get_slice(":", 0)
	var rest := path.substr(kind.length() + 1)
	var to: Variant = c.get("to")
	var from: Variant = c.get("from")
	if kind == "pose":
		# pose:<move>/<mode>: the twist's own clip in place of the element's (`from`: the element's pick now; `to` a clip a pose
		# may play, BendPoses.usable)
		var mv0 := rest.get_slice("/", 0)
		var md0 := rest.substr(mv0.length() + 1)
		if mv0 == "" or md0 == "" or not (to is String) or not (from is String):
			return "%s: malformed" % path
		var ep := BendPoses.pick(mv0, md0, String(out.el))
		if String(ep.get("clip", "")) != String(from):
			return "%s: the element casts it with %s, the node says from %s" % [path, String(ep.get("clip", "-")), String(from)]
		if not BendPoses.usable(String(to)):
			return "%s: %s is no clip a pose may play" % [path, String(to)]
		return _put(out.pose as Dictionary, [rest], String(to))
	if kind == "class":
		return _take_class(out, n, path, rest, from, to)
	if path in TUNE_PATHS:
		return _take_tune(out, path, from, to)
	if kind == "set":
		# (set:<set>.<key>: a skill set's own rule, skill_tree.json skill_sets.<set>.zone, read by a behaviour talent's code through
		# tune(body, path, base): Delta's shorter mud pools)
		if not String(n.get("id", "")) in behaviour():
			return "%s: new behaviour not built" % path
		var cur_s: Variant = set_rule(rest.get_slice(".", 0), rest.get_slice(".", 1))
		if cur_s == null or not _same_shape_num(cur_s, from) or not _same_shape_num(from, to, true):
			return "%s: the data holds %s, the node says from %s" % [path, str(cur_s), str(from)]
		return _put_n(out, "tune", [path], to, from)
	if kind == "new" or path == "new":
		# (a behaviour talent's own code: only once it is built, its id in `behaviour`)
		if not String(n.get("id", "")) in behaviour():
			return "%s: new behaviour not built" % path
		if path == "new" or to == null:
			return ""
		if to is Dictionary and (to as Dictionary).get("bend") is Dictionary:
			# (a new mode the node adds to a move, its spec and its lock: modes_added)
			var nm := to as Dictionary
			var nmv := String(nm.get("move", ""))
			var nmd := String(nm.get("mode", ""))
			if nmv == "" or nmd == "" or SwayMoves.move(nmv).is_empty():
				return "%s: a new mode of no move" % path
			if (SwayMoves.move(nmv).get("bend", {}) as Dictionary).has(nmd) or nmd in (SwayMoves.move(nmv).get("modes", []) as Array):
				return "%s: %s/%s is a mode the move has" % [path, nmv, nmd]
			if nm.get("lock_s") is float or nm.get("lock_s") is int:
				var why_l := _put(out.lock as Dictionary, ["%s/%s" % [nmv, nmd]], float(nm.lock_s))
				if why_l != "":
					return why_l
		return _put_n(out, "tune", [path], to, from)
	# (a spec key Classic does not have, from none: NEW_SPEC_KEYS only, which the code reads as off when absent)
	var new_key := kind == "spec" and from == null and path.get_slice(".", path.get_slice_count(".") - 1) in NEW_SPEC_KEYS
	if not (to is float or to is int) or not (new_key or from is float or from is int):
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
		if new_key:
			if cur != null:
				return "%s: the data holds %s, the node says from none" % [path, str(cur)]
		elif cur == null or not is_equal_approx(float(cur), float(from)):
			return "%s: the data holds %s, the node says from %s" % [path, str(cur), str(from)]
		if not _consumed(mv, mode, sub) and not String(n.get("id", "")) in behaviour():
			return "%s: no code reads this number" % path
		return _put_n(out, "spec", ["%s/%s" % [mv, mode]] + sub, to, from)
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
		# the move's lock, scoped to the node's own mode (Step's lock is not Hop's); a move with no modes (Mend) its "" mode
		var md := String(n.get("mode", ""))
		var mlk: Variant = mdata.get("mode_lock_s", {})
		var modeless := md == "" and SwayCaster.modes_of(mv2).is_empty()
		if (md == "" and not modeless) or (mlk is Dictionary and (mlk as Dictionary).has(md)):
			return "%s: no single base lock for mode %s" % [path, md]
		if not is_equal_approx(float(mdata.get("lock_s", -1.0)), float(from)):
			return "%s: the data holds %s, the node says from %s" % [path, str(mdata.get("lock_s")), str(from)]
		return _put_n(out, "lock", ["%s/%s" % [mv2, md]], to, from)
	if tail[0] == "mode_lock_s" and tail.size() == 2:
		var mlk2: Variant = mdata.get("mode_lock_s", {})
		if not (mlk2 is Dictionary) or not (mlk2 as Dictionary).has(tail[1]) or not is_equal_approx(float((mlk2 as Dictionary)[tail[1]]), float(from)):
			return "%s: the data does not hold from %s" % [path, str(from)]
		return _put_n(out, "lock", ["%s/%s" % [mv2, tail[1]]], to, from)
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
			return _put_n(out, bucket, sub2, to, from)
		if bucket == "ice" and sub2.size() == 3 and sub2[0] == "materials" and sub2[1] == "snow" and sub2[2] == "hits":
			return _put_n(out, "ice", sub2, to, from)
		return "%s: no builder reads this per wearer" % path
	return "%s: no code reads this number per wearer" % path


## A tune change (TUNE_PATHS): `from` the game's number now (an array of numbers for a hurl's speeds), `to` of the same shape,
## into the tune part under its path ("" taken, else why not).
static func _take_tune(out: Dictionary, path: String, from: Variant, to: Variant) -> String:
	var cur: Variant = tune_base(path)
	if cur == null:
		return "%s: the game holds no such number" % path
	if not _same_shape_num(cur, from) or not _same_shape_num(from, to, true):
		return "%s: the data holds %s, the node says from %s" % [path, str(cur), str(from)]
	return _put_n(out, "tune", [path], to, from)


## The game's own number at tune path `path` (null: none).
static func tune_base(path: String) -> Variant:
	var kind := path.get_slice(":", 0)
	var keys: Array = Array(path.substr(kind.length() + 1).split("."))
	match kind:
		"rules":
			if keys.size() == 2 and keys[0] == "guard_rules":
				return Bending.rules().get(String(keys[1]))
			if keys.size() == 3 and keys[0] == "passives":
				return Bending.passive(String(keys[1])).get(String(keys[2]))
		"stock":
			if keys.size() == 1:
				return (RingRules.data().get("stock", {}) as Dictionary).get(String(keys[0]))
			if keys.size() == 2:
				return RingRules.stock_block(String(keys[0])).get(String(keys[1]))
		"set":
			# (a skill set's rule: data/sway/skill_tree.json skill_sets.<set>.zone.<key>)
			if keys.size() == 2:
				var t: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH)) if FileAccess.file_exists(TREE_PATH) else null
				var zd: Variant = (((t as Dictionary).get("skill_sets", {}) as Dictionary).get(String(keys[0]), {}) as Dictionary).get("zone") \
						if t is Dictionary else null
				return (zd as Dictionary).get(String(keys[1])) if zd is Dictionary else null
		"move":
			var md := SwayMoves.move(String(keys[0]))
			var v2: Variant = _dig(md, keys.slice(1))
			if v2 == null and keys.size() == 2 and String(keys[1]) in ["sputter_s", "release_s"]:
				return Bending.rule("sputter_s", 0.7) if keys[1] == "sputter_s" else SwayMoves.lock_rule("release_s", 1.0)
			return v2
		"set":
			if keys.size() == 2:
				return set_rule(String(keys[0]), String(keys[1]))
	return null


## A skill set's own rule (data/sway/skill_tree.json skill_sets.<set>.zone.<key>: Sulphur's cloud_radius_m, cloud_life_s, ...),
## null none. The game's number for everyone wearing the set; a node's set:<set>.<key> change makes it the wearer's own.
static func set_rule(set_name: String, key: String) -> Variant:
	_node("_")                                   # (the tree read)
	var z: Variant = _dig(_tree_root, ["skill_sets", set_name, "zone", key])
	return z if (z is float or z is int) else null


## The Beat (the skill tree's beat: a held cast let go within window_s after its lock fills; a Catch's E again within it of a
## clean catch): its window (s). It pays only a worn technique (beat_paid).
static func beat_s() -> float:
	_node("_")
	var w: Variant = _dig(_tree_root, ["beat", "window_s"])
	return float(w) if (w is float or w is int) else 0.2


## Whether `body` wears a live technique that pays on the Beat for a held cast of move `m` at `mode` (its beat_on: the node's
## own move, _beat_on); `m` "": any of his casts (whether he wears a Beat technique at all). Classic, every other loadout and
## every other move: false, the Beat does nothing and shows nothing.
static func beat_paid(body: Object, m := "", mode := "") -> bool:
	if not _wears(body):
		return false
	var ov := overlay_of(body)
	if m == "":
		return bool(ov.get("beat", false))
	var on: Variant = ov.get("beat_on")
	return on is Array and ("%s/%s" % [m, mode]) in (on as Array)


## Whether `a` and `b` are the same number (or arrays of the same numbers; `shape_only`: only the same shape).
static func _same_shape_num(a: Variant, b: Variant, shape_only := false) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return shape_only or is_equal_approx(float(a), float(b))
	if a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i in (a as Array).size():
			if not _same_shape_num((a as Array)[i], (b as Array)[i], shape_only):
				return false
		return true
	return false


## class:<tag>+<variant>.<key>: key `key` of the class of the wearer's hits with `tag` (rules.json stock.classes), `from` the
## data's, into the overlay's class part as {tag: {key: to}} ("" taken, else why not). A change with no key (a whole class: a hit
## the node adds, Surfacing's, the Reel's) is no number; nor is a key that says what the hit is (set, dir, pull). A volley's
## count (volley_n) only beside the node's own spec count for that move and mode: the hits a volley's % is spread over are the
## cast's (BendEffects.apply writes its count on the hit), the class's count only stands in where the hit carries none.
static func _take_class(out: Dictionary, n: Dictionary, path: String, rest: String, from: Variant, to: Variant) -> String:
	var plus := rest.find("+")
	var dot := rest.find(".", plus + 1) if plus > 0 else -1
	if plus <= 0 or dot < 0:
		if to is Dictionary and from == null and String(n.get("id", "")) in behaviour():
			# (a behaviour talent's whole new class: new_class(body, "<tag>+<variant>"))
			return _put(out["class_new"] as Dictionary, [rest], to)
		return "%s: a hit the node adds, not a number of one" % path
	var tag := rest.substr(0, plus)
	var key := rest.substr(dot + 1)
	if not (to is float or to is int) or not (from is float or from is int):
		return "%s: not a number" % path
	if not key in CLASS_KEYS:
		return "%s: %s says what the hit is, not how much" % [path, key]
	var base: Variant = RingRules.stock_block("classes").get(tag)
	if not (base is Dictionary):
		return "%s: no class %s" % [path, tag]
	var cur: Variant = (base as Dictionary).get(key)
	var c := _change_of(n, path)
	if cur == null and bool(c.get("default_from", false)) and key == "volley_n":
		cur = 1                                    # (a class with no volley_n is one projectile: the node's from is that default)
	if cur == null or not is_equal_approx(float(cur), float(from)):
		return "%s: the data holds %s, the node says from %s" % [path, str(cur), str(from)]
	var built := String(n.get("id", "")) in behaviour()
	if key == "volley_n" and not _counts_with(n, tag, to) and not (built and _has_new(n)):
		return "%s: no spec count of the node's own beside it" % path
	var when := String(c.get("when", ""))
	if when != "":
		if not built:
			return "%s: a class when %s needs its node's new code" % [path, when]
		# (only the node's own hits whose info says so take it: hit_class; beat, a cast let go on the Beat (Heave); avalanche,
		# the Avalanche's rolling stones)
		return _put_n(out, "class_when", [when, tag, key], to, from)
	return _put_n(out, "class", [tag, key], to, from)


## Node `n`'s change at `path` ({} none).
static func _change_of(n: Dictionary, path: String) -> Dictionary:
	for c: Variant in (n.get("changes", []) as Array):
		if c is Dictionary and String((c as Dictionary).get("path", "")) == path:
			return c as Dictionary
	return {}


## Whether node `n` has a "new" change (its own code makes what the number is of: the Avalanche's three stones).
static func _has_new(n: Dictionary) -> bool:
	for c: Variant in (n.get("changes", []) as Array):
		if c is Dictionary and String((c as Dictionary).get("path", "")).begins_with("new"):
			return true
	return false


## Whether node `n` also changes the spec count of the move and mode `tag` names to `to`.
static func _counts_with(n: Dictionary, tag: String, to: Variant) -> bool:
	for c: Variant in (n.get("changes", []) as Array):
		if c is Dictionary and String((c as Dictionary).get("path", "")) == "spec:%s.count" % tag \
				and is_equal_approx(float((c as Dictionary).get("to", -1.0)), float(to)):
			return true
	return false


## Whether game code reads spec key path `sub` of move `mv` at `mode` for the wearer's own cast (BendEffects.apply merges the
## overlay in before anything reads the spec). The Skate's puddles are in the data but Classic's Skate makes none: only a built
## behaviour talent's own code reads them (Wet Trail's, BendEffects._wet_trail: _take lets a node in `behaviour` through).
static func _consumed(_mv: String, _mode: String, sub: Array) -> bool:
	return String(sub[0]) != "puddles"


static func _dig(d: Variant, keys: Array) -> Variant:
	var cur: Variant = d
	for k: Variant in keys:
		if not (cur is Dictionary) or not (cur as Dictionary).has(String(k)):
			return null
		cur = (cur as Dictionary)[String(k)]
	return cur


## A number `to` at nested `keys` of part `part` of a node's resolve `out`, with [its `from` (the data's), whether the node is a
## set twist] beside it under out.from (the tree's stacking reads them: overlay_for, _fold_n) ("" put, else why not).
static func _put_n(out: Dictionary, part: String, keys: Array, to: Variant, from: Variant) -> String:
	var why := _put(out[part] as Dictionary, keys, to)
	if why == "" and (from is float or from is int) and (to is float or to is int):
		var fr: Dictionary = out["from"]
		if not fr.has(part):
			fr[part] = {}
		_put(fr[part] as Dictionary, keys, [from, bool(out.get("final", false))])
	return why


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
## The overlay of `picks` for a body that casts as `element` (""): {spec, lock, wall, ice, pose, class, ids (applied), refused
## {id: why}}. A pick that is not live, of another element, worn without a node it requires, beside a node the tree's excludes
## keep it from (either way), or that pulls a number another already set the other way (or sets a pose or a whole class twice),
## applies nothing. Two picks that change one number the same way from the same base stack as the tree's "stacking" says
## (_fold_n: their ratios multiply; a set twist's number is final).
static func overlay_for(picks: Array, element := "") -> Dictionary:
	var out := {"spec": {}, "lock": {}, "wall": {}, "ice": {}, "pose": {}, "class": {}, "tune": {}, "class_new": {}, "class_when": {},
			"ids": [], "refused": {}, "from": {}}
	for v: Variant in picks:
		var id := String(v)
		var why := why_not(id)
		var r := resolve(id) if why == "" else {}
		if why == "" and element != "" and String(r.el) != element:
			why = "another element's"
		if why == "" and id in (out.ids as Array):
			why = "twice"
		if why == "":
			for q: Variant in _requires(id):
				if not q in picks:
					why = "worn without %s" % String(q)
					break
		if why == "":
			why = _excluded(id, out.ids as Array)
		if why != "":
			(out.refused as Dictionary)[id] = why
			continue
		var trial := {}
		for part: String in PARTS:
			trial[part] = (out[part] as Dictionary).duplicate(true)
		var trial_from: Dictionary = (out["from"] as Dictionary).duplicate(true)
		var rf: Dictionary = r.get("from", {})
		var clash := ""
		for part: String in PARTS:
			if not (trial_from.get(part) is Dictionary):
				trial_from[part] = {}
			clash = _fold_n(trial[part] as Dictionary, r.get(part, {}) as Dictionary, trial_from[part] as Dictionary,
					rf.get(part, {}) as Dictionary)
			if clash != "":
				break
		if clash != "":
			(out.refused as Dictionary)[id] = clash
			continue
		for part: String in PARTS:
			out[part] = trial[part]
		out["from"] = trial_from
		(out.ids as Array).append(id)
		if bool(r.get("beat", false)):
			out["beat"] = true
			if not (out.get("beat_on") is Array):
				out["beat_on"] = []
			for k: Variant in (r.get("beat_on", []) as Array):
				if not k in (out.beat_on as Array):
					(out.beat_on as Array).append(k)
	return out


## Why node `id` may not be worn beside the nodes `worn` (the skill tree's excludes, either way; "" none).
static func _excluded(id: String, worn: Array) -> String:
	var ex: Variant = _node(id).get("excludes", [])
	for x: Variant in (ex as Array if ex is Array else []):
		if String(x) in worn:
			return "excludes %s" % String(x)
	for w: Variant in worn:
		var wx: Variant = _node(String(w)).get("excludes", [])
		if wx is Array and id in (wx as Array):
			return "excluded by %s" % String(w)
	return ""


## `src` folded into `into` as the skill tree's "stacking" says: a number two nodes change the same way from the same base
## multiplies their ratios (into x src / from: 0.7 s x 0.8/0.7 x 0.8/0.7), unless one of them is a set twist (its number is
## final for that move: it stands, the other's is dropped); the other way, from another base, or not a number (a pose, a whole
## class) is a clash: returns where, else "". `into_f` and `src_f` hold their [from, set twist] leaves (_put_n), kept beside.
static func _fold_n(into: Dictionary, src: Dictionary, into_f: Dictionary, src_f: Dictionary) -> String:
	for k: String in src:
		if src[k] is Dictionary:
			if into.has(k) and not (into[k] is Dictionary):
				return k
			if not into.has(k):
				into[k] = {}
			if not (into_f.get(k) is Dictionary):
				into_f[k] = {}
			var sf: Variant = src_f.get(k)
			var why := _fold_n(into[k], src[k], into_f[k], sf as Dictionary if sf is Dictionary else {})
			if why != "":
				return "%s.%s" % [k, why]
		elif into.has(k):
			var st := _stack(into[k], src[k], into_f.get(k), src_f.get(k))
			if st.is_empty():
				return k
			into[k] = st[0]
			into_f[k] = st[1]
		else:
			into[k] = src[k]
			if src_f.has(k):
				into_f[k] = src_f[k]
	return ""


## Two nodes' numbers `a` (worn so far) and `b` for one key, with their [from, set twist] `fa` and `fb` (null: no from): [the
## number worn, its [from, set twist]], or [] a clash (_fold_n).
static func _stack(a: Variant, b: Variant, fa: Variant, fb: Variant) -> Array:
	if not (fa is Array and fb is Array) or not (a is float or a is int) or not (b is float or b is int):
		return []
	var f := float((fa as Array)[0])
	if absf(f) < 1e-9 or not is_equal_approx(f, float((fb as Array)[0])):
		return []
	var da := signf(float(a) - f)
	if da == 0.0 or da != signf(float(b) - f):
		return []                                  # (opposite pulls: never worn together)
	var ta := bool((fa as Array)[1])
	var tb := bool((fb as Array)[1])
	if ta and tb:
		return []
	if ta:
		return [a, fa]
	if tb:
		return [b, fb]
	var v := float(a) * float(b) / f
	if a is int and b is int and (fa as Array)[0] is int:
		return [roundi(v), fa]
	return [v, fa]


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
		return NONE
	var ov: Variant = (body as Node).get_meta(OVERLAY_META)
	return ov if ov is Dictionary else NONE


## Whether `body` wears numbers (the readers' first question: Classic answers it with one meta lookup, nothing made).
static func _wears(body: Object) -> bool:
	return body != null and is_instance_valid(body) and body is Node and (body as Node).has_meta(OVERLAY_META)


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
	if not _wears(body):
		return base
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


## The clip a worn twist casts move `m` at `mode` with ("" none: the element's own pick, or the style's): the overlay's pose
## (BendPoses.pick asks it first for the wearer).
static func pose_of(body: Object, m: String, mode: String) -> String:
	if not _wears(body):
		return ""
	var ov := overlay_of(body)
	if ov.is_empty():
		return ""
	return String((ov.get("pose", {}) as Dictionary).get("%s/%s" % [m, mode], ""))


## The class `cls` (RingRules.class_of's: tagged, its growth scaled) of a hit by `body`, with the wearer's own numbers for its
## tag over it (`cls` itself for Classic or a tag he changes nothing of: no copy). A growth is scaled as class_of scales the
## data's. The tag stays the move's. `info` the hit's: one whose info carries a node's flag takes the wearer's class_when for it
## over that (info.beat, sent on the Beat by SwayCaster's release and BendR3.info_for: Heave's Column; info.avalanche: the
## Avalanche's rolling stones, GustLift._avalanche). A returned hit's class (RingRules.return_class: its tag
## "<origin>.return", which no node's class change names) asks here too: only a Kiln Stone's heat reaches it (info.heated).
static func hit_class(body: Object, cls: Dictionary, info := {}) -> Dictionary:
	if cls.is_empty() or not _wears(body):
		return cls
	var ov := overlay_of(body)
	var tag := String(cls.get("tag", ""))
	var over: Variant = (ov.get("class", {}) as Dictionary).get(tag)
	# (a node's class "when" <flag>: only on his hits whose info carries the flag; beat: let go on the Beat, Heave's Column)
	var whens: Array = [over]
	var cw: Variant = ov.get("class_when")
	if cw is Dictionary:
		for f: String in (cw as Dictionary):
			if bool(info.get(f, false)) and ((cw as Dictionary)[f] as Dictionary).get(tag) is Dictionary:
				whens.append(((cw as Dictionary)[f] as Dictionary)[tag])
	# (Kiln Stone: a stone of his heated by fire it crossed, BendZone.KILN_STONE: its launch base higher)
	var heated := bool(info.get("heated", false)) and wears(body, BendZone.KILN_STONE)
	if not (over is Dictionary) and whens.size() == 1 and not heated:
		return cls
	var out := cls.duplicate()
	for o: Variant in whens:
		if o is Dictionary:
			for k: String in o:
				out[k] = float(o[k]) * (RingRules.stock_num("growth_scale", 1.0) if k == "growth" else 1.0)
	if heated:
		out["base"] = float(out.get("base", 0.0)) * BendZone.KILN_MULT
	return out


## The behaviour talents built (loadout_apply.json behaviour: {id: where its code is}).
static func behaviour() -> Dictionary:
	var b: Variant = config().get("behaviour", {})
	return b if b is Dictionary else {}


## Whether `body` wears node `id` live now (a behaviour talent's code asks this where the behaviour happens; Classic: false).
static func wears(body: Object, id: String) -> bool:
	return _wears(body) and id in picks_of(body)


## A NEW MODE (a new skill on an empty double tap, the tree's answer yes: Mire on water's 4, water_shield's "mire"): a behaviour
## talent's change "new:<what>.spec" holds {move, mode, label, lock_s, pose_as, bend} (never moves.json: the Classic fingerprint
## lists every bend spec there). For its wearer alone: modes_added (SwayCaster.modes_of with a body: the keys, the strip, the
## wheel, a bot's options), new_spec (the cast: SwayCaster.spec_of, FormEffects.apply, BendCast.cast, NpcBending.spec_of), its
## lock_s in the lock part (lock()), pose_as the mode whose pose it is cast with (BendPoses.pick), label its name
## (new_mode_label: SwayCaster.mode_label). Classic (nothing worn): none of it, no copy made.
static func modes_added(body: Object, m: String) -> Array:
	var out: Array = []
	if not _wears(body):
		return out
	for e: Dictionary in _new_modes(body):
		if String(e.get("move", "")) == m and not String(e.get("mode", "")) in out:
			out.append(String(e.get("mode", "")))
	return out


## The new mode `mode` of move `m` that `body` wears ({move, mode, label, lock_s, pose_as, bend}; {} none).
static func new_mode(body: Object, m: String, mode: String) -> Dictionary:
	if not _wears(body) or mode == "":
		return {}
	for e: Dictionary in _new_modes(body):
		if String(e.get("move", "")) == m and String(e.get("mode", "")) == mode:
			return e
	return {}


## The bend spec of the new mode `mode` of move `m` that `body` wears ({} none: Classic, or a mode moves.json has).
static func new_spec(body: Object, m: String, mode: String) -> Dictionary:
	var b: Variant = new_mode(body, m, mode).get("bend")
	return b as Dictionary if b is Dictionary else {}


static func _new_modes(body: Object) -> Array:
	var out: Array = []
	var t: Variant = overlay_of(body).get("tune")
	if t is Dictionary:
		for k: String in t:
			if k.begins_with("new:") and k.ends_with(".spec") and t[k] is Dictionary and (t[k] as Dictionary).get("bend") is Dictionary:
				out.append(t[k])
	return out


## The name of the new mode `mode` of move `m` a built behaviour talent adds ("" none): read once from the tree.
static func new_mode_label(m: String, mode: String) -> String:
	if _new_labels.is_empty():
		_new_labels["_read"] = ""
		for id: String in behaviour():
			for c: Variant in (_node(id).get("changes", []) as Array):
				var to: Variant = (c as Dictionary).get("to") if c is Dictionary else null
				if to is Dictionary and (to as Dictionary).get("bend") is Dictionary:
					var td := to as Dictionary
					_new_labels["%s/%s" % [String(td.get("move", "")), String(td.get("mode", ""))]] = String(td.get("label", ""))
	return String(_new_labels.get("%s/%s" % [m, mode], ""))


## A whole class a worn behaviour talent adds ("<tag>+<variant>" as its change names it; {} none).
static func new_class(body: Object, key: String) -> Dictionary:
	if not _wears(body):
		return {}
	var c: Variant = (overlay_of(body).get("class_new", {}) as Dictionary).get(key)
	return c as Dictionary if c is Dictionary else {}


## The class (RingRules.class_of's shape: tagged, its growth scaled) of a hit by `body` tagged `tag`, a worn behaviour talent's
## whole new class ("<tag>+<variant>" as its change names it; {} none: RingRules.on_hit then reads the hit as untagged).
static func new_hit_class(body: Object, tag: String) -> Dictionary:
	var nc := new_class(body, tag)
	if nc.is_empty():
		return {}
	var out := nc.duplicate()
	out["tag"] = tag
	out["growth"] = float(out.get("growth", 0.0)) * RingRules.stock_num("growth_scale", 1.0)
	return out


## The wearer's own number at tune path `path` (TUNE_PATHS), else `base` (the game's: Classic reads it unchanged).
static func tune(body: Object, path: String, base: Variant) -> Variant:
	if not _wears(body):
		return base
	var t: Variant = overlay_of(body).get("tune")
	return (t as Dictionary).get(path, base) if t is Dictionary else base


## tune() as a float.
static func tune_f(body: Object, path: String, base: float) -> float:
	return float(tune(body, path, base))


## Move `m`'s lock at `mode` for `body`: `base` (the data's, before the stretch, the tier and lock_mult) or the wearer's own.
static func lock(body: Object, m: String, mode: String, base: float) -> float:
	if not _wears(body):
		return base
	var ov := overlay_of(body)
	if ov.is_empty():
		return base
	return float((ov.get("lock", {}) as Dictionary).get("%s/%s" % [m, mode], base))


## FormMatter.numbers for a wall of `matter` raised from `base` (earth_wall.wall) by `body`: kind "wall" is Earth Wall (the Wall
## mode), "ice" Ice Wall; the wearer's numbers over the base and, for snow, over the matter's own (materials.snow.hits).
static func wall_numbers(body: Object, kind: String, base: Dictionary, matter: String) -> Dictionary:
	var entry := FormMatter.entry("earth_wall", matter)
	var ov: Variant = overlay_of(body).get(kind) if _wears(body) else null
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


# ---------------------------------------------------------------- the new skills (a worn talent's own mode of a move)
## THE NEW SKILLS (2026-10-11, the owner's yes to the tree's draft: new skills on the empty double taps): a node of kind
## new_skill (its slot: key, tap twice, on <move>) adds a mode of its move for its wearer alone. Its spec is moves.json
## <move>.talent_bend.<mode>: a bend spec with `talent` (the node's id: only its wearer casts it), its own `lock_s`, `label` (its
## name on the bar) and `pose_as` (the move's mode whose pose it is cast with). Never in the move's modes or bend, so the Classic
## fingerprint, the static kit (SwayCaster.modes_of: the HUD's key words, the quick spell, the radial wheel, Bending.first_of) and
## every bot of a normal match never see it; built once for every element (any move's talent_bend, any node). The seams ask here
## with the body, and a body that wears nothing answers each with one meta lookup:
##   modes_for(body, id, base)          SwayCaster.my_modes, Bending.other_move (4 tapped twice, a wheel step), BodyBendCaster
##                                      .mode_of, a bot's options (NpcBending._build_options: talent_pairs)
##   talent_spec(body, m, mode)         SwayCaster.spec_of, FormEffects.apply, BendCast.cast (the player's cast and a bot's)
##   talent_lock(body, m, mode, base)   SwayCaster._lock_time, NpcBending.lock_for
##   pose_mode(body, m, mode)           BendPoses.pick (the body's pose)
##   talent_label(m, mode)              SwayCaster.mode_label's fallback
## The first: earth's Sulphur Vent (earth.sulphur.vent: earth_wall.talent_bend.vent, BendGas.vent).
static func talent_modes(body: Object, id: String) -> Array:
	if not _wears(body):
		return []
	var tb: Variant = SwayMoves.move(id).get("talent_bend")
	if not (tb is Dictionary):
		return []
	var out: Array = []
	for md: String in (tb as Dictionary):
		var s: Variant = (tb as Dictionary)[md]
		if not md.begins_with("_") and s is Dictionary and wears(body, String((s as Dictionary).get("talent", ""))):
			out.append(md)
	return out


## Move `id`'s ring modes for `body`: `base` (null: SwayCaster.modes_of(id), the move's) and the modes his worn talents add after
## them: a moves.json talent_bend mode (talent_modes: the Sulphur Vent) and a mode the tree's node itself adds (modes_added:
## Mire) (`base` itself, never a copy, when he adds none: Classic reads the very array it read before).
static func modes_for(body: Object, id: String, base: Variant = null) -> Array:
	var ms: Array = base as Array if base is Array else SwayCaster.modes_of(id)
	var ex := talent_modes(body, id)
	for md: String in modes_added(body, id) + FireTalents.modes_for(body, id, []):
		if not md in ex and not md in ms:
			ex.append(md)                        # (a mode the tree's node adds: Mire; fire's own new skill: Cauterize)
	return ms if ex.is_empty() else ms + ex


## Every [move, mode] of element `el`'s keys a worn talent of `body`'s adds ([] Classic): a bot's own options.
static func talent_pairs(body: Object, el: String) -> Array:
	var out: Array = []
	if not _wears(body):
		return out
	for key: Variant in Bending.keys(el):
		for id: Variant in (key as Array):
			for md: String in talent_modes(body, String(id)) + modes_added(body, String(id)):
				if not [String(id), md] in out:
					out.append([String(id), md])
	return out


## The spec of move `m`'s talent mode `mode` when `body` wears its node ({} else: Classic, another mode, not worn). Shared and
## read-only (BendEffects.apply copies it before it reads it).
static func talent_spec(body: Object, m: String, mode: String) -> Dictionary:
	if not _wears(body) or mode == "":
		return {}
	var tb: Variant = SwayMoves.move(m).get("talent_bend")
	if not (tb is Dictionary) or not ((tb as Dictionary).get(mode) is Dictionary):
		return {}
	var s: Dictionary = (tb as Dictionary)[mode]
	return s if wears(body, String(s.get("talent", ""))) else {}


## A worn talent mode's own lock (its spec's lock_s; the caller's stretch, tier and lock_mult still apply), else `base`.
static func talent_lock(body: Object, m: String, mode: String, base: float) -> float:
	var s := talent_spec(body, m, mode)
	return float(s.get("lock_s", base)) if not s.is_empty() else base


## The mode whose cast pose a worn talent mode plays (its spec's pose_as: one of the move's own), else `mode`.
static func pose_mode(body: Object, m: String, mode: String) -> String:
	var s := talent_spec(body, m, mode)
	return String(s.get("pose_as", mode)) if not s.is_empty() else mode


## A talent mode's name (its spec's label: "Sulphur Vent"), else `mode` (SwayCaster.mode_label's fallback: no body asked, a
## name is no number).
static func talent_label(m: String, mode: String) -> String:
	var tb: Variant = SwayMoves.move(m).get("talent_bend")
	if tb is Dictionary and (tb as Dictionary).get(mode) is Dictionary:
		return String(((tb as Dictionary)[mode] as Dictionary).get("label", mode))
	return mode
