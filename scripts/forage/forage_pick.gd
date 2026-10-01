class_name ForagePick
extends Node
## Picking a plant (ForageField's E): the player turns to it and works at it with an bundled Actor_B clip for the
## plant's height (forage.json clips: "low" pick-flower for the rosettes and sprigs, "ground" search-low for acorns and
## digging a root, "waist" search at a metre for the brambles, "high" search-high for the hazel), while a bar fills
## over the plant's pick_s; then a handful goes into the pack (ForageField.take) and the player gets up. Moving,
## jumping, crouching, aiming, firing, drawing a weapon or E again stops it (nothing taken); a hit stops it at once.
## The same pattern as FieldDressing (FrontierPlayer.begin_kneel / end_kneel, a HorsePhaseBlender on the player's
## AnimationPlayer).

signal picked(kind: String, item: String)

const LIB := "actor_b"
## The exit clip is played this far (s); PlayerAnim takes the rest.
const OUT_S := 1.2
const CANCEL_ACTIONS := ["jump", "crouch", "aim", "fire", "reload", "sprint", "interact"]

var field: ForageField
var player: FrontierPlayer
var working := false
var patch := -1
var plant := -1
var kind := ""
var progress := 0.0

var _clips: Array = []
var _blender: HorsePhaseBlender
var _ap: AnimationPlayer
var _phase := 0            ## 0 bending to it, 1 working, 2 getting up
var _t := 0.0
var _dur := 3.0
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar
var _hurt_hooked := false


func _ready() -> void:
	_build_ui()


## Starts picking plant `li` of patch `pi` at `point`; false when the player cannot now.
func start(p: FrontierPlayer, pi: int, li: int, point: Vector3) -> bool:
	if working or p == null or field == null:
		return false
	var pa: Dictionary = field.patches[pi]
	var d: Dictionary = field.data.plants[pa.kind]
	_ap = p.begin_kneel(self, point)
	if _ap == null:
		return false
	player = p
	if not _hurt_hooked:
		p.hurt.connect(_on_hurt)
		_hurt_hooked = true
	working = true
	patch = pi
	plant = li
	kind = String(pa.kind)
	progress = 0.0
	_dur = float(d.get("pick_s", 3.0))
	_clips = (field.data.get("clips", {}) as Dictionary).get(String(d.get("clip", "low")), [])
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, p, LIB)
	_blender.show_clip(_clips[0], 0.0, 0.0)
	_blender.update(0.0)
	_label.text = String(d.get("take", "Pick"))
	_bar.value = 0.0
	_layer.visible = true
	return true


func _physics_process(dt: float) -> void:
	if not working:
		return
	if player.is_dead or player.kneeling != self:
		_stop()
		return
	# E pressed to start is still down on the first ticks: only a fresh press stops it
	if _phase < 2 and (_t > 0.1 or _phase > 0) and _cancel_pressed():
		_get_up()
	_t += dt
	match _phase:
		0:
			_blender.show_clip(_clips[0], minf(_t, _len(_clips[0])), 0.15)
			if _t >= _len(_clips[0]):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(_clips[1], fposmod(_t, _len(_clips[1])), 0.3)
			progress = minf(progress + dt / _dur, 1.0)
			_bar.value = progress
			if progress >= 1.0:
				_give()
				_get_up()
		2:
			_blender.show_clip(_clips[2], minf(_t, _len(_clips[2])), 0.2)
			if _t >= minf(OUT_S, _len(_clips[2])):
				_stop()
				return
	_blender.update(dt)


## A handful (or the root) into the pack, a note on screen.
func _give() -> void:
	var got := field.take(patch, plant)
	var item := String(field.data.plants[kind].get("item", kind))
	if got < 0.5:
		field._notice("Nothing left to take here")
		return
	var inv := InventoryState.from_player(player)
	inv.add(item, 1)
	player.inventory_pack = inv.pack.duplicate(true)
	field._notice("+1 %s  (%d in the pack)" % [InventoryState.name_of(item), inv.pack_count(item)])
	picked.emit(kind, item)


func _cancel_pressed() -> bool:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3:
		return true
	for a: String in CANCEL_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return not player.hands_free        # a weapon key drew a weapon


func _get_up() -> void:
	if _phase == 2:
		return
	_phase = 2
	_t = 0.0
	_layer.visible = false


func _on_hurt(_dir: Vector2, _amount: float, _heavy: bool) -> void:
	if working:
		_stop()         # up at once: something is attacking


func _stop() -> void:
	working = false
	_layer.visible = false
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	if player and player.kneeling == self:
		player.end_kneel()
	patch = -1
	plant = -1


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.78
	box.anchor_bottom = 0.78
	box.offset_left = -150.0
	box.offset_right = 150.0
	_layer.add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 5)
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(300, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.5, 0.66, 0.34)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
