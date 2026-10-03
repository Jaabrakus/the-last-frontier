class_name CursorHold
extends Node
## Hold for a free cursor in play (the owner 2026-10-03: the classic HUD's micro menu, the bags, the tooltips, the chat's
## scroll and the map's zoom want a cursor without leaving the game): while ACTION is held the mouse is shown and free (it
## starts at the crosshair), the camera does not turn, the crosshair hides (FrontierHUD._draw_overlay) and a click or the
## wheel off the HUD does nothing (no shot, no hotbar step, no capture: only the HUD's buttons take them); let go, the mouse
## is captured again. ACTION ("free_cursor") is rebindable: ensure_input() puts it on KEY (the backquote, `) only when the
## action is missing. Nothing when a screen already has the mouse (Esc, Tab, a talk, the command mode, the game paused) or
## the player is dead; a screen opened from the HUD while it is held keeps the mouse when the key is let go.
##   CursorHold.install(hud)   FrontierHUD._ready (the player's HUD); CursorHold.of(hud)
##   held                      the cursor is free by the hold now
##   key_label()               the key's name for the help ("`")

const ACTION := &"free_cursor"
const KEY := KEY_QUOTELEFT
const NODE_NAME := "CursorHold"

var player: FrontierPlayer
var held := false
var _captured := false            ## the mouse was captured when the hold freed it (only then is it captured again)


static func install(hud: FrontierHUD) -> CursorHold:
	var have := of(hud)
	if have != null:
		return have
	ensure_input()
	var h := CursorHold.new()
	h.name = NODE_NAME
	h.player = hud.player
	h.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.add_child(h)
	return h


static func of(hud: Node) -> CursorHold:
	return hud.get_node_or_null(NODE_NAME) as CursorHold if hud != null else null


## ACTION on KEY, made when missing (the player may rebind it). Safe to call again.
static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


## The bound key's name ("`"; "?" unbound).
static func key_label() -> String:
	if not InputMap.has_action(ACTION):
		return "?"
	for e in InputMap.action_get_events(ACTION):
		if e is InputEventKey:
			var k := (e as InputEventKey).physical_keycode
			if k == KEY_NONE:
				k = (e as InputEventKey).keycode
			return "`" if k == KEY_QUOTELEFT else OS.get_keycode_string(k)
		if e is InputEventMouseButton:
			return "Mouse %d" % (e as InputEventMouseButton).button_index
	return "?"


## The game view has the mouse (no screen over it): the hold may free it, letting go may take it back.
func _game_has_mouse() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree() or player.is_dead:
		return false
	var tree := get_tree()
	if tree.paused or StoryDialogue.is_open(tree):
		return false
	return not (player.rts != null and is_instance_valid(player.rts) and player.rts.active)


func _process(_delta: float) -> void:
	var down := InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)
	var game := _game_has_mouse()
	if held:
		if down and game:
			if _captured and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # (a screen opened from the HUD closed under the hold: free again)
			return
		# let go: the mouse captured again; a screen come up over the game (the command mode): it has the mouse now
		held = false
		if not down and game and _captured and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured = false
		return
	if not down or not game or not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture):
		return
	held = true
	_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var vp := get_viewport()
		vp.warp_mouse(vp.get_visible_rect().size * 0.5)           # (from the crosshair)


## While held, the mouse off the HUD goes nowhere: its motion does not turn the camera, a click does not capture it again
## (FrontierPlayer._unhandled_input) or fire, the wheel does not step the hotbar. (This node is the HUD's, under the
## player: it sees the unhandled input before the player does.)
func _unhandled_input(event: InputEvent) -> void:
	if held and swallows(event) and _game_has_mouse():
		get_viewport().set_input_as_handled()


func swallows(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventMouseButton
