extends SceneTree
## LoadoutInput.ensure() registers weapon_4..6 and sling_all without touching input_setup.gd, keeps the
## existing actions, and no physical key ends up on two actions (with HorseInput and the throwable pickup
## key registered too, as in game).
##
##   Godot --headless --path . -s tests/loadout/test_loadout_input.gd      (run under a hard time limit)

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	HorseInput.ensure()
	LoadoutInput.ensure()
	LoadoutInput.ensure()   # idempotent
	for a in ["weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6", "sling_all", "interact", "whistle"]:
		_check(InputMap.has_action(a), "action %s registered" % a)
	_check(_key_of("weapon_4") == KEY_4 and _key_of("weapon_5") == KEY_5 and _key_of("weapon_6") == KEY_6, "weapon_4..6 on 4-6")
	_check(_key_of("sling_all") == KEY_X, "sling_all on X")
	var col := LoadoutInput.collisions()
	_check(col.is_empty(), "no key on two actions: %s" % [col])
	if _fails.is_empty():
		print("LOADOUT INPUT TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		quit(1)


func _key_of(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
