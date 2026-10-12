class_name NetCasts
extends RefCounted
## Casts online (docs/tidebreak/ring_netcode.md, "Casts"): a cast travels as an event, never as its things; every machine runs
## the same code with the same inputs and makes the same things. Static; NetSpells.net is the session.
##   recorded    the player's cast as it lands (SwayCaster._apply_grown: begin() .. end() round SwayEffects.apply): every
##               question its caster was asked meanwhile answered and kept in order (PlayerBendCaster's tape: the aim, the
##               launch point, the keys, the target), its dice seeded, and with them what the run needs to run again: the
##               move, its variation and tier, grown, airborne, its release time (the caster's own clock: what a hit tells
##               him back is in it), its target's net id and point, where he stood, his velocity, facings. Sent to every
##               other machine (RingNet.send_cast); here it ran at once, its things named "<my peer>:<seq>:<n>"
##   run         run(ev, sender) on every other machine: the cast run again on its caster's puppet (his NetBendCaster answering
##               from the event, his SwayCaster pinned to its variation, the puppet stood where he stood while it runs), its
##               things named as on his machine. On the host it decides (hits, meetings: NetSpells); elsewhere a ghost. A
##               guard's zone is the puppet's held guard (SwayCaster._gzone: his guard hold pose while his E is held)
##   the lock    the player's lock as it goes (SwayCaster's lock_started, lock_switched, locked, grew, cast, lock_broken, fizzled;
##               watch()) sent too (RingNet.send_lock); the puppet's SwayCaster plays it (SwayCaster.net_lock): its state
##               and its signals, so its SwayPose poses him as his own machine poses him
## Offline nothing is recorded and nothing is sent: begin() is {} and end() does nothing.

## Every cast this machine has sent (tests: the newest last, at most 32) and run for another machine.
static var sent: Array = []
static var ran: Array = []
static var _seq := 0
## The SwayCasters watched for their locks (instance ids).
static var _watched := {}


# ---------------------------------------------------------------- the player's own
## The cast of SwayCaster `sc` about to land (its move `m` on `t` at `at`; `grown`, `rel` its release: {air, at}): the
## recording begun, its event so far ({} offline, or not this machine's player).
static func begin(sc: SwayCaster, m: String, t: Node3D, at: Vector3, grown: bool, rel: Dictionary) -> Dictionary:
	if not NetSpells.online() or sc == null or sc.puppet or sc.player == null or not sc.player.is_local:
		return {}
	var p := sc.player
	var bc := BendCaster.of(p) as PlayerBendCaster
	if bc == null:
		return {}
	_seq += 1
	var net := NetSpells.net
	var ev := {"id": "%d:%d" % [net.my_id(), _seq], "m": m, "mode": sc.mode_of(m), "tier": sc.tier(m), "grown": grown,
			"air": bool(rel.get("air", BendR3.airborne(p))), "rel_at": float(rel.get("at", BendStatus.now())),
			"t": net.net_id_of(t), "at": at, "pos": p.global_position, "vel": p.velocity, "ry": p.rotation.y,
			"yaw": p.yaw, "pitch": p.pitch, "seed": randi(), "src": sc.lock_src, "sent": net.clock.now(),
			"bound": bc.feet_bound(), "carry": bc.carry_ready()}
	bc.tape_begin(int(ev.seed))
	ev["_keep"] = NetSpells.run_begin(String(ev.id))
	return ev


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
	BendR3.release = {"air": bool(ev.get("air", false)), "at": float(ev.get("rel_at", BendStatus.now()))}
	nbc.begin(ev)
	nbc.grown = bool(ev.get("grown", false))
	sc.net_pin(m, mode)
	var t: Node3D = net.body_by_net_id(int(ev.get("t", 0)))
	if t == null:
		t = p                                         # (no body: the move's own point (`at`) is what it reads)
	var keep_ctx := NetSpells.run_begin(String(ev.get("id", "")))
	SwayEffects.apply(sc, m, t, ev.get("at", p.global_position))
	NetSpells.run_end(keep_ctx)
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
