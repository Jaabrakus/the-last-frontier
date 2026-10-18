extends Node3D
## Local playable reference lab. Source geometry remains in ignored artifacts;
## no shipping defaults, imported resources, appearance files or saves are changed.

const LabWorld := preload("res://scripts/labs/asset_lab_world.gd")
const ReferenceParts := preload("res://tools/reference_world/reference_character_parts.gd")
const ToonMaterials := preload("res://tools/reference_world/reference_toon_materials.gd")
const HANDS_PATH := "res://artifacts/world_reference/character_fit/link_hands_actor_b.glb"
const BODY_PATH := "res://artifacts/world_reference/character_fit/link_body_actor_b.glb"
const SOURCE_PIECES := "res://artifacts/world_reference/character_outfits/available_source_pieces/"
const MODELS := ["Current body", "Current body + fitted hands", "Fitted reference body"]
const OUTFITS := ["Sky tunic", "Green traveler", "Sleeveless training"]
const OUTFIT_ELEMENTS := ["earth", "earth", "fire"]
const WEAPONS := ["sword", "spear", "bow", "tomahawk", "spells"]

class LabControls extends PlayerControls:
	func _allowed() -> bool:
		return not from_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	func pressed(action: StringName) -> bool:
		return super.pressed(action) if _allowed() else false

	func just_pressed(action: StringName) -> bool:
		return super.just_pressed(action) if _allowed() else false

	func move_vector() -> Vector2:
		return super.move_vector() if _allowed() else Vector2.ZERO


class LabPlayer extends FrontierPlayer:
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# The click resumes the camera. It must not also swing, charge or cast.
			Input.action_release("fire")
			Input.action_release("aim")
			get_viewport().set_input_as_handled()
			return
		super._unhandled_input(event)


var player: FrontierPlayer
var world: Node3D
var current_body: CharacterBodyMesh
var source_body: CharacterBodyMesh
var caster: SwayCaster
var selected_model := 1
var selected_outfit := 0
var selected_weapon := "spells"
var selected_element := 0
var current_area := "map"
var reports: Dictionary = {}
var partners: Array[SparringPartner] = []
var training_target: FrontierPlayer
var target_hits := 0
var _hands_scene: PackedScene
var _native_meshes: Dictionary = {}
var _look: Dictionary = {}
var _panel: PanelContainer
var _status: Label
var _message: Label
var _help: Label
var _weapon_epoch := 0
var _timer := 0.0
var _model_choice: OptionButton
var _outfit_choice: OptionButton
var _weapon_choice: OptionButton
var _element_choice: OptionButton
var _spell_choice: OptionButton
var _spell_ids: Array[String] = []
var _wanted_spell := ""


func _ready() -> void:
	world = LabWorld.new()
	world.name = "TestMapAndArena"
	add_child(world)
	world.build()
	reports.world = world.report
	_build_player()
	_build_partners()
	_reference_stands()
	_build_ui()
	select_model(selected_model)
	select_element(0)
	go_to("map")
	if DisplayServer.get_name() != "headless" and not "--no-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_panel.hide()
	_message.text = "F1 / Esc: lab controls   ·   WASD: move   ·   Space: jump   ·   Shift: sprint"


func _build_player() -> void:
	player = LabPlayer.new()
	player.name = "LabPlayer"
	# Build the game controller without persistent appearance/customizer or world HUD.
	# Enable its normal local input afterwards; movement and animation still have one owner.
	player.is_local = false
	player.use_appearance = false
	player.character_scene = load("res://characters/Actor_B.tscn") as PackedScene
	player.demo_horse = false
	player.demo_wheelbarrow = false
	player.enable_grip = false
	player.enable_traversal = false
	player.show_gear = false
	player.torch_count = 0
	player.no_death = true
	player.controls = LabControls.new()
	player.weapon_order = ["bow"]
	player.camera_distance = 4.6
	player.shoulder_offset = 0.35
	player.ignore_mouse_capture = DisplayServer.get_name() == "headless"
	add_child(player)
	current_body = player.skeleton.get_node("Body") as CharacterBodyMesh
	_look = AppearanceStore.validate(CharacterPeoples.preset_look("vietnamese_m_a"))
	select_outfit(0)
	for mesh: MeshInstance3D in current_body.part_meshes("head"):
		_native_meshes[mesh] = mesh.mesh
	_hands_scene = _load_glb(HANDS_PATH)
	var full := _load_glb(BODY_PATH)
	if full:
		source_body = CharacterBodyMesh.new()
		source_body.name = "ReferenceBody"
		var ap := player.skeleton.get_parent().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		if source_body.build(player.skeleton, full, ap.get_animation("actor_b/null-add")):
			player.skeleton.add_child(source_body)
			reports.toon_materials = ToonMaterials.apply(source_body)
			_set_meshes(source_body, false)
			source_body.active = false
			reports.body_binding = source_body.report.duplicate(true)
		else:
			source_body.free()
			source_body = null
	caster = SwayCaster.install(player)
	Bending.of(player).element = "earth"
	for spell: Dictionary in SwayCaster.spells():
		caster.grant(String(spell.id), false)
	player.is_local = true
	player.camera.current = true
	player.hands_free = true
	player.anim.hands_free = true
	var arc := TrajectoryPreview.new()
	arc.name = "LabTrajectoryPreview"
	arc.player = player
	player.add_child(arc)
	player.gather.give("saber", 1)
	select_weapon("spells")


func _load_glb(path: String) -> PackedScene:
	if not FileAccess.file_exists(path):
		reports[path] = "Missing local reference file"
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		reports[path] = "GLB load failed: " + str(error)
		return null
	var node := document.generate_scene(state)
	if node == null:
		return null
	var packed := PackedScene.new()
	error = packed.pack(node)
	node.free()
	return packed if error == OK else null


func select_model(index: int) -> void:
	selected_model = clampi(index, 0, MODELS.size() - 1)
	if selected_model == 1 and _hands_scene == null or selected_model == 2 and source_body == null:
		selected_model = 0
	current_body.remove_part("fitted_hands")
	for mesh: MeshInstance3D in _native_meshes:
		if is_instance_valid(mesh):
			mesh.mesh = _native_meshes[mesh]
	# Dress resets only this lab instance, including the garment occlusion masks.
	_set_meshes(current_body, true)
	select_outfit(selected_outfit)
	if selected_model == 1:
		reports.hand_transfer = ReferenceParts.apply_hands(current_body, _hands_scene)
	current_body.active = selected_model != 2
	if source_body:
		source_body.active = selected_model == 2
		_set_meshes(source_body, selected_model == 2)
	if selected_model == 2:
		_set_meshes(current_body, false)
	_sync_choices()


func select_outfit(index: int) -> void:
	selected_outfit = clampi(index, 0, OUTFITS.size() - 1)
	_look["outfit"] = PlayerAppearance.arena_outfit(OUTFIT_ELEMENTS[selected_outfit], float(_look.get("sex", 1.0)))
	if selected_outfit == 0:
		# Closed tunic silhouette with fitted trousers and tall boots for this lab.
		var fitted := PlayerAppearance.arena_outfit("fire", 1.0)
		var boots := PlayerAppearance.arena_outfit("water", 1.0)
		_look.outfit["legs.lower"] = fitted["legs.lower"].duplicate(true)
		_look.outfit["feet"] = boots["feet"].duplicate(true)
		_look.outfit["accessories.arms"] = {"id": "-", "colors": {}}
	var palette: Array = [["#3d86ab", "#e3d8b7"], ["#5c8050", "#d4c08a"], ["#9c5140", "#e4c894"]][selected_outfit]
	for slot: String in _look.outfit:
		var entry: Dictionary = _look.outfit[slot]
		if String(entry.get("id", "-")) != "-":
			entry.colors = {"0": palette[0], "1": palette[1], "2": "#715640", "3": palette[1]}
	if selected_outfit == 0:
		_look.outfit["legs.lower"].colors = {"0": "#d0c3a0", "1": "#8b7553", "2": "#715640"}
		_look.outfit["feet"].colors = {"0": "#66503a", "1": "#b4a58a", "2": "#715640"}
		_look.outfit["accessories.waist"].colors = {"0": "#70583d", "1": "#a6946f", "3": "#70583d"}
	PlayerAppearance.dress(current_body, _look)
	if source_body:
		# A clothing-fit prototype using existing project garments on the fitted rig.
		# The source tunic geometry was not located; these stay labelled project clothes.
		var fit := PlayerOutfit.dress(source_body, _look.outfit, float(_look.get("sex", 1.0)))
		BodyMaterials.apply_look(source_body, PlayerAppearance.dressed_look(_look, fit), fit.parts as Array)
		_set_meshes(source_body, selected_model == 2)
	# dress() knows the current garments, not the experimental hands.
	for mesh: MeshInstance3D in current_body.part_meshes("fitted_hands"):
		mesh.visible = selected_model == 1
	if selected_model == 2:
		_set_meshes(current_body, false)
	_sync_choices()


static func _set_meshes(body: CharacterBodyMesh, shown: bool) -> void:
	for mesh: MeshInstance3D in body.meshes:
		if is_instance_valid(mesh):
			mesh.visible = shown


func select_weapon(id: String) -> void:
	if not id in WEAPONS:
		return
	selected_weapon = id
	_weapon_epoch += 1
	var epoch := _weapon_epoch
	caster.ready_spell("")
	player.gather.put_away()
	# Respect the native stow blend before drawing a different weapon.
	while player.gather.phase != GatherTools.Phase.IDLE or player.is_switching() \
			or (player.weapon != null and player.weapon.is_equipping()):
		await get_tree().physics_frame
		if epoch != _weapon_epoch or not is_inside_tree():
			return
	if id == "sword" or id == "spells":
		if not player.hands_free and player.weapon and player.weapon.active:
			player.toggle_hands_free()
		if id == "sword":
			player.gather.take_out("saber")
		else:
			var moves := Bending.bar(Bending.ELEMENTS[selected_element])
			if _wanted_spell != "":
				caster.ready_spell(_wanted_spell)
			elif not moves.is_empty():
				caster.ready_spell(String(moves[0]))
	else:
		if player.weapons.get(id) is Throwable:
			var thrown := player.weapons[id] as Throwable
			thrown.count = maxi(thrown.count, 12)
		player.switch_weapon(id)
	_sync_choices()


func select_element(index: int) -> void:
	selected_element = clampi(index, 0, Bending.ELEMENTS.size() - 1)
	Bending.of(player).element = Bending.ELEMENTS[selected_element]
	_spell_ids.clear()
	for key: Array in Bending.keys(Bending.ELEMENTS[selected_element]):
		for id: String in key:
			if not _spell_ids.has(id):
				_spell_ids.append(id)
	_wanted_spell = _spell_ids[0] if not _spell_ids.is_empty() else ""
	if _spell_choice:
		_spell_choice.clear()
		for id: String in _spell_ids:
			_spell_choice.add_item(caster.spell_label(id))
	if selected_weapon == "spells":
		select_weapon("spells")
	_sync_choices()


func select_spell(index: int) -> void:
	if index < 0 or index >= _spell_ids.size():
		return
	_wanted_spell = _spell_ids[index]
	select_weapon("spells")


func go_to(area: String) -> void:
	current_area = "arena" if area == "arena" else "map"
	# The lab's teleport starts a fresh fall measurement at the destination.
	player.set("_fall_top", -INF)
	player.global_position = world.spawn_at(current_area)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = -0.15
	player.rotation.y = 0.0
	_sync_choices()


func reset_position() -> void:
	caster._end_on("lab reset")
	player.respawn()
	BendStatus.clear_round(player)
	var rag := player.get_node_or_null("Ragdoll") as PlayerRagdoll
	if rag and rag.is_down():
		rag.recover_now()
	go_to(current_area)
	_reset_target()


func _reset_target() -> void:
	if training_target:
		training_target.respawn()
		BendStatus.clear_round(training_target)
		var target_rag := training_target.get_node_or_null("Ragdoll") as PlayerRagdoll
		if target_rag and target_rag.is_down():
			target_rag.recover_now()
		training_target.global_position = Vector3(80, 0.25, -6)
		training_target.velocity = Vector3.ZERO
		training_target.set("_fall_top", -INF)


func _build_partners() -> void:
	for offset: Vector3 in [Vector3(-3, 0, -4), Vector3(3, 0, -4)]:
		var partner := SparringPartner.new()
		partner.name = "TrainingPartner" + str(partners.size())
		partner.position = Vector3(80, 0, 0) + offset
		add_child(partner)
		var body := partner.sk.get_node("Body") as CharacterBodyMesh
		var lk := AppearanceStore.validate(CharacterPeoples.preset_look("vietnamese_m_a"))
		lk.outfit = PlayerAppearance.arena_outfit("fire", 1.0)
		PlayerAppearance.dress(body, lk)
		partners.append(partner)
		var label := Label3D.new()
		label.text = "Sparring · strike to test contact"
		label.position = Vector3(0, 2.2, 0)
		label.font_size = 28
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		partner.add_child(label)
	# Use a supported combat receiver so spell bolts actually hit and knock it.
	training_target = FrontierPlayer.new()
	training_target.name = "SpellTrainingTarget"
	training_target.is_local = false
	training_target.arena = true
	training_target.use_appearance = false
	training_target.controls = PlayerControls.new(false)
	training_target.character_scene = player.character_scene
	training_target.no_death = true
	training_target.max_health = 1000.0
	training_target.position = Vector3(80, 0.25, -6)
	training_target.rotation.y = PI
	add_child(training_target)
	var body := training_target.skeleton.get_node("Body") as CharacterBodyMesh
	var look := AppearanceStore.validate(CharacterPeoples.preset_look("vietnamese_m_a"))
	look.outfit = PlayerAppearance.arena_outfit("water", 1.0)
	PlayerAppearance.dress(body, look)
	training_target.hurt.connect(func(_direction: Vector2, _amount: float, _heavy: bool) -> void: target_hits += 1)
	var label := Label3D.new()
	label.text = "Spell target · hit / knockback"
	label.position = Vector3(0, 2.2, 0)
	label.font_size = 28
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	training_target.add_child(label)


func _reference_stands() -> void:
	for spec: Array in [["npc_gerudo_clothing_reference.glb", Vector3(86, 0, 6), "Source clothing reference"],
			["arrow_reference.glb", Vector3(89, 1, 6), "Source arrow reference"]]:
		var packed := _load_glb(SOURCE_PIECES + String(spec[0]))
		if packed == null:
			continue
		var stand := packed.instantiate() as Node3D
		stand.name = "ReferenceStand" + String(spec[0]).get_basename()
		stand.position = spec[1]
		add_child(stand)
		reports[stand.name] = ToonMaterials.apply_node(stand)
		var label := Label3D.new()
		label.text = spec[2]
		label.position = (spec[1] as Vector3) + Vector3(0, 2.9, 0)
		label.font_size = 24
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LabControls"
	layer.layer = 30
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 18)
	_panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "TIDEBREAK · ASSET PLAYGROUND"
	title.add_theme_font_size_override("font_size", 21)
	box.add_child(title)
	_status = Label.new()
	box.add_child(_status)
	_model_choice = _choice(box, "Body / hands", MODELS, select_model)
	_outfit_choice = _choice(box, "Outfit / clothing fit", OUTFITS, select_outfit)
	_weapon_choice = _choice(box, "Weapon / casting", ["Sword", "Spear", "Bow", "Tomahawk", "Spells"], func(i: int) -> void: select_weapon(WEAPONS[i]))
	_element_choice = _choice(box, "Element", ["Earth", "Water", "Fire", "Air"], select_element)
	_spell_choice = _choice(box, "Spell", [], select_spell)
	var row := HBoxContainer.new()
	box.add_child(row)
	for area: String in ["map", "arena"]:
		var button := Button.new()
		button.text = "Terrain map" if area == "map" else "Test arena"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(go_to.bind(area))
		row.add_child(button)
	var reset := Button.new()
	reset.text = "Reset / recover"
	reset.pressed.connect(reset_position)
	box.add_child(reset)
	_help = Label.new()
	_help.add_theme_font_size_override("font_size", 15)
	box.add_child(_help)
	var note := Label.new()
	note.text = "Extracted terrain, body/hands and reference pieces.\nClothing fits and weapons use project assets.\nSource tunic geometry has not been located."
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(0.76, 0.82, 0.83)
	box.add_child(note)
	_message = Label.new()
	_message.position = Vector2(20, 700)
	_message.add_theme_font_size_override("font_size", 17)
	_message.add_theme_color_override("font_shadow_color", Color.BLACK)
	_message.add_theme_constant_override("shadow_offset_x", 1)
	_message.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_message)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(6, 15)
	layer.add_child(crosshair)
	caster.ring = SwayRing.new()
	caster.ring.caster = caster
	layer.add_child(caster.ring)
	_sync_choices()


func _choice(parent: VBoxContainer, title: String, choices: Array, callback: Callable) -> OptionButton:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var control := OptionButton.new()
	for text: String in choices:
		control.add_item(text)
	control.item_selected.connect(callback)
	parent.add_child(control)
	return control


func _sync_choices() -> void:
	if _panel == null:
		return
	_model_choice.select(selected_model)
	_outfit_choice.select(selected_outfit)
	_outfit_choice.disabled = false
	_weapon_choice.select(WEAPONS.find(selected_weapon))
	_element_choice.select(selected_element)
	if _spell_choice and not _spell_ids.is_empty():
		_spell_choice.select(maxi(0, _spell_ids.find(_wanted_spell)))
	_status.text = ("Terrain map" if current_area == "map" else "Test arena") + "  ·  " + MODELS[selected_model]
	var use := "Hold / release LMB · quick spell\nHold / release RMB · selected spell"
	if selected_weapon == "sword":
		use = "LMB · sword attack   RMB · defend"
	elif selected_weapon != "spells":
		use = "Hold LMB · aim / charge, release · " + ("shoot" if selected_weapon == "bow" else "throw") + "\nRMB · cancel"
	_help.text = "WASD · move   Space · jump   Shift · sprint\n1 sword   2 spear   3 bow   4 tomahawk   5 spells\n" + use + "\nF1 · controls   Esc · free cursor\nClick outside the panel to resume play."


func _input(event: InputEvent) -> void:
	if _panel == null:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_F1 or key.physical_keycode == KEY_ESCAPE:
			_panel.visible = not _panel.visible if key.physical_keycode == KEY_F1 else true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panel.visible else Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_5:
			select_weapon(WEAPONS[key.physical_keycode - KEY_1])
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if player == null:
		return
	_timer += delta
	if _timer < 0.25:
		return
	_timer = 0.0
	if player.position.y < -12 or absf(player.position.z) > 40 or player.position.x < -40 or player.position.x > 96:
		reset_position()
	if training_target and (training_target.position.y < -6 or absf(training_target.position.z) > 11 \
			or absf(training_target.position.x - 80.0) > 11):
		_reset_target()
	if _message:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_panel.hide()
		var strikes := target_hits
		for partner: SparringPartner in partners:
			strikes += partner.struck
		_message.position.y = get_viewport().get_visible_rect().size.y - 36
		var casting := ""
		if selected_weapon == "spells":
			casting = " · " + Bending.ELEMENTS[selected_element].capitalize() + " / " + caster.spell_label(caster.readied_spell)
			if caster.state != SwayCaster.State.IDLE:
				casting += " · " + str(roundi(caster.fill * 100.0)) + "%"
		_message.text = "F1 / Esc: controls   ·   " + selected_weapon.capitalize() + casting + "   ·   Target hits: " + str(strikes)
