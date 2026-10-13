class_name LoadingScreen
extends CanvasLayer
## The loading screen (user 2026-09-27: loading screens of oil paintings "instead of the godot"), in the broadcast look the owner
## chose (BroadcastUI, 2026-10-10): a picture over the whole window, drifting slowly nearer, its title, caption and the tip at the
## lower left over a soft shade, a foot plate like the lobby's ticker along the bottom (a LOADING tag, what the level is building,
## the percent) with the progress as a teal line along its top. It loads the scene on a thread, changes to it, gives it
## a moment to settle (a save's parts are applied a few frames after the level is built: SaveGame), then fades out.
## Added to the root, so it outlives the scene change.
## On the way into Tidebreak's ring (scenes/ring.tscn, a match or a practice) the ring's own still (the dressed ring, rendered
## by tools/ring/ring_still.gd) with Tidebreak's title and a caption of its own (screens.json "loading"; ring_entry), and a tip
## of the sport's under the caption: one rule or one answer in a line (screens.json "tips", and "tips_stock" or
## "tips_classic" for the rule set the ring will play, MatchSetup.rule_set: no zone rules told before a % match; tip_pool,
## tip_for), each drawn by lot.
## Alive while the level builds (improvement round 1, PERF: "a window that looks frozen while shaders compile"): the ring
## builds a part a frame behind it (RingLevel._build) and tells how far it is (the level's metas loading_progress 0..1 and
## loading_step, the foot's line); the bar glides to it (BAR_RATE, never back), a glint runs along the teal
## (GLINT_S a sweep), the line's dots step on (DOTS_PER_S) and the picture keeps drifting, so a frame that does come late
## reads as a moment's catch, not a hang. A level without the metas (the open world) fills the bar on the settle's time, as
## before. Every size is a BroadcastUI design size (none under its 16 px floor).
##
##   LoadingScreen.go(get_tree(), "res://scenes/main.tscn")
##   LoadingScreen.preview(parent, scene_path, progress, step)     # the screen alone, loading nothing (the shot tools')

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
## The foot plate's height (design px).
const FOOT_H := 72.0
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
var _bar: Control
var _glint: TextureRect
var _step_label: Label
var _percent_label: Label
var _root: Control
## A screen made only to be looked at (preview): nothing loads, nothing is covered, the mouse is left as it is.
var _preview := false
var _preview_step := ""
## Where the bar is going (0..1): _progress; the bar itself glides there (_shown).
var _target := 0.0
## The tip shown ("" none: not the ring).
var tip := ""
## The picture's file and its caption as shown (the tests read them).
var picture := ""
var caption := ""


static func go(tree: SceneTree, scene_path: String, applying_save := false) -> LoadingScreen:
	var ls := LoadingScreen.new()
	ls.path = scene_path
	ls.with_save = applying_save
	tree.root.add_child(ls)
	return ls


## The screen alone, as it looks `progress` (0..1) of the way into `scene_path` with `step` in its foot: nothing loads or changes, the
## window is not covered, the mouse is left as it is (the UI audit's shots and a test's look at it).
static func preview(parent: Node, scene_path := RING_SCENE, progress := 0.62, step := "") -> LoadingScreen:
	var ls := LoadingScreen.new()
	ls.path = scene_path
	ls._preview = true
	ls._preview_step = step
	ls._target = clampf(progress, 0.0, 1.0)
	ls._shown = ls._target
	parent.add_child(ls)
	return ls


## Whether a loading screen still covers the window (RingMode holds its countdown meanwhile).
static func covering() -> bool:
	return is_instance_valid(_cover)


func _exit_tree() -> void:
	if _cover == self:
		_cover = null


func _ready() -> void:
	if not _preview:
		_cover = self
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BroadcastUI.NAVY0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# (the ring has its own: a still of the dressed ring and Tidebreak's captions, not the open world's paintings and lore)
	var e := ring_entry(path)
	var tex: Texture2D = e.get("texture") if e.has("texture") else null
	if e.is_empty():
		e = MenuPaintings.next()
		tex = MenuPaintings.texture(e)
	_pic = TextureRect.new()
	_pic.texture = tex
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = MenuPaintings.stretch(e) if not e.has("texture") else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(e.get("whole", false)):
		_pic.anchor_left = 0.38        # a portrait to the right, its caption on the dark ground beside it
	_root.add_child(_pic)
	# the shades: a deep navy rising from the foot and one from the left, for the words over the picture
	var sheet := bool(e.get("sheet", false))
	if sheet:
		BroadcastUI.grad(_root, [[0.0, Color(BroadcastUI.NAVY0, 0.86)], [1.0, Color(BroadcastUI.NAVY0, 0.0)]], Vector2(0.5, 0.0), Vector2(0.5, 1.0), Rect2(0, 0, 1, 0.6))
	else:
		BroadcastUI.grad(_root, [[0.0, Color(BroadcastUI.NAVY0, 0.0)], [0.45, Color(BroadcastUI.NAVY0, 0.55)], [1.0, Color(BroadcastUI.NAVY0, 0.94)]],
				Vector2(0.5, 0.0), Vector2(0.5, 1.0), Rect2(0, 0.28, 1, 0.72))
	BroadcastUI.grad(_root, [[0.0, Color(BroadcastUI.NAVY0, 0.62)], [1.0, Color(BroadcastUI.NAVY0, 0.0)]], Vector2(0.0, 0.5), Vector2(1.0, 0.5), Rect2(0, 0, 0.7, 1))
	var L := BroadcastUI.layout(_root)
	tip = tip_for(path)
	var has_text := not e.is_empty()
	# the words at the lower left (a drawing's subject is along its bottom: its words go up into the empty sky): the title in the
	# headline type, the caption, the tip under a tag
	var box := BroadcastUI.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if sheet else BoxContainer.ALIGNMENT_END
	if sheet:
		BroadcastUI.put(L, box, Rect2(84, 64, 940, 560))
	else:
		L.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		box.offset_left = 84
		box.offset_right = 84 + 940
		box.offset_top = -(FOOT_H + 40 + 560)
		box.offset_bottom = -(FOOT_H + 40)
	if has_text:
		var title := String(e.title) if e.has("texture") else MenuPaintings.title_line(e)
		var head := BroadcastUI.caps(title, BroadcastUI.head(true, 4), 112, BroadcastUI.WHITE)
		head.name = "Title"
		head.set_meta(&"dsz", 112)
		BroadcastUI.fit_text(head, 900.0, 56)
		box.add_child(head)
		var bar := ColorRect.new()
		bar.color = BroadcastUI.TEAL
		bar.custom_minimum_size = Vector2(300, 6)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		var cap := BroadcastUI.para(String(e.caption), BroadcastUI.body(true), 30, BroadcastUI.WHITE, 900.0)
		cap.name = "Caption"
		box.add_child(cap)
		caption = String(e.caption)
		picture = tex.resource_path if tex != null else ""
	if tip != "":
		box.add_child(BroadcastUI.gap(0, 14))
		var th := BroadcastUI.hbox(0)
		th.add_child(BroadcastUI.tag("%s  ·  A TIP" % MatchSetup.sport().to_upper(), 18, BroadcastUI.INK, BroadcastUI.TEAL, 3))
		(th.get_child(0).get_child(0) as Label).name = "TipHead"
		box.add_child(th)
		var tl := BroadcastUI.para(tip, BroadcastUI.body(true), 26, BroadcastUI.WHITE, 900.0)
		tl.name = "Tip"
		box.add_child(tl)
	# the foot: the plate like the lobby's ticker, the progress as its teal top line, what is being built and how far
	var foot := Control.new()
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -FOOT_H
	BroadcastUI.rect(foot, Rect2(0, 0, 4000, FOOT_H), Color(BroadcastUI.NAVY0, 0.96)).name = "Plate"
	var track := ColorRect.new()
	track.name = "Track"
	track.color = Color(BroadcastUI.LINE, 0.9)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(track)
	track.anchor_right = 1.0
	track.offset_bottom = 6.0
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.clip_contents = true
	track.add_child(_bar)
	_bar.anchor_bottom = 1.0
	_bar.anchor_right = _shown
	var fill := ColorRect.new()
	fill.color = BroadcastUI.TEAL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (a soft light running along the teal: the bar is alive even while it waits on one part)
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
	_glint.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_glint)
	BroadcastUI.put(foot, BroadcastUI.tag("LOADING", 22, BroadcastUI.INK, BroadcastUI.TEAL, 3, Vector4(54, 12, 22, 9)), Rect2(-40, 14, 0, 0))
	_step_label = BroadcastUI.caps("", BroadcastUI.head(false, 2, 1), 22, BroadcastUI.WHITE)
	_step_label.name = "Step"
	_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BroadcastUI.put(foot, _step_label, Rect2(250, 12, 760, 50))
	var pg := BroadcastUI.group(foot, Vector2(1, 0), Vector2(-250, 12), Vector2(170, 50))
	_percent_label = BroadcastUI.lab("0%", BroadcastUI.head(true, 1), 34, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_percent_label.name = "Percent"
	_percent_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pg.add_child(_percent_label)
	_pic.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	if not _preview:
		ResourceLoader.load_threaded_request(path)
	else:
		_state = "preview"
		_draw_bar(0.0)


## The ring's own picture and words for the way into `scene_path` ({} for any scene but the ring, or no still on disk):
## {texture, title, caption} from screens.json "loading" (the still tools/ring/ring_still.gd renders of the dressed ring;
## the caption drawn by lot, `rng`: a test's). The owner, 2026-10-05: the ring's loading showed the open world's painting
## and its lore ("The shallows").
static func ring_entry(scene_path: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if scene_path != RING_SCENE:
		return {}
	var ld: Dictionary = MatchSetup.screens().get("loading", {})
	var pic := String(ld.get("picture", ""))
	if pic == "" or not ResourceLoader.exists(pic):
		return {}
	var caps: Array = ld.get("captions", [])
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var cap := String(caps[r.randi_range(0, caps.size() - 1)]) if not caps.is_empty() else ""
	return {"texture": load(pic) as Texture2D, "title": String(ld.get("title", MatchSetup.sport())), "caption": cap}


## The tips the ring's way may tell: the ones for any rules (screens.json "tips") and the rule set's own ("tips_stock": the %
## ring's lives; "tips_classic": the zones), for the rule set the next ring plays (MatchSetup.rule_set).
static func tip_pool() -> Array:
	var out: Array = []
	for key: String in ["tips", "tips_" + MatchSetup.rule_set()]:
		var t: Variant = MatchSetup.screens().get(key, [])
		if t is Array:
			out.append_array(t)
	return out


## A tip of Tidebreak's for the way into `scene_path` ("" for any scene but the ring), drawn by lot (`rng`: a test's).
static func tip_for(scene_path: String, rng: RandomNumberGenerator = null) -> String:
	if scene_path != RING_SCENE:
		return ""
	var tips := tip_pool()
	if tips.is_empty():
		return ""
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	return String(tips[r.randi_range(0, tips.size() - 1)])


func _progress(p: float) -> void:
	_target = maxf(_target, clampf(p, 0.0, 1.0))


## The bar a step nearer where the load is (never back), the glint along it, the level's line, the percent.
func _draw_bar(delta: float) -> void:
	_shown = move_toward(_shown, _target, BAR_RATE * minf(delta, 0.1))
	_bar.anchor_right = _shown
	var w := _bar.get_parent_control().size.x * _shown
	_glint.position.x = lerpf(-GLINT_W, w, fmod(_t, GLINT_S) / GLINT_S)
	_glint.visible = w > 8.0
	var scn := get_tree().current_scene if _state == "settle" else null
	var line := String(scn.get_meta(&"loading_step", "")) if scn != null else _preview_step
	if line != "":
		line += ".".repeat(1 + int(_t * DOTS_PER_S) % 3)      # (a beat while it works)
	if _step_label.text != line:
		_step_label.text = line
	var pct := "%d%%" % roundi(_shown * 100.0)
	if _percent_label.text != pct:
		_percent_label.text = pct


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
