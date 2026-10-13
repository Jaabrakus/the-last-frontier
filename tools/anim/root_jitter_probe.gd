extends SceneTree
## Feet jitter probe (the animation quality pass, 2026-10-11): a practice ring, the player holding a direction while a cast
## roots him (earth's 2 by default), each physics frame printed: the lower body's state (LocoBrain), the cast's phase, rooted,
## his speed and the step of each ankle in his own frame. Headless:
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/anim/root_jitter_probe.gd -- [el=earth] [key=2]
##       [frames=90] [move=move_forward]
## Lines: JIT <frame> ...; JIT_SUMMARY {alternations, max_step_m}; ends ROOT JITTER DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var st: FxStage
var el := "earth"
var key := 2
var n_frames := 90
var move := &"move_forward"


func _initialize() -> void:
	var a := CaptureKit.args({"el": el, "key": str(key), "frames": str(n_frames), "move": String(move)})
	el = String(a.el)
	key = int(a.key)
	n_frames = int(a.frames)
	move = StringName(String(a.move))
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("ROOT JITTER FAILED (watchdog)")
		quit(2))
	st = FxStage.new(self)
	st.start(el)
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("ROOT JITTER FAILED: no fight")
		quit(1)
		return
	await st.reset()
	st.aiming = true
	var p := st.p
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = StringName("weapon_%d" % key)
		e.pressed = down
		Input.parse_input_event(e)
	await st.frames(3)
	p.controls.set_held(move, true)
	p.controls.set_held(&"aim", true)
	var prev := {}
	var steps: Array = []
	var alt := 0
	var maxs := 0.0
	for i in n_frames:
		await process_frame
		st.keep()
		if i == 40:
			p.controls.set_held(&"aim", false)
		var sk := p.skeleton
		var inv := p.global_transform.affine_inverse()
		var line := ""
		var big := 0.0
		for bn: String in ["l_ankle", "r_ankle"]:
			var bi := sk.find_bone(bn)
			var q := inv * (sk.global_transform * sk.get_bone_global_pose(bi).origin)
			var s := q.distance_to(prev[bn]) if prev.has(bn) else 0.0
			prev[bn] = q
			big = maxf(big, s)
			line += " %s %.3f" % [bn, s]
		steps.append(big)
		maxs = maxf(maxs, big)
		var c := st.sway
		print("JIT %d lower %s cast %s/%s rooted %s v %.2f%s" % [i, String(p.anim.loco.state) if p.anim != null else "-",
				c.pose.anim_name if c.pose != null else "-", c.pose.phase if c.pose != null else "-", c.rooted, p.horizontal_speed(), line])
	for i in range(2, steps.size()):
		if float(steps[i - 1]) > 2.5 * maxf(maxf(float(steps[i - 2]), float(steps[i])), 0.01) and float(steps[i - 1]) > 0.04:
			alt += 1
	p.controls.set_held(move, false)
	print("JIT_SUMMARY ", JSON.stringify({"spikes": alt, "max_step_m": snappedf(maxs, 0.001)}))
	print("ROOT JITTER DONE")
	quit(0)
