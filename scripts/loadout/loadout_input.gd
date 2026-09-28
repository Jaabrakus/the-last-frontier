class_name LoadoutInput
extends RefCounted
## Input actions the loadout needs, registered at runtime like InputSetup (which it calls first) and
## HorseInput, so scripts/core/input_setup.gd stays unchanged. Existing bindings win.
##
## weapon_1..3 already exist (InputSetup). The loadout adds the throwable categories and "hands free":
##   weapon_4  spears        weapon_5  tomahawks        weapon_6  atlatl
##   sling_all X: put every weapon on the body (hands free)
## The key rules (what a key does with a weapon already in hand) are data:
## data/loadout/loadout_items.json keys.rules (loadout_design.md 3.1).
## Keys already taken elsewhere and left alone: E interact, H horse whistle, O customize, F melee
## (planned), R reload, C / Ctrl crouch, F3-F12 debug.

const KEYS := {
	"weapon_4": [KEY_4],
	"weapon_5": [KEY_5],
	"weapon_6": [KEY_6],
	"sling_all": [KEY_X],
}

static var _done := false


static func ensure() -> void:
	InputSetup.ensure()
	if _done:
		return
	_done = true
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)


## Every physical key bound by more than one action (after ensure()): {keycode: [actions]}.
static func collisions() -> Dictionary:
	var by_key := {}
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k: int = (ev as InputEventKey).physical_keycode
				if k == KEY_NONE:
					k = (ev as InputEventKey).keycode
				if not by_key.has(k):
					by_key[k] = []
				by_key[k].append(String(action))
	var out := {}
	for k in by_key:
		if (by_key[k] as Array).size() > 1:
			out[k] = by_key[k]
	return out
