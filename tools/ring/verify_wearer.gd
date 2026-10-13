extends SceneTree
## VERIFY (read-only reviewer probe, loadouts B1+B2): each of the plan's eight number-only nodes, worn by ONE body and not the other,
## in both seatings (the player wearing and the bot not, then the bot wearing and the player not), through the game's own casts.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/verify_wearer.gd
## The oracle is data/sway/skill_tree.json changes[] read here on its own (path, from, to), never BendLoadout. Per change:
##   spec:<move>/<mode>.<keys>   the number in the spec the cast engine recorded for a real BendEffects.apply (BendEffects.last_of)
##   move:<move>.mode_lock_s.<m> / move:<move>.lock_s   the lock a bot reads (NpcBending.lock_for with its body) and the player's
##                               own (SwayCaster._lock_time), as a ratio to the Classic lock
##   move:earth_wall.wall.*      the wall a real BendCast.cast(earth_wall) (or BendEffects.apply water_shield/ice_wall) raises
## and what the effect itself does (bolt speed and radius, Gust width, Burrow and Step velocity, under time, wall hits and width).
## Ends "VERIFY WEARER PASSED (n checks)" / FAILED; exit 0 only on a pass.

const NAME := "VERIFY WEARER"
const NODES := ["air.slice.keen", "air.ball.dense", "air.gust.full_sail", "earth.burrow.lie_low", "water.skate.wet_trail", "fire.step.quick",
		"earth.wall.thick", "water.wall.thick_ice"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var _tree: Dictionary = {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _initialize() -> void:
	seed(1750)
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	print("%s %s (%d checks, %d failed)" % [NAME, "PASSED" if fails.is_empty() and checks > 0 else "FAILED", checks, fails.size()])
	quit(0 if fails.is_empty() and checks > 0 else 1)


func _walk(o: Variant) -> void:
	if o is Dictionary:
		if (o as Dictionary).get("id") is String and (o as Dictionary).get("kind") is String and (o as Dictionary).has("ring_legal"):
			_tree[String((o as Dictionary).id)] = o
		for k: Variant in (o as Dictionary):
			_walk((o as Dictionary)[k])
	elif o is Array:
		for v: Variant in (o as Array):
			_walk(v)


func _dig(d: Variant, keys: Array) -> Variant:
	var cur: Variant = d
	for k: Variant in keys:
		if not (cur is Dictionary) or not (cur as Dictionary).has(String(k)):
			return null
		cur = (cur as Dictionary)[String(k)]
	return cur


func _near(a: Variant, b: Variant, tol := 0.0005) -> bool:
	return a != null and b != null and absf(float(a) - float(b)) <= tol


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _newest_bolt(body: Node) -> BendBolt:
	var found: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and is_instance_valid(b) and b.caster == body and not b.is_queued_for_deletion():
			found = b
	return found


func _sweep(body: Node) -> void:
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and is_instance_valid(b) and b.caster == body:
			b.queue_free()


func _newest_ice(body: Node) -> FormRaised:
	var found: FormRaised = null
	for n in get_nodes_in_group(FormRaised.GROUP):
		var r := n as FormRaised
		if r != null and is_instance_valid(r) and r.has_meta(&"bend_ice") and int(r.get_meta(&"bend_by", 0)) == body.get_instance_id() and not r.is_queued_for_deletion():
			found = r
	return found


func _run() -> void:
	_walk(JSON.parse_string(FileAccess.get_file_as_string("res://data/sway/skill_tree.json")))
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if mode == null or player == null or mode.foe == null:
		_expect(false, "the ring with a player and a bot")
		return _end()
	await _ticks(30)
	var bot: NpcFighter = mode.foe
	var roles: Array = [["player", player, BendCaster.of(player)], ["bot", bot, BendCaster.of(bot)]]
	var sc := SwayCaster.of(player)
	var bend: NpcBending = bot.brain.bending if bot.brain != null else null
	_expect(roles[0][2] != null and roles[1][2] != null and sc != null and bend != null, "both bodies have a caster; the player a SwayCaster and the bot a bending mind")
	if roles[0][2] == null or roles[1][2] == null or sc == null or bend == null:
		return _end()
	# the bot is held still and the player parked from the rules is not needed: the casts are made directly
	bot.held = true
	var snap := JSON.stringify(SwayMoves.data())
	var all_on := {}
	for id: String in NODES:
		all_on[id] = true
	# the shipped switches first (no override): which of the eight a body wears
	BendLoadout.config_override = {}
	# (of the eight: the live list holds many more nodes since, the talents of 2026-10-11)
	var shipped: Array = BendLoadout.live_ids().filter(func(x: String) -> bool: return x in NODES)
	print("VWEARER shipped live: %s" % [shipped])
	var cfg := JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/loadout_apply.json")) as Dictionary
	var want_on: Array = []
	for id: String in NODES:
		if bool((cfg.nodes as Dictionary).get(id, false)) and id in (cfg.live as Array):
			want_on.append(id)
	var a1 := shipped.duplicate()
	a1.sort()
	var a2 := want_on.duplicate()
	a2.sort()
	_expect(a1 == a2, "BendLoadout.live_ids() == the file's live list less switched-off nodes (%s)" % [shipped])
	# (the eight as shipped follow the file's switches: Thick Wall went on with earth's talents, 2026-10-11; Wet Trail stays out:
	# nothing makes the Skate's puddles)
	_expect("earth.burrow.lie_low" in shipped and not "water.skate.wet_trail" in shipped,
			"live as shipped: the file's switches (%d of the eight), Lie Low among them, never Wet Trail" % shipped.size())

	# ---- each node: wearer in seat 0, then in seat 1
	BendLoadout.config_override = {"nodes": all_on}
	for id: String in NODES:
		var n: Dictionary = _tree.get(id, {})
		_expect(not n.is_empty(), "%s is in the skill tree" % id)
		if n.is_empty():
			continue
		var el := id.get_slice(".", 0)
		var refused := id == "water.skate.wet_trail"
		for wi in 2:
			var wearer: Array = roles[wi]
			BendLoadout.wear(wearer[1] as Node, [id], "", el)
			var worn_ok := (BendLoadout.picks_of(wearer[1] as Node) == [id]) if not refused else BendLoadout.picks_of(wearer[1] as Node).is_empty()
			_expect(worn_ok and BendLoadout.overlay_of(roles[1 - wi][1] as Node).is_empty(),
					"%s: worn by the %s%s, nothing on the %s" % [id, wearer[0], "" if not refused else " (refused: nothing is worn)", roles[1 - wi][0]])
			for ri in 2:
				var who: Array = roles[ri]
				var is_wearer := ri == wi and not refused
				var tag := "%s | %s casts, %s wears" % [id, who[0], wearer[0]]
				for c: Dictionary in n.changes:
					var path := String(c.path)
					var want := float(c.to) if is_wearer else float(c.from)
					var rest := path.get_slice(":", 1)
					if path.begins_with("spec:"):
						var mv := rest.get_slice("/", 0)
						var keys: Array = Array(rest.substr(mv.length() + 1).split("."))
						var md := String(keys[0])
						var spec: Dictionary = (SwayMoves.move(mv).bend as Dictionary)[md]
						var caster := who[2] as BendCaster
						var dirs: Array = [Vector2.ZERO]
						if mv == "footwork":
							dirs = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]
						for hv: Vector2 in dirs:
							if mv == "footwork":
								if who[0] == "player":
									(caster as PlayerBendCaster).held_override = hv
								else:
									(caster as BodyBendCaster).dash_dir = hv
							BendEffects.apply(caster, mv, md, spec)
							var rec := BendEffects.last_of(caster)
							var got: Variant = _dig(rec.get("spec", {}), keys.slice(1))
							var how := String(rec.get("how", ""))
							# Step: the direction picks which carry; the node names one of fwd / back / side
							var relevant := true
							if mv == "footwork":
								relevant = (keys[1] == "fwd" and hv == Vector2(0, 1)) or (keys[1] == "back" and hv == Vector2(0, -1)) or (keys[1] == "side" and hv == Vector2(1, 0))
								if relevant:
									var v: Vector3 = rec.get("v", Vector3.ZERO)
									_expect(_near(Vector2(v.x, v.z).length(), want, 0.01), "%s: the real Step (%s held, how=%s) carries %.2f m/s (want %.2f)" % [tag, keys[1], how, Vector2(v.x, v.z).length(), want])
							if relevant:
								_expect(_near(got, want), "%s: recorded %s = %s (want %s)" % [tag, path, str(got), want])
							if mv == "footwork":
								if who[0] == "player":
									(caster as PlayerBendCaster).held_override = null
								else:
									(caster as BodyBendCaster).dash_dir = Vector2.ZERO
						# the effect itself
						if mv == "air_blast":
							_sweep(who[1] as Node)
							BendEffects.apply(caster, mv, md, spec)
							var b := _newest_bolt(who[1] as Node)
							if keys[1] == "mps":
								_expect(b != null and _near(b.velocity.length(), want, 0.01), "%s: the bolt flies %.1f m/s (%s)" % [tag, want, "%.2f" % b.velocity.length() if b != null else "none"])
							elif keys[1] == "radius_m":
								_expect(b != null and _near(b.radius, want), "%s: the bolt's radius is %.2f m (%s)" % [tag, want, "%.3f" % b.radius if b != null else "none"])
							if b != null:
								# the blow's cost to its victim is the move's own data lock, never the wearer's
								var base_lock := float((SwayMoves.move(mv).get("mode_lock_s", {}) as Dictionary).get(md, SwayMoves.move(mv).get("lock_s", -1.0)))
								_expect(_near(b.lock_s, base_lock, 0.001), "%s: what the %s costs whom it hits is %.2f s whoever casts it (%.2f)" % [tag, md, base_lock, b.lock_s])
								_expect(_near(b.damage, float(spec.get("damage", b.damage))), "%s: damage is the spec's (%s)" % [tag, str(b.damage)])
							_sweep(who[1] as Node)
						elif mv == "air_gust" and keys[1] == "grow":
							var g := who[2] as BendCaster
							g.grown = true
							_sweep(who[1] as Node)
							BendEffects.apply(g, mv, md, spec)
							var gb := _newest_bolt(who[1] as Node)
							_expect(gb != null and _near(gb.radius * 2.0, want, 0.002), "%s: the grown Gust is %.2f m wide (%s)" % [tag, want, "%.2f" % (gb.radius * 2.0) if gb != null else "none"])
							g.grown = false
							_sweep(who[1] as Node)
							BendEffects.apply(g, mv, md, spec)
							var gp := _newest_bolt(who[1] as Node)
							_expect(gp != null and _near(gp.radius * 2.0, 2.0, 0.002), "%s: the plain Gust is 2.0 m wide whoever casts it (%s)" % [tag, "%.2f" % (gp.radius * 2.0) if gp != null else "none"])
							_sweep(who[1] as Node)
						elif mv == "earth_skate" and keys[1] == "under_s":
							BendEffects.apply(caster, mv, md, spec)
							var under := BendStatus.until(who[1] as Node, &"bend_under_until")
							_expect(_near(under, want, 0.05), "%s: stones pass over for %.2f s (%.3f)" % [tag, want, under])
						elif mv == "earth_skate" and keys[1] == "fwd_mps":
							BendEffects.apply(caster, mv, md, spec)
							var rv: Vector3 = BendEffects.last_of(caster).get("v", Vector3.ZERO)
							_expect(_near(Vector2(rv.x, rv.z).length(), want, 0.01), "%s: Burrow travels %.1f m/s (%.2f)" % [tag, want, Vector2(rv.x, rv.z).length()])
						elif mv == "flow" and keys[1] == "fwd_mps":
							BendEffects.apply(caster, mv, md, spec)
							var fv: Vector3 = BendEffects.last_of(caster).get("v", Vector3.ZERO)
							_expect(_near(Vector2(fv.x, fv.z).length(), float(c.from), 0.01), "%s: Skate travels %.1f m/s, the node being refused (%.2f)" % [tag, float(c.from), Vector2(fv.x, fv.z).length()])
					elif rest.contains(".mode_lock_s.") or rest.ends_with(".lock_s"):
						var mv2 := rest.get_slice(".", 0)
						var md2 := String(n.mode) if rest.ends_with(".lock_s") else rest.get_slice(".", 2)
						var classic := NpcBending.lock_for(mv2, md2, "normal", 0.0)
						var got_l := NpcBending.lock_for(mv2, md2, "normal", 0.0, who[1] as Node)
						var ratio := float(c.to) / float(c.from) if is_wearer else 1.0
						_expect(_near(got_l, classic * ratio, 0.0001), "%s: a bot's lock for %s/%s is %.4f s (classic %.4f x %.3f)" % [tag, mv2, md2, got_l, classic, ratio])
						if who[0] == "player":
							sc.modes[mv2] = md2
							BendLoadout.clear_numbers(player)
							var cl := sc._lock_time(mv2, null, 0.0, 0.0)
							if wearer[0] == "player":
								BendLoadout.wear(player, [id], "", el)
							var pl := sc._lock_time(mv2, null, 0.0, 0.0)
							_expect(cl > 0.0 and _near(pl / cl, ratio, 0.001), "%s: the player's own lock (SwayCaster._lock_time) is %.3f of Classic (%.4f vs %.4f)" % [tag, ratio, pl, cl])
						if rest.ends_with(".lock_s"):
							for other_md: String in ["hop", "back_flip", "ignite_step"]:
								var cl2 := NpcBending.lock_for(mv2, other_md, "normal", 0.0)
								_expect(_near(NpcBending.lock_for(mv2, other_md, "normal", 0.0, who[1] as Node), cl2, 0.0001), "%s: footwork's %s keeps its lock (%.3f)" % [tag, other_md, cl2])
						# what a hit costs its victim is the data's, wearer or not
						_expect(_near(BendEffects.lock_of(mv2, md2), float((SwayMoves.move(mv2).get("mode_lock_s", {}) as Dictionary).get(md2, SwayMoves.move(mv2).get("lock_s", -1.0)))),
								"%s: BendEffects.lock_of (a hit's cost) is the data's" % tag)
					elif rest.begins_with("earth_wall.wall."):
						var sub := Array(rest.split(".")).slice(2)
						var key := String(sub[sub.size() - 1])
						var body := who[1] as Node3D
						if el == "earth":
							var at := body.global_position + Vector3(0, 0, 4.0)
							BendCast.cast(who[2], "earth_wall", "wall", null, at)
							var made: Variant = BendEffects.last_of(who[2]).get("made")
							var wall := made as FormRaised
							var gotw: Variant = null
							if wall != null and is_instance_valid(wall):
								gotw = wall.hits_max if key == "hits" else wall.size.x if key == "width_m" else wall.rise_s if key == "rise_s" else null
							_expect(wall != null and _near(gotw, want, 0.001), "%s: the real Earth Wall's %s is %s (%s)" % [tag, key, want, str(gotw)])
							if wall != null and is_instance_valid(wall):
								wall.queue_free()
							# a bot's own fallback builder reads the same numbers
							if who[0] == "bot":
								var fw: Variant = bend._wall(player)
								var lw := bend.last_wall
								var gotb: Variant = null
								if lw != null and is_instance_valid(lw):
									gotb = lw.hits_max if key == "hits" else lw.size.x if key == "width_m" else lw.rise_s
								_expect(fw != null and _near(gotb, want, 0.001), "%s: the bot's own wall (NpcBending._wall) %s is %s (%s)" % [tag, key, want, str(gotb)])
								if lw != null and is_instance_valid(lw):
									lw.queue_free()
							# an earth wall raised from the other matters keeps their own hits
							if key == "hits":
								var wd: Dictionary = SwayMoves.move("earth_wall").wall
								var fm := preload("res://scripts/sway/form_matter.gd")
								for matter: String in ["stone", "mud", "snow", "wood"]:
									var wnum := BendLoadout.wall_numbers(who[1] as Node, "wall", wd, matter)
									var mat_hits := int((fm.entry("earth_wall", matter) as Dictionary).get("hits", wd.hits))
									_expect(int(wnum.hits) == mat_hits, "%s: a %s wall keeps its matter's %d hits (%d)" % [tag, matter, mat_hits, int(wnum.hits)])
						else:
							# water's Thick Ice: the Ice Wall the real cast raises; an earth wall of this body keeps today's numbers
							var wdi: Dictionary = SwayMoves.move("water_shield").bend.ice_wall
							BendEffects.apply(who[2], "water_shield", "ice_wall", wdi)
							var ice := _newest_ice(who[1] as Node)
							var goti: Variant = null
							if ice != null:
								goti = ice.hits_max if key == "hits" else ice.rise_s if key == "rise_s" else null
							_expect(ice != null and _near(goti, want, 0.001), "%s: the real Ice Wall's %s is %s (%s)" % [tag, key, want, str(goti)])
							if ice != null:
								ice.queue_free()
				# crossing: this body's wall numbers when the node is not its element's
				if n.get("extends_move") == "earth_wall" and el == "earth":
					var wi2 := BendEffects._wall(who[1] as Node3D, Transform3D(Basis.IDENTITY, (who[1] as Node3D).global_position + Vector3(0, 0, 7.0)), "snow", -1.0, -1.0, true)
					_expect(wi2 != null and wi2.hits_max == 3 and _near(wi2.rise_s, 0.7), "%s: Thick Wall does not touch this body's Ice Wall (%d hits, rise %.2f)" % [tag, wi2.hits_max if wi2 != null else -1, wi2.rise_s if wi2 != null else -1.0])
					if wi2 != null:
						wi2.queue_free()
				if id == "water.wall.thick_ice":
					var at2 := (who[1] as Node3D).global_position + Vector3(0, 0, 4.0)
					BendCast.cast(who[2], "earth_wall", "wall", null, at2)
					var ew := BendEffects.last_of(who[2]).get("made") as FormRaised
					_expect(ew != null and ew.hits_max == 4 and _near(ew.size.x, 3.0), "%s: Thick Ice does not touch this body's Earth Wall (%d hits, %.1f m)" % [tag, ew.hits_max if ew != null else -1, ew.size.x if ew != null else -1.0])
					if ew != null and is_instance_valid(ew):
						ew.queue_free()
			BendLoadout.clear(wearer[1] as Node)
			await _ticks(2)
		_expect(BendLoadout.overlay_of(player).is_empty() and BendLoadout.overlay_of(bot).is_empty(), "%s: both bodies Classic again" % id)
	_expect(JSON.stringify(SwayMoves.data()) == snap, "moves.json as the process read it: nothing worn left a trace in the shared data")
	_end()
