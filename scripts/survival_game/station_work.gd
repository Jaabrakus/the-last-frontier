class_name StationWork
extends Node
## The player at work at a station (SurvivalBridge.work; CampStation's tanning frame, drying rack and alchemy table):
## they turn to it and work it, low (kneeling: the extracted Actor_B low-search clips, as FieldDressing), at a table
## (the 1 m search clips) or up high (hanging meat on a rack: the high search clips), while a bar fills. The work is a
## job of the survival core (its time and its check: the bar follows the job, and it ends when the job does) or, with
## no job, `seconds` of real time. Moving, jumping, aiming or a weapon drawn stops it: a core job is cancelled (the
## core keeps its progress) and `on_end` hears false; done, it hears true.
##
##   work.begin(station.global_position, "table", "Grinding plantain", 5.0, "", func(ok): ...)

const LIB := "actor_b"
const CLIPS := {
	"low": ["actor_b-cap-ambi-search-low-in-place-entry", "actor_b-cap-ambi-search-low-in-place", "actor_b-cap-ambi-search-low-in-place-exit"],
	"table": ["actor_b-cap-ambi-search-1m-in-place-entry", "actor_b-cap-ambi-search-1m-in-place", "actor_b-cap-ambi-search-1m-in-place-exit"],
	"high": ["actor_b-cap-ambi-search-high-in-place-entry", "actor_b-cap-ambi-search-high-in-place", "actor_b-cap-ambi-search-high-in-place-exit"],
}
const OUT_S := 1.4
const CANCEL_ACTIONS := ["jump", "crouch", "aim", "fire", "reload", "sprint"]

var bridge: SurvivalBridge
var working := false
## The core job worked ("" for timed work), and how the last work ended.
var job := ""
var last_ok := false

var _clips: Array = []
var _seconds := 0.0
var _elapsed := 0.0
var _on_end: Callable
var _ended := false
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _phase := 0
var _t := 0.0
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar


func _ready() -> void:
	_build_ui()


## Starts work facing `face_at`. `height`: "low", "table" or "high". `job_id`: the core job already started for it (its
## time sets the bar), or "" for `seconds` of real time. False when the player cannot (then nothing was started here;
## the caller cancels its job).
func begin(face_at: Vector3, height: String, text: String, seconds: float, job_id: String, on_end: Callable) -> bool:
	var p := bridge.player
	if working or p == null:
		return false
	_ap = p.begin_kneel(self, face_at)
	if _ap == null:
		return false
	working = true
	job = job_id
	_seconds = maxf(seconds, 0.1)
	_elapsed = 0.0
	_on_end = on_end
	_ended = false
	_clips = CLIPS.get(height, CLIPS.low)
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, p, LIB)
	_blender.show_clip(_clips[0], 0.0, 0.0)
	_blender.update(0.0)
	_label.text = text
	_bar.value = 0.0
	_layer.visible = true
	return true


## Goes on kneeling into the next core job (TrapStation: the catch taken, then skinned and dressed): the bar follows
## `job_id` now. Call it as the last job finishes (the core's job_finished), with the next one started.
func go_on(job_id: String, text: String) -> void:
	if not working or _ended:
		return
	job = job_id
	_label.text = text
	_bar.value = 0.0


## Stops now (the player's choice, or the caller's): a core job is cancelled, the player gets up.
func stop(reason := "moved") -> void:
	if not working:
		return
	if job != "" and SurvivalJobs.is_running(bridge.core) and String(SurvivalJobs.current(bridge.core).get("action", "")) == job:
		bridge.core.cancel_job(reason)
	_finish(false)


func _physics_process(dt: float) -> void:
	if not working:
		return
	var p := bridge.player
	if p == null or not is_instance_valid(p) or p.is_dead or p.kneeling != self:
		_finish(false)
		_end()
		return
	if _phase < 2 and _cancel_pressed():
		stop("moved")
	_t += dt
	match _phase:
		0:
			_blender.show_clip(_clips[0], minf(_t, _len(_clips[0])), 0.15)
			if _t >= _len(_clips[0]):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(_clips[1], fposmod(_t, _len(_clips[1])), 0.3)
			if job != "":
				var j := SurvivalJobs.current(bridge.core)
				if String(j.get("action", "")) == job:
					_bar.value = clampf(float(j.get("elapsed_min", 0.0)) / maxf(float(j.get("duration_min", 1.0)), 0.01), 0.0, 1.0)
				else:
					_finish(true)                 # the job is over (the caller had the core's result)
			else:
				_elapsed += dt
				_bar.value = clampf(_elapsed / _seconds, 0.0, 1.0)
				if _elapsed >= _seconds:
					_finish(true)
		2:
			_blender.show_clip(_clips[2], minf(_t, _len(_clips[2])), 0.2)
			if _t >= minf(OUT_S, _len(_clips[2])):
				_end()
				return
	_blender.update(dt)


func _finish(ok: bool) -> void:
	if _ended:
		return
	_ended = true
	last_ok = ok
	_layer.visible = false
	_phase = 2
	_t = 0.0
	if _on_end.is_valid():
		_on_end.call(ok)


func _end() -> void:
	working = false
	job = ""
	_layer.visible = false
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	var p := bridge.player
	if p and p.kneeling == self:
		p.end_kneel()


func _cancel_pressed() -> bool:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3:
		return true
	for a: String in CANCEL_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return not bridge.player.hands_free


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
	box.offset_left = -170.0
	box.offset_right = 170.0
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
	_bar.custom_minimum_size = Vector2(340, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.6, 0.4)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
