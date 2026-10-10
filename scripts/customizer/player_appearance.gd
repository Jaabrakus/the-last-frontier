class_name PlayerAppearance
extends Node
## The player's face, skin, eyes, brows and hair from the customizer, on the game's body.
##
## The body is the customizer's body v4 (assets/character/body/body.glb: the whole MakeHuman body, with the pubic hair
## part), added as the part "head" on the game's CharacterBodyMesh (one shared Skin, one helper driver), dressed with
## the garments of the look's outfit (PlayerOutfit: cloth2 garments grown from that body; the basic dress of a shirt and
## breeches or a shift and a petticoat unless the look chooses). The legacy outfit
## (assets/character/actor_b_body.glb) still gives the skeleton its binds but is not drawn. The slung gear rests on the
## outfit's bulk (SlingRig).
##
## O opens the character creator (CharacterCreator; its Fine-tune opens the detailed
## CustomizerOverlay); Accept calls apply() and saves the look. At the first launch (no saved
## look; not in tool or test runs, not headless, no --appearance, no --no-creator) the creator
## opens by itself. FaceBlink blinks the eyes (the `blink` shape) every few seconds.
##
##   var app := PlayerAppearance.install(player, skeleton)   # player._build_character() calls it
##   app.apply(CharacterPeoples.preset_look("japanese_f_a"))

signal look_changed(look: Dictionary)

const ACTION := &"customize"

var body: CharacterBodyMesh
var look := {}
var blink: FaceBlink
var overlay: Node
## Customizer garments worn over the legacy outfit, slot -> id (PlayerOutfit.dress bulk_slots).
var outfit_slots := {}
## The back of the skirt rolled up (the tandem crawl; set_rolled), the breeches down (a tandem partner; set_pants_down);
## the dress as PlayerOutfit fitted it (hide_regions, hide_hair_zones, has_hat), to show again what they uncover.
var rolled := false
var pants_down := false
var _fit := {}
var _was_down := false


## Adds the appearance to `player` (under it, named "Appearance") and dresses its body with
## the saved look (AppearanceStore.load_current()). Returns null without a CharacterBodyMesh.
static func install(player: Node, skeleton: Skeleton3D) -> PlayerAppearance:
	var b: CharacterBodyMesh = skeleton.get_node_or_null("Body") as CharacterBodyMesh if skeleton else null
	if b == null:
		return null
	var pa := PlayerAppearance.new()
	pa.name = "Appearance"
	pa.body = b
	player.add_child(pa)
	var saved := AppearanceStore.load_current()
	pa.apply(saved if SurvivalBridge.bare_ahead() else ClothesSlots.restored(saved))     # (a normal start in its own clothes)
	ensure_input()
	# (the first launch, or the main menu's New game; never over a Tidebreak match's countdown: the menu offers the creator
	# on the first press of the sport instead, MainMenu._open_match)
	if (offer_creator() and not MatchSetup.active()) or MainMenu.take_new_game():
		pa._offer_creator.call_deferred()
	return pa


## True at the first launch of the game: no saved look and the creator not offered before (Back on the offer saves no
## look but marks it made: AppearanceStore.mark_offered), a normal run (not a tool or test run with -s, not headless,
## no --appearance or --no-creator; `check_run` false skips these run checks, for tests).
static func offer_creator(check_run := true) -> bool:
	if check_run:
		var loop := Engine.get_main_loop()
		if loop == null or loop.get_script() != null or DisplayServer.get_name() == "headless":
			return false
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--appearance") or a == "--no-creator":
				return false
	return not FileAccess.file_exists(AppearanceStore.current_path()) and not AppearanceStore.was_offered()


## The post-Accept hook of the creator (the main menu's `_after_creator`; the creator itself is untouched): whether the step to
## choose the character's element comes next, that is, the creator was accepted (Back keeps no look, so no step) and the saved
## character has none yet (AppearanceStore.element()). A look that has its element is not asked again.
static func element_due(accepted: bool) -> bool:
	return accepted and AppearanceStore.element() == ""


## The element of the look worn now ("" until chosen).
func element() -> String:
	return AppearanceStore.clean_element(look.get("element", ""))


func _offer_creator() -> void:
	# after the level's first frames (its loading and HUD set-up)
	for i in 3:
		await get_tree().process_frame
	if is_inside_tree() and not is_instance_valid(overlay):
		overlay = CharacterCreator.open(self, true)


static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_O
	InputMap.action_add_event(ACTION, e)


## The look dictionary (BodyMaterials.apply_look keys) for the dressed body: the full fit, the regions the garments
## cover hidden (`fit`: what PlayerOutfit.dress returned), the hair pressed flat under a hat.
static func dressed_look(lk: Dictionary, fit: Dictionary) -> Dictionary:
	var out := lk.duplicate(true)
	out["outfit_fit"] = "full"
	out["hide_regions"] = (fit.get("hide_regions", []) as Array).duplicate()
	out["hide_hair_zones"] = (fit.get("hide_hair_zones", []) as Array).duplicate()
	out["hat_fit"] = 1.0 if bool(fit.get("has_hat", false)) else 0.0
	return out


## Puts body v4 (the part "head") with the look's hair and pubic hair on a CharacterBodyMesh, the garments of its
## outfit over it (PlayerOutfit: the basic dress unless the look chooses), the legacy outfit's meshes hidden, and
## applies `lk`; then the Character look (SoftLook.apply_body). Returns what PlayerOutfit.dress() did (has_hat, hide_regions,
## bulk_slots for the slung gear, parts).
static func dress(b: CharacterBodyMesh, lk: Dictionary) -> Dictionary:
	if b.part_meshes("head").is_empty():
		b.add_part("head", BodyMaterials.BODY_GLB)
	var outfit: Dictionary = lk.get("outfit", {}) if lk.get("outfit") is Dictionary else {}
	var fit := PlayerOutfit.dress(b, outfit, float(lk.get("sex", 0.0)))
	BodyMaterials.apply_look(b, dressed_look(lk, fit), ["head", "body_hair"] + (fit.parts as Array))
	var own := {}
	for t in b.parts:
		for mi in b.parts[t]:
			own[mi] = true
	for mi: MeshInstance3D in b.meshes:
		if is_instance_valid(mi) and not own.has(mi):
			mi.visible = false
	# (the Character look: Soft puts soft copies of the materials on, Classic leaves them as made; SoftLook)
	SoftLook.apply_body(b)
	return fit


## `lk` validated; the element of the look `was` carried over when `lk` has none (a look the creator builds anew, for another
## people or a body type, carries none: the character keeps its own).
static func carry_element(lk: Dictionary, was: Dictionary) -> Dictionary:
	var out := AppearanceStore.validate(lk)
	var kept := AppearanceStore.clean_element(was.get("element", ""))
	if kept != "" and not lk.has("element"):
		out["element"] = kept
	return out


func apply(lk: Dictionary) -> void:
	look = carry_element(lk, look)
	var fit := dress(body, look)
	outfit_slots = fit.get("bulk_slots", {})
	_fit = fit.duplicate(true)
	rolled = false
	pants_down = false
	if blink == null:
		blink = FaceBlink.new()
		blink.name = "FaceBlink"
		add_child(blink)
	blink.body = body
	_sync_gear.call_deferred()
	look_changed.emit(look)


## The back rolled up (on all fours in the tandem crawl, FrontierPlayer: the petticoat's back is rolled onto the lower
## back, CharacterBodyMesh.skirt_tuck_back) or let down: rolled, the linen under it (the shirt slot: a shift, a shirt)
## is rolled up with it, its part below the waist not drawn (ROLLED_GARMENT_HIDES), and the skin it and the petticoat
## covered there is drawn again (ROLLED_SHOWS: the user 2026-09-29, "see the white around the buttocks, and in the
## side view we lose the buttocks").
const ROLLED_SHOWS := ["pelvis_side", "thigh_upper_l", "thigh_upper_r"]
const ROLLED_GARMENT_HIDES := ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_lower_l", "thigh_upper_r",
		"thigh_lower_r"]


## The breeches down at the knees (the partner in a tandem pose: kneeling behind the crawl, the plank over Happy Baby;
## FrontierPlayer; the user 2026-09-29: "for the men's yoga poses of crawl, kneel and plank the pants roll to the knees
## exposing the genitals"): the legs garment is drawn only below the thighs' upper half (PANTS_GARMENT_HIDES: what is
## left of it lies about the knees), the shirt's tails rolled up as in the crawl, and the skin they covered drawn again
## with its own dress (PANTS_SHOWS: the genitals with their hair and their swing, as bare).
const PANTS_SHOWS := ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r"]
const PANTS_GARMENT_HIDES := ["abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side",
		"thigh_upper_l", "thigh_upper_r"]


func set_rolled(on: bool) -> void:
	if on == rolled or body == null:
		return
	rolled = on
	_undress()


func set_pants_down(on: bool) -> void:
	if on == pants_down or body == null:
		return
	pants_down = on
	_undress()


## The body and the garments for what is rolled up or down now (set_rolled, set_pants_down).
func _undress() -> void:
	var shown: Array = []
	var cloth := {"outfit:shirt": [], "outfit:legs.lower": []}
	if rolled or pants_down:
		shown.append_array(ROLLED_SHOWS)
		cloth["outfit:shirt"] = ROLLED_GARMENT_HIDES
	if pants_down:
		shown.append_array(PANTS_SHOWS)
		cloth["outfit:legs.lower"] = PANTS_GARMENT_HIDES
	var fit := _fit.duplicate(true)
	fit["hide_regions"] = (_fit.get("hide_regions", []) as Array).filter(func(r: String) -> bool: return not r in shown)
	# (the skin's hide mask, the pubic hair part and the genitals' swing follow the dressed look's hide_regions)
	BodyMaterials.apply_look(body, dressed_look(look, fit), ["head", "body_hair"])
	for tag: String in cloth:
		var mask := BodyMaterials.hide_mask(cloth[tag])
		for mi: MeshInstance3D in body.part_meshes(tag):
			_set_hide(mi, mask)
	SoftLook.apply_body(body)                # (apply_look made new skin materials: the Character look on them too)


static func _set_hide(mi: MeshInstance3D, mask: Vector2i) -> void:
	if not is_instance_valid(mi) or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as ShaderMaterial
		if m and m.shader and m.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "hide_mask"):
			m.set_shader_parameter("hide_mask", mask)


## THE ARENA'S DRESS (Tidebreak's ring; FrontierPlayer.arena): the element side's ring dress (the catalog's set "ring",
## built by tools/asset_author/build_ring_garments.py; the owner 2026-10-05: assets in the spirit of the inspiration, our
## own cuts), the same garments the ring's bots of that element wear: data/npc/factions.json ARENA_FACTION's
## element_dress[element], slot -> {id, colors} (earth: the wrap tunic, wrapped trousers, sash, arm wraps, shoes; water:
## the fur-trimmed parka, fitted trousers, belt, boots; fire: the sleeveless top, fitted trousers, sash, wrist guards,
## shoes; air: the long tunic, wide trousers, sash, shoes); every other slot empty (no hat, no musket gear). Without
## those garments (a catalog without the ring set) the old athletic dress: the basic shirt dyed the element's colour
## (MatchSetup.color), plain trousers, a sash. The face, the skin, the hair stay the saved look's; nothing is saved (the
## look on file is the player's own, worn again out of the ring).
const ARENA_FACTION := "ring_team_a"
const ARENA_LEGS := {"men": "breeches", "women": "salvar_mens"}
const ARENA_SASH := "sash_worsted"


## The ring dress of `element` (ARENA_FACTION's element_dress entries with a garment id), every other slot "-"; {} when
## the faction has none for it or one of its garments is not in this build.
static func ring_dress(element: String) -> Dictionary:
	var dress: Variant = (NpcFactions.get_faction(ARENA_FACTION).get("element_dress", {}) as Dictionary).get(element)
	if not dress is Dictionary:
		return {}
	var out := {}
	for slot: String in PlayerOutfit.SLOTS:
		out[slot] = {"id": "-", "colors": {}}
	var any := false
	for slot: String in dress:
		var v: Variant = (dress as Dictionary)[slot]
		if not (v is Dictionary and (v as Dictionary).has("id")) or not slot in PlayerOutfit.SLOTS:
			continue
		var id := String((v as Dictionary).id)
		if id != "-" and not PlayerOutfit.usable(id):
			return {}
		out[slot] = {"id": id, "colors": ((v as Dictionary).get("colors", {}) as Dictionary).duplicate()}
		any = any or id != "-"
	return out if any else {}


static func arena_outfit(element: String, sex: float) -> Dictionary:
	var ring := ring_dress(element)
	if not ring.is_empty():
		return ring
	var col := MatchSetup.color(element)
	var dark := col.darkened(0.55)
	var out := {}
	for slot: String in PlayerOutfit.SLOTS:
		out[slot] = {"id": "-", "colors": {}}
	var bt := PlayerOutfit.body_type(sex)
	out["shirt"] = {"id": String(PlayerOutfit.BASIC[bt].get("shirt", "")), "colors": {"0": "#" + col.to_html(false),
			"1": "#" + col.lightened(0.35).to_html(false)}}
	var legs := String(ARENA_LEGS.get(bt, ""))
	if not PlayerOutfit.usable(legs):
		legs = String(PlayerOutfit.BASIC[bt].get("legs.lower", ""))
	out["legs.lower"] = {"id": legs, "colors": {"0": "#" + dark.to_html(false), "1": "#" + col.to_html(false)}}
	if PlayerOutfit.usable(ARENA_SASH):
		out["accessories.waist"] = {"id": ARENA_SASH, "colors": {"0": "#" + col.to_html(false),
				"1": "#" + col.lightened(0.4).to_html(false), "3": "#" + col.lightened(0.2).to_html(false)}}
	return out


## The arena's dress for `element` on the body (see arena_outfit); the rest of the look as it is.
func arena_dress(element: String) -> void:
	if body == null or not element in Bending.ELEMENTS:
		return
	var lk := look.duplicate(true)
	lk["outfit"] = arena_outfit(element, float(lk.get("sex", 0.0)))
	apply(lk)


## The slung weapons, quiver and belt items sit on the outfit's bulk (SlingRig, body_fit.json): the
## player's loadout keeps the outfit key, so a SlingRig installed later (inventory) keeps it too.
func _sync_gear() -> void:
	var p := get_parent()
	if p == null:
		return
	var rig = p.get("gear") if "gear" in p else null
	if rig is SlingRig and is_instance_valid(rig):
		(rig as SlingRig).set_outfit_from_appearance(outfit_slots)
	elif "loadout" in p and p.get("loadout") is Loadout:
		(p.get("loadout") as Loadout).outfit_bulk = PlayerOutfit.bulk_key(outfit_slots)


func open_customizer() -> void:
	if is_instance_valid(overlay):
		return
	overlay = CharacterCreator.open(self)


## O does not open the creator in a game (user 2026-10-01: "o should never open while the game starts"): the creator is the new
## game's (offer_creator, the main menu's New game); a spouse's look is changed from her sheet (GearTab.customize).
