class_name NpcSkirmish
extends RefCounted
## A fighter that fights from cover (NpcFighter.tactics "cover": the duel's opponent, DuelMode; a squad's opts tactics "cover";
## the user, 2026-10-04: "lets build a test game where it is 1v1 npc can find cover aim and etc"). NpcBrain's COMBAT hands it
## each think (step) once its own rules have said who the foe is and whether he is in sight now (NpcSenses, the light, his
## stance, his cover: no wallhack). Where it believes he is (threat()): where he is while it sees him, else the newer of where it
## last saw him and where it last heard him (his shot; his feet near: NpcBrain.heard_at).
##   MOVE    to the cover it chose (NpcCover.pick: a spot behind something solid that hides it from him, with a place to fight
##           from): a sprint while he has it in sight (SPRINT_SPEED), a run otherwise; caught in the open near him (SNAP_M)
##           with a shot in the musket, it stops and fires
##   HIDE    behind it, crouched behind a low thing, standing behind a tall one, facing him; empty, it reloads there; loaded,
##           after a moment (HOLD_S by its skill) it peeks; while he is unseen it looks to its flanks now and then (LOOK_S)
##   PEEK    rises over the low thing, or steps out past its end (the aimed side-step, facing him: NpcFighter.face_lock), and
##           looks: in sight, the musket up (NpcFighter.begin_aim: its reaction if he has only now come into sight, the aim
##           settling, the lead, his chest or, when only his head shows, his head); nothing within PEEK_S, back
##   BACK    to the hidden spot again (and the reload); the next peek on the other side when this one drew his fire
## RELOCATE (a new NpcCover.pick, away from the spots it just left): its cover FLANKED (the line from where he is to its hidden
## spot clear, twice running; with a shot in it and him in sight it answers first), BROKEN (gone, crumbling), HIT there, no
## place left to fight from, the way there held up; he stays hidden (PEEKS_MAX peeks running saw nothing and nothing of him
## for SEEK_S): it FLANKS him (FLANK chance by its skill) or ADVANCES to nearer cover; badly hurt (FALLBACK_HEALTH) it FALLS
## BACK to cover further off and fights on. A foe on it (NpcBrain.CHARGE_M): a hurried shot when loaded, else the musket's butt
## (NpcBrain._close_in). An axe man (no musket) closes in as before.
## `bounds` (a Rect2 on the ground; the duel's arena) keeps its covers inside it. What it did is counted for the tests (peeks,
## relocations by why, the log).

enum Mode { MOVE, HIDE, PEEK, BACK }
const NAMES := ["MOVE", "HIDE", "PEEK", "BACK"]

## How far it looks for cover (m).
const RADIUS := 24.0
## Its cover is looked at for a flank every FLANK_S; FLANK_N looks running that find it open, and it goes.
const FLANK_S := 0.5
const FLANK_N := 2
## Hidden and loaded, how long it waits before it peeks (s), by its skill preset ("" a line fighter's own: normal).
const HOLD_S := {"easy": Vector2(1.5, 2.8), "normal": Vector2(0.8, 1.9), "hard": Vector2(0.45, 1.1)}
## How long a peek looks for him once out (s).
const PEEK_S := Vector2(1.3, 2.2)
## Peeks running that saw nothing, and nothing seen or heard of him for SEEK_S: it goes after him.
const PEEKS_MAX := 2
const SEEK_S := 9.0
## Going after a hidden foe, the chance it flanks him rather than advancing (by its skill preset).
const FLANK := {"easy": 0.25, "normal": 0.5, "hard": 0.65}
## Under this share of its health it falls back (at most each FALLBACK_S).
const FALLBACK_HEALTH := 0.5
const FALLBACK_S := 15.0
## Caught in the open with a shot in it, the foe this near and seeing it, more than SNAP_FAR_M from its cover: it fires.
const SNAP_M := 16.0
const SNAP_FAR_M := 4.0
## Going to a cover longer than this (s), or held up on the way: another.
const MOVE_MAX_S := 8.0
## While the foe is unseen past LOOK_AFTER_S: every LOOK_S it looks LOOK_DEG to one side of where it believes he is, for LOOK_FOR_S.
const LOOK_AFTER_S := 4.0
const LOOK_S := 3.2
const LOOK_FOR_S := 1.0
const LOOK_DEG := 70.0
## A foe newly in sight: out of it longer than this (s) before.
const NEW_SIGHT_S := 1.0
## It remembers the last few spots it left (it does not go back to them at once).
const LEFT_KEEP := 3

var b: NpcBrain
var me: NpcFighter
var mode := Mode.HIDE
## The cover it fights from (NpcCover.pick's record), {} none yet.
var cov := {}
## Keeps its covers inside this (the duel's arena; no area: anywhere).
var bounds := Rect2()
var mode_t := 0.0
var peeks := 0
var peeks_blind := 0
var shots_from_cover := 0
var relocations := 0
## Relocations by why ("flanked", "broken", "hit", "seek", "fallback", "held up", "no peek"), and the last.
var why_count := {}
var last_why := ""
## What it decided, newest last (tests, the debug view): [clock, text].
var notes: Array = []
var _hold := 1.0
var _peek_for := 1.5
var _peek_out_t := -1.0
var _peek_saw := false
var _peek_side := 0
var _flank_t := 0.0
var _flank_n := 0
var _fallback_t := -100.0
var _hits := 0
var _look_t := 0.0
var _look_until := -1.0
var _look_sign := 1.0
var _left: Array[Vector3] = []
var _seen_last := -100.0
var _react_next := false
var _hit_pending := false
## The last shot of his it heard (the brain's heard_t): one heard while it peeks or hides, the next peek from elsewhere.
var _heard_seen := -100.0
## A shot from its hidden spot was blocked (its own cover in the way): from here it peeks instead.
var _blocked_here := false
## A pick that found nothing is not tried again before this (the brain's clock).
var _pick_after := -100.0


func _init(brain: NpcBrain) -> void:
	b = brain
	me = brain.me


func mode_name() -> String:
	return NAMES[mode]


## Where it believes the foe is now (see the header).
func threat() -> Vector3:
	if b.seen_now and NpcSenses.can_fight(b.target):
		return b.target.global_position
	if b.heard_at != Vector3.INF and b.heard_t > b.seen_t:
		return b.heard_at
	if b.last_seen != Vector3.INF:
		return b.last_seen
	return me.global_position + me.forward() * 20.0


## Its cover's hidden spot (INF none).
func spot() -> Vector3:
	return cov.spot if not cov.is_empty() else Vector3.INF


## A fight begins (or begins again): the cover and the counts of the last one forgotten.
func reset() -> void:
	cov = {}
	b.cover = Vector3.INF
	mode = Mode.HIDE
	mode_t = 0.0
	peeks_blind = 0
	_left.clear()
	_flank_n = 0
	_hits = me.hits_taken
	_seen_last = -100.0


# ---------------------------------------------------------------- each think
func step(dt: float) -> void:
	mode_t += dt
	var t := b.target
	var seen := b.seen_now
	var now := b._clock
	if seen:
		if now - _seen_last > NEW_SIGHT_S:
			_react_next = true                     # (he has just come into sight: its reaction before the musket comes up)
		_seen_last = now
	var tp := threat()
	var d := me.global_position.distance_to(tp)
	var has_gun := me.gun != null and me.gun.visible
	var loaded := has_gun and me.loaded
	if me.hits_taken != _hits:
		_hits = me.hits_taken
		_hit_pending = true
	if b.heard_t > _heard_seen:
		# (his shot: the place it last showed itself is watched; the next peek from another)
		_heard_seen = b.heard_t
		if not cov.is_empty() and mode != Mode.MOVE:
			_peek_side = _other_side()
	# a foe on it: a hurried shot, else the butt
	if seen and d < NpcBrain.CHARGE_M:
		if loaded:
			if not me.busy():
				_aim(t, true)
			return
		if me.action == "reload":
			me.cancel_reload()
		if not me.busy():
			me.face_lock = Vector3.INF
			b._close_in(t.global_position, d)
		return
	if me.busy():
		# loading where he has come round its cover: put by, and to cover from him there
		if me.action == "reload" and not cov.is_empty() and (_flanked(tp, dt) or NpcCover.broken(cov)):
			me.cancel_reload()
			_relocate("broken" if NpcCover.broken(cov) else "flanked", tp)
		return
	if not has_gun:
		# (an axe man, or his musket dropped: in at him as before)
		me.face_lock = Vector3.INF
		if seen:
			b._close_in(t.global_position, d)
		else:
			me.go(tp, NpcFighter.RUN_SPEED, 2.0)
		return
	if _hit_pending:
		# hit where it is: he knows the place (an answer first when it can see him with a shot in it)
		_hit_pending = false
		if not (seen and loaded) and mode != Mode.MOVE and _relocate("hit", tp):
			return
	if me.health < me.health_max * FALLBACK_HEALTH and now - _fallback_t > FALLBACK_S and mode != Mode.MOVE:
		_fallback_t = now
		if _relocate("fallback", tp):
			return
	if cov.is_empty() or NpcCover.broken(cov):
		var was := not cov.is_empty()
		if now < _pick_after or not _relocate("broken" if was else "first", tp):
			if now >= _pick_after:
				_pick_after = now + 1.5
			_in_the_open(seen, loaded, t, d, tp)
			return
	match mode:
		Mode.MOVE:
			_moving(seen, loaded, t, d, tp, now)
		Mode.HIDE:
			_hiding(seen, loaded, t, tp, now, dt)
		Mode.PEEK:
			_peeking(seen, loaded, t, tp)
		Mode.BACK:
			_going_back(tp)


func _moving(seen: bool, loaded: bool, t: Node3D, d: float, tp: Vector3, now: float) -> void:
	var goal: Vector3 = cov.spot
	var far := NpcBrain._flat(me.global_position, goal)
	if far <= 0.45:
		me.halt()
		_to(Mode.HIDE)
		_hold = 0.4                                  # (just there: a quick look first if he was in sight)
		me.crouch(bool(cov.low))
		me.face_point(tp)
		return
	if seen and loaded and d < SNAP_M and far > SNAP_FAR_M:
		_note("caught in the open: fires")
		_aim(t, true)
		return
	if mode_t > MOVE_MAX_S or (mode_t > 1.0 and me.way_blocked()):
		_relocate("held up", tp)
		return
	var exposed := seen or now - b.seen_t < 1.5
	me.face_lock = Vector3.INF
	me.crouch(false)
	me.go(goal, NpcFighter.SPRINT_SPEED if exposed else NpcFighter.RUN_SPEED, 0.35)


func _hiding(seen: bool, loaded: bool, t: Node3D, tp: Vector3, now: float, dt: float) -> void:
	me.halt()
	me.face_lock = Vector3.INF
	me.crouch(bool(cov.low))
	var open := _flanked(tp, dt)
	if seen and loaded and not _blocked_here:
		# (he is in sight from where it hides: a shot from here; its own cover in the way, it peeks or goes)
		if open:
			_note("flanked, he is in sight: fires from here")
		_aim(t)
		return
	if open:
		_relocate("flanked", tp)
		return
	if not loaded:
		me.face_point(tp)
		me.begin_reload()
		return
	if peeks_blind >= PEEKS_MAX and now - maxf(b.seen_t, b.heard_t) > SEEK_S:
		var how := "flank" if me.rng.randf() < float(FLANK.get(me.skill_preset, 0.5)) else "advance"
		if _relocate("seek", tp, how):
			return
		peeks_blind = 0                              # (nowhere better to go: it waits on here)
	_look_about(tp, now)
	if mode_t >= _hold:
		_start_peek(tp)


func _start_peek(tp: Vector3) -> void:
	NpcCover.peek_for(me, cov, tp, b.target, _peek_side)
	if cov.peek == Vector3.INF:
		if not _relocate("no peek", tp):
			_to(Mode.HIDE)
			_hold = 2.0
		return
	peeks += 1
	_peek_saw = false
	_peek_out_t = -1.0
	_peek_for = me.rng.randf_range(PEEK_S.x, PEEK_S.y)
	_to(Mode.PEEK)
	_note("peeks (%s)" % ("rises" if int(cov.peek_side) == 0 else ("steps right" if int(cov.peek_side) > 0 else "steps left")))


func _peeking(seen: bool, loaded: bool, t: Node3D, tp: Vector3) -> void:
	if not loaded:
		# (it fired: back behind its cover to load; the next peek from another place when it can)
		shots_from_cover += 1
		_peek_side = _other_side()
		_to(Mode.BACK)
		_going_back(tp)
		return
	var p: Vector3 = cov.peek
	me.crouch(bool(cov.peek_low))
	if NpcBrain._flat(me.global_position, p) > 0.25:
		if seen:
			_peek_saw = true
			_aim(t)
			return
		me.face_lock = tp + Vector3.UP * 1.3
		me.go(p, NpcFighter.STRAFE_SPEED, 0.18, true)
		if mode_t > 4.0:
			_to(Mode.BACK)                            # (it cannot get out there)
		return
	me.halt()
	me.face_lock = Vector3.INF
	me.face_point(tp)
	if _peek_out_t < 0.0:
		_peek_out_t = mode_t
	if seen:
		_peek_saw = true
		_aim(t)
		return
	if mode_t - _peek_out_t > _peek_for:
		if not _peek_saw:
			peeks_blind += 1
		_note("peek saw nothing" if not _peek_saw else "back")
		_to(Mode.BACK)


func _going_back(tp: Vector3) -> void:
	var s: Vector3 = cov.spot
	me.crouch(bool(cov.low))
	if NpcBrain._flat(me.global_position, s) <= 0.3:
		me.halt()
		me.face_lock = Vector3.INF
		me.face_point(tp)
		_to(Mode.HIDE)
		_hold = _hold_s()
		return
	me.face_lock = tp + Vector3.UP * 1.3
	me.go(s, NpcFighter.STRAFE_SPEED, 0.15, true)
	if mode_t > 4.0:
		_relocate("held up", tp)


## No cover near: it fights where it stands (crouched to load, the musket up when he shows) and goes toward him.
func _in_the_open(seen: bool, loaded: bool, t: Node3D, d: float, tp: Vector3) -> void:
	me.face_lock = Vector3.INF
	if seen and loaded:
		_aim(t)
	elif not loaded:
		me.halt()
		me.crouch(true)
		me.face_point(tp)
		me.begin_reload()
	elif d > 8.0:
		me.crouch(false)
		me.go(tp, NpcFighter.RUN_SPEED, 6.0)


## The musket up on `t`: its reaction first if he has only now come into sight, his head when that is all of him that shows.
func _aim(t: Node3D, hurry := false) -> void:
	var react := 0.0
	if _react_next:
		react = float(me.aim_cfg.get("reaction_s", 0.0))
		_react_next = false
	me.face_lock = Vector3.INF
	me.halt()
	me.begin_aim(t, b.seen_part(t), react, hurry)


## A new cover for `why` (see the header; `how` the pick's mode: "fight", "advance", "flank", "fallback"); false: none found,
## the old one kept.
func _relocate(why: String, tp: Vector3, how := "") -> bool:
	if how == "":
		how = "fallback" if why == "fallback" else "fight"
	var avoid: Array = _left.duplicate()
	if not cov.is_empty():
		avoid.append(cov.spot)
	# (flanked, hit, its cover gone: in a hurry, the nearest good cover)
	var urgent := why in ["flanked", "broken", "hit", "held up"]
	var opts := {"radius": RADIUS, "mode": how, "avoid": avoid, "foe": b.target, "bounds": bounds, "urgent": urgent}
	var rec := NpcCover.pick(me, tp, opts)
	if rec.is_empty() and how in ["flank", "advance"]:
		opts["mode"] = "advance" if how == "flank" else "flank"
		rec = NpcCover.pick(me, tp, opts)
	if rec.is_empty() and why in ["flanked", "broken", "hit", "held up", "no peek"]:
		opts["mode"] = "reload"
		rec = NpcCover.pick(me, tp, opts)
	if rec.is_empty() and why in ["flanked", "broken", "hit"] and not _left.is_empty():
		# (nothing new near: back to a cover it left a while ago, rather than none)
		opts["avoid"] = [cov.spot] if not cov.is_empty() else []
		opts["mode"] = "fight"
		rec = NpcCover.pick(me, tp, opts)
	if rec.is_empty():
		_note("%s: no cover found" % why)
		return false
	if not cov.is_empty():
		_left.append(cov.spot)
		while _left.size() > LEFT_KEEP:
			_left.remove_at(0)
		relocations += 1
		why_count[why] = int(why_count.get(why, 0)) + 1
	last_why = why
	cov = rec
	b.cover = rec.spot
	_blocked_here = false
	peeks_blind = 0
	_flank_n = 0
	_peek_side = 0
	_to(Mode.MOVE)
	_note("%s: to %s cover %.0f m off (%s, %.0f m from him)" % [why, "low" if rec.low else "tall",
			NpcBrain._flat(me.global_position, rec.spot), how, float(rec.d_threat)])
	return true


## Whether its cover no longer hides it from where it believes he is (FLANK_N looks running, one each FLANK_S): the lines from
## him to its hidden spot clear, or to its chest where it is.
func _flanked(tp: Vector3, dt: float) -> bool:
	_flank_t -= dt
	if _flank_t > 0.0:
		return _flank_n >= FLANK_N
	_flank_t = FLANK_S
	if NpcCover.protects(me, cov, tp, b.target) and not NpcCover.exposed(me, tp, b.target):
		_flank_n = 0
	else:
		_flank_n += 1
	return _flank_n >= FLANK_N


## A look to one flank and then the other while he is unseen (its eyes do the rest: NpcBrain's sight).
func _look_about(tp: Vector3, now: float) -> void:
	if now - maxf(b.seen_t, b.heard_t) < LOOK_AFTER_S:
		me.face_point(tp)
		return
	if now < _look_until:
		return
	if now - _look_t >= LOOK_S:
		_look_t = now
		_look_until = now + LOOK_FOR_S
		_look_sign = -_look_sign
		var to := tp - me.global_position
		to.y = 0.0
		var dir := to.normalized().rotated(Vector3.UP, deg_to_rad(LOOK_DEG) * _look_sign) if to.length() > 0.1 else me.forward()
		me.face_point(me.global_position + dir * 5.0)
	else:
		me.face_point(tp)


## The next peek's side after one from `cov.peek_side`: the other side after a side-step, a side (either) after rising over it.
func _other_side() -> int:
	var k := int(cov.get("peek_side", 0))
	return -k if k != 0 else (1 if me.rng.randf() < 0.5 else -1)


## The shot it meant was blocked from where it is (NpcBrain.shot_blocked): from a peek, another place next; from its hidden
## spot, a peek at once.
func on_shot_blocked(_why: String) -> void:
	if mode == Mode.PEEK:
		_peek_side = _other_side()
		_to(Mode.BACK)
	elif mode == Mode.HIDE:
		_blocked_here = true
		_hold = 0.0


func _hold_s() -> float:
	var r: Vector2 = HOLD_S.get(me.skill_preset, HOLD_S.normal)
	return me.rng.randf_range(r.x, r.y)


func _to(m: Mode) -> void:
	if m != mode:
		mode = m
		mode_t = 0.0


func _note(what: String) -> void:
	notes.append([snappedf(b._clock, 0.01), what])
	if notes.size() > 40:
		notes.remove_at(0)
