class_name LoadoutDrawClips
extends RefCounted
## The clips of a draw set (data/loadout/carry_gear.json draw_sets) laid out on a timeline, for the
## preview and the handoff test: a draw is [grab clip + its additive twin] then [equip clip + twin]; a
## holster is the equip clip played backwards, then the finish (the graph's holster_finish row, only when
## nothing follows; the stow clip for hands free, draw_sets.*.sling_all_finish). Times are natural clip
## seconds (the caller multiplies real time by the rate, the graph's quick flag = x2).
##
##   var dc := LoadoutDrawClips.new(entry.ds, "stand", poser)
##   if dc.ok: layers += dc.draw_layers(tn); rig.drive(id, dc.draw_role(tn), dc.draw_phase(tn))
##
## Mirrored clips ("M:<clip>", the left-hip pistol and the right-chest flashlight draw) are not built
## yet (loadout_design.md 8.1.3); such a set reports ok = false.

var ok := true
var grab := ""
var grab_twin := ""
var equip := ""
var equip_twin := ""
var finish := ""
var sling_finish := ""
var grab_s := 0.0
var equip_s := 0.0
var missing: Array[String] = []


func _init(ds: Dictionary, stance: String, poser: LoadoutClipPoser) -> void:
	if ds.has("grab"):
		grab = String(ds.grab)
		grab_twin = String(ds.get("grab_twin", ""))
		equip = String(ds.get("equip", ""))
		equip_twin = String(ds.get("equip_twin", ""))
	elif ds.has("equip"):
		equip = String(ds.equip)
	elif ds.has(stance) or ds.has("stand"):
		equip = String(ds.get(stance, ds.get("stand", "")))
	var hf: Variant = ds.get("holster_finish", {})
	if hf is Dictionary:
		finish = String((hf as Dictionary).get(stance, ""))
	var sf: Variant = ds.get("sling_all_finish", {})
	if sf is Dictionary:
		sling_finish = String((sf as Dictionary).get(stance, ""))
	for f in ["grab", "grab_twin", "equip", "equip_twin", "finish", "sling_finish"]:
		var c := String(get(f))
		if c.begins_with("M:"):
			ok = false
			missing.append(c)
		elif c != "" and (c.contains(" ") or not poser.has_clip(c)):
			if f in ["grab", "equip"]:
				missing.append(c)
			set(f, "")
	if equip == "" or (ds.has("grab") and grab == ""):
		ok = false
	grab_s = poser.length(grab) if grab != "" else 0.0
	equip_s = poser.length(equip) if equip != "" else 0.0


func draw_length() -> float:
	return grab_s + equip_s


func draw_role(tn: float) -> String:
	return "grab" if grab_s > 0.0 and tn < grab_s else "draw"


func draw_phase(tn: float) -> float:
	if grab_s > 0.0 and tn < grab_s:
		return tn / grab_s
	return clampf((tn - grab_s) / maxf(equip_s, 1e-4), 0.0, 1.0)


## Partial + additive layers of a draw at natural time tn (after the draw: its last frame, the carry pose).
func draw_layers(tn: float) -> Array:
	if grab_s > 0.0 and tn < grab_s:
		return _pair(grab, grab_twin, tn)
	return _pair(equip, equip_twin, clampf(tn - grab_s, 0.0, equip_s))


## Holster at natural time tn: the equip clip backwards, then `fin` (finish clip or "").
func holster_layers(tn: float, fin: String) -> Array:
	if tn < equip_s:
		return _pair(equip, equip_twin, equip_s - tn)
	if fin != "":
		return [[fin, tn - equip_s, "partial"]]
	return []


func holster_role(tn: float) -> String:
	return "holster" if tn < equip_s else "finish"


func holster_phase(tn: float) -> float:
	return clampf(tn / maxf(equip_s, 1e-4), 0.0, 1.0)


static func _pair(c: String, twin: String, t: float) -> Array:
	var out: Array = [[c, t, "partial"]]
	if twin != "":
		out.append([twin, t, "add"])
	return out
