extends "res://tests/gathering/test_gathering.gd"
## The gathering sounds on the real level (push n12s hook-up): runs the gathering test's level part (the real
## input path: a tree felled with the axe, the trunk bucked, a rock broken with the mattock until it is gone; a
## sapling where the headless level has one) and checks that every gathering event played its own recorded sound
## through GatherSfx (scripts/audio/gather_sfx.gd, audio/sfx/gathering_rec/):
##   each stroke into the standing tree   gather_rec_axe_chop / _big, one per stroke
##   the tree going over                  gather_rec_tree_crack and gather_rec_tree_fall, once
##   the tree landing                     gather_rec_tree_land, once
##   each bucking stroke                  gather_rec_buck
##   each mattock stroke on the rock      gather_rec_pick_rock / _hard, one per stroke
##   a piece breaking off / the last one  gather_rec_rock_split / gather_rec_rock_depleted (once, at the end)
## and that the swish was timed for the landing (GatherSfx.fall_time against the real fall).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_gathering_sfx.gd -- --no-capture

var _strokes := {}             ## stroke kind -> strokes landed
var _fell_frame := -1
var _land_frame := -1
var _fall_pred := -1.0


func _initialize() -> void:
	GatherSfx.reset_log()
	await _test_level()
	_check_sounds()
	print("REPORT ", JSON.stringify(report))
	if failures.is_empty():
		print("GATHERING SFX TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("GATHERING SFX TEST FAILED (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _level_fell(h: VegHarvest) -> void:
	gt.stroke_landed.connect(func(kind: String, _i: Dictionary) -> void: _strokes[kind] = int(_strokes.get(kind, 0)) + 1)
	gt.felled.connect(func(ft: FelledTree) -> void:
		_fell_frame = Engine.get_physics_frames()
		_fall_pred = GatherSfx.fall_time(ft.length, gt.data.felling)
		ft.landed.connect(func(_f: FelledTree) -> void: _land_frame = Engine.get_physics_frames()))
	await super._level_fell(h)


func _check_sounds() -> void:
	var c := GatherSfx.counts
	report["sfx_counts"] = c
	report["strokes"] = _strokes
	var n := func(ids: Array) -> int:
		var k := 0
		for id: StringName in ids:
			k += int(c.get(id, 0))
		return k
	var trees := int(_strokes.get("tree", 0))
	var chops: int = n.call([&"gather_rec_axe_chop", &"gather_rec_axe_chop_big"])
	_check(trees > 0 and chops == trees, "one chop sound per stroke into the tree (%d chops, %d strokes)" % [chops, trees])
	_check(int(c.get(&"gather_rec_tree_crack", 0)) == 1 and int(c.get(&"gather_rec_tree_fall", 0)) == 1,
			"the tree going over cracks and swishes once (%d, %d)" % [int(c.get(&"gather_rec_tree_crack", 0)), int(c.get(&"gather_rec_tree_fall", 0))])
	_check(int(c.get(&"gather_rec_tree_land", 0)) == 1, "the landing sounds once (%d)" % int(c.get(&"gather_rec_tree_land", 0)))
	var trunks := int(_strokes.get("trunk", 0))
	_check(trunks > 0 and int(c.get(&"gather_rec_buck", 0)) == trunks,
			"one bucking sound per stroke into the trunk (%d, %d strokes)" % [int(c.get(&"gather_rec_buck", 0)), trunks])
	var saps := int(_strokes.get("sapling", 0))
	_check(int(c.get(&"gather_rec_axe_chop_sapling", 0)) == saps, "one sapling sound per stroke into a sapling (%d, %d strokes)"
			% [int(c.get(&"gather_rec_axe_chop_sapling", 0)), saps])
	var rocks := int(_strokes.get("rock", 0))
	var picks: int = n.call([&"gather_rec_pick_rock", &"gather_rec_pick_rock_hard"])
	_check(rocks > 0 and picks == rocks, "one mattock sound per stroke on the rock (%d, %d strokes)" % [picks, rocks])
	var splits := int(c.get(&"gather_rec_rock_split", 0))
	_check(splits > 0 and splits < rocks, "pieces breaking off sound (%d of %d strokes)" % [splits, rocks])
	_check(int(c.get(&"gather_rec_rock_depleted", 0)) == 1, "the last piece sounds the outcrop giving way, once (%d)"
			% int(c.get(&"gather_rec_rock_depleted", 0)))
	if _fell_frame >= 0 and _land_frame >= 0:
		var real := float(_land_frame - _fell_frame) / float(Engine.physics_ticks_per_second)
		report["fall_s"] = real
		report["fall_pred_s"] = _fall_pred
		_check(absf(real - _fall_pred) < 0.3, "the swish is timed for the landing: predicted %.2f s, the tree came down in %.2f s"
				% [_fall_pred, real])
	else:
		_check(false, "the fall was seen (felled at frame %d, landed at %d)" % [_fell_frame, _land_frame])
