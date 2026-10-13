class_name WebMouse
## The mouse in the web build when the browser will not hold it (2026-10-13: the pointer lock refused in an embedded page,
## the app's own browser, maybe Reddit's frame: the camera never turned and every click went on asking for the lock).
## tools/web/shell.html keeps window.tidebreakMouse = {want, refused}: the game asked for the lock and the browser said no.
## Then the mouse is the game's all the same (free_look: FrontierPlayer turns by its moves and lets its clicks through, the
## casts take them: ignore_mouse_capture), the page hides the cursor over the game, and the cursor held against the left or
## right edge keeps turning (edge_turn: an unheld cursor stops at the screen's edge). Off the web: always false, 0.

## The turn at the edge (rad/s) and how near the edge it starts (of the width).
const EDGE_TURN := 2.2
const EDGE_SHARE := 0.03

static var _frame := -1
static var _free := false


static func free_look() -> bool:
	if not OS.has_feature("web"):
		return false
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_free = bool(JavaScriptBridge.eval(
				"!!(window.tidebreakMouse && window.tidebreakMouse.want && window.tidebreakMouse.refused)", true))
	return _free


## The yaw (rad/s, + left) from the cursor held at the edge of `vp` in free look; 0 otherwise.
static func edge_turn(vp: Viewport) -> float:
	if vp == null or not free_look():
		return 0.0
	var w := vp.get_visible_rect().size.x
	var x := vp.get_mouse_position().x
	if w <= 0.0:
		return 0.0
	if x <= w * EDGE_SHARE:
		return EDGE_TURN
	if x >= w * (1.0 - EDGE_SHARE):
		return -EDGE_TURN
	return 0.0
