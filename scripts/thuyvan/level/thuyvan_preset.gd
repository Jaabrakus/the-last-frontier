class_name ThuyVanPreset
extends RefCounted
## The greybox's Mountain Folk (data/world/maps/r1_grey/mountain_folk.json; plan phase 1, T5): a look made through the
## creator's own preset machinery (CharacterPeoples.preset_look, its faces), weathered, and dressed in today's garments
## nearest the Common Folk sheet (PlayerOutfit: the first garment of each slot's list this build has). Nothing new is
## made: no garment, no texture. The look on file (AppearanceStore) is never written: PlayerAppearance.apply dresses the
## body only.
##
##   ThuyVanPreset.dress(player)        # the player's body, its body type kept (ThuyVanLevel)
##   ThuyVanPreset.look(1.0)            # a man's look (the watchers: StoryWalker.make)

const PATH := "res://data/world/maps/r1_grey/mountain_folk.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {}
	return _data


## The Mountain Folk look for body type `sex` (1 a man's, 0 a woman's): {} when this build has no face to make it from.
## `pick` takes the n-th face of the list (watchers each their own).
static func look(sex: float, pick := 0) -> Dictionary:
	var d := data()
	var sx := "m" if sex >= 0.5 else "f"
	var lk := {}
	var faces: Array = (d.get("faces", {}) as Dictionary).get(sx, [])
	for i in faces.size():
		lk = CharacterPeoples.preset_look(String(faces[(i + pick) % faces.size()]))
		if not lk.is_empty():
			break
	# none of those in this build: the first face of the first people like them (the creator's own list)
	if lk.is_empty():
		for p: Dictionary in CharacterPeoples.peoples():
			var pid := String(p.get("id", ""))
			for like: Variant in d.get("people_like", []):
				if lk.is_empty() and pid.contains(String(like)):
					var prs := CharacterPeoples.presets(pid, 1.0 if sex >= 0.5 else 0.0)
					if not prs.is_empty():
						lk = CharacterPeoples.preset_look(String((prs[pick % prs.size()] as Dictionary).get("id", "")))
	if lk.is_empty():
		return {}
	var over: Dictionary = d.get("look", {})
	for k: String in over:
		lk[k] = over[k]
	lk["outfit"] = outfit()
	return lk


## The outfit ({slot: {id, colors}}): each slot's first garment this build dresses in ("-": bare). A garment further down
## a list (a stand-in) takes the zone colours without the first one's catalog preset.
static func outfit() -> Dictionary:
	var out := {}
	var want: Dictionary = data().get("outfit", {})
	for slot: String in PlayerOutfit.SLOTS:
		var w: Variant = want.get(slot)
		if not w is Dictionary:
			continue
		var ids: Array = (w as Dictionary).get("ids", [])
		for i in ids.size():
			var id := String(ids[i])
			if id == "-":
				out[slot] = {"id": "-", "colors": {}}
				break
			if PlayerOutfit.usable(id):
				var colors: Dictionary = ((w as Dictionary).get("colors", {}) as Dictionary).duplicate()
				if i > 0:
					colors.erase("preset")
				out[slot] = {"id": id, "colors": colors}
				break
	return out


## Dresses `player` as Mountain Folk (its body type kept). False without an appearance or a face to make it from.
static func dress(player: FrontierPlayer) -> bool:
	if player == null or player.appearance == null:
		return false
	var sex := float(player.appearance.look.get("sex", 1.0))
	var lk := look(sex)
	if lk.is_empty():
		push_warning("ThuyVanPreset: no face in this build for the Mountain Folk preset; the saved look is kept.")
		return false
	player.appearance.apply(lk)
	return true
