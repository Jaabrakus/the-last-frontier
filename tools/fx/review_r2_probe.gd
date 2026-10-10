extends SceneTree
## Review round 2 probe (read-only): edge paths of the Cascade runtime, SpellFx and the Spellbreak bridge that the tests do not
## walk. Prints "P<n> ..." lines; each states what was measured. Headless:
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r2_probe.gd
## (every element forced on for the bridge sections; nothing is written outside user://review_r2_*)

const LOOP := "g3/Content/VFX/Character/Wind/WindProj_FX"
const DASH := "g3/Content/VFX/Character/Dash/DashTrail_FX"
const LCHARGE := "g3/Content/VFX/Character/FX_LightningCharge"

var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	await _frames(2)
	await _p1_kill_all_twice()
	await _p2_stale_comp_vel()
	await _p4_glowball()
	await _p6_keep_restore()
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	await _p3_watch_twice()
	await _p5_dash_keys()
	print("P* done")
	quit(0)


# P1: SpellFx.kill_all() when one handle's finished handler kills another handle
func _p1_kill_all_twice() -> void:
	var p := SpellFx.of(stage)
	var a := SpellFx.spawn(LOOP, Vector3(0, 1, 0), {"scene": stage, "one_shot": false})
	var b := SpellFx.spawn(LOOP, Vector3(1, 1, 0), {"scene": stage, "one_shot": false})
	var n := {"a": 0, "b": 0}
	a.finished.connect(func() -> void:
		n.a += 1
		b.kill())
	b.finished.connect(func() -> void: n.b += 1)
	await _frames(3)
	p.kill_all()
	print("P1 kill_all with a's finished handler killing b: a.finished x%d, b.finished x%d (expected 1 and 1), playing %d" % [n.a, n.b, p.playing_count()])
	# the same through Handle.kill() twice and through the tick path
	var c := SpellFx.spawn(LOOP, Vector3(2, 1, 0), {"scene": stage, "one_shot": false})
	var k := [0]
	c.finished.connect(func() -> void: k[0] += 1)
	await _frames(2)
	c.kill()
	c.kill()
	p.kill_all()
	print("P1b kill(), kill(), kill_all() on one handle: finished x%d (expected 1)" % k[0])


# P2: a pooled effect replayed after a fast follow starts with the earlier play's comp_vel
func _inherit_speed(h: SpellFx.Handle) -> Array:
	var fastest := 0.0
	var n := 0
	for e in h.fx.emitters:
		if e.one("VelocityInheritParent") != null:
			for q in e.particles:
				fastest = maxf(fastest, e.world_vel(q).length())
				n += 1
	return [fastest, n]


func _p2_stale_comp_vel() -> void:
	var mover := Node3D.new()
	stage.add_child(mover)
	var h1 := SpellFx.spawn(DASH, mover, {"scene": stage, "one_shot": false})
	var fx1 := h1.fx
	for i in 40:
		mover.global_position += Vector3(0, 0, -20.0 / 60.0)
		await process_frame
	var cv1 := fx1.comp_vel
	h1.kill()
	CascadeFx.rng.seed = 11
	var h2 := SpellFx.spawn(DASH, Vector3(5, 1, 0), {"scene": stage, "one_shot": false})
	var pooled := h2.fx == fx1
	var before := h2.fx.comp_vel.length()
	await process_frame
	var a := _inherit_speed(h2)
	h2.kill()
	CascadeFx.rng.seed = 11
	var h3 := SpellFx.spawn(DASH, Vector3(5, 1, 0), {"scene": stage, "one_shot": false})
	h3.fx.comp_vel = Vector3.ZERO                   # (what a reset in activate() would give)
	await process_frame
	var b := _inherit_speed(h3)
	h3.kill()
	print("P2 DashTrail_FX followed at 20 m/s (comp_vel %.1f), killed, replayed at rest on the pooled node (reused %s): comp_vel before its first step %.1f" % [cv1.length(), str(pooled), before])
	print("P2b first frame of the replay, same dice: VelocityInheritParent particles %d, fastest %.2f m/s; with comp_vel reset to 0: %d, fastest %.2f m/s" % [a[1], a[0], b[1], b[0]])
	mover.queue_free()


# P4: FX_LightningCharge 'glowball' (duration 0, loops 0, one burst at 0): how many it spawns
func _p4_glowball() -> void:
	var h := SpellFx.spawn(LCHARGE, Vector3(0, 1, 0), {"scene": stage, "one_shot": false})
	if h == null:
		print("P4 FX_LightningCharge not imported")
		return
	var em: Object = null
	for e in h.fx.emitters:
		if String(e.s.name) == "glowball":
			em = e
	var spawned := 0
	var last := 0
	var peak := 0
	for i in 120:
		await process_frame
		var n: int = em.particles.size()
		peak = maxi(peak, n)
	var life := CascadeFx.s1(em.one("Lifetime").Lifetime, 0.0, 0.5)
	print("P4 glowball: duration %.2f loops %d bursts %s delay_first_only %s; lifetime %.2f s; 2 s after the start %d live, peak %d (a single burst of 1 would give 1)" % [
			float(em.s.duration), int(em.s.loops), str(em.s.bursts), str(em.s.delay_first_only), life, em.particles.size(), peak])
	h.kill()


# P6: CaptureKit.keep/restore with two overlapping runs
func _p6_keep_restore() -> void:
	const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
	var path := "user://review_r2_keep.cfg"
	var w := func(s: String) -> void:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(s)
		f.close()
	var r := func() -> String:
		return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<none>"
	w.call("O")
	CaptureKit.keep([path])            # run A starts
	w.call("O+A")                      # A marks a topic
	CaptureKit.keep([path])            # run B starts (A still running)
	w.call("O+B")                      # B marks
	CaptureKit.restore([path])         # A ends
	w.call("O+B2")                     # B marks again
	CaptureKit.restore([path])         # B ends
	var final: String = r.call()
	print("P6 two overlapping captures: file after both ended = %s (the original was O)" % final)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for s in [".audit_bak", ".audit_none"]:
		if FileAccess.file_exists(path + s):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + s))


# P3: SbFx.watch_landing called twice for one body
func _p3_watch_twice() -> void:
	var b := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	b.add_child(cs)
	stage.add_child(b)
	b.global_position = Vector3(0, 0, 0)
	Bending.of(b).element = "earth"
	await _frames(2)
	SbFx.watch_landing(b, "pillar/self", "air_trail", "land")
	SbFx.watch_landing(b, "pillar/self", "air_trail", "land")
	var n := 0
	for c in b.get_children():
		if c is SbFx.Watch:
			n += 1
	print("P3 watch_landing twice on one body: %d Watch nodes (each ends the air trail and plays the landing)" % n)
	SbFx.stop(b)
	b.queue_free()
	await _frames(2)


# P5: SbFx._dash_keys entries of bodies freed mid-dash
func _p5_dash_keys() -> void:
	var before := SbFx._dash_keys.size()
	for i in 5:
		var b := CharacterBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = CapsuleShape3D.new()
		b.add_child(cs)
		stage.add_child(b)
		Bending.of(b).element = "fire"
		await process_frame
		SbFx.dash_began(b, "fire_jets/jets", Vector3.FORWARD, {"tag": "fire_jets/jets"})
		await process_frame
		b.free()
	print("P5 dash_began then the body freed before dash_ended, x5: _dash_keys grew %d -> %d (never erased)" % [before, SbFx._dash_keys.size()])
