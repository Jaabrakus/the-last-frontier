extends "res://tools/showcase/showcase_video.gd"
## Short clips of the game's systems, each in two cuts (user 2026-09-27: "lets do multiple small clips of our systems
## in the game and tutorials"):
##
##   <out>/<clip>/clean/   the game as played, nothing drawn over it but the game's own prompts (for sharing)
##   <out>/<clip>/tut/     the same frames with the tutorial drawn over them: the clip's name, and each step as it is
##                         done, with its keys, a key lighting up while it is pressed
##
## One run records every clip (the level loads once); each clip is its own film, faded in from black and out to it.
## The tutorial cut is composited on the GPU from the clean picture (a second view that draws the first view's
## picture and the tutorial panel over it), so both cuts are the same frames.
##
##   Godot --path . --resolution 960x540 --fixed-fps 30 --write-movie <dir>/raw.avi \
##       -s tools/showcase/clips.gd -- out=<dir> new_game [size=1920x1080] [ui=1920x1080] [only=<id>,<id>]
## "camp" needs the survival rules (survival=on survival_seed=7: cooking is the survival core's) and "hunt" the
## wildlife (wildlife=on: its spawner does the field dressing): record those two in a run of their own
## (make_clips.sh's EXTRA). "forage" and "rest" want survival=on too (eating, resting); "sky" wildlife=on birdlife=on
## (the owls); "mammoth" is in the climbing yard: scene=res://scenes/climb_yard.tscn.
##   python3 tools/showcase/video_audio.py <dir>/raw.avi <dir>/<clip>/frames.txt <dir>/<clip>/audio.wav
##   video_encode encode <dir>/<clip>/clean 30 <clip>.mp4 <dir>/<clip>/audio.wav    (and tut -> <clip>_tutorial.mp4)
##
## tools/showcase/make_clips.sh does all of it. The player is Actor_B; see CREDITS.md for the rest.

const CLIPS := ["torch", "hold_e", "axe", "throw", "vault", "barrow",
		"bow", "musket", "climb", "tree", "fell", "ride", "camp", "hunt",
		"forage", "rest", "wheel", "barricade", "build", "sky", "mammoth"]
const TITLES := {
	"torch": "The torch",
	"hold_e": "Everything in reach: hold E",
	"axe": "Fighting with the axe",
	"throw": "Thrown weapons",
	"vault": "Vaulting",
	"barrow": "The wheelbarrow",
	"bow": "The hunting bow",
	"musket": "The flintlock musket",
	"climb": "Climbing and ladders",
	"tree": "Climbing a tree",
	"fell": "Felling, limbing and bucking",
	"ride": "Riding",
	"camp": "A campfire and cooking",
	"hunt": "Hunting and field dressing",
	"forage": "Wild food and herbs",
	"rest": "Resting and sleeping",
	"wheel": "The equip wheel and the pack",
	"barricade": "A log barricade",
	"build": "Building a cabin",
	"sky": "Weather and night",
	"mammoth": "The mammoth",
}
const FADE_S := 0.35           ## each clip fades in from black and out to it
const FLASH_S := 0.35          ## a tapped key stays lit at least this long
const ROWS_MAX := 6
## The keys the steps name, and the game's actions they light for.
const CAP_ACTIONS := {
	"W": [&"move_forward"], "A": [&"move_left"], "S": [&"move_back"], "D": [&"move_right"],
	"Space": [&"jump"], "Shift": [&"sprint"], "Alt": [&"walk"], "C": [&"crouch"], "R": [&"reload"],
	"T": [&"torch"], "E": [&"interact"], "Q": [&"equip_wheel"], "B": [&"build_mode"], "Tab": [&"inventory"],
	"Z": [&"sleep"], "F": [&"cook"], "G": [&"grip"], "V": [&"eat"], "X": [&"sling_all"],
	"1": [&"weapon_1"], "2": [&"weapon_2"], "3": [&"weapon_3"], "4": [&"weapon_4"], "5": [&"weapon_5"],
	"6": [&"weapon_6"], "7": [&"tool_axe"], "8": [&"tool_mattock"],
	"LMB": [&"fire"], "RMB": [&"aim"], "MMB": [&"club_grip"], "Wheel": [&"weapon_next", &"weapon_prev"],
}

var tut_view: SubViewport
var tut_layer: CanvasLayer
var tut_panel: PanelContainer
var tut_kicker: Label
var tut_title: Label
var tut_rows: VBoxContainer
var tut_caps: Array = []
var held := {}                  ## action -> true while this script holds it
var flash := {}                 ## action -> seconds it stays lit
var clip_frame := 0
var clip_log := PackedStringArray()
var fade_out_from := INF        ## seg_t the fade to black starts at
var spawned: Array = []         ## what a clip added to the level (freed before the next clip)
var barrow_home := Transform3D()
var barrow_seen := false
var level_pieces := {}          ## the built pieces the level had before the first clip (kept; the clips' own go)
var _serif: SystemFont
var _sans: SystemFont
var _sans_b: SystemFont


## A key drawn as a key cap (or a mouse with its button lit), lit while the action is held or just tapped.
class KeyCap extends Control:
	var label := ""
	var host: Object
	var s := 1.0
	var font: Font
	var live := true            ## only the current step's keys light

	func _init(l: String, h: Object, sc: float, f: Font) -> void:
		label = l
		host = h
		s = sc
		font = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := 46.0
		if _mouse():
			w = 34.0
		elif label.length() > 1:
			w = 26.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(23 * s)).x / s
		custom_minimum_size = Vector2(maxf(w, 46.0 if not _mouse() else 34.0), 46.0) * s
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _mouse() -> bool:
		return label in ["LMB", "RMB", "MMB", "Wheel"]

	func _draw() -> void:
		var lit: bool = live and host.call("is_lit", label)
		var gold := Color(0.95, 0.74, 0.36)
		var ink := Color(0.97, 0.94, 0.87)
		if _mouse():
			var r := Rect2(Vector2(3, 0) * s, Vector2(28, 46) * s)
			var body := StyleBoxFlat.new()
			body.bg_color = Color(0.05, 0.05, 0.06, 0.55)
			body.set_corner_radius_all(int(12 * s))
			body.border_color = ink
			body.set_border_width_all(maxi(1, int(2 * s)))
			draw_style_box(body, r)
			var mid := r.position.x + r.size.x * 0.5
			var split := r.position.y + r.size.y * 0.42
			draw_line(Vector2(r.position.x, split), Vector2(r.end.x, split), ink, maxf(1.0, 1.5 * s))
			if label != "Wheel":
				draw_line(Vector2(mid, r.position.y), Vector2(mid, split), ink, maxf(1.0, 1.5 * s))
			var inset := 2.5 * s
			if label == "LMB" or label == "RMB" or label == "MMB":
				if lit and label != "MMB":
					var left := label == "LMB"
					var x0 := r.position.x + inset if left else mid + 1.0 * s
					var x1 := mid - 1.0 * s if left else r.end.x - inset
					var btn := StyleBoxFlat.new()
					btn.bg_color = gold
					if left:
						btn.corner_radius_top_left = int(10 * s)
					else:
						btn.corner_radius_top_right = int(10 * s)
					draw_style_box(btn, Rect2(x0, r.position.y + inset, x1 - x0, split - inset * 0.6 - r.position.y - inset))
				elif label == "MMB":
					var wr := Rect2(Vector2(mid - 3 * s, r.position.y + 5 * s), Vector2(6, 12) * s)
					var wheel := StyleBoxFlat.new()
					wheel.bg_color = gold if lit else Color(ink, 0.0)
					wheel.border_color = ink
					wheel.set_border_width_all(maxi(1, int(1.5 * s)))
					wheel.set_corner_radius_all(int(3 * s))
					draw_style_box(wheel, wr)
			else:
				var wr := Rect2(Vector2(mid - 3 * s, r.position.y + 5 * s), Vector2(6, 12) * s)
				var wheel := StyleBoxFlat.new()
				wheel.bg_color = gold if lit else Color(ink, 0.0)
				wheel.border_color = ink
				wheel.set_border_width_all(maxi(1, int(1.5 * s)))
				wheel.set_corner_radius_all(int(3 * s))
				draw_style_box(wheel, wr)
			return
		var box := StyleBoxFlat.new()
		box.bg_color = gold if lit else Color(0.05, 0.05, 0.06, 0.55)
		box.set_corner_radius_all(int(7 * s))
		box.border_color = gold if lit else ink
		box.set_border_width_all(maxi(1, int(2 * s)))
		box.border_width_bottom = maxi(2, int(4 * s))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var fs := int(23 * s)
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := Vector2((size.x - ts.x) * 0.5, (size.y - 2 * s + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.06, 0.04) if lit else ink)


func _order() -> Array:
	return CLIPS


# --- the two cuts --------------------------------------------------------------------------------------------------

func _build_overlay() -> void:
	super()
	captions = false               # the clean cut has no captions; the tutorial has its own panel
	cine_takes_over = false        # (a clip's side shot must not turn what E and the torch aim at)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var s := px.y / 1080.0
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
	_serif.font_weight = 500
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
	_sans.font_weight = 500
	_sans_b = SystemFont.new()
	_sans_b.font_names = _sans.font_names
	_sans_b.font_weight = 700
	tut_view = SubViewport.new()
	tut_view.name = "TutorialView"
	tut_view.size = px
	tut_view.disable_3d = true
	tut_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tut_view)
	var pic := TextureRect.new()
	pic.texture = view.get_texture()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_view.add_child(pic)
	tut_layer = CanvasLayer.new()
	tut_layer.layer = 10
	tut_view.add_child(tut_layer)

	tut_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.04, 0.58)
	sb.set_corner_radius_all(int(8 * s))
	sb.border_width_left = int(4 * s)
	sb.border_color = Color(0.85, 0.62, 0.3, 0.95)
	sb.content_margin_left = 24 * s
	sb.content_margin_right = 28 * s
	sb.content_margin_top = 16 * s
	sb.content_margin_bottom = 20 * s
	tut_panel.add_theme_stylebox_override("panel", sb)
	tut_panel.position = Vector2(44, 44) * s
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_layer.add_child(tut_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(4 * s))
	tut_panel.add_child(vb)
	tut_kicker = _label(_sans_b, int(18 * s), Color(0.9, 0.7, 0.42))
	tut_kicker.text = "HOW TO PLAY"
	tut_title = _label(_serif, int(46 * s), Color(0.97, 0.94, 0.87))
	vb.add_child(tut_kicker)
	vb.add_child(tut_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6 * s)
	vb.add_child(gap)
	tut_rows = VBoxContainer.new()
	tut_rows.add_theme_constant_override("separation", int(10 * s))
	vb.add_child(tut_rows)
	tut_panel.modulate.a = 0.0


## A step of the tutorial: `spec` is text with keys in brackets ("Double-tap [T] [T]: torch mode"). It becomes the
## current row; the ones before it dim.
func _step(spec: String) -> void:
	var s := px.y / 1080.0
	for r in tut_rows.get_children():
		(r as Control).modulate.a = 0.5
		var bar := r.get_child(0) as ColorRect
		bar.color.a = 0.0
	for c in tut_caps:
		if is_instance_valid(c):
			(c as KeyCap).live = false
	while tut_rows.get_child_count() >= ROWS_MAX:
		var old := tut_rows.get_child(0)
		tut_rows.remove_child(old)
		old.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * s))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(3, 30) * s
	bar.color = Color(0.95, 0.74, 0.36)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var at := 0
	for m in re.search_all(spec):
		var txt := spec.substr(at, m.get_start() - at).strip_edges()
		if txt != "":
			row.add_child(_row_text(txt, s))
		var cap := KeyCap.new(m.get_string(1), self, s, _sans_b)
		tut_caps.append(cap)
		row.add_child(cap)
		at = m.get_end()
	var rest := spec.substr(at).strip_edges()
	if rest != "":
		row.add_child(_row_text(rest, s))
	tut_rows.add_child(row)


func _row_text(t: String, s: float) -> Label:
	var l := _label(_sans, int(28 * s), Color(0.95, 0.93, 0.88))
	l.text = t
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## A key is lit while an action it stands for is held by this script, or for a moment after a tap.
func is_lit(label: String) -> bool:
	for a: StringName in CAP_ACTIONS.get(label, []):
		if held.has(a) or float(flash.get(a, 0.0)) > 0.0:
			return true
	return false


func _flash(action: StringName, secs := FLASH_S) -> void:
	flash[action] = maxf(float(flash.get(action, 0.0)), secs)


func _press(action: StringName) -> void:
	held[action] = true
	_flash(action)
	super(action)


func _release(action: StringName) -> void:
	held.erase(action)
	super(action)


func _tap(action: StringName, hold_s := 0.1) -> void:
	held[action] = true
	_flash(action, hold_s + FLASH_S)
	await super(action, hold_s)
	held.erase(action)


## A mouse click as the game polls it (as an event the musket would take it as its own and shoulder).
func _click(hold_s := 0.12) -> void:
	held[&"fire"] = true
	_flash(&"fire", hold_s + FLASH_S)
	Input.action_press(&"fire")
	await _sec(hold_s)
	Input.action_release(&"fire")
	held.erase(&"fire")


## A press / release as input events (what a real key does: the "just pressed" edge the firearms wait for).
func _press_ev(action: StringName) -> void:
	held[action] = true
	_flash(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)


func _release_ev(action: StringName) -> void:
	held.erase(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)


## A key event the handlers read as events (the hold-E list's wheel), lit.
func _event(action: StringName) -> void:
	_flash(action)
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _frame()


func _overlay(t: float) -> void:
	super(t)
	var dt := 1.0 / fps
	for a in flash.keys():
		flash[a] = float(flash[a]) - dt
	var i := 0
	while i < tut_caps.size():
		if not is_instance_valid(tut_caps[i]):
			tut_caps.remove_at(i)
			continue
		(tut_caps[i] as Control).queue_redraw()
		i += 1
	tut_panel.modulate.a = smoothstep(0.15, 0.6, t) * (1.0 - smoothstep(fade_out_from - 0.3, fade_out_from, t))
	var a := 1.0 - smoothstep(0.0, FADE_S, t)
	if fade_out_from < INF:
		a = maxf(a, smoothstep(fade_out_from, fade_out_from + FADE_S, t))
	black_rect.color = Color(0, 0, 0, a)


func _begin_segment() -> void:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()
	# the health panel with the rested bar stays in the picture (user 2026-09-28: "keep survival bar on for the
	# recording because the main game"); the slot strip, ammo and compass stay out (the "12345" HUD)
	show_vitals = true
	# what the clip before left: its carcasses and dummies gone, the barrow back where the level put it
	var w := Wheelbarrow.find(self)
	if w:
		if not barrow_seen:
			barrow_home = w.global_transform
			barrow_seen = true
		if w.is_pushed():
			w.set_down("clip")
		if w.load_node != null:
			w.tip_out()
		w.park_at(barrow_home.origin, barrow_home.basis.z)
	for n in spawned:
		if is_instance_valid(n):
			(n as Node).queue_free()
	spawned.clear()
	# built pieces a clip left (a campfire, a cabin) go before the next: they would stand in its way
	if level_pieces.is_empty():
		level_pieces[0] = true
		for bp in level.find_children("*", "BuiltPiece", true, false):
			level_pieces[bp.get_instance_id()] = true
	else:
		for bp in level.find_children("*", "BuiltPiece", true, false):
			if not level_pieces.has(bp.get_instance_id()):
				bp.queue_free()
	# well rested, as after a night's sleep (the blue bar under the health bar full, as in play); the rest clip shows
	# earning it from nothing
	_rested()
	player.health = player.max_health if cur_id != "rest" else player.health
	# the range's dummies stand whatever hits them
	for d in level.find_children("*", "TargetDummy", true, false):
		d.set("max_health", 1.0e6)
		d.set("health", 1.0e6)
	last_image = null              # no dissolve from the clip before: each clip is its own film
	clip_frame = 0
	clip_log = PackedStringArray()
	fade_out_from = INF
	held.clear()
	flash.clear()
	for r in tut_rows.get_children():
		tut_rows.remove_child(r)
		r.queue_free()
	tut_caps.clear()
	tut_title.text = String(TITLES.get(cur_id, cur_id))
	DirAccess.make_dir_recursive_absolute(out.path_join(cur_id).path_join("clean"))
	DirAccess.make_dir_recursive_absolute(out.path_join(cur_id).path_join("tut"))


func _end_segment() -> void:
	if recording:
		fade_out_from = seg_t
		await _sec(FADE_S + 0.05)
	recording = false
	await _flush()
	var f := FileAccess.open(out.path_join(cur_id).path_join("frames.txt"), FileAccess.WRITE)
	f.store_line("# frame engine_frame shot t  (fps %d, size %dx%d, movie %s)" % [fps, px.x, px.y, Engine.get_write_movie_path()])
	for l in clip_log:
		f.store_line(l)
	f.store_line("# end engine_frame %d" % Engine.get_process_frames())
	f.close()
	black_rect.color = Color(0, 0, 0, 0)
	tut_panel.modulate.a = 0.0
	super()


func _save_frame(img: Image) -> void:
	var dir := out.path_join(cur_id)
	var n := clip_frame
	clip_log.append("%d %d %s %.4f" % [n, Engine.get_process_frames() - 1, cur_id, seg_t])
	clip_frame += 1
	frame_no += 1
	var tut := tut_view.get_texture().get_image()
	while pending.size() >= SAVE_QUEUE:
		WorkerThreadPool.wait_for_task_completion(pending.pop_front())
	var q := jpg_q
	pending.append(WorkerThreadPool.add_task(func() -> void:
		img.save_jpg(dir.path_join("clean/f%05d.jpg" % n), q)
		tut.save_jpg(dir.path_join("tut/f%05d.jpg" % n), q)))


func _write_log() -> void:
	pass


# --- clips ---------------------------------------------------------------------------------------------------------

func _ground_v(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground(p.x, p.z), p.z)


## The weapon drawn and ready: the switch and its own draw done (a click during the draw is ignored).
func _equip(key: String) -> void:
	await super(key)
	await _until(func() -> bool: return player.weapon == null or not player.weapon.is_equipping(), 4.0)


## Until the torch is in the hand (the handoff done).
func _torch_in_hand() -> void:
	await _until(func() -> bool: return player.torch.holding() and not player.torch.pending, 4.0)


## Two taps of T inside the double-tap time.
func _double_t() -> void:
	await _tap(&"torch", 0.08)
	await _sec(0.08)
	await _tap(&"torch", 0.08)


## Take out a torch, raise and lower it, set it in the ground, take it back, throw one. At dusk outside the fort's
## east wall; the game's own camera (the prompts, the ghost torch and the throw's arc are the game's).
func seg_torch() -> void:
	_clock(19.85, "clear", 0.0)
	await _equip("musket")
	var at := Vector3(24.0, 0.0, 12.0)
	_place(at.x, at.z, at + Vector3(0, 0, -5))
	player.pitch = deg_to_rad(-12.0)
	if player.torch.count() < 3:
		player.torch.add_torches(3)
	await _roll("", "", "", 60)
	await _sec(0.5)
	_step("[T]  Take out a lit torch")
	await _tap(&"torch")
	await _torch_in_hand()
	await _sec(1.0)
	_step("[T]  Raise it, and again to lower it")
	await _tap(&"torch")
	await _sec(1.9)
	await _tap(&"torch")
	await _sec(1.4)
	_step("[T] [T]  Double-tap: torch mode")
	await _double_t()
	await _sec(1.6)
	_step("[LMB]  Push it into the ground")
	await _click()
	await _sec(1.4)
	var set_t := player.torch.last_dropped
	_step("[E]  Take it back")
	if set_t:
		await _sec(0.5)
		await _tap(&"interact")
		await _torch_in_hand()
	await _sec(0.6)
	player.pitch = deg_to_rad(-14.0)
	_step("[T] [T]  Torch mode, then [T]  to throw")
	await _double_t()
	await _sec(0.9)
	await _tap(&"torch")
	await _sec(1.4)
	_step("[LMB]  Throw it")
	await _click()
	await _sec(2.6)
	_step("[T]  Another torch")
	await _tap(&"torch")
	await _torch_in_hand()
	await _sec(1.2)
	_step("Hold [T]  Put it away")
	await _sec(0.4)
	await _tap(&"torch", 0.6)
	await _sec(1.8)


## The hold-E list by the wheelbarrow with a dead doe beside it: hold E, the wheel chooses, letting go does it.
func seg_hold_e() -> void:
	_clock(15.0, "fair", 0.2)
	await _equip("musket")
	var w := Wheelbarrow.find(self)
	if w == null:
		print("CLIPS: no wheelbarrow")
		return
	w.park_at(_ground_v(Vector3(2.5, 0, -27.0)), Vector3(0, 0, -1))
	await _warm(6)
	var side := -w.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	level.add_child(doe)
	spawned.append(doe)
	doe.global_position = _ground_v(w.bed_point() + side * 1.3)
	await _warm(2)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _skip(6.0)
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := w.bed_point() + side * 2.2 - fwd * 0.6
	_place(at.x, at.z, doe.global_position)
	player.pitch = deg_to_rad(-30.0)
	await _roll("", "", "", 50)
	await _sec(0.8)
	_step("[E]  Tap: what the crosshair is on")
	await _sec(1.8)
	_step("Hold [E]  Everything in reach")
	_press(&"interact")
	var it := player.interactor
	await _until(func() -> bool: return not it.menu.is_empty(), 2.0)
	await _sec(1.2)
	_step("[Wheel]  Choose")
	var want := -1
	for i in it.menu.size():
		if "barrow" in String(it.menu[i].text).to_lower():
			want = i
	if want < 0:
		want = mini(2, it.menu.size() - 1)
	print("CLIPS hold_e rows: ", it.menu.map(func(r: Dictionary) -> String: return String(r.text)), " -> ", want)
	while it.menu_i != want and not it.menu.is_empty():
		await _event(&"weapon_next")
		await _sec(0.55)
	await _sec(0.6)
	_step("Let go of [E]  Do it")
	_release(&"interact")
	_flash(&"interact")
	await _sec(2.6)
	_step("[RMB]  While holding: put the list away")
	await _sec(0.4)
	_press(&"interact")
	await _until(func() -> bool: return not it.menu.is_empty(), 2.0)
	await _sec(0.9)
	await _event(&"aim")
	await _sec(0.5)
	_release(&"interact")
	await _sec(1.0)


## The felling axe's four cuts on a range dummy: the move key held as you click picks the cut.
func seg_axe() -> void:
	_clock(10.0, "fair", 0.2)
	var spot := Vector3(-8.0, 0.0, -30.0)
	_place(spot.x, spot.z, spot + Vector3(0, 0, -5))
	player.pitch = 0.0
	var d := TargetDummy.new()
	d.position = _ground_v(spot + Vector3(0.0, 0.0, -1.05))
	level.add_child(d)
	d.max_health = 1.0e6
	d.health = 1.0e6
	spawned.append(d)
	var g: GatherTools = player.gather
	_cam_rel(Vector3(-2.9, 1.55, -1.9), Vector3(0.1, 1.15, -0.45), 50.0, 4.0, null, false)
	await _roll("", "", "", 50)
	await _sec(0.5)
	_step("[7]  The felling axe")
	await _tap(&"tool_axe")
	await _until(func() -> bool: return g.phase == GatherTools.Phase.READY, 4.0)
	await _sec(0.5)
	for c: Array in [["D", &"move_right", "Swing right to left"], ["A", &"move_left", "Swing left to right"],
			["W", &"move_forward", "Overhead"], ["S", &"move_back", "Rising cut"]]:
		_step("[%s] + [LMB]  %s" % [c[0], c[2]])
		await _sec(0.5)
		held[c[1]] = true
		_flash(c[1], 0.6)
		_flash(&"fire", 0.6)
		Input.action_press(c[1])
		Input.action_press(&"fire")
		await _frame()
		await _frame()
		Input.action_release(c[1])
		Input.action_release(&"fire")
		held.erase(c[1])
		await _until(func() -> bool: return g.phase == GatherTools.Phase.READY, 5.0)
		await _sec(0.5)
		player.global_position = Vector3(spot.x, _ground(spot.x, spot.z) + 0.05, spot.z)
		player.velocity = Vector3.ZERO
	_step("[7]  Put it away")
	await _tap(&"tool_axe")
	await _sec(1.4)


## The tomahawk and the spear thrown into the range's dummies (they stick), then a look at them.
func seg_throw() -> void:
	_clock(8.9, "fair", 0.2)
	for k in ["tomahawk", "spear"]:
		if not player.is_carried(k):
			player.set_carried(k, true)
	_place(-2.2, FrontierStructures.FIRING_LINE_Z - 1.5, Vector3(-2.5, 1.0, -30.0))
	for k in ["tomahawk", "spear"]:
		var tw := player.weapons.get(k) as Throwable
		if tw:
			for f in ["spread_base", "spread_move", "spread_undercharge", "fire_bloom", "spread_air", "spread_fatigue", "spread"]:
				tw.set(f, 0.0)
	await _equip("tomahawk")
	aim_target = Vector3(-2.5, 1.35, -30.0)
	aim_rate = 5.0
	await _roll("", "", "")
	await _sec(0.4)
	_step("[5]  The tomahawk")
	await _sec(0.9)
	_step("Hold [LMB]  Wind up: the arc shows")
	_press(&"fire")
	await _sec(1.1)
	_step("Let go of [LMB]  Throw")
	_release(&"fire")
	await _sec(1.6)
	_step("[4]  The spear")
	held[&"weapon_4"] = true
	_flash(&"weapon_4", 0.5)
	await _equip("spear")
	held.erase(&"weapon_4")
	aim_target = Vector3(0.0, 1.15, -45.0)
	await _sec(0.6)
	_step("Hold [LMB] and let go  Throw")
	_press(&"fire")
	await _sec(1.3)
	_release(&"fire")
	await _sec(1.6)
	aim_target = Vector3.INF
	_step("[E]  Walk up and take them back")
	await _target_close(Vector3(-2.5, 0.0, -30.0), 1.8)
	await _target_close(Vector3(0.0, 0.0, -45.0), 1.8)


## The firing line's rail at a sprint (it vaults by itself), then a straw truss at a run with Space.
func seg_vault() -> void:
	_clock(9.0, "fair", 0.2)
	await _equip("musket")
	_place(0.0, -9.0, Vector3(0, 0, -60))
	player.traversal.controller.teleported()
	var cam := Vector3(8.5, _ground(8.5, -24.5) + 1.3, -24.5)
	_cam_at(cam, func() -> Vector3: return player.global_position + Vector3(0, 0.9, -0.6), 45.0, 6.0)
	await _roll("", "", "")
	await _sec(0.4)
	_step("[W] + Hold [Shift]  Sprint at it: vaults by itself")
	_press(&"move_forward")
	_press(&"sprint")
	await _until(func() -> bool: return player.global_position.z < -27.0, 6.0)
	_release(&"sprint")
	await _sec(0.5)
	_release(&"move_forward")
	await _sec(0.6)
	var b2 := Vector3(5.0, 0.0, -50.0)
	_place(b2.x, b2.z + 8.0, b2 + Vector3(0, 0, -20))
	player.traversal.controller.teleported()
	var cam2 := Vector3(b2.x + 7.0, _ground(b2.x + 7.0, b2.z + 1.0) + 1.3, b2.z + 1.0)
	_cam_at(cam2, func() -> Vector3: return player.global_position + Vector3(0, 0.9, -0.8), 42.0, 6.0)
	_step("[Space]  At a run: vault a straw truss")
	await _cut(20)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= b2.z + 1.5, 4.0)
	await _tap(&"jump")
	await _until(func() -> bool: return player.global_position.z < b2.z - 6.0, 7.0)
	_release(&"move_forward")
	await _sec(0.8)


## The wheelbarrow: take the handles, push it with a doe in the bed, set it down.
func seg_barrow() -> void:
	_clock(15.3, "fair", 0.2)
	await _equip("musket")
	var w := Wheelbarrow.find(self)
	if w == null:
		print("CLIPS: no wheelbarrow")
		return
	var lane := Vector3(0.0, 0.0, -1.0)
	w.park_at(_ground_v(Vector3(3.5, 0, -24.0)), lane)
	await _warm(6)
	var side := -w.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	level.add_child(doe)
	spawned.append(doe)
	doe.global_position = _ground_v(w.bed_point() + side * 1.4)
	await _warm(3)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _skip(6.0)
	w.put_carcass(doe)
	await _warm(10)
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_place(g.x - fwd.x * 0.9, g.z - fwd.z * 0.9, w.bed_point())
	player.pitch = deg_to_rad(-20.0)
	var sd := fwd.cross(Vector3.UP).normalized()
	_cam_rel(Vector3(3.4, 1.5, -0.6), Vector3(-0.2, 0.7, -1.6), 50.0, 3.0)
	if not player.hands_free:
		player.toggle_hands_free()          # (the musket slung first: both hands for the handles)
	await _warm(60)
	await _roll("", "", "", 20)
	await _sec(0.6)
	_step("[E]  At the handles: take it")
	await _tap(&"interact")
	await _until(func() -> bool: return w.is_pushed(), 3.0)
	await _sec(0.6)
	_step("[W]  Push: a doe, logs, or what the pack holds")
	player.yaw = atan2(-lane.x, -lane.z)
	_press(&"move_forward")
	await _sec(4.2)
	_release(&"move_forward")
	await _sec(0.6)
	_step("[E]  Set it down")
	await _tap(&"interact")
	await _sec(1.6)
	print("CLIPS barrow pushed=%s sd=%s" % [w.is_pushed(), sd])


## Draw, loose, and let the string down without shooting, at the range's 25 m dummy; the arrows in it after.
func seg_bow() -> void:
	_clock(8.2, "fair", 0.2)
	var tgt := Vector3(0.0, 1.3, -45.0)
	_place(-1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("musket")
	aim_target = tgt
	aim_rate = 5.0
	await _roll("", "", "")
	await _sec(0.4)
	_step("[1]  The bow")
	held[&"weapon_1"] = true
	_flash(&"weapon_1", 0.5)
	await _equip("bow")
	held.erase(&"weapon_1")
	await _sec(0.5)
	_step("Hold [LMB]  Draw: longer, harder and flatter")
	_press(&"fire")
	await _sec(1.7)
	_step("Let go of [LMB]  Loose")
	_release(&"fire")
	await _sec(1.6)
	_step("Hold [LMB] , then [RMB]  Let the string down")
	_press(&"fire")
	await _sec(1.3)
	_press(&"aim")
	await _sec(0.25)
	_release(&"aim")
	_release(&"fire")
	await _sec(1.4)
	_step("Hold [LMB] , let go  Another")
	_press(&"fire")
	await _sec(1.6)
	_release(&"fire")
	await _sec(1.4)
	aim_target = Vector3.INF
	await _target_close(Vector3(tgt.x, 0.0, tgt.z), 2.2)


## Shoulder, fire, reload; a side view at the firing line.
func seg_musket() -> void:
	_clock(8.6, "fair", 0.2)
	var tgt := Vector3(2.5, 1.25, -70.0)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("bow")
	aim_target = tgt
	aim_rate = 5.0
	_cam_rel(Vector3(-2.3, 1.65, 1.6), Vector3(0.4, 1.35, -3.0), 50.0, 4.0)
	await _roll("", "", "")
	await _sec(0.4)
	_step("[2]  The musket")
	held[&"weapon_2"] = true
	_flash(&"weapon_2", 0.5)
	await _equip("musket")
	held.erase(&"weapon_2")
	await _sec(0.5)
	_step("Hold [LMB]  Shoulder it")
	_press_ev(&"fire")
	await _sec(1.4)
	print("CLIPS musket held: state %s aim %.2f" % [player.weapon.get("state"), player.weapon.get("aim")])
	_step("Let go of [LMB]  Fire")
	_release_ev(&"fire")
	await _sec(2.2)
	_step("[R]  Reload: powder, ball, ramrod, prime")
	await _tap(&"reload")
	await _sec(6.5)


## Space at the fort's walkway edge climbs onto it; the ladder by the gate, up hand over hand.
func seg_climb() -> void:
	_clock(15.2, "fair", 0.2)
	await _equip("musket")
	_place(8.0, -10.8, Vector3(8.0, 0, -40))
	player.traversal.controller.teleported()
	_cam_rel(Vector3(2.6, 1.5, 3.2), Vector3(-0.2, 1.6, -1.5), 52.0, 5.0)
	await _roll("", "", "")
	await _sec(0.4)
	_step("[W] , then [Space]  at a ledge: climb up")
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= -13.55, 3.0)
	await _tap(&"jump", 0.15)
	await _sec(3.4)
	_release(&"move_forward")
	await _sec(0.6)
	_place(-5.1, -11.6, Vector3(-5.1, 0, -40))
	player.traversal.controller.teleported()
	_cam_at(Vector3(-9.6, _ground(-9.6, -8.4) + 3.0, -8.4), func() -> Vector3: return player.global_position + Vector3(0, 1.1, 0), 52.0, 3.0)
	_step("[W]  at a ladder: climb it")
	await _cut(30)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.y > 2.1 and not player.traversal.showing, 9.0)
	await _sec(0.6)
	_release(&"move_forward")
	await _sec(0.8)


## A tree standing on its own (few others within LONE_M), near the fort, sized for the job: [index, pos, trunk radius,
## collider height, crown bottom] or [] (climb: a trunk collider 0.22 m+ across and 5-9 m to the crown, as PlayerGrip
## wants; fell: 0.16-0.3 m, 12 m+ tall, crown high off the ground so the game's camera sees under it).
const LONE_M := 12.0


func _lone_tree(climb: bool) -> Array:
	var lay = level.get("vegetation").layout
	var n: int = lay.tree_pos.size()
	var cands: Array = []
	for i in n:
		if lay.tree_collider[i] == 0 or (not climb and int(lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT):
			continue
		var pos: Vector3 = lay.tree_pos[i]
		var dist := Vector2(pos.x, pos.z).length()
		if dist < 30.0 or dist > 220.0 or (absf(pos.x) < 16.0 and pos.z < 0.0 and pos.z > -160.0):
			continue
		if absf(pos.y - _ground(pos.x, pos.z)) > 0.08:
			continue
		var info: Dictionary = VegHarvest.Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		var sc: float = lay.tree_scale[i]
		var r := float(info.get("trunk_radius", 0.3)) * sc
		var h := float(info.get("collider_height", 6.0)) * sc
		var tall := float(info.get("height", 18.0)) * sc
		var cb := float(info.get("crown_bottom", 4.0)) * sc
		if climb and (r * 0.92 < 0.22 or maxf(h, 3.3) < 5.0 or h > 9.0):
			continue
		if not climb and (r < 0.16 or r > 0.3 or tall < 12.0 or cb < 3.5):
			continue
		cands.append([dist, i, pos, r, h, cb])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best := []
	var best_n := 1 << 30
	for c: Array in cands.slice(0, 160):
		var p: Vector3 = c[2]
		var near := 0
		for j in n:
			var q: Vector3 = lay.tree_pos[j]
			if absf(q.x - p.x) < LONE_M and absf(q.z - p.z) < LONE_M and j != int(c[1]):
				near += 1
		if near < best_n:
			best_n = near
			best = [c[1], p, c[3], c[4], c[5]]
		if near == 0:
			break
	print("CLIPS lone tree (%s): %s, %d others within %.0f m" % ["climb" if climb else "fell", best, best_n, LONE_M])
	return best


## The direction (flat) a tree `tall` m high at `p` has the clearest lane to fall along: the fewest other trees within
## 1.6 m of the line.
func _fall_lane(p: Vector3, tall: float) -> Vector3:
	var lay = level.get("vegetation").layout
	var best := Vector3.FORWARD
	var best_n := 1 << 30
	for k in 16:
		var a := TAU * k / 16.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var n := 0
		for q: Vector3 in lay.tree_pos:
			var v := q - p
			var along := v.x * d.x + v.z * d.z
			if along < 0.5 or along > tall + 2.0:
				continue
			if absf(v.x * d.z - v.z * d.x) < 1.6:
				n += 1
		if n < best_n:
			best_n = n
			best = d
	print("CLIPS fall lane %s: %d trees in it" % [best, best_n])
	return best


## The nearest sturdy tree north of the fort (as tests/climb/test_tree_climb.gd picks it): [axis, radius, crown].
func _climb_tree() -> Array:
	var veg = level.get("vegetation")
	var lay = veg.layout
	var best := INF
	var out := []
	for i in lay.tree_pos.size():
		if lay.tree_collider[i] == 0:
			continue
		var info: Dictionary = VegHarvest.Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		var sc: float = lay.tree_scale[i]
		var r := clampf(float(info.get("trunk_radius", 0.3)) * sc * 0.92, 0.1, 0.75)
		var h := maxf(float(info.get("collider_height", 6.0)) * sc, 3.3)
		var pos: Vector3 = lay.tree_pos[i]
		if r < 0.22 or h < 5.0 or h > 9.0 or absf(pos.y - _ground(pos.x, pos.z)) > 0.05:
			continue
		var d := pos.distance_to(Vector3(0, 0, -30))
		if d < best and _clear_round(pos, r):
			best = d
			out = [pos, r, pos.y + h - 0.3]
	return out


func _clear_round(pos: Vector3, r: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	q.shape = cap
	var to_open := Vector3(0, 0, -30) - pos
	to_open.y = 0.0
	var at := pos + to_open.normalized() * (r + 0.6)
	q.transform = Transform3D(Basis(), Vector3(at.x, _ground(at.x, at.z) + 0.95, at.z))
	return player.get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty()


## Hold G at a trunk, W up to the crown, onto a branch, then a held Space jumps down.
func seg_tree() -> void:
	_clock(10.4, "fair", 0.2)
	var t := _lone_tree(true)
	if t.is_empty():
		print("CLIPS: no tree to climb")
		return
	var axis: Vector3 = t[1]
	var radius: float = clampf(float(t[2]) * 0.92, 0.1, 0.75)
	var to_open := Vector3(0, 0, 0) - axis
	to_open.y = 0.0
	to_open = to_open.normalized()
	var at := axis + to_open * (radius + 0.55)
	_place(at.x, at.z, axis)
	player.pitch = deg_to_rad(8.0)
	await _roll("", "", "", 40)
	await _sec(0.5)
	var g: PlayerGrip = player.grip
	_step("Hold [G]  at a trunk: take hold")
	_press(&"grip")
	await _until(func() -> bool: return g.state == PlayerGrip.HOLD, 3.0)
	await _sec(0.6)
	_step("[W]  Climb: the grip tires as you go")
	_press(&"move_forward")
	await _until(func() -> bool: return g.perched, 18.0)
	_release(&"move_forward")
	_step("At the crown: onto a branch, crouched")
	await _sec(1.2)
	_release(&"grip")
	await _sec(1.8)
	_step("Hold [Space]  Jump down")
	await _tap(&"jump", 0.5)
	await _sec(2.6)


## Hold the axe's click at a trunk to fell it; E in the crown limbs it; E along the log bucks a length off.
func seg_fell() -> void:
	_clock(10.5, "fair", 0.2)
	var h := VegHarvest.find(self)
	var lt := _lone_tree(false)
	if lt.is_empty():
		print("CLIPS: no tree to fell")
		return
	var i: int = lt[0]
	var tree := h.describe("tree", "tree", i)
	var tp: Vector3 = tree.pos
	var d := _fall_lane(tp, float(tree.height))       # (it falls away from the axe)
	var at := tp - d * (float(tree.radius) + 1.0)
	_place(at.x, at.z, tp)
	player.pitch = deg_to_rad(4.0)
	var gt: GatherTools = player.gather
	if gt.skills:
		gt.skills.set_points("woodcutting", 70.0)
	await _roll("", "", "")
	await _sec(0.4)
	_step("[7]  The felling axe")
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 3.0)
	_step("Hold [LMB]  at a trunk: fell it")
	var felled := [null]
	gt.felled.connect(func(f: FelledTree) -> void: felled[0] = f, CONNECT_ONE_SHOT)
	_press(&"fire")
	await _until(func() -> bool: return felled[0] != null, 14.0)
	_release(&"fire")
	var ft: FelledTree = felled[0]
	if ft == null:
		return
	await _until(func() -> bool: return ft.is_down(), 6.0)
	await _sec(1.0)
	# in its crown, beside the stem
	var cr := float(ft.info.get("crown_radius", 3.0))
	var mid := ft.hinge + ft.axis() * (float(ft.info.get("crown_bottom", ft.length * 0.4)) + ft.length) * 0.5
	var sd := ft.axis().cross(Vector3.UP).normalized()
	var stand := mid + sd * minf(cr * 0.5, 1.5)
	_place(stand.x, stand.z, mid)
	player.pitch = deg_to_rad(-22.0)
	_step("[E]  in the crown: limb it, stroke by stroke")
	await _cut(20)
	var limbed := [null]
	gt.limbed.connect(func(sl: SkidLoad) -> void: limbed[0] = sl, CONNECT_ONE_SHOT)
	for k in 30:
		if limbed[0] != null:
			break
		print("CLIPS limb tap %d: target %s prompt '%s'" % [k, gt.target.get("type", ""), player.interactor._label.text])
		await _tap(&"interact")
		await _sec(0.35)
		await _until(func() -> bool: return gt._swing.is_empty() and gt.in_hand() == "felling_axe", 4.0)
	var lg: SkidLoad = limbed[0]
	await _sec(1.0)
	if lg == null or lg.logs_left < 2:
		return
	var bm := lg.front + (lg.back - lg.front) * 0.5
	var bs := (lg.back - lg.front).cross(Vector3.UP).normalized()
	_place(bm.x + bs.x, bm.z + bs.z, bm)
	player.pitch = deg_to_rad(-22.0)
	_step("[E]  along the log: buck off a length")
	await _cut(20)
	var n0 := lg.logs_left
	for k in 12:
		if not is_instance_valid(lg) or lg.logs_left < n0:
			break
		print("CLIPS buck tap %d: target %s prompt '%s' in hand %s player %s log %s-%s" % [k, gt.target.get("type", ""), player.interactor._label.text,
				gt.in_hand(), player.global_position, lg.front, lg.back])
		if not "Buck" in player.interactor._label.text:
			break
		await _tap(&"interact")
		await _sec(0.35)
		await _until(func() -> bool: return gt._swing.is_empty() and gt.in_hand() == "felling_axe", 4.0)
	await _sec(1.4)


## E at the saddle mounts; W rides, Shift steps up a gait; E held gets off.
func seg_ride() -> void:
	_clock(15.5, "fair", 0.25)
	var horse := _horse()
	if horse == null:
		print("CLIPS: no horse")
		return
	var lead := horse.get_node_or_null("Lead")
	if lead and lead.has_method("stop"):
		lead.stop()
	var hp := Vector3(-9.0, 0.0, -24.0)
	hp.y = _ground(hp.x, hp.z)
	horse.global_position = hp
	horse.look_at(hp + Vector3(0, 0, -1), Vector3.UP)
	horse.speed = 0.0
	await _warm(10)
	var mp := horse.get_mount_point(Horse.LEFT).origin
	var away := mp - horse.get_saddle_transform().origin
	away.y = 0.0
	away = away.normalized()
	var st := mp + away * 0.4
	_place(st.x, st.z, horse.get_saddle_transform().origin)
	player.pitch = deg_to_rad(-10.0)
	_cam_rel(Vector3(4.2, 1.7, 2.8), Vector3(0.0, 1.4, -1.5), 50.0, 3.0, horse)
	await _roll("", "", "", 30)
	await _sec(0.5)
	_step("[E]  at the saddle: mount")
	await _tap(&"interact")
	await _until(func() -> bool: return player.riding != null, 3.0)
	await _sec(2.2)
	player.yaw = horse.global_rotation.y
	_step("[W]  Walk on")
	_press(&"move_forward")
	await _sec(1.6)
	_step("[Shift]  A tap for each gait up: trot, canter")
	await _tap(&"sprint")
	await _sec(1.5)
	await _tap(&"sprint")
	await _sec(2.6)
	_release(&"move_forward")
	_step("Let go of [W]  Rein in")
	await _sec(2.0)
	_step("Hold [E]  Get off")
	await _tap(&"interact", 0.7)
	await _until(func() -> bool: return player.riding == null, 3.0)
	await _sec(1.0)


## Build a campfire (B, the wheel, hold E), light it (E), cook venison on it (F).
func seg_camp() -> void:
	_clock(17.6, "fair", 0.2)
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 6)
	inv.add("venison", 2)
	player.inventory_pack = inv.pack.duplicate(true)
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	if mode == null:
		print("CLIPS: no build mode")
		return
	var fire_at := _ground_v(Vector3(21.0, 0, 6.0))
	_place(fire_at.x, fire_at.z + 2.6, fire_at)
	if not player.hands_free:
		player.toggle_hands_free()
	player.pitch = deg_to_rad(-26.0)
	var side := Vector3(1, 0, 0)
	_cam_at(fire_at + side * 3.4 + Vector3(0, 1.9, 2.4), func() -> Vector3: return (fire_at + player.global_position) * 0.5 + Vector3.UP * 0.6, 50.0, 3.0)
	await _warm(60)
	await _roll("", "", "", 10)
	await _sec(0.4)
	_step("[B]  Build mode")
	await _tap(&"build_mode")
	await _until(func() -> bool: return mode.active, 2.0)
	await _sec(0.6)
	_step("[Wheel]  Choose the campfire")
	mode.select_type("campfire")
	_flash(&"weapon_next", 0.8)
	mode.aim_at = fire_at
	await _sec(1.2)
	_step("Hold [E] , let go  Build it here")
	_press(&"interact")
	await _sec(0.6)
	_release(&"interact")
	await _sec(0.8)
	if mode.active:
		await _tap(&"build_mode")
	mode.aim_at = Vector3.INF
	await _sec(0.6)
	var cf: Campfire = null
	for c in level.find_children("*", "Campfire", true, false):
		if (c as Node3D).global_position.distance_to(fire_at) < 1.5:
			cf = c
	if cf == null:
		print("CLIPS: the campfire was not built")
		return
	_step("[E]  Light it: flint and steel")
	await _tap(&"interact")
	await _until(func() -> bool: return cf.is_lit(), 3.0)
	await _sec(1.6)
	_step("[F]  Roast venison from the pack")
	await _tap(&"cook")
	await _sec(5.5)


## Crouched with the bow at a deer in the meadow by the range: a shot through the vitals, then E: skin, then butcher.
## (A deer of its own, standing broadside: the level's herds keep to their own plans and hours.)
func seg_hunt() -> void:
	_clock(16.8, "fair", 0.15)
	await _equip("bow")
	var at := Vector3(9.0, 0.0, -84.0)
	var dp := _ground_v(Vector3(12.0, 0.0, -99.0))
	var bw := player.weapons.get("bow") as Weapon
	if bw:
		for f in ["spread_base", "spread_move", "spread_undercharge", "spread_air", "spread_fatigue", "spread_unaimed", "spread"]:
			bw.set(f, 0.0)                # (the shot goes where the tutorial says: the vitals)
	var deer := WildAnimal.new()
	deer.setup("deer", level.get_node_or_null("Wildlife") as WildlifeSpawner, null, 21)   # (the spawner does the field dressing)
	level.add_child(deer)
	spawned.append(deer)
	deer.global_position = dp
	deer.rotation.y = PI * 0.5            # broadside to the player
	deer.set("_yaw", deer.rotation.y)
	deer.set_active(true)
	_place(at.x, at.z, dp)
	var vit := deer.get_node_or_null("Hit_vitals") as Node3D
	var vp := func() -> Vector3: return vit.global_position if vit else deer.global_position + Vector3.UP * 0.8
	aim_rate = 4.0
	for k in 45:
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	await _roll("", "", "", 0)
	_step("[C]  Crouch: quieter, and downwind")
	await _tap(&"crouch")
	for k in int(1.4 * fps):
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	_step("Hold [LMB]  Draw on the vitals")
	_press(&"fire")
	for k in int(1.8 * fps):
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	_step("Let go of [LMB]  Loose")
	_release(&"fire")
	await _sec(1.0)
	print("CLIPS hunt: deer %.1f m away, dead %s" % [deer.global_position.distance_to(player.global_position), deer.is_dead()])
	if not deer.is_dead() and vit:
		Hit.deliver(vit as StaticBody3D, 150.0, vit.global_position, Vector3(1, 0, 0), player)
	aim_target = Vector3.INF
	await _sec(2.4)
	var side := (-deer.global_basis.z).cross(Vector3.UP).normalized()
	var by := deer.global_position + side * 1.3
	await _tap(&"crouch")
	_place(by.x, by.z, deer.global_position)
	player.pitch = deg_to_rad(-30.0)
	await _skip(1.0)
	_cam_rel(Vector3(-1.6, 1.7, 2.4), Vector3(0.3, 0.4, -1.2), 50.0, 3.0)
	_step("[E]  at the carcass: skin it, then butcher it")
	await _cut(20)
	await _tap(&"interact")
	await _sec(0.5)
	print("CLIPS dress after E: prompt '%s' kneeling %s" % [player.interactor._label.text, player.kneeling])
	await _sec(5.5)


## The hour and the weather; with the survival rules on (as the game plays: make_clips.sh records with them), their
## core keeps the clock and the sky follows it, so the hour is set there too.
func _clock(hour: float, weather := "fair", cover := -1.0) -> void:
	super(hour, weather, cover)
	_survival_time(hour)
	_rested()


## Well rested for the next 8 game hours (the rest clip: not at all, it earns it), and fed, so hunger does not cap it.
func _rested() -> void:
	var sb := SurvivalBridge.find(self)
	if sb == null or sb.core == null:
		return
	if cur_id == "rest":
		sb.core.state.flags["well_rested_until"] = -1.0
		return
	sb.core.state.flags["well_rested_until"] = float(sb.core.state.minutes) + 8.0 * 60.0
	if not args.has("_rest_logged"):
		args["_rest_logged"] = true
		print("CLIPS rested: %.1f h left, cap %.1f h, well rested %s" % [sb.rested_hours_left(), sb.rest_cap_h(), sb.is_well_rested()])


## With the survival rules on, their core keeps the clock (the sky follows it): the hour set there, on the same day.
func _survival_time(hour: float) -> void:
	var b := SurvivalBridge.find(self)
	if b == null or b.core == null:
		return
	var m := float(b.core.state.minutes)
	var into := fposmod(m, 1440.0)
	var to := hour * 60.0
	b.core.state.minutes = m - into + to       # (the same day: no days skipped, so no hunger piled up between clips)
	b.core.state.world["clock_acc"] = 0.0


## Blackberries at the fort's edge: E picks them; V eats the best food in the pack.
func seg_forage() -> void:
	_clock(11.5, "fair", 0.2)
	var f := ForageField.find(self)
	if f == null:
		print("CLIPS: no forage")
		return
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind != "blackberry":
			continue
		var dd := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
		if dd < bd:
			bd = dd
			best = i
	if best < 0:
		print("CLIPS: no blackberries")
		return
	var pl: Dictionary = f.patches[best].plants[0]
	for q in f.patches[best].plants:
		if float(q.stock) > 0.0:
			pl = q
			break
	var pp: Vector3 = pl.pos
	var out_dir := Vector3(-pp.x, 0.0, -pp.z).normalized()
	var at := pp + out_dir * 1.1
	_place(at.x, at.z, pp)
	player.pitch = deg_to_rad(-22.0)
	if not player.hands_free:
		player.toggle_hands_free()
	var side := out_dir.cross(Vector3.UP).normalized()
	_cam_at(at + side * 2.6 + out_dir * 1.4 + Vector3.UP * 1.4, func() -> Vector3: return (at + pp) * 0.5 + Vector3.UP * 0.7, 45.0)
	await _warm(50)
	await _roll("", "", "", 10)
	await _sec(0.5)
	_step("[E]  Pick: berries, nuts, roots and herbs")
	await _tap(&"interact")
	await _sec(4.4)
	_step("Each in its place and season: deer eat them too")
	await _sec(1.6)
	_step("[V]  Eat the best food in the pack")
	await _tap(&"eat")
	await _sec(2.6)


## By a lit campfire at dusk, hurt: a tap of Z rests (the health refills), holding Z sleeps the night through.
func seg_rest() -> void:
	_clock(19.9, "clear", 0.1)
	var fire_at := _ground_v(Vector3(21.0, 0, 6.0))
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 14)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(fire_at.x + 1.7, fire_at.z + 0.6, fire_at)
	if not player.hands_free:
		player.toggle_hands_free()          # (build mode leaves while a weapon is in the hands)
	await _warm(60)
	if mode:
		mode.set_active(true)
		mode.select_type("campfire")
		mode.aim_at = fire_at
		await _warm(6)
		mode.refresh_placement()
		var fp := mode.place()
		mode.set_active(false)
		mode.aim_at = Vector3.INF
		var cf := fp.get_node_or_null("Campfire") as Campfire if fp else null
		if cf:
			cf.light()
			for k in 8:
				cf.add_wood(player)         # (banked for the night: a fire that dies wakes the sleeper)
			spawned.append(fp)
		print("CLIPS rest fire: piece %s campfire %s lit %s" % [fp, cf, cf.is_lit() if cf else false])
	_place(fire_at.x + 1.7, fire_at.z + 0.6, fire_at)
	if not player.hands_free:
		player.toggle_hands_free()
	player.health = 52.0
	show_vitals = true
	_cam_at(fire_at + Vector3(-2.6, 1.7, 3.6), func() -> Vector3: return (fire_at + player.global_position) * 0.5 + Vector3.UP * 0.5, 50.0, 3.0)
	await _warm(60)
	await _roll("", "", "", 10)
	await _sec(0.6)
	_step("[Z]  Rest: sit down, the health refills")
	await _tap(&"sleep")
	await _sec(4.5)
	_step("Hold [Z]  Sleep: the night passes, a fire makes it better")
	_press_ev(&"sleep")
	await _sec(0.9)
	_release_ev(&"sleep")
	var sl := level.find_children("*", "SurvivalSleep", true, false)
	var sleeper: Node = sl[0] if not sl.is_empty() else null
	await _until(func() -> bool: return sleeper != null and bool(sleeper.get("sleeping")), 3.0)
	print("CLIPS rest: sleeping %s at %.2f h" % [sleeper.get("sleeping") if sleeper else "-", dn.clock.time_of_day() if dn.clock.has_method("time_of_day") else -1.0])
	await _until(func() -> bool: return sleeper == null or not bool(sleeper.get("sleeping")), 20.0)
	print("CLIPS rest: awake at %.0f min of the day" % fposmod(float(SurvivalBridge.find(self).core.state.minutes), 1440.0))
	_step("Well rested: the blue bar, faster healing and learning")
	await _sec(3.2)


## Hold Q: the wheel; the mouse's way chooses; letting go takes it in hand. Tab: the pack.
func seg_wheel() -> void:
	_clock(11.0, "fair", 0.22)
	await _equip("musket")
	_place(2.0, 4.0, Vector3(2.0, 0, -30.0))
	await _roll("", "", "")
	await _sec(0.6)
	var wheel: EquipWheel = player.equip_wheel
	_step("Hold [Q]  The wheel: weapons, tools, the torch")
	_press(EquipWheel.ACTION)
	await _sec(0.7)
	_step("Move the mouse  Choose")
	if wheel and wheel.is_open:
		var n := wheel.slots.size()
		for i in n + 1:
			var ang := TAU * float(i % n) / float(n)
			wheel.pick_toward(Vector2(sin(ang), -cos(ang)) * 200.0)
			await _sec(0.28)
		var bi := -1
		for i in n:
			if String(wheel.slots[i].id) == "w:bow":
				bi = i
		if bi >= 0:
			var ang := TAU * float(bi) / float(n)
			wheel.pick_toward(Vector2(sin(ang), -cos(ang)) * 200.0)
		await _sec(0.7)
	_step("Let go of [Q]  Take it in hand")
	_release(EquipWheel.ACTION)
	await _sec(1.8)
	_step("[Tab]  The pack: everything you carry")
	await _tap(&"inventory")
	await _sec(3.6)
	for c in root.get_children():
		if c is InventoryScreen:
			(c as InventoryScreen).close()
	await _sec(0.6)


## A cut log (SaveParts' loose bole, as tests/horse/log_pull_shots.gd makes one) lying at `a` along `dir`.
func _loose_log(a: Vector3, dir: Vector3, length: float, r: float, seed_i: int) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, _ground(a.x, a.z) + r, a.z)
	var b := f + d * length
	b.y = _ground(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": 9000 + seed_i,
			"pos": [a.x, a.y, a.z]}, "front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.92,
			"logs_total": 1, "logs_left": 1}, GatherData.get_default().felling, true)
	level.add_child(s)
	spawned.append(s)
	return s


## E at a log's end takes its rope, S pulls it back, E lays it down; E on a laid one stacks it; crouched behind it.
func seg_barricade() -> void:
	_clock(14.0, "fair", 0.2)
	await _equip("musket")
	var lp = player.log_pull
	var at := _ground_v(Vector3(-3.0, 0.0, -112.0))    # (across the range lane: open dirt, clear of its dummies and trusses)
	var ax := Vector3(1, 0, 0)
	var side := Vector3(0, 0, 1)
	# the first log laid already; the second lies 3 m out, to be pulled onto it
	var first := _loose_log(at, ax, 2.4, 0.2, 1)
	await _warm(40)
	_place(first.front.x - 0.9, first.front.z, first.front)     # (at its end: the rope from afar would drag it over)
	await _warm(10)
	lp.start(first, 0)
	await _warm(130)
	lp.stack_on = lp._find_stack()
	lp.lay()
	await _warm(80)
	var second := _loose_log(at - side * 2.8 + ax * 1.4, ax, 2.4, 0.2, 2)
	var third := _loose_log(at + side * 0.6, ax, 2.4, 0.2, 3)
	await _warm(40)
	var end := second.front
	_place(end.x - 0.9, end.z, end)
	player.pitch = deg_to_rad(-18.0)
	var mid := first.mid()
	print("CLIPS barricade: first laid at %s" % first.mid())
	_cam_at(mid + side * 5.2 + ax * 1.2 + Vector3.UP * 1.9, func() -> Vector3: return mid - side * 1.4 + Vector3.UP * 0.3, 55.0, 3.0)
	await _warm(30)
	await _roll("", "", "", 10)
	await _sec(0.5)
	_step("[E]  at a log's end: take the rope")
	await _tap(&"interact")
	await _until(func() -> bool: return lp.load != null, 3.0)
	await _sec(1.0)
	_step("[S]  Pull it back  ·  [A] [D]  sideways")
	_press(&"move_back")
	await _sec(2.4)
	_release(&"move_back")
	await _sec(0.3)
	_step("[E]  Lay it down")
	await _tap(&"interact")
	await _until(func() -> bool: return lp.load == null, 2.0)
	await _sec(1.0)
	# another, lying beside the laid one: onto it
	var e3 := third.front
	_place(e3.x - 0.9, e3.z, e3)
	player.pitch = deg_to_rad(-18.0)
	_step("[E] , then [E]  over a laid log: stack it, up to three high")
	await _cut(16)
	await _tap(&"interact")
	await _until(func() -> bool: return lp.load != null, 3.0)
	await _sec(1.2)
	await _tap(&"interact")
	await _sec(1.4)
	if lp.load != null:
		lp.stack_on = lp._find_stack()
		lp.lay()
	print("CLIPS barricade: third laid %s on %s" % [third.laid, third.get("stacked_on")])
	await _sec(0.8)
	_step("[C]  Crouch behind it; aim over it")
	_place(mid.x, mid.z + 0.9, mid - side * 20.0)
	player.pitch = deg_to_rad(-5.0)
	_cam_at(mid - side * 5.5 + ax * 1.8 + Vector3.UP * 1.1, func() -> Vector3: return mid + Vector3.UP * 0.6, 50.0, 3.0)
	await _cut(20)
	await _tap(&"crouch")
	await _sec(1.8)
	await _tap(&"crouch")
	await _sec(0.4)
	_press_ev(&"aim")
	await _sec(2.0)
	_release_ev(&"aim")
	await _sec(0.6)


## Build mode: B; the wheel picks the piece; holding E and letting go builds it where it snaps; a cabin, piece by piece.
func seg_build() -> void:
	_clock(12.5, "fair", 0.25)
	var cabin := Vector3(21.0, 0.0, 6.0)
	var mode: BuildMode = player.building
	var inv := InventoryState.from_player(player)
	inv.add("log", 300)
	inv.add("stone", 200)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(cabin.x + 4.0, cabin.z + 3.5, cabin)
	if not player.hands_free:
		player.toggle_hands_free()
	var c := cabin + Vector3(0, _ground(cabin.x, cabin.z), 0)
	var st := {"a": 0.0}
	cam_fn = func(dt: float) -> Array:
		st.a = float(st.a) + dt * 0.12
		var a := float(st.a) + 0.5
		return [c + Vector3(sin(a) * 11.0, 5.2, cos(a) * 11.0), c + Vector3(0, 1.4, 0), 50.0]
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine
	await _warm(40)
	await _roll("", "", "", 10)
	await _sec(0.4)
	_step("[B]  Build mode")
	await _tap(&"build_mode")
	await _until(func() -> bool: return mode.active, 2.0)
	await _sec(0.5)
	_step("[Wheel]  Choose a piece  ·  [R]  turn it")
	await _sec(0.8)
	_step("Hold [E] , let go  Build it where it snaps")
	var G := BuildGeometry
	var fl := await _build_with_e(mode, "floor", c)
	if fl:
		var fo := fl.global_position
		var top := float(G.FLOOR_H)
		var walls := {}
		for sp: Array in [["wall", Vector3(1.3, 0, 0)], ["wall_window", Vector3(-1.3, 0, 0)], ["wall_door", Vector3(0, 0, 1.3)],
				["wall", Vector3(0, 0, -1.3)]]:
			walls[sp[1]] = await _build_with_e(mode, String(sp[0]), fo + (sp[1] as Vector3) + Vector3(0, top, 0))
		for k: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
			var w: BuiltPiece = walls.get(k)
			if w:
				await _build_with_e(mode, "gable", w.global_transform * Vector3(0, float(G.WALL_H) + 0.01, 0))
		await _build_with_e(mode, "roof", fo + Vector3(0, top, 0))
		await _build_with_e(mode, "hearth", fo + Vector3(2.3, 0, 0))
		for sp in level.find_children("*", "BuiltPiece", true, false):
			spawned.append(sp)
	mode.aim_at = Vector3.INF
	_step("[B]  Done")
	await _sec(0.8)
	await _tap(&"build_mode")
	await _sec(1.2)


## A piece built the player's way: chosen (the wheel), its ghost where it snaps, E held and let go.
func _build_with_e(mode: BuildMode, type: String, p: Vector3) -> BuiltPiece:
	mode.select_type(type)
	_flash(&"weapon_next", 0.4)
	mode.aim_at = p
	mode.aim_from = Vector3.INF
	await _sec(0.35)
	var n0 := level.find_children("*", "BuiltPiece", true, false).size()
	_press(&"interact")
	await _sec(0.4)
	_release(&"interact")
	await _sec(0.3)
	var all := level.find_children("*", "BuiltPiece", true, false)
	if all.size() > n0:
		return all[all.size() - 1] as BuiltPiece
	print("CLIPS build: %s not built with E; placed" % type)
	return mode.place()


## Weather and night: a storm front brewing and breaking over the range, then dusk: fireflies, and an owl.
func seg_sky() -> void:
	_clock(14.2, "fair", 0.3)
	var w := dn.weather
	dn.force_weather("storm")
	w.field.front.w = 1.0
	w.set("_front_strength", 1.0)
	w.kind_duration = 1.0e6
	_place(10.0, -44.0, Vector3(-40.0, 0.0, -100.0))     # (off the moving dummy's track at 40 m)
	var pos := player.global_position
	_storm_at(16.0, pos)
	var d2 := Vector2(w.field.front.x, w.field.front.y).normalized()
	_place(pos.x, pos.z, pos + Vector3(-d2.x, 0.0, -d2.y) * 100.0)     # (facing the storm: it lies against the front's way)
	await _skip(1.0)
	_cam_rel(Vector3(0.8, 2.0, 4.2), Vector3(-0.2, 4.0, -12.0), 60.0, 3.0)
	await _warm(40)
	await _roll("", "", "", 10)
	_step("Storms you can see coming: the wind rises as a front brews")
	var dur := 12.0
	var n := int(dur * fps)
	var strikes := [4.5, 6.2, 7.6, 8.8, 10.0, 11.2]
	for fi in n:
		var t := float(fi) / fps
		if fi == int(5.5 * fps):
			_step("Then the gust front, rain and lightning")
		var km := lerpf(12.0, -4.0, pow(t / dur, 1.2))
		var strike := false
		for sx: float in strikes:
			if t >= sx and t - 1.0 / fps < sx:
				strike = true
		_storm_at(km, pos, strike)
		await _frame()
	dn.force_weather("fair")
	# dusk: fireflies over the meadow, then an owl
	_clock(20.15, "clear", 0.0)
	var m := Vector3(20.0, 0.0, -110.0)
	_place(m.x, m.z, Vector3(24.0, 0.0, -125.0))
	await _skip(3.0)
	var cam := Vector3(18.0, _ground(18.0, -100.0) + 1.5, -100.0)
	_cam_path([[cam, Vector3(24.0, cam.y - 0.3, -125.0)], [cam + Vector3(2.0, 0.2, -1.0), Vector3(20.0, cam.y + 0.4, -128.0)]], 6.0, 60.0)
	_step("Dusk: fireflies in summer; the sun and moon cross the sky")
	await _cut(60)
	await _sec(5.0)
	var birds := level.get_node_or_null("BirdLife") as BirdLife
	if birds:
		dn.clock.set_time(19.4)
		birds.sun_override = -8.0
		await _skip(2.0)
		var owls := birds.owls()
		if not owls.is_empty():
			var o := owls[0]
			var to := o.global_position - player.global_position
			to.y = 0.0
			var oc := o.global_position - to.normalized() * 1.7
			oc.y = o.global_position.y + 0.35
			var far := o.global_position - to.normalized() * 30.0
			_place(far.x, far.z, o.global_position)
			birds.sun_override = -16.0
			_cam_path([[oc, o.global_position + Vector3.UP * 0.32], [oc + Vector3(0, 0.05, 0) - to.normalized() * 0.4, o.global_position + Vector3.UP * 0.32]], 5.0, 40.0)
			_step("Owls at night: stare too long and they are gone")
			await _cut(30)
			await _sec(4.5)
		birds.sun_override = INF


## In the climbing yard: a ball behind a knee brings the mammoth down; while it is down, G takes hold of its flank and
## W climbs onto its back; G again when it shakes.
func seg_mammoth() -> void:
	var yard = level.get("yard")
	if yard == null or yard.giant == null:
		print("CLIPS: no climbing yard (scene=res://scenes/climb_yard.tscn)")
		return
	_clock(10.5, "fair", 0.2)
	var gi = yard.giant
	gi.paces = false
	await _equip("musket")
	await _warm(30)
	# behind it and to the side: the back of a hind knee in sight
	var legs: Array = gi.weak
	var wk: Node3D = null
	var best := -INF
	var body: Vector3 = gi.global_position
	var fwd: Vector3 = -(gi.get("body") as Node3D).global_basis.z if gi.get("body") is Node3D else -gi.global_basis.z
	for z: Node3D in legs:
		var back := -(z.global_position - body).dot(fwd)
		if back > best:
			best = back
			wk = z
	var aim_pt := wk.global_position if wk else body + Vector3.UP * 1.5
	var from_dir := (-fwd * 0.8 + fwd.cross(Vector3.UP).normalized() * 0.6).normalized()
	var stand := aim_pt + from_dir * 11.0
	_place(stand.x, stand.z, aim_pt)
	aim_target = aim_pt
	aim_rate = 5.0
	_cam_rel(Vector3(1.6, 1.8, 3.2), Vector3(-0.6, 1.2, -6.0), 55.0, 3.0)
	await _warm(40)
	await _roll("", "", "", 10)
	await _sec(0.4)
	_step("Hold [LMB]  Shoulder: aim behind a knee")
	_press_ev(&"fire")
	await _sec(1.6)
	_step("Let go of [LMB]  Fire: that leg buckles")
	_release_ev(&"fire")
	await _sec(1.6)
	if String(gi.down_leg) == "" and wk:
		print("CLIPS mammoth: the ball missed the knee; brought down")
		gi.apply_hit(60.0, aim_pt, -from_dir, player, "knee_" + String(wk.name).trim_prefix("Weak_").trim_prefix("knee_"))
	aim_target = Vector3.INF
	await _sec(1.4)
	print("CLIPS mammoth down_leg '%s' phase '%s'" % [gi.down_leg, gi.down_phase])
	# at its flank, while it is down
	var st: Dictionary = yard.stations["giant"]
	_place((st.stand as Vector3).x, (st.stand as Vector3).z, st.look)
	player.pitch = 0.15
	_cam_game()
	_step("Hold [G]  at its flank while it is down: take hold")
	await _cut(20)
	_press(&"grip")
	await _sec(0.8)
	_step("[W]  Climb onto its back")
	_press(&"move_forward")
	await _until(func() -> bool: return player.grip.state == PlayerGrip.OFF \
			or (player.grip.anchor != null and player.grip.anchor.global_basis.y.y > 0.93), 12.0)
	_release(&"move_forward")
	_release(&"grip")
	await _sec(1.0)
	_step("Hold [G]  when it shakes; stand while it is calm")
	await _until(func() -> bool: return bool(gi.shaking), 8.0)
	_press(&"grip")
	await _until(func() -> bool: return not bool(gi.shaking), 6.0)
	await _sec(0.6)
	_release(&"grip")
	await _sec(1.0)
