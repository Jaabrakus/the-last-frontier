class_name WeaponBalance
## Weapon balance loader: writes the numbers of data/weapons/ballistics.json onto a weapon
## instance (speed, gravity, drag, damage, spread and handling), so one file is the balance
## authority and the script defaults stay the fallback. Design:
## Player_Animation_Project/graph_analysis/weapons/weapons_balance_design.md, section 3.
##
##   WeaponBalance.apply(weapon, "musket")      the row for a roster key ("tomahawk_pipe" uses
##                                             the "tomahawk" row through "aliases")
##   WeaponBalance.apply(weapon)                the first row whose "class" is the weapon's own
##                                             global class name
##
## Call it after the weapon is constructed and `player` is set, before its first equip() or
## tick(). It writes only script properties named in the row's "set" (never runtime state
## such as spread, state, charge or aim, and never the inventory: count, reserve, quiver...),
## coerced to the property's type (float, int, bool, Vector2/Vector3 from [x, y(, z)]). Unknown
## names are skipped and reported, never fatal. "upgrades" blocks are applied, each atomically,
## only when every property they name in "requires" exists on the weapon (the set B quadratic
## drag switches on by itself once its hooks land). Calling it twice gives the same state.
##
## A missing or broken file, or another schema, leaves the weapon on its script defaults
## (one warning); apply() then returns ok = false with nothing applied.
##
## Returns {"key": resolved row key, "ok", "applied", "skipped", "upgrades", "skipped_upgrades"}
## (the last four PackedStringArray). The applied row key and its "expect" block are kept on the
## weapon as meta (&"balance_key", &"balance_expect"): expect(weapon), effective_range(weapon).
##
## The class check walks the script chain, so the "musket" row also passes on an
## OverUnderMusket (it extends Musket): always pass the over-under its own key.

const DEFAULT_PATH := "res://data/weapons/ballistics.json"
const SCHEMA := "frontier.weapons.ballistics/1"
## Script variables apply() never writes, even if a row names them: runtime state and inventory.
const PROTECTED: Array[String] = [
	"spread", "state", "charge", "aim", "active", "hold_time", "player", "model", "muzzle", "socket",
	"clips", "relaxed", "reload_stages", "count", "max_count", "reserve", "quiver", "loaded", "held",
	"last_thrown", "scripted_input", "use_scripted_input",
]

## Tests: push_error (instead of push_warning) on unknown properties, class mismatches and
## unknown keys.
static var strict := false
## "" or a key of "presets" (only "realistic" exists: the tomahawk's spin assist 0.5). Set it
## before the first apply; weapons already balanced must be applied again.
static var preset := ""

static var _doc := {}
static var _path := DEFAULT_PATH
static var _tried := false
static var _loaded := false


## Applies the balance row for `weapon`. `key` is the roster key ("musket", "tomahawk_pipe",
## ...); empty = the first row whose "class" is the weapon's own global class name.
static func apply(weapon: Weapon, key := "") -> Dictionary:
	var out := {"key": key, "ok": false, "applied": PackedStringArray(), "skipped": PackedStringArray(),
			"upgrades": PackedStringArray(), "skipped_upgrades": PackedStringArray()}
	if weapon == null:
		_complain("WeaponBalance.apply: no weapon")
		return out
	if not _ensure_loaded():
		return out
	var rk := resolve_key(key) if key != "" else key_for(weapon)
	var r := row(rk)
	if r.is_empty():
		_complain("WeaponBalance: no balance row for %s (key '%s')" % [_class_name(weapon), key])
		return out
	out.key = rk
	var cls := String(r.get("class", ""))
	if cls != "" and not script_is(weapon, cls):
		_complain("WeaponBalance: row '%s' is for %s, not %s: nothing applied" % [rk, cls, _class_name(weapon)])
		return out
	var values: Dictionary = (r.get("set", {}) as Dictionary).duplicate()
	if preset != "":
		var p: Dictionary = (_doc.get("presets", {}) as Dictionary).get(preset, {})
		if p.is_empty():
			_complain("WeaponBalance: unknown preset '%s'" % preset)
		values.merge(p.get(rk, {}) as Dictionary, true)
	var res := apply_set(weapon, values)
	var applied: PackedStringArray = res.applied
	var skipped: PackedStringArray = res.skipped
	var ups := PackedStringArray()
	var skipped_ups := PackedStringArray()
	for up: Variant in r.get("upgrades", []):
		if not up is Dictionary:
			continue
		var id := String(up.get("id", "?"))
		var can := true
		for n: Variant in up.get("requires", []):
			if not has_property(weapon, String(n)):
				can = false
				break
		if can:
			var ur := apply_set(weapon, up.get("set", {}))
			applied.append_array(ur.applied)
			skipped.append_array(ur.skipped)
			ups.append(id)
		else:
			skipped_ups.append(id)
	out.applied = applied
	out.skipped = skipped
	out.upgrades = ups
	out.skipped_upgrades = skipped_ups
	if strict and not skipped.is_empty():
		push_error("WeaponBalance: %s (%s) has no property %s" % [rk, _class_name(weapon), ", ".join(skipped)])
	weapon.set_meta(&"balance_key", rk)
	weapon.set_meta(&"balance_expect", r.get("expect", {}))
	out.ok = true
	return out


## Writes `values` ({property: JSON value}) onto `target`, coerced to each property's type.
## Only script variables are written, never PROTECTED ones. {"applied", "skipped"}.
static func apply_set(target: Object, values: Dictionary) -> Dictionary:
	var types := _script_property_types(target)
	var applied := PackedStringArray()
	var skipped := PackedStringArray()
	for name: Variant in values:
		var n := String(name)
		if not types.has(n) or n in PROTECTED:
			skipped.append(n)
			continue
		var v: Variant = _coerce(values[name], int(types[n]))
		if v == null:
			skipped.append(n)
			_complain("WeaponBalance: %s = %s does not fit the property's type" % [n, str(values[name])])
			continue
		target.set(n, v)
		applied.append(n)
	return {"applied": applied, "skipped": skipped}


## The row for a roster key, resolved through "aliases"; {} if none.
static func row(key: String) -> Dictionary:
	if not _ensure_loaded():
		return {}
	var rows: Dictionary = _doc.get("weapons", {})
	return rows.get(resolve_key(key), {})


## Roster key -> row key ("tomahawk_pipe" -> "tomahawk").
static func resolve_key(key: String) -> String:
	if not _ensure_loaded():
		return key
	return String((_doc.get("aliases", {}) as Dictionary).get(key, key))


## The first row whose "class" is the weapon's own (leaf) global class name; "" if none.
static func key_for(weapon: Object) -> String:
	if not _ensure_loaded() or weapon == null:
		return ""
	var own := _class_name(weapon)
	var rows: Dictionary = _doc.get("weapons", {})
	for k: Variant in rows:
		if String((rows[k] as Dictionary).get("class", "")) == own:
			return String(k)
	return ""


## The applied row's "expect" block (generated by tools/weapons/check_balance.py), or {}.
static func expect(weapon: Object) -> Dictionary:
	return weapon.get_meta(&"balance_expect", {}) if weapon else {}


## Effective range in metres: expect.d50_m (torso D50, standing, settled), else the cone
## model's 0.5 / tan(spread_base).
static func effective_range(weapon: Weapon) -> float:
	var e := expect(weapon)
	if e.has("d50_m") and (e.d50_m is float or e.d50_m is int):
		return float(e.d50_m)
	return BallisticsUtil.effective_range(weapon.spread_base)


## The ladder orders of the file ("max_range", "effective", "best"): row keys, shortest first.
static func ladder(kind := "max_range") -> Array:
	if not _ensure_loaded():
		return []
	return (_doc.get("ladder", {}) as Dictionary).get(kind, [])


## The parsed file ({} when it did not load).
static func data() -> Dictionary:
	_ensure_loaded()
	return _doc


## Parses and caches `path`. False (one warning) when it is missing, broken or of another schema.
static func load_file(path := DEFAULT_PATH) -> bool:
	_path = path
	_tried = true
	_loaded = false
	_doc = {}
	if not FileAccess.file_exists(path):
		push_warning("WeaponBalance: %s not found; weapons keep their script defaults" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("WeaponBalance: %s is not valid JSON; weapons keep their script defaults" % path)
		return false
	if String((parsed as Dictionary).get("schema", "")) != SCHEMA:
		push_warning("WeaponBalance: %s has schema '%s', not %s; weapons keep their script defaults"
				% [path, (parsed as Dictionary).get("schema", ""), SCHEMA])
		return false
	_doc = parsed
	_loaded = true
	return true


## Drops the cache, the preset and strict mode (tests). The next call loads DEFAULT_PATH again.
static func reset() -> void:
	_doc = {}
	_path = DEFAULT_PATH
	_tried = false
	_loaded = false
	preset = ""
	strict = false


## True when `obj`'s script, or one it extends, has the global class name `cls` (or the object
## is that native class).
static func script_is(obj: Object, cls: String) -> bool:
	if obj == null:
		return false
	if obj.is_class(cls):
		return true
	var s := obj.get_script() as Script
	while s:
		if String(s.get_global_name()) == cls:
			return true
		s = s.get_base_script()
	return false


## True when `obj` has a script variable `name` that apply_set may write.
static func has_property(obj: Object, name: String) -> bool:
	return _script_property_types(obj).has(name) and not name in PROTECTED


# --- Internals -------------------------------------------------------------------------------

static func _ensure_loaded() -> bool:
	if not _tried:
		load_file(_path)
	return _loaded


static func _class_name(obj: Object) -> String:
	var s := obj.get_script() as Script if obj else null
	while s:
		var n := String(s.get_global_name())
		if n != "":
			return n
		s = s.get_base_script()
	return obj.get_class() if obj else "null"


static func _script_property_types(obj: Object) -> Dictionary:
	var out := {}
	if obj == null:
		return out
	for p: Dictionary in obj.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[String(p.name)] = int(p.type)
	return out


static func _coerce(v: Variant, type: int) -> Variant:
	var is_num := v is float or v is int
	if type == TYPE_FLOAT:
		return float(v) if is_num else null
	if type == TYPE_INT:
		return int(roundf(float(v))) if is_num else null
	if type == TYPE_BOOL:
		if v is bool:
			return v
		return (float(v) != 0.0) if is_num else null
	if type == TYPE_VECTOR2:
		if v is Array and (v as Array).size() == 2:
			return Vector2(float(v[0]), float(v[1]))
		return null
	if type == TYPE_VECTOR3:
		if v is Array and (v as Array).size() == 3:
			return Vector3(float(v[0]), float(v[1]), float(v[2]))
		return null
	if type == TYPE_STRING or type == TYPE_STRING_NAME:
		return String(v) if v is String or v is StringName else null
	if type == TYPE_NIL:
		return v          # untyped script variable
	return null


static func _complain(msg: String) -> void:
	if strict:
		push_error(msg)
	else:
		push_warning(msg)
