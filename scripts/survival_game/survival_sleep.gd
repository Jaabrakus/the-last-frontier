class_name SurvivalSleep
extends Node
## Sleep (Z; SurvivalBridge.sleeper). The player sits down on the ground and dozes (the bundled Actor_B sit-floor
## clips through a HorsePhaseBlender, as FieldDressing kneels), the screen dims, and the core's sleep job runs
## (rest.sleep: at night until half an hour after sunrise, by day a nap; its game hours pass in 5-12 real seconds, the
## sky with them, since the core drives the sky). It ends when the job is done, or early on the core's wake rules (a
## wolf within 60 m, a need getting worse, a fire dying, a storm), on Z again or on moving; the player gets up.
## Sleep is a boost, not a need: it earns WELL RESTED (SurvivalBridge.grant_rest), longer for longer and better sleep.
## Sleeping rough on the bare ground is poor sleep; a lean-to over the sleeper and a fire by them make it better
## (SurvivalBridge.rest_quality: the core's quality for the shelter, bedding and warmth, more by a lit fire), sampled
## through the sleep and averaged, so a fire that dies in the night counts for the hours it burnt. A bed is to come.
## Resting (user 2026-09-27: "resting or sleeping just refills the bar, we don't need to speed up time"): a tap of Z
## sits the player down to REST: the clock runs as it does, the health bar refills (full in REST_FILL_S; well rested
## faster) and a bleeding wound closes faster (PlayerWounds). Holding Z (HOLD_SLEEP_S) sleeps, from standing or from
## sitting; asleep the bar refills in SLEEP_FILL_S. A tap of Z or moving gets up. start() still sleeps at once.

const LIB := "actor_b"
## Real seconds to refill the health bar from empty: resting, and asleep; well rested, resting refills this much faster.
const REST_FILL_S := 40.0
const SLEEP_FILL_S := 10.0
const REST_FILL_RESTED := 1.5
## And by the stomach (user 2026-09-27: "well fed makes resting faster"): never so slow that hunger stops the healing.
const REST_FILL_FOOD := {"fed": 1.25, "peckish": 1.0, "hungry": 0.85, "very_hungry": 0.75, "starving": 0.6, "wasting": 0.6}
## Holding Z this long sleeps.
const HOLD_SLEEP_S := 0.6
## A wolf this near (the core's threat) and the player will not sit down.
const REST_THREAT_M := 40.0
const REST_DIM := 0.18
## Passed out (drink past its limit: the core's pass_out; Vices): the screen near black, the core's hours run this fast
## (game minutes a real second) until it comes to. No word of why (the player never learns "senseless").
const OUT_DIM := 0.94
const OUT_MIN_PER_S := 40.0
const CLIPS := ["actor_b-cap-casual-sit-floor-enter", "actor_b-cap-casual-sit-floor-loop", "actor_b-cap-casual-sit-floor-exit"]
## The getting-up clip is played this far (s); PlayerAnim takes the rest.
const OUT_S := 2.4
const DIM := 0.72

var bridge: SurvivalBridge
var sleeping := false
## Sitting down to rest (awake, the clock as it is).
var resting := false
## Passed out where they stood (the core's pass_out), until the core comes to.
var passed_out := false
## Why the last sleep ended ("rested", "threat", ...), and the game hours it lasted.
var why_woke := ""
var slept_h := 0.0
## Game hours of the well-rested boost the last sleep earned, the sleep's average quality, and where it was.
var earned_h := 0.0
var quality := 0.0
var where := ""

var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _phase := 0          ## 0 sitting down, 1 asleep, 2 getting up
var _t := 0.0
var _start_min := 0.0
var _layer: CanvasLayer
var _shade: ColorRect
var _label: Label
var _q_sum := 0.0
## Game minutes of the sleep in extreme cold (chilled to the bone, or a bitter night: SurvivalBridge.extreme_cold), and of
## those by a heat source (SurvivalBridge.by_heat).
var _cold_w := 0.0
var _heat_w := 0.0
## Game minutes of the whole sleep by a heat source (half or more: a warm rest, not capped by drink or hunger).
var _warm_w := 0.0
## Whether the last sleep was a warm rest.
var warm := false
## Whether the last sleep's boost was withheld for want of a heat source.
var too_cold := false
var _q_w := 0.0
var _q_min := 0.0
var _hold := -1.0         ## how long Z has been held since its press (-1: not held)
var _hold_first := false  ## the press that sat the player down (let go early: they keep resting)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.02, 0.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_shade)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	_label.position = Vector2(-160, -20)
	_label.size = Vector2(320, 40)
	_label.visible = false
	_layer.add_child(_label)
	hook(bridge.core)


## Listens to `core` (a new core after a load).
func hook(core: SurvivalCore) -> void:
	if core and not core.job_interrupted.is_connected(_on_interrupted):
		core.job_interrupted.connect(_on_interrupted)


## Why the player cannot lie down now ("" when they can).
func why_not() -> String:
	var p := bridge.player
	if sleeping:
		return "Already asleep"
	if p.is_dead:
		return "."
	if p.riding != null:
		return "Get off the horse to sleep"
	if (p.kneeling != null and p.kneeling != self) or not p.is_on_floor() or (p.traversal and p.traversal.showing):
		return "Not now"
	var pv := bridge.core.preview("rest.sleep")
	if not bool(pv.get("ok", false)):
		var rs: Array = pv.get("reasons", [])
		return "You cannot sleep: %s" % (String(rs[0]) if not rs.is_empty() else "not now")
	return ""


## Why the player cannot sit down to rest now ("" when they can).
func why_not_rest() -> String:
	var p := bridge.player
	if sleeping or resting:
		return "."
	if p.is_dead:
		return "."
	if p.riding != null:
		return "Get off the horse to rest"
	if p.kneeling != null or not p.is_on_floor() or (p.traversal and p.traversal.showing):
		return "Not now"
	if SurvivalUtil.num(bridge.core.state.context.get("threat_m"), 9999.0) < REST_THREAT_M:
		return "Not with a wolf this near"
	return ""


## Sits down to rest (the clock as it is, the bar refilling).
func rest() -> bool:
	var why := why_not_rest()
	if why != "":
		if why != ".":
			bridge._notice(why)
		return false
	if not _sit_down():
		return false
	resting = true
	why_woke = ""
	return true


func _sit_down() -> bool:
	var p := bridge.player
	_ap = p.begin_kneel(self, p.global_position - p.global_basis.z)
	if _ap == null:
		return false
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, p, LIB)
	_blender.show_clip(CLIPS[0], 0.0, 0.0)
	_blender.update(0.0)
	return true


## Sleeps now: sits down first, or from a rest goes to sleep where they sit.
func start() -> bool:
	var why := why_not()
	if why != "":
		if why != ".":
			bridge._notice(why)
		return false
	var p := bridge.player
	var sat := resting and p.kneeling == self
	if not sat and not _sit_down():
		return false
	var r := bridge.core.start_job("rest.sleep", {})
	if not bool(r.get("ok", false)):
		if not sat:
			p.end_kneel()
			_end()
		bridge._notice("You cannot sleep now")
		return false
	resting = false
	sleeping = true
	why_woke = ""
	_start_min = bridge.core.state.minutes
	_q_sum = 0.0
	_q_w = 0.0
	_q_min = _start_min
	_cold_w = 0.0
	_heat_w = 0.0
	_warm_w = 0.0
	warm = false
	too_cold = false
	where = _where()
	return true


## Wake now (the player's choice): the core's job is stopped, the player gets up.
func wake() -> void:
	if sleeping and SurvivalJobs.is_running(bridge.core):
		bridge.core.cancel_job("woke")
	_get_up("woke")


func _on_interrupted(job: Dictionary, reason: String) -> void:
	if not sleeping or String(job.get("action", "")) != "rest.sleep":
		return
	# going from fed to peckish wakes the core's sleeper (its wake rule: any need or condition gets worse); a night's
	# sleep burns most of a meal, so the player would wake early every night: they turn over and sleep on (the core's
	# rule, and the balance its harness is tested on, are left as they are)
	if _phase == 1 and (reason == "food worse: peckish" or reason == "hunger: peckish") and not bridge.core.is_dead():
		if bool(bridge.core.start_job("rest.sleep", {}).get("ok", false)):
			return
	_get_up(reason)


func _physics_process(dt: float) -> void:
	if bridge == null or bridge.player == null:
		return
	var p := bridge.player
	var paused := get_tree().paused
	if passed_out:
		_out_frame(dt)
		return
	if not sleeping and not resting:
		# a tap sits down to rest; held, the rest becomes sleep
		if Input.is_action_just_pressed(&"sleep") and not paused and rest():
			_hold = 0.0
			_hold_first = true
		return
	if p.is_dead or p.kneeling != self:
		stop_now()
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3
	if resting:
		if Input.is_action_just_pressed(&"sleep") and not paused:
			_hold = 0.0
			_hold_first = false
		if _hold >= 0.0:
			if Input.is_action_pressed(&"sleep"):
				_hold += dt
				if _hold >= HOLD_SLEEP_S:
					_hold = -1.0
					start()
			else:
				if not _hold_first and _phase < 2:
					_get_up_rest()
				_hold = -1.0
		if moving and _phase < 2:
			_get_up_rest()
	elif _phase < 2 and (Input.is_action_just_pressed(&"sleep") or moving):
		wake()
	_refill(dt)
	if resting:
		_rest_frame(dt)
		return
	_sample_quality()
	if _phase == 1 and not SurvivalJobs.is_running(bridge.core):
		_get_up("rested")
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIPS[0], minf(_t, _len(CLIPS[0])), 0.2)
			_shade.color.a = DIM * clampf(_t / _len(CLIPS[0]), 0.0, 1.0)
			if _t >= _len(CLIPS[0]):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIPS[1], fposmod(_t, _len(CLIPS[1])), 0.3)
			_shade.color.a = move_toward(_shade.color.a, DIM, dt)   # from a rest's light dim, slowly
		2:
			_blender.show_clip(CLIPS[2], minf(_t, _len(CLIPS[2])), 0.2)
			_shade.color.a = DIM * (1.0 - clampf(_t / 0.8, 0.0, 1.0))
			if _t >= minf(OUT_S, _len(CLIPS[2])):
				_end()
				return
	_label.visible = _phase < 2
	_label.text = "Asleep  ·  %s" % SurvivalClock.time_string(bridge.core)
	_blender.update(dt)


## The health bar refills while seated: resting (well rested faster) or asleep.
func _refill(dt: float) -> void:
	var p := bridge.player
	var cap := bridge.health_cap()
	if _phase == 2 or p.is_dead or p.health >= cap:
		return
	p.health = minf(p.health + p.max_health * fill_rate() * dt, cap)


## Of the health bar a second, seated: asleep, or resting (well rested and well fed faster).
func fill_rate() -> float:
	var st := String(bridge.core.need_stages().get("need.food", "fed")) if bridge.core else "fed"
	var k := float(REST_FILL_FOOD.get(st, 1.0))
	# chilled to the bone (LastingChill), the ague (LastingConditions): slower (the caps hold it under theirs)
	k *= bridge.heal_mult()
	if sleeping:
		return k / SLEEP_FILL_S
	return k * (REST_FILL_RESTED if bridge.is_healing_rest() else 1.0) / REST_FILL_S


## A rest's frame: sitting down, sitting, getting up (the sleep's clips, the screen only a little dimmed).
func _rest_frame(dt: float) -> void:
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIPS[0], minf(_t, _len(CLIPS[0])), 0.2)
			_shade.color.a = REST_DIM * clampf(_t / _len(CLIPS[0]), 0.0, 1.0)
			if _t >= _len(CLIPS[0]):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIPS[1], fposmod(_t, _len(CLIPS[1])), 0.3)
			_shade.color.a = REST_DIM
		2:
			_blender.show_clip(CLIPS[2], minf(_t, _len(CLIPS[2])), 0.2)
			_shade.color.a = REST_DIM * (1.0 - clampf(_t / 0.8, 0.0, 1.0))
			if _t >= minf(OUT_S, _len(CLIPS[2])):
				_end()
				return
	_label.visible = _phase < 2
	_label.text = "Resting  ·  hold Z to sleep"
	_blender.update(dt)


## Down where they stand (the core passed them out): from a rest or a sleep too.
func pass_out_now() -> void:
	if passed_out:
		return
	var p := bridge.player
	if sleeping and SurvivalJobs.is_running(bridge.core):
		bridge.core.cancel_job("passed out")
	sleeping = false
	resting = false
	_hold = -1.0
	var seated := p.kneeling == self and _blender != null
	if not seated:
		if p.riding != null or p.kneeling != null or not _sit_down():
			# on a horse or at work: the screen goes dark all the same
			_ap = null
	passed_out = true
	_phase = 1 if seated else 0
	_t = 0.0


func _out_frame(dt: float) -> void:
	var p := bridge.player
	if p.is_dead:
		stop_now()
		return
	_t += dt
	_shade.color.a = move_toward(_shade.color.a, OUT_DIM, dt * 1.5)
	_label.visible = false
	if bridge.core.is_passed_out():
		bridge.core.advance(OUT_MIN_PER_S * dt)
	if _blender and p.kneeling == self:
		match _phase:
			0:
				_blender.show_clip(CLIPS[0], minf(_t, _len(CLIPS[0])), 0.2)
				if _t >= _len(CLIPS[0]):
					_phase = 1
					_t = 0.0
			1:
				_blender.show_clip(CLIPS[1], fposmod(_t, _len(CLIPS[1])), 0.3)
				if not bridge.core.is_passed_out():
					_phase = 2
					_t = 0.0
					bridge._notice("You come to on the ground, your head pounding")
			2:
				_blender.show_clip(CLIPS[2], minf(_t, _len(CLIPS[2])), 0.2)
				_shade.color.a = OUT_DIM * (1.0 - clampf(_t / 1.2, 0.0, 1.0))
				if _t >= minf(OUT_S, _len(CLIPS[2])):
					_end()
					return
		_blender.update(dt)
	elif not bridge.core.is_passed_out():
		bridge._notice("You come to, your head pounding")
		_end()


func _get_up_rest() -> void:
	if not resting or _phase == 2:
		return
	_phase = 2
	_t = 0.0


func _get_up(reason: String) -> void:
	if not sleeping or _phase == 2:
		return
	why_woke = reason
	slept_h = (bridge.core.state.minutes - _start_min) / 60.0
	_phase = 2
	_t = 0.0
	# the boost: how long and how well they slept (shelter, bedding, warmth, a fire: SurvivalBridge.rest_quality)
	_sample_quality()
	quality = _q_sum / _q_w if _q_w > 0.0 else bridge.rest_quality()
	# in extreme cold only a sleep by a heat source rests (user 2026-09-27: "for the extreme cold they can not became well
	# rested unless they sleep next a heat source"): half of its cold hours at least by a fire, or indoors by a hearth
	too_cold = _cold_w > 0.0 and _heat_w < _cold_w * 0.5
	# a warm rest (half the sleep or more by a heat source): drink, a hangover or hunger do not cap it
	warm = _q_w > 0.0 and _warm_w >= _q_w * 0.5
	earned_h = 0.0 if too_cold else bridge.grant_rest(slept_h, quality, warm)
	if bridge.lasting:
		# a night in moccasins mends sore feet; the day's healing sleep eases the restlessness
		bridge.lasting.slept(slept_h, earned_h > 0.0 and bridge.last_rest_healed)
	var line := wake_line(reason, slept_h)
	if where != "" and (reason == "rested" or reason == "woke"):
		line += " " + where
	if earned_h > 0.0 and bridge.last_rest_healed:
		line += ": well rested for %d hours (you heal and learn faster)" % roundi(earned_h)
	elif earned_h > 0.0:
		# healing once a day (SurvivalBridge.is_healing_rest)
		line += ": well rested for %d hours (you learn faster; you have had today's healing sleep)" % roundi(earned_h)
	elif too_cold:
		line += ": too cold to rest (sleep by a fire)"
	bridge._notice(line)


## The sleep's quality for the game minutes since the last sample (the core steps in whole quanta).
func _sample_quality() -> void:
	var m := bridge.core.state.minutes
	if m > _q_min:
		var q := bridge.rest_quality()
		_q_sum += q * (m - _q_min)
		_q_w += m - _q_min
		var heat := bridge.by_heat()
		if heat:
			_warm_w += m - _q_min
		if bridge.extreme_cold():
			_cold_w += m - _q_min
			if heat:
				_heat_w += m - _q_min
		_q_min = m


## Where the sleeper lies, for the waking line: "in the pole bed in your cabin", "on the bough bed in the lean-to by the
## fire", "by the fire", or "".
func _where() -> String:
	var c := bridge.camp
	if c == null:
		return ""
	var parts: PackedStringArray = []
	var bed := c.bed_at(bridge.player.global_position)
	if bed:
		parts.append("on the bough bed" if bed.kind == "bough_bed" else "in the pole bed")
	var sh := c.shelter_word()
	if sh != "":
		parts.append(sh)
	if c.by_fire(CampLink.FIRE_SLEEP_M) and not bool(c.told.get("indoors", false)):
		parts.append("by the fire")
	return " ".join(parts)


## What woke the sleeper, in words (the core's wake rules: SurvivalCore.watch_triggers).
static func wake_line(reason: String, hours: float) -> String:
	if reason == "rested":
		return "You wake after %.0f hours" % hours
	if reason == "woke":
		return "You get up after %.0f hours" % hours
	if reason.begins_with("food worse"):
		return "Hunger wakes you: eat before you sleep"
	if reason.begins_with("warmth worse"):
		return "The cold wakes you: a fire or a shelter would help"
	if reason.begins_with("wetness worse"):
		return "You wake wet through"
	if reason.contains("threat"):
		return "You wake with a start: a wolf is near"
	if reason.begins_with("the fire is"):
		return "You wake: the fire has burnt down" if reason.ends_with("smouldering") else "You wake: the fire is out"
	if reason.begins_with("the weather"):
		return "A storm wakes you"
	return "You wake: %s" % reason


func _end() -> void:
	sleeping = false
	resting = false
	passed_out = false
	_hold = -1.0
	_shade.color.a = 0.0
	_label.visible = false
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	if bridge.player and bridge.player.kneeling == self:
		bridge.player.end_kneel()


## Ends at once (death): the core's sleep job stopped, the player's pose handed back.
func stop_now() -> void:
	if SurvivalJobs.is_running(bridge.core):
		bridge.core.cancel_job("death")
	_end()


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0
