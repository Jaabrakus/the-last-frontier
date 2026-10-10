extends SceneTree
## Review round 1 probe (read-only): what the Spellbreak bridge costs when every element is switched off (config.json as
## shipped), per call, and what an early-out on SbFx.on(el) would save.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r1_dormant.gd
## Headless is right here: SbFx.on() answers false at once in headless, but resolve() reaches it only AFTER the lookup,
## so the lookup is what is measured.

const N := 100000


func _bench(label: String, f: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	for i in N:
		f.call()
	var us := float(Time.get_ticks_usec() - t0) / float(N)
	print("  %-62s %.2f us/call" % [label, us])
	return us


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("REVIEW dormant bridge")
	var cfg := SbFx.config()
	print("  elements: ", cfg.get("elements"), "  enabled: ", cfg.get("enabled"))
	for el in SbFx.ELEMENTS:
		print("  on(%s) = %s (headless forces false)" % [el, SbFx.on(el)])
	var body := Node3D.new()
	root.add_child(body)
	var ctx := {"at": Vector3(1, 2, 3), "dir": Vector3.FORWARD, "node": body}
	var info := {"tag": "fire_blast/punch.grown"}

	# the call sites build a key (a string) and a ctx dictionary first
	_bench("call-site cost alone: key_of(info) + ctx dict", func() -> void:
		var k := SbFx.key_of(info)
		var c := {"at": Vector3(1, 2, 3), "dir": Vector3.FORWARD, "info": info, "node": body}
		k = k + str(c.size()))
	var base := _bench("SbFx.on(\"fire\") (the switch itself)", func() -> void: SbFx.on("fire"))
	_bench("SbFx.fire(null, hit key, role present in table)", func() -> void:
		SbFx.fire(null, "fire_blast/punch.grown", "impact", ctx))
	_bench("SbFx.fire(null, key with no table row)", func() -> void:
		SbFx.fire(null, "zz_none/zz", "impact", ctx))
	_bench("SbFx.fire(body in tree, hit key, role present)", func() -> void:
		SbFx.fire(body, "fire_blast/punch.grown", "impact", ctx))
	_bench("SbFx.start(owner, slot, body, key, role)", func() -> void:
		SbFx.start(body, "flight", body, "fire_blast/punch.grown", "flight", ctx))
	_bench("SbFx.stop(owner) with nothing held", func() -> void: SbFx.stop(body))
	_bench("SbFx.resolve(body, key, role)", func() -> void:
		SbFx.resolve(body, "fire_blast/punch.grown", "impact"))
	_bench("SbFx.any_on() (the early-out every call site now takes first)", func() -> void: SbFx.any_on())

	# what an early-out would cost: the same call, but the switch of every element tested first
	_bench("hypothetical early-out: on(e) x4 then return", func() -> void:
		var any := false
		for e: String in SbFx.ELEMENTS:
			if SbFx.on(e):
				any = true
				break
		if any:
			SbFx.fire(null, "fire_blast/punch.grown", "impact", ctx))
	print("  baseline on(): %.2f us" % base)
	print("  SpellFx player created while dormant: ", SbFx.fire(body, "fire_blast/punch.grown", "impact", ctx), " ; /root/SpellFx exists: ",
			root.get_node_or_null("SpellFx") != null)
	quit(0)
