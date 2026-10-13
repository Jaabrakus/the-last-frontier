extends SceneTree
## The casting ring is the aim's help (the owner, 2026-10-12: "yea we still want aim assit but we want the cross hair on the
## target in gameplay"; "for the aim assit anything within the circle not just the dot okay.."; the circle: the casting ring
## SwayRing draws round the crosshair). The player's Normal help ("light"): a foe whose chest is inside the ring's on-screen
## circle at the cast's aim gets the cast (to his chest, led); none inside: the crosshair's line at the foe's depth (the
## parallax fix), no pull; never an ally. In the real ring (scenes/ring.tscn: a 1v1 practice, the standing dummy, stock
## rules, the default "high" camera, the radial scheme), the camera turned only through the rig's own yaw / pitch every
## physics tick so the crosshair holds a chosen point (a perfect mouse hand: the cast's recoil taken back), every cast through
## the real input actions. Groups:
##   S  the ring's numbers: its angle from SwayRing.RADIUS (the ring's canvas scale, its viewport's height, the camera's FOV);
##      a point at that angle projects RADIUS px from the screen's centre; PlayerBendCaster.ring_deg agrees, the ring hidden too
##   A  crosshair on the chest, Normal: each element's aimed shots HIT at 6 / 12 / 20 / 28 m (where their range reaches)
##   R  his chest inside the ring near its edge (RING_IN of its radius, to the crosshair's right and below it), Normal: HIT,
##      for each element's aimed shots at 6-28 m, the help's target him at the aim
##   O  his chest just outside the ring (RING_OUT of its radius), Normal: no help (no target at the aim), the shot on the
##      crosshair's line at his depth within TOL_M
##   L  an ally (the dummy made the player's side) with his chest well inside the ring, Normal: no help (no target at the aim)
##   T  a flick: the lock filled with the crosshair well off him (FLICK_FROM of the ring), snapped so his chest is inside the
##      ring near its edge just before the let go (the jab at 6 m, each element's shot at 12 m): HIT (the help read at the aim)
##   B  crosshair OFF his body (over his head at 1.85 m; 0.6 m beside his belly), "off" and Normal: off on the crosshair's
##      line; Normal on the line with his chest outside the ring, a HIT with it inside (either within RING_EDGE_DEG of it)
##   C  the same off-body points, "strong": every cast inside its 6 deg cone goes to his chest and HITS (as designed)
## Exit 0 when every check passes, 1 otherwise ("RINGTEST FAIL" lines name each).
##   GODOT_TIMEOUT=1500 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier \
##     -s tests/ring/test_casting_ring.gd -- [groups=S,A,R,O,L,T,B,C] [only=fire,earth,water,air] [dists=6,12,20,28] [out=<dir>] [tag=]
## VERIFICATION ONLY, before the patch is applied: overlay=<dir> swaps the game's scripts for <dir>/<res path> copies in memory
## (GDScript.reload, before the ring loads; nothing on disk changes), so the patched code can be tested on a read-only checkout.

const OWN_CFG := "user://ring_assist_test.cfg"
const TOL_M := 0.2
## Where his chest is put for R / T (inside, near the edge), O (just outside) and L (the ally, well inside): of the ring's radius.
const RING_IN := 0.85
const RING_OUT := 1.15
const RING_ALLY := 0.6
## T's flick: the lock filled with his chest FLICK_FROM of the ring's radius off the crosshair, the crosshair snapped to
## RING_IN FLICK_TICKS ticks before the let go.
const FLICK_FROM := 4.0
const FLICK_TICKS := 3
## Measured at the aim (the first projectile's tick): within this of the ring's edge either outcome is the design.
const RING_EDGE_DEG := 0.08
## The order the overlay's scripts are reloaded in (bases first).
const OVERLAY_ORDER := ["scripts/ring/match_setup.gd", "scripts/bending/bend_caster.gd", "scripts/bending/player_bend_caster.gd",
	"scripts/net/ring/net_bend_caster.gd", "scripts/bending/bend_effects.gd", "scripts/bending/bend_bolt.gd",
	"scripts/bending/bend_cast.gd", "scripts/sway/form_effects.gd"]

var opts := {"groups": "S,A,R,O,L,T,B,C", "only": "fire,earth,water,air", "dists": "6,12,20,28", "overlay": "",
	"out": OS.get_user_data_dir().path_join("casting_ring_test"), "tag": "ring"}

## Each element's aimed shots: key (hotbar action, "" none), taps (1 the key's first move, 2 its other), button (fire: the jab
## on the left button, aim: the readied move on the right), hold ("full": the lock full then a human beat; seconds: at least
## that long (the Fireball's grow); "grow": until the lock grew), max_m (its range: nothing farther is asked of it), b (the
## element's shot for groups B, C, O and L).
const SHOTS := {
	"fire": [
		{"name": "embers", "key": "", "taps": 0, "button": "fire", "hold": "full", "max_m": 6.0, "jab": true},
		{"name": "punch", "key": "weapon_1", "taps": 1, "button": "aim", "hold": "full", "max_m": 99.0, "b": true},
		{"name": "fireball", "key": "weapon_1", "taps": 1, "button": "aim", "hold": 1.65, "max_m": 99.0},
		{"name": "high_kick", "key": "weapon_2", "taps": 2, "button": "aim", "hold": "full", "max_m": 99.0, "to_crosshair": true},
	],
	"earth": [
		{"name": "pebbles", "key": "", "taps": 0, "button": "fire", "hold": "full", "max_m": 6.0, "jab": true},
		{"name": "spike", "key": "weapon_1", "taps": 1, "button": "aim", "hold": "full", "max_m": 99.0, "b": true},
		{"name": "boulder", "key": "weapon_1", "taps": 2, "button": "aim", "hold": "full", "max_m": 99.0},
	],
	"water": [
		{"name": "lash", "key": "weapon_1", "taps": 1, "button": "aim", "hold": "full", "max_m": 12.0},
		{"name": "spear", "key": "weapon_1", "taps": 2, "button": "aim", "hold": "full", "max_m": 99.0, "b": true},
	],
	"air": [
		{"name": "slice", "key": "weapon_1", "taps": 1, "button": "aim", "hold": "full", "max_m": 99.0, "b": true},
		{"name": "wind_ball", "key": "weapon_1", "taps": 2, "button": "aim", "hold": "full", "max_m": 99.0},
		{"name": "lance", "key": "weapon_2", "taps": 1, "button": "aim", "hold": "grow", "max_m": 99.0},
	],
}
## The crosshair's points off his body: [name, m over his feet, m to the player's right].
const OFF_BODY := [["over_head", 1.85, 0.0], ["beside", 1.1, 0.6]]
## The ring placements: [name, k of the ring's radius, way the crosshair is off his chest ("left": his chest to its right;
## "up": his chest below it)].
const RING_WAYS := ["left", "up"]

var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var aiming := false
var aim_h := -1.0
var aim_side := 0.0
var ring_k := 0.0
var ring_way := ""
var settle_err_deg := 0.0
var tracks := {}
var hits := 0
var released: Array = []
var fails: Array = []
var checks := 0
var rows: Array = []
## At the cast's aim (the tick its first projectile is seen): his chest off the camera's ray (deg), the help's target.
var at_aim := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		if opts.has(key):
			opts[key] = arg.substr(key.length() + 1)
	DirAccess.make_dir_recursive_absolute(opts.out)
	if String(opts.overlay) != "" and not _overlay(String(opts.overlay)):
		_finish("overlay failed")
		return
	seed(4242)
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
	create_timer(1750.0, true, false, true).timeout.connect(func() -> void: _finish("watchdog"))
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
			push_error("RINGTEST overlay: no script res://" + rel)
			return false
		s.source_code = FileAccess.get_file_as_string(src)
		var err := s.reload(false)
		print("RINGTEST OVERLAY %s err=%d" % [rel, err])
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
	if DisplayServer.get_name() == "headless":
		# (headless the root is a 64 px stub: sized as the game's window, the size the help reads with no screen)
		root.size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
		await _ticks(2)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	c.cast_released.connect(func(m: String, v: String) -> void: released.append("%s/%s" % [m, v]))
	mode.rules.pct_dealt.connect(func(by: Node, b: Node3D, delta: float) -> void:
		if by == p and b == mode.foe and delta > 0.0:
			hits += 1)
	mode.rules.launched.connect(func(b: Node3D, _v: Vector3, _s: float, by: Node, _tag: String) -> void:
		if by == p and b == mode.foe:
			hits += 1)
	physics_frame.connect(_tick)
	var groups := String(opts.groups).split(",")
	var dists := String(opts.dists).split(",")
	var first := true
	for el: String in String(opts.only).split(","):
		await _element(el)
		if first and "S" in groups:
			await _screen()
		first = false
		for spec: Dictionary in SHOTS[el]:
			if "A" in groups:
				for ds: String in dists:
					if float(ds) <= float(spec.max_m):
						await _case("A", el, "light", float(ds), spec, ["chest"])
			if "R" in groups and not bool(spec.get("to_crosshair", false)):
				for ds: String in dists:
					if float(ds) <= float(spec.max_m):
						for w: String in RING_WAYS:
							await _case("R", el, "light", float(ds), spec, ["ring", RING_IN, w])
			if "T" in groups and (bool(spec.get("jab", false)) or bool(spec.get("b", false))):
				var flick := spec.duplicate()
				flick["hold"] = "flick"
				await _case("T", el, "light", 6.0 if bool(spec.get("jab", false)) else 12.0, flick, ["ring", FLICK_FROM, "left"])
			if not bool(spec.get("b", false)):
				continue
			for ds: String in dists:
				if "O" in groups:
					for w: String in RING_WAYS:
						await _case("O", el, "light", float(ds), spec, ["ring", RING_OUT, w])
				if "L" in groups and ds in ["6", "20"]:
					await _case("L", el, "light", float(ds), spec, ["ring", RING_ALLY, "left"])
			for ob: Array in OFF_BODY:
				for ds: String in dists:
					if "B" in groups:
						for h: String in ["off", "light"]:
							await _case("B", el, h, float(ds), spec, ["off", ob[1], ob[2], ob[0]])
					if "C" in groups:
						await _case("C", el, "strong", float(ds), spec, ["off", ob[1], ob[2], ob[0]])
	_finish("")


func _element(el: String) -> void:
	aiming = false
	p.controls.release_all()
	MatchSetup.element = el
	MatchSetup.foes = ["fire"]
	mode.restart()
	await _until(func() -> bool: return mode.phase == "FIGHT" and p.arena_element == el, 12.0)
	await _secs(0.5)
	c = SwayCaster.of(p)


## The ring's angular radius (deg) as the test reads it, apart from the patch: SwayRing.RADIUS times the ring's canvas scale,
## over half its viewport's height, through the camera's vertical FOV.
func _ring_deg() -> float:
	var cam := p.camera
	var rn: SwayRing = c.ring
	var r := SwayRing.RADIUS * absf(rn.get_global_transform_with_canvas().get_scale().y)
	var h := rn.get_viewport_rect().size.y
	return rad_to_deg(atan(tan(deg_to_rad(cam.fov) * 0.5) * r / (h * 0.5)))


func _check(group: String, ok: bool, what: String) -> void:
	checks += 1
	var l := "RINGTEST %s %s %s" % ["PASS" if ok else "FAIL", group, what]
	if not ok:
		fails.append(l)
	print(l)


## S: the ring's numbers, and the patch's ring_deg the same, the ring hidden too.
func _screen() -> void:
	await _stage(12.0)
	var cam := p.camera
	var rn: SwayRing = c.ring
	var vp := rn.get_viewport_rect().size
	var deg := _ring_deg()
	var scale := absf(rn.get_global_transform_with_canvas().get_scale().y)
	print("RINGTEST RING viewport=%dx%d radius_px=%.1f canvas_scale=%.3f fov=%.2f keep_aspect=%d ring_deg=%.3f" % [vp.x, vp.y,
		SwayRing.RADIUS, scale, cam.fov, cam.keep_aspect, deg])
	# (a point at the ring's angle off the camera's ray, 12 m out: drawn RADIUS px from the screen's centre)
	var fwd := -cam.global_basis.z
	var q := cam.global_position + fwd.rotated(cam.global_basis.x.normalized(), deg_to_rad(deg)) * 12.0
	var px := cam.unproject_position(q).distance_to(Vector2(vp) * 0.5)
	_check("S", absf(px - SwayRing.RADIUS * scale) < 0.5, "a point at the ring's angle (%.3f deg) projects %.2f px from the centre (the ring: %.1f px)" % [deg, px, SwayRing.RADIUS * scale])
	var pbc := BendCaster.of(p)
	var has := pbc.has_method(&"ring_deg")
	var got: float = pbc.call(&"ring_deg") if has else -1.0
	_check("S", has and absf(got - deg) < 0.01, "PlayerBendCaster.ring_deg %.3f = the ring's %.3f" % [got, deg])
	rn.visible = false
	var hid: float = pbc.call(&"ring_deg") if has else -1.0
	rn.visible = true
	_check("S", has and absf(hid - deg) < 0.01, "the ring hidden, the help's ring the same: %.3f" % hid)
	var row := {"group": "S", "viewport": [vp.x, vp.y], "radius_px": SwayRing.RADIUS, "canvas_scale": scale, "fov": cam.fov, "ring_deg": deg}
	rows.append(row)
	aiming = false


## Where the crosshair is held: his chest (aim_h < 0 and no ring placement), aim_h m over his feet and aim_side m to the
## player's right, or (ring_k) off his chest by ring_k of the ring's angle (his chest to the crosshair's right, or under it).
func _spot() -> Vector3:
	var chest := NpcSenses.chest_of(mode.foe)
	if ring_k > 0.0:
		var to := chest - p.camera.global_position
		var right := to.cross(Vector3.UP).normalized()
		var up := right.cross(to).normalized()
		var u := -right if ring_way == "left" else up
		return chest + u * to.length() * tan(deg_to_rad(_ring_deg() * ring_k))
	if aim_h < 0.0:
		return chest
	return mode.foe.global_position + Vector3.UP * aim_h + _right() * aim_side


## The player's right across the line of fire (level).
func _right() -> Vector3:
	var f := mode.foe.global_position - p.global_position
	f.y = 0.0
	return f.normalized().cross(Vector3.UP).normalized()


## The crosshair held on _spot(): the camera's centre ray turned by the rig's own yaw and pitch every tick.
func _tick() -> void:
	if aiming and p != null and is_instance_valid(mode.foe):
		var cam := p.camera
		var want := (_spot() - cam.global_position).normalized()
		var fwd := -cam.global_basis.z
		var dy := wrapf(atan2(-want.x, -want.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
		var dp := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(fwd.y, -1.0, 1.0))
		settle_err_deg = rad_to_deg(fwd.angle_to(want))
		p.yaw += dy
		p.pitch = clampf(p.pitch + dp, -deg_to_rad(p.pitch_limit_deg), deg_to_rad(p.pitch_limit_deg))
	_track()


## The cast's aim seen (its first projectile): his chest off the camera's ray, the help's target then, the ring's angle.
func _mark_aim() -> void:
	if not at_aim.is_empty() or p == null:
		return
	var cam := p.camera
	var chest := NpcSenses.chest_of(mode.foe)
	at_aim = {"off_deg": rad_to_deg((chest - cam.global_position).angle_to(-cam.global_basis.z)), "ring_deg": _ring_deg(),
		"target": BendCaster.of(p).aim_target(), "cam_m": chest.distance_to(cam.global_position), "ring_up": c.ring._alpha}


## Every projectile of the player's in flight, its path kept (bolts; stones thrown).
func _track() -> void:
	if p == null:
		return
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b == null or b.caster != p:
			continue
		var id := b.get_instance_id()
		if not tracks.has(id):
			tracks[id] = {"pts": [], "node": b}
			_mark_aim()
		if not b.spent:
			(tracks[id].pts as Array).append(b.global_position)
	# (read by name, not through the class: the overlay's reload makes FormEffects.Throw a new class)
	for n in get_nodes_in_group(FormEffects.Throw.GROUP):
		var bc: Variant = n.get("caster")
		var stone: Variant = n.get("stone")
		if not (bc is BendCaster) or not (bc as BendCaster).valid() or (bc as BendCaster).body != p or not is_instance_valid(stone) \
				or not bool(n.get("is_thrown")):
			continue
		var id2 := (stone as Node3D).get_instance_id()
		if not tracks.has(id2):
			tracks[id2] = {"pts": [], "node": stone}
			_mark_aim()
		(tracks[id2].pts as Array).append((stone as Node3D).global_position)


## A path's pass through the plane across the line of fire at his chest: {dy, dx} from the chest (dx to the right); the
## nearest point when it stopped short (met him, or ended).
func _pass(pts: Array, chest: Vector3, f: Vector3) -> Dictionary:
	var r := f.cross(Vector3.UP).normalized()
	var best := {}
	var bestd := INF
	for i in pts.size():
		var q: Vector3 = pts[i]
		if i > 0:
			var q0: Vector3 = pts[i - 1]
			var s0 := (q0 - chest).dot(f)
			var s := (q - chest).dot(f)
			if s0 < 0.0 and s >= 0.0:
				var x := q0.lerp(q, -s0 / maxf(s - s0, 1e-6))
				return {"dy": x.y - chest.y, "dx": (x - chest).dot(r), "crossed": true}
		var dd := q.distance_to(chest)
		if dd < bestd:
			bestd = dd
			best = {"dy": q.y - chest.y, "dx": (q - chest).dot(r), "crossed": false}
	return best


## Both stood on the deck's long axis about its middle, `d` m apart, at 0 %, the dummy's way "stand"; the crosshair settled.
func _stage(d: float) -> void:
	aiming = false
	p.controls.release_all()
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var y := mode.ring.deck_y()
	var ax := (xf.basis.x * Vector3(1, 0, 1)).normalized()
	var mid := Vector3(xf.origin.x, y, xf.origin.z)
	RingLevel.place(mode.foe, Transform3D(Basis.looking_at(-ax, Vector3.UP), mid + ax * d * 0.5))
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), mid - ax * d * 0.5))
	mode.rules.reset_pct(mode.foe, 0.0)
	mode.rules.reset_pct(p, 0.0)
	mode.make_whole(mode.foe)
	mode.make_whole(p)
	if mode.practice_ctl != null:
		mode.practice_ctl.set_way("stand")
	aiming = true
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _secs(0.7)
	await _until(func() -> bool: return settle_err_deg < 0.02 and c.state == SwayCaster.State.IDLE, 2.0)


func _case(group: String, el: String, help: String, d: float, spec: Dictionary, at: Array) -> void:
	MatchSetup._aim_help = help
	var kind := String(at[0])
	aim_h = float(at[1]) if kind == "off" else -1.0
	aim_side = float(at[2]) if kind == "off" else 0.0
	ring_k = float(at[1]) if kind == "ring" else 0.0
	ring_way = String(at[2]) if kind == "ring" else ""
	var label := String(at[3]) if kind == "off" else ("%s_%.2f_%s" % [kind, ring_k, ring_way] if kind == "ring" else kind)
	var team0: Variant = mode.foe.get_meta(BendCaster.TEAM_META) if mode.foe.has_meta(BendCaster.TEAM_META) else null
	if group == "L":
		mode.foe.set_meta(BendCaster.TEAM_META, BendCaster.team_of(p))      # (the dummy made the player's side: an ally)
	await _stage(d)
	tracks = {}
	hits = 0
	released = []
	at_aim = {}
	var chest := NpcSenses.chest_of(mode.foe)
	var f := chest - NpcSenses.chest_of(p)
	f.y = 0.0
	f = f.normalized()
	var spot := _spot()
	var line := {"dy": spot.y - chest.y, "dx": (spot - chest).dot(_right())}
	for i in int(spec.taps):
		_key(StringName(spec.key))
		await _ticks(6)
	if int(spec.taps) > 0:
		await _ticks(4)
	var btn := StringName(spec.button)
	p.controls.set_held(btn, true)
	var t0 := BendStatus.now()
	var hold: Variant = spec.hold
	var full_at := -1.0
	while released.is_empty() and BendStatus.now() - t0 <= 4.0:
		await physics_frame
		var t := BendStatus.now() - t0
		var ready := c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]
		if hold is float:
			if t >= float(hold) and ready:
				break
		elif String(hold) == "flick":
			# (a flick: the lock filled with the crosshair well off him, then snapped onto RING_IN of the ring a beat before
			# the let go, inside the lock's grace)
			if ready:
				ring_k = RING_IN
				await _ticks(FLICK_TICKS)
				break
		elif String(hold) == "grow":
			if c.grown and ready:
				await _secs(0.08)
				break
		elif ready:
			if full_at < 0.0:
				full_at = t
			elif t - full_at >= 0.08:
				break
	p.controls.set_held(btn, false)
	await _until(func() -> bool: return not released.is_empty(), 1.5)
	await _secs(0.25)
	await _until(func() -> bool:
		for id in tracks:
			var nd: Variant = tracks[id].node
			if is_instance_valid(nd) and not (nd is BendBolt and (nd as BendBolt).spent):
				return false
		return true, 2.5)
	await _secs(0.1)
	if group == "L":
		if team0 == null:
			mode.foe.remove_meta(BendCaster.TEAM_META)
		else:
			mode.foe.set_meta(BendCaster.TEAM_META, team0)
	var n := 0
	var sy := 0.0
	var sx := 0.0
	var passes: Array = []          # (each projectile: [dy, dx, points kept, first and last point's distance to his chest])
	var all_crossed := true
	for id in tracks:
		var pts: Array = tracks[id].pts
		if pts.is_empty():
			continue
		var ps := _pass(pts, chest, f)
		passes.append([snappedf(float(ps.dy), 0.01), snappedf(float(ps.dx), 0.01), pts.size(), snappedf((pts[0] as Vector3).distance_to(chest), 0.01),
			snappedf((pts[pts.size() - 1] as Vector3).distance_to(chest), 0.01)])
		all_crossed = all_crossed and bool(ps.get("crossed", false))
		sy += float(ps.dy)
		sx += float(ps.dx)
		n += 1
	var hit := hits > 0
	var off_deg := float(at_aim.get("off_deg", -1.0))
	var rdeg := float(at_aim.get("ring_deg", _ring_deg()))
	var tg: Variant = at_aim.get("target")
	var tg_s := "none" if tg == null else ("him" if tg == mode.foe else str(tg))
	var row := {"group": group, "element": el, "help": help, "dist": d, "shot": spec.name, "aim": label, "hit": hit,
		"released": released, "projectiles": n, "off_deg_at_aim": off_deg, "ring_deg": rdeg, "target_at_aim": tg_s,
		"cam_m": float(at_aim.get("cam_m", -1.0)), "ring_alpha_at_aim": float(at_aim.get("ring_up", -1.0)),
		"line_dy": line.dy, "line_dx": line.dx, "passes": passes}
	if n > 0:
		row["shot_dy"] = sy / n
		row["shot_dx"] = sx / n
	var on_line := func() -> Array:
		if n == 0:
			return [false, "no projectile"]
		var ey := float(row.shot_dy) - float(line.dy)
		var ex := float(row.shot_dx) - float(line.dx)
		row["err_dy"] = ey
		row["err_dx"] = ex
		if hit and not all_crossed:
			# (it met him short of his plane: the crosshair's line was over a part of him (his head), the dy above is where it met)
			return [true, "met him on the crosshair's way"]
		return [absf(ey) <= TOL_M and absf(ex) <= TOL_M, "shot %+.2f m up / %+.2f m right of the crosshair's line at his depth" % [ey, ex]]
	var ok := true
	var why := ""
	match group:
		"A", "C":
			ok = hit
			why = "no hit"
		"R", "T":
			# (a volley (Embers: 7 bolts in a 9 deg fan) is sent at his chest but its fan can straddle him: its centre on his
			# chest stands for the hit)
			var centred := n > 1 and absf(float(row.get("shot_dy", 9.0))) <= TOL_M and absf(float(row.get("shot_dx", 9.0))) <= TOL_M
			ok = (hit or centred) and tg == mode.foe
			why = "hit %s, the help's target at the aim %s (his chest %.2f deg off, the ring %.2f)" % [hit, tg_s, off_deg, rdeg]
		"O":
			var r: Array = on_line.call()
			ok = tg == null and bool(r[0])
			why = "the help's target at the aim %s (his chest %.2f deg off, the ring %.2f); %s" % [tg_s, off_deg, rdeg, r[1]]
		"L":
			ok = tg == null and n > 0
			why = "the help's target at the aim %s (the ally's chest %.2f deg off, the ring %.2f), %d projectiles" % [tg_s, off_deg, rdeg, n]
		"B":
			var r: Array = on_line.call()
			if help == "off":
				ok = bool(r[0])
				why = String(r[1])
			else:
				var inside := off_deg >= 0.0 and off_deg < rdeg - RING_EDGE_DEG
				var outside := off_deg >= rdeg + RING_EDGE_DEG
				if inside:
					ok = hit
					why = "inside the ring (%.2f < %.2f deg): no hit" % [off_deg, rdeg]
				elif outside:
					ok = bool(r[0])
					why = "outside the ring (%.2f > %.2f deg): %s" % [off_deg, rdeg, r[1]]
				else:
					ok = hit or bool(r[0])
					why = "on the ring's edge: neither a hit nor the line"
	checks += 1
	row["ok"] = ok
	rows.append(row)
	var line_s := "RINGTEST %s %s %-6s %-6s %4.0fm %-9s %-18s hit=%s off=%.2fdeg ring=%.2fdeg (%.2f m wide at %.1f m from the camera) target=%s shot=%s line=%+.2f/%+.2f" % [
		"PASS" if ok else "FAIL", group, el, help, d, spec.name, label, hit, off_deg, rdeg,
		2.0 * float(row.cam_m) * tan(deg_to_rad(rdeg)), float(row.cam_m), tg_s,
		"%+.2f/%+.2f" % [row.shot_dy, row.shot_dx] if n > 0 else "-", line.dy, line.dx]
	if not ok:
		line_s += "  (" + why + ")"
		fails.append(line_s)
	print(line_s)
	aiming = false
	ring_k = 0.0
	p.controls.release_all()
	if mode.ring != null:
		mode.ring.clear_dropped()
	for nd in get_nodes_in_group(FormRaised.GROUP):
		if is_instance_valid(nd) and FormEffects.own(BendCaster.of(p), nd):
			(nd as Node).queue_free()
	await _secs(0.3)


func _key(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)


func _finish(error: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	var f := FileAccess.open(String(opts.out).path_join("test_%s.json" % opts.tag), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"error": error, "rows": rows}, "\t"))
	for l: String in fails:
		print(l)
	var passed := error == "" and fails.is_empty() and checks > 0
	print("RINGTEST %s checks=%d fails=%d error=%s" % ["OK" if passed else "FAILED", checks, fails.size(), error])
	quit(0 if passed else 1)
