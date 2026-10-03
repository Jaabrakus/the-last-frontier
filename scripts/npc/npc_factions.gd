class_name NpcFactions
extends RefCounted
## The sides people fight for (data/npc/factions.json): a faction's side, the sides it is hostile to, its fighters' looks,
## garments, weapons, steadiness, barks and loot. Built for the 1757 German Flatts raid (French marines and Canadian militia
## against the valley's militia), toughs, later city guards and the sky crews (the Long Patience's men, hostile to no one
## until a story's turn).
##   NpcFactions.hostile("french_marine", "militia")    -> true    (a fighter's foes: other factions, or "player")
##   NpcFactions.set_hostile("toughs", "british", true)            (a story's turn: one side now attacks the other)
##   NpcFactions.look_for("militia", rng)                -> a look dictionary (a peoples preset dressed in the faction's garments)
##   NpcFactions.outfit_of("militia", 1.0, rng)          -> one fighter's outfit (each man his own: see outfit_of)
## No Native fighters: a preset of the Eastern Woodlands peoples, or of a people with Native ancestry, is never used for a
## fighter (those are consultation slots: docs/main_story.md, "What the consultation rule means for this story").

const PATH := "res://data/npc/factions.json"
## The player's own side (FrontierPlayer is of it).
const PLAYER := "player"
## Peoples presets never dressed as fighters (the consultation rule).
const CONSULT_PEOPLES := ["haudenosaunee", "lenape", "shawnee", "wabanaki", "metis", "afro_native"]
const CONSULT_GROUPS := ["Eastern Woodlands"]

static var _data := {}
## Run-time changes to hostility: "sideA>sideB" -> bool (set_hostile).
static var _override := {}


static func all() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = (d.get("factions", {}) if d is Dictionary else {}) as Dictionary
	return _data


static func get_faction(id: String) -> Dictionary:
	return all().get(id, {})


## The side `id` fights on ("player" for the player; a faction's own id when it names none).
static func side_of(id: String) -> String:
	if id == PLAYER:
		return PLAYER
	return String(get_faction(id).get("side", id))


## Whether fighters of factions `a` and `b` (or the player, "player") are foes: either side attacks the other on sight (the
## other fights back), unless set_hostile has said otherwise.
static func hostile(a: String, b: String) -> bool:
	if a == b:
		return false
	var sa := side_of(a)
	var sb := side_of(b)
	if sa == sb:
		return false
	var key := sa + ">" + sb
	if _override.has(key):
		return bool(_override[key])
	return sb in (get_faction(a).get("hostile", []) as Array) or sa in (get_faction(b).get("hostile", []) as Array)


## A side now attacks another (or no longer does): both ways. For the level it is set in: NpcSenses (made here if there is
## none yet) clears the changes when the level goes, so they never carry into the next game; a save keeps them with saved()
## and a load gives them back with restore().
static func set_hostile(side_a: String, side_b: String, on: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null and tree.current_scene.is_node_ready():
		NpcSenses.of(tree)
	_override[side_a + ">" + side_b] = on
	_override[side_b + ">" + side_a] = on


static func clear_overrides() -> void:
	_override.clear()


## The run-time changes to hostility, for a save ("sideA>sideB" -> bool).
static func saved() -> Dictionary:
	return _override.duplicate()


## The changes a save kept, back (those made since are dropped).
static func restore(d: Dictionary) -> void:
	_override.clear()
	for k: Variant in d:
		_override[String(k)] = bool(d[k])


## Whether a peoples preset may be dressed as a fighter (not a consultation slot).
static func usable_preset(preset_id: String) -> bool:
	var pr := CharacterPeoples.preset(preset_id)
	if pr.is_empty():
		return false
	var people := String(pr.get("people", ""))
	if people in CONSULT_PEOPLES:
		return false
	return not String(CharacterPeoples.people(people).get("group", "")) in CONSULT_GROUPS


## A look for a fighter of `id`: one of its presets (validated by AppearanceStore), in its outfit (outfit_of, this
## fighter's own pick of its garments and colours).
static func look_for(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var f := get_faction(id)
	var looks: Array = (f.get("looks", []) as Array).filter(func(p: Variant) -> bool: return usable_preset(String(p)))
	var preset := String(looks[rng.randi() % looks.size()]) if not looks.is_empty() else "scots_irish_m_a"
	var look := CharacterPeoples.preset_look(preset)
	look["outfit"] = outfit_of(id, float(look.get("sex", 1.0)), rng)
	return look


## What a fighter of `id` wears (a look's "outfit": {slot: {id, colors}}). Each slot of the faction's "outfit": the first
## garment of its wants this build dresses in (PlayerOutfit.usable), or, when the faction's "outfit_mix" weighs the
## slot ({slot: {id: weight}}; the id "-" is nothing in that slot), one of its usable ids picked by weight (2026-10-03:
## an ununiformed militia, not one blue-and-buff man forty times). Its colours are the faction's garment_colors for
## that garment (zone tokens, or a catalog colour "preset": PlayerOutfit.resolve_colors); a list there is one choice
## per fighter, a whole colour dictionary or a single zone's token alike. The faction's "drop_under" ({outer id: [slots]})
## takes off what a closed coat hides entirely (a veste under the capot: 5k triangles nobody sees). The basic dress of
## a body of `sex`, in the faction's "colors" (lists picked the same way), fills the slots none of those fill.
## Without `rng` every pick is the first (the deterministic uniform: the customizer's preset, the checks).
static func outfit_of(id: String, sex := 1.0, rng: RandomNumberGenerator = null) -> Dictionary:
	var f := get_faction(id)
	var outfit := {}
	var wants: Dictionary = f.get("outfit", {})
	var mix: Dictionary = f.get("outfit_mix", {}) if f.get("outfit_mix") is Dictionary else {}
	var gcol: Dictionary = f.get("garment_colors", {}) if f.get("garment_colors") is Dictionary else {}
	for slot: String in wants:
		var gid := _pick_garment(wants[slot] as Array, mix.get(slot), rng)
		if gid == "" or gid == "-":
			continue
		outfit[slot] = {"id": gid, "colors": _pick_colors(gcol.get(gid, {}), rng)}
	var drop: Dictionary = f.get("drop_under", {}) if f.get("drop_under") is Dictionary else {}
	var outer := String((outfit.get("outer", {}) as Dictionary).get("id", ""))
	for slot: Variant in drop.get(outer, []):
		outfit.erase(String(slot))
	var colors: Dictionary = f.get("colors", {})
	var basic := PlayerOutfit.basic(sex)
	for slot: String in basic:
		if not outfit.has(slot):
			outfit[slot] = {"id": String(basic[slot].id), "colors": _pick_colors(colors.get(slot, {}), rng)}
	return outfit


## The garment a fighter wears in a slot: the first usable of `wants`, or (a `mix` {id: weight} and an rng) one of the mix's
## usable ids by weight ("-": none). Without an rng, a mix gives its heaviest usable id ("-" counts).
static func _pick_garment(wants: Array, mix: Variant, rng: RandomNumberGenerator) -> String:
	if mix is Dictionary and not (mix as Dictionary).is_empty():
		var ids: Array = []
		var ws: Array = []
		for k: Variant in mix:
			var gid := String(k)
			if gid == "-" or PlayerOutfit.usable(gid):
				ids.append(gid)
				ws.append(maxf(float(mix[k]), 0.0))
		if not ids.is_empty():
			if rng == null:
				var best := 0
				for i in ids.size():
					if float(ws[i]) > float(ws[best]):
						best = i
				return String(ids[best])
			var total := 0.0
			for w: float in ws:
				total += w
			var r := rng.randf() * total
			for i in ids.size():
				r -= float(ws[i])
				if r <= 0.0:
					return String(ids[i])
			return String(ids[ids.size() - 1])
	for gid: Variant in wants:
		if PlayerOutfit.usable(String(gid)):
			return String(gid)
	return ""


## A fighter's colours of one garment from the faction's entry: a list is one choice (a colour dictionary each); in the
## dictionary a list of tokens is one choice for that zone. Without an rng, the first of each.
static func _pick_colors(gc: Variant, rng: RandomNumberGenerator) -> Dictionary:
	if gc is Array:
		var a: Array = gc
		gc = a[rng.randi() % a.size()] if rng != null and not a.is_empty() else (a[0] if not a.is_empty() else {})
	if not (gc is Dictionary):
		return {}
	var out := {}
	for k: Variant in gc:
		var v: Variant = gc[k]
		if v is Array:
			var a: Array = v
			out[k] = a[rng.randi() % a.size()] if rng != null and not a.is_empty() else (a[0] if not a.is_empty() else "")
		else:
			out[k] = v
	return out


## A line for `what` ("alert", "combat", "flee", "surrender", "talk"), or "".
static func bark(id: String, what: String, rng: RandomNumberGenerator) -> String:
	var lines: Array = (get_faction(id).get("barks", {}) as Dictionary).get(what, [])
	return String(lines[rng.randi() % lines.size()]) if not lines.is_empty() else ""


## A [lo, hi] number pair of the faction's (`fallback` when it has none), picked between.
static func pick(id: String, key: String, fallback: Vector2, rng: RandomNumberGenerator) -> float:
	var v: Variant = get_faction(id).get(key)
	if v is Array and (v as Array).size() >= 2:
		return rng.randf_range(float(v[0]), float(v[1]))
	return rng.randf_range(fallback.x, fallback.y)
