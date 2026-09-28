class_name PlayerControls
extends RefCounted
## Where a player's controls come from (user 2026-09-27, a second player driven by an AI to try duels, and later by the
## network): by default this machine's keyboard and mouse (Input), as ever; `from_input` false, whatever drives the
## player (an AI: MeleeDuelAI; the network, later) holds and lets go of the same actions (set_held). A player
## (FrontierPlayer.controls) and what reads its keys (GatherTools, AxeMelee, PlayerGrip) ask it, not Input.
## A press set from a physics frame's start (a node with an earlier physics priority, or a script resumed on
## SceneTree.physics_frame) is just_pressed through that frame.

## True: the keyboard and mouse. False: set_held drives it.
var from_input := true
var _held := {}            ## action -> true, held now
var _down_at := {}         ## action -> the physics frame it went down


func _init(keyboard := true) -> void:
	from_input = keyboard


func pressed(action: StringName) -> bool:
	if from_input:
		return InputMap.has_action(action) and Input.is_action_pressed(action)
	return _held.has(action)


func just_pressed(action: StringName) -> bool:
	if from_input:
		return InputMap.has_action(action) and Input.is_action_just_pressed(action)
	return _held.has(action) and int(_down_at.get(action, -1)) == Engine.get_physics_frames()


## The move keys as one vector (x right, y back: Input.get_vector's).
func move_vector() -> Vector2:
	if from_input:
		return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var v := Vector2(float(pressed(&"move_right")) - float(pressed(&"move_left")),
			float(pressed(&"move_back")) - float(pressed(&"move_forward")))
	return v.limit_length(1.0)


## Driven by something else: `action` held from now (pressed this physics frame) or let go.
func set_held(action: StringName, on: bool) -> void:
	if on and not _held.has(action):
		_held[action] = true
		_down_at[action] = Engine.get_physics_frames()
	elif not on:
		_held.erase(action)


## Everything let go.
func release_all() -> void:
	_held.clear()
