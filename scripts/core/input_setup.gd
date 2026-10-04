class_name InputSetup
## Registers default bindings at startup so the project runs without touching
## the Input Map. Any action you define in Project Settings > Input Map is left alone.

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL, KEY_C],
	"walk": [KEY_ALT],       # the horse's walking gait (on foot: none, FrontierPlayer)
	"sprint": [KEY_SHIFT],
	"reload": [KEY_R],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],     # thrown weapons: spear
	"weapon_5": [KEY_5],     # tomahawk
	"weapon_6": [KEY_6],     # atlatl (the mouse wheel cycles all six)
	"eat": [KEY_V],          # the best food in the pack (SurvivalBridge)
	"sleep": [KEY_Z],        # sleep on the ground, or wake (SurvivalSleep)
	"cook": [KEY_F],         # cook the pack's raw food on a lit campfire (CampCooking)
	"grip": [KEY_G],         # hold to grip a rock face or a giant's fur (PlayerGrip)
	"drink": [KEY_U],        # hold: a pull from the rum, as long as it is held (Vices; G is the climbing grip)
	"smoke": [KEY_Y],        # hold: a draw on the clay pipe (Vices)
	"rts": [KEY_F1],         # command mode: the camera over the land, the household commanded (RtsMode)
	"anatomy": [KEY_N],      # the skeleton map under every body, on or off (Anatomy)
	"inspect": [KEY_M],      # a look inside the dead body in reach (InspectView; M closes it again)
	"household": [KEY_J],    # the household screen: your wife or husband, their tasks and stats (Household)
}
const MOUSE := {
	"fire": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
	"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
}
## Animation debug tools (AnimDebugOverlay, plan section 9). Function keys only: they cannot
## collide with the controls above (Shift sprint, Alt walk, Ctrl/C crouch, ...), Esc or the
## HUD's F3. The overlay ignores them outside debug builds.
const DEBUG_KEYS := {
	"anim_debug": [KEY_F4],
	"anim_freeze": [KEY_F5 | KEY_MASK_SHIFT],     # Shift: F5 is quick save (SaveGame)
	"anim_step": [KEY_F6],
	"anim_slowmo": [KEY_F7],
	"anim_options": [KEY_F8],
	"debug_hit_light": [KEY_F9 | KEY_MASK_SHIFT], # Shift: F9 is load (SaveGame)
	"debug_hit_heavy": [KEY_F10],
	"debug_death": [KEY_F11],
	"debug_respawn": [KEY_F12],
}

static var _done := false


static func ensure() -> void:
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
	for action in MOUSE:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button in MOUSE[action]:
			var m := InputEventMouseButton.new()
			m.button_index = button
			InputMap.action_add_event(action, m)
	for action in DEBUG_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEBUG_KEYS[action]:
			var d := InputEventKey.new()
			d.physical_keycode = key & KEY_CODE_MASK
			d.shift_pressed = (key & KEY_MASK_SHIFT) != 0
			InputMap.action_add_event(action, d)
