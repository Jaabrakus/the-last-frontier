class_name WebMouse
## The mouse in the web build on a page that cannot lock it (2026-10-13: the pointer lock refused in an embedded page, the
## app's own browser, maybe Reddit's frame). tools/web/shell.html stands in for the lock there (Input.mouse_mode reads
## CAPTURED while the game wants the mouse, so it plays as under a lock), but an unheld cursor stops at the screen's edge:
## held there, the page says so (window.tidebreakMouse.edge: -1 left, 1 right) and the view keeps turning (edge_turn).
## Off the web, or under a real lock: 0.

## The turn while the cursor is held at an edge (rad/s).
const EDGE_TURN := 2.2

static var _frame := -1
static var _edge := 0


## The yaw (rad/s, + left) the cursor held at the left or right edge asks for.
static func edge_turn() -> float:
	if not OS.has_feature("web"):
		return 0.0
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_edge = int(JavaScriptBridge.eval("window.tidebreakMouse ? window.tidebreakMouse.edge : 0", true))
	return -_edge * EDGE_TURN
