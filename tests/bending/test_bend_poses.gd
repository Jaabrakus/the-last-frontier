extends SceneTree
## The bending moves' own cast poses and their strike (BendPoses, data/bending/poses.json; SwayPose.struck, strike_wait,
## strike_point, current_clip; SwayCaster's deferred strike; NpcBody.play_cast), on the real level, in the duel:
##   provenance  every clip poses.json names (and NpcBody.FORM_CLIPS') is in one of our own libraries (BendPoses.LIBRARIES),
##               named own-, with an authored meta and none of native_asset_id / source_attribution / original_name, not
##               excluded (nor own-axe-d, -w, -a: measured off reference swings), with a row in animations/SOURCE.md;
##               every pose's timing within its clip
##   the pick    a variation's own pose over the skill's over the element's default (a bend spec only); an excluded or a
##               missing clip passed over; the Sway's old spells without a pose keep their tier clip
##   the poses   held_override in the duel: Earth Wall wall plays own-bend-earth-raise (the stomp-rise) and roots the
##               caster, Stone boulder own-bend-earth-boulder (the owner's "left kick to stomp and then push") rooted, Fire Jab
##               jab own-bend-fire-punch, Air Shield shield own-bend-air-shield (its first mapping, own-axe-block-high, is held back:
##               poses.json exclude_why), Gust push (no bend spec, no pose) its mastery tier's clip
##   the strike  a synthetic clip (hold_s 0.2, strike_s 0.3) on Fire Blast punch: the bolt leaves 0.08 s or more after the
##               release, as the pose says struck, from the pose's hand; a Catch on the same clip stands the very frame the
##               lock lets go; the pose taken away after a release, the fallback timer still lands the bolt within 0.25 s
##   bots        NpcBody.play_cast: its library holds every pose clip; strike / rate == wind_s within 1 ms, in either
##               argument order; the plain push ("cast_push") for a move without a pose; a floor cast's strike its press
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_poses.gd -- mode=duel

const NAME := "BEND POSES"
## The in-test watchdog (below the run's GODOT_TIMEOUT of 300 s).
const LIMIT_S := 240.0

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(_watchdog)
	DuelMode.incoming = true
	_provenance()
	_picks()
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _watchdog() -> void:
	print(NAME + " FAILED (watchdog)")
	quit(2)


func _end() -> void:
	BendPoses.override = {}
	BendPoses.extra_library = null
	if p != null and is_instance_valid(p) and c != null and is_instance_valid(c):
		c.held_override = null
	print(NAME + (" PASSED" if fails == 0 else " FAILED"))
	quit(0 if fails == 0 else 1)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


# ---------------------------------------------------------------- provenance (no scene)
func _provenance() -> void:
	var src := FileAccess.get_file_as_string("res://animations/SOURCE.md")
	var names := BendPoses.all_clips()
	for k: String in NpcBody.FORM_CLIPS:
		var nm := String(NpcBody.FORM_CLIPS[k][0])
		if not nm in names:
			names.append(nm)
	var bad: Array[String] = []
	for nm: String in names:
		var a := BendPoses.animation(nm)
		var lib := BendPoses.library_of(nm)
		var why := ""
		if a == null:
			why = "in no library"
		elif not lib in BendPoses.LIBRARIES:
			why = "not one of our own libraries (%s)" % lib
		elif not nm.begins_with("own-"):
			why = "not named own-"
		elif BendPoses.excluded(nm) or nm.begins_with("own-axe-d") or nm.begins_with("own-axe-w") or nm.begins_with("own-axe-a"):
			why = "excluded"
		elif not a.has_meta(&"authored"):
			why = "no authored meta"
		else:
			for k: StringName in [&"native_asset_id", &"source_attribution", &"original_name"]:
				if a.has_meta(k):
					why = "carries " + String(k)
		if why == "" and not ("`%s`" % nm) in src:
			why = "no row in animations/SOURCE.md"
		if why != "":
			bad.append("%s: %s" % [nm, why])
	_expect(bad.is_empty() and names.size() >= 8, "every pose clip (%d) is ours: an own library, own-, authored, no inherited ids, not excluded, in SOURCE.md%s"
			% [names.size(), "" if bad.is_empty() else " -- " + "; ".join(bad)])
	var ex: Array = BendPoses.data().get("exclude", [])
	_expect("own-axe-d" in ex and "own-axe-w" in ex and "own-axe-a" in ex, "exclude names own-axe-d, -w and -a")
	# the timing of each pose within its clip
	var off: Array[String] = []
	var clips: Dictionary = BendPoses.data().get("clips", {})
	for nm: String in clips:
		var row: Dictionary = clips[nm]
		var a := BendPoses.animation(nm)
		var rel := BendPoses.animation(String(row.get("then", nm)))
		if a == null or rel == null:
			off.append(nm + ": no clip")
			continue
		var hold := float(row.get("hold_s", a.get_meta(&"hold_s", a.length)))
		var strike := float(row.get("strike_s", -1.0))
		if hold > a.length + 0.001 or strike > rel.length + 0.001 or (not row.has("then") and strike >= 0.0 and strike < hold - 0.001):
			off.append("%s: hold %.2f strike %.2f of %.2f" % [nm, hold, strike, a.length])
	_expect(off.is_empty(), "every pose's hold and strike within its clip%s" % ("" if off.is_empty() else ": " + ", ".join(off)))


# ---------------------------------------------------------------- the pick (no scene)
func _picks() -> void:
	BendPoses.override = {"moves": {"fire_blast": {"pose": "own-sway-push-two", "modes": {"punch": "own-axe-stab", "fireball": "own-axe-d"}}}}
	var a := BendPoses.pick("fire_blast", "punch", "fire")
	var b := BendPoses.pick("fire_blast", "stream", "fire")
	var x := BendPoses.pick("fire_blast", "fireball", "fire")
	_expect(String(a.get("clip", "")) == "own-axe-stab" and String(a.get("from", "")) == "mode",
			"the variation's own pose first (%s from %s)" % [a.get("clip", "-"), a.get("from", "-")])
	_expect(String(b.get("clip", "")) == "own-sway-push-two" and String(b.get("from", "")) == "move",
			"then the skill's (%s from %s)" % [b.get("clip", "-"), b.get("from", "-")])
	_expect(String(x.get("clip", "")) == "own-sway-push-two", "an excluded clip (own-axe-d) passed over (%s)" % x.get("clip", "-"))
	BendPoses.override = {"moves": {"fire_blast": {"modes": {"punch": "own-no-such-clip"}}}}
	var d := BendPoses.pick("fire_blast", "punch", "fire")
	var want := String(BendPoses.data().cast.fire)
	_expect(String(d.get("clip", "")) == want and String(d.get("from", "")) == "cast",
			"a missing clip passed over to the element's default (%s from %s)" % [d.get("clip", "-"), d.get("from", "-")])
	BendPoses.override = {}
	var g := BendPoses.pick("gust", "push", "air")
	var gp := BendPoses.pick("gust", "pull", "air")
	_expect(g.is_empty() and String(gp.get("clip", "")) == "own-forage-grab-r",
			"Gust push (no bend spec, no pose) none: its tier clip; Gust pull its own (%s)" % gp.get("clip", "-"))
	var j := BendPoses.pick("fire_jab", "jab", "fire")
	_expect(String(j.get("clip", "")) == "own-bend-fire-punch" and is_equal_approx(float(j.get("strike_s", -1.0)), 8.0 / 30.0)
			and String(j.get("hand", "")) == "r_palm" and j.has("hold_s") and String(j.get("alt", "")) == "own-bend-fire-punch-l",
			"a pick filled from the clips table and the clip's metas, its alt the other hand (%s)" % str(j))
	var ew := BendPoses.pick("earth_wall", "wall", "earth")
	_expect(String(ew.get("clip", "")) == "own-bend-earth-raise" and bool(ew.get("root", false)) and String(ew.get("mask", "")) == "full",
			"Earth Wall: the stomp-rise, whole and rooted (%s)" % str(ew))
	var bo := BendPoses.pick("stone_form", "cannonball", "earth")
	var bclip := BendPoses.animation(String(bo.get("clip", "")))
	_expect(String(bo.get("clip", "")) == "own-bend-earth-boulder" and bool(bo.get("root", false)) and bclip != null
			and float(bo.get("hold_s", -1.0)) < float(bo.get("strike_s", -1.0)) and String(bo.get("hand", "")) == "both",
			"Stone boulder: the kick, the stomp, the two-hand push (strike %.2f s, after its hold %.2f s)" % [float(bo.get("strike_s", -1.0)),
			float(bo.get("hold_s", -1.0))])
	# every element's stance names an own looping clip; every bending move of the four elements has an own pose
	var st: Dictionary = BendPoses.data().get("stance", {})
	var bad: Array[String] = []
	for el: String in Bending.ELEMENTS:
		var nm := SwayPose.stance_name(el)
		var a2 := BendPoses.animation(nm)
		if nm != "own-bend-stance-" + el or a2 == null or a2.loop_mode != Animation.LOOP_LINEAR:
			bad.append("%s: %s" % [el, st.get(el, "-")])
	_expect(bad.is_empty(), "each element's stance is its own loop (own-bend-stance-<element>)%s" % ("" if bad.is_empty() else ": " + ", ".join(bad)))
	var tiers: Array[String] = []
	for m: String in (BendPoses.data().get("moves", {}) as Dictionary):
		var mv := SwayMoves.move(m)
		var el2 := String(mv.get("element", ""))
		if not el2 in Bending.ELEMENTS:
			continue
		for md: String in (mv.get("bend", {}) as Dictionary):
			var pk := BendPoses.pick(m, md, el2)
			if pk.is_empty() or not String(pk.clip).begins_with("own-"):
				tiers.append("%s/%s" % [m, md])
	_expect(tiers.size() <= 8, "nearly every bending move has an own pose (%d without: %s)" % [tiers.size(), ", ".join(tiers)])


# ---------------------------------------------------------------- in the duel
func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null and c.pose != null, "the duel, its player, his caster and pose")
	if c == null or c.pose == null:
		return _end()
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	if n != null:
		n.held = true
	DuelMode.element = "earth"
	_expect(BendPoses.element_of(p) == "earth", "the duel's player casts as his element (%s)" % BendPoses.element_of(p))
	await _poses()
	await _stance()
	await _combo()
	await _bots()
	await _strike()
	_end()


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z), v.z)


## The player in the arena facing +x, the bender `d` m before him, held still and whole.
func _stage(d := 9.0) -> void:
	var at := duel.arena.center() + Vector3(-6.0, 0.0, 6.0)
	p.global_position = _ground(at) + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	if n != null and is_instance_valid(n):
		n.held = true
		n.global_position = _ground(at + Vector3(d, 0.0, 0.0)) + Vector3.UP * 0.05
		n.velocity = Vector3.ZERO
		n.health = n.health_max
		n.action = ""


func _aim(pt: Vector3) -> void:
	var d := pt - p.camera.global_position
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Readies `id` in `mode` as the player does (onto the bar's last slot when it is not on the bar).
func _ready_spell(id: String, mode: String) -> bool:
	var hb := p.hotbar
	if hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	var ok := c.ready_spell(id)
	c.set_mode(id, mode)
	return ok and c.readied_spell == id and c.mode_of(id) == mode


## The aim held (held_override) on `pt` (INF: anywhere) until `cond` or `limit` s; the seconds it took (INF: never).
func _hold_until(pt: Vector3, cond: Callable, limit := 2.0) -> float:
	c.held_override = true
	var t := 0.0
	while t < limit:
		if pt != Vector3.INF:
			_aim(pt)
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if cond.call():
			return t
	return INF


func _let_go_and_settle() -> void:
	c.held_override = false
	await _secs(0.9)


func _poses() -> void:
	var cases := [
		["earth", "earth_wall", "wall", "own-bend-earth-raise", true],
		["earth", "stone_form", "cannonball", "own-bend-earth-boulder", true],
		["fire", "fire_jab", "jab", "own-bend-fire-punch", false],
		["air", "air_shield", "shield", "own-bend-air-shield", false],
		["air", "gust", "push", String(SwayPose.clip_for(2)), false],
	]
	for cs: Array in cases:
		DuelMode.element = String(cs[0])
		_stage()
		await _secs(0.2)
		var id := String(cs[1])
		var mode := String(cs[2])
		var ok := _ready_spell(id, mode)
		var pt := Vector3.INF
		if id == "earth_wall":
			pt = _ground(p.global_position + Vector3(4.0, 0.0, 0.0))
		elif id == "stone_form" and n != null:
			pt = NpcSenses.chest_of(n)
		elif id == "gust" and n != null:
			pt = NpcSenses.chest_of(n)
		var t := await _hold_until(pt, func() -> bool: return c.state != SwayCaster.State.IDLE)
		await _secs(0.15)
		var clip := String(c.pose.current_clip())
		var tier_clip := String(SwayPose.clip_for(c.tier(id)))
		var want := String(cs[3]) if id != "gust" else tier_clip
		_expect(ok and t != INF and clip == want and c.rooted == bool(cs[4]),
				"%s: %s %s plays %s%s (%s; lock %s, rooted %s)" % [cs[0], id, mode, want, ", rooted" if cs[4] else "",
				clip, "on" if t != INF else "never began (hint '%s', blocked '%s')" % [c.hint, c.blocked()], c.rooted])
		await _let_go_and_settle()
	_expect(c.pose.phase == "" and not c.rooted, "let go: the pose over, the caster free (%s)" % c.pose.phase)


# ---------------------------------------------------------------- the stance and the combo
## The element the player casts as: the duel's and his Bending node's (BendPoses.element_of reads the node first).
func _element(el: String) -> void:
	DuelMode.element = el
	Bending.of(p).element = el


func _stance() -> void:
	_element("earth")
	_stage()
	await _secs(1.2)
	var w := c.pose.stance_weight()
	var hf := "hands_free %s, weapon %s, on floor %s, speed %.2f" % [p.hands_free, p.weapon, p.is_on_floor(), p.horizontal_speed()]
	_expect(String(c.pose.stance_clip()) == "own-bend-stance-earth" and w > 0.95 and c.pose._pose != null and c.pose._pose.active,
			"standing still as earth: the earth stance loops on the body (%s, weight %.2f; %s)" % [c.pose.stance_clip(), w, hf])
	_element("water")
	await _secs(0.8)
	_expect(String(c.pose.stance_clip()) == "own-bend-stance-water" and c.pose.stance_weight() > 0.9,
			"as water: the water stance (%s, %.2f)" % [c.pose.stance_clip(), c.pose.stance_weight()])
	Input.action_press("move_forward")
	var lo := 1.0
	for i in int(0.8 * Engine.physics_ticks_per_second):
		await physics_frame
		lo = minf(lo, c.pose.stance_weight())
	Input.action_release("move_forward")
	_expect(lo < 0.05, "walking: the stance gives way to the legs (weight down to %.2f at %.2f m/s)" % [lo, p.horizontal_speed()])
	await _secs(0.8)
	_expect(c.pose.stance_weight() > 0.9, "still again: the stance back (%.2f)" % c.pose.stance_weight())
	# a cast over the stance: the cast's clip on the body, the stance under it
	_stage()
	await _secs(0.3)
	_ready_spell("water_whip", "whip")
	var t := await _hold_until(Vector3.INF, func() -> bool: return c.state != SwayCaster.State.IDLE)
	await _secs(0.15)
	var ls: Array = c.pose._pose.layers if c.pose._pose != null else []
	_expect(t != INF and ls.size() >= 2 and (ls[0] as Dictionary).anim == BendPoses.animation("own-bend-stance-water")
			and String(c.pose.current_clip()).begins_with("own-bend-water-whip"),
			"a lock over the stance: the stance's layer first, the cast's over it (%s over %d layers)" % [c.pose.current_clip(), ls.size()])
	await _let_go_and_settle()


func _combo() -> void:
	_element("fire")
	_stage(14.0)
	await _secs(0.3)
	_ready_spell("fire_blast", "punch")
	var seen: Array[String] = []
	for i in 3:
		var t := await _hold_until(Vector3.INF, func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
		seen.append(String(c.pose.current_clip()) if t != INF else "no lock")
		c.held_override = false
		await _secs(0.12)
	_expect(seen == ["own-bend-fire-punch", "own-bend-fire-punch-l", "own-bend-fire-punch"],
			"Fire Blast punch three times in a row: right, left, right (%s)" % ", ".join(seen))
	await _secs(1.2)
	var t2 := await _hold_until(Vector3.INF, func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	_expect(t2 != INF and String(c.pose.current_clip()) == "own-bend-fire-punch",
			"after a pause past the combo window: the right hand again (%s)" % c.pose.current_clip())
	await _let_go_and_settle()


# ---------------------------------------------------------------- bots
func _bots() -> void:
	if n == null or n.body == null:
		_expect(false, "the duel's bender and his body")
		return
	var b := n.body
	var missing: Array[String] = []
	for nm: String in BendPoses.all_clips():
		if not b.has_clip(nm):
			missing.append(nm)
	_expect(missing.is_empty() and b.has_clip("cast_push"), "the bot's library holds every pose clip and cast_push%s" % ("" if missing.is_empty() else ": missing " + ", ".join(missing)))
	var r1 := b.play_cast("fire_jab", "jab", 0.5, "fire")
	var k1 := b.cast_clip
	var s1 := b.cast_strike_s
	var cur := String(b.ap.current_animation) if b.ap != null else ""
	_expect(k1.begins_with("own-bend-fire-punch") and r1 > 0.0 and absf(s1 / r1 - 0.5) < 0.001 and cur.ends_with(k1),
			"Fire Jab on the bot: %s at %.3f x, its strike (%.2f s in the clip) %.4f s from now (wind 0.5)" % [k1, r1, s1, s1 / maxf(r1, 1e-6)])
	var r2 := b.play_cast("fire_jab", "jab", "fire", 0.5)
	var k2 := b.cast_clip
	_expect(is_equal_approx(r1, r2) and k2.begins_with("own-bend-fire-punch") and k2 != k1,
			"the order (move, mode, element, wind_s) the same (%.3f), and the next cast the other hand (%s, then %s)" % [r2, k1, k2])
	_expect(b.cast_pick.get("hand", "") in ["r_palm", "l_palm"], "the bot's pick names the game's limb (%s)" % b.cast_pick.get("hand", "-"))
	var r3 := b.play_cast("gust", "push", 0.6, "air")
	_expect(b.cast_clip == "cast_push" and r3 > 0.0 and absf(b.cast_strike_s / r3 - 0.6) < 0.001,
			"Gust push (no pose): the plain push, its push_s on the launch (%s, %.4f s)" % [b.cast_clip, b.cast_strike_s / maxf(r3, 1e-6)])
	var r5 := b.play_cast("earth_wall", "wall", 0.9, "earth")
	_expect(b.cast_clip == "own-bend-earth-raise" and absf(b.cast_strike_s / r5 - 0.9) < 0.001,
			"Earth Wall on the bot: the stomp-rise, its strike (%.2f s) on the launch (%.4f s)" % [b.cast_strike_s, b.cast_strike_s / maxf(r5, 1e-6)])
	# (the floor cast's press, a release of another clip: mapped for the check)
	BendPoses.override = {"moves": {"earth_wall": {"modes": {"wall": "own-form-clap-press"}}}}
	var r4 := b.play_cast("earth_wall", "wall", 0.9, "earth")
	BendPoses.override = {}
	_expect(b.cast_clip == "own-form-clap-press" and absf(b.cast_strike_s / r4 - 0.9) < 0.001 and b.cast_strike_s > 0.5,
			"a floor cast on the bot: its press (%.2f s) on the launch (%.4f s)" % [b.cast_strike_s, b.cast_strike_s / maxf(r4, 1e-6)])
	# the stance: an element bot's idle is its element's own loop
	# (the stance only while he fights: held, he stands at the plain idle; let go for the check, held again at once)
	var el0: String = n.element
	n.element = "fire"
	b.clip = ""
	b.play("idle", 0.0)
	var held_cur := String(b.ap.current_animation) if b.ap != null else ""
	n.held = false
	b.play("idle", 0.0)
	var cur2 := String(b.ap.current_animation) if b.ap != null else ""
	n.held = true
	_expect(held_cur.ends_with("/idle") and b.clip == "idle" and cur2.ends_with("stance_fire")
			and b.ap.get_animation(cur2).loop_mode == Animation.LOOP_LINEAR,
			"a fire bot idles in the fire stance while it fights, looping (%s; clip %s); held, the plain idle (%s)" % [cur2, b.clip, held_cur])
	n.element = ""
	n.held = false
	b.play("idle", 0.0)
	cur2 = String(b.ap.current_animation) if b.ap != null else ""
	n.held = true
	_expect(cur2.ends_with("/idle"), "a bot of no element idles as before (%s)" % cur2)
	n.element = el0
	b.play("idle", 0.0)
	var sp := b.strike_point()
	_expect(sp.is_finite() and sp.distance_to(n.global_position) < 2.5, "the bot's strike point at his hands (%.2f m off his feet)" % sp.distance_to(n.global_position))
	await _secs(1.0)


# ---------------------------------------------------------------- the strike
func _bolts() -> int:
	var k := 0
	for x in get_nodes_in_group(BendBolt.GROUP):
		if is_instance_valid(x) and (x as BendBolt).caster == p:
			k += 1
	return k


func _strike() -> void:
	var a := Animation.new()
	a.length = 0.6
	a.set_meta(&"hold_s", 0.2)
	a.set_meta(&"strike_s", 0.3)
	a.set_meta(&"back_s", 0.4)
	a.set_meta(&"hand", "r_palm")
	a.set_meta(&"authored", "tests/bending/test_bend_poses.gd: a synthetic clip with no tracks")
	var lib := AnimationLibrary.new()
	lib.add_animation(&"own-test-strike", a)
	BendPoses.extra_library = lib
	BendPoses.override = {"moves": {"fire_blast": {"modes": {"punch": "own-test-strike"}}, "stone_catch": {"modes": {"catch": "own-test-strike"}}}}
	# --- Fire Blast punch: the bolt leaves on the strike
	DuelMode.element = "fire"
	_stage(14.0)
	await _secs(0.2)
	_ready_spell("fire_blast", "punch")
	var full := await _hold_until(Vector3.INF, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _secs(0.1)
	var wait := c.pose.strike_wait()
	_expect(full != INF and String(c.pose.current_clip()) == "own-test-strike" and absf(wait - 0.1) < 0.02,
			"Fire Blast punch locks on the synthetic clip (%s), its strike %.3f s past the hold" % [c.pose.current_clip(), wait])
	BendEffects.last = {"do": "sentinel"}
	var rec := {"cast_f": -1, "at_cast": "", "struck_f": -1, "struck_do": "", "point": Vector3.INF}
	var on_cast := func(_m: String, _t: Node3D) -> void:
		rec.cast_f = Engine.get_physics_frames()
		rec.at_cast = String(BendEffects.last.get("do", ""))
	var on_struck := func(_m: String) -> void:
		rec.struck_f = Engine.get_physics_frames()
		rec.struck_do = String(BendEffects.last.get("do", ""))
		rec.point = c.pose.strike_point()
	c.cast.connect(on_cast, CONNECT_ONE_SHOT)
	c.pose.struck.connect(on_struck, CONNECT_ONE_SHOT)
	var b0 := _bolts()
	c.held_override = false
	var t := 0.0
	while t < 1.0 and String(BendEffects.last.get("do", "")) == "sentinel":
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	var landed_f := Engine.get_physics_frames()
	var dt := float(landed_f - int(rec.cast_f)) / Engine.physics_ticks_per_second
	var chest := p.global_position + Vector3.UP * 1.35
	_expect(rec.at_cast == "sentinel" and String(BendEffects.last.get("do", "")) == "bolt" and dt >= 0.08 and dt <= 0.16,
			"the bolt leaves on the strike: nothing at the release (%s), a bolt %.3f s after it" % [rec.at_cast, dt])
	_expect(int(rec.struck_f) >= 0 and rec.struck_do == "bolt" and _bolts() > b0,
			"as the pose says struck (the effect landed by then: %s), a bolt of his in the air" % rec.struck_do)
	var pt: Vector3 = rec.point
	_expect(pt.is_finite() and pt.distance_to(chest) < 1.2, "struck from the pose's hand (%.2f m from the chest)" % (pt.distance_to(chest) if pt.is_finite() else INF))
	await _let_go_and_settle()
	# --- a Catch on a strike_s clip: the guard stands the frame the lock lets go
	DuelMode.element = "earth"
	_stage(14.0)
	await _secs(0.2)
	_ready_spell("stone_catch", "catch")
	full = await _hold_until(Vector3.INF, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _secs(0.1)
	var cwait := c.pose.strike_wait()
	BendEffects.last = {"do": "sentinel"}
	var seen := {"do": "", "zones": 0}
	var on_catch := func(_m: String, _t: Node3D) -> void:
		seen.do = String(BendEffects.last.get("do", ""))
		for z in get_nodes_in_group(BendZone.GROUP):
			if is_instance_valid(z) and (z as BendZone).kind == "catch" and (z as BendZone).owner_node == p:
				seen.zones = int(seen.zones) + 1
	c.cast.connect(on_catch, CONNECT_ONE_SHOT)
	c.held_override = false
	await physics_frame
	await physics_frame
	_expect(full != INF and cwait > 0.05 and seen.do == "zone" and int(seen.zones) >= 1,
			"a Catch on a clip with a strike (%.2f s off) stands the frame the lock lets go (%s, %d catch)" % [cwait, seen.do, seen.zones])
	await _let_go_and_settle()
	# --- the pose taken away after the release: the fallback lands the bolt
	DuelMode.element = "fire"
	_stage(14.0)
	await _secs(0.2)
	_ready_spell("fire_blast", "punch")
	full = await _hold_until(Vector3.INF, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _secs(0.1)
	BendEffects.last = {"do": "sentinel"}
	var rec2 := {"cast_f": -1}
	var cut := func(_m: String, _t: Node3D) -> void:
		rec2.cast_f = Engine.get_physics_frames()
		var po := c.pose
		c.pose = null                                      # (gone: no struck will come)
		po.queue_free()
	c.cast.connect(cut, CONNECT_ONE_SHOT)
	c.held_override = false
	t = 0.0
	while t < 1.0 and String(BendEffects.last.get("do", "")) == "sentinel":
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	var dt2 := float(Engine.get_physics_frames() - int(rec2.cast_f)) / Engine.physics_ticks_per_second
	_expect(full != INF and int(rec2.cast_f) >= 0 and String(BendEffects.last.get("do", "")) == "bolt" and dt2 >= 0.15 and dt2 <= 0.25,
			"the pose taken away: the fallback timer lands the bolt %.3f s after the release (within 0.25 s)" % dt2)
	c.held_override = false
	BendPoses.override = {}
	BendPoses.extra_library = null
