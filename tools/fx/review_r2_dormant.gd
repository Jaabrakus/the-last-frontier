extends SceneTree
## Review round 2 probe (read-only): what each SbFx entry point costs per call with every element off (config.json as shipped),
## measured on the windowed path (allow_headless: on() goes through the master switch and the element table, not the
## headless shortcut) and on the headless one, and how many calls per frame the scripts make (none: every call site is per event).
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r2_dormant.gd

const N := 200000


func _bench(label: String, f: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	for i in N:
		f.call()
	var us := float(Time.get_ticks_usec() - t0) / float(N)
	print("  %-60s %.3f us" % [label, us])
	return us


func _initialize() -> void:
	var body := Node3D.new()
	root.add_child(body)
	var ctx := {"at": Vector3(1, 2, 3), "dir": Vector3.FORWARD}
	var base := _bench("empty callable (the loop's own cost)", func() -> void: pass)
	for headless_shortcut in [true, false]:
		SbFx.allow_headless = not headless_shortcut
		SbFx.reload_data()
		print("REVIEW dormant: allow_headless %s, elements %s, any_on %s" % [str(SbFx.allow_headless), SbFx.config().get("elements"), SbFx.any_on()])
		_bench("SbFx.any_on()", func() -> void: SbFx.any_on())
		_bench("SbFx.fire(body, key, role, ctx)", func() -> void: SbFx.fire(body, "fire_blast/punch.grown", "impact", ctx))
		_bench("SbFx.start(owner, slot, body, key, role, ctx)", func() -> void: SbFx.start(body, "flight", body, "fire_blast/punch.grown", "flight", ctx))
		_bench("SbFx.sustain(owner, slot, ...)", func() -> void: SbFx.sustain(body, "rooted", body, "rooted", "idle", ctx, 0.9, "take_hold"))
		_bench("SbFx.stop(owner)", func() -> void: SbFx.stop(body))
		_bench("SbFx.dash_began(body, key, dir, info)", func() -> void: SbFx.dash_began(body, "fire_jets/jets", Vector3.FORWARD, {}))
		_bench("SbFx.dash_ended(body)", func() -> void: SbFx.dash_ended(body))
	print("  base %.3f us is in every figure above" % base)
	print("  SpellFx player made: %s" % [root.get_node_or_null("SpellFx") != null])
	SbFx.allow_headless = false
	quit(0)
