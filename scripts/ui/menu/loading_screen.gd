class_name LoadingScreen
extends CanvasLayer
## The loading screen (user 2026-09-27: loading screens of oil paintings "instead of the godot"): a painting
## (MenuPaintings) over the whole window, drifting slowly nearer, its title and caption at the lower left over a soft
## shade, a thin gold line along the bottom for the progress. It loads the scene on a thread, changes to it, gives it
## a moment to settle (a save's parts are applied a few frames after the level is built: SaveGame), then fades out.
## Added to the root, so it outlives the scene change.
## On the way into Tidebreak's ring (scenes/ring.tscn, a match or a practice) a tip of the sport's under the caption: one rule
## or one answer in a line (data/ring/screens.json "tips", MatchSetup.screens; tip_for), drawn by lot.
## Alive while the level builds (improvement round 1, PERF: "a window that looks frozen while shaders compile"): the ring
## builds a part a frame behind it (RingLevel._build) and tells how far it is (the level's metas loading_progress 0..1 and
## loading_step, the caption's last line); the bar glides to it (BAR_RATE, never back), a glint runs along the bar's gold
## (GLINT_S a sweep), the line's dots step on (DOTS_PER_S) and the painting keeps drifting, so a frame that does come late
## reads as a moment's catch, not a hang. A level without the metas (the open world) fills the bar on the settle's time, as
## before.
##
##   LoadingScreen.go(get_tree(), "res://scenes/main.tscn")

const MIN_S := 2.4          ## s the painting stays at least (time to read the caption)
const SETTLE_S := 0.9       ## s after the scene change before the fade
const SAVE_SETTLE_S := 1.6  ## the same when a save is being applied
const FADE_S := 0.7
const DRIFT := 0.06         ## how much nearer the painting drifts while it shows
## The longest the painting waits on a level's meta loading_hold (s after the scene change; the ring warms its effects).
const HOLD_MAX_S := 15.0
## The ring's scene: its loading screen tells a tip of the sport.
const RING_SCENE := "res://scenes/ring.tscn"
## How fast the bar glides to where the load is (of the whole width per s); a glint's sweep along it (s) and its width (px).
const BAR_RATE := 0.9
const GLINT_S := 1.6
const GLINT_W := 140.0
## The line's dots after what is being built step on this many times a second.
const DOTS_PER_S := 2.5

## The loading screen covering the window now (until its fade begins), if any: covering().
static var _cover: LoadingScreen

var path := ""
var with_save := false
var _t := 0.0
var _settle := 0.0
var _fade_t := 0.0
var _state := "load"
var _shown := 0.0
var _pic: TextureRect
var _bar: ColorRect
var _glint: TextureRect
var _step_label: Label
var _root: Control
## Where the bar is going (0..1): _progress; the bar itself glides there (_shown).
var _target := 0.0
## The tip shown ("" none: not the ring).
var tip := ""


static func go(tree: SceneTree, scene_path: String, applying_save := false) -> LoadingScreen:
	var ls := LoadingScreen.new()
	ls.path = scene_path
	ls.with_save = applying_save
	tree.root.add_child(ls)
	return ls


## Whether a loading screen still covers the window (RingMode holds its countdown meanwhile).
static func covering() -> bool:
	return is_instance_valid(_cover)


func _exit_tree() -> void:
	if _cover == self:
		_cover = null


func _ready() -> void:
	_cover = self
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.022, 0.014)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var e := MenuPaintings.next()
	_pic = TextureRect.new()
	_pic.texture = MenuPaintings.texture(e)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = MenuPaintings.stretch(e)
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	if bool(e.get("whole", false)):
		_pic.anchor_left = 0.38        # a portrait to the right, its caption on the dark ground beside it
	_root.add_child(_pic)
	# the caption at the lower left, over a shade rising from the bottom
	var shade := MenuUI.left_shade(0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.62
	_root.add_child(shade)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 72
	box.offset_right = 72 + 620
	box.offset_top = -64
	box.offset_bottom = -64
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if bool(e.get("sheet", false)):
		# a drawing's subject is along its bottom: the caption goes up into its empty sky
		box.anchor_top = 0.0
		box.anchor_bottom = 0.0
		box.offset_top = 64
		box.offset_bottom = 64
		box.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(box)
	if not e.is_empty():
		box.add_child(MenuUI.label(MenuPaintings.title_line(e), 26, MenuUI.GOLD))
		box.add_child(MenuUI.label(String(e.caption), 19, MenuUI.INK, true))
	tip = tip_for(path)
	if tip != "":
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		box.add_child(gap)
		var head := MenuUI.label("%s  ·  A TIP" % MatchSetup.sport().to_upper(), 14, MenuUI.GOLD)
		head.name = "TipHead"
		box.add_child(head)
		var tl := MenuUI.label(tip, 20, MenuUI.INK, true)
		tl.name = "Tip"
		box.add_child(tl)
	var track := ColorRect.new()
	track.color = Color(MenuUI.DIM, 0.25)
	track.anchor_top = 1.0
	track.anchor_bottom = 1.0
	track.anchor_right = 1.0
	track.offset_top = -3
	_root.add_child(track)
	_bar = ColorRect.new()
	_bar.color = MenuUI.GOLD
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -3
	_bar.clip_contents = true
	_root.add_child(_bar)
	# (a soft light running along the gold: the bar is alive even while it waits on one part)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 1
	_glint = TextureRect.new()
	_glint.texture = gt
	_glint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glint.stretch_mode = TextureRect.STRETCH_SCALE
	_glint.anchor_bottom = 1.0
	_glint.offset_right = GLINT_W
	_glint.modulate = Color(1.0, 0.97, 0.85, 0.9)
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_glint)
	# (what the level is building, the caption's last line, on its shade)
	_step_label = MenuUI.label("", 15, MenuUI.GOLD)
	_step_label.name = "Step"
	_step_label.modulate.a = 0.8
	box.add_child(_step_label)
	_pic.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	ResourceLoader.load_threaded_request(path)


## A tip of Tidebreak's for the way into `scene_path` ("" for any scene but the ring), drawn by lot (`rng`: a test's).
static func tip_for(scene_path: String, rng: RandomNumberGenerator = null) -> String:
	if scene_path != RING_SCENE:
		return ""
	var tips: Variant = MatchSetup.screens().get("tips", [])
	if not (tips is Array) or (tips as Array).is_empty():
		return ""
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	return String((tips as Array)[r.randi_range(0, (tips as Array).size() - 1)])


func _progress(p: float) -> void:
	_target = maxf(_target, clampf(p, 0.0, 1.0))


## The bar a step nearer where the load is (never back), the glint along it, the level's line.
func _draw_bar(delta: float) -> void:
	_shown = move_toward(_shown, _target, BAR_RATE * minf(delta, 0.1))
	_bar.anchor_right = _shown
	var w := _bar.size.x
	_glint.position.x = lerpf(-GLINT_W, w, fmod(_t, GLINT_S) / GLINT_S)
	_glint.visible = w > 8.0
	var scn := get_tree().current_scene if _state == "settle" else null
	var line := String(scn.get_meta(&"loading_step", "")) if scn != null else ""
	if line != "":
		line += ".".repeat(1 + int(_t * DOTS_PER_S) % 3)      # (a beat while it works)
	if _step_label.text != line:
		_step_label.text = line


func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + DRIFT * clampf(_t / 20.0, 0.0, 1.0)
	_pic.scale = Vector2(s, s)
	_draw_bar(delta)
	match _state:
		"load":
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(path, prog)
			_progress(float(prog[0]) * 0.7 if not prog.is_empty() else 0.0)
			if st == ResourceLoader.THREAD_LOAD_LOADED and _t >= 0.6:
				_progress(0.72)
				_state = "change"
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_state = "change"
		"change":
			# (one frame with the bar drawn, then the level is built: the window holds this painting meanwhile)
			var ps := ResourceLoader.load_threaded_get(path) as PackedScene
			if ps:
				get_tree().change_scene_to_packed(ps)
			else:
				get_tree().change_scene_to_file(path)
			_state = "settle"
		"settle":
			_settle += delta
			var need := SAVE_SETTLE_S if with_save else SETTLE_S
			var scn := get_tree().current_scene
			if scn != null and scn.has_meta(&"loading_progress"):
				_progress(0.72 + 0.28 * clampf(float(scn.get_meta(&"loading_progress")), 0.0, 1.0))
			else:
				_progress(0.75 + 0.25 * clampf(_settle / need, 0.0, 1.0))
			var hold := scn != null and bool(scn.get_meta(&"loading_hold", false)) and _settle < HOLD_MAX_S
			if _settle >= need and _t >= MIN_S and not hold:
				_progress(1.0)
				_state = "fade"
				_cover = null
		"fade":
			_fade_t += delta
			_root.modulate.a = 1.0 - clampf(_fade_t / FADE_S, 0.0, 1.0)
			if _fade_t >= FADE_S:
				# (the character creator opens under the loading screen on a new game and pauses the tree:
				# it keeps the mouse it took, the cursor visible)
				if not get_tree().paused:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				elif Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				queue_free()
