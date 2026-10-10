extends RefCounted
## Classic's fingerprint (nothing worn): every number and timing the live loadouts touch, read through the game's own code in the
## ring scene, so the same fingerprint can be taken from the code before the loadouts (c0a631a0^) and from today's and compared.
## It names nothing the loadouts added (no BendLoadout, no style, no 4-argument pick), so it runs on both.
##   locks     the player's SwayCaster._lock_time for every move and mode (0, 3/4 and the whole of its reach), a bot's
##             NpcBending.lock_for (easy, normal, hard; near and far), NpcBending.range_of, BendEffects.lock_of (what a hit costs)
##   picks     BendPoses.pick(move, mode, element) for every element, move and mode (the cast pose and its times)
##   timeline  SwayPose driven by hand at 60 Hz for every element's own move and mode, three lock lengths (let go in the wind-up,
##             just after it, long after it) and the other hand: the clip, the strike frame, the end frame, the rooted frames, the
##             effect's wait, and a hash of every frame's sampled clip time and weight
##   effects   real BendEffects.apply casts by the player: each bolt and wave (speed, radius, width, damage, knock, lift, lock cost),
##             each dash (its velocity; the Step held forward, back and to the side), the Earth Wall on earth, stone, mud and snow,
##             the Ice Wall (hits, size, rise)
## Used by tests/ring/test_loadout_classic.gd (the pinned comparison) and tools/ring/loadout_classic_print_run.gd (writes one).

const DT := 1.0 / 60.0
const PRESETS := ["easy", "normal", "hard"]
const ELEMENTS := ["earth", "water", "fire", "air"]

var player: FrontierPlayer
var sc: SwayCaster
var pose: SwayPose


static func r4(v: float) -> float:
	return snappedf(v, 0.0001)


func collect(tree: SceneTree, p: FrontierPlayer) -> Dictionary:
	player = p
	sc = SwayCaster.of(player)
	pose = sc.pose if sc != null else null
	for i in 60:                                # (on the deck: an airborne caster reads the air locks)
		if player.is_on_floor() and not sc.airborne():
			break
		await tree.physics_frame
	var out := {"locks": _locks(), "picks": _picks()}
	out["timeline"] = _timeline()
	out["effects"] = await effects_for(tree, player)
	return out


# ---------------------------------------------------------------- the moves and their modes
func _moves() -> Array:
	var ms: Array = (SwayMoves.data().get("moves", {}) as Dictionary).keys()
	ms.sort()
	return ms


func _modes(m: String) -> Array:
	var d := SwayMoves.move(m)
	var out: Array = []
	for v: Variant in (d.get("modes", []) as Array):
		if not String(v) in out:
			out.append(String(v))
	var b: Variant = d.get("bend", {})
	if b is Dictionary:
		for k: String in b:
			if not k in out:
				out.append(k)
	if out.is_empty():
		out.append("")
	out.sort()
	return out


func _pin(m: String, md: String) -> void:
	sc._pin_id = m
	sc._pin_mode = md
	sc._pinning = true


func _unpin() -> void:
	sc._pinning = false
	sc._pin_id = ""
	sc._pin_mode = ""


# ---------------------------------------------------------------- locks, ranges, costs
func _locks() -> Dictionary:
	var out := {}
	for m: String in _moves():
		for md: String in _modes(m):
			var key := "%s/%s" % [m, md]
			var rec := {}
			_pin(m, md)
			var r := sc.range_of(m, null)
			rec["mode_seen"] = sc.mode_of(m)
			rec["range"] = r4(r)
			rec["player"] = [r4(sc._lock_time(m, null, 0.0, r)), r4(sc._lock_time(m, null, r * 0.75, r)), r4(sc._lock_time(m, null, r, r))]
			_unpin()
			var nr := NpcBending.range_of(m, md)
			rec["npc_range"] = r4(nr)
			var nl: Array = []
			for pr: String in PRESETS:
				nl.append(r4(NpcBending.lock_for(m, md, pr, 0.0)))
				nl.append(r4(NpcBending.lock_for(m, md, pr, nr)))
			rec["npc"] = nl
			rec["cost"] = r4(BendEffects.lock_of(m, md))
			out[key] = rec
	return out


# ---------------------------------------------------------------- picks
func _picks() -> Dictionary:
	var out := {}
	for el: String in ELEMENTS:
		for m: String in _moves():
			for md: String in _modes(m):
				var pk := BendPoses.pick(m, md, el)
				if not pk.is_empty():
					out["%s:%s/%s" % [el, m, md]] = JSON.stringify(pk, "", true)
	return out


# ---------------------------------------------------------------- the cast timeline
func _timeline() -> Dictionary:
	var out := {}
	if pose == null:
		return out
	var keep_el := BendPoses.element_of(player)
	for el: String in ELEMENTS:
		Bending.of(player).element = el
		for m: String in _moves():
			if String(SwayMoves.move(m).get("element", "")) != el or not SwayCaster.is_spell(m):
				continue
			for md: String in _modes(m):
				var pk := BendPoses.pick(m, md, el)
				if pk.is_empty():
					continue
				var hold := float(pk.get("hold_s", 0.3))
				for extra: float in [0.03, hold + 0.15, hold + 0.7]:
					out["%s:%s/%s@%.3f" % [el, m, md, extra]] = _drive(m, md, extra, 0)
				if pk.has("alt"):
					out["%s:%s/%s@alt" % [el, m, md]] = _drive(m, md, hold + 0.15, 1)
	Bending.of(player).element = keep_el
	return out


var _struck_at := -1
var _frame := 0


func _on_struck(_m: String) -> void:
	if _struck_at < 0:
		_struck_at = _frame


## One cast of (m, md) driven by hand: pressed for `press_s`, then let go and run to its end (`again` casts of it first: the
## other hand within the combo window). `at_strike`: also the clip time showing on the strike frame (t_at_strike).
func _drive(m: String, md: String, press_s: float, again: int, at_strike := false) -> Dictionary:
	_pin(m, md)
	var out := {}
	pose._clock += 10.0                         # (out of the last drive's combo window)
	pose._last_key = ""
	for rep in again + 1:
		pose._stop()
		pose.set_process(false)
		_struck_at = -1
		_frame = 0
		pose._on_started(m, null)
		for i in maxi(int(ceil(press_s / DT)), 1):
			pose._process(DT)
		var wait := pose.strike_wait()
		pose.struck.connect(_on_struck, CONNECT_ONE_SHOT)
		pose._on_cast(m, null)
		if rep < again:
			for j in 6:
				pose._process(DT)
			if pose.struck.is_connected(_on_struck):
				pose.struck.disconnect(_on_struck)
			continue
		out["clip"] = pose.anim_name
		out["wait"] = r4(wait)
		var trace := PackedStringArray()
		var roots := 0
		var guard := 0
		while pose.phase != "" and guard < 900:
			_frame += 1
			guard += 1
			pose._process(DT)
			if pose.rooting():
				roots += 1
			if at_strike and _frame == _struck_at:
				out["t_at_strike"] = _layer_t()
			trace.append("%s:%.4f:%.3f" % [pose.phase, _layer_t(), pose.weight])
		out["struck"] = _struck_at
		out["end"] = _frame
		out["root"] = roots
		out["trace"] = "|".join(trace).sha256_text().substr(0, 16)
		if pose.struck.is_connected(_on_struck):
			pose.struck.disconnect(_on_struck)
	_unpin()
	return out


## The cast layer's clip time this frame (-1 none), through a blend from the last cast.
func _layer_t() -> float:
	var ls: Array = pose._cast_layers
	while not ls.is_empty():
		var l0: Dictionary = ls[0]
		if l0.has("time"):
			return float(l0.time)
		if l0.get("blend_to") is Array:
			ls = l0.blend_to
		else:
			break
	return -1.0


# ---------------------------------------------------------------- real casts
## The real casts of `body` (the player, or a bot: its own BendCaster; held keys only for the player). `only` limits them to
## those move/mode keys (empty: every one).
func effects_for(tree: SceneTree, body: Node3D, only: Array = []) -> Dictionary:
	var out := {}
	var bc := BendCaster.of(body)
	if bc == null:
		return out
	var pbc := bc as PlayerBendCaster
	var home := body.global_position
	var keep_el := BendPoses.element_of(body)
	for m: String in _moves():
		var d := SwayMoves.move(m)
		var b: Variant = d.get("bend", {})
		if not (b is Dictionary):
			continue
		for md: String in (b as Dictionary):
			var spec: Variant = (b as Dictionary)[md]
			if not (spec is Dictionary):
				continue
			var s := spec as Dictionary
			var dov := String(s.get("do", ""))
			if not dov in ["bolt", "wind_wave", "dash"] or int(s.get("count", 1)) > 1 or s.has("as"):
				continue
			if not only.is_empty() and not "%s/%s" % [m, md] in only:
				continue
			Bending.of(body).element = String(d.get("element", "air"))
			var helds: Array = [null]
			if dov == "dash" and String(s.get("dir", "")) == "held" and pbc != null:
				helds = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2.ZERO]
			for grown: bool in ([false, true] if s.get("grow") is Dictionary else [false]):
				for hv: Variant in helds:
					if pbc != null:
						pbc.held_override = hv
					body.global_position = home
					(body as CharacterBody3D).velocity = Vector3.ZERO
					bc.grown = grown
					var before := _bolts(tree, body)
					BendEffects.apply(bc, m, md, s)
					bc.grown = false
					var key := "%s/%s%s%s" % [m, md, "+grown" if grown else "", "" if hv == null else " held %s" % str(hv)]
					var rec := {}
					if dov == "dash":
						var v: Vector3 = BendEffects.last_of(bc).get("v", Vector3.ZERO)
						rec = {"v_flat": r4(Vector2(v.x, v.z).length()), "v_up": r4(v.y),
								"under": snappedf(BendStatus.until(body, &"bend_under_until"), 0.01)}
						for i in 40:
							await tree.physics_frame
						if body.has_meta(&"bend_under_until"):
							body.remove_meta(&"bend_under_until")
					else:
						for nb: BendBolt in _bolts(tree, body):
							if nb in before:
								continue
							rec = {"mps": r4(nb.velocity.length()), "radius": r4(nb.radius), "width": r4(nb.width_m), "height": r4(nb.height_m),
									"damage": r4(nb.damage), "knock": r4(nb.knock_mps), "up": r4(nb.up_mps), "range": r4(nb.range_m),
									"lock_s": r4(nb.lock_s), "gravity": r4(nb.gravity)}
							nb.queue_free()
					out[key] = rec
	if pbc != null:
		pbc.held_override = null
	body.global_position = home
	(body as CharacterBody3D).velocity = Vector3.ZERO
	# the walls: Earth Wall on every matter, the Ice Wall
	if only.is_empty() or "earth_wall/wall" in only:
		Bending.of(body).element = "earth"
		var k := 0
		for matter: String in ["earth", "stone", "mud", "snow"]:
			var w := FormEffects.earth_wall(bc, body.global_position + Vector3(0, 0, 4.0 + float(k)), SwayMoves.move("earth_wall"), matter)
			out["earth_wall/%s" % matter] = _wall_rec(w)
			k += 1
	if only.is_empty() or "ice_wall" in only:
		Bending.of(body).element = "water"
		var iw := BendEffects.ice_wall(bc, Vector3.FORWARD)
		out["ice_wall"] = _wall_rec(iw)
	if keep_el != "":
		Bending.of(body).element = keep_el
	await tree.physics_frame
	return out


func _wall_rec(w: FormRaised) -> Dictionary:
	if w == null:
		return {"none": true}
	var rec := {"hits": w.hits_max, "w": r4(w.size.x), "h": r4(w.size.y), "t": r4(w.size.z), "rise": r4(w.rise_s), "matter": w.matter}
	w.queue_free()
	return rec


func _bolts(tree: SceneTree, by: Node) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and is_instance_valid(b) and b.caster == by and not b.is_queued_for_deletion():
			out.append(b)
	return out
