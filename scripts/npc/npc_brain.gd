class_name NpcBrain
extends RefCounted
## A fighter's mind (NpcFighter): what it notices and what it does about it, thought over every THINK_S (not each frame).
##
##   IDLE / PATROL  at its post, or walking its patrol (a wait at each point), or its squad's order (attack: to a place, or
##                  after a foe it is told of; hold)
##   SUSPICIOUS     something half seen or heard (a shot, footfalls, an ally's alarm far off): it turns that way, walks over
##                  with its musket up and looks about, then goes back to its post
##   COMBAT         a foe seen: the musket to the shoulder and fired when it has the foe in sight within FIRE_M; empty, it
##                  runs to cover (NpcCover: behind the nearest tree, rock or wall away from the foe) and reloads there
##                  crouched (a cover it cannot reach, or not within COVER_GO_S, is given up: it loads where it stands,
##                  crouched), or clubs a foe that is on it (CHARGE_M); with no musket it closes in with its axe (straight at
##                  him once he is in sight within NpcFighter.STRAIGHT_M); a foe lost from sight is sought where it was last
##                  seen, and after CALM_S out of sight he is given up and it calms down. In a fight it sees its foe by the
##                  same rules as before it (the light, his stance, his cover), only further (SIGHT_MAX) and all round for
##                  TRACK_S after it last saw him: a man who gets away, or hides in the dark, is lost
##   FLEE           badly hurt, or too many of its squad down (its courage says how many): it runs FLEE_M away from the foe
##   SURRENDER      caught while it runs (a foe within CORNER_M, or its way blocked with one near), or badly hurt with its
##                  musket empty and the foe on it: on its knees, its weapon down; let go (E), it walks off, out of the fight
##   DEAD
##
## PERCEPTION: for the nearest few foes (NpcSenses.foes_of), sight within a cone (FOV_CALM, wider once alert) to SIGHT_M by
## day, shortened by the dark (NpcSenses.daylight; a lit torch shows a man), by crouching and by keeping still, and to half
## again when only the head shows over cover; seen means a clear line from its eyes to the chest or the head (two rays at
## most per foe each LOS_S, kept). Footfalls are heard near (running further, crouching less). Awareness of each foe rises
## with what it sees and hears and falls off without: SUSPECT makes it suspicious, SPOT and it fights. A foe spotted is shouted
## to its side within SHARE_M (told: they fight too); a noise (NpcSenses.noise) makes it suspicious; a foe's hit, it fights
## back (a hit from its own side, or from the player when they are not foes, it takes for a mistake). Foes are the factions'
## (NpcFactions.hostile: either side attacking the other on sight).

enum State { IDLE, PATROL, SUSPICIOUS, COMBAT, FLEE, SURRENDER, DEAD }
const NAMES := ["IDLE", "PATROL", "SUSPICIOUS", "COMBAT", "FLEE", "SURRENDER", "DEAD"]

const SIGHT_M := 70.0
const SIGHT_MAX := 110.0
const FOV_CALM := 130.0
const FOV_ALERT := 220.0
## Within this it notices a foe whichever way it faces.
const CLOSE_M := 3.0
const SUSPECT := 0.35
const SPOT := 1.0
const DECAY := 0.12
const LOS_S := 0.5
const SHARE_M := 40.0
const CALM_S := 30.0
const SEARCH_S := 10.0
const FIRE_M := 85.0
## Further than this it runs to get a shot; nearer it walks.
const APPROACH_M := 40.0
const CHARGE_M := 7.0
const COVER_S := 4.0
## Heading for cover longer than this (or its way blocked), it gives the cover up and loads where it stands.
const COVER_GO_S := 5.0
## The foe it fights, seen within this many seconds, it keeps its eyes on whichever way it faces.
const TRACK_S := 2.0
## Closing in on a foe in sight, it runs at where he will be this far ahead at most (s).
const LEAD_S := 0.8
const FLEE_M := 60.0
const FLEE_S := 30.0
const CORNER_M := 4.5
## A squad told to attack a foe goes straight for it within this (it knows where the foe is).
const HUNT_M := 15.0

var me: NpcFighter
var state := State.IDLE
## The foe it is after; where and when it was last seen (the brain's clock); a place it suspects; its cover.
var target: Node3D = null
var last_seen := Vector3.INF
var seen_t := -100.0
var suspect_at := Vector3.INF
var cover := Vector3.INF
## Awareness of each foe (instance id -> 0..1.3).
var aware := {}
## The target in sight at the last look.
var seen_now := false
## Times it spotted a foe itself (not told of it); a test's count.
var spotted := 0
var _clock := 0.0
var _state_t := 0.0
var _los := {}
var _cover_t := -100.0
var _patrol_i := 0
var _wait := 0.0
var _flee_to := Vector3.INF
var _routed := false
var _released := false
var _blocked_t := -100.0
var _side_to := Vector3.INF
var _search_t := 0.0
var _look_t := 0.0
## When it set off for the cover it has; the cover given up (it loads where it stands until loaded).
var _cover_since := -100.0
var _reload_here := false


func _init(f: NpcFighter) -> void:
	me = f


func state_name() -> String:
	return NAMES[state]


## Run off and out of the fight (it stays where it ran to), or let go.
func routed() -> bool:
	return _routed or _released


func think(dt: float) -> void:
	_clock += dt
	_state_t += dt
	if me.is_dead():
		_to(State.DEAD)
		return
	if state == State.SURRENDER:
		me.halt()
		return
	_perceive(dt)
	match state:
		State.IDLE, State.PATROL:
			_calm(dt)
		State.SUSPICIOUS:
			_suspicious(dt)
		State.COMBAT:
			_combat(dt)
		State.FLEE:
			_flee(dt)


func _to(s: State) -> void:
	if s == state:
		return
	state = s
	_state_t = 0.0
	me.state_changed.emit(me, NAMES[s])


# ---------------------------------------------------------------- what it sees and hears
func _perceive(dt: float) -> void:
	var eye := me.eye()
	var fwd := me.forward()
	var day := NpcSenses.daylight(me.get_tree())
	var near := {}
	var best: Node3D = null
	var best_a := 0.0
	for c: Array in NpcSenses.foes_of(me, SIGHT_MAX):
		var n: Node3D = c[1]
		var gain := _sense(n, float(c[0]), eye, fwd, day)
		var id := n.get_instance_id()
		var a := float(aware.get(id, 0.0))
		a = minf(a + gain * dt, 1.3) if gain > 0.0 else maxf(a - DECAY * dt, 0.0)
		aware[id] = a
		near[id] = true
		if a > best_a:
			best_a = a
			best = n
	for id: int in aware.keys():
		if not near.has(id):
			aware[id] = maxf(float(aware[id]) - DECAY * dt, 0.0)
			if float(aware[id]) <= 0.0:
				aware.erase(id)
	if _routed or _released or not state in [State.IDLE, State.PATROL, State.SUSPICIOUS]:
		return
	if best != null and best_a >= SPOT:
		spotted += 1
		_engage(best)
	elif best != null and best_a >= SUSPECT and state != State.SUSPICIOUS:
		_suspect(best.global_position)


## What `n` (a foe `d` m off) raises its awareness by, per second: seen (_seen_in: the cone, the range for the light, the
## stance and the pace, the cover), heard (its footfalls).
func _sense(n: Node3D, d: float, eye: Vector3, fwd: Vector3, day: float) -> float:
	var low := NpcSenses.crouched(n)
	var sp := NpcSenses.speed_of(n)
	var gain := 0.0
	var r_eff := _seen_in(n, d, eye, fwd, day)
	if r_eff > 0.0:
		gain += (1.0 - d / r_eff) * 2.2 + 0.25 + minf(sp, 5.0) * 0.08
		if n == target:
			last_seen = n.global_position
			seen_t = _clock
	var noise := 0.0
	if sp > 5.0:
		noise = 24.0
	elif sp > 2.2:
		noise = 12.0
	elif sp > 0.3:
		noise = 4.0 if low else 8.0
	if d < noise:
		gain += (1.0 - d / noise) * 1.2
	return gain


## How far it sees `n` now (m): SIGHT_M by day (SIGHT_MAX for the foe it is fighting: its eyes are on him, and his crouch
## hides him less), shortened by the dark (NpcSenses.daylight), by his crouch and by his keeping still; a lit torch shows him.
func _sight_m(n: Node3D, day: float) -> float:
	var low := NpcSenses.crouched(n)
	var sp := NpcSenses.speed_of(n)
	var fighting := state == State.COMBAT and n == target
	var base := SIGHT_MAX if fighting else SIGHT_M
	var r := base * day * ((0.6 if fighting else 0.5) if low else 1.0) * (0.75 if sp < 0.3 else (1.2 if sp > 4.0 else 1.0))
	if NpcSenses.torch_lit(n):
		r = maxf(r, base * 0.8 * (0.5 if low else 1.0))
	return r


## Whether it sees `n` (`d` m off) now: in its cone (FOV_CALM, FOV_ALERT once alert; or close by, CLOSE_M; or the foe it is
## fighting, seen within TRACK_S), within its sight (_sight_m), and a clear line to him (_look: the chest; only the head over
## cover, and then half the range). The range he is seen within (0: not seen).
func _seen_in(n: Node3D, d: float, eye: Vector3, fwd: Vector3, day: float) -> float:
	var rng_m := _sight_m(n, day)
	if d >= rng_m:
		return 0.0
	var to := n.global_position - me.global_position
	var ang := absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))))
	var fov := FOV_ALERT if state in [State.SUSPICIOUS, State.COMBAT] else FOV_CALM
	var tracked := n == target and _clock - seen_t < TRACK_S
	if not (ang < fov * 0.5 or d < CLOSE_M or tracked):
		return 0.0
	var vis := _look(n, eye)
	if vis <= 0.0:
		return 0.0
	var r_eff := rng_m * (1.0 if vis >= 1.0 else 0.5)
	return r_eff if d < r_eff else 0.0


## How much of `n` it sees from `eye`: 1 the chest, 0.5 only the head (over cover), 0 nothing (kept LOS_S).
func _look(n: Node3D, eye: Vector3) -> float:
	var id := n.get_instance_id()
	var c: Array = _los.get(id, [])
	if not c.is_empty() and _clock - float(c[0]) < LOS_S:
		return float(c[1])
	var space := me.get_world_3d().direct_space_state
	var ex := me.ray_exclude()
	var v := 0.0
	if NpcSenses.clear_line(space, eye, NpcSenses.chest_of(n), n, ex):
		v = 1.0
	elif NpcSenses.clear_line(space, eye, NpcSenses.head_of(n), n, ex):
		v = 0.5
	_los[id] = [_clock, v]
	return v


## A loud noise (a shot) at `pos`: a foe's makes it suspicious and half aware of him; in a fight, the foe it lost is there.
func heard(pos: Vector3, _radius: float, source: Node) -> void:
	if state in [State.DEAD, State.SURRENDER, State.FLEE] or _routed or _released:
		return
	var foe := _is_foe(source)
	if state == State.COMBAT:
		if source == target and _clock - seen_t > 1.0:
			last_seen = pos
		return
	if foe:
		var id := source.get_instance_id()
		aware[id] = maxf(float(aware.get(id, 0.0)), SUSPECT + 0.25)
	_suspect(pos)


## Hurt by `source`: a foe it fights back (and knows where the blow came from); one of its own side's, or the player when
## they are not foes, it takes for a mistake: it calls out, and does not turn on him (a crime and its witnesses are the
## reputation work's, later).
func hurt(source: Node, _dir: Vector3) -> void:
	if state in [State.DEAD, State.SURRENDER] or _released:
		return
	if not _is_foe(source):
		if source != null and state != State.COMBAT:
			me.bark("alert")
		return
	if source is Node3D and NpcSenses.can_fight(source):
		last_seen = (source as Node3D).global_position
		seen_t = _clock
		if state in [State.IDLE, State.PATROL, State.SUSPICIOUS] and not _routed:
			_engage(source as Node3D)
		elif state == State.COMBAT and not seen_now:
			target = source as Node3D


## An ally's alarm: a foe (or null: only the place) at `at`.
func told(foe: Node3D, at: Vector3) -> void:
	if not state in [State.IDLE, State.PATROL, State.SUSPICIOUS] or _routed or _released:
		return
	if foe != null and _is_foe(foe):
		target = foe
		last_seen = at
		seen_t = _clock - 1.0
		aware[foe.get_instance_id()] = maxf(float(aware.get(foe.get_instance_id(), 0.0)), SPOT)
		_to(State.COMBAT)
		me.bark("alert")
	else:
		_suspect(at)


func on_died() -> void:
	_to(State.DEAD)


## The shot it was about to fire was blocked ("friend": one of its own in the way; "cover"): it steps aside a few metres.
func shot_blocked(_why: String) -> void:
	_blocked_t = _clock
	var side := me.forward().cross(Vector3.UP) * (1.0 if me.rng.randf() < 0.5 else -1.0)
	_side_to = me.global_position + side * 3.0


## Let go: it walks off away from `from`, out of the fight.
func release(from: Vector3) -> void:
	_released = true
	target = null
	_flee_to = _away(from, FLEE_M)
	_to(State.FLEE)


# ---------------------------------------------------------------- what it does
func _engage(foe: Node3D) -> void:
	target = foe
	last_seen = foe.global_position
	seen_t = _clock
	aware[foe.get_instance_id()] = maxf(float(aware.get(foe.get_instance_id(), 0.0)), SPOT)
	if state != State.COMBAT:
		_to(State.COMBAT)
		me.bark("combat")
		for a in NpcSenses.allies_of(me, SHARE_M):
			a.brain.told(foe, last_seen)


func _suspect(at: Vector3) -> void:
	suspect_at = at
	_search_t = 0.0
	if state != State.SUSPICIOUS:
		_to(State.SUSPICIOUS)
		me.bark("alert")
		me.halt()


func _calm(dt: float) -> void:
	match me.order_kind:
		"attack":
			var o: Variant = me.order
			if typeof(o) == TYPE_OBJECT:
				var n := o as Node3D if is_instance_valid(o) else null
				if not NpcSenses.can_fight(n):
					me.order_kind = "hold"
					me.order = me.global_position
					me.home = me.global_position
					return
				# after a foe it was sent against: it knows where he is; near, it goes for him
				if _is_foe(n) and me.global_position.distance_to(n.global_position) < HUNT_M:
					_engage(n)
					return
				_to(State.PATROL)
				var dn := _flat(me.global_position, n.global_position)
				me.go(n.global_position, NpcFighter.RUN_SPEED if dn > 25.0 else NpcFighter.WALK_SPEED, 2.0)
				return
			if o is Vector3:
				var p := o as Vector3
				_to(State.PATROL)
				if _flat(me.global_position, p) > 2.5:
					me.go(p, NpcFighter.RUN_SPEED if _flat(me.global_position, p) > 25.0 else NpcFighter.WALK_SPEED, 2.0)
				else:
					me.order_hold(p)
				return
			me.order_kind = ""
		"patrol":
			if me.patrol.size() > 0:
				_to(State.PATROL)
				var p := me.patrol[_patrol_i % me.patrol.size()]
				if _flat(me.global_position, p) > 1.3:
					me.go(p, NpcFighter.WALK_SPEED, 1.0)
					_wait = me.rng.randf_range(2.0, 6.0)
				else:
					me.halt()
					_wait -= dt
					if _wait <= 0.0:
						_patrol_i += 1
				return
	_to(State.IDLE)
	if me.home != Vector3.INF and _flat(me.global_position, me.home) > 2.5:
		me.go(me.home, NpcFighter.WALK_SPEED, 1.0)
	else:
		me.halt()


func _calm_down() -> void:
	target = null
	cover = Vector3.INF
	_reload_here = false
	seen_now = false
	me.crouch(false)
	_to(State.PATROL if me.order_kind != "" else State.IDLE)


func _suspicious(dt: float) -> void:
	if suspect_at == Vector3.INF:
		_calm_down()
		return
	if _state_t < 1.5:
		me.halt()
		me.face_point(suspect_at)
		return
	if _flat(me.global_position, suspect_at) > 3.0 and _search_t <= 0.0 and _state_t < 25.0:
		me.go(suspect_at, NpcFighter.WALK_SPEED, 2.5)
		return
	# there (or as near as it gets): a look about
	me.halt()
	_search_t += dt
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = 2.0
		var a := me.rng.randf() * TAU
		me.face_point(me.global_position + Vector3(cos(a), 0.0, sin(a)))
	if _search_t > SEARCH_S:
		suspect_at = Vector3.INF
		_calm_down()


func _combat(_dt: float) -> void:
	# the foe it fights: in sight by the rules it notices by (_seen_in), or not; out of sight CALM_S, he is given up
	seen_now = false
	if NpcSenses.can_fight(target):
		var d0 := me.global_position.distance_to(target.global_position)
		seen_now = _seen_in(target, d0, me.eye(), me.forward(), NpcSenses.daylight(me.get_tree())) > 0.0
		if seen_now:
			last_seen = target.global_position
			seen_t = _clock
		elif _clock - seen_t > CALM_S:
			aware.erase(target.get_instance_id())
			target = null
	if not NpcSenses.can_fight(target):
		target = _next_foe()
		if target != null:
			# (one it is aware of now: where he is, as good as seen a moment ago)
			last_seen = target.global_position
			seen_t = maxf(seen_t, _clock - 1.0)
		else:
			if last_seen == Vector3.INF or _clock - seen_t > CALM_S:
				_calm_down()
				return
			# gone from sight: where it was last seen
			if _flat(me.global_position, last_seen) > 3.0 and not me.busy():
				me.crouch(false)
				me.go(last_seen, NpcFighter.WALK_SPEED, 2.5)
			elif not me.busy():
				me.halt()
				if me.gun != null and not me.loaded:
					me.begin_reload()
			return
	var tp := target.global_position
	var d := me.global_position.distance_to(tp)
	if _should_flee(d):
		if d < CORNER_M and not (me.gun != null and me.loaded):
			me.surrender()
			_to(State.SURRENDER)
		else:
			_start_flee()
		return
	if me.busy():
		# a reload put by for a foe that is on it: the butt for him instead
		if me.action == "reload" and seen_now and d < CHARGE_M * 0.6:
			me.cancel_reload()
		else:
			return
	if _clock - _blocked_t < 1.5 and _side_to != Vector3.INF:
		me.crouch(false)
		me.go(_side_to, NpcFighter.WALK_SPEED, 0.5)
		return
	var musket := me.gun != null and me.gun.visible
	if musket and me.loaded:
		_reload_here = false
		if seen_now and d <= FIRE_M:
			me.crouch(cover != Vector3.INF and _flat(me.global_position, cover) < 1.2)
			me.begin_aim(target)
			return
		# no shot from here: nearer, or round to where it can see him
		var goal := last_seen if last_seen != Vector3.INF else tp
		me.crouch(false)
		if _flat(me.global_position, goal) > 6.0 or not seen_now:
			me.go(goal, NpcFighter.RUN_SPEED if d > APPROACH_M else NpcFighter.WALK_SPEED, 4.0)
		else:
			me.halt()
		return
	if musket:
		# empty: the butt for a foe on it, else behind cover to load (a cover it cannot get to: where it stands, crouched)
		if d < CHARGE_M and seen_now:
			_close_in(tp, d)
			return
		if not _reload_here and _clock - _cover_t > COVER_S:
			_cover_t = _clock
			var c := NpcCover.find(me, tp)
			if c != Vector3.INF and (cover == Vector3.INF or _flat(c, cover) > 1.0):
				_cover_since = _clock                # (a new spot: its own time to get there)
			cover = c
		if not _reload_here and cover != Vector3.INF and _flat(me.global_position, cover) > 0.8:
			if _clock - _cover_since > COVER_GO_S or (_clock - _cover_since > 0.6 and me.way_blocked()):
				_reload_here = true
				cover = Vector3.INF
			else:
				me.crouch(false)
				me.go(cover, NpcFighter.RUN_SPEED, 0.5)
				return
		me.halt()
		me.crouch(_reload_here or cover != Vector3.INF)
		me.face_point(tp)
		me.begin_reload()
		return
	# no musket: an axe, close in
	_close_in(tp, d)


## Into reach of the foe at `tp` and a blow.
func _close_in(tp: Vector3, d: float) -> void:
	me.crouch(false)
	if d <= NpcFighter.REACH:
		me.halt()
		me.face_point(tp)
		me.swing_at(target)
	else:
		# (in sight and near: straight at him, no plan on the walk grid for a goal that moves each step, and at where he is
		# going: his pace ahead by the time it takes to get there, a little under a second at most)
		var near := seen_now and d < NpcFighter.STRAIGHT_M
		var to := tp
		if near:
			var v := NpcSenses.velocity_of(target)
			v.y = 0.0
			to = tp + v * minf(d / NpcFighter.RUN_SPEED, LEAD_S)
		me.go(to, NpcFighter.RUN_SPEED, NpcFighter.REACH * 0.7, near)


## Hurt past its courage, or too many of its squad down while it is hurt.
func _should_flee(_d: float) -> bool:
	if _routed:
		return false
	var hurt := me.health < me.health_max * (0.2 + 0.3 * (1.0 - me.courage))
	var losses := me.squad != null and me.squad.lost_frac() > 0.45 + 0.4 * me.courage
	return hurt or (losses and me.health < me.health_max * 0.8)


func _start_flee() -> void:
	var from := last_seen if last_seen != Vector3.INF else me.global_position - me.forward() * 5.0
	_flee_to = _away(from, FLEE_M)
	cover = Vector3.INF
	me.crouch(false)
	_to(State.FLEE)
	me.bark("flee")


func _flee(_dt: float) -> void:
	if not _released:
		var near := NpcSenses.foes_of(me, 14.0, 1)
		if not near.is_empty():
			var d := float(near[0][0])
			if d < CORNER_M or (me.way_blocked() and d < 12.0):
				me.surrender()
				_to(State.SURRENDER)
				return
	if _flat(me.global_position, _flee_to) < 3.0 or _state_t > FLEE_S:
		# away: out of the fight, it stays there
		_routed = true
		target = null
		me.order_kind = ""
		me.home = me.global_position
		_to(State.IDLE)
		me.halt()
		return
	me.go(_flee_to, NpcFighter.RUN_SPEED, 2.5)


## Whether `n` is a foe of its faction that can still fight (the player, or a fighter of a hostile faction).
func _is_foe(n: Variant) -> bool:
	if not NpcSenses.can_fight(n):
		return false
	var other := NpcFactions.PLAYER if n is FrontierPlayer else (n as NpcFighter).faction
	return NpcFactions.hostile(me.faction, other)


## The foe it is most aware of that can still fight (null: none).
func _next_foe() -> Node3D:
	var best: Node3D = null
	var best_a := SUSPECT
	for id: int in aware:
		var a := float(aware[id])
		if a < best_a or not is_instance_id_valid(id):
			continue
		var n := instance_from_id(id) as Node3D
		if NpcSenses.can_fight(n):
			best = n
			best_a = a
	return best


## A point `m` metres from here, straight away from `from`, on the ground.
func _away(from: Vector3, m: float) -> Vector3:
	var away := me.global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = -me.forward()
	var p := me.global_position + away.normalized() * m
	p.y = FrontierTerrain.height_at(p.x, p.z)
	return p


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
