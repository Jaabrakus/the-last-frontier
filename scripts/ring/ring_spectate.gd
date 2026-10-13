class_name RingSpectate
extends Node3D
## Watching after your last life in a team format (the owner, 2026-10-10: 2v2 and 4v4 "Triple AAA"; before this the player
## out of lives stood hidden at his spout, his camera on an empty grate, until the game ended). RingMode starts it when the
## player's last life goes in a team format and stops it at the next game (or a rematch): a camera of its own behind a
## fighter still in play, your team first, from his own end looking down the deck the way he fights, eased after him; Space
## (jump) steps to the next one. One plain line at the foot says whom you watch: nothing is drawn on or near anyone. Your move
## strip is put away while you watch (no move to make) and the hint card waits (RingLessons: nothing while away).
##   RingSpectate.start(mode) -> RingSpectate   stop()   watched() -> Node3D   next()
## Every number in data/ring/rules.json "spectate" (back_m, up_m, ahead_m, ease).

const NODE_NAME := "RingSpectate"

var mode: RingMode
var cam: Camera3D
var target: Node3D
var _layer: CanvasLayer
var _line: Label
var _was: Camera3D
## The player's move strip, put away while watching (no moves to make), and whether it stood.
var _strip: CanvasItem
var _strip_was := false


## Watching for the player of `m` (a camera of its own made current; the player's back when stop() is called).
static func start(m: RingMode) -> RingSpectate:
	var old := m.get_node_or_null(NODE_NAME) as RingSpectate
	if old != null:
		return old
	var s := RingSpectate.new()
	s.name = NODE_NAME
	s.mode = m
	m.add_child(s)
	return s


static func num(key: String, def: float) -> float:
	var c: Variant = RingRules.data().get("spectate", {})
	return float((c as Dictionary).get(key, def)) if c is Dictionary else def


func _ready() -> void:
	cam = Camera3D.new()
	cam.name = "SpectateCam"
	cam.fov = 62.0
	add_child(cam)
	var vp := get_viewport()
	_was = vp.get_camera_3d() if vp != null else null
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_line = BroadcastUI.caps("", BroadcastUI.head(false, 3, 1), 22, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_line.name = "Watching"
	_line.add_theme_constant_override("outline_size", 6)
	_line.add_theme_color_override("font_outline_color", Color(BroadcastUI.INK, 0.85))
	_layer.add_child(_line)
	target = _pick(0)
	if target != null:
		cam.global_transform = _wanted()
	cam.make_current()
	var p := mode.player if mode != null else null
	if p != null and is_instance_valid(p) and p.hud != null and p.hud.get(&"bend_strip") is CanvasItem:
		_strip = p.hud.get(&"bend_strip") as CanvasItem
		_strip_was = _strip.visible
		_strip.visible = false


## Back to the player's own camera, this taken away.
func stop() -> void:
	if _strip != null and is_instance_valid(_strip):
		_strip.visible = _strip_was
	var p := mode.player if mode != null else null
	if p != null and is_instance_valid(p) and p.camera != null and is_instance_valid(p.camera):
		p.camera.make_current()
	elif _was != null and is_instance_valid(_was):
		_was.make_current()
	queue_free()


func watched() -> Node3D:
	return target


## The next fighter still in play (your side first, then theirs).
func next() -> void:
	target = _pick(1)


func _process(dt: float) -> void:
	if mode == null or not is_instance_valid(mode):
		return
	if target == null or not is_instance_valid(target) or not mode.in_play(target):
		target = _pick(0)
	if Input.is_action_just_pressed(&"jump"):
		next()
	_say()
	if target == null:
		return
	var want := _wanted()
	var k := 1.0 - exp(-dt * num("ease", 4.0))
	cam.global_position = cam.global_position.lerp(want.origin, k)
	var look := target.global_position + Vector3.UP * 1.2 + _ahead() * num("ahead_m", 5.0)
	cam.look_at(look, Vector3.UP)


## Where the camera wants to be: behind the target from his own end, up over his shoulder.
func _wanted() -> Transform3D:
	var at := target.global_position - _ahead() * num("back_m", 7.0) + Vector3.UP * num("up_m", 3.4)
	return Transform3D(Basis.looking_at((target.global_position + _ahead() * num("ahead_m", 5.0)) - at, Vector3.UP), at)


## The way the target fights: from his side's end toward the other end, along the deck.
func _ahead() -> Vector3:
	var e := mode.rules.end_of(target) if mode.rules != null else 0
	return mode.ring.axis() * (1.0 if e == 0 else -1.0) if mode.ring != null else Vector3.FORWARD


## The fighter `step` places after the one watched among those still in play, your side first ([] none: null).
func _pick(step: int) -> Node3D:
	var all: Array = []
	if mode.rules == null:
		return null
	var mine := clampi(mode.rules.team_of(mode.player), 0, 1)
	for t: int in [mine, 1 - mine]:
		for b in mode.rules.sides[t]:
			if b != mode.player and mode.in_play(b):
				all.append(b)
	if all.is_empty():
		return null
	var i := all.find(target)
	return all[posmod(i + step, all.size())] if i >= 0 else all[0]


func _say() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := maxf(vp.y / 900.0, 0.5)
	var w := MatchSetup.screens().get("spectate", {}) as Dictionary
	if target == null:
		_line.text = String(w.get("none", "Out of lives"))
	else:
		var nm := RingMode.name_of(target)
		if nm == "":
			nm = MatchSetup.competitor(RingReplay._element_of(target))
		_line.text = String(w.get("line", "Out of lives  ·  watching %s  ·  Space: next")) % nm
	_line.add_theme_font_size_override(&"font_size", int(22.0 * s))
	_line.reset_size()
	_line.position = Vector2((vp.x - _line.size.x) * 0.5, vp.y - 150.0 * s)
