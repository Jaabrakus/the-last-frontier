class_name LoadoutData
extends RefCounted
## Read-only access to the loadout design data (loaded once, cached):
##
##   data/loadout/carry_gear.json      carry points (stowed transform per item kind), gear -> points,
##                                     draw sets, back layering, pair gaps, yield rule
##   data/loadout/loadout_items.json   item kinds, long-slot rule, key binding table
##   data/loadout/loadout_presets.json presets and the default
##   data/loadout/sling_runtime.json   runtime parameters of this workflow (customizer maps, straps,
##                                     horn, handoff defaults, test thresholds)
##
## The first three are written by tools/loadout/build_loadout_data.py (the design,
## source/graph_analysis/loadout/loadout_design.md); this class never writes them.
##
##   var d := LoadoutData.get_default()
##   d.point("R_hip", "pistol")          # the carry_gear entry of a placement ({} if none)
##   d.stow_local("R_hip", "pistol")     # Transform3D, model in the carrying bone's rest frame
##
## Provenance: stowed transforms and clip names come from the Actor_B rig. Clip names are kept as
## they appear in the actor_b library (each clip keeps its native asset id there).

const CARRY_PATH := "res://data/loadout/carry_gear.json"
const ITEMS_PATH := "res://data/loadout/loadout_items.json"
const PRESETS_PATH := "res://data/loadout/loadout_presets.json"
const RUNTIME_PATH := "res://data/loadout/sling_runtime.json"
const FIT_PATH := "res://data/loadout/design_fit_check.json"
const BODY_FIT_PATH := "res://data/loadout/body_fit.json"

## Long slots on the back, in assignment order.
const LONG_SLOTS: Array[String] = ["long_A", "long_B"]
## Pistol points in draw order (fastest draw first; loadout_design.md 3).
const PISTOL_ORDER: Array[String] = ["R_hip", "back_right", "chest_R", "L_hip", "chest_L"]
## Long kinds in the order the long-slot rule assigns them.
const LONG_ORDER: Array[String] = ["musket", "over_under", "bow", "spear_pair", "dart_bundle"]

static var _default: LoadoutData

var carry := {}
var items := {}
var presets := {}
var runtime := {}
var _fit := {}
var _body_fit := {}
var _xf_cache := {}


static func get_default() -> LoadoutData:
	if _default == null:
		_default = LoadoutData.new()
		_default.load_all()
	return _default


## Drops the cache (tests that rewrite nothing still call it to start clean).
static func reset() -> void:
	_default = null


func load_all() -> bool:
	carry = _read(CARRY_PATH)
	items = _read(ITEMS_PATH)
	presets = _read(PRESETS_PATH)
	runtime = _read(RUNTIME_PATH)
	return not (carry.is_empty() or items.is_empty() or presets.is_empty())


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LoadoutData: %s is missing" % path)
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("LoadoutData: %s does not parse" % path)
		return {}
	return d


## design_fit_check.json (large; loaded on first use, for the tests).
func fit() -> Dictionary:
	if _fit.is_empty():
		_fit = _read(FIT_PATH)
	return _fit


## body_fit.json (large; loaded on first use: outfit bulk, limb radii).
func body_fit() -> Dictionary:
	if _body_fit.is_empty():
		_body_fit = _read(BODY_FIT_PATH)
	return _body_fit


# --- item kinds -------------------------------------------------------------------------------

func kind(k: String) -> Dictionary:
	return items.get("kinds", {}).get(k, {})


func kind_class(k: String) -> String:
	return String(kind(k).get("class", ""))


func is_long(k: String) -> bool:
	return kind_class(k) == "long"


func count_max(k: String) -> int:
	return int(kind(k).get("count_max", 1))


func needs(k: String) -> Array:
	return kind(k).get("needs", [])


## The long slots a kind may take, in preference order.
func long_slots_of(k: String) -> Array:
	return kind(k).get("slots", [])


## Belt / sash / sling points a kind may take (preference order).
func points_of(k: String) -> Array:
	var d := kind(k)
	if d.has("points"):
		return d.points
	if d.has("point"):
		return [d.point]
	return []


# --- carry points -----------------------------------------------------------------------------

func point(p: String, k: String) -> Dictionary:
	return carry.get("points", {}).get("%s.%s" % [p, k], {})


func has_point(p: String, k: String) -> bool:
	return carry.get("points", {}).has("%s.%s" % [p, k])


## stow.local parsed (the model in the carrying bone's rest frame); IDENTITY when there is none.
func stow_local(p: String, k: String) -> Transform3D:
	return _xf(p, k, "local")


## stow.bind parsed (the same in skeleton space at the bind pose null-add).
func stow_bind(p: String, k: String) -> Transform3D:
	return _xf(p, k, "bind")


func stow_bone(p: String, k: String) -> String:
	var e := point(p, k)
	if e.has("stow"):
		return String(e.stow.bone)
	return String(e.get("bone", "pelvis"))


func _xf(p: String, k: String, field: String) -> Transform3D:
	var key := "%s.%s|%s" % [p, k, field]
	if _xf_cache.has(key):
		return _xf_cache[key]
	var e := point(p, k)
	var t := Transform3D.IDENTITY
	if e.has("stow") and e.stow.has(field):
		var v: Variant = str_to_var(String(e.stow[field]))
		if v is Transform3D:
			t = v
	_xf_cache[key] = t
	return t


func draw_set(id: String) -> Dictionary:
	return carry.get("draw_sets", {}).get(id, {})


## The draw set used for a placement (its first "draw" entry), {} if none.
func draw_set_of(p: String, k: String) -> Dictionary:
	var e := point(p, k)
	var ds: Array = e.get("draw", [])
	if ds.is_empty():
		return {}
	var d := draw_set(String(ds[0]))
	if d.is_empty():
		return {}
	d = d.duplicate(true)
	d["id"] = String(ds[0])
	return d


func gear(id: String) -> Dictionary:
	return carry.get("gear", {}).get(id, {})


func pistol_cap() -> int:
	return int(carry.get("pistol_cap", 4))


## Extra standoff (m) of `over` (e.g. "long_A.musket") where it crosses `under`; 0 when none.
func layering_extra(over: String, under: String) -> float:
	var ex: Dictionary = carry.get("back_layering", {}).get("extra_standoff_cm", {})
	return float(ex.get("%s over %s" % [over, under], 0.0)) * 0.01


## Layer of a placement on the back: 0 body items, 1 quiver, 2 long_B, 3 long_A.
static func layer_of(p: String) -> int:
	match p:
		"quiver": return 1
		"long_B": return 2
		"long_A": return 3
	return 0


# --- presets ----------------------------------------------------------------------------------

func preset_ids() -> Array:
	return presets.get("presets", {}).keys()


func preset(id: String) -> Dictionary:
	return presets.get("presets", {}).get(id, {})


func default_preset() -> String:
	return String(presets.get("default", "musket_bow"))


# --- runtime parameters (sling_runtime.json) --------------------------------------------------

func rt(key: String, fallback: Variant = null) -> Variant:
	return runtime.get(key, fallback)


## Outfit bulk offset (m, along the outward normal) of `region` for a body_fit outfit key, relative to
## the legacy coat the placements were measured on. `which`: 0 min, 1 typical, 2 max.
func bulk_offset(outfit: String, region: String, which := 1) -> float:
	var ob: Dictionary = body_fit().get("outfit_bulk", {})
	var ref: Dictionary = ob.get("reference_legacy_coat_mm", {})
	var o: Dictionary = ob.get("outfits", {}).get(outfit, {})
	if outfit == "" or outfit == "legacy" or not o.has(region):
		return 0.0
	var v: Array = o[region]
	return (float(v[clampi(which, 0, v.size() - 1)]) - float(ref.get(region, 0.0))) * 0.001


## Limb capsule radii (m) of the survey (body_fit.json method.limbs radius_p90).
func limb_radii() -> Dictionary:
	var out := {}
	var lm: Dictionary = body_fit().get("method", {}).get("limbs", {})
	for ln: String in lm:
		out[ln] = float(lm[ln].get("radius_p90", 0.05))
	if out.is_empty():
		out = {"r_upper_arm": 0.07, "r_forearm": 0.049, "r_hand": 0.049, "l_upper_arm": 0.072, "l_forearm": 0.049,
				"l_hand": 0.05, "r_thigh": 0.094, "r_shin": 0.077, "l_thigh": 0.094, "l_shin": 0.077, "head": 0.115}
	return out
