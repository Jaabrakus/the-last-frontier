extends SceneTree
## A life alone (user 2026-10-01: "in the startup char creation have spouse on or off"): spouse=off starts with no wife or husband,
## the household stands without one, and its save says so (a load must not make one).
##   Godot --headless --path . -s tests/survival_game/test_no_spouse.gd -- survival=on spouse=off
var fails := 0

func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 400:
		await physics_frame
	var h := Household.find(self)
	_c(h != null, "the household stands")
	if h:
		_c(h.sc == null and h.body == null and h.workers().is_empty(), "no spouse, no body, no workers")
		_c(bool(h.save_data().get("no_spouse", false)), "the save says a life alone")
		h.load_data({"no_spouse": true})
		_c(h.sc == null, "a load of it makes none")
	print("NO SPOUSE TEST ", "FAILED" if fails > 0 else "PASSED")
	quit(1 if fails > 0 else 0)

func _c(ok: bool, what: String) -> void:
	print("  ", "ok  " if ok else "FAIL", " ", what)
	if not ok:
		fails += 1
