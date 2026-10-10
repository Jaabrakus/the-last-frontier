extends SceneTree
## Review round 1 probe (read-only): small hot-path costs in the Cascade runtime.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_hot.gd
##   has_effect()   a file-system stat on every call (SbFx._play, would_replace and ids() call it)
##   cold build     a new CascadeFx node for an effect when the pool has none (a 5th copy at once, or no prewarm)
##   idle player    SpellFx._process with nothing playing (it still runs every frame)
##   big step       one step(dt) after a stall (a window drag, a debugger pause): the particles it spawns at once

const IDS := [
	"g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP",
	"g3/Content/VFX/Character/Fire/Fireball_Base_Impact01_FxP",
	"g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor",
	"g3/Content/VFX/Character/Wind/TornadoNewSimple",
	"g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	var player := SpellFx.of(root)
	await process_frame
	print("REVIEW cascade hot paths")
	var N := 20000
	var t0 := Time.get_ticks_usec()
	for i in N:
		SpellFx.has_effect(IDS[0])
	print("  SpellFx.has_effect(): %.2f us/call (FileAccess.file_exists on res://, uncached)" % (float(Time.get_ticks_usec() - t0) / N))
	t0 = Time.get_ticks_usec()
	for i in N:
		SpellFx.spec(IDS[0])
	print("  SpellFx.spec() cached: %.2f us/call" % (float(Time.get_ticks_usec() - t0) / N))

	print("  cold builds (spec parse excluded: spec() warmed first):")
	for id: String in IDS:
		SpellFx.spec(id)
	CascadeMaterials.shared()
	for id: String in IDS:
		var ta := Time.get_ticks_usec()
		var fx := player._build(id)
		var tb := Time.get_ticks_usec()
		var fx2 := player._build(id)
		var tc := Time.get_ticks_usec()
		print("    %-40s first %.2f ms, second %.2f ms (%d emitters)" % [id.get_file(), (tb - ta) / 1000.0, (tc - tb) / 1000.0, fx.emitters.size()])
		fx.queue_free()
		fx2.queue_free()
	await process_frame

	# SpellFx._process with nothing playing
	player.set_process(true)
	var frames := 600
	t0 = Time.get_ticks_usec()
	for f in frames:
		player._process(1.0 / 60.0)
	print("  idle SpellFx._process: %.2f us/frame" % (float(Time.get_ticks_usec() - t0) / frames))

	# one big step
	for id: String in ["g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke", "g3/Content/VFX/Character/Wind/TornadoNewSimple",
			"g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP"]:
		var h := SpellFx.spawn(id, Vector3(0, 1, -3))
		for f in 30:
			await process_frame
		var before := h.particle_count()
		var tb := Time.get_ticks_usec()
		h.fx.step(0.016)
		var t_norm := (Time.get_ticks_usec() - tb) / 1000.0
		var parts_norm := h.particle_count()
		tb = Time.get_ticks_usec()
		h.fx.step(30.0)                         # (a 30 s stall)
		var t_big := (Time.get_ticks_usec() - tb) / 1000.0
		print("  %-36s particles %d -> %d (normal step %.2f ms) -> %d after a 30 s step (%.1f ms)" % [id.get_file(), before, parts_norm, t_norm, h.particle_count(), t_big])
		h.kill()
	quit(0)
