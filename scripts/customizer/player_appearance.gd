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
	pa.apply(AppearanceStore.load_current())
	ensure_input()
	if offer_creator() or MainMenu.take_new_game():     # (the first launch, or the main menu's New game)
		pa._offer_creator.call_deferred()
	return pa


## True at the first launch of the game: no saved look, a normal run (not a tool or test run
## with -s, not headless, no --appearance or --no-creator; `check_run` false skips these run
## checks, for tests).
static func offer_creator(check_run := true) -> bool:
	if check_run:
		var loop := Engine.get_main_loop()
		if loop == null or loop.get_script() != null or DisplayServer.get_name() == "headless":
			return false
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--appearance") or a == "--no-creator":
				return false
	return not FileAccess.file_exists(AppearanceStore.CURRENT)


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
## applies `lk`. Returns what PlayerOutfit.dress() did (has_hat, hide_regions, bulk_slots for the slung gear, parts).
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
	return fit


func apply(lk: Dictionary) -> void:
	look = AppearanceStore.validate(lk)
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


static func _set_hide(mi: MeshInstance3D, mask: Vector2i) -> void:
	if not is_instance_valid(mi) or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as ShaderMaterial
		if m and m.shader and m.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "hide_mask"):
			m.set_shader_parameter("hide_mask", mask)


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
