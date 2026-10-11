extends SceneTree
## Cheese hunt, lens "team": a calibration of snipe_driver.gd's aim (is its Lightning able to land at all?): Practice (1v1)
## against the "stand" dummy (it never moves nor guards), the same driver casting only Lightning at it for max_s seconds.
## Key and mouse actions only. Prints "LTCAL {released, hits, rate}".
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/team/lt_calib.gd -- [max_s=60]

const Snipe := preload("res://tools/ring/cheese/team/snipe_driver.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://cheese_lt_calib.cfg"

var a := {}
var mode: RingMode
var player: FrontierPlayer
var sim: Node
var hits := 0


func _initialize() -> void:
	a = CaptureKit.args({"max_s": "60", "dummy": "stand", "aim": "light"})
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("LTCAL WATCHDOG")
		quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = String(a.aim)
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.set_practice("earth", String(a.dummy))
	MatchSetup.element = "fire"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for f in 1800:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null:
			break
	if mode == null or mode.player == null:
		print("LTCAL FAILED: no ring")
		quit(1)
		return
	player = mode.player
	player.controls = PlayerControls.new(false)
	player.ignore_mouse_capture = true
	mode.rules.launched.connect(func(_b: Node3D, _v: Vector3, _hs: float, by: Node, tag: String) -> void:
		if by == player and tag.begins_with("fire_arc/lightning"):
			hits += 1)
	while mode.phase != "FIGHT":
		await physics_frame
	sim = Snipe.new()
	sim.call(&"setup", player, mode, "expert", 4242)
	sim.set(&"camera_aim", true)
	sim.set(&"way", "snipe_any")
	current_scene.add_child(sim)
	var t := 0.0
	while t < float(a.max_s):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	var rel: Array = sim.get(&"lt")
	var d := 0.0
	for r: Dictionary in rel:
		d += float(r.d)
	print("LTCAL " + JSON.stringify({"released": rel.size(), "hits": hits, "rate": snappedf(float(hits) / maxf(rel.size(), 1), 0.01),
			"mean_d": snappedf(d / maxf(rel.size(), 1), 0.1), "dummy": String(a.dummy), "aim": String(a.aim)}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	RingReplay.force = ""
	RingRules.rule_set_override = ""
	quit(0)
