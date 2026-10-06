extends SceneTree
## The guard matrix (round 2's skills, the owner 2026-10-05: "dont forget the other elements": every guard used well by the
## bots at each preset): each element's shots sent into each element's guard, bot against bot, printed. In the duel's level,
## on a flat slab raised SLAB_Y over the arena (a deck with open edges, as tests/npc/test_bend_bots.gd), a shooter bot and a
## guard bot ELEMENT_M apart, both held to their part (each one's opening grace kept on: no attack of its own begun; the
## shooter told each shot, NpcBending._next, through its own lock and wind-up, so the guard reads it as a man's):
##   the shots  each element's strikes: key 1's moves, key 2's first, its jab (earth Spike, Boulder, Shove, Pebbles; water
##              Lash, Spear, Wave, Splash; fire Punch, Lightning, Kick, Embers; air Slice, Wind Ball, Gust, Palm), SHOTS of them
##              a mirror pairing in turn (half as many a cross pairing), both put back at their places and made whole between
##   counted    per pairing (shooter element > guard element, the preset): guards begun, perfect, late, whiffs, what the guard
##              took (answered), the guard bot struck (hits on it), earth's catches, clean catches and returns
##   gated      each element's guard is begun against its own element's shots and takes them (and, for earth, stones are
##              caught and sent back) at normal and hard together; at easy (react_chance 0.25: it lets most through) the four together
##              begin some; a hard bot's guards land on the beat more often than an easy one's (perfect share)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_guard_matrix.gd -- mode=duel [preset=easy|normal|hard]
##         [shots=6]
## With no preset: the whole matrix at normal, the mirrors (each element into its own guard) at easy and hard, so the run
## fits its watchdog; preset= one preset's whole matrix (the review's three runs).
## A "METRIC guard_matrix ..." line a pairing and a table at the end. Last line "GUARD MATRIX PASSED" or "... FAILED"; exit 0
## only on a pass; the watchdog (LIMIT_S) fails it first.

const NAME := "GUARD MATRIX"
const LIMIT_S := 410.0
const SLAB_Y := 220.0
const SLAB := Vector2(40.0, 16.0)
const ELEMENT_M := 12.0
const SHOT_S := 2.6
const FACTION_A := "ring_team_a"
const FACTION_B := "ring_team_b"
## Each element's shots ("move/mode").
const SHOTS := {
	"earth": ["stone_form/spike", "stone_form/cannonball", "earth_shove/push", "rock_jab/pebbles"],
	"water": ["water_whip/whip", "ice/spear", "wave/push", "water_jet/splash"],
	"fire": ["fire_blast/punch", "fire_arc/lightning", "fire_kick/kick", "fire_jab/embers"],
	"air": ["air_blast/slice", "air_blast/ball", "air_gust/gust", "air_palm/palm"],
}

var fails := 0
var p: FrontierPlayer
var duel: DuelMode
var mid := Vector3.ZERO
var presets: Array = ["normal", "easy", "hard"]
var shots := 6
## Every preset its whole matrix (preset= given), else only normal's: easy and hard their mirrors.
var whole := false
var _seed := 1750
## preset -> guard element -> [perfect, late] summed over the shooters (the perfect share by preset).
var beats := {}
## "preset/element" -> [guards begun, taken, catches, returns] against its own element's shots.
var mirrors := {}
var rows: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "light"              # (nothing here aims the player's camera)
	seed(1750)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("preset="):
			presets = [a.substr(7)]
			whole = true
		elif a.begins_with("shots=") and a.substr(6).is_valid_int():
			shots = int(a.substr(6))
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		_table()
		print(NAME + " FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _end() -> void:
	_table()
	print(NAME + (" PASSED" if fails == 0 else " FAILED"))
	quit(0 if fails == 0 else 1)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		_keep()
		await physics_frame


func _keep() -> void:
	if p != null and is_instance_valid(p):
		p.health = p.max_health
	if duel != null and duel.phase == DuelMode.Phase.FIGHT:
		duel.phase_t = minf(duel.phase_t, 10.0)
	if duel != null and duel.npc != null and is_instance_valid(duel.npc):
		duel.npc.held = true


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	_expect(p != null and duel != null, "the duel and its player")
	if p == null or duel == null:
		return _end()
	p.no_death = true
	for i in int((Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0) * Engine.physics_ticks_per_second):
		await physics_frame
	if duel.npc != null:
		duel.npc.held = true
		duel.npc.global_position = duel.arena.center() + Vector3(0.0, 0.0, 60.0)
	mid = duel.arena.center()
	mid.y = SLAB_Y
	_slab()
	# the player parked off the slab, out of every bot's sight
	p.global_position = mid + Vector3(0.0, 40.0, 120.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	for pr: String in presets:
		beats[pr] = {}
		for g: String in Bending.ELEMENTS:
			for s: String in Bending.ELEMENTS:
				if whole or pr == "normal" or s == g:
					await _pairing(s, g, pr)
	_gates()
	_end()


func _slab() -> void:
	var sb := StaticBody3D.new()
	sb.name = "MatrixSlab"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SLAB.x, 1.0, SLAB.y)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(mid.x, SLAB_Y - 0.5, mid.z)


func edge_m(pos: Vector3, dir: Vector3) -> float:
	var hx := SLAB.x * 0.5
	var hz := SLAB.y * 0.5
	var lx := pos.x - mid.x
	var lz := pos.z - mid.z
	var t := INF
	if absf(dir.x) > 1e-5:
		t = minf(t, ((hx if dir.x > 0.0 else -hx) - lx) / dir.x)
	if absf(dir.z) > 1e-5:
		t = minf(t, ((hz if dir.z > 0.0 else -hz) - lz) / dir.z)
	return maxf(t, 0.0)


func bound(pos: Vector3) -> Vector3:
	var hx := SLAB.x * 0.5 - 1.0
	var hz := SLAB.y * 0.5 - 1.0
	return Vector3(clampf(pos.x, mid.x - hx, mid.x + hx), pos.y, clampf(pos.z, mid.z - hz, mid.z + hz))


func _bot(el: String, at: Vector3, face: Vector3, preset: String, faction: String) -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, faction, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": preset, "seed": _seed, "y": SLAB_Y, "face": face})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	var b := f.brain.bending
	if b != null:
		b.bounds_fn = bound
		b.edge_fn = edge_m
	return f


func _free(f: NpcFighter) -> void:
	if f != null and is_instance_valid(f) and f.squad != null and is_instance_valid(f.squad):
		f.squad.get_parent().remove_child(f.squad)
		f.squad.queue_free()


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, NpcBending.FLIGHT_GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


func _place(f: NpcFighter, at: Vector3, face: Vector3) -> void:
	f.global_position = at
	f.velocity = Vector3.ZERO
	var k := BendKnock.peek(f)
	if k != null:
		k.reset()
	f.health = f.health_max
	f.face_point(face)


## Shooter element `s`'s shots into guard element `g`'s guard bot, both of preset `pr`.
func _pairing(s: String, g: String, pr: String) -> void:
	_clear()
	await _secs(0.2)
	var at_g := mid + Vector3(ELEMENT_M * 0.5, 0.0, 0.0)
	var at_s := mid - Vector3(ELEMENT_M * 0.5, 0.0, 0.0)
	var gb := _bot(g, at_g, at_s, pr, FACTION_B)
	var sb := _bot(s, at_s, at_g, pr, FACTION_A)
	if gb == null or sb == null:
		_expect(false, "%s > %s (%s): both bots" % [s, g, pr])
		return
	await _secs(0.1)
	gb.brain.told(sb, sb.global_position)
	sb.brain.told(gb, gb.global_position)
	var G := gb.brain.bending
	var S := sb.brain.bending
	var hits := [0]
	var hurt := [0.0]
	var hp := [gb.health]
	var list: Array = SHOTS[s]
	for i in (shots if s == g else maxi(shots / 2, 2)):          # (the cross pairings: what passes, a few shots)
		_clear()
		_place(gb, at_g, at_s)
		_place(sb, at_s, at_g)
		G._grace_until = INF                     # (each to its part: neither begins an attack of its own)
		S._grace_until = INF
		G._rest_until = 0.0
		var key := String(list[i % list.size()])
		S._cool.erase(key)
		S._next[key] = 0.0
		S._rest_until = 0.0
		hp[0] = gb.health
		for f in int(SHOT_S * Engine.physics_ticks_per_second):
			_keep()
			if is_instance_valid(gb):
				if gb.health < hp[0] - 0.01:
					hurt[0] += hp[0] - gb.health
					hits[0] += 1
				hp[0] = gb.health
				gb.global_position.x = clampf(gb.global_position.x, mid.x - SLAB.x * 0.5 + 1.0, mid.x + SLAB.x * 0.5 - 1.0)
			await physics_frame
	var begun := 0
	for k: String in G.reactions_by:
		begun += int(G.reactions_by[k])
	var row := "%s > %s %s: shots %d (%s), guards %d (perfect %d, late %d, whiff %d), took %d, struck %d (%.0f), catches %d (clean %d), returns %d, jumps %d" % [
			s, g, pr, S.casts, ",".join(PackedStringArray(S.casts_by.keys())), begun, G.perfects, G.lates, G.whiffs, G.answered, hits[0],
			hurt[0], G.catches, G.clean_catches, G.returns, G.floor_jumped]
	print("METRIC guard_matrix " + row)
	rows.append(row)
	var bt: Array = beats[pr].get(g, [0, 0, 0, 0, 0])
	beats[pr][g] = [int(bt[0]) + G.perfects, int(bt[1]) + G.lates, int(bt[2]) + begun, int(bt[3]) + G.catches, int(bt[4]) + G.returns]
	if s == g:
		# (its own element's shots are what its guard is for: gated over the presets, _gates)
		mirrors[pr + "/" + g] = [begun, G.answered, G.catches, G.returns]
	_free(gb)
	_free(sb)
	await _secs(0.1)


func _gates() -> void:
	# (each element's guard begun against its own element's shots and taking them, normal and hard together: a few shots a
	# pairing, so one pairing's rolls (react_chance, the volley) may let all of them through)
	for g: String in Bending.ELEMENTS:
		var m := [0, 0, 0, 0]
		for pr: String in ["normal", "hard"]:
			var e: Array = mirrors.get(pr + "/" + g, [0, 0, 0, 0])
			for i in 4:
				m[i] += int(e[i])
		if mirrors.has("normal/" + g) or mirrors.has("hard/" + g):
			_expect(m[0] >= 2 and m[1] >= 1, "%s's guard is begun against its own element's shots and takes them (normal and hard: %d begun, %d taken)"
					% [g, m[0], m[1]])
			if g == "earth":
				_expect(m[2] >= 1 and m[3] >= 1, "earth catches stones and sends them back by its guard again (%d caught, %d returned)" % [m[2], m[3]])
	if beats.has("easy"):
		var eb := 0
		for g: String in beats["easy"]:
			eb += int(beats["easy"][g][2])
		_expect(eb >= 2, "easy bots guard some of their own element's shots too (%d begun)" % eb)
	if beats.has("easy") and beats.has("hard"):
		var share := func(pr: String) -> float:
			var pf := 0
			var lt := 0
			for g: String in beats[pr]:
				pf += int(beats[pr][g][0])
				lt += int(beats[pr][g][1])
			return float(pf) / maxf(float(pf + lt), 1.0)
		_expect(float(share.call("hard")) > float(share.call("easy")), "a hard bot's guards land on the beat more than an easy one's (%.2f vs %.2f)"
				% [share.call("hard"), share.call("easy")])


func _table() -> void:
	print("  the guard matrix (shooter > guard):")
	for r in rows:
		print("    " + r)
	for pr: String in beats:
		for g: String in beats[pr]:
			var b: Array = beats[pr][g]
			print("METRIC guard_beats preset=%s guard=%s perfect=%d late=%d begun=%d catches=%d returns=%d" % [pr, g, b[0], b[1], b[2], b[3], b[4]])
