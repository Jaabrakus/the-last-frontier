class_name HorseInput
extends RefCounted
## Input actions the horse needs, registered at runtime like InputSetup (which it calls
## first) so scripts/core/input_setup.gd stays unchanged. Existing bindings win.
##
## Riding uses the existing actions: move_forward / move_back (throttle / brake),
## move_left / move_right (steer), sprint (tap: spur one gait up; hold at gallop:
## sprint), walk (hold: walk), jump (jump at canter or faster, rear from a stand).

const KEYS := {
	"interact": [KEY_E],     # mount / dismount
	"whistle": [KEY_H],      # call the horse
}

static var _done := false


static func ensure() -> void:
	InputSetup.ensure()
	if _done:
		return
	_done = true
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
