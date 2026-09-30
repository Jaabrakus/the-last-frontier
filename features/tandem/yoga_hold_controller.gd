class_name TandemYogaHoldController
extends Node
## Hold-to-stay yoga pose with stamina, for the Actor_B happy baby clips
## (yoga/actor_b_yoga.glb: actor_b-yoga-happy-baby-enter / -hold / -hold-tremor /
## -flinch / -exit / -collapse).
##
## Hold the input action to go into the pose and stay there. Holding drains stamina:
## below tremor_from the pose starts to shake (the hold loop blends toward the tremor
## loop, which runs on the same timeline), below flinch_below it flinches at shrinking
## intervals (each flinch costs a little stamina), and at zero it collapses; the player
## then has to rest until stamina is back to reenter_at. Releasing the button exits the
## pose, and stamina refills while resting.
##
## Add it as a child of the character and point animation_player at the AnimationPlayer
## that holds the clips. It builds its own AnimationTree (as its child) on that player.
## Stamina drains only while the pose is held (not during the 4 s entry). After a
## collapse the button has to be released and pressed again.
##
## Co-op / networked play: call set_held() to drive the button from the game instead of
## the input action (use_input() switches back), and seek_hold() to put the hold loop on a
## shared clock. The hold loop is two 4 s breaths (HOLD_BREATH_SECONDS); its pose at 0 s
## and 4 s is the same, so starting a hold on either avoids a jump after -enter.

const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")

signal state_changed(state: State)
signal flinched
signal collapsed

enum State { REST, ENTER, HOLD, EXIT, COLLAPSE, EXHAUSTED }

@export var animation_player: AnimationPlayer
@export var hold_action: StringName = &"tandem_yoga_hold"
## AnimationLibrary that holds the clips ("" = the default library).
@export var library: StringName = &""
@export var clip_prefix := "actor_b-yoga-happy-baby"
## Seconds of holding from full stamina (at drain_per_sec = 1).
@export var max_stamina := 10.0
@export var drain_per_sec := 1.0
@export var regen_per_sec := 1.5
## Stamina fraction where the shaking starts; it reaches full at zero stamina.
@export_range(0.0, 1.0) var tremor_from := 0.6
## Stamina fraction below which the pose flinches (the first one comes 0.6-1.5 s after).
@export_range(0.0, 1.0) var flinch_below := 0.45
## Stamina lost per flinch.
@export var flinch_cost := 0.3
## Seconds between flinches just below flinch_below, and near zero stamina.
@export var flinch_gap_max := 2.5
@export var flinch_gap_min := 0.6
## Stamina fraction needed to go back into the pose after a collapse.
@export_range(0.0, 1.0) var reenter_at := 0.3

var state := State.REST
var stamina := 0.0
var tree: AnimationTree

var _time := 0.0
var _flinch_in := 0.0
var _tremor := 0.0
var _len := {}
var _need_release := false
var _use_external := false
var _external_held := false

const HOLD_BREATH_SECONDS := 4.0

const _INPUT := {
	State.REST: "rest", State.ENTER: "enter", State.HOLD: "hold",
	State.EXIT: "exit", State.COLLAPSE: "collapse",
}


func _ready() -> void:
	stamina = max_stamina
	for part in ["enter", "hold", "hold-tremor", "flinch", "exit", "collapse"]:
		var anim := animation_player.get_animation(_clip(part))
		assert(anim != null, "missing clip " + _clip(part))
		_len[part] = anim.length
		anim.loop_mode = Animation.LOOP_LINEAR if part.begins_with("hold") else Animation.LOOP_NONE
	tree = AnimationTree.new()
	tree.name = "YogaHoldTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	# track paths resolve from the same root node the AnimationPlayer uses
	tree.root_node = tree.get_path_to(animation_player.get_node(animation_player.root_node))
	tree.tree_root = _build_tree()
	tree.active = true
	tree.set("parameters/rest_freeze/scale", 0.0)      # rest = the first frame of -enter
	_go(State.REST)


func _process(delta: float) -> void:
	var held := _external_held if _use_external else Input.is_action_pressed(hold_action)
	if not held:
		_need_release = false
	_time += delta
	match state:
		State.REST:
			_regen(delta)
			if held and not _need_release and stamina > 0.0:
				_go(State.ENTER)
		State.EXHAUSTED:
			_regen(delta)
			if stamina >= reenter_at * max_stamina:
				_go(State.REST)
		State.ENTER:
			if _time >= _len["enter"]:
				_go(State.HOLD if held else State.EXIT)
		State.HOLD:
			_drain(delta)
			if stamina <= 0.0:
				_go(State.COLLAPSE)
			elif not held:
				_go(State.EXIT)
			else:
				_update_flinch(delta)
		State.EXIT:
			_regen(delta)
			if _time >= _len["exit"]:
				_go(State.REST)
		State.COLLAPSE:
			if _time >= _len["collapse"]:
				_go(State.EXHAUSTED)
	_update_tremor(delta)


func stamina_fraction() -> float:
	return stamina / max_stamina


## Drive the hold button from the game (e.g. a remote player's state) instead of input.
func set_held(on: bool) -> void:
	_use_external = true
	_external_held = on


## Go back to reading hold_action from Input.
func use_input() -> void:
	_use_external = false


## Put the hold loop (and the tremor loop, which is synced to it) at t seconds, wrapped
## to the loop. Safe to call every frame from a shared clock, or once per breath.
func seek_hold(t: float) -> void:
	tree.set("parameters/hold_seek/seek_request", fposmod(t, _len["hold"]))


func hold_length() -> float:
	return _len["hold"]


func _go(new_state: State) -> void:
	state = new_state
	_time = 0.0
	if _INPUT.has(new_state):                          # EXHAUSTED stays on the collapse's last frame
		tree.set("parameters/state/transition_request", _INPUT[new_state])
	if new_state == State.HOLD:
		_flinch_in = _next_flinch_gap()
	if new_state == State.COLLAPSE:
		_need_release = true
		collapsed.emit()
	state_changed.emit(new_state)


func _drain(delta: float) -> void:
	stamina = maxf(stamina - drain_per_sec * delta, 0.0)


func _regen(delta: float) -> void:
	stamina = minf(stamina + regen_per_sec * delta, max_stamina)


func _update_tremor(delta: float) -> void:
	var target := 0.0
	if state == State.HOLD and tremor_from > 0.0:
		target = clampf((tremor_from - stamina_fraction()) / tremor_from, 0.0, 1.0)
	_tremor = move_toward(_tremor, target, delta * 0.8)     # ease in and out of the shaking
	tree.set("parameters/fatigue/blend_amount", _tremor * _tremor * (3.0 - 2.0 * _tremor))


func _update_flinch(delta: float) -> void:
	if stamina_fraction() >= flinch_below:
		_flinch_in = randf_range(0.6, 1.5)                  # the first flinch comes soon
		return
	_flinch_in -= delta
	if _flinch_in <= 0.0 and not tree.get("parameters/flinch_shot/active"):
		_set_fullness(1.0)
		tree.set("parameters/flinch_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		stamina = maxf(stamina - flinch_cost, 0.0)
		flinched.emit()
		_flinch_in = _next_flinch_gap()


## A flinch on demand (a partner's dip coming down on her): the flinch plays over the hold and costs `cost` of
## the pool (0: free). False when she is not holding the pose or is already flinching.
func flinch(cost := flinch_cost, fullness := 1.0) -> bool:
	if state != State.HOLD or bool(tree.get("parameters/flinch_shot/active")):
		return false
	_set_fullness(fullness)
	tree.set("parameters/flinch_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	stamina = maxf(stamina - cost, 0.0)
	flinched.emit()
	return true


## Keep paired reactions in the torso while the held lower-body pose stays intact.
func set_torso_flinch(sk: Skeleton3D, enabled: bool) -> void:
	var shot := (tree.tree_root as AnimationNodeBlendTree).get_node("flinch_shot") as AnimationNodeOneShot
	if enabled:
		var torso := sk.find_bone("upper_base")
		assert(torso >= 0, "Happy Baby torso bone missing")
		var bones: Array[int] = [torso]
		var names: Array[StringName] = []
		while not bones.is_empty():
			var bone: int = bones.pop_back()
			names.append(sk.get_bone_name(bone))
			bones.append_array(sk.get_bone_children(bone))
		var clip := animation_player.get_animation(_clip("flinch"))
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			shot.set_filter_path(path, path.get_subname_count() > 0 and StringName(path.get_subname(0)) in names)
	shot.filter_enabled = enabled


## The flinch clip at this fullness (the flinch gauge: 1 as authored, see TandemClips.variant); only between flinches.
func _set_fullness(fullness: float) -> void:
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node("flinch") as AnimationNodeAnimation
	var want := CLIPS.variant(animation_player, library, clip_prefix + "-flinch", fullness)
	if node.animation != want:
		node.animation = want


func _next_flinch_gap() -> float:
	var k := clampf(stamina_fraction() / maxf(flinch_below, 0.001), 0.0, 1.0)
	return lerpf(flinch_gap_min, flinch_gap_max, k) + randf_range(-0.3, 0.3)


func _clip(part: String) -> StringName:
	var name := clip_prefix + "-" + part
	return StringName(name if library == &"" else String(library) + "/" + name)


func _anim(part: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = _clip(part)
	return node


func _build_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	# rest: -enter frozen on its first frame (lying flat, same as the end of -exit / -collapse)
	bt.add_node("rest", _anim("enter"))
	bt.add_node("rest_freeze", AnimationNodeTimeScale.new())
	bt.connect_node("rest_freeze", 0, "rest")
	bt.add_node("enter", _anim("enter"))
	# hold: the hold loop blended toward the tremor loop by fatigue, in sync
	bt.add_node("hold", _anim("hold"))
	bt.add_node("tremor", _anim("hold-tremor"))
	var fatigue := AnimationNodeBlend2.new()
	fatigue.sync = true
	bt.add_node("fatigue", fatigue)
	bt.connect_node("fatigue", 0, "hold")
	bt.connect_node("fatigue", 1, "tremor")
	# seek_hold() moves both loops through here
	bt.add_node("hold_seek", AnimationNodeTimeSeek.new())
	bt.connect_node("hold_seek", 0, "fatigue")
	# flinch: a one-shot over the hold
	bt.add_node("flinch", _anim("flinch"))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.3
	bt.add_node("flinch_shot", shot)
	bt.connect_node("flinch_shot", 0, "hold_seek")
	bt.connect_node("flinch_shot", 1, "flinch")
	bt.add_node("exit", _anim("exit"))
	bt.add_node("collapse", _anim("collapse"))
	var states := AnimationNodeTransition.new()
	states.xfade_time = 0.15
	for input in ["rest", "enter", "hold", "exit", "collapse"]:
		states.add_input(input)
	bt.add_node("state", states)
	bt.connect_node("state", 0, "rest_freeze")
	bt.connect_node("state", 1, "enter")
	bt.connect_node("state", 2, "flinch_shot")
	bt.connect_node("state", 3, "exit")
	bt.connect_node("state", 4, "collapse")
	bt.connect_node("output", 0, "state")
	return bt
