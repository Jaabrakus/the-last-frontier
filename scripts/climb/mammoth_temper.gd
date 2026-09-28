class_name MammothTemper
extends Node
## The woolly mammoth's temper (user 2026-09-27: "if we are within distance they will attack us charge at us and swing
## there trunk to get us to back away, there goal is to survive and run away", "do a ground stomp"). It does not hunt:
## it drives people off, and when that fails, or once it has been brought down, it leaves.
##   calm     it paces (StandInGiant's own pacing); a player within ALERT_R and it turns on them
##   threat   it stops, faces them (the head up and shaking, the display: StandInGiant.display) for THREAT_S; if they
##            back off past CALM_R it calms; within CHARGE_R it attacks, else it holds its ground facing them
##   charge   head down, it runs at them (CHARGE_MPS; it turns only CHARGE_TURN a second, so a step aside dodges it) and
##            rams whoever is before its tusks (RAM); then it slows and turns on them again
##   swing    close before it (CLOSE_R, its front half): the trunk swept to their side (TrunkSwing_L / _R), a blow that
##            knocks them back (SWING)
##   stomp    at its forefeet or under it (STOMP_R): it rears and slams them down (Stomp): the ground shakes for the
##            players about (CameraShake) and those at its forefeet are knocked away (STOMP)
##   flee     after ATTACKS attacks with them still close, or when it rises from a buckled leg (its weak points): it turns
##            from the nearest player and walks off fast (FLEE_MPS) for FLEE_S or until FLEE_R clear; never past LEASH_R
##            from where it was built
##   home     calm again and away from where it was built: it walks back (HOME_MPS), faces as it stood, and paces
## A climber on it (StandInGiant.carries) is left to its shakes; a buckled leg stops it (down: nothing but getting up).
## Its blows go through Hit.deliver (the player's apply_hit: blunt force) and knock the player down, thrown away from it
## and up as a ragdoll (FrontierPlayer.knock_down, PlayerRagdoll), to get up where they come to rest. When they cannot be
## knocked down (mid-vault, say) they are thrown on their feet: their velocity set (the grip's throw does the same), held
## for THROW_HOLD_S till they are off the ground (on it the player's own step stops a standing body at once).
## Off in tool and test runs (-s) unless they pass mammoth_temper=on, or set `enabled`.

const ALERT_R := 22.0
const CALM_R := 30.0
const CHARGE_R := 15.0
const CLOSE_R := 7.0
const STOMP_R := 3.4
const THREAT_S := 2.4
const TURN := 1.1                 ## rad/s it turns to face someone
const CHARGE_MPS := 5.2
const CHARGE_TURN := 0.6          ## rad/s while charging
const CHARGE_S := 4.0
const RAM_R := 2.4                ## m from its front (the tusks' root) a ram strikes
const RECOVER_S := 1.2
const ATTACKS := 3
const FLEE_MPS := 3.4
const FLEE_S := 8.0
const FLEE_R := 32.0
const LEASH_R := 45.0
const HOME_MPS := 1.2
## The blows: damage (blunt), and the throw: m/s away from it and up.
const RAM := {"damage": 42.0, "away": 8.5, "up": 3.5}
const SWING := {"damage": 18.0, "away": 7.0, "up": 3.0}
const STOMP := {"damage": 26.0, "away": 6.0, "up": 4.5}
## The trunk's reach from the head, and the swing's blow (seconds into its clip, 24 fps frames 14 to 20).
const SWING_REACH := 5.4
const SWING_HIT := Vector2(14.0 / 24.0, 20.0 / 24.0)
## The stomp's slam (its clip's frame 23), the reach of its blow from between the forefeet, and its quake.
const STOMP_HIT_S := 23.0 / 24.0
const STOMP_HIT_R := 5.2
const STOMP_QUAKE := 0.95
const STOMP_QUAKE_R := 30.0
## Its front (the tusks' root) ahead of its middle, and its forefeet (m, its own frame: -Z ahead).
const FRONT := Vector3(0.0, 0.0, -3.1)
const FOREFEET := Vector3(0.0, 0.0, -1.5)
const THROW_HOLD_S := 0.12

var giant: StandInGiant
var enabled := true
var mood := "calm"
var target: FrontierPlayer
var attacks := 0
var _t := 0.0
var _struck := {}                 ## players this blow has already struck
var _charge_v := 0.0
var _flee_dir := Vector3.ZERO
var _throws := {}                 ## player -> [velocity, seconds left] of a throw being held


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args:
		enabled = "mammoth_temper=on" in OS.get_cmdline_user_args()
	if giant:
		giant.got_up.connect(_on_got_up)


## The players it minds: alive, on foot, not on it, and not knocked down (it drives people off; one down is no threat).
func _players() -> Array[FrontierPlayer]:
	var out: Array[FrontierPlayer] = []
	for n in get_tree().get_nodes_in_group(&"player"):
		var p := n as FrontierPlayer
		if p == null or p.is_dead or giant.carries(p):
			continue
		var rd := p.get_node_or_null(^"Ragdoll") as PlayerRagdoll
		if rd and rd.is_down():
			continue
		out.append(p)
	return out


## The nearest player it cares about (on foot, alive, not on it), and how far (flat).
func _nearest() -> Array:
	var best: FrontierPlayer = null
	var bd := INF
	for p in _players():
		var d := _flat(p.global_position, giant.where())
		if d < bd:
			bd = d
			best = p
	return [best, bd]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A place in its own frame (Body's: its middle the origin, -Z ahead; the model is turned half round, so its left is -X).
func _local(p: Vector3) -> Vector3:
	return giant.body.global_transform.affine_inverse() * p


func _go(m: String) -> void:
	mood = m
	_t = 0.0
	_struck.clear()


func _physics_process(dt: float) -> void:
	if giant == null or giant.anim == null:
		return
	if not enabled:
		if giant.driven and mood != "calm":
			giant.set_driven(false)
			_go("calm")
		return
	_t += dt
	_hold_throws(dt)
	if giant.dead_side != "":
		if mood != "dead":
			_go("dead")
		return
	# down on a buckled leg, or someone on it: it has other things to do
	if giant.down_phase != "":
		if mood != "down":
			giant.drive_speed = 0.0
			giant.display = false
			_go("down")
		return
	if giant.carrying():
		if giant.driven:
			giant.set_driven(false)
		_go("calm")
		return
	var near := _nearest()
	var np := near[0] as FrontierPlayer
	var nd := float(near[1])
	giant.head_aim = move_toward(giant.head_aim, 0.3 if mood == "threat" else (-0.22 if mood == "charge" else 0.0), dt * 0.8)
	match mood:
		"calm":
			if np and nd < ALERT_R:
				target = np
				giant.set_driven(true)
				_go("threat")
			elif _flat(giant.where(), giant.spawn.origin) > 2.0:
				giant.set_driven(true)
				_go("home")
		"home":
			_home(dt, np, nd)
		"threat":
			_threat(dt, np, nd)
		"charge":
			_charge(dt)
		"recover":
			giant.drive_speed = move_toward(giant.drive_speed, 0.0, CHARGE_MPS / RECOVER_S * dt)
			if target:
				giant.turn_toward(target.global_position - giant.where(), TURN * 0.6, dt)
			if _t >= RECOVER_S:
				_after_attack(np, nd)
		"swing", "stomp":
			_blow()
			if giant.acting == "" and _t > 0.3:
				_after_attack(np, nd)
		"flee":
			_flee(dt, np, nd)
		"down":
			pass


func _threat(dt: float, np: FrontierPlayer, nd: float) -> void:
	giant.drive_speed = move_toward(giant.drive_speed, 0.0, 3.0 * dt)
	if np == null or nd > CALM_R:
		giant.display = false
		giant.drive_speed = 0.0
		giant.set_driven(false)
		_go("calm")
		return
	target = np
	var left := giant.turn_toward(np.global_position - giant.where(), TURN, dt)
	giant.display = true
	if _t < THREAT_S or left > 0.35:
		return
	giant.display = false
	if nd < CHARGE_R:
		_attack(np, nd)
	else:
		_t = THREAT_S * 0.5          # holds its ground, facing them, and looks again soon


## Which blow for `p` at `nd`: under it or at its forefeet the stomp; close before it the trunk; farther the charge.
func _attack(p: FrontierPlayer, nd: float) -> void:
	var l := _local(p.global_position)
	var at_feet := _flat(p.global_position, giant.body.global_transform * FOREFEET) < STOMP_R \
			or (absf(l.x) < 2.0 and l.z > -3.5 and l.z < 3.0)
	if at_feet and giant.act("Stomp"):
		_go("stomp")
	elif nd < CLOSE_R and l.z < 1.0:
		# (Body's frame: the model turned half round, its left at -X)
		if giant.act("TrunkSwing_L" if l.x < 0.0 else "TrunkSwing_R"):
			_go("swing")
	else:
		_charge_v = 0.0
		_go("charge")


func _charge(dt: float) -> void:
	_charge_v = move_toward(_charge_v, CHARGE_MPS, CHARGE_MPS / 0.8 * dt)
	giant.drive_speed = _charge_v
	if target and is_instance_valid(target):
		giant.turn_toward(target.global_position - giant.where(), CHARGE_TURN, dt)
	var front := giant.body.global_transform * FRONT
	for p in _players():
		if not _struck.has(p) and _flat(p.global_position, front) < RAM_R and absf(p.global_position.y - front.y) < 3.0:
			_struck[p] = true
			_strike(p, RAM)
	var passed := target != null and is_instance_valid(target) \
			and (target.global_position - giant.where()).dot(giant.heading()) < -2.0
	if _t >= CHARGE_S or passed or not _struck.is_empty():
		attacks += 1
		_go("recover")


## The swing's and the stomp's blows, at their moments in the clip.
func _blow() -> void:
	var at := giant.act_time()
	if at < 0.0:
		return
	if mood == "swing" and at >= SWING_HIT.x and at <= SWING_HIT.y:
		var head := giant.head.global_position
		var side := -1.0 if giant.acting == "TrunkSwing_L" else 1.0      # (Body's frame: its left is -X)
		for p in _players():
			var l := _local(p.global_position)
			if _struck.has(p) or p.global_position.distance_to(head) > SWING_REACH or l.z > 1.5:
				continue
			if l.x * side < -1.0:
				continue                                                 # on the side the trunk swept from
			_struck[p] = true
			# thrown the way the trunk sweeps, and away
			var sweep := giant.body.global_basis * Vector3(side, 0.0, 0.0)
			_strike(p, SWING, sweep)
	elif mood == "stomp" and at >= STOMP_HIT_S and not _struck.has(&"slam"):
		_struck[&"slam"] = true
		var feet := giant.body.global_transform * FOREFEET
		CameraShake.quake(get_tree(), feet, STOMP_QUAKE, STOMP_QUAKE_R, 1.2)
		for p in _players():
			if _flat(p.global_position, feet) < STOMP_HIT_R and p.global_position.y - feet.y < 2.5:
				_strike(p, STOMP)


## A blow on `p`: its damage (blunt) and a throw away from it and up (`sweep`: mostly that way instead).
func _strike(p: FrontierPlayer, blow: Dictionary, sweep := Vector3.ZERO) -> void:
	var away := p.global_position - giant.where()
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else -giant.heading()
	if sweep != Vector3.ZERO:
		sweep.y = 0.0
		away = (sweep.normalized() * 0.7 + away * 0.3).normalized()
	Hit.deliver(p, float(blow.damage), p.global_position + Vector3.UP * 1.0, away, giant)
	if not p.is_dead:
		var v := away * float(blow.away) + Vector3.UP * float(blow.up)
		# knocked down (a ragdoll, then the get-up); when they cannot be now, thrown on their feet
		if not p.knock_down(v):
			p.velocity = v
			_throws[p] = [v, THROW_HOLD_S]


## A throw held till the player is off the ground (their step would stop them where they stand).
func _hold_throws(dt: float) -> void:
	for p in _throws.keys():
		var h: Array = _throws[p]
		h[1] = float(h[1]) - dt
		if not is_instance_valid(p) or p.is_dead or float(h[1]) <= 0.0:
			_throws.erase(p)
			continue
		var v: Vector3 = h[0]
		p.velocity.x = v.x
		p.velocity.z = v.z
		if p.is_on_floor():
			p.velocity.y = maxf(p.velocity.y, v.y)


## After a blow: they backed off, or it has struck ATTACKS times: it leaves; else it faces them again.
func _after_attack(np: FrontierPlayer, nd: float) -> void:
	if mood == "swing" or mood == "stomp":
		attacks += 1
	if np == null or nd > CHARGE_R or attacks >= ATTACKS:
		_start_flee(np)
	else:
		_go("threat")
		_t = THREAT_S * 0.6


func _on_got_up(_leg: String) -> void:
	if enabled:
		giant.set_driven(true)
		_start_flee(_nearest()[0])


func _start_flee(from: FrontierPlayer) -> void:
	attacks = 0
	giant.display = false
	var away := -giant.heading()
	if from:
		away = giant.where() - from.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.01 else -giant.heading()
	_flee_dir = away.rotated(Vector3.UP, randf_range(-0.35, 0.35))
	_go("flee")


func _flee(dt: float, np: FrontierPlayer, nd: float) -> void:
	# never past its leash: the way out bends round, back toward where it was built
	var from_spawn := giant.where() - giant.spawn.origin
	from_spawn.y = 0.0
	var dir := _flee_dir
	if from_spawn.length() > LEASH_R * 0.8:
		var inward := -from_spawn.normalized()
		dir = dir.lerp(inward, clampf((from_spawn.length() - LEASH_R * 0.8) / (LEASH_R * 0.2), 0.0, 1.0)).normalized()
	var left := giant.turn_toward(dir, TURN, dt)
	giant.drive_speed = move_toward(giant.drive_speed, FLEE_MPS if left < 1.2 else 1.0, 2.5 * dt)
	if _t >= FLEE_S or (np == null or nd > FLEE_R):
		giant.drive_speed = 0.0
		_go("home")


func _home(dt: float, np: FrontierPlayer, nd: float) -> void:
	if np and nd < ALERT_R * 0.8 and _t > 3.0:
		target = np
		_go("threat")
		return
	var to := giant.spawn.origin - giant.where()
	to.y = 0.0
	if to.length() > 1.0:
		var left := giant.turn_toward(to, TURN * 0.7, dt)
		giant.drive_speed = move_toward(giant.drive_speed, HOME_MPS if left < 0.6 else 0.3, 1.5 * dt)
		return
	giant.drive_speed = move_toward(giant.drive_speed, 0.0, 2.0 * dt)
	var sf := -giant.spawn.basis.z
	if giant.turn_toward(Vector3(sf.x, 0.0, sf.z), TURN * 0.7, dt) < 0.03 and giant.drive_speed == 0.0:
		giant.set_driven(false)
		_go("calm")
