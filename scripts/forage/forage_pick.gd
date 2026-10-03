class_name ForagePick
extends Node
## Picking a plant (ForageField's E), on the move (user 2026-10-02: "i just want it to be arms, where they press the button and
## there arm reaches out and gets something", "instead of a timer we should have it like a progress bar like felling where they
## can grab keep some, it keeps the idea of being mobile like i got shot i can quickly grab something put in pack"):
## each E is one grab: an arm reaches out, closes on a handful and brings it back to the pack (our own clip, keyed in Blender:
## tools/anim_author/blender/forage_grab.py, installed by tools/anim_author/install_forage.gd), over whatever the body is doing
## (walking, running, standing: the legs are the game's; ToolPose "reach_r", or "reach_l" when the right hand is on a gun:
## the torso leans and bends toward the reaching arm, the other arm left to the game).
## Nothing stops the player. Every grab yields (user: "each grab yield material"): a handful into the pack (ForageField.take)
## as the fingers close; the bar under the prompt is the patch picked (ForageField.picked_share), filling with each grab
## as a felling stroke's does, and the prompt says how many handfuls are left ("Pick blackberries  (5 left)").

signal picked(kind: String, item: String)

const CLIPS := "res://animations_extra/Frontier_Forage.res"
const BLEND_IN_S := 0.12             ## the arm eased onto the clip from what it was doing, and back off it
const BLEND_OUT_S := 0.18
const SHOW_S := 2.5                  ## the bar stays this long after a grab

## The player now grabbing (HowTo's "forage"), or null.
static var grabbing: Node = null

var field: ForageField
var player: FrontierPlayer
var working := false
var patch := -1
var plant := -1
var kind := ""
var progress := 0.0                  ## the bar: the patch picked (0..1)

var _lib: AnimationLibrary
var _pose: ToolPose
var _anim: Animation
var _mask := "reach_r"
var _t := 0.0
var _counted := false
var _show_t := 0.0
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar


func _ready() -> void:
	_build_ui()


## One grab at plant `li` of patch `pi` (at `point`); false when the player cannot now (a grab still going, riding, dead...).
func start(p: FrontierPlayer, pi: int, li: int, point: Vector3) -> bool:
	if working or p == null or field == null or p.is_dead or p.riding != null or p.climbing != null or p.kneeling != null:
		return false
	if _lib == null:
		_lib = load(CLIPS) as AnimationLibrary
	if _lib == null:
		return false
	player = p
	working = true
	grabbing = p
	patch = pi
	plant = li
	kind = String(field.patches[pi].kind)
	progress = field.picked_share(pi)
	# the right hand on a gun (the musket, the pistol): the left reaches
	var right_busy := p.weapon != null and p.weapon.active and not p.hands_free and p.weapon.hand == Weapon.Hand.RIGHT
	_mask = "reach_l" if right_busy else "reach_r"
	_anim = _lib.get_animation(&"own-forage-grab-l" if right_busy else &"own-forage-grab-r")
	_t = 0.0
	_counted = false
	if _pose == null or not is_instance_valid(_pose):
		_pose = ToolPose.new()
		_pose.name = "ForageGrab"
	if _pose.get_parent() != p.skeleton:
		if _pose.get_parent():
			_pose.get_parent().remove_child(_pose)
		p.skeleton.add_child(_pose)
	SwayPose.put_last(p.skeleton, _pose)        # over the tree and every other modifier, the body (its helpers) still last
	_pose.active = true
	_label.text = String(field.data.plants[kind].get("take", "Pick"))
	_bar.value = progress
	_show()
	return true


func _physics_process(dt: float) -> void:
	if _show_t > 0.0:
		_show_t -= dt
		if _show_t <= 0.0:
			_layer.visible = false
	if not working:
		return
	if not is_instance_valid(player) or player.is_dead or player.riding != null or player.climbing != null:
		_stop()
		return
	_t += dt
	var len := _anim.length
	var w := minf(clampf(_t / BLEND_IN_S, 0.0, 1.0), clampf((len - _t) / BLEND_OUT_S, 0.0, 1.0))
	_pose.layers = [{"anim": _anim, "time": minf(_t, len), "weight": w, "mask": _mask}]
	if not _counted and _t >= float(_anim.get_meta(&"grab_s", 0.33)):
		_counted = true
		_grab()
	if _t >= len:
		_stop()


## The fingers closed on it: a handful into the pack, the bar on.
func _grab() -> void:
	_give()
	progress = field.picked_share(patch)
	_bar.value = progress
	_show()


func _show() -> void:
	_layer.visible = true
	_show_t = SHOW_S


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


func _stop() -> void:
	working = false
	if grabbing == player:
		grabbing = null
	if _pose and is_instance_valid(_pose):
		_pose.layers = []
		_pose.active = false


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
