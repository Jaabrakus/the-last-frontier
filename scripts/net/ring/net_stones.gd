class_name NetStones
extends RefCounted
## Stones online (docs/tidebreak/ring_netcode.md, "Stones"): earth's ammo kept one on every machine. Static; NetSpells.net is
## the session.
##   made        a stone a cast makes (a kick-up, a raised Spike or Boulder, a chunk torn from a wall) is made by its cast's run
##               on every machine and named there (FormStone._make: NetSpells.tag); one the host makes by a decision (a catch's
##               held stone, a stone dropped loose off a wall or by a late or cushioning guard, earth's Pop stone) is named in
##               a run of its own (spawn) and told in full (check's first word)
##   the host    the host's physics moves the stones (a ball rolls); each named stone tells its state (state_of: its shape,
##               place, phase, who holds it, whose loose stone it is, who raised it, its catch's numbers) when a decision
##               changed it (the signature: a catch, a drop, a throw's end), every SEND_MOVING_S while it rolls and once
##               when it comes to rest; never while a flight (GustLift) carries it: that is run alike on every machine. Its
##               end (shattered, sunk) is an "end" word (gone)
##   the others  apply(id, d): made from the word when it is not here (a decision's stone), else put where the host's is, its
##               phase and marks the host's (a holder's, a maker's: their own bodies here); kept still here (kinematic: no
##               machine but the host rolls a stone); a flight of it the host's word has ended stopped (GustLift.net_stop);
##               a sink begun; ended(): a stone the host's word ends, its flight's burst played when one carried it
## The marks a stone keeps by a body's instance id (bend_held_by, bend_loose_by, bend_raised_by) travel as the body's net id.

const SEND_MOVING_S := 0.2
## The marks told with a stone (beside its holder, loose maker and raiser): each as it is.
const MARKS: Array[StringName] = [&"bend_weight", &"bend_shape", &"bend_stone_d", &"bend_rally", &"bend_origin_tag",
		&"bend_pop_stone", &"bend_clean", &"bend_returns", &"form_grown"]
const BODY_MARKS: Array[StringName] = [&"bend_held_by", &"bend_loose_by", &"bend_raised_by"]


## A stone made now (FormStone._make): named in its cast's run (NetSpells.tag), or, the host's outside one, in a decision run
## of its own and marked to be told in full.
static func made(s: FormStone) -> void:
	if not NetSpells.online():
		return
	if NetSpells.naming():
		NetSpells.tag(s)
	elif NetSpells.decides():
		var keep := NetSpells.run_begin()
		NetSpells.tag(s)
		NetSpells.run_end(keep)
		s.set_meta(&"net_new", true)


## The host's turn of stone `s` each physics frame (see the header).
static func check(s: FormStone, dt: float) -> void:
	if not NetSpells.online() or not NetSpells.decides() or NetSpells.id_of(s) == "":
		return
	var busy := GustLift.busy(s)
	var sig := [int(s.state), busy, int(s.get_meta(&"bend_held_by", 0)), int(s.get_meta(&"bend_loose_by", -1)),
			int(s.get_meta(&"bend_raised_by", 0)), s.freeze, s.has_meta(&"bend_pop_stone"), bool(s.get_meta(&"bend_clean", false))]
	var moving := not busy and not s.freeze and s.linear_velocity.length() > 0.2
	var was: Array = s.get_meta(&"net_sig", [])
	var t := float(s.get_meta(&"net_t", 0.0)) + dt
	var tell := s.has_meta(&"net_new") or (sig != was and not busy)
	if not tell and not busy:
		if moving and t >= SEND_MOVING_S:
			tell = true
		elif not moving and bool(s.get_meta(&"net_moving", false)):
			tell = true                                  # (come to rest: its place once more)
	s.set_meta(&"net_moving", moving)
	s.set_meta(&"net_sig", sig)                          # (a flight's own changes are the flight's: told by its end)
	if not tell:
		s.set_meta(&"net_t", t)
		return
	s.set_meta(&"net_t", 0.0)
	if s.has_meta(&"net_new"):
		s.remove_meta(&"net_new")
	NetSpells.word(["stone", NetSpells.id_of(s), state_of(s)])


## Stone `s` as the host has it (see the header).
static func state_of(s: FormStone) -> Dictionary:
	var marks := {}
	for k in MARKS:
		if s.has_meta(k):
			marks[String(k)] = s.get_meta(k)
	var bodies := {}
	for k in BODY_MARKS:
		if s.has_meta(k):
			var id := int(s.get_meta(k))
			bodies[String(k)] = instance_from_id(id) if id > 0 else null
	return {"kind": s.kind, "r": s.radius, "h": s.height, "matter": s.matter, "xf": s.global_transform, "base": s.base,
			"st": int(s.state), "frozen": s.freeze, "life": s.life_s, "sink": s.sink_s, "age": s.age, "busy": GustLift.busy(s),
			"marks": marks, "bodies": bodies}


## The host's word on stone `id` (another machine's): see the header.
static func apply(id: String, d: Dictionary) -> void:
	var s := NetSpells.find(id) as FormStone
	if s == null:
		if int(d.get("st", 0)) == FormStone.State.SINKING or NetSpells.net == null:
			return
		s = _make_from(d)
		if s == null:
			return
		NetSpells.name_as(s, id)
	if not bool(d.get("busy", false)):
		for l in s.get_tree().get_nodes_in_group(GustLift.GROUP):
			if (l as GustLift).stone == s:
				(l as GustLift).net_stop()             # (the host's flight of it is over: its place is the host's word's)
		s.global_transform = d.get("xf", s.global_transform)
	s.base = d.get("base", s.base)
	s.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	s.freeze = true                                     # (only the host rolls a stone)
	var st := int(d.get("st", s.state))
	if st == FormStone.State.SINKING:
		s.sink()
	elif s.state != FormStone.State.SINKING:
		s.state = st
		s.age = float(d.get("age", s.age))
	for k in MARKS:
		if s.has_meta(k) and not (d.get("marks", {}) as Dictionary).has(String(k)):
			s.remove_meta(k)
	var marks: Dictionary = d.get("marks", {})
	for k: String in marks:
		s.set_meta(StringName(k), marks[k])
	var bodies: Dictionary = d.get("bodies", {})
	for k in BODY_MARKS:
		if not bodies.has(String(k)):
			if s.has_meta(k):
				s.remove_meta(k)
			continue
		var b: Variant = bodies[String(k)]
		s.set_meta(k, (b as Node).get_instance_id() if b is Node and is_instance_valid(b) else 0)


## A stone made here from the host's word `d` (its shape, its place).
static func _make_from(d: Dictionary) -> FormStone:
	var tree := NetSpells.net.get_tree()
	var scn := tree.current_scene if tree != null else null
	if scn == null:
		return null
	var base: Transform3D = d.get("base", Transform3D.IDENTITY)
	var nd := {"radius_m": float(d.get("r", 0.26)), "height_m": float(d.get("h", 1.75)), "rise_s": 0.01,
			"life_s": float(d.get("life", 30.0)), "sink_s": float(d.get("sink", 1.0)), "mass_kg": 20.0}
	var s: FormStone
	if String(d.get("kind", "cannonball")) == "spike":
		s = FormStone.spike(scn, base.origin, -base.basis.z, nd, 0, String(d.get("matter", "stone")))
	else:
		s = FormStone.ball(scn, base.origin - Vector3.UP * float(d.get("r", 0.26)), nd, 0, String(d.get("matter", "stone")))
	s.base = base
	s.global_transform = d.get("xf", base)
	return s


## Stone `s` gone on the host (its _exit_tree): the "end" word (another machine ends its own: ended).
static func gone(s: FormStone) -> void:
	if NetSpells.online() and NetSpells.decides() and NetSpells.id_of(s) != "":
		NetSpells.word(["end", NetSpells.id_of(s), "gone", s.global_position])


## The host's word that stone `s` is gone (another machine's): a flight carrying it bursts as the host's did (its shatter's
## look) where the host's ended; else it goes.
static func ended(s: FormStone, at: Vector3) -> void:
	if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
		return
	for l in s.get_tree().get_nodes_in_group(GustLift.GROUP):
		var lift := l as GustLift
		if lift.stone == s and lift.phase == GustLift.Phase.FLIGHT:
			s.global_position = at
			lift.net_burst(at)
			return
	s.queue_free()
