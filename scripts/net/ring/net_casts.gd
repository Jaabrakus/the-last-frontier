class_name NetCasts
extends RefCounted
## Casts online (docs/tidebreak/ring_netcode.md, "Casts"): a cast travels as an event, never as its things; every machine runs
## the same code with the same inputs and makes the same things. Static; NetSpells.net is the session.
##   recorded    the player's cast as it lands (SwayCaster._apply_grown: begin() .. end() round SwayEffects.apply): every
##               question its caster was asked meanwhile answered and kept in order (PlayerBendCaster's tape: the aim, the
##               launch point, the keys, the target), its dice seeded, and with them what the run needs to run again: the
##               move, its variation and tier, grown, airborne, its release time (the caster's own clock: what a hit tells
##               him back is in it), whether it was let go on the Beat (only when it was: a worn technique's; release_of),
##               its target's net id and point, where he stood, his velocity, facings. Sent to every
##               other machine (RingNet.send_cast); here it ran at once, its things named "<my peer>:<seq>:<n>"
##   run         run(ev, sender) on every other machine: the cast run again on its caster's puppet (his NetBendCaster answering
##               from the event, his SwayCaster pinned to its variation, the puppet stood where he stood while it runs), its
##               things named as on his machine. On the host it decides (hits, meetings: NetSpells); elsewhere a ghost. A
##               guard's zone is the puppet's held guard (SwayCaster._gzone: his guard hold pose while his E is held)
##   raised      a Spike's or Boulder's stone raised at its lock's fill (SwayCaster._raise_at_fill) and turned by a switch
##               (step_other) recorded and run the same way (kind "raise", "reshape": FormEffects.raise_stone, reshape_raised
##               on the puppet); its grow and its drop are the lock's course (net_lock "grew", "drop", "broken", "fizzled")
##   its age     (R1 e) a cast run here is as old as the wire made it (the host's clock now less its `sent`, at most
##               MAX_AGE_S): its bolts are flown on by it at once (BendBolt.catch_up: on the host their meetings decided as
##               they go), its zones are that much older (a guard's beat measured from when he raised it), so the host's
##               things and every ghost stand where the caster sees his
##   the lock    the player's lock as it goes (SwayCaster's lock_started, lock_switched, locked, grew, cast, lock_broken, fizzled;
##               watch()) sent too (RingNet.send_lock); the puppet's SwayCaster plays it (SwayCaster.net_lock): its state
##               and its signals, so its SwayPose poses him as his own machine poses him
## Offline nothing is recorded and nothing is sent: begin() is {} and end() does nothing.

## The most of a cast's age caught up (s): what the wire took past it is not made up (a bolt never jumps far).
const MAX_AGE_S := 0.15

## Every cast this machine has sent (tests: the newest last, at most 32) and run for another machine.
static var sent: Array = []
## Tests: added to every cast's age here (a slow link stood in for on one machine).
static var age_bias := 0.0
static var ran: Array = []
static var _seq := 0
## The SwayCasters watched for their locks (instance ids).
static var _watched := {}


# ---------------------------------------------------------------- the player's own
## The cast of SwayCaster `sc` about to land (its move `m` on `t` at `at`; `grown`, `rel` its release: {air, at}): the
## recording begun, its event so far ({} offline, or not this machine's player).
static func begin(sc: SwayCaster, m: String, t: Node3D, at: Vector3, grown: bool, rel: Dictionary, kind := "cast") -> Dictionary:
	if not NetSpells.online() or sc == null or sc.puppet or sc.player == null or not sc.player.is_local:
		return {}
	var p := sc.player
	var bc := BendCaster.of(p) as PlayerBendCaster
	if bc == null:
		return {}
	_seq += 1
	var net := NetSpells.net
	var ev := {"id": "%d:%d" % [net.my_id(), _seq], "kind": kind, "m": m, "mode": sc.mode_of(m), "tier": sc.tier(m), "grown": grown,
			"air": bool(rel.get("air", BendR3.airborne(p))), "rel_at": float(rel.get("at", BendStatus.now())),
			"t": net.net_id_of(t), "at": at, "pos": p.global_position, "vel": p.velocity, "ry": p.rotation.y,
			"yaw": p.yaw, "pitch": p.pitch, "seed": randi(), "src": sc.lock_src, "sent": net.clock.now(),
			"bound": bc.feet_bound(), "carry": bc.carry_ready()}
	if bool(rel.get("beat", false)):
		ev["beat"] = true                             # (let go on the Beat, a worn technique's: AirTalents; Classic never sends it)
	bc.tape_begin(int(ev.seed))
	ev["_keep"] = NetSpells.run_begin(String(ev.id))
	return ev


## The release a cast event `ev` replays with (BendR3.release): {air, at}, and beat when it was let go on the Beat.
static func release_of(ev: Dictionary) -> Dictionary:
	var rel := {"air": bool(ev.get("air", false)), "at": float(ev.get("rel_at", BendStatus.now()))}
	if bool(ev.get("beat", false)):
		rel["beat"] = true
	return rel


## The cast begun (begin) has landed: its tape closed, its event sent.
static func end(sc: SwayCaster, ev: Dictionary) -> void:
	if ev.is_empty():
		return
	NetSpells.run_end(ev._keep as Dictionary)
	ev.erase("_keep")
	var bc := BendCaster.of(sc.player) as PlayerBendCaster
	ev["tape"] = bc.tape_end() if bc != null else {}
	_log(sent, ev)
	if NetSpells.online():
		NetSpells.net.send_cast(ev)


## SwayCaster `sc` (this machine's player's) watched: its lock's course sent as it goes (once a caster).
static func watch(sc: SwayCaster) -> void:
	if sc == null or _watched.has(sc.get_instance_id()):
		return
	_watched[sc.get_instance_id()] = true
	sc.lock_started.connect(func(m: String, _t: Node3D) -> void: _send_lock(sc, ["start", m, sc.mode_of(m), sc.lock_src]))
	sc.lock_switched.connect(func(m: String, _t: Node3D) -> void: _send_lock(sc, ["start", m, sc.mode_of(m), sc.lock_src]))
	sc.locked.connect(func(m: String, _t: Node3D) -> void: _send_lock(sc, ["full", m]))
	sc.grew.connect(func(m: String) -> void: _send_lock(sc, ["grew", m]))
	sc.cast.connect(func(m: String, _t: Node3D) -> void: _send_lock(sc, ["cast", m]))
	sc.lock_broken.connect(func(m: String, _t: Node3D, why: String) -> void: _send_lock(sc, ["broken", m, why]))
	sc.fizzled.connect(func(m: String, _t: Node3D) -> void: _send_lock(sc, ["fizzled", m]))


## A note of SwayCaster `sc`'s lock beside its signals (["drop", m]: its raised stone let go): sent as its lock's course.
static func lock_note(sc: SwayCaster, e: Array) -> void:
	_send_lock(sc, e)


static func _send_lock(sc: SwayCaster, e: Array) -> void:
	if NetSpells.online() and is_instance_valid(sc) and not sc.puppet and sc.player != null and sc.player.is_local:
		NetSpells.net.send_lock(e)


# ---------------------------------------------------------------- another machine's
## Peer `from`'s cast `ev` run here on his puppet (see the header).
static func run(ev: Dictionary, from: int) -> void:
	var net := NetSpells.net
	if net == null:
		return
	var p := net.body_of(from) as FrontierPlayer
	var sc := SwayCaster.of(p) if p != null else null
	var nbc := BendCaster.of(p) as NetBendCaster if p != null else null
	if sc == null or nbc == null:
		return
	_log(ran, ev)
	var m := String(ev.get("m", ""))
	var mode := String(ev.get("mode", ""))
	# (stood where he stood, as he faced, while it runs: the cast reads its body's place as his machine read his)
	var keep_xf := p.global_transform
	var keep_v := p.velocity
	var keep_yaw := p.yaw
	var keep_pitch := p.pitch
	p.global_position = ev.get("pos", p.global_position)
	p.rotation.y = float(ev.get("ry", p.rotation.y))
	p.velocity = ev.get("vel", Vector3.ZERO)
	p.yaw = float(ev.get("yaw", p.yaw))
	p.pitch = float(ev.get("pitch", p.pitch))
	var keep_rel := BendR3.release
	BendR3.release = release_of(ev)                   # (the Beat too: the host decides what a Beat cast does)
	nbc.begin(ev)
	nbc.grown = bool(ev.get("grown", false))
	sc.net_pin(m, mode)
	var t: Node3D = net.body_by_net_id(int(ev.get("t", 0)))
	if t == null:
		t = p                                         # (no body: the move's own point (`at`) is what it reads)
	var keep_ctx := NetSpells.run_begin(String(ev.get("id", "")), true)
	var made: Array = NetSpells.ctx().get("made", [])
	match String(ev.get("kind", "cast")):
		"raise":
			sc.raised = FormEffects.raise_stone(sc, m, mode)          # (his Spike or Boulder up before him, as on his machine)
		"reshape":
			if sc.raised != null and is_instance_valid(sc.raised):
				sc.raised = FormEffects.reshape_raised(sc.raised, mode)
		_:
			SwayEffects.apply(sc, m, t, ev.get("at", p.global_position))
			FormEffects.drop_raised_of(p)              # (a stone the cast did not throw lies loose, as his)
	NetSpells.run_end(keep_ctx)
	catch_up(made, age_of(ev))
	sc.net_unpin()
	nbc.grown = false
	nbc.end()
	BendR3.release = keep_rel
	if String(ev.get("src", "")) == SwayCaster.SRC_GUARD:
		var z: Variant = BendEffects.last_of(nbc).get("zone")
		sc.net_guard(z as BendZone if z is BendZone and is_instance_valid(z) else null)
	p.global_transform = keep_xf
	p.velocity = keep_v
	p.yaw = keep_yaw
	p.pitch = keep_pitch


## Cast `ev`'s age here (s): the host's clock now less when it was cast, at most MAX_AGE_S (0: no clock yet).
static func age_of(ev: Dictionary) -> float:
	var net := NetSpells.net
	if net == null or not net.clock.synced or not ev.has("sent"):
		return 0.0
	return clampf(net.clock.now() - float(ev.sent) + age_bias, 0.0, MAX_AGE_S)


## The things a cast's run made, `age` s on: its bolts flown on (BendBolt.catch_up), its zones that much older.
static func catch_up(made: Array, age: float) -> void:
	if age <= 0.0:
		return
	for n: Variant in made:
		if n is BendBolt and is_instance_valid(n):
			(n as BendBolt).catch_up(age)
		elif n is BendZone and is_instance_valid(n):
			(n as BendZone).t += age


## Peer `from`'s lock event `e` played on his puppet's SwayCaster.
static func lock_event(e: Array, from: int) -> void:
	var net := NetSpells.net
	var p := net.body_of(from) if net != null else null
	var sc := SwayCaster.of(p) if p != null else null
	if sc != null and sc.puppet:
		sc.net_lock(e)


static func _log(into: Array, ev: Dictionary) -> void:
	into.append(ev)
	if into.size() > 32:
		into.pop_front()


static func reset() -> void:
	sent.clear()
	ran.clear()
	_watched.clear()
