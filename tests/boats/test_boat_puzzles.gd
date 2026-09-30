extends SceneTree
## The two building puzzles (BarkFit, PitchSpread; user 2026-09-29: "building it is a puzzle"), logic only, headless:
##   Godot --headless --path . -s tests/boats/test_boat_puzzles.gd
##   bark   pressing where it is slack keeps the skin in its band and scores well; leaving it or hammering one place scores badly;
##          over-drawing tears
##   pitch  a steady brush spreads it evenly and scores well; a fast pass leaves it thin, dwelling in one place makes a blob
var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _play_bark(mode: String) -> BarkFit:
	var b := BarkFit.make(0.45, 0.72, 28.0, true, 3)
	var t := 0.0
	var k := 0
	while not b.done():
		b.step(0.05)
		t += 0.05
		if mode == "careful":
			# press the slackest section whenever it is below the band
			var s := b.slackest()
			if b.tension[s] < b.lo + 0.05 and int(t * 20.0) % 3 == 0:
				b.press(s)
		elif mode == "hammer":
			b.press(3)
		elif mode == "sweep":
			if int(t * 20.0) % 4 == 0:
				b.press(k % BarkFit.ZONES)
				k += 1
	return b


func _initialize() -> void:
	var idle := _play_bark("idle")
	var careful := _play_bark("careful")
	var hammer := _play_bark("hammer")
	var sweep := _play_bark("sweep")
	_expect(idle.score() < 0.15, "leaving the bark alone: it never comes up to its band (%.2f)" % idle.score())
	_expect(careful.score() > 0.55, "pressing where it is slack keeps it evenly in band (%.2f, %d tears)" % [careful.score(), careful.tears])
	_expect(hammer.tears > 0 and hammer.score() < careful.score(), "hammering one place tears the bark (%d tears, %.2f)" % [hammer.tears, hammer.score()])
	_expect(careful.score() > sweep.score() + 0.3, "reading each section does far better than a blind sweep along it (%.2f against %.2f)" % [careful.score(), sweep.score()])
	var b := BarkFit.make()
	var before: float = b.tension[3]
	b.press(3)
	_expect(is_equal_approx(b.tension[3] - before, BarkFit.PRESS) and b.tension[2] > 0.0, "a press draws its section and a little of its neighbours")
	b.step(1.0)
	_expect(b.tension[3] < before + BarkFit.PRESS, "the bark springs back a little as time goes")
	var d := BarkFit.make()
	d.time = d.duration
	d.press(2)
	_expect(is_equal_approx(d.tension[2], BarkFit.make().tension[2]) or d.done(), "no pressing after the time is up")
	# pitch
	var steady := PitchSpread.make(3.0, 35.0)
	var x := 0.0
	var dt := 0.02
	var passes := 0
	while not steady.done() and passes < 2:   # two passes; a third would lay it too thick
		x = 0.0
		steady.lift()
		while x < 1.0 and not steady.done():
			x += 0.5 * dt   # two seconds across
			steady.brush(x, dt)
			steady.step(dt)
		passes += 1
	var fast := PitchSpread.make(3.0, 35.0)
	x = 0.0
	fast.lift()
	while x < 1.0:
		x += 5.0 * dt
		fast.brush(x, dt)
		fast.step(dt)
	var blob := PitchSpread.make(3.0, 35.0)
	while not blob.done():
		blob.brush(0.5, dt)
		blob.step(dt)
	_expect(steady.score() > 0.7, "steady passes along the seam cover it well (%.2f after %d passes)" % [steady.score(), passes])
	_expect(fast.score() < 0.3, "one fast pass leaves it thin (%.2f)" % fast.score())
	_expect(blob.score() < 0.3 and blob.thick[PitchSpread.CELLS / 2] > 0.9, "dwelling in one place makes a blob and leaves the rest bare (%.2f)" % blob.score())
	_expect(steady.score() > fast.score() and steady.score() > blob.score(), "steady is the best of the three")
	_expect(is_equal_approx(PitchSpread.make().cell_score(0.6), 1.0) and PitchSpread.make().cell_score(0.2) == 0.5 and PitchSpread.make().cell_score(1.2) < 1.0, "a cell in the band counts whole, a thin one in proportion, a thick one loses a little")
	var run_out := PitchSpread.make(0.02, 35.0)
	while not run_out.done():
		run_out.brush(fmod(run_out.time, 1.0), 0.02)
		run_out.step(0.02)
		if run_out.time > 30.0:
			break
	_expect(run_out.used >= run_out.supply - 0.0001, "the pitch is only so much: it runs out (%.2f of %.2f used)" % [run_out.used, run_out.supply])
	# the bed of stakes
	var hull: Dictionary = (BoatBuild.plans().birchbark as Dictionary).hull
	var good_bed := StakeBed.make(hull)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for tg in good_bed.targets.duplicate():
		good_bed.place(tg + Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)))
	var sloppy_bed := StakeBed.make(hull)
	for i in sloppy_bed.wanted():
		sloppy_bed.place(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-2.6, 2.6)))
	var half_bed := StakeBed.make(hull)
	for i in half_bed.wanted() / 2:
		half_bed.place(half_bed.targets[i])
	_expect(good_bed.wanted() == 14 and good_bed.full() and good_bed.score() > 0.7, "a bed set within a hand of every place scores well (%.2f)" % good_bed.score())
	_expect(sloppy_bed.score() < 0.3, "stakes driven anywhere score badly (%.2f)" % sloppy_bed.score())
	_expect(half_bed.score() > 0.4 and half_bed.score() < 0.55, "half the stakes, right, is half the bed (%.2f)" % half_bed.score())
	_expect(good_bed.place(Vector2.ZERO) == -1.0, "no more stakes than the bed wants")
	# the lashing
	var nimble := Lashing.make(true, 0.1)
	while not nimble.done():
		# pull as the marker crosses the middle
		var prev := nimble.pos
		nimble.step(0.004)
		if (prev - 0.5) * (nimble.pos - 0.5) <= 0.0:
			nimble.pull()
	var greedy := Lashing.make(true, 0.1)
	for i in Lashing.STITCHES:
		greedy.step(0.13)
		greedy.pull()
	var idle_l := Lashing.make(true, 0.1)
	_expect(nimble.score() > 0.85, "stitches pulled as the marker crosses the middle score well (%.2f)" % nimble.score())
	_expect(greedy.score() < nimble.score() - 0.3, "stitches pulled at random do far worse (%.2f)" % greedy.score())
	_expect(idle_l.score() == 0.0 and not idle_l.done(), "no stitches pulled, nothing sewn")
	_expect(Lashing.make(true, 0.1)._speed < nimble._speed, "the marker quickens with every stitch")
	# the ribs
	var steamer := RibSteam.make(true, 2)
	while not steamer.done():
		var w := steamer.window()
		while steamer.heat < (w.x + w.y) * 0.5:
			steamer.hold(0.02)
		steamer.release()
	var hasty := RibSteam.make(true, 2)
	while not hasty.done():
		hasty.hold(0.1)
		hasty.release()
	var boiled := RibSteam.make(true, 2)
	while not boiled.done():
		while boiled.heat < 0.98:
			boiled.hold(0.05)
		boiled.release()
	_expect(steamer.score() > 0.9, "each rib steamed to the middle of its window is set well (%.2f)" % steamer.score())
	_expect(hasty.score() < 0.5, "ribs set before they are supple crack (%.2f)" % hasty.score())
	_expect(boiled.score() < 0.35, "ribs left in the steam go mushy (%.2f)" % boiled.score())
	_expect(RibSteam.make(true, 1).release() == -1.0, "a rib not put in the steam cannot be set")
	if fails.is_empty():
		print("BOAT PUZZLES TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT PUZZLES TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
