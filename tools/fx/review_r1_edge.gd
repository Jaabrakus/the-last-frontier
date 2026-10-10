extends SceneTree
## Review round 1 probe (read-only): SpellFx / SbFx edge paths the tests do not run.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_edge.gd
##   A  a handle released inside _process while a finished handler kills another: how often does the other say "finished"?
##   B  attach to a node taken out of the tree but not freed (a pooled bolt): does the effect keep stepping with errors?
##   C  the camera freed while SbFx.prewarm / SpellFx.prewarm awaits (a level left, a camera swapped)
## Read the log for "ERROR" / "SCRIPT ERROR" lines after each "== X" banner.

const BALL := "g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP"
const HIT := "g3/Content/VFX/Character/Fire/Fireball_Base_Impact01_FxP"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	var player := SpellFx.of(root)
	await process_frame

	print("== A double finished")
	var a: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0))
	var b: SpellFx.Handle = SpellFx.spawn(BALL, Vector3(2, 1, 0))
	var b_fin := [0]
	var a_fin := [0]
	a.finished.connect(func() -> void:
		a_fin[0] += 1
		b.kill())
	b.finished.connect(func() -> void: b_fin[0] += 1)
	var guard := 0
	while a.is_playing() and guard < 600:
		await process_frame
		guard += 1
	await process_frame
	print("  A finished %d time(s), B (killed by A's handler, same frame) finished %d time(s) [expect 1 and 1]" % [a_fin[0], b_fin[0]])

	print("== B attach, node removed from the tree but not freed")
	var holder := Node3D.new()
	root.add_child(holder)
	var h: SpellFx.Handle = SpellFx.spawn(BALL, holder, {"attach": true})
	await process_frame
	await process_frame
	root.remove_child(holder)
	for i in 5:
		await process_frame
	print("  after 5 frames out of the tree: playing %s (see ERROR lines above this line)" % h.is_playing())
	h.kill()
	holder.free()

	print("== C camera freed during prewarm")
	var cam2 := Camera3D.new()
	root.add_child(cam2)
	cam2.current = false
	await process_frame
	var ids := ["g3/Content/VFX/Character/Wind/WindMBlast_FX", "g3/Content/VFX/Character/Ice/Ice_Lance_Squib",
			"g3/Content/VFX/Character/Wind/WindProj_FX", "g3/Content/VFX/Character/Wind/TornadoNewSimple"]
	for id: String in ids:
		for fx in player._idle.get(id, []):
			if is_instance_valid(fx):
				fx.free()
		player._idle.erase(id)
	var done := [false]
	var runner := func() -> void:
		await SbFx.prewarm(cam2, func(_f: float) -> void: pass)
		done[0] = true
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	SbFx.allow_headless = true
	# prewarm the Sb list would be long; use SpellFx.prewarm directly with a short list, then the SbFx tail by hand
	var warm_done := [false]
	var r2 := func() -> void:
		await SpellFx.prewarm(ids, cam2, Callable(), 1)
		warm_done[0] = true
	r2.call()
	await process_frame
	cam2.free()
	var guard2 := 0
	while not warm_done[0] and guard2 < 300:
		await process_frame
		guard2 += 1
	print("  prewarm finished: %s after %d frames (cam freed after the first batch)" % [warm_done[0], guard2])
	SbFx.force_on = null
	SbFx.force_elements = {}
	SbFx.allow_headless = false
	quit(0)
