class_name TandemKneelPose
extends Node
## The rising kneel from actor_b_kneel.glb: up on both knees, about to get up, the left hand
## in a fist low in front of the left knee and the right arm curled across the chest (no
## props), the head up. The loop plays on its own (15 s: three 5 s breaths, an inhale on each
## 5 s). flinch() plays the stamina flinch over it: the body drops and lurches forward over the
## knees, the left fist drops, the right arm squeezes in, then it recovers. The knees, shins and
## feet never move.
##
## The flinch starts and ends on the loop's first frame, so it cross-fades in fast and hands
## back to the loop from its start (no pop). Give it the AnimationPlayer of actor_b_kneel.glb;
## it builds its own AnimationTree over it:
##   output <- state  Transition: hold (the loop) / alternating flinch lanes for immediate repeat presses

const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")

signal flinched
## Emitted once after an accepted flinch completes; stopping a session cancels it.
signal flinch_finished
signal session_started
signal session_stopped

const LOOP := "actor_b-kneel-stick"
const FLINCH := "actor_b-kneel-stick-flinch"

@export var anim_player: AnimationPlayer
@export var library: StringName = &""
## The backward recoil answering the crawling lead's own backward flinch (tools/author_kneel_backward.gd).
@export var backward_clip: Animation
## Set false for a partner who enters only after accepting an invitation.
@export var auto_start := true
@export var flinch_fade_in := 0.05     ## s: short, so the hit reads at once
@export var stamina_max := 100.0
@export var flinch_cost := 5.0
@export var idle_regain := 3.0
@export var recovery_delay := 0.75
@export var flinch_fade_out := 0.25    ## s from the flinch's tail back into the loop

var stamina := 100.0
var _recovery_left := 0.0
var _flinch_lane := "flinch_b"
var tree: AnimationTree
var _state: AnimationNodeTransition
var _flinch_left := 0.0                ## s of the flinch still to play
var _flinch_len := 1.2
var _session_active := false
var _in_flinch := false                ## the tree is on the flinch (not yet fading back)


func _ready() -> void:
	stamina = stamina_max
	if anim_player != null:
		_build_tree()
		if auto_start:
			start_session()


func _process(delta: float) -> void:
	if not is_flinching():
		_recovery_left = maxf(_recovery_left - delta, 0.0)
		if _recovery_left <= 0.0:
			stamina = minf(stamina + idle_regain * delta, stamina_max)
	if not _session_active:
		return
	var was_flinching := _flinch_left > 0.0
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	if _in_flinch and _flinch_left <= flinch_fade_out:
		_in_flinch = false
		_play("hold", flinch_fade_out)            # the flinch's tail cross-fades into the loop's start
	if was_flinching and _flinch_left <= 0.0:
		flinch_finished.emit()


## Begin the kneeling pose; the caller owns visibility and partner availability.
func start_session() -> bool:
	if tree == null:
		return false
	if _session_active:
		return true
	_flinch_left = 0.0
	_in_flinch = false
	_session_active = true
	tree.active = true
	_play("hold", 0.0)
	tree.advance(0.0)
	set_process(true)
	session_started.emit()
	return true


## Stop the pose and clear a flinch so rejoining starts with the kneeling loop.
func stop_session() -> void:
	var was_active := _session_active
	_session_active = false
	_flinch_left = 0.0
	_in_flinch = false
	if tree != null:
		_play("hold", 0.0)
		tree.advance(0.0)
		tree.active = false
	if was_active:
		session_stopped.emit()


func is_session_active() -> bool:
	return _session_active


## Each press restarts a flinch through the other lane, even during a reaction.
## `fullness` is the flinch gauge: how full the flinch plays (1: as authored; see TandemClips.variant).
func flinch(fullness := 1.0) -> bool:
	if not _session_active or stamina < flinch_cost:
		return false
	stamina = maxf(stamina - flinch_cost, 0.0)
	_recovery_left = recovery_delay
	_flinch_lane = "flinch_b" if _flinch_lane == "flinch_a" else "flinch_a"
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node(_flinch_lane) as AnimationNodeAnimation
	var want := CLIPS.variant(anim_player, library, FLINCH, fullness)
	if node.animation != want:
		node.animation = want
	_play(_flinch_lane, flinch_fade_in)
	_in_flinch = true
	_flinch_left = _flinch_len
	flinched.emit()
	return true


## The upper body rocks back (the lead's own backward flinch, answered). `fullness` as flinch(). Costs a flinch.
func flinch_backward(fullness := 1.0) -> bool:
	if not _session_active or backward_clip == null or stamina < flinch_cost:
		return false
	stamina = maxf(stamina - flinch_cost, 0.0)
	_recovery_left = recovery_delay
	_flinch_lane = "back_b" if _flinch_lane == "back_a" else "back_a"
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node(_flinch_lane) as AnimationNodeAnimation
	var want := CLIPS.variant(anim_player, &"kneel_reactions", "backward", fullness)
	if node.animation != want:
		node.animation = want
	_play(_flinch_lane, flinch_fade_in)
	_in_flinch = true
	_flinch_left = backward_clip.length
	flinched.emit()
	return true


func is_flinching() -> bool:
	return _session_active and _flinch_left > 0.0


func _play(state: String, fade: float) -> void:
	if tree == null:
		return
	_state.xfade_time = fade
	tree.set("parameters/state/transition_request", state)


func _clip(anim: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = _qualified(anim)
	return n


func _build_tree() -> void:
	anim_player.get_animation(_qualified(LOOP)).loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(_qualified(FLINCH)).loop_mode = Animation.LOOP_NONE
	_flinch_len = anim_player.get_animation(_qualified(FLINCH)).length

	var bt := AnimationNodeBlendTree.new()
	_state = AnimationNodeTransition.new()
	for input in ["hold", "flinch_a", "flinch_b"]:
		_state.add_input(input)
	_state.set_input_reset(0, true)    # back from a flinch, the loop starts from its first frame
	_state.set_input_reset(2, true)
	_state.set_input_reset(1, true)    # each flinch plays from the top
	bt.add_node("hold", _clip(LOOP), Vector2(-300, -40))
	bt.add_node("flinch_a", _clip(FLINCH), Vector2(-300, 80))
	bt.add_node("flinch_b", _clip(FLINCH), Vector2(-300, 160))
	bt.add_node("state", _state, Vector2(-60, 20))
	bt.connect_node("state", 0, "hold")
	bt.connect_node("state", 1, "flinch_a")
	bt.connect_node("state", 2, "flinch_b")
	if backward_clip != null:
		var reactions := AnimationLibrary.new()
		reactions.add_animation("backward", backward_clip)
		if anim_player.has_animation_library("kneel_reactions"):
			anim_player.remove_animation_library("kneel_reactions")
		anim_player.add_animation_library("kneel_reactions", reactions)
		for lane: String in ["back_a", "back_b"]:
			var index := _state.get_input_count()
			_state.add_input(lane)
			_state.set_input_reset(index, true)
			bt.add_node(lane, _clip("kneel_reactions/backward"))
			bt.connect_node("state", index, lane)
	bt.connect_node("output", 0, "state")

	tree = AnimationTree.new()
	tree.name = "KneelPoseTree"
	tree.tree_root = bt
	add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	# The clips' tracks are relative to the player's root node (the glb scene's root).
	tree.root_node = tree.get_path_to(anim_player.get_node(anim_player.root_node))
	tree.active = false


func _qualified(clip: String) -> StringName:
	if clip.contains("/") or library == &"":
		return StringName(clip)
	return StringName(String(library) + "/" + clip)
