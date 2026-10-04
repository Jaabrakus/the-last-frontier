class_name CustomizerOverlay
extends CanvasLayer
## The detailed customizer: face, skin, eyes, brows and hair of the player on sliders, with a
## live 3D preview. O opens the character creator (CharacterCreator); its Fine-tune opens this
## on the creator's look (edit(): Apply returns the look to the creator). Opened on its own
## (open()), Apply puts the look on the player and saves it (AppearanceStore). The game is
## paused while it is open; Cancel or Esc closes without changes.
##
## Tabs:
##   People  group and people (with a short note), the people's presets for the chosen body
##           fit, "New individual" (a random person of that people: the people's mean face
##           plus its within-group spread, skin, eyes and hair from its ranges) and "Mix with"
##           a second people by an amount (families of mixed descent).
##   Face    one slider per face feature (the body's face_* shapes), grouped: face shape, jaw
##           and chin, eyes, nose, mouth, ears.
##   Skin    Tone 1-12 swatches and a fine melanin slider, undertone, blood (haemoglobin),
##           freckles, weathering, stubble.
##   Eyes    iris colours, brow thickness and arch.
##   Hair    every hair style, colour presets, grey.
##   Outfit  garments over the frontier clothes (OutfitTab, PlayerOutfit): capots, the fur coat,
##           a fur robe, fur cap, fur mittens, winter moccasins, a sash; fur and cloth colours.
## Labels never name a skin tone after a people (costume bible 1.2).
##
## The preview is a plain Actor_B in its own world (the same CharacterBodyMesh and
## PlayerAppearance.dress() path as the game), idling, with a studio or a frontier light.

const IDLE := &"actor_b/actor_b-p-stealth-idle"

var app: PlayerAppearance
var look := {}
var _body: CharacterBodyMesh
var _pivot: Node3D
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _sliders := {}
var _rng := RandomNumberGenerator.new()
var _people_list: ItemList
var _group_opt: OptionButton
var _note: Label
var _presets_box: HFlowContainer
var _mix_opt: OptionButton
var _mix_slider: HSlider
var _sex_opt: OptionButton
var _hair_list: ItemList
var _outfit_tab: OutfitTab
var _undertone_opt: OptionButton
var _drag := false
var _yaw := 0.0
var _zoom_face := true
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _suspend := false


## Called with the edited look (or {} on Cancel) instead of applying it to the player: the
## character creator's Fine-tune (CharacterCreator), which keeps the game paused.
var on_done: Callable


static func open(appearance: PlayerAppearance) -> CustomizerOverlay:
	var o := CustomizerOverlay.new()
	o.app = appearance
	o.look = appearance.look.duplicate(true)
	appearance.get_tree().root.add_child(o)
	return o


## Opens the sliders on `lk` for the creator; `done` gets the result.
static func edit(lk: Dictionary, done: Callable, tree: SceneTree) -> CustomizerOverlay:
	var o := CustomizerOverlay.new()
	o.look = lk.duplicate(true)
	o.on_done = done
	tree.root.add_child(o)
	return o


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_prev_mouse = Input.mouse_mode
	for a in InputMap.get_actions():
		Input.action_release(a)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_refresh_all()


func close(apply_look: bool) -> void:
	if on_done.is_valid():
		# the creator's fine-tune: the creator keeps the tree paused and applies the look (its
		# rows show "Custom" where a slider moved a value off their choices)
		on_done.call(look if apply_look else {})
		queue_free()
		return
	if apply_look and is_instance_valid(app):
		app.apply(look)
		AppearanceStore.save_current(app.look)
	get_tree().paused = false
	for a in InputMap.get_actions():
		Input.action_release(a)
	if not "--no-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = _prev_mouse
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close(false)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.06, 1.0)      # opaque: the HUD text showed through the title
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	root.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(460, 0)
	hb.add_child(left)
	var title := Label.new()
	title.text = "Character"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)
	var row := HBoxContainer.new()
	left.add_child(row)
	row.add_child(_label("Body fit"))
	_sex_opt = OptionButton.new()
	_sex_opt.add_item("Woman", 0)
	_sex_opt.add_item("Man", 1)
	_sex_opt.item_selected.connect(func(i: int) -> void:
		look.sex = float(i)
		_refresh_presets()
		_update_preview())
	row.add_child(_sex_opt)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tabs)
	tabs.add_child(_people_tab())
	tabs.add_child(_face_tab())
	tabs.add_child(_skin_tab())
	tabs.add_child(_eyes_tab())
	tabs.add_child(_hair_tab())
	# what is worn (PlayerOutfit: the basic dress unless chosen)
	if PlayerOutfit.enabled():
		_outfit_tab = OutfitTab.create(func() -> Dictionary: return look, func() -> void: _update_preview())
		tabs.add_child(_outfit_tab)
		tabs.tab_changed.connect(func(i: int) -> void:
			if tabs.get_tab_control(i) == _outfit_tab:
				_zoom_face = false
				_place_camera())
	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	var apply_b := Button.new()
	apply_b.text = "Apply"
	apply_b.pressed.connect(func() -> void: close(true))
	buttons.add_child(apply_b)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: close(false))
	buttons.add_child(cancel)
	var reset := Button.new()
	reset.text = "Default"
	reset.pressed.connect(func() -> void:
		look = AppearanceStore.default_look()
		_refresh_all())
	buttons.add_child(reset)
	# preview
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.gui_input.connect(_on_preview_input)
	right.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	svc.add_child(sv)
	_build_stage(sv)
	var vrow := HBoxContainer.new()
	right.add_child(vrow)
	for v in [["Face", true], ["Full", false]]:
		var b := Button.new()
		b.text = v[0]
		b.pressed.connect(func() -> void:
			_zoom_face = v[1]
			_place_camera())
		vrow.add_child(b)
	var light := OptionButton.new()
	light.add_item("Studio light", 0)
	light.add_item("Frontier light", 1)
	light.item_selected.connect(_set_light)
	vrow.add_child(light)
	var hint := Label.new()
	hint.text = "  Drag to turn. Esc closes."
	vrow.add_child(hint)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _slider(key: String, label: String, lo: float, hi: float, parent: Container, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(label)
	l.custom_minimum_size = Vector2(210, 0)
	l.clip_text = true
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.tooltip_text = label
	s.value_changed.connect(func(v: float) -> void:
		if not _suspend:
			cb.call(v)
			_update_preview())
	row.add_child(s)
	_sliders[key] = s
	return s


func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return [sc, vb]


func _people_tab() -> Control:
	var t := _scroll("People")
	var vb: VBoxContainer = t[1]
	_group_opt = OptionButton.new()
	for g in CharacterPeoples.listed_groups():
		_group_opt.add_item(String(g))
	_group_opt.item_selected.connect(func(_i: int) -> void: _refresh_people_list())
	vb.add_child(_group_opt)
	_people_list = ItemList.new()
	_people_list.custom_minimum_size = Vector2(0, 150)
	_people_list.item_selected.connect(func(i: int) -> void:
		look.people = String(_people_list.get_item_metadata(i))
		_refresh_note()
		_refresh_presets())
	vb.add_child(_people_list)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(420, 0)
	vb.add_child(_note)
	vb.add_child(_label("Presets"))
	_presets_box = HFlowContainer.new()
	vb.add_child(_presets_box)
	var nb := Button.new()
	nb.text = "New individual"
	nb.tooltip_text = "A random person of this people (and of the mixed-in people, if any)."
	nb.pressed.connect(_new_individual)
	vb.add_child(nb)
	var mrow := HBoxContainer.new()
	vb.add_child(mrow)
	mrow.add_child(_label("Mix with"))
	_mix_opt = OptionButton.new()
	_mix_opt.add_item("(none)")
	_mix_opt.set_item_metadata(0, "")
	var i := 1
	for p: Dictionary in CharacterPeoples.peoples():
		_mix_opt.add_item(String(p.label))
		_mix_opt.set_item_metadata(i, String(p.id))
		i += 1
	mrow.add_child(_mix_opt)
	_mix_slider = HSlider.new()
	_mix_slider.min_value = 0.0
	_mix_slider.max_value = 1.0
	_mix_slider.step = 0.05
	_mix_slider.value = 0.5
	_mix_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mix_slider.tooltip_text = "Share of the second people"
	mrow.add_child(_mix_slider)
	return t[0]


func _face_tab() -> Control:
	var t := _scroll("Face")
	var vb: VBoxContainer = t[1]
	var group := ""
	for f: Dictionary in CharacterPeoples.features():
		if f.group != group:
			group = f.group
			var h := _label(group)
			h.add_theme_font_size_override("font_size", 15)
			vb.add_child(h)
		var key := String(f.key)
		_slider(key, String(f.label), -1.0, 1.0, vb, func(v: float) -> void:
			if not look.get("face") is Dictionary:
				look.face = BodyMaterials.face_weights(look)
			look.face[key] = v)
	return t[0]


func _skin_tab() -> Control:
	var t := _scroll("Skin")
	var vb: VBoxContainer = t[1]
	vb.add_child(_label("Tone"))
	var grid := GridContainer.new()
	grid.columns = 6
	vb.add_child(grid)
	for i in 12:
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 34)
		b.text = str(i + 1)
		b.tooltip_text = "Tone %d" % (i + 1)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BodyMaterials.tone_color(i / 11.0)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color(0, 0, 0, 0.6) if i < 6 else Color(1, 1, 1, 0.7))
		b.pressed.connect(func() -> void:
			look.melanin = i / 11.0
			_refresh_sliders()
			_update_preview())
		grid.add_child(b)
	_slider("melanin", "Tone (fine)", 0.0, 1.0, vb, func(v: float) -> void: look.melanin = v)
	var row := HBoxContainer.new()
	vb.add_child(row)
	row.add_child(_label("Undertone"))
	_undertone_opt = OptionButton.new()
	for u in ["cool", "neutral", "warm", "olive"]:
		_undertone_opt.add_item(u.capitalize())
	_undertone_opt.item_selected.connect(func(i: int) -> void:
		look.undertone = ["cool", "neutral", "warm", "olive"][i]
		_update_preview())
	row.add_child(_undertone_opt)
	_slider("haemoglobin", "Colour in the cheeks (blood)", 0.0, 1.0, vb, func(v: float) -> void: look.haemoglobin = v)
	_slider("freckles", "Freckles", 0.0, 1.0, vb, func(v: float) -> void: look.freckles = v)
	_slider("weathering", "Weathering (sun, wind)", 0.0, 1.0, vb, func(v: float) -> void: look.weathering = v)
	_slider("stubble", "Stubble", 0.0, 1.0, vb, func(v: float) -> void: look.stubble = v)
	vb.add_child(_label("Body"))
	_slider("bust", "Bust (body type 2)", -1.0, 1.0, vb, func(v: float) -> void: look.bust = v)
	_slider("genital", "Genital size (body type 1)", -1.0, 1.0, vb, func(v: float) -> void: look.genital = v)
	return t[0]


func _eyes_tab() -> Control:
	var t := _scroll("Eyes")
	var vb: VBoxContainer = t[1]
	vb.add_child(_label("Eye colour"))
	var grid := GridContainer.new()
	grid.columns = 5
	vb.add_child(grid)
	var eyes: Dictionary = BodyMaterials.body_info().get("eyes", {})
	for k: String in eyes:
		var b := Button.new()
		b.custom_minimum_size = Vector2(80, 30)
		b.text = k.replace("_", " ")
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(String(eyes[k]))
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		b.pressed.connect(func() -> void:
			look.iris = k
			_update_preview())
		grid.add_child(b)
	_slider("brow_thickness", "Brow thickness", 0.2, 1.3, vb, func(v: float) -> void: _brows()["thickness"] = v)
	_slider("brow_arch", "Brow arch", 0.0, 1.0, vb, func(v: float) -> void: _brows()["arch"] = v)
	_slider("brow_density", "Brow density", 0.3, 1.0, vb, func(v: float) -> void: _brows()["density"] = v)
	return t[0]


func _brows() -> Dictionary:
	if not look.get("brows") is Dictionary:
		look.brows = {}
	return look.brows


func _hair_tab() -> Control:
	var t := _scroll("Hair")
	var vb: VBoxContainer = t[1]
	_hair_list = ItemList.new()
	_hair_list.custom_minimum_size = Vector2(0, 220)
	for f in DirAccess.get_files_at(BodyMaterials.HAIR_DIR):
		if f.ends_with(".glb"):
			var id := f.get_basename()
			var info := BodyMaterials.hair_info(id)
			_hair_list.add_item(String(info.get("name", id)))
			_hair_list.set_item_metadata(_hair_list.item_count - 1, id)
			_hair_list.set_item_tooltip(_hair_list.item_count - 1, String(info.get("description", "")))
	_hair_list.item_selected.connect(func(i: int) -> void:
		var h := _hair()
		h["style"] = String(_hair_list.get_item_metadata(i))
		_update_preview())
	vb.add_child(_hair_list)
	vb.add_child(_label("Colour"))
	var grid := GridContainer.new()
	grid.columns = 4
	vb.add_child(grid)
	for p: Dictionary in BodyMaterials.load_json(BodyMaterials.HAIR_COLORS).get("presets", []):
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 28)
		b.text = String(p.label)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BodyMaterials.hair_color(float(p.eumelanin), float(p.pheomelanin), float(p.grey))
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.85) if float(p.eumelanin) > 2.0 else Color(0, 0, 0, 0.7))
		var pid := String(p.id)
		b.pressed.connect(func() -> void:
			var h := _hair()
			for k in ["eumelanin", "pheomelanin", "grey"]:
				h.erase(k)
			h["color"] = pid
			_update_preview())
		grid.add_child(b)
	return t[0]


func _hair() -> Dictionary:
	if not look.get("hair") is Dictionary:
		look.hair = {}
	return look.hair


# ---------------------------------------------------------------------------
# State -> UI
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_sex_opt.select(1 if float(look.get("sex", 0.0)) >= 0.5 else 0)
	var pid := String(look.get("people", ""))
	var pp := CharacterPeoples.people(pid)
	if not pp.is_empty():
		var gi := CharacterPeoples.listed_groups().find(pp.group)
		if gi >= 0:
			_group_opt.select(gi)
	_refresh_people_list()
	_refresh_note()
	_refresh_presets()
	_refresh_sliders()
	if _outfit_tab:
		_outfit_tab.refresh()
	_update_preview()


func _refresh_people_list() -> void:
	_people_list.clear()
	var g := _group_opt.get_item_text(_group_opt.selected) if _group_opt.selected >= 0 else ""
	for p: Dictionary in CharacterPeoples.listed_peoples(g):
		_people_list.add_item(String(p.label))
		_people_list.set_item_metadata(_people_list.item_count - 1, String(p.id))
		if p.id == look.get("people", ""):
			_people_list.select(_people_list.item_count - 1)


func _refresh_note() -> void:
	var p := CharacterPeoples.people(String(look.get("people", "")))
	_note.text = String(p.get("note", "Choose a people, then a preset or a new individual.")) \
			+ ("\nArtistic licence: %s" % p.licence_note if p.get("licence_note") is String else "")


func _refresh_presets() -> void:
	for c in _presets_box.get_children():
		c.queue_free()
	var sex := 1.0 if float(look.get("sex", 0.0)) >= 0.5 else 0.0
	var people_id := String(look.get("people", ""))
	var world := CharacterPeoples.is_world(people_id)
	var n := 0
	for pr: Dictionary in CharacterPeoples.presets(people_id, sex):
		n += 1
		var b := Button.new()
		b.text = String(pr.label) if not world else "Face %d" % n
		var pid := String(pr.id)
		b.pressed.connect(func() -> void:
			var lk := CharacterPeoples.preset_look(pid)
			lk["people"] = people_id          # (a world people's faces are real peoples' presets: still its look)
			look = _keep_outfit(lk)
			_refresh_sliders()
			_update_preview())
		_presets_box.add_child(b)


func _refresh_sliders() -> void:
	_suspend = true
	var fw := BodyMaterials.face_weights(look)
	for k in fw:
		if _sliders.has(k):
			_sliders[k].value = fw[k]
	for k in ["melanin", "haemoglobin", "freckles", "weathering", "stubble", "bust", "genital"]:
		_sliders[k].value = float(look.get(k, 0.5 if k == "haemoglobin" else 0.0))
	var b: Dictionary = look.get("brows", {}) if look.get("brows") is Dictionary else {}
	_sliders.brow_thickness.value = float(b.get("thickness", 0.7))
	_sliders.brow_arch.value = float(b.get("arch", 0.5))
	_sliders.brow_density.value = float(b.get("density", 0.8))
	var u := ["cool", "neutral", "warm", "olive"].find(String(look.get("undertone", "neutral")))
	_undertone_opt.select(maxi(u, 0))
	var style := String(_hair().get("style", ""))
	for i in _hair_list.item_count:
		if _hair_list.get_item_metadata(i) == style:
			_hair_list.select(i)
			# select() does not scroll: show the current style when the Hair tab is drawn
			_hair_list.ensure_current_is_visible()
	_suspend = false


## A new face (people preset, new individual) keeps the clothes chosen on the Outfit tab, and the name, the tattoos and
## the jewellery (the creator's rows keep them across a change of people too: CreatorOptions.KEEP).
func _keep_outfit(lk: Dictionary) -> Dictionary:
	if look.get("outfit") is Dictionary:
		lk["outfit"] = (look.outfit as Dictionary).duplicate(true)
	for k: String in ["name", "tattoos"]:
		if look.has(k):
			lk[k] = look[k].duplicate(true) if look[k] is Array else look[k]
	if look.has(CreatorOptions.LEGACY_JEWELLERY) or CreatorOptions.JEWEL_ROWS.keys().any(func(r: String) -> bool: return look.has(r)):
		for r: String in CreatorOptions.JEWEL_ROWS:
			lk[r] = CreatorOptions.jewel_id(look, r)
		lk.erase(CreatorOptions.LEGACY_JEWELLERY)
	return lk


func _new_individual() -> void:
	var pid := String(look.get("people", ""))
	if pid.is_empty():
		pid = CharacterPeoples.default_people()
	var mix := String(_mix_opt.get_item_metadata(_mix_opt.selected))
	var sex := 1.0 if float(look.get("sex", 0.0)) >= 0.5 else 0.0
	var lk := CharacterPeoples.random_look(pid, sex, _rng, mix, _mix_slider.value)
	if not lk.is_empty():
		lk.weathering = look.get("weathering", 0.35)
		look = _keep_outfit(lk)
		_refresh_sliders()
		_update_preview()


# ---------------------------------------------------------------------------
# Preview stage
# ---------------------------------------------------------------------------
func _build_stage(sv: SubViewport) -> void:
	var world := Node3D.new()
	world.process_mode = Node.PROCESS_MODE_ALWAYS
	sv.add_child(world)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	world.add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-15, 120, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	_set_light(0)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	_pivot.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	_body = CharacterBodyMesh.attach(sk, ap)
	BindRest.ensure_character(inst)
	if ap and ap.has_animation(IDLE):
		ap.play(IDLE)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_place_camera()


func _set_light(i: int) -> void:
	if i == 0:
		_env.background_color = Color(0.30, 0.32, 0.34)
		_env.ambient_light_color = Color(0.55, 0.57, 0.60)
		_env.ambient_light_energy = 0.45
		_sun.rotation_degrees = Vector3(-28, 30, 0)
		_sun.light_color = Color(1.0, 0.98, 0.95)
		_sun.light_energy = 1.1
	else:
		# a low, warm sun and the dark slate of the game's grade
		_env.background_color = Color(0.20, 0.23, 0.25)
		_env.ambient_light_color = Color(0.36, 0.42, 0.48)
		_env.ambient_light_energy = 0.30
		_sun.rotation_degrees = Vector3(-14, -55, 0)
		_sun.light_color = Color(1.0, 0.80, 0.58)
		_sun.light_energy = 1.6


func _place_camera() -> void:
	if _cam == null:
		return
	var target := Vector3(0, 1.50, 0) if _zoom_face else Vector3(0, 0.95, 0)
	var dist := 1.05 if _zoom_face else 3.6
	_cam.position = target + Vector3(0, 0.02, dist)
	_cam.look_at(target)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_yaw += event.relative.x * 0.01
		_pivot.rotation.y = _yaw


func _update_preview() -> void:
	if _body:
		PlayerAppearance.dress(_body, look)
