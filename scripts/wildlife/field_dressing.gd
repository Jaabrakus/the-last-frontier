class_name FieldDressing
extends Node
## Skinning and butchering with a knife (user 2026-09-26: "lets allow skinning with a knife or butcher the animal we
## collect"). E on a carcass (WildAnimal.interact) starts its next step when the player has the skinning knife (KNIFE:
## in the pack from the start, as the gathering tools are): SKIN takes the hide or pelt (and a buck's antler), then
## BUTCHER takes the meat (deer; wolves and foxes are only skinned). The player kneels over the carcass
## (FrontierPlayer.begin_kneel; the clips actor_b-cap-ambi-search-low-in-place-entry / -in-place / -exit through a
## HorsePhaseBlender on the player's AnimationPlayer) while a bar fills. Moving, jumping, crouching, aiming, firing,
## drawing a weapon or E again stops the work (the player gets up); a hit stops it at once. The carcass keeps its
## progress (WildAnimal.dress_progress), so the work goes on where it stopped.
##
##   var fd := FieldDressing.new(); fd.player = player; fd.spawner = spawner; spawner.add_child(fd)

signal finished(animal: WildAnimal, step: String)

const KNIFE := "skinning_knife"
## A knapped flint knife does the same work (the start with nothing).
const FLINT_KNIFE := "flint_knife"
const LIB := "actor_b"
const CLIP_IN := "actor_b-cap-ambi-search-low-in-place-entry"
const CLIP_LOOP := "actor_b-cap-ambi-search-low-in-place"
const CLIP_OUT := "actor_b-cap-ambi-search-low-in-place-exit"
## The exit clip is played this far (s); PlayerAnim takes the rest (the traversal inertializer smooths the hand-back).
const OUT_S := 1.5
const CANCEL_ACTIONS := ["jump", "crouch", "aim", "fire", "reload", "sprint"]

var player: FrontierPlayer
var spawner: WildlifeSpawner
var carcass: WildAnimal
var step := ""
var working := false
var _blender: HorsePhaseBlender
var _ap: AnimationPlayer
var _phase := 0            ## 0 kneeling down, 1 working, 2 getting up
var _t := 0.0
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar


func _ready() -> void:
	_build_ui()
	if player:
		player.hurt.connect(_on_hurt)
	_ensure_knife.call_deferred()


## The player's skinning knife: in the pack (or worn).
func has_knife() -> bool:
	if player == null:
		return false
	if player.loadout and player.loadout.has_kind(KNIFE):
		return true
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) in [KNIFE, FLINT_KNIFE] and int(e.get("count", 0)) > 0:
			return true
	return false


## Every frontiersman carries a knife: the player owns one from the start.
func _ensure_knife() -> void:
	if player == null or has_knife() or (is_inside_tree() and SurvivalBridge.bare_of(get_tree())):
		return
	var inv := InventoryState.from_player(player)
	inv.add(KNIFE, 1)
	player.inventory_pack = inv.pack.duplicate(true)


## Begins (or, on the carcass being worked, stops) a step. False when it cannot start (no knife: a note says so).
func toggle(a: WildAnimal, s: String) -> bool:
	if working:
		if a == carcass:
			_get_up()
		return false
	if player == null or a == null:
		return false
	if not has_knife():
		if spawner:
			spawner.note("You need a knife to %s the %s" % [s, String(a.data.name)])
		return false
	_ap = player.begin_kneel(self, a.global_position)
	if _ap == null:
		return false
	carcass = a
	step = s
	working = true
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, player, LIB)
	_blender.show_clip(CLIP_IN, 0.0, 0.0)
	_blender.update(0.0)
	_label.text = "%s the %s" % [s.capitalize(), String(a.data.name)]
	_bar.value = a.dress_progress
	_layer.visible = true
	return true


func _physics_process(dt: float) -> void:
	if not working:
		return
	if not is_instance_valid(carcass) or player.is_dead or player.kneeling != self:
		_stop()
		return
	if _phase < 2 and _cancel_pressed():
		_get_up()
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIP_IN, minf(_t, _len(CLIP_IN)), 0.15)
			if _t >= _len(CLIP_IN):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIP_LOOP, fposmod(_t, _len(CLIP_LOOP)), 0.3)
			var dur := float(carcass.data.get(step + "_s", 6.0))
			carcass.dress_progress = minf(carcass.dress_progress + dt / dur, 1.0)
			_bar.value = carcass.dress_progress
			if carcass.dress_progress >= 1.0:
				var a := carcass
				var s := step
				a.finish_dress(s, player)
				finished.emit(a, s)
				_get_up()
		2:
			_blender.show_clip(CLIP_OUT, minf(_t, _len(CLIP_OUT)), 0.2)
			if _t >= minf(OUT_S, _len(CLIP_OUT)):
				_stop()
				return
	_blender.update(dt)


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
	carcass = null
	step = ""


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
	fill.bg_color = Color(0.78, 0.62, 0.38)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
