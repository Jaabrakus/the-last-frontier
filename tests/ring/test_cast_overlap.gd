extends SceneTree
## One at a time (the owner, 2026-10-12: "he was able to get a fire knock up and a fireball at the same time" ... "that shouldnt
## be allowed right?"; his rule: moves come out one at a time and nothing is ever forced out early; the next lock may begin and
## fill while the last cast still waits on its strike, but it is not let go before that one has landed at its own strike: a
## release made meanwhile is kept and goes the moment it lands). In the real ring (scenes/ring.tscn: a 1v1 practice, the
## standing dummy, stock rules: round 3 on, the radial scheme), fire, every cast through the real input actions (the hotbar's
## keys, the aim, E, key 3; PlayerControls as a test drives them), each release (SwayCaster.cast_released) and each effect
## leaving (its bolt or zone entering the tree) timed on the bend clock; the dummy stands out of every cast's way (nothing is
## hit: no hit-stop or follow-up times a lock):
##   K  the Kick (its floor wave lands on the release: no strike wait) then key 1 and the aim at once: the wave on its release;
##      the Punch's bolt after it, its own strike wait after its release
##   A  the High Kick (a throw: it leaves on its pose's strike) full, then key 1 and the aim at once, the Punch's lock begun while
##      the High Kick still waits on its strike: the High Kick leaves at its own strike, not as the next lock begins (before the
##      fix SwayPose told the strike as the next lock began, and SwayCaster's next release forced a waiting cast out); the
##      Punch's bolt after it, at least the High Kick's strike wait apart
##   B  the same with head starts (FireTalents.give_head_start, as a worn technique gives one): the High Kick let go early in
##      its wind-up waits longer on its strike, the Punch's lock is full and let go before that strike: the Punch is kept and
##      goes the moment the High Kick has landed (not before it, not later than a tick after); the High Kick at its own strike;
##      the Punch's bolt its own strike wait after its (kept) release
##   D  the High Kick (head start) then E tapped: the guard's lock full before the High Kick's strike; the guard stands the
##      moment the High Kick has landed (never delayed beyond it), its zone that frame; the High Kick at its own strike
##   C  nothing waiting, nothing delayed: E tapped (the guard: no strike wait) stands the frame its lock fills, its zone that
##      frame; key 3 tapped (the dash) goes the frame it may (its lock full, key3_min_s after the press), the dash that frame
## Exit 0 when every check passes, 1 otherwise ("OVERLAP FAIL" lines name each; a scenario whose overlap was not reached
## fails as "not reached", never passes unexamined).
##   GODOT_TIMEOUT=600 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier \
##     -s tests/ring/test_cast_overlap.gd -- [only=K,A,B,D,C] [out=<dir>] [tag=<name>]
## VERIFICATION ONLY, before the patch is applied: overlay=<dir> swaps the game's scripts for <dir>/<res path> copies in memory
## (GDScript.reload, before the ring loads; nothing on disk changes), so the patched code can be tested on a read-only checkout.

const OWN_CFG := "user://cast_overlap_test.cfg"
## The pose's clock (SwayPose ticks once a rendered frame: --fixed-fps 60), the grain a strike is told on.
const FRAME := 1.0 / 60.0
## The order the overlay's scripts are reloaded in.
const OVERLAY_ORDER := ["scripts/sway/sway_pose.gd", "scripts/sway/sway_caster.gd"]

var opts := {"only": "K,A,B,D,C", "overlay": "", "out": "", "tag": "test"}

var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var aiming := false
var spot := Vector3.ZERO
var settle_err_deg := 0.0
## A physics step (s): the grain a release and a cast's things land on (the project ticks at 120).
var tick := 1.0 / 120.0
## Everything timed: {ev "lock" | "full" | "release" | "effect", t (BendStatus.now()), m, md, src, tag, kind, wait, pending}.
var events: Array = []
var fails: Array = []
var checks := 0
var rows: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		if opts.has(key):
			opts[key] = arg.substr(key.length() + 1)
	if String(opts.out) != "":
		DirAccess.make_dir_recursive_absolute(opts.out)
	if String(opts.overlay) != "" and not _overlay(String(opts.overlay)):
		_finish("overlay failed")
		return
	seed(4242)
	tick = 1.0 / float(Engine.physics_ticks_per_second)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._scheme = "radial"
	MatchSetup._aim_help = "light"
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = true
	MatchSetup.my_pct = -1.0
	MatchSetup.foe_pct = -1.0
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	create_timer(560.0, true, false, true).timeout.connect(func() -> void: _finish("watchdog"))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


## The patched scripts swapped in, in memory (verification only).
func _overlay(dir: String) -> bool:
	for rel: String in OVERLAY_ORDER:
		var src := dir.path_join(rel)
		if not FileAccess.file_exists(src):
			continue
		var s := load("res://" + rel) as GDScript
		if s == null:
			push_error("OVERLAP overlay: no script res://" + rel)
			return false
		s.source_code = FileAccess.get_file_as_string(src)
		var err := s.reload(false)
		print("OVERLAP OVERLAY %s err=%d" % [rel, err])
		if err != OK:
			return false
	return true


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null or mode.foe == null:
		_finish("no ring")
		return
	p = mode.player
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	if c == null or c.pose == null:
		_finish("no caster")
		return
	print("OVERLAP r3=%s element=%s scheme=%s" % [c.r3(), c.quick_element(), c.scheme()])
	c.lock_started.connect(func(m: String, _t: Node3D) -> void:
		events.append({"ev": "lock", "t": BendStatus.now(), "m": m, "md": c.mode_of(m), "src": c.lock_src}))
	c.locked.connect(func(m: String, _t: Node3D) -> void:
		events.append({"ev": "full", "t": BendStatus.now(), "m": m, "md": c.mode_of(m), "src": c.lock_src}))
	c.cast_released.connect(func(m: String, md: String) -> void:
		# (the wait this cast's effect is given: read before the pose hears the cast, as SwayCaster read it; the record its
		# effect wrote at once when it has none)
		events.append({"ev": "release", "t": BendStatus.now(), "m": m, "md": md, "src": c.lock_src, "wait": c.strike_wait(m),
				"pending": not c._pending.is_empty(), "did": String(BendEffects.last_of(p).get("do", ""))}))
	node_added.connect(_on_node)
	physics_frame.connect(_tick)
	var only := String(opts.only).split(",")
	for s: String in ["K", "A", "B", "D", "C"]:
		if s in only:
			await call("_scenario_" + s)
	_finish("")


## Each physics tick: the crosshair held on `spot` (the rig's own yaw and pitch, as a steady hand).
func _tick() -> void:
	if not aiming or p == null:
		return
	var cam := p.camera
	var want := (spot - cam.global_position).normalized()
	var fwd := -cam.global_basis.z
	var dy := wrapf(atan2(-want.x, -want.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
	var dp := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(fwd.y, -1.0, 1.0))
	settle_err_deg = rad_to_deg(fwd.angle_to(want))
	p.yaw += dy
	p.pitch = clampf(p.pitch + dp, -deg_to_rad(p.pitch_limit_deg), deg_to_rad(p.pitch_limit_deg))


## A thing of the player's cast entering the tree: its effect leaving (a bolt, a throw, a wave: BendBolt; a guard: BendZone).
func _on_node(n: Node) -> void:
	if p == null:
		return
	var bb := n as BendBolt
	if bb != null and bb.caster == p:
		events.append({"ev": "effect", "t": BendStatus.now(), "kind": "bolt", "tag": String(bb.info.get("tag", "")),
				"m": String(bb.info.get("move", "")), "md": String(bb.info.get("mode", ""))})
		return
	var z := n as BendZone
	if z != null and z.owner_node == p:
		events.append({"ev": "effect", "t": BendStatus.now(), "kind": "zone", "tag": "zone/" + z.kind, "m": "", "md": z.kind})


## The player on the deck's long axis 6 m short of its middle, facing along it; the dummy 7 m to his side (out of every cast's
## way); the crosshair held 14 m ahead along the axis at chest height; settled, nothing locking, nothing waiting on a strike.
func _stage() -> void:
	aiming = false
	p.controls.release_all()
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var y := mode.ring.deck_y()
	var ax := (xf.basis.x * Vector3(1, 0, 1)).normalized()
	var side := ax.cross(Vector3.UP).normalized()
	var mid := Vector3(xf.origin.x, y, xf.origin.z)
	var at := mid - ax * 6.0
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), at))
	RingLevel.place(mode.foe, Transform3D(Basis.looking_at(-side, Vector3.UP), at + side * 7.0))
	mode.rules.reset_pct(mode.foe, 0.0)
	mode.rules.reset_pct(p, 0.0)
	mode.make_whole(mode.foe)
	mode.make_whole(p)
	if mode.practice_ctl != null:
		mode.practice_ctl.set_way("stand")
	BendCombo.reset(p)
	if p.has_meta(&"bend_whiff_until"):
		p.remove_meta(&"bend_whiff_until")
	spot = at + Vector3.UP * 1.35 + ax * 14.0
	aiming = true
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _secs(0.6)
	await _until(func() -> bool: return settle_err_deg < 0.05 and c.state == SwayCaster.State.IDLE and c._pending.is_empty(), 2.0)
	await _secs(0.35)                          # (past double_tap_s: the next key tap is a first tap)
	events.clear()


func _key(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)


## `key` tapped `taps` times (a double tap 6 ticks apart); true once the caster has `id` at `md` readied.
func _ready_key(key: StringName, taps: int, id: String, md: String) -> bool:
	for i in taps:
		_key(key)
		if i < taps - 1:
			await _ticks(6)
	return await _until(func() -> bool: return c.readied_spell == id and c.base_mode_of(id) == md, 0.6)


## The aim held from now until its lock is full and `beat` s more (a human's let go), then let go: the bend clock as the caster
## reads the let go (this tick), or -1 when the lock never filled.
func _hold_aim(beat: float) -> float:
	p.controls.set_held(&"aim", true)
	var ok := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	if not ok:
		p.controls.set_held(&"aim", false)
		return -1.0
	if beat > 0.0:
		await _secs(beat)
	p.controls.set_held(&"aim", false)
	return BendStatus.now()


## Everything of this scenario's casts out and landed (no lock, nothing waiting), a beat more.
func _settle() -> void:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE and c._pending.is_empty(), 2.0)
	await _secs(0.4)


func _first(ev: String, pred := Callable()) -> Dictionary:
	for e: Dictionary in events:
		if String(e.ev) == ev and (not pred.is_valid() or pred.call(e)):
			return e
	return {}


func _is(m: String, md: String) -> Callable:
	return func(e: Dictionary) -> bool: return String(e.m) == m and String(e.md) == md


func _bolt_of(tag_prefix: String) -> Callable:
	return func(e: Dictionary) -> bool: return String(e.get("tag", "")).begins_with(tag_prefix)


func _f(t: float) -> String:
	return "%+.3f" % t


func _check(scn: String, ok: bool, what: String) -> void:
	checks += 1
	var line := "OVERLAP %s %s %s" % ["PASS" if ok else "FAIL", scn, what]
	print(line)
	rows.append({"scenario": scn, "ok": ok, "what": what})
	if not ok:
		fails.append(line)


func _skip(scn: String, why: String) -> void:
	_check(scn, false, "not reached: " + why)


## A timeline of this scenario's events (bend clock, ticks from its first).
func _dump(scn: String) -> void:
	var t0 := float(events[0].t) if not events.is_empty() else 0.0
	for e: Dictionary in events:
		print("OVERLAP   %s %6.3f s (%3d) %-7s %s/%s %s%s" % [scn, float(e.t) - t0, roundi((float(e.t) - t0) / tick), e.ev,
				e.get("m", ""), e.get("md", ""), e.get("tag", ""),
				(" wait=%.3f pending=%s src=%s" % [float(e.wait), e.pending, e.src]) if String(e.ev) == "release" else ""])


# ---------------------------------------------------------------- K: the Kick (no strike wait), then the Punch at once
func _scenario_K() -> void:
	await _stage()
	if not await _ready_key(&"weapon_2", 1, "fire_kick", "kick"):
		_skip("K", "the Kick not readied (%s/%s)" % [c.readied_spell, c.base_mode_of(c.readied_spell)])
		return
	var let1 := await _hold_aim(0.08)
	if let1 < 0.0:
		_skip("K", "the Kick's lock never filled")
		return
	await physics_frame
	if not await _ready_key(&"weapon_1", 1, "fire_blast", "punch"):
		_skip("K", "the Punch not readied")
		return
	var let2 := await _hold_aim(0.08)
	await _settle()
	_dump("K")
	var kr := _first("release", _is("fire_kick", "kick"))
	var kw := _first("effect", _bolt_of("fire_kick/kick"))
	var pr := _first("release", _is("fire_blast", "punch"))
	var pw := _first("effect", _bolt_of("fire_blast/punch"))
	if kr.is_empty() or kw.is_empty() or pr.is_empty() or pw.is_empty() or let2 < 0.0:
		_skip("K", "a cast or its effect missing (kick %s/%s, punch %s/%s)" % [not kr.is_empty(), not kw.is_empty(), not pr.is_empty(), not pw.is_empty()])
		return
	_check("K", absf(float(kw.t) - float(kr.t)) < 0.5 * tick and float(kr.wait) == 0.0,
			"the Kick's wave leaves on its release (no strike wait: %s s after it, its wait %.3f)" % [_f(float(kw.t) - float(kr.t)), float(kr.wait)])
	_check("K", float(pr.t) >= float(kw.t) and absf(float(pw.t) - float(pr.t) - float(pr.wait)) <= 1.5 * FRAME,
			"the Punch let go after the wave left and its bolt its own strike wait after its release (%s s; wait %.3f)" % [_f(float(pw.t) - float(pr.t)), float(pr.wait)])
	_check("K", float(pw.t) - float(kw.t) >= float(pr.wait) - FRAME,
			"one at a time: the Punch's bolt %s s after the wave (at least its strike wait %.3f)" % [_f(float(pw.t) - float(kw.t)), float(pr.wait)])


# ---------------------------------------------------------------- A: the High Kick (strike wait) full, then the Punch at once
func _scenario_A() -> void:
	await _stage()
	if not await _ready_key(&"weapon_2", 2, "fire_kick", "high_kick"):
		_skip("A", "the High Kick not readied (%s/%s)" % [c.readied_spell, c.base_mode_of(c.readied_spell)])
		return
	var let1 := await _hold_aim(0.08)
	if let1 < 0.0:
		_skip("A", "the High Kick's lock never filled")
		return
	await physics_frame
	if not await _ready_key(&"weapon_1", 1, "fire_blast", "punch"):
		_skip("A", "the Punch not readied")
		return
	var let2 := await _hold_aim(0.08)
	await _settle()
	_dump("A")
	var hr := _first("release", _is("fire_kick", "high_kick"))
	var hw := _first("effect", _bolt_of("fire_kick/high_kick"))
	var pl := _first("lock", _is("fire_blast", "punch"))
	var pr := _first("release", _is("fire_blast", "punch"))
	var pw := _first("effect", _bolt_of("fire_blast/punch"))
	if hr.is_empty() or hw.is_empty() or pl.is_empty() or pr.is_empty() or pw.is_empty() or let2 < 0.0:
		_skip("A", "a cast or its effect missing (hk %s/%s, punch lock %s release %s bolt %s)" % [not hr.is_empty(), not hw.is_empty(),
				not pl.is_empty(), not pr.is_empty(), not pw.is_empty()])
		return
	var hwait := float(hr.wait)
	var due := float(hr.t) + hwait
	if not (hwait > 3.0 * FRAME and float(pl.t) < due - 2.0 * FRAME):
		_skip("A", "the Punch's lock did not begin while the High Kick waited (wait %.3f, lock %s s after its release)" % [hwait, _f(float(pl.t) - float(hr.t))])
		return
	_check("A", float(hw.t) >= due - 1.5 * FRAME and float(hw.t) <= due + 1.5 * FRAME,
			"the High Kick leaves at its own strike: %s s after its release (its strike wait %.3f), the Punch's lock begun %s s after it" % [
				_f(float(hw.t) - float(hr.t)), hwait, _f(float(pl.t) - float(hr.t))])
	_check("A", float(pr.t) >= float(hw.t) and float(pw.t) > float(hw.t),
			"the Punch let go (%s s) and its bolt (%s s) after the High Kick left" % [_f(float(pr.t) - float(hw.t)), _f(float(pw.t) - float(hw.t))])
	_check("A", absf(float(pw.t) - float(pr.t) - float(pr.wait)) <= 1.5 * FRAME,
			"the Punch's bolt its own strike wait after its release (%s s; wait %.3f)" % [_f(float(pw.t) - float(pr.t)), float(pr.wait)])
	_check("A", float(pw.t) - float(hw.t) >= hwait - FRAME,
			"one at a time: %s s between the High Kick and the Punch (at least the High Kick's strike wait %.3f)" % [_f(float(pw.t) - float(hw.t)), hwait])


# ---------------------------------------------------------------- B: head starts: the Punch let go before the High Kick's strike
func _scenario_B() -> void:
	await _stage()
	if not await _ready_key(&"weapon_2", 2, "fire_kick", "high_kick"):
		_skip("B", "the High Kick not readied")
		return
	FireTalents.give_head_start(p, "fire_kick/high_kick", 0.95, 2.0)
	var let1 := await _hold_aim(0.0)            # (full almost at once: let go early in its wind-up, its strike further off)
	if let1 < 0.0:
		_skip("B", "the High Kick's lock never filled")
		return
	await physics_frame
	if not await _ready_key(&"weapon_1", 1, "fire_blast", "punch"):
		_skip("B", "the Punch not readied")
		return
	FireTalents.give_head_start(p, "fire_blast/punch", 0.95, 2.0)
	var let2 := await _hold_aim(0.0)
	await _settle()
	_dump("B")
	var hr := _first("release", _is("fire_kick", "high_kick"))
	var hw := _first("effect", _bolt_of("fire_kick/high_kick"))
	var pr := _first("release", _is("fire_blast", "punch"))
	var pw := _first("effect", _bolt_of("fire_blast/punch"))
	if hr.is_empty() or hw.is_empty() or pr.is_empty() or pw.is_empty() or let2 < 0.0:
		_skip("B", "a cast or its effect missing (hk %s/%s, punch %s/%s)" % [not hr.is_empty(), not hw.is_empty(), not pr.is_empty(), not pw.is_empty()])
		return
	var hwait := float(hr.wait)
	var due := float(hr.t) + hwait
	if not (let2 < due - 2.0 * FRAME):
		_skip("B", "the Punch was not let go before the High Kick's strike (let go %s s after its release, its wait %.3f)" % [_f(let2 - float(hr.t)), hwait])
		return
	_check("B", float(hw.t) >= due - 1.5 * FRAME and float(hw.t) <= due + 1.5 * FRAME,
			"the High Kick leaves at its own strike: %s s after its release (its strike wait %.3f; the Punch let go %s s after it)" % [
				_f(float(hw.t) - float(hr.t)), hwait, _f(let2 - float(hr.t))])
	_check("B", float(pr.t) >= float(hw.t),
			"the Punch let go before the High Kick's strike is not released before the High Kick left (%s s after it)" % _f(float(pr.t) - float(hw.t)))
	_check("B", float(pr.t) <= maxf(float(hw.t), let2) + tick + 0.0001,
			"... and goes the moment the High Kick has landed (%s s after it; let go %s s before it)" % [_f(float(pr.t) - float(hw.t)), _f(float(hw.t) - let2)])
	_check("B", absf(float(pw.t) - float(pr.t) - float(pr.wait)) <= 1.5 * FRAME,
			"the Punch's bolt its own strike wait after its release (%s s; wait %.3f)" % [_f(float(pw.t) - float(pr.t)), float(pr.wait)])
	_check("B", float(pw.t) - float(hw.t) >= float(pr.wait) - FRAME and float(pw.t) > float(hw.t),
			"one at a time: the Punch's bolt %s s after the High Kick (at least its own strike wait %.3f)" % [_f(float(pw.t) - float(hw.t)), float(pr.wait)])


# ---------------------------------------------------------------- D: the High Kick (head start), then E tapped
func _scenario_D() -> void:
	await _stage()
	if not await _ready_key(&"weapon_2", 2, "fire_kick", "high_kick"):
		_skip("D", "the High Kick not readied")
		return
	FireTalents.give_head_start(p, "fire_kick/high_kick", 0.95, 2.0)
	var let1 := await _hold_aim(0.0)
	if let1 < 0.0:
		_skip("D", "the High Kick's lock never filled")
		return
	await physics_frame
	p.controls.set_held(SwayCaster.GUARD, true)
	await _ticks(2)
	p.controls.set_held(SwayCaster.GUARD, false)     # (tapped: the guard's click runs on)
	await _settle()
	_dump("D")
	var hr := _first("release", _is("fire_kick", "high_kick"))
	var hw := _first("effect", _bolt_of("fire_kick/high_kick"))
	var gl := _first("lock", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_GUARD)
	var gf := _first("full", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_GUARD)
	var gr := _first("release", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_GUARD)
	var gz := _first("effect", func(e: Dictionary) -> bool: return String(e.kind) == "zone")
	if hr.is_empty() or hw.is_empty() or gl.is_empty() or gf.is_empty() or gr.is_empty() or gz.is_empty():
		_skip("D", "a cast or its effect missing (hk %s/%s, guard lock %s full %s release %s zone %s)" % [not hr.is_empty(), not hw.is_empty(),
				not gl.is_empty(), not gf.is_empty(), not gr.is_empty(), not gz.is_empty()])
		return
	var hwait := float(hr.wait)
	var due := float(hr.t) + hwait
	if not (float(gf.t) < due - 2.0 * FRAME):
		_skip("D", "the guard's lock was not full before the High Kick's strike (full %s s after its release, its wait %.3f)" % [_f(float(gf.t) - float(hr.t)), hwait])
		return
	_check("D", float(hw.t) >= due - 1.5 * FRAME and float(hw.t) <= due + 1.5 * FRAME,
			"the High Kick leaves at its own strike: %s s after its release (its strike wait %.3f; the guard's lock begun %s s after it)" % [
				_f(float(hw.t) - float(hr.t)), hwait, _f(float(gl.t) - float(hr.t))])
	var may := maxf(float(gf.t), float(hw.t))
	_check("D", float(gr.t) >= float(hw.t) and float(gr.t) <= may + tick + 0.0001,
			"the guard stands the moment the High Kick has landed, never later (%s s after it; its lock full %s s before it)" % [
				_f(float(gr.t) - float(hw.t)), _f(float(hw.t) - float(gf.t))])
	_check("D", absf(float(gz.t) - float(gr.t)) < 0.5 * tick and float(gr.wait) == 0.0,
			"its zone the frame it stands (%s s; no strike wait: %.3f)" % [_f(float(gz.t) - float(gr.t)), float(gr.wait)])


# ---------------------------------------------------------------- C: nothing waiting: quick taps go at once
func _scenario_C() -> void:
	await _stage()
	p.controls.set_held(SwayCaster.GUARD, true)
	await _ticks(2)
	p.controls.set_held(SwayCaster.GUARD, false)
	await _settle()
	_dump("C")
	var gf := _first("full", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_GUARD)
	var gr := _first("release", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_GUARD)
	var gz := _first("effect", func(e: Dictionary) -> bool: return String(e.kind) == "zone")
	if gf.is_empty() or gr.is_empty() or gz.is_empty():
		_skip("C", "the guard tapped: a lock, release or zone missing (full %s release %s zone %s)" % [not gf.is_empty(), not gr.is_empty(), not gz.is_empty()])
	else:
		_check("C", absf(float(gr.t) - float(gf.t)) < 0.5 * tick and absf(float(gz.t) - float(gr.t)) < 0.5 * tick,
				"E tapped with nothing waiting: the guard stands the frame its lock fills (%s s) and its zone then (%s s)" % [
					_f(float(gr.t) - float(gf.t)), _f(float(gz.t) - float(gr.t))])
	await _stage()
	var pressed := BendStatus.now()
	_key(&"weapon_3")
	await _settle()
	_dump("C")
	var dl := _first("lock", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_DASH)
	var df := _first("full", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_DASH)
	var dr := _first("release", func(e: Dictionary) -> bool: return String(e.src) == SwayCaster.SRC_DASH)
	if dl.is_empty() or df.is_empty() or dr.is_empty():
		_skip("C", "key 3 tapped: its lock, full or release missing (lock %s full %s release %s)" % [not dl.is_empty(), not df.is_empty(), not dr.is_empty()])
	else:
		var may := maxf(float(df.t), float(dl.t) + BendR3.num("key3_min_s", 0.22))
		_check("C", float(dr.t) >= may - 0.5 * tick and float(dr.t) <= may + tick + 0.0001 and String(dr.did) == "dash" and float(dr.wait) == 0.0,
				"key 3 tapped with nothing waiting: the dash goes the frame it may (%s s after its lock was full, %s s after the press; %s at once)" % [
					_f(float(dr.t) - float(df.t)), _f(float(dr.t) - pressed), dr.did])


func _finish(error: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if String(opts.out) != "":
		var f := FileAccess.open(String(opts.out).path_join("overlap_%s.json" % opts.tag), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"error": error, "rows": rows}, "\t"))
	for l: String in fails:
		print(l)
	var passed := error == "" and fails.is_empty() and checks > 0
	print("CAST OVERLAP TEST %s checks=%d fails=%d error=%s" % ["PASSED" if passed else "FAILED", checks, fails.size(), error])
	quit(0 if passed else 1)
