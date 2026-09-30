class_name AnimGraphData
extends RefCounted
## Read-only access to the two generated animation tables (plan sections 5.3, 5.4; WP3):
##
##   animations/actor_b_graph.json          tools/anim_graph/export_actor_b_graph.py (WP1)
##   animations/actor_b_clip_metrics.json   tools/anim_graph/measure_clips.gd (WP2)
##
## Numeric asset IDs, symbol IDs and record offsets are kept as the exporter wrote them
## (meta.attribution carries the provenance text).
##
## Clip names are Godot action names of the `actor_b` library ("actor_b-p-run-fw"); godot_anim()
## gives the library path. resolve_alias() maps original / source / graph names to the action.
##
## Gameplay overrides (graph `gameplay_overrides`, all off by default = graph-faithful): the
## runtime turns one on with set_override(flag, true); transition_use() and option() then return
## the override's values (for example override_fast_hemisphere_fade gives hemi_fw_to_bw 0.3 s
## instead of the graph's 0.75 s). The flags are exposed to gameplay as @export toggles by
## PlayerAnim ("Gameplay overrides" group).
##
##   var data := AnimGraphData.load_files()
##   data.role("musket", "run", "fw").clip          # "actor_b-p-run-fw"
##   data.transition_use("hemi_fw_to_bw").fade_s     # 0.75 (0.3 with the G2 override)

const GRAPH_PATH := "res://animations/actor_b_graph.json"
const METRICS_PATH := "res://animations/actor_b_clip_metrics.json"
## Clips that stand in for the graph's own (tools/anim_author/author_locomotion.gd writes it): graph clip name ->
## {lib, clip, speed, length}; the libraries they live in, by name.
const CLIP_OVERRIDES_PATH := "res://data/anim_author/locomotion_clips.json"
## Arm layers the roles take in place of their own (tools/anim_author/author_locomotion.gd writes it).
const CARRY_PATCHES_PATH := "res://data/anim_author/carry_patches.json"
const OVERRIDE_LIBS := {"frontier_locomotion": "res://animations_extra/Frontier_Locomotion.res"}
const FIXTURE_GRAPH := "res://tools/anim_graph/fixtures/mini_graph.json"
const FIXTURE_METRICS := "res://tests/anim/fixtures/mini_metrics.json"
const LIB := &"actor_b"
const WEAPON_ORDER := ["bow", "musket", "pistol", "spear", "tomahawk", "atlatl"]
const MODE_ORDER := ["walk", "run", "sprint", "crouch"]
const STANCES := ["stand", "crouch"]
const DIRS := ["fw", "bw", "lt", "rt"]
## Lower-body direction banks: input group -> {hemisphere: bank_roles key}. The "fw" hemisphere
## uses the forward chain mapping (x = blend angle; -90 = *_rt, +90 = *_lt), "bw" the backward
## one (x = angle-mod(int(a) + 180); -90 = *_lt, +90 = *_rt), as in the graph's run-fw / run-bkwd
## trees. A reversal is named by the hemisphere it ends in: rev_bw_fw (run-bw^run-fwd) is "fw".
const BANK_GROUPS := {
	"move": {"fw": "move_fw", "bw": "move_bw"},
	"start": {"fw": "start_fw", "bw": "start_bw"},
	"stop": {"fw": "stop_fw", "bw": "stop_bw"},
	"rev": {"fw": "rev_bw_fw", "bw": "rev_fw_bw"},
}

var graph := {}
var metrics := {}
var graph_path := ""
var metrics_path := ""
var errors := PackedStringArray()
var warnings := PackedStringArray()

var _overrides := {}          ## flag -> bool
var _option_set := {}         ## option -> value set at runtime (wins over overrides)
var _alias := {}              ## any known name -> action name
var _alias_ambiguous := {}    ## name -> [action names]
var _bank_role_names := {}    ## role -> true
var _override_libs := {}      ## library name -> resource path, of the clips standing in for the graph's own

static var _json_cache := {}  ## path -> [modified_time, Dictionary]


## Loads and indexes both tables. The metrics file is optional (an empty path or a missing file
## gives empty metrics and a warning). Returns null when the graph cannot be read.
static func load_files(p_graph := GRAPH_PATH, p_metrics := METRICS_PATH) -> AnimGraphData:
	var g := _read_json(p_graph)
	if g.is_empty():
		push_error("AnimGraphData: cannot read graph table %s" % p_graph)
		return null
	var m := {}
	if p_metrics != "":
		m = _read_json(p_metrics)
	var d := AnimGraphData.from_dicts(g, m)
	if p_graph == GRAPH_PATH:
		d.apply_clip_overrides()
		d.apply_carry_patches()
	d.graph_path = p_graph
	d.metrics_path = p_metrics
	if p_metrics != "" and m.is_empty():
		d.warnings.append("metrics table %s not readable; clip speeds, bone sets and pitch tables fall back" % p_metrics)
	return d


## The day-1 fixtures (1 weapon x 2 modes).
static func load_fixture() -> AnimGraphData:
	return load_files(FIXTURE_GRAPH, FIXTURE_METRICS)


## Wraps already parsed tables (tests use this for doctored copies). The dictionaries are not
## copied; treat them as read-only afterwards.
static func from_dicts(g: Dictionary, m := {}) -> AnimGraphData:
	var d := AnimGraphData.new()
	d.graph = g
	d.metrics = m
	d._index()
	return d


## Drops the parsed-JSON cache (the files are re-read on the next load_files()).
static func clear_cache() -> void:
	_json_cache.clear()


## Our own clips in place of some of the graph's (CLIP_OVERRIDES_PATH: the jog): the clip's library path, its travel
## speed and its stride (speed * length) replaced; the rest of its entry and metrics (the plant phases, the loop) are
## the original's. Copies the entries it changes, so the parsed-file cache stays as the files have it.
func apply_clip_overrides() -> void:
	var t := _read_json(CLIP_OVERRIDES_PATH)
	if t.is_empty():
		return
	graph = graph.duplicate(false)
	graph["clips"] = (graph.get("clips", {}) as Dictionary).duplicate(false)
	metrics = metrics.duplicate(false)
	metrics["clips"] = (metrics.get("clips", {}) as Dictionary).duplicate(false)
	for name: String in t.get("clips", {}):
		var o: Dictionary = t.clips[name]
		var lib := String(o.lib)
		if not graph.clips.has(name) or not OVERRIDE_LIBS.has(lib):
			continue
		var info: Dictionary = (graph.clips[name] as Dictionary).duplicate(false)
		info["godot"] = "%s/%s" % [lib, o.clip]
		graph.clips[name] = info
		_override_libs[lib] = OVERRIDE_LIBS[lib]
		if o.has("speed") and metrics.clips.has(name):
			var mc: Dictionary = (metrics.clips[name] as Dictionary).duplicate(false)
			var tr: Dictionary = (mc.get("travel", {}) as Dictionary).duplicate(false)
			tr["speed"] = float(o.speed)
			tr["stride_m"] = float(o.speed) * float(o.length)
			mc["travel"] = tr
			metrics.clips[name] = mc


## Arm layers the roles take in place of their own (CARRY_PATCHES_PATH): for each rule the roles of its weapon in its modes
## (but `roles_except`) lose their layers in `slots` and take the rule's `layers`, or the same role's layers of the weapon
## in `copy_from` (none when that role has none in those slots). `clips` adds graph clips from our own libraries, which the
## patched layers name. Copies what it changes.
func apply_carry_patches() -> void:
	var t := _read_json(CARRY_PATCHES_PATH)
	if t.is_empty():
		return
	graph = graph.duplicate(false)
	graph["clips"] = (graph.get("clips", {}) as Dictionary).duplicate(false)
	graph["roles"] = (graph.get("roles", {}) as Dictionary).duplicate(false)
	graph["actions"] = (graph.get("actions", {}) as Dictionary).duplicate(false)
	for name: String in t.get("clips", {}):
		var c: Dictionary = t.clips[name]
		var lib := String(c.lib)
		if not OVERRIDE_LIBS.has(lib):
			continue
		graph.clips[name] = {"additive": false, "alternatives": [], "godot": "%s/%s" % [lib, c.clip], "graph_names": [],
				"length": float(c.length), "original_name": name, "source_kind": "clip", "source_names": [name]}
		_alias[name] = name
		_override_libs[lib] = OVERRIDE_LIBS[lib]
	# actions of our own (a copy of a graph action under a key of its own, playing a clip of ours): the bow's nock from the hand
	for key: String in t.get("actions", {}):
		var spec: Dictionary = t.actions[key]
		var src: Dictionary = graph.actions.get(String(spec.copy_of), {})
		if src.is_empty():
			continue
		var e: Dictionary = src.duplicate(false)
		e["frontier_key"] = String(spec.frontier_key)
		e["partial"] = String(spec.partial)
		if e.get("partial_role") is Dictionary:
			var pr: Dictionary = (e.partial_role as Dictionary).duplicate(false)
			pr["clip"] = String(spec.partial)
			pr["graph_clip"] = String(spec.partial)
			e["partial_role"] = pr
		graph.actions[key] = e
	for rule: Dictionary in t.get("rules", []):
		var slots: Array = rule.get("slots", [])
		var except: Array = rule.get("roles_except", [])
		var only: Array = rule.get("roles_only", [])
		for key: String in graph.roles.keys():
			var parts := key.split("/")
			if parts.size() != 3 or parts[0] != String(rule.weapon) or not (rule.modes as Array).has(parts[1]) or except.has(parts[2]):
				continue
			# (roles_only: the air, landing, hit and death roles keep their own, they are shared between the weapons' inputs)
			if not only.is_empty() and not only.has(parts[2]):
				continue
			var role: Dictionary = (graph.roles[key] as Dictionary).duplicate(false)
			var layers: Array = []
			var had := false
			var at := -1
			for l: Dictionary in role.get("layers", []):
				if slots.has(String(l.get("slot", ""))):
					if not had:
						at = layers.size()
					had = true
				else:
					layers.append(l)
			# (only the roles that carry such a layer: the air, landing, hit and death roles have none)
			if not had:
				continue
			# (the new layers go where the first replaced one was: the partial arms come before their additive)
			var put: Array = []
			if rule.has("copy_from"):
				# (copy_mode: from that mode's role instead of the same mode's: the walk's backward roles from the sprint's)
				var src: Dictionary = graph.roles.get("%s/%s/%s" % [rule.copy_from, rule.get("copy_mode", parts[1]), rule.get("copy_role", parts[2])], {})
				for l: Dictionary in src.get("layers", []):
					if slots.has(String(l.get("slot", ""))):
						put.append(l)
			else:
				put.append_array(rule.get("layers", []))
			for i in put.size():
				layers.insert(at + i, put[i])
			role["layers"] = layers
			graph.roles[key] = role


## Libraries the overriding clips live in: name -> resource path.
func override_libraries() -> Dictionary:
	return _override_libs


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var mt := FileAccess.get_modified_time(path)
	var c: Array = _json_cache.get(path, [])
	if not c.is_empty() and c[0] == mt:
		return c[1]
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not v is Dictionary:
		return {}
	_json_cache[path] = [mt, v]
	return v


func _index() -> void:
	for flag in graph.get("gameplay_overrides", {}):
		_overrides[flag] = bool(graph.gameplay_overrides[flag].get("default", false))
	for b in graph.get("bank_roles", {}):
		for r in graph.bank_roles[b]:
			_bank_role_names[r] = true
	var clips: Dictionary = graph.get("clips", {})
	for name in clips:
		_alias[name] = name
	# Other names only where they do not collide with an action name; ties are recorded.
	for name in clips:
		var c: Dictionary = clips[name]
		var others: Array = [c.get("original_name", "")]
		others.append_array(c.get("source_names", []))
		others.append_array(c.get("graph_names", []))
		for o in others:
			o = String(o)
			if o == "" or o == name or clips.has(o):
				continue
			if _alias.has(o) and _alias[o] != name:
				var amb: Array = _alias_ambiguous.get(o, [_alias[o]])
				if not amb.has(name):
					amb.append(name)
				_alias_ambiguous[o] = amb
				continue
			_alias[o] = name


# --- identity -------------------------------------------------------------------------------

func is_fixture() -> bool:
	return graph.get("meta", {}).has("fixture")


func attribution() -> String:
	return String(graph.get("meta", {}).get("attribution", ""))


## Weapons of the table, in Frontier order.
func weapons() -> PackedStringArray:
	var out := PackedStringArray()
	for w in WEAPON_ORDER:
		if graph.get("profiles", {}).has(w):
			out.append(w)
	for w in graph.get("profiles", {}):
		if not out.has(w):
			out.append(w)
	return out


## Movement modes of the table, in the order walk, run, sprint, crouch.
func modes() -> PackedStringArray:
	var out := PackedStringArray()
	for m in MODE_ORDER:
		if graph.get("modes", {}).has(m):
			out.append(m)
	for m in graph.get("modes", {}):
		if not out.has(m):
			out.append(m)
	return out


func stance_of(mode: String) -> String:
	return String(graph.get("modes", {}).get(mode, {}).get("stance", "crouch" if mode == "crouch" else "stand"))


## Stances that have at least one mode.
func stances() -> PackedStringArray:
	var out := PackedStringArray()
	for m in modes():
		var s := stance_of(m)
		if not out.has(s):
			out.append(s)
	return out


## The first mode of a stance (walk/run/sprint share idle content; crouch is its own).
func modes_of_stance(stance: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in modes():
		if stance_of(m) == stance:
			out.append(m)
	return out


# --- clips ----------------------------------------------------------------------------------

func has_clip(name: String) -> bool:
	return graph.get("clips", {}).has(resolve_alias(name))


func clip_info(name: String) -> Dictionary:
	return graph.get("clips", {}).get(resolve_alias(name), {})


func clip_length(name: String) -> float:
	return float(clip_info(name).get("length", 0.0))


func clip_additive(name: String) -> bool:
	return bool(clip_info(name).get("additive", false))


## Action name for any known name (action, original, source or graph name); the name itself
## when unknown.
func resolve_alias(name: String) -> String:
	return String(_alias.get(name, name))


## Names that map to more than one action ({name: [actions]}).
func ambiguous_aliases() -> Dictionary:
	return _alias_ambiguous


## Library path for AnimationNodeAnimation.animation ("actor_b/<action>"). A name that already is
## a library path (TreeBuilder's baked frontier_bank clips, e.g. the sampled carry poses of THROW2;
## no graph clip name has a "/") is returned as it is.
func godot_anim(name: String) -> StringName:
	var info := clip_info(name)
	if info.has("godot"):
		return StringName(info.godot)
	if "/" in name:
		return StringName(name)
	return StringName("%s/%s" % [LIB, resolve_alias(name)])


# --- roles ----------------------------------------------------------------------------------

## Lower-body role "<w>/<m>/<role>" ({} when absent).
func role(w: String, m: String, r: String) -> Dictionary:
	return graph.get("roles", {}).get("%s/%s/%s" % [w, m, r], {})


## The role's clip when it has one ("" for missing, disabled and direct roles).
func role_clip(w: String, m: String, r: String) -> String:
	var d := role(w, m, r)
	if d.is_empty() or d.get("clip") == null or String(d.get("status", "")) in ["missing", "disabled"]:
		return ""
	return String(d.clip)


## Role names of the lower body (every "<w>/<m>/<role>" suffix), sorted.
func role_names() -> PackedStringArray:
	var seen := {}
	for k in graph.get("roles", {}):
		seen[String(k).get_slice("/", 2)] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


func is_bank_role(r: String) -> bool:
	return _bank_role_names.has(r)


## [center, lt, rt] role names of a bank_roles entry (move_fw, start_bw, rev_fw_bw, ...).
func bank_roles(bank: String) -> PackedStringArray:
	return PackedStringArray(graph.get("bank_roles", {}).get(bank, []))


## Runtime-supplied roles: kind in hit_full, hit_add, death, fire; key "<w>/<m>/<dir|variant>"
## (fire: "<w>/<stance>").
func runtime_role(kind: String, key: String) -> Dictionary:
	return graph.get("runtime_roles", {}).get(kind, {}).get(key, {})


## runtime_clips.<kind>[key] ("" when absent).
func runtime_clip(kind: String, key: String) -> String:
	var v: Variant = graph.get("runtime_clips", {}).get(kind, {}).get(key, "")
	return String(v) if v is String else ""


func aim_tree(w: String, stance: String) -> Dictionary:
	return graph.get("aim_trees", {}).get("%s/%s" % [w, stance], {})


func aim_move(w: String, stance: String) -> Dictionary:
	return graph.get("aim_move", {}).get("%s/%s" % [w, stance], {})


func hand_state(w: String, stance: String, key := "weapon_out") -> Dictionary:
	return graph.get("hand_states", {}).get("%s/%s" % [w, stance], {}).get(key, {})


## crouch_change["<w>/<stand_to_crouch|crouch_to_stand>"] ({full, add, overlay, mode}).
func crouch_change(w: String, direction: String) -> Dictionary:
	return graph.get("crouch_change", {}).get("%s/%s" % [w, direction], {})


func grip(w: String) -> Dictionary:
	return graph.get("grips", {}).get(w, {})


## actions["<w>/<stance>/<key>"] ({} when absent).
func action(w: String, stance: String, key: String) -> Dictionary:
	return graph.get("actions", {}).get("%s/%s/%s" % [w, stance, key], {})


## weapon_layers.weapon_out.clips["<w>/<stance>"] with `applies` resolved against force.
func weapon_out(w: String, stance: String) -> Dictionary:
	var wo: Dictionary = graph.get("weapon_layers", {}).get("weapon_out", {})
	var c: Dictionary = wo.get("clips", {}).get("%s/%s" % [w, stance], {})
	if c.is_empty():
		return c
	var out := c.duplicate()
	var force: Dictionary = wo.get("force", {})
	if force.has(w):
		out["applies"] = bool(force[w])
	return out


func prop_bone(w: String) -> String:
	return String(graph.get("weapon_layers", {}).get("prop_bones", {}).get(w, "r_hand_prop_attachment"))


# --- transitions, thresholds, options, overrides ---------------------------------------------

func transition(key: String) -> Dictionary:
	return graph.get("transitions", {}).get(key, {})


## Effective `use` of a transition row: the primary record's graph-faithful values, or those of
## the graph variant `record` ("0x..."), with every enabled gameplay override applied on top.
## Adds: key, record, status, fade_graph (the graph value), override (flag or "").
func transition_use(key: String, record := "") -> Dictionary:
	var row := transition(key)
	if row.is_empty():
		return {}
	var use: Dictionary = row.get("use", {}).duplicate()
	var rec := String(row.graph.record) if row.get("graph") is Dictionary else ""
	if record != "":
		for v in row.get("graph_variants", []):
			if String(v.get("record", "")) == record:
				use = v.get("use", {}).duplicate()
				rec = record
				break
	use["key"] = key
	use["record"] = rec
	use["status"] = String(row.get("status", ""))
	use["fade_graph"] = float(use.get("fade_s", 0.0))
	use["override"] = ""
	for o in row.get("overrides", []):
		var flag := String(o.get("flag", ""))
		if not override_enabled(flag):
			continue
		for f in o:
			if not f in ["flag", "rule", "why"]:
				use[f] = o[f]
		use["override"] = flag
	# gameplay_overrides[flag].transitions[key] (same values; covers rows that do not list it).
	for flag in _overrides:
		if not _overrides[flag]:
			continue
		var t: Dictionary = graph.gameplay_overrides[flag].get("transitions", {})
		if t.has(key):
			for f in t[key]:
				use[f] = t[key][f]
			use["override"] = flag
	return use


func threshold(name: String, default: Variant = null) -> Variant:
	return graph.get("thresholds", {}).get(name, default)


func tuning(name: String, default: Variant = null) -> Variant:
	return graph.get("tuning", {}).get(name, default)


## Effective option: a runtime set_option() value, else an enabled override's sets_options,
## else the table's options block.
func option(name: String, default: Variant = null) -> Variant:
	if _option_set.has(name):
		return _option_set[name]
	var v: Variant = graph.get("options", {}).get(name, default)
	for flag in _overrides:
		if _overrides[flag]:
			var so: Dictionary = graph.gameplay_overrides[flag].get("sets_options", {})
			if so.has(name):
				v = so[name]
	return v


func set_option(name: String, value: Variant) -> void:
	_option_set[name] = value


func clear_option(name: String) -> void:
	_option_set.erase(name)


## Every gameplay override flag of the table (all default off).
func override_flags() -> PackedStringArray:
	var out := PackedStringArray(_overrides.keys())
	out.sort()
	return out


func override_enabled(flag: String) -> bool:
	return bool(_overrides.get(flag, false))


func set_override(flag: String, on: bool) -> void:
	if not _overrides.has(flag):
		push_warning("AnimGraphData: unknown gameplay override '%s'" % flag)
		return
	_overrides[flag] = on


## {rule, default, why, transitions, sets_options} of an override flag.
func override_info(flag: String) -> Dictionary:
	return graph.get("gameplay_overrides", {}).get(flag, {})


# --- metrics --------------------------------------------------------------------------------

func has_metrics() -> bool:
	return not metrics.is_empty()


func clip_metrics(name: String) -> Dictionary:
	return metrics.get("clips", {}).get(resolve_alias(name), {})


## Measured travel speed (m/s) of a clip; 0 when unknown.
func clip_speed(name: String) -> float:
	var t: Variant = clip_metrics(name).get("travel")
	return float(t.get("speed", 0.0)) if t is Dictionary else 0.0


## speed * length (m per clip cycle); 0 when unknown.
func stride_m(name: String) -> float:
	var t: Variant = clip_metrics(name).get("travel")
	return float(t.get("stride_m", 0.0)) if t is Dictionary else 0.0


## {l: [phases], r: [phases], l_contact, r_contact} or {}.
func plants(name: String) -> Dictionary:
	var p: Variant = clip_metrics(name).get("plant")
	return p if p is Dictionary else {}


## metrics bone_sets[name] (upper, hands, stabilized, pitch_add_union, lower); empty when absent.
func bone_set(name: String) -> PackedStringArray:
	return PackedStringArray(metrics.get("bone_sets", {}).get(name, []))


## Chest height (m above the feet) of a stance: metrics, else tuning.chest_height_fallback.
func chest_height(stance: String) -> float:
	var ch: Dictionary = metrics.get("chest_height", {})
	if ch.has(stance):
		return float(ch[stance])
	return float(tuning("chest_height_fallback", {}).get(stance, 1.35 if stance == "stand" else 0.95))


func pitch_table(w: String, stance: String) -> Dictionary:
	return metrics.get("pitch", {}).get("%s/%s" % [w, stance], {})


# --- whole-table helpers ----------------------------------------------------------------------

## Every clip (action name) the runtime may play: roles and their layers, bank roles, aim trees,
## aim-move, hand states, crouch change, grips, actions (partial + twin), runtime clips / roles
## and their layers, weapon-out clips. Sorted, unique.
func referenced_clips() -> PackedStringArray:
	var seen := {}
	var add := func(c: Variant) -> void:
		if c is String and c != "":
			seen[c] = true
	var add_role := func(r: Variant) -> void:
		if not r is Dictionary:
			return
		add.call(r.get("clip"))
		for l in r.get("layers", []):
			# resolved graph layers, and the substitute / Frontier-composed carry layers (TreeBuilder.PLAYABLE_LAYER_STATUS)
			if l is Dictionary and String(l.get("status", "resolved")) in ["resolved", "substitute", "frontier"]:
				add.call(l.get("clip"))
	for k in graph.get("roles", {}):
		add_role.call(graph.roles[k])
	for k in graph.get("aim_trees", {}):
		var at: Dictionary = graph.aim_trees[k]
		for s in at:
			if s == "hands":
				add.call(at.hands.get("clip"))
			else:
				add_role.call(at[s])
	for sect in ["aim_move", "hand_states", "crouch_change"]:
		for k in graph.get(sect, {}):
			for s in graph[sect][k]:
				add_role.call(graph[sect][k][s])
	for w in graph.get("grips", {}):
		for s in ["carry", "aim_stand", "aim_crouch"]:
			add.call(graph.grips[w].get(s))
	for k in graph.get("actions", {}):
		add.call(graph.actions[k].get("partial"))
		add.call(graph.actions[k].get("twin"))
	for kind in graph.get("runtime_clips", {}):
		var rc: Variant = graph.runtime_clips[kind]
		if rc is Dictionary and kind != "sources":
			for k in rc:
				add.call(rc[k])
	for kind in graph.get("runtime_roles", {}):
		for k in graph.runtime_roles[kind]:
			add_role.call(graph.runtime_roles[kind][k])
	var wo: Dictionary = graph.get("weapon_layers", {}).get("weapon_out", {}).get("clips", {})
	for k in wo:
		add.call(wo[k].get("clip"))
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## Validates the tables against a loaded library. Returns error strings (empty = valid):
## every graph clip exists in `lib` with the same length (+-1e-3 s), additive flag
## (Animation meta additive_source) and native_asset_id; every referenced clip is a graph clip;
## every layer weight and weight-curve sample is in [0, 1]; every alias resolves to its action;
## every metrics clip exists in the library.
func validate(ap: AnimationPlayer, lib := LIB) -> PackedStringArray:
	var errs := PackedStringArray()
	var clips: Dictionary = graph.get("clips", {})
	for name in clips:
		var info: Dictionary = clips[name]
		var path := StringName(info.get("godot", "%s/%s" % [lib, name]))
		# (a clip of our own in place of the graph's: it lives in its own library, which the player gets when the tree is
		# built; its length is the original's, its asset id ours)
		var own := _override_libs.has(String(path).get_slice("/", 0))
		if String(path) != "%s/%s" % [lib, name] and not own:
			errs.append("clip %s: godot path %s is not %s/%s" % [name, path, lib, name])
		if own and not ap.has_animation(path):
			var ol := load(String(_override_libs[String(path).get_slice("/", 0)])) as AnimationLibrary
			if ol == null or not ol.has_animation(String(path).get_slice("/", 1)):
				errs.append("clip %s: %s not in its own library" % [name, path])
			elif absf(ol.get_animation(String(path).get_slice("/", 1)).length - float(info.get("length", -1.0))) > 1e-3:
				errs.append("clip %s: length differs from the clip standing in for it" % name)
			continue
		if not ap.has_animation(path):
			errs.append("clip %s: not in library %s" % [name, lib])
			continue
		var a := ap.get_animation(path)
		if absf(a.length - float(info.get("length", -1.0))) > 1e-3:
			errs.append("clip %s: length %.4f in JSON, %.4f in library" % [name, float(info.get("length", -1.0)), a.length])
		if a.has_meta(&"additive_source") and bool(a.get_meta(&"additive_source")) != bool(info.get("additive", false)):
			errs.append("clip %s: additive %s in JSON, additive_source %s in library meta" % [name, info.get("additive"), a.get_meta(&"additive_source")])
		elif not a.has_meta(&"additive_source"):
			errs.append("clip %s: library animation has no additive_source meta" % name)
		if a.has_meta(&"native_asset_id") and String(a.get_meta(&"native_asset_id")) != String(info.get("native_asset_id", "")):
			errs.append("clip %s: native_asset_id differs from the library meta" % name)
		# Aliases resolve back to this action (unless recorded as ambiguous).
		var names: Array = [info.get("original_name", "")]
		names.append_array(info.get("source_names", []))
		names.append_array(info.get("graph_names", []))
		for o in names:
			o = String(o)
			if o == "" or _alias_ambiguous.has(o):
				continue
			if resolve_alias(o) != name and not clips.has(o):
				errs.append("clip %s: alias %s resolves to %s" % [name, o, resolve_alias(o)])
	for c in referenced_clips():
		if not clips.has(c):
			errs.append("referenced clip %s is not in the clips table" % c)
	for e in _weight_errors():
		errs.append(e)
	for c in metrics.get("clips", {}):
		if not ap.has_animation(StringName("%s/%s" % [lib, c])):
			errs.append("metrics clip %s: not in library %s" % [c, lib])
		elif absf(ap.get_animation(StringName("%s/%s" % [lib, c])).length - float(metrics.clips[c].get("length", -1.0))) > 1e-3:
			errs.append("metrics clip %s: length differs from the library" % c)
	return errs


## Layer weights and curve samples outside [0, 1].
func _weight_errors() -> PackedStringArray:
	var errs: Array[String] = []   # an Array: the lambda below appends to it (packed arrays are copied on capture)
	var check_role := func(where: String, r: Variant) -> void:
		if not r is Dictionary:
			return
		for l in r.get("layers", []):
			var w := float(l.get("weight", 0.0))
			if w < 0.0 or w > 1.0 or is_nan(w):
				errs.append("%s layer %s: weight %s outside [0, 1]" % [where, l.get("clip"), w])
			var curve: Variant = l.get("weight_curve")
			if curve is Array:
				for x in curve:
					if float(x) < 0.0 or float(x) > 1.0:
						errs.append("%s layer %s: weight curve sample %s outside [0, 1]" % [where, l.get("clip"), x])
						break
	for k in graph.get("roles", {}):
		check_role.call("roles." + k, graph.roles[k])
	for sect in ["aim_trees", "aim_move", "hand_states", "crouch_change"]:
		for k in graph.get(sect, {}):
			for s in graph[sect][k]:
				check_role.call("%s.%s.%s" % [sect, k, s], graph[sect][k][s])
	for kind in graph.get("runtime_roles", {}):
		for k in graph.runtime_roles[kind]:
			check_role.call("runtime_roles.%s.%s" % [kind, k], graph.runtime_roles[kind][k])
	var wo: float = float(graph.get("weapon_layers", {}).get("weapon_out", {}).get("weight", 1.0))
	if wo < 0.0 or wo > 1.0:
		errs.append("weapon_layers.weapon_out.weight %s outside [0, 1]" % wo)
	return PackedStringArray(errs)
