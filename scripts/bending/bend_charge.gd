class_name BendCharge
extends Node3D
## The element gathering round a bender's body while a move charges (the owner, 2026-10-12: "instead of the spell circle we
## need to animate like in avatar the element charging and bending around their body"), and channelled to the point of the
## attack as it fills (the owner: "i want to channel the energy to the point of attack like for a kicks it should be
## channeled at the foot"): the limb the move's clip leaves from (limb(): the pose's l_palm, r_palm, both, l_foot, r_foot;
## SwayPose.strike_limb, NpcBody.strike_limb). In place of the circle on the ground (FormCircle) for every bending lock in
## the ring (wanted): the player's (FormCast), a bot's (NpcBending), an online opponent's puppet (its own FormCast). The
## circle's face, so the callers swap one for the other: fill (0..1, the lock), full (it pulses), flash() (the click),
## end(kind) ("cast": thrown out with the cast; "break" / "fizzle": it falls away), freed after.
##   water  as air's, in water (the owner, 2026-10-12: "water gathering is like trash it should be more fluid like maybe
##          smoke water", "the water gather should be like air", "we want the water to gather where the attack is going to
##          be"): thin wisps of water coil and spiral up round the body, a blue mist swirling with them, then wind tight round
##          the limb; the Geyser's flows out along the deck to where it will rise and gathers there (then: "have it charge
##          where the spells are going to be or let it flow there"): from before his feet to the cast's own place as the
##          lock fills (_water_spot: the foe he tracks, else the aim's ground, within its reach), a low whirl closing in,
##          the deck breaking behind it as the Fissure's does ("it moves still like a fissure right": _fissure_step);
##          cast, the body is marked (WATER_SENT_META) so the Geyser sends no more water from his feet; drops shake off
##   fire   born on the body as the show draws it (2026-10-16, the cel look): a breath of flame at the mouth as the lock
##          begins, then thick flat tongues licking up along the striking limb (the forearm, or the shin for a kick) and a
##          flame held in the fist or on the foot, growing with the lock, flaring at the click, snapping out along the strike
##          and gone in a puff of smoke; no coils (see _build_fire)
##   earth  stones lift off the deck round the feet one by one, circle the body, then gather round the hands or the foot; a
##          Spike's or Boulder's raised stone (FormEffects.raised_of) is made from them: they fly into it one by one and it
##          grows from STONE_FROM of its size to its own (its look only; its body is as it was). Broken pieces lying near
##          (RockDebris; the owner: "we can have broken rock pieces on the floor we channel it to make the things") are
##          pulled in first; the rocks of a charge that falls away lie where they fell, pieces for the next
##   air    wind bands spiral round the body, then wind tight round the limb; dust swirls at the feet
## Our own effects only: ToonFx's materials and meshes, ToonRibbon trails, BendLooks' emitters and fireball body. Drawn only
## where effects are (BendLooks.live(): not headless); the fill, the limb, the pieces taken, the ending and the freeing run
## everywhere (the tests read them headless).

const GROUP := &"bend_charges"
## Every bending lock in the ring shows this in place of the circle (false: the circle as before).
const SHOW := true
const ELEMENTS := ["earth", "water", "fire", "air"]
const LIMBS := ["l_palm", "r_palm", "both", "l_foot", "r_foot"]
const FLASH_S := 0.35
## Each ending's own time (the heads flung or falling, the stones going), then the trails' tails (TAIL_S) before it is freed.
const END_S := {"cast": 0.32, "break": 0.45, "fizzle": 0.55}
const TAIL_S := 0.45
## The bones the element gathers round (the ring rig's), and where each is on a body without them (local, -Z forward).
const FALLBACK := {"l_palm": Vector3(-0.22, 1.12, -0.32), "r_palm": Vector3(0.22, 1.12, -0.32),
		"l_elbow": Vector3(-0.3, 1.18, -0.06), "r_elbow": Vector3(0.3, 1.18, -0.06),
		"l_knee": Vector3(-0.1, 0.5, -0.05), "r_knee": Vector3(0.1, 0.5, -0.05),
		"l_ball": Vector3(-0.12, 0.05, -0.15), "r_ball": Vector3(0.12, 0.05, -0.15)}
const LIGHT_RANGE := 2.6
## The share of the lock's level over which the element goes from round the body to the limb.
const CHANNEL := Vector2(0.3, 0.85)
## Water: a Geyser's water flowed out to its place while it charged (marked on the body as it is cast, BendStatus.now()):
## main's BendEffects.spout then sends none from his feet (BendLooks.geyser_send).
const WATER_SENT_META := &"bend_water_sent"
## Water: a Geyser's crack along the deck, a step of it (m) as the Fissure's rows are laid.
const FISSURE_STEP_M := 0.7
## Water: its wisps' width and colours (air's strip in water: a pale blue body, a deeper blue edge, a navy line).
const WISP_W := 0.08
const WISP_MAIN := Color(0.62, 0.86, 1.0, 0.9)
const WISP_EDGE := Color(0.18, 0.52, 0.98, 0.78)
const WISP_INK := Color(0.05, 0.18, 0.42)
## Fire (the cel look): SLEEVE tongues along a limb, a tongue's length and width at the lock's start and full (m), the fist's
## flame, the breath at the mouth (s), the sway's drawings a second (on twos with the shader's), and the cast's timing: the
## flames held pulled back on the limb (the wind-up) until the pose's strike or HOLD_S, then stretched along the strike for
## SNAP_S (the smear) and gone in a puff.
const SLEEVE := 4
const SLEEVE_LEN := Vector2(0.2, 0.46)
const SLEEVE_W := Vector2(0.13, 0.21)
const FIST_LEN := 0.58
const FIST_W := 0.3
const BREATH_S := 0.38
const MOUTH_Y := 1.3
const STEP_FPS := 12.0
const HOLD_S := 0.2
const SNAP_S := 0.09
## Each sleeve's limb (_seg) and the share the other limbs burn at while the element is round the body.
const SLEEVE_SEG := {"l_arm": "l_palm", "r_arm": "r_palm", "l_leg": "l_foot", "r_leg": "r_foot"}
const SLEEVE_LOW := 0.5
## Earth: the rocks, the loose pieces pulled in (within PULL_M flat, at most PULL_MAX, flying PULL_S), a rock's flight into
## the raised stone (INTO_S), and the share of its size the stone's look starts at while it is made from them.
const ROCKS := 9
const PULL_M := 7.0
const PULL_MAX := 7
const PULL_S := 0.5
const INTO_S := 0.3
const STONE_FROM := 0.35

var body: Node3D
var element := "water"
var fill := 0.0
var full := false
## "": charging; "cast", "break", "fizzle": ending (freed after).
var ending := ""
## The limb the move leaves from now (returns l_palm, r_palm, both, l_foot or r_foot; "", an unknown one or none: both).
var limb_fn: Callable
## Earth: the loose pieces this charge pulled in (RockDebris.take), its own from then.
var claimed: Array = []
## Earth: the rocks gone into the raised stone.
var merged := 0

var _t := 0.0
var _flash := 0.0
var _end_t := 0.0
var _visual := false
## Its sound while it gathers (the sound audit, 2026-10-13: a foe's wind-up was silent, his first sound its release): a
## quiet loop of its element on him (CHARGE_SOUNDS), CHARGE_DB rising with the fill and a little higher, faded at its end.
## Not on the listener's own body: his lock has its own tone (SwayTone).
const CHARGE_SOUNDS := {"earth": &"earth_grind", "water": &"water_slosh", "fire": &"fire_crackle", "air": &"air_swirl"}
const CHARGE_DB := Vector2(-22.0, -11.0)
var _hum: AudioStreamPlayer3D
var _skel: Skeleton3D
var _bones := {}
## The moving heads the ribbons follow: {head: Node3D, rb: ToonRibbon, phase, vel, w, stopped, drops}
var _runs: Array = []
## Earth's rocks: {mesh, phase, r, h, at, lift, size, spin, axis, speed, vel, lifted, src, fly, dep, into, from, gone}
var _rocks: Array = []
var _emit: Array = []
## Fire's flames: a MultiMesh of tongues a limb (SLEEVE_SEG's keys; the last instance the fist's or foot's flame), the breath at
## the mouth, the sparks off the striking limb, each limb's smoothed motion (the tongues trail it), the strike heard (the
## snap) and when.
var _sleeves := {}
var _breath: MeshInstance3D
var _spark: GPUParticles3D
var _limb_vel := {}
var _struck := false
var _snap_at := INF
var _snapped := false
var _light: OmniLight3D
## Water: its mist, and whether it gathers on the deck where it will rise now (the Geyser's), and that place.
var _mist: GPUParticles3D
var _deck := false
var _spot := Vector3.ZERO
## Water: where the Geyser's crack along the deck reached (_fissure_step; INF not begun).
var _fissure_last := Vector3.INF
var _shown := 0.0
## Earth: the raised stone being made from the rocks (its look, its own scale), the level when it rose, done.
var _stone: Node3D
var _stone_mi: Node3D
var _stone_base := Vector3.ONE
var _stone_k0 := 0.0
var _stone_done := false


## The element of `el` charging round `p_body` (under it, drawn in world space).
static func make(p_body: Node3D, el: String) -> BendCharge:
	var c := BendCharge.new()
	c.name = "BendCharge"
	c.body = p_body
	c.element = el if el in ELEMENTS else "water"
	c.add_to_group(GROUP)
	p_body.add_child(c)
	return c


## Whether a lock of move `m` by `body` shows the element round the body: every bending move of a fighter in the ring
## (BendR3.on: Tidebreak) while SHOW. The open world's Form art and the duel keep their circles (the circle-work asked for
## there, 2026-10-02).
static func wanted(m: String, p_body: Node) -> bool:
	return SHOW and m != "" and SwayMoves.move(m).has("bend") and BendR3.on(p_body)


func _ready() -> void:
	top_level = true
	_place()
	_visual = BendLooks.live()
	if element == "earth" and body != null and is_inside_tree():
		var deb := get_tree().current_scene.get_node_or_null(RockDebris.NODE_NAME) as RockDebris
		if deb != null:
			claimed = deb.take(body.global_position, PULL_M, PULL_MAX)
			for m: Node3D in claimed:
				var xf := m.global_transform
				m.get_parent().remove_child(m)
				add_child(m)                       # (its own from now: freed with it, or laid down again as it falls away)
				m.top_level = true
				m.global_transform = xf
	if not _visual:
		return
	_hum_on()
	if body != null:
		var sk := body.find_children("*", "Skeleton3D", true, false)
		if not sk.is_empty():
			_skel = sk[0] as Skeleton3D
			for b: String in FALLBACK:
				_bones[b] = _skel.find_bone(b)
	if element == "fire":
		# (the player's pose says when the strike lands: fire's flames snap out with it; a bot's snap at HOLD_S)
		var sc := SwayCaster.of(body) if body != null else null
		if sc != null and sc.pose != null and sc.pose.has_signal(&"struck"):
			sc.pose.struck.connect(_on_struck)
	match element:
		"water":
			_build_water()
		"fire":
			_build_fire()
		"earth":
			_build_earth()
		_:
			_build_air()
	_light = OmniLight3D.new()
	_light.light_color = _tint().lerp(Color.WHITE, 0.25)
	_light.omni_range = LIGHT_RANGE
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3(0, 1.1, 0)


## The limb the element is channelled to now: the move's (limb_fn), else both hands.
func limb() -> String:
	var l := String(limb_fn.call()) if limb_fn.is_valid() else ""
	return l if l in LIMBS else "both"


## The click: the lock is full.
func flash() -> void:
	_flash = 1.0
	if not _visual:
		return
	var pool := ToonFxPool.of(get_tree().current_scene) if is_inside_tree() else null
	var tip := _tip(limb())
	match element:
		"water":
			BendLooks.burst(_water_tip(), "water", 8, Vector3.UP, 120.0, 2.5, 0.16, false)
		"fire":
			# (the limb's flame flares up (the tongues' flare, _fire) and a few flat sparks fly off it: no blast, no cloud)
			if pool != null:
				pool.shoot("spark_fire", tip, 5, Vector3.UP, 60.0, Vector2(1.5, 3.2), Vector2(0.025, 0.04), 0.4,
						Vector3(0, -4.0, 0), 1.0)
		"earth":
			_dust_puff(_center(), 5, 1.4, 0.35)
		_:
			_dust_puff(tip, 4, 2.5, 0.3, "puff_air")


## The lock ended: "cast" flings the element out with the cast, "break" and "fizzle" let it fall away. Freed after.
func end(kind: String) -> void:
	if ending != "":
		return
	ending = kind if END_S.has(kind) else "break"
	_end_t = 0.0
	if _hum != null and is_instance_valid(_hum):
		var tw := _hum.create_tween()
		tw.tween_property(_hum, "volume_db", -60.0, 0.15)
		tw.tween_callback(_hum.stop)
	_stone_finish()
	for e in _emit:
		if is_instance_valid(e):
			(e as GPUParticles3D).emitting = false
	var out := _forward()
	for run: Dictionary in _runs:
		var v: Vector3 = run.vel
		if ending == "cast":
			var head := run.head as Node3D
			var away := Vector3(head.global_position.x - _center().x, 0.0, head.global_position.z - _center().z).normalized()
			run.vel = v * 1.4 + away * 3.5 + out * 6.0 + Vector3.UP * 1.0
		else:
			run.vel = v * 0.4
	for rk: Dictionary in _rocks:
		var m := rk.mesh as Node3D
		if ending == "cast":
			var away := Vector3(m.global_position.x - _center().x, 0.0, m.global_position.z - _center().z).normalized()
			rk.vel = away * 5.0 + out * 7.0 + Vector3.UP * 1.5
		else:
			rk.vel = Vector3.ZERO
	if element == "water" and ending == "cast" and _deck and body != null and is_instance_valid(body):
		body.set_meta(WATER_SENT_META, BendStatus.now())     # (its water is there already: no send from his feet)
		for run: Dictionary in _runs:
			var v2: Vector3 = run.vel
			run.vel = Vector3(v2.x * 0.2, 7.5, v2.z * 0.2)       # (the Geyser's: its wisps go up with the column)
	if _visual and ending == "cast":
		match element:
			"water":
				BendLooks.burst(_water_tip(), "water", 10, out, 70.0, 3.5, 0.16, false)
			"earth":
				_dust_puff(_center(), 8, 2.0, 0.45)
			"air":
				_dust_puff(_tip(limb()), 6, 3.0, 0.4, "puff_air")
	if _visual and element == "fire" and ending != "cast":
		# (snuffed: the flames shrink away and a puff of smoke comes off each limb that burned)
		for key: String in _sleeves:
			if (_sleeves[key] as Node3D).visible:
				BendLooks.fire_out((_seg(String(SLEEVE_SEG[key]))[1] as Vector3) + Vector3.UP * 0.05, 0.6, 1)


## Its loop begun (a fighter's not the listener's): CHARGE_SOUNDS of its element, at CHARGE_DB's quiet end.
func _hum_on() -> void:
	if body == null or not is_instance_valid(body) or not CHARGE_SOUNDS.has(element) or not BendSounds.arena_on(get_tree()):
		return
	if body is FrontierPlayer and (body as FrontierPlayer).camera != null \
			and (body as FrontierPlayer).camera == get_viewport().get_camera_3d():
		return
	_hum = BendSounds.loop_player(CHARGE_SOUNDS[element], self, absi(body.get_instance_id()) % 4)
	if _hum != null:
		_hum.volume_db = CHARGE_DB.x
		_hum.position = Vector3.UP * 1.0
		_hum.play(float(absi(body.get_instance_id()) % 50) / 100.0)     # (never the game's dice for a sound)


func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt / FLASH_S)
	if _hum != null and is_instance_valid(_hum) and ending == "":
		_hum.volume_db = lerpf(CHARGE_DB.x, CHARGE_DB.y, clampf(fill, 0.0, 1.0))
		_hum.pitch_scale = lerpf(0.92, 1.12, clampf(fill, 0.0, 1.0))
	if body == null or not is_instance_valid(body):
		queue_free()
		return
	_place()
	if ending != "":
		_end_t += dt
		if _end_t >= float(END_S[ending]) + TAIL_S:
			_leave_rocks()
			queue_free()
			return
	if not _visual:
		return
	# (how much of it shows: half at once as the lock begins (it reads from the first frames), then grows with the fill; it
	# goes as it ends)
	var want := 0.0 if ending != "" else clampf(0.5 + fill * 0.5, 0.0, 1.0)
	_shown = move_toward(_shown, want, dt * (8.0 if want > _shown else 2.5))
	match element:
		"water":
			_water(dt)
		"fire":
			_fire(dt)
		"earth":
			_earth(dt)
		_:
			_air(dt)
	if _light != null:
		var pulse := 1.0 + (0.18 * sin(_t * 11.0) if full and ending == "" else 0.0)
		_light.light_energy = (0.25 + 1.4 * _level()) * _shown * pulse + 1.6 * _flash
		_light.global_position = _center().lerp(_tip(limb()), _channel()) + Vector3.UP * 0.1


func _exit_tree() -> void:
	_stone_finish()


# ---------------------------------------------------------------- shared
func _place() -> void:
	if body != null and is_instance_valid(body):
		global_transform = Transform3D(Basis.IDENTITY, body.global_position)


func _center() -> Vector3:
	return global_position


## The lock's level for the look: its fill eased, pulsing a little while full.
func _level() -> float:
	var k := smoothstep(0.0, 1.0, fill)
	if full and ending == "":
		k = 1.0 + 0.06 * sin(_t * 11.0)
	return k


## How far the element has gone from round the body to the limb (0..1).
func _channel() -> float:
	return smoothstep(CHANNEL.x, CHANNEL.y, minf(_level(), 1.0))


func _tint() -> Color:
	return BendLooks.color("stone" if element == "earth" else element)


## Where the body faces (flat; the caster's forward).
func _forward() -> Vector3:
	if body == null or not is_instance_valid(body):
		return Vector3.FORWARD
	var f := -body.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-4 else Vector3.FORWARD


## Bone `b`'s place (world), else its fallback on the body.
func _bone(b: String) -> Vector3:
	var id := int(_bones.get(b, -1))
	if _skel != null and is_instance_valid(_skel) and id >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(id).origin
	if body != null and is_instance_valid(body) and FALLBACK.has(b):
		var f := _forward()
		var side := f.cross(Vector3.UP).normalized() * -1.0
		var l: Vector3 = FALLBACK[b]
		return body.global_position + side * l.x + Vector3.UP * l.y - f * l.z
	return _center() + Vector3.UP * 1.0


## Limb `l`'s stretch (world, [from, to]): the forearm (elbow to palm) of a hand, the shin (knee to the ball of the foot) of
## a foot, from the left palm to the right for both.
func _seg(l: String) -> Array:
	match l:
		"l_palm":
			return [_bone("l_elbow"), _bone("l_palm")]
		"r_palm":
			return [_bone("r_elbow"), _bone("r_palm")]
		"l_foot":
			return [_bone("l_knee"), _bone("l_ball")]
		"r_foot":
			return [_bone("r_knee"), _bone("r_ball")]
	return [_bone("l_palm"), _bone("r_palm")]


## Where limb `l`'s element gathers: the palm, the ball of the foot, or between the palms.
func _tip(l: String) -> Vector3:
	var s := _seg(l)
	return ((s[0] as Vector3) + (s[1] as Vector3)) * 0.5 if l == "both" else s[1]


## A point on a coil round stretch `seg`: `u` along it (0 its from, 1 its to), `th` round it, `r` off it.
static func _coil(seg: Array, u: float, th: float, r: float) -> Vector3:
	var a: Vector3 = seg[0]
	var b: Vector3 = seg[1]
	var ax := b - a
	var n := ax.length()
	ax = ax / n if n > 0.01 else Vector3.UP
	var b1 := ax.cross(Vector3.UP)
	if b1.length_squared() < 1e-4:
		b1 = ax.cross(Vector3.RIGHT)
	b1 = b1.normalized()
	var b2 := ax.cross(b1).normalized()
	return a.lerp(b, u) + (b1 * cos(th) + b2 * sin(th)) * r


## A head (an invisible point the ribbon follows) with its ribbon of `mat`.
func _run(mat: String, w: float, tail: float, life: float, coils := 0, phase := 0.0) -> Dictionary:
	var head := Node3D.new()
	head.top_level = true
	add_child(head)
	head.global_position = _center() + Vector3.UP
	var rb := ToonRibbon.new()
	rb.main_mat = ToonFx.mat(mat)
	rb.width = w
	rb.tail_w = tail
	rb.life = life
	if coils > 0:
		rb.coils = coils
		rb.coil_mat = ToonFx.mat(mat)
		rb.coil_r = w * 1.4
		rb.coil_w = w * 0.35
		rb.coil_spin = 20.0
	add_child(rb)
	var run := {"head": head, "rb": rb, "phase": phase, "vel": Vector3.ZERO, "w": w, "stopped": false}
	rb.follow(head)
	_runs.append(run)
	return run


## A head moved to `p` (or flung / falling while it ends); its ribbon let go a moment into the ending.
func _move(run: Dictionary, p: Vector3, dt: float) -> void:
	var head := run.head as Node3D
	if ending != "":
		var v: Vector3 = run.vel
		if ending != "cast":
			v += Vector3(0, -9.0, 0) * dt
		run.vel = v
		head.global_position += v * dt
		if not bool(run.stopped) and _end_t > float(END_S[ending]) * 0.6:
			(run.rb as ToonRibbon).stop()
			run.stopped = true
		return
	if dt > 0.0:
		run.vel = (p - head.global_position) / dt
	head.global_position = p
	(run.rb as ToonRibbon).width = float(run.w) * clampf(_shown, 0.05, 1.0) * (1.0 + 0.35 * _flash)


func _emitter(kind: String, extents: Vector3, amount: int, life: float, rise: float, size: float) -> GPUParticles3D:
	var g := BendLooks.emitter(self, kind, extents, amount, life, rise, size)
	if g != null:
		g.local_coords = false
		g.amount_ratio = 0.05
		_emit.append(g)
	return g


func _dust_puff(at: Vector3, n: int, speed: float, size: float, key := "puff_dust") -> void:
	var pool := ToonFxPool.of(get_tree().current_scene) if is_inside_tree() else null
	if pool == null:
		return
	pool.shoot(key, at + Vector3.UP * 0.1, n, Vector3.UP, 80.0, Vector2(speed * 0.3, speed), Vector2(size * 0.6, size),
			0.7, Vector3(0, 0.5, 0), 2.0, {"r": 0.3, "flat": 0.6})


# ---------------------------------------------------------------- water
func _build_water() -> void:
	# (air's wisps in water: thin, coiling, the wind shader's strip tinted as the water)
	var wm := ToonFx.mat("wind_strip").duplicate() as ShaderMaterial
	wm.set_shader_parameter(&"c_main", WISP_MAIN)
	wm.set_shader_parameter(&"c_edge", WISP_EDGE)
	wm.set_shader_parameter(&"c_ink", WISP_INK)
	for i in 4:
		var run := _water_run(wm, TAU * float(i) / 4.0)
		var drops := BendLooks.emitter(run.head, "water", Vector3(0.04, 0.04, 0.04), 6, 0.45, 0.4, 0.035)
		if drops != null:
			drops.local_coords = false
			drops.amount_ratio = 0.05
			_emit.append(drops)
			run.drops = drops
	# (the mist: blue puffs swirling with the wisps, as air's dust swirls; where the water gathers)
	_mist = _emitter("frost", Vector3(0.45, 0.06, 0.45), 22, 0.75, 0.5, 0.32)
	if _mist != null:
		var pm := _mist.process_material as ParticleProcessMaterial
		pm.tangential_accel_min = 4.0
		pm.tangential_accel_max = 7.0


## A wisp of `mat` (air's _run, its material a water-tinted copy of air's).
func _water_run(mat: ShaderMaterial, phase: float) -> Dictionary:
	var head := Node3D.new()
	head.top_level = true
	add_child(head)
	head.global_position = _center() + Vector3.UP
	var rb := ToonRibbon.new()
	rb.main_mat = mat
	rb.width = WISP_W
	rb.tail_w = 0.2
	rb.life = 0.34
	rb.coils = 1
	rb.coil_mat = mat
	rb.coil_r = WISP_W * 1.4
	rb.coil_w = WISP_W * 0.35
	rb.coil_spin = 20.0
	add_child(rb)
	var run := {"head": head, "rb": rb, "phase": phase, "vel": Vector3.ZERO, "w": WISP_W, "stopped": false}
	rb.follow(head)
	_runs.append(run)
	return run


## The bend spec of the move charging when its water gathers on the deck where it will rise (the Geyser's, do "spout"),
## else {}: the player's lock (SwayCaster), a bot's (its brain's NpcBending).
func _deck_spec() -> Dictionary:
	if body == null or not is_instance_valid(body):
		return {}
	var m := ""
	var md := ""
	var sc := SwayCaster.of(body)
	if sc != null and sc.move != "":
		m = sc.move
		md = sc.mode_of(m)
	elif body is NpcFighter and (body as NpcFighter).brain != null and (body as NpcFighter).brain.bending != null:
		m = (body as NpcFighter).brain.bending.casting
		md = (body as NpcFighter).brain.bending.mode
	var b: Variant = SwayMoves.move(m).get("bend", {}) if m != "" else {}
	var s: Variant = (b as Dictionary).get(md, {}) if b is Dictionary else {}
	if s is Dictionary and String((s as Dictionary).get("do", "")) == "spout":
		return s
	return {}


## Where the Geyser will rise (its cast's own place): the foe the player's lock tracks (SwayCaster.track_target, where the
## game has it), else the aim's ground (BendEffects.aim, the bot's own pick for a bot) within the spec's reach.
func _water_spot(spec: Dictionary) -> Vector3:
	var sc := SwayCaster.of(body)
	var tt: Variant = sc.get(&"track_target") if sc != null else null
	if tt is Node3D and is_instance_valid(tt) and float(sc.get(&"track_off")) <= 0.25:
		return FormEffects.ground_at(body, (tt as Node3D).global_position) + Vector3.UP * 0.08
	var bc := BendCaster.of(body)
	if bc == null:
		return _center() + _forward() * 2.0
	return BendEffects._ground_at(body, BendEffects.aim(bc, spec), spec) + Vector3.UP * 0.08


## The Geyser's water going along the deck as the Fissure's ground does: every FISSURE_STEP_M of its way the deck cracks
## where it passed and water spurts up out of the crack, a chip or two of the deck with it.
func _fissure_step() -> void:
	var at := _water_tip()
	at.y -= 0.08
	if _fissure_last == Vector3.INF:
		_fissure_last = at
		return
	var flat := Vector3(at.x - _fissure_last.x, 0.0, at.z - _fissure_last.z)
	if flat.length() < FISSURE_STEP_M:
		return
	var way := flat.normalized()
	var n := int(flat.length() / FISSURE_STEP_M)
	var pool := ToonFxPool.of(get_tree().current_scene) if is_inside_tree() else null
	for i in n:
		var pt := _fissure_last + way * FISSURE_STEP_M * float(i + 1)
		pt.y = at.y
		if pool != null:
			pool.mark("cracks", pt + Vector3.UP * 0.01, Vector3.UP, 0.9, 1.6)
		BendLooks.burst(pt + Vector3.UP * 0.05, "water", 6, (Vector3.UP * 1.4 + way).normalized(), 30.0, 3.2, 0.16, false)
		BendLooks.burst(pt + Vector3.UP * 0.05, "stone", 2, Vector3.UP, 50.0, 2.0, 0.08, false)
	_fissure_last += way * FISSURE_STEP_M * float(n)


## Where the water gathers now: the Geyser's flowing from before his feet out along the deck to where it will rise as the
## lock fills; else the limb's tip.
func _water_tip() -> Vector3:
	if _deck:
		var from := _center() + _forward() * 0.35 + Vector3.UP * 0.08
		return from.lerp(_spot, smoothstep(0.1, 0.9, minf(_level(), 1.0)))
	return _tip(limb())


func _water(dt: float) -> void:
	var k := _level()
	var ch := _channel()
	var l := limb()
	var seg := _seg(l)
	var ds := _deck_spec()
	_deck = not ds.is_empty()
	if _deck:
		_spot = _water_spot(ds)
	var w := lerpf(4.5, 9.5, minf(k, 1.0)) + 6.0 * _flash
	var c := _center()
	var wrap_r := 0.25 if l.ends_with("foot") else 0.22
	for i in _runs.size():
		var run: Dictionary = _runs[i]
		var th := float(run.phase) + _t * w
		var h := lerpf(0.3, 1.0, minf(k, 1.0)) + 0.65 * sin(th * 0.35 + float(i) * 1.6)
		h = clampf(h, 0.05, 1.9)
		# (air's vortex: wider at the top, closing in as it fills)
		var r := lerpf(1.0, 0.6, minf(k, 1.0)) * lerpf(0.85, 1.15, clampf(h / 2.0, 0.0, 1.0))
		var p := c + Vector3(cos(th) * r, h, sin(th) * r)
		var to := Vector3.ZERO
		if _deck:
			# (the Geyser's: down to the deck before his feet, a low whirl closing in, where it is sent from)
			var foot := _water_tip()
			var rr := lerpf(0.85, 0.35, ch)
			to = Vector3(foot.x + cos(th) * rr, foot.y + 0.05 + 0.1 * absf(sin(th * 1.3 + float(i))), foot.z + sin(th) * rr)
		else:
			var u := fposmod(_t * 1.3 + float(i) * 0.25, 1.0)
			to = _coil(seg, lerpf(0.0, 1.1, u) if l != "both" else u, th * 1.5, wrap_r)
		_move(run, p.lerp(to, ch * 0.9), dt)
		if run.has("drops") and is_instance_valid(run.drops) and ending == "":
			(run.drops as GPUParticles3D).amount_ratio = clampf(0.1 + 0.6 * k, 0.05, 1.0) * _shown
	if _deck and _visual and ending == "":
		_fissure_step()
	if _mist != null and is_instance_valid(_mist) and ending == "":
		# (the mist round his feet at first, then where the water gathers)
		_mist.global_position = (c + Vector3.UP * 0.1).lerp(_water_tip(), ch)
		_mist.amount_ratio = clampf(0.15 + 0.7 * k + 0.5 * _flash, 0.05, 1.0) * _shown


# ---------------------------------------------------------------- fire
## Fire (2026-10-16, the cel look; the owner: as the show draws it): no coils. Flame is born on the body: a breath of it at the
## mouth as the lock begins (BREATH_S), then thick flat tongues licking up along the striking limb, the forearm (the elbow to
## past the palm) or the shin (the knee to the ball of the foot), each tongue's base on the limb, pointing up and away from
## the body and trailing the limb's motion, and a bigger flame held in the fist (or on the foot). Both forearms burn low
## (SLEEVE_LOW) while the element is round the body; channelled, the striking limb's flames grow whole and the other's go out
## (a kick: both arms go out, the shin and the foot come up). They grow with the lock, flare at the click, and at the cast
## stay pulled back on the limb (the wind-up, HOLD_S or until the pose's strike), snap out along the strike for SNAP_S (a smear,
## as a drawing's) and are gone in a puff of smoke and a few sparks (BendLooks.fire_out). Their sway steps on twos (STEP_FPS)
## with the shader's drawings. One MultiMesh a limb (SLEEVE + 1 quads of ToonFx "flame", mode 0: each turned round its own axis
## to face the camera), a quad for the breath, a few sparks off the fist.
func _build_fire() -> void:
	for key: String in SLEEVE_SEG:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ToonFx.quad_base()
		mm.instance_count = SLEEVE + 1
		for i in SLEEVE + 1:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Sleeve_" + key
		mmi.multimesh = mm
		mmi.material_override = ToonFx.mat("flame")
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 4.0
		mmi.top_level = true
		mmi.visible = false
		FxParams.put(mmi, &"seed", ToonFx.vis_rng.randf() * 10.0)
		add_child(mmi)
		mmi.global_transform = Transform3D.IDENTITY
		_sleeves[key] = mmi
	_breath = MeshInstance3D.new()
	_breath.name = "Breath"
	_breath.mesh = ToonFx.quad_base()
	_breath.material_override = ToonFx.mat("flame")
	_breath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_breath.extra_cull_margin = 2.0
	_breath.top_level = true
	_breath.visible = false
	FxParams.put(_breath, &"seed", ToonFx.vis_rng.randf() * 10.0)
	add_child(_breath)
	_spark = _emitter("embers", Vector3(0.06, 0.06, 0.06), 6, 0.45, 1.2, 0.028)


## The pose's strike (the player's): the flames snap out with it.
func _on_struck(_m: String) -> void:
	if ending == "cast" and not _struck:
		_struck = true
		_snap_at = _end_t


## The mouth: before the face at MOUTH_Y over the body's feet (the rig's head bone is the head's top: its breath came out over
## the head).
func _mouth() -> Vector3:
	return _center() + Vector3.UP * MOUTH_Y + _forward() * 0.22


## A drawing's jitter for tongue `i` at drawing `step`: 0.8 .. 1.2, the same for a whole drawing, new at the next.
static func _jit(i: int, step: int) -> float:
	var h := fmod(sin(float(i) * 12.9898 + float(step) * 78.233) * 43758.5453, 1.0)
	return 0.8 + 0.4 * absf(h)


## A tongue's transform for the flame shader's mode 0: its base at `base`, `axis` its way (world), `len` m long, `w` m wide.
static func _tongue(base: Vector3, axis: Vector3, len: float, w: float) -> Transform3D:
	var ax := axis.normalized() if axis.length_squared() > 1e-6 else Vector3.UP
	var side := ax.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = ax.cross(Vector3.RIGHT)
	side = side.normalized()
	return Transform3D(Basis(side * maxf(w, 0.001), ax * maxf(len, 0.001), side.cross(ax).normalized()), base)


## Limb `key`'s motion (m/s, smoothed): its middle `mid` now against the last frame's.
func _limb_motion(key: String, mid: Vector3, dt: float) -> Vector3:
	var e: Dictionary = _limb_vel.get(key, {})
	var v := Vector3.ZERO
	if e.has("at") and dt > 0.0:
		v = ((mid - (e.at as Vector3)) / dt).limit_length(12.0)
		v = (e.vel as Vector3).lerp(v, 0.35)
	_limb_vel[key] = {"at": mid, "vel": v}
	return v


func _fire(dt: float) -> void:
	var k := minf(_level(), 1.0)
	var ch := _channel()
	var l := limb()
	var step := floori(_t * STEP_FPS)
	var out := _forward()
	# (what each limb burns at: both forearms low while the element is round the body; channelled, the striker's whole and
	# the others' out)
	var on := {"l_arm": SLEEVE_LOW, "r_arm": SLEEVE_LOW, "l_leg": 0.0, "r_leg": 0.0}
	match l:
		"l_palm":
			on.l_arm = lerpf(SLEEVE_LOW, 1.0, ch)
			on.r_arm = SLEEVE_LOW * (1.0 - ch)
		"r_palm":
			on.r_arm = lerpf(SLEEVE_LOW, 1.0, ch)
			on.l_arm = SLEEVE_LOW * (1.0 - ch)
		"l_foot", "r_foot":
			on.l_arm = SLEEVE_LOW * (1.0 - ch)
			on.r_arm = SLEEVE_LOW * (1.0 - ch)
			on["l_leg" if l == "l_foot" else "r_leg"] = ch
		_:
			on.l_arm = lerpf(SLEEVE_LOW, 1.0, ch)
			on.r_arm = lerpf(SLEEVE_LOW, 1.0, ch)
	# (the cast: held back on the limb (back: the wind-up's lean against the strike), then the snap, then gone)
	var back := 0.0
	var snap := 0.0
	var die := 1.0
	if ending == "cast":
		var snap_at := minf(_snap_at, HOLD_S)
		if _end_t < snap_at:
			back = clampf(_end_t / maxf(snap_at, 0.01), 0.0, 1.0)
		else:
			snap = 1.0 - clampf((_end_t - snap_at) / SNAP_S, 0.0, 1.0)
			die = snap
			if snap <= 0.0 and not _struck:
				_struck = true                      # (a bot's: no pose signal; the snap ran at HOLD_S)
	elif ending != "":
		die = maxf(0.0, 1.0 - _end_t / float(END_S[ending]))
	var flare := 1.0 + 0.45 * _flash
	var shown := clampf(_shown, 0.05, 1.0)
	var tip_of := Vector3.INF
	for key: String in _sleeves:
		var mmi := _sleeves[key] as MultiMeshInstance3D
		var s := float(on[key]) * die
		var seg := _seg(String(SLEEVE_SEG[key]))
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		if s < 0.03 or _shown < 0.03 or (ending == "cast" and _end_t > minf(_snap_at, HOLD_S) + SNAP_S):
			mmi.visible = false
			continue
		mmi.visible = true
		var ax := b - a
		var ln := ax.length()
		ax = ax / ln if ln > 0.01 else Vector3.UP
		var away := (a + b) * 0.5 - (_center() + Vector3.UP * 1.0)
		away -= ax * away.dot(ax)
		away = away.normalized() if away.length_squared() > 1e-4 else Vector3.UP
		var vel := _limb_motion(key, (a + b) * 0.5, dt)
		# (the tongues lick up and away off the limb, trailing where it moves; the wind-up pulls them back along it, the
		# snap throws them out along the strike)
		var lick := (Vector3.UP * 0.8 + away * 0.45 - vel * 0.06).normalized()
		lick = lick.lerp(-out * 0.6 + Vector3.UP * 0.4, 0.45 * back).normalized()
		if snap > 0.0:
			lick = lick.lerp(out, 0.85).normalized()
		var grow := shown * s * flare
		var mm := mmi.multimesh
		var kh := absi(key.hash()) % 7
		for i in SLEEVE:
			var j := _jit(i + kh, step)
			var u := 0.1 + 0.9 * (float(i) + 0.5) / float(SLEEVE) + (j - 1.0) * 0.08
			var base := a.lerp(b, u) + away * 0.03
			var len := lerpf(SLEEVE_LEN.x, SLEEVE_LEN.y, k) * grow * j * (1.0 + 1.5 * snap)
			var w := lerpf(SLEEVE_W.x, SLEEVE_W.y, k) * grow * (1.0 - 0.45 * snap)
			var axis := (lick + ax * ((j - 1.0) * 1.5)).normalized()
			mm.set_instance_transform(i, _tongue(base, axis, len, w))
		# (the fist's or the foot's flame: bigger, leaning forward, the first to snap out)
		var tip := b + ax * 0.03
		var jf := _jit(9 + kh, step)
		var flen := FIST_LEN * lerpf(0.5, 1.0, k) * grow * jf * (1.0 + 2.4 * snap)
		var fw := FIST_W * grow * (1.0 - 0.4 * snap)
		var faxis := (Vector3.UP * 0.7 + out * 0.35 + away * 0.2 - vel * 0.05).normalized()
		faxis = faxis.lerp(-out * 0.5 + Vector3.UP * 0.5, 0.5 * back).normalized()
		if snap > 0.0:
			faxis = faxis.lerp(out, 0.9).normalized()
		mm.set_instance_transform(SLEEVE, _tongue(tip, faxis, flen, fw))
		if s >= 0.9 or tip_of == Vector3.INF:
			tip_of = tip
	# (the breath: a flat tongue of flame breathed out at the mouth as the lock begins, gone as the arms take it)
	if _breath != null:
		var bt := _t / BREATH_S
		if ending == "" and bt < 1.0 and _shown > 0.05:
			_breath.visible = true
			var bl := 0.28 * sin(PI * bt) * _jit(3, step)
			var baxis := (out * 0.8 + Vector3.DOWN * 0.12).normalized()
			_breath.global_transform = _tongue(_mouth(), baxis, bl, 0.17 * _jit(5, step))
		else:
			_breath.visible = false
	# (a few flat sparks off the striking limb)
	if _spark != null and is_instance_valid(_spark):
		if tip_of != Vector3.INF:
			_spark.global_position = tip_of + Vector3.UP * 0.1
		_spark.amount_ratio = clampf(0.1 + 0.6 * k + 0.4 * _flash, 0.05, 1.0) * _shown if ending == "" else 0.05
	# (the snap's first frame: the flame leaves the limb in a puff of smoke and a few sparks, where the fist was)
	if ending == "cast" and snap > 0.0 and snap > 0.95 and not _snapped and tip_of != Vector3.INF:
		_snapped = true
		BendLooks.fire_out(tip_of + out * 0.15, 0.7, 2)


# ---------------------------------------------------------------- earth
func _build_earth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(get_instance_id()))
	var n := maxi(ROCKS, claimed.size())
	for i in n:
		var m: Node3D
		var src := Vector3.INF
		var size := rng.randf_range(0.2, 0.32)
		if i < claimed.size():
			# (a broken piece lying near: pulled in from where it lies, its own size)
			m = claimed[i] as Node3D
			src = m.global_position
			size = m.scale.x
			_dust_puff(src, 2, 0.6, 0.2)
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = ToonFx.chunk_mesh(i % 4)
			mi.material_override = ToonFx.mat("rock")
			mi.top_level = true
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mi)
			m = mi
		_rocks.append({"mesh": m, "phase": TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3),
				"r": rng.randf_range(0.75, 1.1), "h": rng.randf_range(0.35, 1.25),
				"at": 0.0 if src != Vector3.INF else float(i - claimed.size()) / float(maxi(n - claimed.size(), 1)) * 0.8,
				"lift": 1.0 if src != Vector3.INF else 0.0, "size": size, "spin": rng.randf_range(1.5, 4.0),
				"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
				"speed": rng.randf_range(0.8, 1.2), "vel": Vector3.ZERO, "lifted": src != Vector3.INF, "src": src,
				"fly": 0.0 if src != Vector3.INF else 1.0, "dep": INF, "into": -1.0, "from": Vector3.ZERO, "gone": false})
	var dust := _emitter("dust", Vector3(0.55, 0.04, 0.55), 14, 0.8, 0.5, 0.3)
	if dust != null:
		dust.position = Vector3(0, 0.05, 0)


## The stone the body raised and holds (a Spike's or a Boulder's, FormEffects.raised_of), null none.
func _raised() -> Node3D:
	var th := FormEffects.raised_of(body)
	return th.stone if th != null else null


## Its look back to its own size (the rocks all in, or the charge over), and left alone from then (its growing in the hands
## is FormStone.grow's).
func _stone_finish() -> void:
	if _stone_done:
		return
	_stone_done = true
	if _stone_mi != null and is_instance_valid(_stone_mi):
		_stone_mi.scale = _stone_base


func _earth(dt: float) -> void:
	var k := _level()
	var ch := _channel()
	var l := limb()
	var foot := l.ends_with("foot")
	var tip := _tip(l)
	var tight := smoothstep(0.7, 1.0, minf(k, 1.0))
	var w := lerpf(1.1, 2.6, minf(k, 1.0)) + 2.0 * _flash
	var c := _center()
	# (a raised stone made from the rocks: its look small, the rocks going into it one by one, all in a little before full)
	if ending == "" and _stone == null and not _stone_done:
		var st := _raised()
		if st != null and st.get("mesh_instance") is Node3D:
			_stone = st
			_stone_mi = st.get("mesh_instance") as Node3D
			_stone_base = _stone_mi.scale
			_stone_k0 = minf(k, 1.0)
			_stone_mi.scale = _stone_base * STONE_FROM
			var left := _rocks.filter(func(r: Dictionary) -> bool: return not bool(r.gone))
			for j in left.size():
				(left[j] as Dictionary).dep = _stone_k0 + (1.0 - _stone_k0) * 0.8 * float(j) / float(maxi(left.size(), 1))
	var making := _stone != null and is_instance_valid(_stone) and not _stone_done
	var heart := Vector3.INF
	if making and _stone_mi != null and is_instance_valid(_stone_mi) and _stone_mi is MeshInstance3D:
		var mi := _stone_mi as MeshInstance3D
		heart = mi.global_transform * (mi.get_aabb().get_center() if mi.mesh != null else Vector3.ZERO)
	elif making:
		heart = _stone.global_position
	for i in _rocks.size():
		var rk: Dictionary = _rocks[i]
		var m := rk.mesh as Node3D
		if not is_instance_valid(m) or bool(rk.gone):
			continue
		if ending != "":
			var v: Vector3 = rk.vel
			if ending != "cast":
				v += Vector3(0, -12.0, 0) * dt
			rk.vel = v
			m.global_position += v * dt
			if ending == "cast":
				var left := 1.0 - _end_t / float(END_S[ending])
				m.scale = Vector3.ONE * float(rk.size) * clampf(left, 0.0, 1.0)
				m.visible = left > 0.0
			elif m.global_position.y < c.y + 0.06:
				m.global_position.y = c.y + 0.06      # (fallen: it lies on the deck, a piece for the next)
				rk.vel = Vector3.ZERO
			continue
		var on := minf(k, 1.0) >= float(rk.at)
		var lift := clampf(float(rk.lift) + (dt / 0.2 if on else -dt / 0.25), 0.0, 1.0)
		rk.lift = lift
		var th := float(rk.phase) + _t * w * float(rk.speed)
		# (round the body, closing in at the waist as it fills; channelled, round the hands or the foot)
		var r := lerpf(float(rk.r), 0.58, tight)
		var h := lerpf(float(rk.h), 0.95 + 0.25 * sin(float(i) * 1.9), tight)
		var tgt := c + Vector3(cos(th) * r, h + 0.05 * sin(_t * 3.0 + float(i)), sin(th) * r)
		var ring_r := 0.3 if foot else 0.36
		var ring := tip + Vector3(cos(th) * ring_r, (0.14 if foot else 0.0) + 0.12 * sin(th * 1.7 + float(i)), sin(th) * ring_r)
		tgt = tgt.lerp(ring, ch)
		if making and float(rk.into) < 0.0 and minf(k, 1.0) >= float(rk.dep):
			rk.into = 0.0
			rk.from = m.global_position
		var p := tgt
		if float(rk.into) >= 0.0 and heart != Vector3.INF:
			# (into the stone: it flies in and is gone, the stone a share bigger)
			var into := minf(float(rk.into) + dt / INTO_S, 1.0)
			rk.into = into
			p = (rk.from as Vector3).lerp(heart, into * into)
			if into >= 1.0:
				rk.gone = true
				m.visible = false
				merged += 1
				var total := _rocks.size()
				if is_instance_valid(_stone_mi):
					_stone_mi.scale = _stone_base * lerpf(STONE_FROM, 1.0, clampf(float(merged) / float(total), 0.0, 1.0))
				_dust_puff(heart - Vector3.UP * 0.1, 1, 0.5, 0.18)
				if merged >= total:
					_stone_finish()
				continue
		elif rk.src != Vector3.INF and float(rk.fly) < 1.0:
			# (a broken piece pulled in from where it lay: it hops up off the deck and flies to its place)
			var fly := minf(float(rk.fly) + dt / PULL_S, 1.0)
			rk.fly = fly
			var e := 1.0 - pow(1.0 - fly, 2.0)
			p = (rk.src as Vector3).lerp(tgt, e) + Vector3.UP * 0.7 * sin(PI * fly)
		elif rk.src == Vector3.INF:
			p.y = lerpf(c.y, tgt.y, 1.0 - pow(1.0 - lift, 3.0))   # (lifted up off the deck)
		m.global_position = p
		m.rotate(rk.axis, dt * float(rk.spin))
		m.scale = Vector3.ONE * float(rk.size) * clampf(lift * 1.4, 0.0, 1.0) * (1.0 + 0.25 * _flash)
		m.visible = lift > 0.01
		if lift > 0.0 and not bool(rk.lifted):
			rk.lifted = true
			_dust_puff(Vector3(p.x, c.y, p.z), 3, 0.8, 0.25)
		elif lift <= 0.0 and rk.src == Vector3.INF:
			rk.lifted = false
	if making and minf(k, 1.0) >= 1.0 and merged >= _rocks.size():
		_stone_finish()
	for e in _emit:
		if is_instance_valid(e) and ending == "":
			# (the dust at the feet settles as the earth goes to the hands)
			(e as GPUParticles3D).amount_ratio = clampf(0.1 + 0.7 * k + 0.5 * _flash, 0.05, 1.0) * _shown \
					* (1.0 - 0.65 * ch if not foot else 1.0)


## A charge that fell away (break, fizzle): its rocks lie where they fell, broken pieces for the next earth charge
## (RockDebris); a cast's went with it. Pulled pieces never used go back too.
func _leave_rocks() -> void:
	if element != "earth" or not is_inside_tree() or not ending in ["break", "fizzle"]:
		return
	var deb := RockDebris.of(get_tree().current_scene)
	if deb == null:
		return
	if not _visual:
		for m: Node3D in claimed:
			if is_instance_valid(m):
				deb.lay(m)                         # (headless: the pieces it took, as they were)
		return
	for rk: Dictionary in _rocks:
		var m := rk.mesh as Node3D
		if is_instance_valid(m) and not bool(rk.gone) and m.visible and m.scale.x > 0.05:
			deb.lay(m)


# ---------------------------------------------------------------- air
func _build_air() -> void:
	for i in 4:
		_run("wind_strip", 0.07, 0.2, 0.3, 1, TAU * float(i) / 4.0)
	var swirl := _emitter("air", Vector3(0.5, 0.04, 0.5), 18, 0.7, 0.7, 0.3)
	if swirl != null:
		swirl.position = Vector3(0, 0.05, 0)
		var pm := swirl.process_material as ParticleProcessMaterial
		pm.tangential_accel_min = 4.0
		pm.tangential_accel_max = 7.0


func _air(dt: float) -> void:
	var k := _level()
	var ch := _channel()
	var l := limb()
	var seg := _seg(l)
	var w := lerpf(5.0, 10.5, minf(k, 1.0)) + 6.0 * _flash
	var c := _center()
	var wrap_r := 0.25 if l.ends_with("foot") else 0.22
	for i in _runs.size():
		var run: Dictionary = _runs[i]
		var th := float(run.phase) + _t * w
		var h := lerpf(0.35, 1.0, minf(k, 1.0)) + 0.75 * sin(th * 0.35 + float(i) * 1.6)
		h = clampf(h, 0.05, 2.0)
		# (a vortex: wider at the top, closing in as it fills; channelled, it winds tight round the limb)
		var r := lerpf(1.05, 0.6, minf(k, 1.0)) * lerpf(0.8, 1.2, clampf(h / 2.0, 0.0, 1.0))
		var p := c + Vector3(cos(th) * r, h, sin(th) * r)
		var u := fposmod(_t * 1.3 + float(i) * 0.25, 1.0)
		var wrap := _coil(seg, lerpf(0.0, 1.1, u) if l != "both" else u, th * 1.5, wrap_r)
		_move(run, p.lerp(wrap, ch * 0.85), dt)
	for e in _emit:
		if is_instance_valid(e) and ending == "":
			(e as GPUParticles3D).amount_ratio = clampf(0.1 + 0.7 * k + 0.5 * _flash, 0.05, 1.0) * _shown


# ---------------------------------------------------------------- earth's flow
## Earth's flow (BendZone._earth_flow; the owner, 2026-10-12: "as it swirls it catches rocks from the rocks chanel", and of a
## water catch "it swirls on the ground so it can be like a mud fissure"): while a shot a perfect Catch took swings round its
## catcher (BendBolt.begin_swing), the channel's rocks come up out of the deck round his feet on the swing's path (broken
## pieces lying near, RockDebris, pulled in to their places first), and the shot sweeps each into itself as it passes them: the
## wind's pebbles, the magma, the mud are made of them. Low (water's swirl along the deck) they lie on the deck and are swept up
## where they lie; high (wind, fire) they rise to meet it. Visual only, drawn where effects are (BendLooks.live()): made with
## the swing on every machine and freed once it is over, a rock never reached laid down as a piece for the next charge.
class RocksInto:
	extends Node3D

	const N := 6
	const SIZE := Vector2(0.16, 0.26)
	## The share of the swing over which its path meets the rocks (the first a little after it starts, the last before its
	## end), how long one takes to fly into the shot once met (share of the swing), and how long they take to come up (s).
	const SWEEP := Vector2(0.12, 0.8)
	const INTO := 0.12
	const RISE_S := 0.12
	## Pieces lying near pulled in (within PULL_M flat, at most PULL_MAX).
	const PULL_M := 4.0
	const PULL_MAX := 3

	var by: Node3D
	var shot: Node3D
	var s := 0.35
	var a0 := 0.0
	var r := 1.0
	var low := false
	var t := 0.0
	## The puff each rock makes as it goes into the shot (its matter's: "stone" pebbles, "fire" magma, "mud").
	var puff := "stone"
	## {mesh, at (its place on the path), deck, u (the swing's share when the path meets it), size, src (a piece's place, INF
	## a new rock), into (-1 not yet; 0..1 flying in), from, gone, axis, spin}
	var _rocks: Array = []

	## The rocks for `p_shot`'s swing round `p_by` (`p_s` s, from angle `p_a0`, radius `p_r`; `p_low` along the deck); null
	## where nothing is drawn.
	static func begin(p_by: Node3D, p_shot: Node3D, p_s: float, p_a0: float, p_r: float, p_low: bool, p_puff := "stone") -> RocksInto:
		if not BendLooks.live() or p_by == null or p_shot == null or not p_by.is_inside_tree():
			return null
		var ri := RocksInto.new()
		ri.name = "RocksInto"
		ri.by = p_by
		ri.shot = p_shot
		ri.s = maxf(p_s, 0.1)
		ri.a0 = p_a0
		ri.r = p_r
		ri.low = p_low
		ri.puff = p_puff
		ri.top_level = true
		p_by.get_tree().current_scene.add_child(ri)
		ri._lay()
		return ri

	func _lay() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(shot.get_instance_id()))
		var c := by.global_position
		var deck := FormEffects.ground_at(by, c).y
		var deb := get_tree().current_scene.get_node_or_null(RockDebris.NODE_NAME) as RockDebris
		var pieces: Array = deb.take(c, PULL_M, PULL_MAX) if deb != null else []
		for i in N:
			var u := lerpf(SWEEP.x, SWEEP.y, (float(i) + 0.5) / float(N))
			var a := a0 - TAU * u
			var rr := r * rng.randf_range(0.85, 1.1)
			var at := Vector3(c.x + sin(a) * rr, deck + (0.1 if low else rng.randf_range(0.4, 0.85)), c.z + cos(a) * rr)
			var m: Node3D
			var src := Vector3.INF
			var size := rng.randf_range(SIZE.x, SIZE.y)
			if i < pieces.size():
				m = pieces[i] as Node3D
				var xf := m.global_transform
				m.get_parent().remove_child(m)
				add_child(m)
				m.top_level = true
				m.global_transform = xf
				src = m.global_position
				size = m.scale.x
			else:
				var mi := MeshInstance3D.new()
				mi.mesh = ToonFx.chunk_mesh(i % 4)
				mi.material_override = ToonFx.mat("rock")
				mi.top_level = true
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				add_child(mi)
				mi.global_position = Vector3(at.x, deck - 0.15, at.z)
				mi.scale = Vector3.ONE * 0.01
				m = mi
				BendLooks.burst(Vector3(at.x, deck + 0.05, at.z), "stone", 2, Vector3.UP, 50.0, 1.0, 0.14, false)
			_rocks.append({"mesh": m, "at": at, "deck": deck, "u": u, "size": size, "src": src, "into": -1.0,
					"from": Vector3.ZERO, "gone": false, "spin": rng.randf_range(2.0, 5.0),
					"axis": Vector3(rng.randf_range(-1.0, 1.0), 1.0, rng.randf_range(-1.0, 1.0)).normalized()})

	func _process(dt: float) -> void:
		t += dt
		var su := t / s
		var alive := shot != null and is_instance_valid(shot) and not bool(shot.get(&"spent"))
		var left := 0
		for rk: Dictionary in _rocks:
			var m := rk.mesh as Node3D
			if bool(rk.gone) or not is_instance_valid(m):
				continue
			left += 1
			var at: Vector3 = rk.at
			var size := float(rk.size)
			if float(rk.into) < 0.0:
				# (coming up out of the deck to its place on the path, or a piece pulled in from where it lay)
				var rise := clampf(t / RISE_S, 0.0, 1.0)
				if rk.src != Vector3.INF:
					m.global_position = (rk.src as Vector3).lerp(at, rise) + Vector3.UP * 0.35 * sin(PI * rise)
				else:
					m.global_position = Vector3(at.x, lerpf(float(rk.deck) - 0.15, at.y, 1.0 - pow(1.0 - rise, 3.0)), at.z)
					m.scale = Vector3.ONE * size * rise
				if alive and su >= float(rk.u) - INTO:
					rk.into = 0.0
					rk.from = m.global_position
			else:
				# (met by the swirl: swept into the shot, gone into it with a puff of its matter)
				var into := minf(float(rk.into) + dt / (INTO * s), 1.0)
				rk.into = into
				var to: Vector3 = (shot as Node3D).global_position if alive else (rk.from as Vector3)
				m.global_position = (rk.from as Vector3).lerp(to, into * into)
				m.scale = Vector3.ONE * size * (1.0 - 0.6 * into)
				if into >= 1.0:
					rk.gone = true
					m.visible = false
					BendLooks.burst(to, puff, 4, Vector3.UP, 120.0, 1.5, 0.15, false)
			m.rotate(rk.axis as Vector3, dt * float(rk.spin))
		if left == 0 or t > s * 2.0 + 0.4 or not alive:
			_done()

	## Over: a rock the swirl never reached laid on the deck, a piece for the next charge (RockDebris); then freed.
	func _done() -> void:
		var deb := RockDebris.of(get_tree().current_scene)
		for rk: Dictionary in _rocks:
			var m := rk.mesh as Node3D
			if deb != null and is_instance_valid(m) and not bool(rk.gone) and m.visible and m.scale.x > 0.05:
				m.global_position.y = float(rk.deck) + 0.06
				deb.lay(m)
		set_process(false)
		queue_free()
