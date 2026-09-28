class_name TandemPlankDipController
extends Node
## Button-triggered hip drop in a plank, for the Actor_B plank clips (yoga/actor_b_yoga.glb:
## actor_b-yoga-plank-hold or -flow, a loop, and actor_b-yoga-plank-dip, a one-shot).
##
## The character holds the plank; pressing the input action drops the hips: the dip plays as
## a OneShot over the hold loop, like a flinch. The dip starts and ends on the hold's first
## frame, so short fades are enough. A press while a dip is playing is kept if it comes in the
## last buffer_time seconds and fires the next dip as soon as this one ends; earlier presses
## are ignored (restarting mid-dip would snap the hips back up).
##
## Add it as a child of the character and point animation_player at the AnimationPlayer
## that holds the clips. It builds its own AnimationTree (as its child) on that player.
## Set auto_start to false for a partner session, then call start_session() when the
## player joins and stop_session() when they leave. The caller owns body visibility.

signal dipped
signal session_started
signal session_stopped

@export var animation_player: AnimationPlayer
@export var dip_action: StringName = &"tandem_plank_dip"
## Disable when the game routes input through request_dip(), such as a join/dip action.
@export var read_input := true
## Keep standalone plank use active by default; partner flows can opt in explicitly.
@export var auto_start := true
## AnimationLibrary that holds the clips ("" = the default library).
@export var library: StringName = &""
@export var clip_prefix := "actor_b-yoga-plank"
## The looping pose clip suffix; use "flow" for the authored continuous plank flow.
@export var base_clip: StringName = &"hold"
@export var fade_in := 0.05
@export var fade_out := 0.2
## A press this close to the end of a dip queues the next one.
@export var buffer_time := 0.25

var tree: AnimationTree

var _dip_len := 0.0
var _dip_left := 0.0                     # seconds of the playing dip still to go
var _queued := false
var _session_active := false


func _ready() -> void:
	var hold := animation_player.get_animation(_clip(String(base_clip)))
	var dip := animation_player.get_animation(_clip("dip"))
	assert(hold != null and dip != null, "missing %s-%s / -dip" % [clip_prefix, base_clip])
	hold.loop_mode = Animation.LOOP_LINEAR
	dip.loop_mode = Animation.LOOP_NONE
	_dip_len = dip.length
	tree = AnimationTree.new()
	tree.name = "PlankDipTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	# track paths resolve from the same root node the AnimationPlayer uses
	tree.root_node = tree.get_path_to(animation_player.get_node(animation_player.root_node))
	tree.tree_root = _build_tree()
	tree.active = false
	set_process(false)
	if auto_start:
		start_session()


func _process(delta: float) -> void:
	if not _session_active:
		return
	_dip_left = maxf(_dip_left - delta, 0.0)
	if read_input and Input.is_action_just_pressed(dip_action):
		request_dip()
	if _queued and not is_dipping():
		_queued = false
		_fire()


## Begin the player's plank flow. Availability of a partner is checked by the caller.
func start_session() -> bool:
	if tree == null:
		return false
	if _session_active:
		return true
	_queued = false
	_dip_left = 0.0
	_session_active = true
	tree.active = true
	# Consume the abort immediately so a previous dip cannot resume on rejoining.
	tree.set("parameters/dip_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.advance(0.0)
	set_process(true)
	session_started.emit()
	return true


## End the flow, including any active or buffered dip, without changing body visibility.
func stop_session() -> void:
	var was_active := _session_active
	_session_active = false
	_queued = false
	_dip_left = 0.0
	set_process(false)
	if tree != null:
		tree.set("parameters/dip_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.advance(0.0)
		tree.active = false
	if was_active:
		session_stopped.emit()


func is_session_active() -> bool:
	return _session_active


## Drop the hips now, or queue it if a dip is ending. Returns true if it fired at once.
func request_dip() -> bool:
	if not _session_active:
		return false
	if not is_dipping():
		_fire()
		return true
	if _dip_left <= buffer_time:
		_queued = true
	return false


func is_dipping() -> bool:
	return _session_active and bool(tree.get("parameters/dip_shot/active"))


func _fire() -> void:
	tree.set("parameters/dip_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_dip_left = _dip_len
	dipped.emit()


func _clip(part: String) -> StringName:
	var name := clip_prefix + "-" + part
	return StringName(name if library == &"" else String(library) + "/" + name)


func _anim(part: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = _clip(part)
	return node


func _build_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("hold", _anim(String(base_clip)))
	bt.add_node("dip", _anim("dip"))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	bt.add_node("dip_shot", shot)
	bt.connect_node("dip_shot", 0, "hold")
	bt.connect_node("dip_shot", 1, "dip")
	bt.connect_node("output", 0, "dip_shot")
	return bt
