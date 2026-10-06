extends SceneTree
## R1's water network (WaterNetwork over data/world/maps/r1/water.json; Thủy Vân Phase 1 T3). Not wired into any level:
## the class alone, headless, no scene:
##
##   Godot --headless --path . -s tests/world/test_water_network.gd
##
##   junction   the torrent's level meets the main channel's at its mouth: no step along the torrent's line into it, none
##              across the main channel's bank; the main channel wins where they overlap
##   reach      in S1 the Silent Reach's flow is 0 from z_from to z_to and eased back to 1 over ease_m past each end;
##              S0 runs as ever; set_reach_flow by hand
##   pounds     each pound flat over its polygon from its milestone (M2 for the lock, the basin and B3's paddies), none
##              before; the downstream pounds fall by days since the river stopped
##   outside    NO_WATER past a channel's half width, past its ends and far from it; the torrent none before M1
##   current    along the centre line's tangent downstream at the channel's speed; still on a pound
##   step       the lock step from M2: the upper level held to the lower gate; before M2 the level eases through it
##   block      as_world_river_block("main") read as WorldRiver would gives the network's centre-line surface within
##              1 mm; the torrent has none
##   parity     every point of tests/world/fixtures/water_parity.json (tools/environment/water/test_water_net.py, the
##              numpy twin) within 1e-3
## Ends with "WATER NETWORK TEST PASSED (<n> checks)" or "WATER NETWORK TEST FAILED (<f> of <n>)".

const WN := preload("res://scripts/world/water/water_network.gd")
const FIXTURE := "res://tests/world/fixtures/water_parity.json"
const NO_WATER := -INF

var checks := 0
var fails: Array[String] = []
var data := {}


func _initialize() -> void:
	var f := FileAccess.open(WN.R1_PATH, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text()) if f else {}
	_expect(not data.is_empty(), "water.json loads")
	if not data.is_empty():
		_junction()
		_reach()
		_pounds()
		_outside()
		_current()
		_step()
		_block()
		_parity()
	if fails.is_empty():
		print("WATER NETWORK TEST PASSED (%d checks)" % checks)
	else:
		for m in fails:
			print("FAIL: ", m)
		print("WATER NETWORK TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _net(state := "S0", milestone := "M1", day := 0.0) -> WN:
	var n: WN = WN.from_data(data)
	n.set_state(state)
	n.set_milestone(milestone)
	n.set_day(day)
	return n


## (x, z) `offset` m to the right (looking downstream) of the channel's centre line, `s` m along (Vector2 is float32:
## about 1e-4 m out at these distances, so the checks through it allow for that).
func _along(n: WN, cid: String, s: float, offset := 0.0) -> Vector2:
	var p := n.point_at(cid, s)
	var t := n.tangent_at(cid, s)
	return Vector2(p.x - t.z * offset, p.z + t.x * offset)


func _channel(cid: String) -> Dictionary:
	for c: Dictionary in data.channels:
		if c.id == cid:
			return c
	return {}


func _junction() -> void:
	var n := _net()
	var j: Dictionary = data.junctions[0]
	var tor_end := n.length("torrent")
	var jump := 0.0
	var last := NAN
	for k in 801:
		var p := _along(n, "torrent", tor_end - 80.0 + 0.1 * k)
		var lv := n.surface_at(p.x, p.y)
		if not is_nan(last):
			jump = maxf(jump, absf(lv - last))
		last = lv
	var worst := 0.0
	var pairs := 0
	for k in 19:
		var sm := float(j.s_into) + (-0.9 + 0.1 * k) * n.half_width_at("torrent", tor_end)
		var hw := n.half_width_at("main", sm)
		for side in [-1.0, 1.0]:
			var a := _along(n, "main", sm, side * (hw - 0.02))
			var b := _along(n, "main", sm, side * (hw + 0.02))
			var ca := n.channel_at(Vector3(a.x, 0.0, a.y))
			var cb := n.channel_at(Vector3(b.x, 0.0, b.y))
			if ca.get("channel", "") == "main" and cb.get("channel", "") == "torrent":
				worst = maxf(worst, absf(n.surface_at(a.x, a.y) - n.surface_at(b.x, b.y)))
				pairs += 1
	var at := Vector3(float(j.at[0]), 0.0, float(j.at[1]))
	_expect(jump < 0.01 and pairs > 0 and worst < 0.005 and n.channel_at(at).get("channel", "") == "main",
			"junction: the torrent runs into the main channel without a step (%.4f m along, %.4f m across its bank, %d pairs)" % [jump, worst, pairs])


func _reach() -> void:
	var r: Dictionary = _channel("main").reaches[0]
	var s0 := float(r.s_from)
	var s1 := float(r.s_to)
	var ease_m := float(r.ease_m)
	var still := _net("S1")
	var run := _net("S0")
	var stopped := true
	var ran := true
	for k in 200:
		var p := _along(still, "main", lerpf(s0, s1, k / 199.0))
		stopped = stopped and still.flow_scale_at(p.x, p.y) < 1e-6 and still.current_at(p.x, p.y).length() < 1e-6
		ran = ran and run.flow_scale_at(p.x, p.y) == 1.0
	var eased := true
	for end_sign in [[s0, -1.0], [s1, 1.0]]:
		var prev := -1.0
		for k in 141:
			var d := (ease_m + 30.0) * k / 140.0
			var p := _along(still, "main", float(end_sign[0]) + float(end_sign[1]) * d)
			var f := still.flow_scale_at(p.x, p.y)
			eased = eased and f >= prev - 1e-6 and (d < ease_m or f > 1.0 - 1e-6)
			prev = f
		var mid := _along(still, "main", float(end_sign[0]) + float(end_sign[1]) * ease_m * 0.5)
		eased = eased and absf(still.flow_scale_at(mid.x, mid.y) - 0.5) < 1e-4
	var ends := absf(_along(still, "main", s0).y - float(r.z_from)) < 1e-3 and absf(_along(still, "main", s1).y - float(r.z_to)) < 1e-3
	var c := _along(still, "main", (s0 + s1) * 0.5)
	still.set_reach_flow("silent_reach", 0.5)
	var by_hand := absf(still.flow_scale_at(c.x, c.y) - 0.5) < 1e-6
	_expect(stopped and ran and eased and ends and by_hand,
			"reach: S1 still from z %.0f to %.0f, eased over %.0f m past its ends; S0 running; by hand half" % [r.z_from, r.z_to, ease_m])


func _pounds() -> void:
	var m2 := _net("S0", "M2")
	var m1 := _net("S0", "M1")
	var flat := true
	var unbuilt := true
	var worst := ""
	for p: Dictionary in data.pounds:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Array in p.polygon:
			lo = Vector2(minf(lo.x, q[0]), minf(lo.y, q[1]))
			hi = Vector2(maxf(hi.x, q[0]), maxf(hi.y, q[1]))
		for i in 15:
			for k in 15:
				var x := lerpf(lo.x + 0.5, hi.x - 0.5, i / 14.0)
				var z := lerpf(lo.y + 0.5, hi.y - 0.5, k / 14.0)
				var ok := m2.surface_at(x, z) == float(p.level) and m2.current_at(x, z) == Vector3.ZERO
				if not ok and worst == "":
					worst = "%s at (%.1f, %.1f): %.3f" % [p.id, x, z, m2.surface_at(x, z)]
				flat = flat and ok
				if p.milestone == "M2":
					var s := m1.surface_at(x, z)
					unbuilt = unbuilt and (s == NO_WATER or not m1.channel_at(Vector3(x, 0.0, z)).is_empty())
					if p.kind == "paddy":
						unbuilt = unbuilt and s == NO_WATER
	_expect(flat and unbuilt, "pounds: flat over their polygons from their milestone, none before %s" % worst)
	var falls := true
	for pid in ["lock_chamber", "barge_basin"]:
		var lv0 := m2.pound_level_at(pid, 0.0)
		var prev := lv0
		for d in range(1, 31):
			var lv := m2.pound_level_at(pid, float(d))
			falls = falls and lv < prev
			prev = lv
		falls = falls and m2.pound_level_at(pid, -5.0) == lv0 and lv0 - prev > 1.0 and lv0 - prev < 2.0
	_expect(falls, "pounds: the lock chamber and the barge basin fall over the river's first 30 still days (%.2f m)" % [m2.pound_level_at("barge_basin", 0.0) - m2.pound_level_at("barge_basin", 30.0)])


func _outside() -> void:
	var n := _net()
	var ok := true
	var wet := true
	var flat := func(_x: float, _z: float) -> float: return 0.0
	for cid in ["main", "torrent"]:
		for k in 40:
			var s := lerpf(20.0, n.length(cid) - 60.0, k / 39.0)
			var hw := n.half_width_at(cid, s)
			for side in [-1.0, 1.0]:
				var o := _along(n, cid, s, side * (hw + 0.05))
				if n.channel_at(Vector3(o.x, 0.0, o.y)).is_empty():
					ok = ok and n.surface_at(o.x, o.y) == NO_WATER and n.depth_at(o.x, o.y, flat) == 0.0
				var i := _along(n, cid, s, side * (hw - 0.05))
				wet = wet and n.surface_at(i.x, i.y) != NO_WATER
	for p in [Vector2(900, -1670), Vector2(900, 1670), Vector2(-1255, -520), Vector2(0, 0), Vector2(-800, 1200)]:
		ok = ok and n.surface_at(p.x, p.y) == NO_WATER
	var c := _along(n, "main", 1000.0)
	var lv := n.surface_at(c.x, c.y)
	var under := n.is_under_water(Vector3(c.x, lv - 0.1, c.y)) and not n.is_under_water(Vector3(c.x, lv + 0.1, c.y)) \
			and not n.is_under_water(Vector3(0.0, -1000.0, 0.0))
	var m0 := _net("S0", "M0")
	var t := _along(m0, "torrent", 500.0)
	var bed := func(_x: float, _z: float) -> float: return lv - 1.25
	var depth := n.depth_at(c.x, c.y, bed)
	_expect(ok and wet and under and m0.surface_at(t.x, t.y) == NO_WATER and absf(depth - 1.25) < 1e-6,
			"outside: none past the half width, the ends or far off; under water below the surface; no torrent at M0")


func _current() -> void:
	var n := _net()
	var ok := true
	var worst := ""
	for cid in ["main", "torrent"]:
		var ch := _channel(cid)
		for k in 60:
			var s := lerpf(10.0, n.length(cid) - 40.0, k / 59.0)
			var p := _along(n, cid, s)
			if n.channel_at(Vector3(p.x, 0.0, p.y)).get("channel", "") != cid:
				continue
			var a := _along(n, cid, s - 1.0)
			var b := _along(n, cid, s + 1.0)
			var along_dir := (b - a).normalized()
			var cur := n.current_at(p.x, p.y)
			var v := Vector2(cur.x, cur.z)
			var speed := _speed_at(ch, s)
			var good := v.length() > 0.1 and v.normalized().dot(along_dir) > 0.999 and absf(v.length() - speed) < 1e-4
			if not good and worst == "":
				worst = " (%s s %.0f: %s vs %s at %.3f)" % [cid, s, str(v), str(along_dir), speed]
			ok = ok and good
	var south := _along(n, "main", 1500.0)
	var east := _along(n, "torrent", 500.0)
	_expect(ok and n.current_at(south.x, south.y).z > 0.0 and n.current_at(east.x, east.y).x > 0.0,
			"current: along the centre line downstream at the channel's speed%s" % worst)


func _speed_at(ch: Dictionary, s: float) -> float:
	var nodes: Array = ch.nodes
	for i in nodes.size() - 1:
		if s <= float(nodes[i + 1][0]):
			var t := (s - float(nodes[i][0])) / (float(nodes[i + 1][0]) - float(nodes[i][0]))
			return lerpf(float(nodes[i][6]), float(nodes[i + 1][6]), t)
	return float(nodes[nodes.size() - 1][6])


func _step() -> void:
	var st: Dictionary = _channel("main").steps[0]
	var m2 := _net("S0", "M2")
	var m1 := _net("S0", "M1")
	var held := m2.level_at_s("main", float(st.s_lower) - 0.5) == float(st.level_upper)
	var hw := m2.half_width_at("main", float(st.s_lower) + 0.5)
	var below := _along(m2, "main", float(st.s_lower) + 0.5, 0.8 * hw)
	var dropped := m2.surface_at(below.x, below.y) < float(st.level_lower) + 0.1
	var eased := m1.level_at_s("main", float(st.s_lower) - 0.5) < float(st.level_upper) - 3.0
	_expect(held and dropped and eased and st.milestone == "M2",
			"step: from M2 the lock holds %.0f m to its lower gate, then %.0f m; before M2 it eases through" % [st.level_upper, st.level_lower])


func _block() -> void:
	var n := _net()
	var blk := n.as_world_river_block("main")
	var nodes: Array = blk.get("nodes", [])
	var err := 0.0
	var off := 0.0
	var i := 0
	for k in 2001:
		var z := lerpf(-1663.5, 1663.5, k / 2000.0)
		while i < nodes.size() - 2 and z > float(nodes[i + 1][0]):
			i += 1
		var t := (z - float(nodes[i][0])) / (float(nodes[i + 1][0]) - float(nodes[i][0]))
		var x := lerpf(float(nodes[i][1]), float(nodes[i + 1][1]), t)
		var lv := lerpf(float(nodes[i][2]), float(nodes[i + 1][2]), t)
		err = maxf(err, absf(n.surface_at(x, z) - lv))
		off = maxf(off, absf(float(n.channel_at(Vector3(x, 0.0, z)).get("offset", INF))))
	_expect(not nodes.is_empty() and err < 1e-3 and off < 1e-3 and n.as_world_river_block("torrent").is_empty()
			and blk.reaches[0].id == "silent_reach",
			"block: WorldRiver's reading of the main channel within %.5f m of the network's surface (centre %.5f m off); none for the torrent" % [err, off])


func _parity() -> void:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	var fx: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if not fx is Dictionary:
		_expect(false, "parity: the fixture loads")
		return
	var bad := 0
	var first := ""
	var pts: Array = fx.points
	var nets := {}
	for p: Dictionary in pts:
		var key := "%s %s %s" % [p.state, p.milestone, p.day]
		if not nets.has(key):
			nets[key] = _net(p.state, p.milestone, float(p.day))
		var n: WN = nets[key]
		var x := float(p.x)
		var z := float(p.z)
		var got_s := n.surface_at(x, z)
		var ok := (got_s == NO_WATER) if typeof(p.surface) == TYPE_NIL else absf(got_s - float(p.surface)) < 1e-3
		var ca := n.channel_at(Vector3(x, 0.0, z))
		ok = ok and String(ca.get("channel", "")) == String(p.channel)
		if p.channel != "":
			ok = ok and absf(float(ca.s) - float(p.s)) < 1e-3 and absf(float(ca.offset) - float(p.offset)) < 1e-3 \
					and absf(float(ca.half_width) - float(p.half_width)) < 1e-3
		var cur := n.current_at(x, z)
		ok = ok and absf(cur.x - float(p.current[0])) < 1e-3 and absf(cur.z - float(p.current[1])) < 1e-3
		ok = ok and absf(n.flow_scale_at(x, z) - float(p.flow_scale)) < 1e-3
		if not ok:
			bad += 1
			if first == "":
				first = " (first: %s at (%.2f, %.2f): surface %s, %s, current %s)" % [p.state, x, z, str(got_s), str(ca), str(cur)]
	_expect(bad == 0 and pts.size() >= 200, "parity: %d points match the numpy twin within 1e-3, %d off%s" % [pts.size(), bad, first])
