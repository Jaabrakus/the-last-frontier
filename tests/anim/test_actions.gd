extends AnimTestSuite
## WP5 (plan sections 6.10 and 10): weapon actions, driven like the game (Weapon.action_started
## at each stage start with the stage duration, gameplay owns the timing, G7).
##   - musket 5-stage reload (begin 1.3, mid 1.6, mid 1.8, mid 2.2, end 1.3 s; stand and crouch)
##     and pistol 3-stage reload (0.8, 1.2, 0.9): each stage plays its graph clip
##     (actions.<w>/<stance>/<key>.partial) and its additive twin; a non-loop stage's OneShot is
##     active for the stage duration (+- 1 frame), a mid stage keeps its weight until the next
##     stage has faded in (hand-over) and then fades out;
##     the graph's automatic begin -> mid chain starts the mid as the begin fades (no dip to the
##     carry pose between stages); a mid stage plays
##     n = round(dur / len) whole loops (the clip wraps n - 1 times inside the stage); consecutive
##     mid stages do not re-fire the OneShot; the carry pose under the reload partials never
##     shows through by more than 0.2 between the stages (no dip), and no arm bone turns faster
##     than 30 rad/s across the whole reload (no pop);
##   - action_cancelled: every action OneShot inactive within 0.15 s + 1 frame;
##   - weapon switch: the draw (equip) clip plays for all 3 weapons;
##   - bow: nock and R-grab (action key "grab" plays the nock's quiver reach, as today); a grab
##     requested while the nock is still fading waits instead of restarting the OneShot (no pop);
##   - Weapon.fired: the fire additive of the weapon and stance is active within 1 frame;
##   - bow draw (Frontier-only additive, C_add, a held-draw pose): its weight follows the draw
##     amount while drawing (so the arm draws over the draw time), stand / crouch clip by the
##     stance weight, scaled by the aim weight, off for the firearms; a let-down unwinds it over
##     tuning charge_let_down_s, a shot hands it to the fire additive within that clip's fade-in;
##   - graph auto chain vs gameplay timing: a reload_mid that arrives before the chain point (up to
##     0.2 s early, or with a long frame) keeps its own stage: the mid stays at full weight for
##     the stage, fired once; the chain never replaces or shortens it;
##   - begin -> mid seam (musket stand / crouch, pistol): model-space speed of the arm and prop
##     bones across the seam no faster than the graph's own sequence at the stage rates (begin to
##     its end, fade-0 cut, mid) x 1.1, and the carry pose shows through by < 0.1;
##   - holster (options.holster, graph default on): the draw clip backwards over the holster
##     phase (not ending at once, reaching the draw's first frame by the phase end), held there
##     through Weapon.action_cancelled until the next weapon's draw has faded in, then faded;
##     option off (gameplay override): nothing plays;
##   - crouch-change additive: rapid toggles crossfade the additives (summed weight <= 1), never
##     stack them.

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const DT := 1.0 / 60.0
const FRAME_TOL := 1.5 * DT
## "No pop": arm bones (clavicle .. wrist) stay below this angular speed through a whole reload.
## For scale: the authored clips reach 21-23 rad/s (musket reload wrists at their stage rates), and
## the graph's own begin -> mid switch (fade 0) jumps 0.27 rad in one frame (16 rad/s at 60 Hz).
const MAX_ARM_SPEED := 30.0
## Between the first stage reaching full weight and the last stage's fade-out, the pose under the
## reload partials (the carry / aim pose) never shows through by more than this (no dip).
const MAX_BASE_LEAK := 0.2
const MUSKET := [["reload_begin", 1.0], ["reload_mid", 1.2], ["reload_mid", 1.4], ["reload_mid", 1.7], ["reload_end", 1.0]]
const PISTOL := [["reload_begin", 0.8], ["reload_mid", 1.2], ["reload_end", 0.9]]
const ARM_BONES := ["l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist"]
const PROP_BONES := ["l_hand_prop_attachment", "r_hand_prop_attachment"]
## Seam check bones (model space).
const SEAM_BONES := ["spined", "neck", "heada", "l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow",
		"l_wrist", "r_wrist", "l_hand_prop_attachment", "r_hand_prop_attachment"]
## Seam speed vs the graph's own begin -> cut -> mid sequence.
const SEAM_MARGIN := 1.1
const SEAM_MAX_LEAK := 0.1
const EQUIP := {"bow": 0.45, "musket": 0.7, "pistol": 0.3}


func describe() -> String:
	return "actions: staged reloads (clips, timing, loops, no re-fire, no pop, chain order, seam), cancel, draw, holster, bow nock / grab, fire, crouch-change"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	await _reload(ctx, h, "musket", "stand", MUSKET)
	await _reload(ctx, h, "musket", "crouch", MUSKET)
	await _reload(ctx, h, "pistol", "stand", PISTOL)
	await _cancel(ctx, h)
	await _draw(ctx, h)
	await _bow(ctx, h)
	await _fire(ctx, h)
	await _charge(ctx, h)
	await _chain_order(ctx, h)
	for c in [["musket", "stand", 1.0, 1.2], ["musket", "crouch", 1.0, 1.2], ["pistol", "stand", 0.8, 1.2]]:
		await _seam(ctx, h, c[0], c[1], c[2], c[3])
	await _holster(ctx, h)
	await _crouch_change(ctx, h)


func _reload(ctx: AnimTestContext, h, w: String, st: String, stages: Array) -> void:
	h.snap(StringName(w), st, 0.0, 0.0)
	h.inp.weapon_aim = 0.0
	h.set_lower(h.idx.input_for("%s/%s/idle" % [w, "crouch" if st == "crouch" else "run"]), 0.0, &"IDLE")
	h.step(10)
	var u: UpperBody = h.upper
	var fires0: Dictionary = u.fire_counts()
	var label := "%s/%s reload" % [w, st]
	var info: Array = []
	var t := 0.0
	var trace: Array = []
	var prev := {}
	var max_speed := 0.0
	var max_speed_at := ""
	var prop_speed := 0.0
	var prop_speed_at := ""
	var t0 := 0.0
	for k in stages.size():
		var key: String = stages[k][0]
		var dur: float = stages[k][1]
		var a := u.resolve_action(w, st, key)
		var x: Dictionary = h.idx.oneshot("X", String(a.get("partial", "")))
		var xa: Dictionary = h.idx.oneshot("XA", String(a.get("twin", ""))) if a.get("twin") is String else {}
		ctx.check(not x.is_empty(), "%s stage %d %s: X OneShot for %s" % [label, k + 1, key, a.get("partial")])
		info.append({"key": key, "dur": dur, "start": t0, "end": t0 + dur, "x": x.get("node", ""), "xa": xa.get("node", ""),
				"loop": bool(a.get("loop", false)), "len": float(x.get("length", 1.0))})
		t0 += dur
	var nodes := {}
	for s in info:
		for n in [s.x, s.xa]:
			if n != "":
				nodes[n] = true
	for k in stages.size():
		var s0: Dictionary = info[k]
		u.on_action(String(s0.key), float(s0.dur), StringName(w))
		var nf := roundi(float(s0.dur) / DT)
		for f in nf:
			h.step(1)
			t += DT
			var row := {"t": t}
			for n in nodes:
				row[n] = [h.oneshot_weight(n), float(h.tree.get(h.idx.oneshots[n].position_node))]
			trace.append(row)
			for b in ARM_BONES + PROP_BONES:
				var q: Quaternion = h.rig.bone_rot(b)
				if prev.has(b):
					var sp := PoseOracle.qdist(prev[b], q) / DT
					var at := "%s at %.3f s (stage %d)" % [b, t, k + 1]
					if b in PROP_BONES:
						if sp > prop_speed:
							prop_speed = sp
							prop_speed_at = at
					elif sp > max_speed:
						max_speed = sp
						max_speed_at = at
				prev[b] = q
	# The last stage fades out after its end.
	for f in 20:
		h.step(1)
		t += DT
		var row := {"t": t}
		for n in nodes:
			row[n] = [h.oneshot_weight(n), float(h.tree.get(h.idx.oneshots[n].position_node))]
		trace.append(row)
	ctx.at_most(max_speed, MAX_ARM_SPEED, "%s: arm bones never turn faster than (rad/s) [%s]" % [label, max_speed_at])
	var xs := {}
	for s in info:
		xs[s.x] = true
	var leak := 0.0
	var leak_at := 0.0
	var first_full := INF
	var last_fade: float = float(info[info.size() - 1].end) - float(h.idx.oneshots[info[info.size() - 1].x].fade[1])
	for row in trace:
		var base := 1.0
		for n in xs:
			base *= 1.0 - float(row[n][0])
		if first_full == INF and base <= 1e-6:
			first_full = row.t
		if first_full != INF and float(row.t) < last_fade - 1e-6 and base > leak:
			leak = base
			leak_at = row.t
	ctx.at_most(leak, MAX_BASE_LEAK, "%s: carry pose showing through the reload partials between stages, worst (at %.3f s)" % [label, leak_at])
	ctx.info("%s: prop bones (the weapon) turn at most %.1f rad/s [%s]" % [label, prop_speed, prop_speed_at])
	var fires: Dictionary = u.fire_counts()
	for k in info.size():
		var s: Dictionary = info[k]
		var tag := "%s stage %d %s (%.1f s)" % [label, k + 1, s.key, s.dur]
		# Full weight from the fade-in to the stage end; the fade-out starts at the end (+- 1 frame).
		var full_from := INF
		var fade_at := INF
		for row in trace:
			if float(row.t) <= float(s.start) + 1e-6:
				continue
			var wgt: float = row[s.x][0]
			if full_from == INF and wgt >= 1.0 - 1e-6:
				full_from = row.t
			elif full_from != INF and wgt < 1.0 - 1e-6 and fade_at == INF:
				fade_at = row.t
		var next_same: bool = k + 1 < info.size() and info[k + 1].x == s.x
		var fo := float(h.idx.oneshots[s.x].fade[1])
		if next_same:
			ctx.check(fade_at > float(s.end) + FRAME_TOL, "%s: stays at full weight into the next mid stage (no re-fire)" % tag)
		elif s.loop:
			# Hand-over: full weight until the next stage has faded in, then its own fade-out.
			var next_in := float(h.idx.oneshots[info[k + 1].x].fade[0]) if k + 1 < info.size() else 0.0
			var hand := next_in + UpperBody.HANDOVER_EXTRA_S
			ctx.check(fade_at - DT >= float(s.end) - 1e-6 and fade_at - DT <= float(s.end) + hand + FRAME_TOL,
					"%s: full weight until the next stage has faded in, then fading (fade from %.3f s, stage end %.3f + hand-over %.2f s)" % [
					tag, fade_at - DT, float(s.end), hand])
		else:
			ctx.near(fade_at - DT, float(s.end) - fo, FRAME_TOL, "%s: full weight until its last %.2f s, fading out with the stage (fade from %.3f s)" % [tag, fo, fade_at - DT])
			var off_at := INF
			for row in trace:
				if float(row.t) > float(s.start) + 2.0 * DT and off_at == INF and row[s.x][0] <= 0.0:
					off_at = row.t
			ctx.near(off_at - DT, float(s.end), FRAME_TOL, "%s: active for the stage duration +- 1 frame (ends at %.3f s)" % [tag, off_at - DT])
		var fi := float(h.idx.oneshots[s.x].fade[0])
		ctx.at_most(full_from - float(s.start), fi + 2.0 * DT + 1e-6, "%s: fades in within its fade-in %.2f s + 1 frame (s)" % [tag, fi])
		if s.xa != "":
			var mid_t: float = float(s.start) + 0.5 * float(s.dur)
			var tw := 0.0
			for row in trace:
				if absf(float(row.t) - mid_t) < 0.5 * DT + 1e-6:
					tw = row[s.xa][0]
			ctx.check(tw >= 1.0 - 1e-6, "%s: additive twin %s at full weight mid-stage" % [tag, h.idx.oneshots[s.xa].clip])
		if s.loop:
			var n := maxi(1, roundi(float(s.dur) / float(s.len)))
			var wraps := 0
			var last := -1.0
			for row in trace:
				if float(row.t) <= float(s.start) + 2.0 * DT or float(row.t) >= float(s.end) - 2.0 * DT:
					last = -1.0 if float(row.t) <= float(s.start) + 2.0 * DT else last
					continue
				var pos: float = row[s.x][1]
				if last >= 0.0 and pos < last - 1e-4:
					wraps += 1
				last = pos
			ctx.check(wraps == n - 1, "%s: %d whole loops (the clip wraps %d times inside the stage, expected %d)" % [tag, n, wraps, n - 1])
	var mids: Array = info.filter(func(s): return s.key == "reload_mid")
	if not mids.is_empty():
		var node: String = mids[0].x
		ctx.check(int(fires.get(node, 0)) - int(fires0.get(node, 0)) == 1,
				"%s: %d consecutive mid stages fire the mid OneShot once (%d FIRE)" % [label, mids.size(), int(fires.get(node, 0)) - int(fires0.get(node, 0))])
	var any := false
	for s in info:
		any = any or h.oneshot_active(s.x)
	ctx.check(not any, "%s: every stage OneShot has ended after the last stage" % label)


func _cancel(ctx: AnimTestContext, h) -> void:
	h.snap(&"musket", "stand", 0.0, 0.0)
	h.set_lower(h.idx.input_for("musket/run/idle"), 0.0, &"IDLE")
	h.step(10)
	var u: UpperBody = h.upper
	u.on_action("reload_begin", 1.3, &"musket")
	h.step(30)
	u.on_action("reload_mid", 1.6, &"musket")
	h.step(20)
	var nodes: Array = u.action_records().keys()
	u.on_action_cancelled(&"musket")
	var t := 0.0
	var off_at := INF
	for f in 30:
		h.step(1)
		t += DT
		var any := false
		for n in nodes:
			any = any or h.oneshot_active(n)
		if not any and off_at == INF:
			off_at = t
	ctx.at_most(off_at, 0.15 + DT + 1e-6, "action_cancelled: every action OneShot inactive within 0.15 s + 1 frame (s) %s" % [nodes])
	# Cancelled while still fading in (sprint right after the reload starts): the engine would jump
	# a shot told to fade out during its fade-in to full weight; it finishes the fade-in first.
	h.step(20)
	u.on_action("reload_begin", 1.3, &"musket")
	h.step(3)
	var x: Dictionary = h.idx.oneshot("X", String(u.resolve_action("musket", "stand", "reload_begin").get("partial", "")))
	var w0: float = h.oneshot_weight(x.node)
	u.on_action_cancelled(&"musket")
	var prev_w := w0
	var fading_rise := false
	t = 0.0
	off_at = INF
	for f in 40:
		h.step(1)
		t += DT
		var wgt: float = h.oneshot_weight(x.node)
		if float(h.tree.get("parameters/%s/fade_out_remaining" % x.node)) > 0.0 and wgt > prev_w + 0.05:
			fading_rise = true
		prev_w = wgt
		if off_at == INF and not h.oneshot_active(x.node):
			off_at = t
	ctx.check(not fading_rise, "action_cancelled during the fade-in (weight %.2f): no jump to full weight when the fade-out starts" % w0)
	ctx.at_most(off_at, float(x.fade[0]) + float(x.fade[1]) + 2.0 * DT + 1e-6,
			"action_cancelled during the fade-in: inactive within the rest of the fade-in + the fade-out (s)")


func _draw(ctx: AnimTestContext, h) -> void:
	var equip := {"bow": 0.45, "musket": 0.7, "pistol": 0.3}
	h.snap(&"pistol", "stand", 0.0, 0.0)
	h.set_lower(h.idx.input_for("pistol/run/idle"), 0.0, &"IDLE")
	h.step(10)
	var u: UpperBody = h.upper
	for w in ["bow", "musket", "pistol"]:
		u.on_action_cancelled(h.inp.weapon_key)
		h.set_weapon(StringName(w))
		u.on_action("equip", equip[w], StringName(w))
		var a := u.resolve_action(w, "stand", "equip")
		var x: Dictionary = h.idx.oneshot("X", String(a.get("partial", "")))
		h.step(2)
		ctx.check(not x.is_empty() and h.oneshot_active(x.node), "switch to %s: draw %s playing" % [w, a.get("partial")])
		if a.get("twin") is String:
			var xa: Dictionary = h.idx.oneshot("XA", String(a.twin))
			ctx.check(not xa.is_empty() and h.oneshot_active(xa.node), "switch to %s: draw twin %s playing" % [w, a.twin])
		h.step(roundi((float(equip[w]) + 0.2) / DT))
		ctx.check(x.is_empty() or not h.oneshot_active(x.node), "switch to %s: draw ended by equip_time + fade" % w)


func _bow(ctx: AnimTestContext, h) -> void:
	h.snap(&"bow", "stand", 0.0, 0.0)
	h.set_lower(h.idx.input_for("bow/run/idle"), 0.0, &"IDLE")
	h.step(10)
	var u: UpperBody = h.upper
	var nock := u.resolve_action("bow", "stand", "nock")
	var grab := u.resolve_action("bow", "stand", "grab")
	ctx.check(String(grab.get("partial", "")) == "actor_b-p-bow-reload--part" and grab.get("partial") == nock.get("partial"),
			"bow R-grab (key grab) plays the quiver reach %s (nock clip, as today)" % grab.get("partial"))
	var x: Dictionary = h.idx.oneshot("X", String(nock.get("partial", "")))
	var node: String = x.get("node", "")
	var fires0 := int(u.fire_counts().get(node, 0))
	# Hand nock (0.35 s), then the grab arrives while the nock OneShot is still fading.
	u.on_action("nock", 0.35, &"bow")
	var pops := 0
	var last_pos := -1.0
	var last_w := 0.0
	var grab_seen := false
	var t := 0.0
	for f in roundi(2.0 / DT):
		if f == roundi(0.35 / DT):
			u.on_action("grab", 1.1, &"bow")
		h.step(1)
		t += DT
		var wgt: float = h.oneshot_weight(node)
		var pos := float(h.tree.get(x.position_node))
		if last_w > 0.02 and wgt > 0.0 and pos < last_pos - 1e-4:
			pops += 1
		if f > roundi(0.35 / DT) and h.oneshot_active(node) and int(u.fire_counts().get(node, 0)) > fires0 + 1:
			grab_seen = true
		last_pos = pos
		last_w = wgt
	ctx.check(pops == 0, "bow grab during the nock's fade-out: the OneShot is not restarted while weighted (%d jumps)" % pops)
	ctx.check(grab_seen and int(u.fire_counts().get(node, 0)) == fires0 + 2, "bow grab plays after the nock has faded (FIREs %d)" % (int(u.fire_counts().get(node, 0)) - fires0))
	ctx.check(not h.oneshot_active(node), "bow grab ended by its stage end + fade")


func _fire(ctx: AnimTestContext, h) -> void:
	var u: UpperBody = h.upper
	for w in ["bow", "musket", "pistol"]:
		for st in ["stand", "crouch"]:
			h.snap(StringName(w), st, 0.0, 0.0)
			h.inp.weapon_aim = 1.0
			h.set_lower(StringName("aimidle__%s__%s" % [w, st]), 0.0, &"AIM_IDLE")
			h.step(20)
			var clip := String(h.idx.fire.get("%s/%s" % [w, st], ""))
			var rec: Dictionary = h.idx.oneshot("F", clip)
			u.on_fired(StringName(w))
			h.step(1)
			ctx.check(not rec.is_empty() and h.oneshot_active(rec.node), "%s/%s fired: fire additive %s active within 1 frame" % [w, st, clip])
			h.step(roundi((float(rec.get("length", 1.0)) + 0.2) / DT))
	h.inp.weapon_aim = 0.0


func _charge(ctx: AnimTestContext, h) -> void:
	var u: UpperBody = h.upper
	var c: Dictionary = h.idx.charge
	if c.is_empty():
		ctx.fail("bow charge nodes built (C_add)")
		return
	var dt: float = UpperRig.DT
	var let_down := float(h.data.tuning("charge_let_down_s", 0.25))
	for st in ["stand", "crouch"]:
		h.snap(&"bow", st, 0.0, 0.0)
		h.inp.weapon_aim = 1.0
		h.inp.charge = 0.0
		h.set_lower(StringName("aimidle__bow__%s" % st), 0.0, &"AIM_IDLE")
		h.step(10)
		ctx.near(float(h.tree.get(c.add)), 0.0, 1e-6, "bow/%s undrawn: charge additive off" % st)
		var rest := PoseOracle.capture(h.rig.sk)
		# Draw as the bow does (draw_time 0.6 s); stop at 60 % for the pose check.
		var follow := 0.0
		var prev := 0.0
		var step_max := 0.0
		for f in 22:
			h.inp.charge = minf(h.inp.charge + dt / 0.6, 0.6)
			h.step(1)
			var a := float(h.tree.get(c.add))
			follow = maxf(follow, absf(a - h.inp.charge))
			step_max = maxf(step_max, absf(a - prev))
			prev = a
		ctx.at_most(follow, 1e-6, "bow/%s drawing: charge additive weight = draw amount (worst difference)" % st)
		ctx.at_most(step_max, dt / 0.6 + 1e-6, "bow/%s drawing: the draw weight moves at the draw rate, no snap (per frame)" % st)
		if c.has("st"):
			ctx.near(float(h.tree.get(c.st)), 1.0 if st == "crouch" else 0.0, 1e-6, "bow/%s: charge clip by stance weight (C_st)" % st)
		var o := PoseOracle.new(h.rig.sk, h.rig.clip_resolver())
		var clip: String = c.clips.get(st, "")
		var drawn := o.compare(rest, PoseOracle.capture(h.rig.sk), ["r_elbow", "r_wrist", "r_shoulder"], "r")
		ctx.at_least(drawn.max_rot, 0.05, "bow/%s at 60 %% draw the drawing arm moves (%s, rad)" % [st, clip])
		# Let-down: the draw ends without a shot.
		h.inp.charge = 0.0
		var off_at := INF
		var down_max := 0.0
		prev = float(h.tree.get(c.add))
		for f in int(ceil(let_down / dt)) + 3:
			h.step(1)
			var a := float(h.tree.get(c.add))
			down_max = maxf(down_max, prev - a)
			prev = a
			if off_at == INF and a <= 1e-6:
				off_at = (f + 1) * dt
		ctx.at_most(down_max, dt / let_down + 1e-6, "bow/%s let-down: the draw unwinds at most 1 / charge_let_down_s per s (per frame)" % st)
		ctx.at_most(off_at, 0.6 * let_down + dt + 1e-6, "bow/%s let-down from 60 %%: charge additive off within 0.6 x %.2f s + 1 frame (s)" % [st, let_down])
		# Shot: full draw, fired (the bow resets its draw in the same frame).
		for f in 40:
			h.inp.charge = minf(h.inp.charge + dt / 0.6, 1.0)
			h.step(1)
		var frec: Dictionary = h.idx.oneshot("F", String(h.idx.fire.get("bow/%s" % st, "")))
		var fade_in := float(frec.get("fade", [0.02])[0])
		u.on_fired(&"bow")
		h.inp.charge = 0.0
		var shot_off := INF
		for f in int(ceil(fade_in / dt)) + 3:
			h.step(1)
			if shot_off == INF and float(h.tree.get(c.add)) <= 1e-6:
				shot_off = (f + 1) * dt
		ctx.at_most(shot_off, fade_in + dt + 1e-6, "bow/%s shot: the held draw hands over to the fire additive within its fade-in %.2f s + 1 frame (s)" % [st, fade_in])
		ctx.check(bool(h.tree.get(frec.active)), "bow/%s shot: fire additive playing" % st)
		h.step(30)
	h.snap(&"musket", "stand", 0.0, 0.0)
	h.inp.weapon_aim = 1.0
	h.inp.charge = 0.8
	h.step(10)
	ctx.near(float(h.tree.get(c.add)), 0.0, 1e-6, "musket: no charge additive (bow weight 0)")
	h.inp.charge = 0.0
	h.inp.weapon_aim = 0.0


## Lowered weapon, idle, `w` / `st`, no action playing.
func _idle(h, w: String, st: String) -> void:
	h.snap(StringName(w), st, 0.0, 0.0)
	h.inp.weapon_aim = 0.0
	h.set_lower(h.idx.input_for("%s/%s/idle" % [w, "crouch" if st == "crouch" else "run"]), 0.0, &"IDLE")
	h.step(20)


## The gameplay's reload_mid before the graph chain point (the weapon's stage timer a little
## early, or a long frame): the chain (reload_begin_to_mid) must not replace or shorten it.
func _chain_order(ctx: AnimTestContext, h) -> void:
	var u: UpperBody = h.upper
	var x: Dictionary = h.idx.oneshot("X", String(u.resolve_action("musket", "stand", "reload_mid").get("partial", "")))
	for early in [0.0, 0.05, 0.2]:
		for hitch in [DT, 0.2]:
			_idle(h, "musket", "stand")
			var f0 := int(u.fire_counts().get(x.node, 0))
			u.on_action("reload_begin", 1.3, &"musket")
			var t := 0.0
			var target: float = 1.3 - float(early) - float(hitch)
			while t + DT <= target + 1e-6:
				h.step(1)
				t += DT
			u.on_action("reload_mid", 1.6, &"musket")
			h.step(1, hitch)
			var rec: Dictionary = u.action_records().get(x.node, {})
			var tt: float = hitch
			var full_until := -1.0
			for f in roundi(2.0 / DT):
				h.step(1)
				tt += DT
				if h.oneshot_weight(x.node) >= 0.999:
					full_until = tt
			var tag := "reload_mid %.2f s early, frame %.3f s" % [early, hitch]
			ctx.near(float(rec.get("dur", -1.0)), 1.6, 1e-6, "%s: the mid keeps the gameplay's stage duration (s)" % tag)
			ctx.at_least(full_until, 1.6 - DT - 1e-6, "%s: mid at full weight through its stage (until, s after the event)" % tag)
			ctx.check(int(u.fire_counts().get(x.node, 0)) - f0 == 1, "%s: the mid OneShot fired once (%d)" % [tag, int(u.fire_counts().get(x.node, 0)) - f0])
			u.on_action_cancelled(&"musket")
			h.step(20)


## Model-space speed of the SEAM_BONES across the begin -> mid seam vs the graph's own sequence.
func _seam(ctx: AnimTestContext, h, w: String, st: String, b_dur: float, m_dur: float) -> void:
	var u: UpperBody = h.upper
	var ref := _seam_graph(h, u, w, st, b_dur, m_dur)
	_idle(h, w, st)
	var b := u.resolve_action(w, st, "reload_begin")
	var m := u.resolve_action(w, st, "reload_mid")
	var xb: Dictionary = h.idx.oneshot("X", String(b.get("partial", "")))
	var xm: Dictionary = h.idx.oneshot("X", String(m.get("partial", "")))
	var prev := {}
	var best := 0.0
	var best_at := ""
	var leak := 0.0
	var t := 0.0
	u.on_action("reload_begin", b_dur, StringName(w))
	for f in roundi((b_dur + 0.4) / DT):
		if absf(t - b_dur) < 0.5 * DT:
			u.on_action("reload_mid", m_dur, StringName(w))
		h.step(1)
		t += DT
		if t > 0.2 and t < b_dur + 0.3:
			leak = maxf(leak, (1.0 - h.oneshot_weight(xb.node)) * (1.0 - h.oneshot_weight(xm.node)))
		for bn in SEAM_BONES:
			var q: Quaternion = h.rig.sk.get_bone_global_pose(h.rig.sk.find_bone(bn)).basis.get_rotation_quaternion()
			if prev.has(bn) and t > b_dur - 0.35:
				var sp := PoseOracle.qdist(prev[bn], q) / DT
				if sp > best:
					best = sp
					best_at = "%s at %.3f s" % [bn, t]
			prev[bn] = q
	u.on_action_cancelled(StringName(w))
	h.step(30)
	var tag := "%s/%s begin -> mid seam" % [w, st]
	ctx.info("%s: graph sequence at the stage rates: begin tail %.1f, fade-0 cut %.1f (one 60 Hz frame), mid head %.1f rad/s; as played %.1f rad/s [%s]" % [
			tag, ref.tail, ref.cut, ref.head, best, best_at])
	ctx.at_most(best, ref.peak * SEAM_MARGIN, "%s: no faster than the graph's own begin / cut / mid x %.1f (model space, rad/s)" % [tag, SEAM_MARGIN])
	ctx.at_most(leak, SEAM_MAX_LEAK, "%s: carry pose showing through between begin and mid, worst" % tag)


## The graph's sequence over the carry pose (oracle, graph semantics): begin partial (+ twin) at
## full weight to its end at its stage rate, fade-0 cut to the mid (+ twin) frame 0, mid at its
## stage rate. {tail, cut, head, peak} model-space speeds of SEAM_BONES (rad/s).
func _seam_graph(h, u: UpperBody, w: String, st: String, b_dur: float, m_dur: float) -> Dictionary:
	_idle(h, w, st)
	var base := PoseOracle.capture(h.rig.sk)
	var o := PoseOracle.new(h.rig.sk, h.rig.clip_resolver())
	var b := u.resolve_action(w, st, "reload_begin")
	var m := u.resolve_action(w, st, "reload_mid")
	var bl: float = h.rig.anim(String(b.partial)).length
	var ml: float = h.rig.anim(String(m.partial)).length
	var rb := bl / b_dur
	var rm := maxi(1, roundi(m_dur / ml)) * ml / m_dur
	var seq: Array = []
	var t := -0.35
	while t < 0.4 + 1e-6:
		var p: PoseOracle.Pose
		if t <= 1e-9:
			var ct := clampf(bl + t * rb, 0.0, bl)
			p = o.partial(base, o.clip(String(b.partial), ct), 1.0)
			if b.get("twin") is String:
				p = o.additive(p, o.clip(String(b.twin), ct), 1.0)
		else:
			var ct := fposmod(t * rm, ml)
			p = o.partial(base, o.clip(String(m.partial), ct), 1.0)
			if m.get("twin") is String:
				p = o.additive(p, o.clip(String(m.twin), ct), 1.0)
		seq.append([t, o.model_transforms(p)])
		t += DT
	var out := {"tail": 0.0, "cut": 0.0, "head": 0.0}
	for i in range(1, seq.size()):
		var seg := "tail" if float(seq[i][0]) <= 1e-9 else ("cut" if float(seq[i - 1][0]) <= 1e-9 else "head")
		for bn in SEAM_BONES:
			var bi: int = h.rig.sk.find_bone(bn)
			var sp := PoseOracle.qdist(seq[i - 1][1][bi].basis.get_rotation_quaternion(), seq[i][1][bi].basis.get_rotation_quaternion()) / DT
			out[seg] = maxf(float(out[seg]), sp)
	out["peak"] = maxf(float(out.tail), maxf(float(out.cut), float(out.head)))
	return out


## Graph holster: the draw clip backwards, held, handed over to the next weapon's draw.
func _holster(ctx: AnimTestContext, h) -> void:
	var u: UpperBody = h.upper
	ctx.check(u.holster_enabled(), "options.holster: graph default on")
	for c in [["musket", "bow", "stand"], ["bow", "pistol", "stand"], ["pistol", "musket", "stand"], ["musket", "pistol", "crouch"]]:
		var wf: String = c[0]
		var wt: String = c[1]
		var st: String = c[2]
		_idle(h, wf, st)
		var tag := "%s/%s holster" % [wf, st]
		var a := u.resolve_graph_action(wf, st, "holster")
		var x: Dictionary = h.idx.oneshot("X", String(a.get("partial", "")))
		if not ctx.check(not x.is_empty() and UpperBody.is_reverse(a) and x.seek != &"",
				"%s: graph state %s plays %s backwards (start phase %s, negative rate callback, TimeSeek)" % [tag, a.get("state"), a.get("partial"), a.get("start_phase")]):
			continue
		var length := float(x.length)
		var dur: float = EQUIP[wf]
		var ok := u.on_holster(StringName(wf), dur)
		var n := roundi(dur / DT)
		var active := 0
		var first := -1.0
		var last := INF
		var backward := true
		for f in n:
			h.step(1)
			var p := float(h.tree.get(x.position_node))
			if h.oneshot_active(x.node):
				active += 1
			if f == 0:
				first = p
			elif p > last + 1e-5:
				backward = false
			last = p
		ctx.check(ok and active >= n - 1, "%s: plays for the holster phase, does not end at once (active %d of %d frames)" % [tag, active, n])
		ctx.check(backward and first >= 0.75 * length, "%s: backwards from near the clip end (%.3f of %.3f s)" % [tag, first, length])
		# The FIRE lands one advance after the request, so up to one frame of clip time can be left.
		var one_frame := absf(float(h.tree.get(x.scale))) * DT if x.scale != &"" else 0.0
		ctx.at_most(last, maxf(0.05 * length, one_frame + 1e-4), "%s: at the draw's first frame (hand at the holster) by the phase end, 5 %% of the clip or one frame (clip s)" % tag)
		# Weapon.unequip() cancels the weapon's actions: the holster holds.
		u.on_action_cancelled(StringName(wf))
		h.step(3)
		ctx.check(h.oneshot_weight(x.node) >= 0.999, "%s: held at full weight through action_cancelled" % tag)
		# The next weapon's draw takes over (hand-over).
		h.set_weapon(StringName(wt))
		u.on_action("equip", EQUIP[wt], StringName(wt))
		var d: Dictionary = h.idx.oneshot("X", String(u.resolve_action(wt, st, "equip").get("partial", "")))
		var hold_until := 0.0
		var draw_full := INF
		var t := 0.0
		for f in 30:
			h.step(1)
			t += DT
			if draw_full == INF and h.oneshot_weight(d.node) >= 0.999:
				draw_full = t
			if h.oneshot_weight(x.node) >= 0.999:
				hold_until = t
		ctx.check(draw_full < INF and hold_until >= draw_full - 1.5 * DT,
				"%s -> %s draw: the holster keeps full weight until the draw has faded in (holster until %.3f s, draw full at %.3f s)" % [tag, wt, hold_until, draw_full])
		ctx.check(not h.oneshot_active(x.node), "%s: faded out after the hand-over" % tag)
		h.step(roundi(float(EQUIP[wt]) / DT) + 15)
	# Gameplay override: instant switch (option off).
	h.data.set_option("holster", false)
	_idle(h, "musket", "stand")
	var fc: Dictionary = u.fire_counts()
	var played := u.on_holster(&"musket", 0.7)
	u.on_action("holster", 0.7, &"musket")
	h.step(3)
	ctx.check(not played and u.fire_counts() == fc, "options.holster off (instant switch): nothing plays")
	h.data.clear_option("holster")


## Rapid crouch toggles with the crouch-change additive (graph default): one additive at a time.
func _crouch_change(ctx: AnimTestContext, h) -> void:
	var u: UpperBody = h.upper
	var cc: Array = []
	for n in h.idx.oneshots:
		if String(h.idx.oneshots[n].chain) == "CC":
			cc.append(n)
	var st_in: StringName = h.idx.input_for("musket/run/idle")
	var cr_in: StringName = h.idx.input_for("musket/crouch/idle")
	for spacing in [0.3, 0.12]:
		_idle(h, "musket", "stand")
		h.step(80)
		var k := roundi(spacing / DT)
		var max_sum := 0.0
		var both := 0
		var starts := {}
		var last := {}
		var jumps := []
		for f in 150:
			if f == 0 or f == k or f == 2 * k:
				h.inp.crouched = not h.inp.crouched
				h.L.request(cr_in if h.inp.crouched else st_in, 0.25)
			h.step(1)
			var s := 0.0
			var on := 0
			for n in cc:
				var wgt: float = h.oneshot_weight(n)
				s += wgt
				if wgt > 0.02:
					on += 1
					starts[n] = true
				# A FADE_OUT during the fade-in jumps the engine's weight to 1 (a pop).
				if float(h.tree.get("parameters/%s/fade_out_remaining" % n)) > 0.0 and wgt > float(last.get(n, 0.0)) + 0.05:
					jumps.append("%s %.2f -> %.2f at frame %d" % [n, float(last.get(n, 0.0)), wgt, f])
				last[n] = wgt
			max_sum = maxf(max_sum, s)
			if on >= 2:
				both += 1
		var tag := "crouch toggles %.2f s apart" % spacing
		ctx.check(jumps.is_empty(), "%s: no crouch-change additive jumps up when it starts fading out %s" % [tag, jumps])
		ctx.at_most(max_sum, 1.0 + 1e-3, "%s: crouch-change additives crossfade, summed weight (never stacked)" % tag)
		ctx.check(starts.size() == 2, "%s: both directions' additives played %s" % [tag, starts.keys()])
		ctx.info("%s: frames with two additives weighted (crossfades): %d" % [tag, both])
		var still := []
		for n in cc:
			if h.oneshot_active(n):
				still.append(n)
		ctx.check(still.is_empty(), "%s: every crouch-change additive has ended 2.5 s later %s" % [tag, still])
		h.inp.crouched = false
		h.snap(&"musket", "stand", 0.0, 0.0)
		h.step(10)
