class_name PadInput
extends Node
## The game on a controller (the owner, 2026-10-15: "make it controller friendly as well add controller support"). The
## actions the keyboard and the mouse drive (InputSetup, SwayCaster.ensure_input) get a controller's buttons and sticks too
## (ensure: BUTTONS, AXES, next to the keys and the mouse, never in place of them), so every reader of them (PlayerControls,
## the Hotbar, RingMoves, SwayCaster, the menus' ui_ actions) plays on a pad as it is. What only a pad needs:
##   the device   active: the last input was a pad's (a button, a stick or a trigger past DEVICE_DEAD); a key, a click or a
##                mouse move gives it back to the keyboard. While it is, the game has the input as under a captured mouse
##                (the gates that ask for one: SwayCaster._quick_input_ok, ...), the aim help is Strong unless one was chosen
##                (MatchSetup.aim_help) and the words name the pad's buttons (KitWords.key: "LT", "RB"; a PlayStation pad's
##                own, "L2", "R1")
##   the look     the right stick turns the view (look: FrontierPlayer's physics frame): a curve for fine aim (LOOK_EXP),
##                LOOK_DEG a second at full lean times the player's pad_look (GameSettings controls.pad), slower over a body
##                the aim help takes (FRICTION); invert_y the mouse's
##   the menus    Start opens and closes the Esc menus; B goes back in them but never opens one (opens_menu); a pad's
##                direction or A on a menu with nothing focused focuses its first button (_focus_first: a menu shown
##                with the mouse in mind still answers the pad)
## The layout (Xbox's names; PlayStation's in brackets):
##   left stick move, L3 crouch (the ring's fast fall)      right stick look and aim
##   LT [L2] hold: aim the readied skill, let go to cast (the right button's)      RT [R2] the jab (the left button's)
##   LB [L1] guard (E)      RB [R1] the next skill (F: keys 1, 2 and 3)
##   A [Cross] jump      B [Circle] dash with the stick (Shift)      X [Square] key 1      Y [Triangle] key 2
##   D-pad up key 4, down key 5, left key 3, right the readied skill onto the jab (Q)      Start [Options] the menu (Esc)
##   in a practice View [Share] both back at their ends (R), R3 the dummy's way (B); in a lesson View skips it (Enter); after
##   a round A the next at once (Space); in a menu A presses, B goes back

## Buttons on the game's actions (JOY_BUTTON_*).
const BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"sprint": [JOY_BUTTON_B],
	"weapon_1": [JOY_BUTTON_X],
	"weapon_2": [JOY_BUTTON_Y],
	"weapon_3": [JOY_BUTTON_DPAD_LEFT],
	"weapon_4": [JOY_BUTTON_DPAD_UP],
	"weapon_5": [JOY_BUTTON_DPAD_DOWN],
	"bend_swap": [JOY_BUTTON_RIGHT_SHOULDER],
	"bend_guard": [JOY_BUTTON_LEFT_SHOULDER],
	"bend_quick_bind": [JOY_BUTTON_DPAD_RIGHT],
	"crouch": [JOY_BUTTON_LEFT_STICK],
	# (the practice: View puts both back at their ends (R), R3 steps the dummy's way (B); a lesson's skip (Enter) View too: the
	# lesson takes it first, RingLessons._input)
	"ring_reset": [JOY_BUTTON_BACK],
	"ring_dummy": [JOY_BUTTON_RIGHT_STICK],
	"lesson_skip": [JOY_BUTTON_BACK],
	# (the menus: Godot's own ui_accept and ui_cancel have no pad button (Enter, Space; Escape): A presses, B goes back, Start
	# opens and closes the Esc menus; the D-pad and the left stick move the focus as Godot's own ui_ directions already do)
	"ui_accept": [JOY_BUTTON_A],
	"ui_cancel": [JOY_BUTTON_START, JOY_BUTTON_B],
}
## Sticks and triggers on the game's actions ([JOY_AXIS_*, its sign]), with each action's dead zone.
const AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0], "fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
const DEAD := {"move": 0.2, "look": 0.12, "aim": 0.3, "fire": 0.3}
## A stick or trigger moved this far is the pad taking over.
const DEVICE_DEAD := 0.35
## The look: degrees a second at full lean (pad_look 1), the curve's power, the vertical's share, the turn over a target.
const LOOK_DEG := 200.0
const LOOK_EXP := 1.8
const LOOK_UP := 0.7
const FRICTION := 0.55

## The last input was a pad's (see the header).
static var active := false
## The pad last used ("xbox", "playstation", "nintendo": its buttons' names).
static var layout := "xbox"
static var _bound := false
static var _listener: Node


## The pad's buttons and sticks on the game's actions (BUTTONS, AXES), the actions made when missing. Safe to call again.
static func ensure() -> void:
	if _bound:
		return
	_bound = true
	InputSetup.ensure()                         # (their actions made with their keys first: InputSetup's, the guard's, Q,
	SwayCaster.ensure_input()                   # the practice's R and B, the lessons' Enter)
	RingPractice.ensure_keys()
	RingLessons._ensure_keys()
	for a: String in BUTTONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for b: int in BUTTONS[a]:
			var e := InputEventJoypadButton.new()
			e.device = -1                         # (every pad: InputMap's all devices)
			e.button_index = b as JoyButton
			if not InputMap.action_has_event(a, e):
				InputMap.action_add_event(a, e)
	for a: String in AXES:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var dz := float(DEAD.get(a.get_slice("_", 0), 0.3))
		InputMap.action_set_deadzone(a, dz)
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = int(AXES[a][0]) as JoyAxis
		m.axis_value = float(AXES[a][1])
		if not InputMap.action_has_event(a, m):
			InputMap.action_add_event(a, m)


## The listener (a node of the tree's root, through pauses: it hears every input first) made once on `tree`, and the
## bindings. Safe to call again.
static func install(tree: SceneTree) -> void:
	ensure()
	if tree == null or tree.root == null or (_listener != null and is_instance_valid(_listener)):
		return
	_listener = PadInput.new()
	_listener.name = "PadInput"
	_listener.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_listener)


func _input(event: InputEvent) -> void:
	note(event)
	if from_pad(event) and event.is_pressed() and _menu_up() and get_viewport().gui_get_focus_owner() == null:
		for a: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"]:
			if event.is_action_pressed(a) and _focus_first(get_tree().root):
				get_viewport().set_input_as_handled()
				return


## Whether a menu has the screen (no one playing: the game paused, or no player in the scene: the main menu's).
func _menu_up() -> bool:
	var tree := get_tree()
	if tree.paused:
		return true
	return tree.current_scene != null and tree.get_first_node_in_group(&"player") == null


## The first button shown under `n` focused (true), none found (false).
static func _focus_first(n: Node) -> bool:
	for ch in n.get_children():
		var b := ch as BaseButton
		if b != null and b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE and not b.disabled:
			b.grab_focus()
			return true
		if (ch is CanvasItem and not (ch as CanvasItem).visible) or (ch is CanvasLayer and not (ch as CanvasLayer).visible):
			continue
		if _focus_first(ch):
			return true
	return false


## The device an input event says is in use (see the header's device).
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_use_pad(event.device)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > DEVICE_DEAD:
			_use_pad(event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			active = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 4.0:
			active = false


static func _use_pad(device: int) -> void:
	active = true
	var nm := Input.get_joy_name(device).to_lower() if device >= 0 else ""
	if nm.contains("playstation") or nm.contains("dualsense") or nm.contains("dualshock") or nm.contains("ps4") \
			or nm.contains("ps5") or nm.contains("sony"):
		layout = "playstation"
	elif nm.contains("nintendo") or nm.contains("switch") or nm.contains("pro controller") or nm.contains("joy-con"):
		layout = "nintendo"
	elif nm != "":
		layout = "xbox"


# ---------------------------------------------------------------- the words
const NAMES := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
			JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "View",
			JOY_BUTTON_START: "Start", "lt": "LT", "rt": "RT"},
	"playstation": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
			JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3",
			JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options", "lt": "L2", "rt": "R2"},
	"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L",
			JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "-",
			JOY_BUTTON_START: "+", "lt": "ZL", "rt": "ZR"},
}
const DPAD := {JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
		JOY_BUTTON_DPAD_RIGHT: "D-pad right"}


## Action `a`'s pad button as the player sees it on the pad in use ("LT", "R1", "D-pad up"; "" none).
static func button_name(a: StringName) -> String:
	ensure()
	if not InputMap.has_action(a):
		return ""
	var names: Dictionary = NAMES.get(layout, NAMES.xbox)
	for e in InputMap.action_get_events(a):
		if e is InputEventJoypadButton:
			var b := int((e as InputEventJoypadButton).button_index)
			if DPAD.has(b):
				return String(DPAD[b])
			if names.has(b):
				return String(names[b])
		elif e is InputEventJoypadMotion:
			match int((e as InputEventJoypadMotion).axis):
				JOY_AXIS_TRIGGER_LEFT:
					return String(names.lt)
				JOY_AXIS_TRIGGER_RIGHT:
					return String(names.rt)
				JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
					return "left stick"
				JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
					return "right stick"
	return ""


## Whether `event` may open an Esc menu (the keyboard's Esc, the pad's Start; never the pad's B, which only goes back).
static func opens_menu(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	return true


## Whether `event` is the keyboard's (or the mouse's) way out, not a pad's (the player's Esc frees the mouse; B never does).
static func from_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


# ---------------------------------------------------------------- the look
## The right stick's turn of player `p` this physics frame (`dt`; see the header's look). Nothing while the keyboard and the
## mouse play, nor for a player whose controls are not this machine's.
static func look(p: FrontierPlayer, dt: float) -> void:
	if not active or p == null or p.controls == null or not p.controls.from_input or p.camera == null:
		return
	var v := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", float(DEAD.look))
	if v == Vector2.ZERO:
		return
	v = v.normalized() * pow(minf(v.length(), 1.0), LOOK_EXP)
	var k := deg_to_rad(LOOK_DEG) * p.pad_look * dt * (p.camera.fov / maxf(p.fov, 1.0))
	if _over_target(p):
		k *= FRICTION
	p.yaw -= v.x * k
	p.pitch -= v.y * k * LOOK_UP * (-1.0 if p.invert_y else 1.0)
	p.pitch = clampf(p.pitch, -deg_to_rad(p.pitch_limit_deg), deg_to_rad(p.pitch_limit_deg))
	if p.ring_moves != null:
		p.ring_moves.note_mouse()               # (the ring's recovery turn stops for his own stick, as for his mouse)


## Whether the aim help takes a body under the crosshair now (the look slows over it).
static func _over_target(p: FrontierPlayer) -> bool:
	var bc := BendCaster.of(p) as PlayerBendCaster
	return bc != null and bc.aim_target() != null
