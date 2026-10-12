extends "res://tools/ring/gameplay_highlight.gd"
## Every move of every element filmed one at a time (the owner, 2026-10-12: "do a recording of each move and then do a critique of
## each move"): one 1v1 match an element (the player of that element against a held bot of the same element, its % at REEL_PCT
## so a launch reads, staleness off), each move cast through the player's own keys as a player casts it: the key pressed (the
## hotbar), right-click held on the bot's chest until the lock fills and let go (the grown cast held on until it grew), key 3's
## move by Shift and a direction (twice quickly for its other move), the jab string by left clicks close in, the guard (E) held
## against the bot's own strike, Patch on a fresh pool, Mend on his own wall. The picture: a side camera across the deck framing
## both (the game's HUD off, the shot's caption on: element, key, the move's name). One take an element, a short dissolve from
## shot to shot. The film's own frames, frames.txt and the movie writer's AVI (for the sound) as gameplay_highlight.gd writes them:
##   GODOT_TIMEOUT=3600 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie <dir>/raw.avi \
##     -s tools/ring/move_reel.gd -- out=<dir> fps=60 size=1280x720 quality=high upscale=off music=off character_look=soft
##     [only=earth,water,fire,air] [light=noon] [pick=jab,stone_form,key3,guard,...]  (pick: shots of those kinds or move ids)
## <dir>/shots.json: [{element, key, id, mode, kind, label, grown, t0, t1}] (each shot's seconds in the film's frames, for the
## cutter: the frames between shots, unrecorded, are not in it).
## Ends with SHOWCASE DONE (the base's line); "MOVE REEL <element> <n> shots" per element.

## The player's and the bot's places on the deck's long axis (m from its centre): GAP apart.
const P_S := -4.0
const B_S := 4.0
## Close in for the jab string (m between them).
const JAB_GAP := 2.4
## Each shot's length (s) after its action begins; a grown cast's and a guard's longer.
const SHOT_S := 3.0
## The bot's % while it is filmed (a launch at 0% barely moves it).
const REEL_PCT := 30.0
## The side camera: across the deck this far, this high, looking at the middle of the two.
const CAM_SIDE := 7.5
const CAM_UP := 1.4
const GUARD_ETA_S := 0.32
const FAST_MPS := 33.0
const GUARD_LEAD_S := 0.3
const CAM_FOV := 40.0

var reel_shots: Array = []
var _el := ""
var _ctl: PlayerControls
var _keep_ctl: PlayerControls
var _hid: Array = []
## The player's pitch sign (his camera looks up for +1: the tests' calibration, test_talents_earth.gd).
var _pitch_sign := 1.0
## The shot's fixed middle (the camera never follows: a launch flies out of a still picture, as a viewer sees it).
var _cam_mid := Vector3.ZERO
var _cam_from := Vector3.INF      # (cam=behind: where the player stood as the shot began, the camera kept still from there)
var _aim_node: Node3D = null       # (the aim's mark when not the foe: mend's wall, the camera's ray over it otherwise)


func _block_user_input() -> void:
	super._block_user_input()
	MatchSetup.set_match()
	MatchSetup.format = "1v1"
	MatchSetup.light = String(args.get("light", "noon"))
	MatchSetup.round_s = 900.0
	MatchSetup.rounds_to_win = 1


func _order() -> Array:
	return ["earth", "water", "fire", "air"]


func seg_earth() -> void:
	await _reel("earth")


func seg_water() -> void:
	await _reel("water")


func seg_fire() -> void:
	await _reel("fire")


func seg_air() -> void:
	await _reel("air")


# --- one element's reel --------------------------------------------------------------------------------------------------

func _reel(el: String) -> void:
	recording = false
	_el = el
	MatchSetup.element = el
	MatchSetup.foes = [el]
	mode.restart()
	while mode.phase != "FIGHT":
		await _frame()
	await _warm(int(2.5 * fps))                      # (past the start's safety)
	var foe := mode.foe
	foe.held = true
	mode.rules.stale_off = true
	if _keep_ctl == null:
		_keep_ctl = player.controls
	_ctl = PlayerControls.new(false)
	player.controls = _ctl
	player.ignore_mouse_capture = true
	cine_takes_over = false                          # (the picture only: the game aims with the player's own camera)
	aim_target = Vector3.INF                         # (the crosshair set exactly each frame instead: _aim)
	player.pitch = 0.3
	await _frame()
	await _frame()
	_pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	player.pitch = 0.0
	cam_fn = _cam
	use_cine = true
	cine.current = false
	view.source = cine
	var shots := _shots_of(el)
	var pick := Array(String(args.get("pick", "")).split(",", false))
	if not pick.is_empty():
		shots = shots.filter(func(x: Dictionary) -> bool: return String(x.kind) in pick or String(x.get("id", "")) in pick \
				or ("%s:%s" % [x.get("id", ""), x.get("mode", "")]) in pick)
	var n := 0
	for sh: Dictionary in shots:
		await _stage(sh)
		var key_word := "LMB" if String(sh.kind) == "jab" else ("E" if String(sh.kind) == "guard" else
				("SHIFT + DIR" if String(sh.kind) == "key3" else "KEY %d" % int(sh.key)))
		await _roll("%s  ·  %s" % [el.to_upper(), key_word], String(sh.label), String(sh.get("detail", "")), 6)
		var t0 := seg_total
		var foe0: Node3D = mode.foe
		var pct0 := mode.rules.pct_of(foe0) if foe0 != null else 0.0
		await _do(sh)
		var dpct := (mode.rules.pct_of(foe0) - pct0) if foe0 != null and is_instance_valid(foe0) else 0.0
		print("MOVE REEL HIT %s %s: foe +%.1f%%" % [el, sh.label, dpct])     # (what it did to him: a hit that shows nothing still counts)
		reel_shots.append({"element": el, "key": sh.get("key", 0), "id": sh.get("id", ""), "mode": sh.get("mode", ""),
				"kind": sh.kind, "label": sh.label, "grown": sh.get("grown", false), "t0": t0, "t1": seg_total,
				"take": cur_id, "foe_pct": snappedf(dpct, 0.1)})
		n += 1
		recording = false
		_let_go()
	print("MOVE REEL %s %d shots" % [el, n])
	player.controls = _keep_ctl
	FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE).store_string(JSON.stringify(reel_shots, "\t"))
	_write_log()


## The element's shots: the jab string, keys 1, 2, 4 and 5 move by move and mode by mode (a grown one after each move that
## grows), key 3's move and its other by Shift, the guard.
func _shots_of(el: String) -> Array:
	var out_s: Array = []
	var jab: Array = NpcBending.jab_of(el)
	out_s.append({"kind": "jab", "id": String(jab[0]) if jab.size() > 0 else "", "mode": String(jab[1]) if jab.size() > 1 else "",
			"label": "Jab string", "detail": "three left clicks close in: the third is the Pop"})
	var keys := Bending.keys(el)
	for i in keys.size():
		var key: Array = keys[i]
		if i == 2:
			var first := Bending.first_of(key)
			out_s.append({"kind": "key3", "key": 3, "tap": 1, "id": String(first.get("id", "")), "mode": String(first.get("mode", "")),
					"label": _name(String(first.get("id", "")), String(first.get("mode", ""))), "detail": "Shift + W"})
			var other := Bending.other_move(key, String(first.get("id", "")), String(first.get("mode", "")))
			if not other.is_empty():
				out_s.append({"kind": "key3", "key": 3, "tap": 2, "id": String(other.id), "mode": String(other.mode),
						"label": _name(String(other.id), String(other.mode)), "detail": "Shift + W twice"})
			continue
		for id: String in key:
			var ms: Array = SwayCaster.modes_of(id)
			if ms.is_empty():
				ms = [""]
			for md: String in ms:
				var sh := {"kind": "cast", "key": i + 1, "id": id, "mode": md, "label": _name(id, md),
						"detail": "right-click held on him, let go when full"}
				if id == "mend":
					sh["detail"] = "on his own wall, raised first"
				elif id == "patch":
					sh["detail"] = "a fresh 25% to take back"
				out_s.append(sh)
				if _grows(id, md):
					var g := sh.duplicate()
					g["grown"] = true
					g["label"] = _name(id, md) + "  ▲ grown"
					g["detail"] = "held on past full until it grows"
					out_s.append(g)
	for id: String in Bending.key3(el):
		# (key 3's own move, Bending.key3: water's Ice Tomahawk; readied by 3 itself, cast as any key's)
		for md: String in (SwayCaster.modes_of(id) if not SwayCaster.modes_of(id).is_empty() else [""]):
			out_s.append({"kind": "cast", "key": 3, "id": id, "mode": md, "label": _name(id, md),
					"detail": "3, right-click held on him, let go when full"})
	out_s.append({"kind": "guard", "id": "", "mode": "", "label": "Guard", "detail": "E held as his strike comes; E again throws back what it holds"})
	return out_s


func _name(id: String, md: String) -> String:
	var n := String(SwayMoves.move(id).get("name", id.capitalize()))
	var ml := SwayCaster.mode_label(id, md) if md != "" else ""
	if ml == "" or ml.to_lower() == n.to_lower() or ml == md and SwayCaster.modes_of(id).size() <= 1:
		return n
	return "%s  ·  %s" % [n, ml]


func _grows(id: String, md: String) -> bool:
	var d := SwayMoves.move(id)
	var sp: Variant = (d.get("bend", {}) as Dictionary).get(md) if d.get("bend") is Dictionary else null
	if sp is Dictionary and (sp as Dictionary).get("grow") is Dictionary:
		return true
	var g: Variant = d.get("grow")
	return g is Dictionary and (g as Dictionary).get(md) is Dictionary


# --- staging ---------------------------------------------------------------------------------------------------------------

## Both back on the axis (the jab's close), still and whole, the bot at REEL_PCT, the deck cleared of what the last shot left
## (stones, walls, zones), the player's crosshair on the bot.
func _stage(sh: Dictionary) -> void:
	_let_go()
	var foe := mode.foe
	var ring := mode.ring
	var sc := SwayCaster.of(player)
	if sc != null:
		sc.held_override = null
		sc.quick_override = null
		sc.drop_all()
	for b: Node3D in [player, foe]:
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
		BendStatus.unfloat(b, true)
	for w in get_nodes_in_group(FormRaised.GROUP):
		if is_instance_valid(w):
			(w as Node).queue_free()
	for s in get_nodes_in_group(FormStone.GROUP):
		if (s as Node).has_meta(FormStone.LOOSE_META) or (s as Node).has_meta(&"bend_held_by"):
			(s as Node).queue_free()
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind != "pool" and not bz.is_queued_for_deletion():
			bz.end("reel")
	var p_s := P_S
	var b_s := B_S
	if String(sh.kind) == "jab":
		p_s = -JAB_GAP * 0.5
		b_s = JAB_GAP * 0.5
	_cam_mid = ring.center() + ring.axis() * ((p_s + b_s) * 0.5)
	_cam_mid.y = ring.top() + 1.0
	_cam_from = ring.center() + ring.axis() * p_s
	_cam_from.y = ring.top()
	for e: Array in [[player, p_s], [foe, b_s]]:
		var n: CharacterBody3D = e[0]
		n.global_position = ring.center() + ring.axis() * float(e[1]) + Vector3.UP * 0.05
		n.velocity = Vector3.ZERO
	mode.make_whole(player)
	mode.make_whole(foe)
	mode.rules.reset_pct(player, 0.0)
	mode.rules.reset_pct(foe, REEL_PCT)
	for i in int(0.6 * fps):
		_aim()
		await _frame()


func _let_go() -> void:
	if _ctl != null:
		_ctl.release_all()
	var sc := SwayCaster.of(player) if player != null else null
	if sc != null:
		sc.held_override = null


## Action `a` (an InputMap action) pressed and let go through Input, as a key is: the hotbar hears it.
func _key(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _frame()


func _frames(s: float) -> void:
	for i in maxi(int(round(s * fps)), 1):
		_aim()
		await _frame()


## The player's crosshair on the bot's chest this frame (his camera's yaw and pitch, as a mouse sets them: the tests' _aim_at).
func _aim() -> void:
	var foe: Node3D = _aim_node if _aim_node != null and is_instance_valid(_aim_node) else mode.foe
	if foe == null or not is_instance_valid(foe) or player.camera == null:
		return
	var up := 0.8 if foe == _aim_node else 1.1
	var d := (foe.global_position + Vector3.UP * up - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0)) * _pitch_sign


# --- the shots -------------------------------------------------------------------------------------------------------------

func _do(sh: Dictionary) -> void:
	var sc := SwayCaster.of(player)
	match String(sh.kind):
		"jab":
			# (each jab held until its short lock fills, then let go, as a player does: a 0.12 s tap let go before the lock and
			# no jab ever left the hand, the first reel's mistake)
			for i in 3:
				_ctl.set_held(&"fire", true)
				var held := 0.0
				while held < 1.2 and sc.state != SwayCaster.State.FULL:
					await physics_frame
					held += 1.0 / Engine.physics_ticks_per_second
				_ctl.set_held(&"fire", false)
				await _frames(0.18)
			await _frames(SHOT_S - 1.6)
		"key3":
			# (each press made at a physics frame's start, as a key's is: a fresh press, Hotbar._shift_dir's chord)
			_ctl.set_held(&"sprint", true)
			await _frames(0.05)
			await physics_frame
			_ctl.set_held(&"move_forward", true)
			if int(sh.get("tap", 1)) == 2:
				# (the direction twice quickly: the second press while the first move's lock still runs switches it, as key 3
				# tapped twice did)
				for i in 2:
					await physics_frame
				_ctl.set_held(&"move_forward", false)
				await physics_frame
				await physics_frame
				_ctl.set_held(&"move_forward", true)
			await _frames(0.08)
			await _frames(0.35)
			_ctl.set_held(&"move_forward", false)
			_ctl.set_held(&"sprint", false)
			await _frames(SHOT_S - 0.5)
		"guard":
			var foe := mode.foe
			var nb: NpcBending = foe.brain.bending if foe.brain != null else null
			var k1 := Bending.first_of(Bending.keys(_el)[0])
			var bs: Dictionary = (SwayMoves.move(String(k1.id)).get("bend", {}) as Dictionary).get(String(k1.mode), {})
			# (E as a player times it: a fast strike (FAST_MPS and up: the Whip, the Slice) is on you before you could see it fly,
			# so E goes up as he winds up, GUARD_LEAD_S before his cast; a slower one as it is GUARD_ETA_S out (the guard's short
			# lock, then its perfect_s). E up before a slow fireball was cast, it came late, half through, nothing went back)
			var fast := float(bs.get("mps", 0.0)) >= FAST_MPS
			if fast:
				await physics_frame
				_ctl.set_held(InputSetup.GUARD_ACTION, true)
				await _frames(GUARD_LEAD_S)
			if nb != null:
				nb.begin(String(k1.id), String(k1.mode))
				nb._release()
			if not fast:
				var waited := 0.0
				while waited < 2.5 and _eta(foe) > GUARD_ETA_S:
					await physics_frame
					waited += 1.0 / Engine.physics_ticks_per_second
				_ctl.set_held(InputSetup.GUARD_ACTION, true)
			await _frames(1.3)
			_ctl.set_held(InputSetup.GUARD_ACTION, false)
			await _frames(0.15)
			_ctl.set_held(InputSetup.GUARD_ACTION, true)        # (E again: earth throws back the stone it holds)
			await _frames(0.12)
			_ctl.set_held(InputSetup.GUARD_ACTION, false)
			await _frames(SHOT_S - 0.5)
		"cast":
			var id := String(sh.id)
			var md := String(sh.mode)
			if id == "patch":
				mode.rules.add_pct(player, 25.0, mode.foe, "reel")
			if id == "mend":
				await _cast_one("earth_wall" if _el == "earth" else "water_shield", "", false)
				await _frames(0.8)
				var w := _wear_wall()                    # (mend packs only a worn wall: a fresh one is refused, "Nothing to mend")
				await _frames(0.6)
				if w != null:                            # (and reaches 3 m, moves.json range_m: walked up to the wall)
					var back := player.global_position - w.global_position
					back.y = 0.0
					player.global_position = w.global_position + back.normalized() * 2.0 + Vector3.UP * (player.global_position.y - w.global_position.y)
					player.velocity = Vector3.ZERO
					_aim_node = w                        # (aimed at the wall's face: the camera's ray at his chest goes over it)
					await _frames(0.4)
			await _cast_one(id, md, bool(sh.get("grown", false)))
			_aim_node = null
			await _frames(SHOT_S)


## The newest raised wall worn by two hits on the caster's face of it (its chips show), so mend has something to pack; the wall.
func _wear_wall() -> FormRaised:
	var w: FormRaised = null
	for n in player.get_tree().get_nodes_in_group(FormRaised.GROUP):
		if n is FormRaised and (n as FormRaised).is_up() and (w == null or n.get_instance_id() > w.get_instance_id()):
			w = n
	if w == null:
		return null
	var dir := (w.global_position - player.global_position)
	dir.y = 0.0
	dir = dir.normalized()
	for i in 2:
		w.apply_hit(w.hit_min + 1.0, w.global_position - dir * 0.6 + Vector3.UP * (1.0 + 0.4 * i), dir)
	return w


## Seconds until the nearest bolt flying at the player reaches him (INF: none; only `by` casts in a guard shot, so any bolt
## coming his way is his).
func _eta(_by: Node3D) -> float:
	var best := INF
	var me := player.global_position + Vector3.UP * 1.0
	for n in player.get_tree().get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b == null or not is_instance_valid(b) or b.spent:
			continue
		var sp := b.velocity.length()
		var to := me - b.global_position
		if sp < 0.5 or to.length() > 16.0 or b.velocity.dot(to) <= 0.0:
			continue
		best = minf(best, maxf(to.length() - 0.8, 0.0) / sp)
	for n in player.get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := n as FormStone                  # (earth's thrown stones: Stone Form's spike and boulder)
		if st == null or not is_instance_valid(st):
			continue
		var v := st.linear_velocity
		var to2 := me - st.global_position
		if v.length() < 3.0 or to2.length() > 16.0 or v.dot(to2) <= 0.0:
			continue
		best = minf(best, maxf(to2.length() - 0.8, 0.0) / v.length())
	return best


## One cast of `id` at `md` through the keys: its key pressed (a second press for a key's other move or mode), the mode set,
## right-click held until the lock is full (grown: until it grew, at most 3 s more), let go.
func _cast_one(id: String, md: String, grown: bool) -> void:
	var sc := SwayCaster.of(player)
	var k := Bending.key_of(_el, id)
	if id in Bending.key3(_el):
		await _key(&"weapon_3")                          # (key 3's own move: 3 readies it, Hotbar.select)
	elif k >= 0:
		var a := StringName("weapon_%d" % (k + 1))
		await _key(a)                                    # (the key, as a player presses it: the strip lights it)
		var first := Bending.first_of(Bending.keys(_el)[k])
		if String(first.get("id", "")) != id or (md != "" and String(first.get("mode", "")) != md):
			await _key(a)                                # (the key's other move: tapped twice, as a player does; the hotbar
			                                             # keeps the key's own readied, so a direct ready would not stand)
	if sc.readied_spell != id:
		print("MOVE REEL READY FALLBACK %s (the keys readied %s)" % [id, sc.readied_spell])
		sc.ready_spell(id)
	if md != "" and sc.mode_of(id) != md:
		sc.set_mode(id, md)
	await _frames(0.1)
	_ctl.set_held(&"aim", true)
	var t := 0.0
	while t < 4.0:
		await _frames(1.0 / fps)
		t += 1.0 / fps
		if sc.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]:
			break
	if grown:
		# (held on: it grows grow_after_s past full, SwayCaster._grow, and goes by itself at its release window)
		var g := 0.0
		while g < 3.0 and not sc.grown:
			await _frames(1.0 / fps)
			g += 1.0 / fps
		await _frames(0.15)
	_ctl.set_held(&"aim", false)


# --- the picture -----------------------------------------------------------------------------------------------------------

## The side camera: across the deck from the shot's staged middle, a little toward the player's end, both in the picture; still
## for the whole shot.
func _cam(_dt: float) -> Array:
	var ring := mode.ring
	var ax := ring.axis()
	var across := ax.cross(Vector3.UP).normalized()
	var mid := _cam_mid
	if String(args.get("cam", "")) == "behind":
		# (cam=behind: over the player's shoulder at the shot's start, toward the foe, as a player sees it: walls and blades
		# are drawn across the line between them, edge-on from the side)
		var pp := _cam_from if _cam_from.is_finite() else player.global_position
		var foe: Node3D = mode.foe
		var to := ((foe.global_position if foe != null and is_instance_valid(foe) else mid) - pp)
		to.y = 0.0
		to = to.normalized() if to.length_squared() > 1e-4 else ax
		var side := to.cross(Vector3.UP).normalized()
		return [pp - to * 3.6 + side * 0.9 + Vector3.UP * 2.1, pp + to * 6.0 + Vector3.UP * 1.0, 55.0]
	var pos := mid + across * CAM_SIDE + Vector3.UP * CAM_UP - ax * 0.6
	return [pos, mid, CAM_FOV]


## The game's HUD out of the picture (the captions are the film's own), as the team film does for its script shots.
func _hide_hud() -> void:
	super._hide_hud()
	if use_cine:
		for n in root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			if cl == overlay or not cl.visible or view.is_ancestor_of(cl) or cl.custom_viewport != view:
				continue
			cl.visible = false
			_hid.append(cl)
