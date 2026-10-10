extends SceneTree
## VERIFY (read-only reviewer probe, loadouts B1+B2): the same seeded bots-vs-bots % ring match played under three switch states,
## traced cast by cast; Classic must be identical whatever the switch says when nothing is worn.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/verify_classic_match.gd -- element=water n=2 seed=7300 cfg=off|on|none tag=x
##   cfg=off   BendLoadout.config_override = {"enabled": false}   (the master switch off: no node, no style anywhere)
##   cfg=on    {"enabled": true} and nothing worn (the shipped state in a script run)
##   cfg=none  no override at all (the file as shipped)
## Mirror match (element on both sides, normal bots, 3 lives, one game per match), the soak's own spectate rig (tools/ring/loadout_soak.gd:
## the player parked, a bot of his element on his side). Each physics frame both bots' cast books are read; every change is an event,
## every 10th frame both bots' positions are, every ko is. Lines:
##   VMATCH game=<i> winner= game_s= lives_lost= events= casts= hash=<sha256 of the whole trace>
##   VMATCH RESULT tag= element= n= hash=<sha256 of all games>
## The whole trace is written to artifacts/ui_audit/verify/loadouts/trace_<tag>.txt.

const NAME := "VERIFY CLASSIC MATCH"
const GAME_LIMIT_S := 1500.0
const OUT_DIR := "res://artifacts/ui_audit/verify/loadouts/"
const STORE := "user://verify_loadout_store.json"

var el := "water"
var games := 2
var _seed := 7300
var _mate_seed := 9100
var cfg := "none"
var tag := "x"
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var mate: NpcFighter
var mate_squad: NpcSquad
var kos: Array = []
var trace := PackedStringArray()
var frame := 0
var _seen: Array = [{}, {}]
var game_hashes := PackedStringArray()
var persist_ok := 0
var persist_bad := 0


func _initialize() -> void:
	seed(1750)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var k := kv.get_slice("=", 0)
		var v := kv.get_slice("=", 1)
		match k:
			"element":
				el = v
			"n":
				games = maxi(int(v), 1)
			"seed":
				_seed = int(v)
				_mate_seed = int(v) + 1800
			"cfg":
				cfg = v
			"tag":
				tag = v
	match cfg:
		"store":
			# a worn fire slot (Boxing + Quick Step) in a store of its own, read by RingMode.restart as the game reads the player's
			DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
			AdvancementStore.path = STORE
			AdvancementStore.reload_file()
			var lo := AdvancementLoadout.new("fire", "boxing", ["fire.step.quick"])
			print("VMATCH fixture: valid='%s' save='%s'" % [lo.valid(), AdvancementStore.save_slot("fire", 0, lo, "Verify")])
			AdvancementStore.wear("fire", 0)
			BendLoadout.read_store_in_scripts = true
			BendLoadout.config_override = {}
		"off":
			BendLoadout.config_override = {"enabled": false}
		"on":
			BendLoadout.config_override = {"enabled": true}
		_:
			BendLoadout.config_override = {}
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = el
	MatchSetup.foes = [el]
	MatchSetup.difficulty = "normal"
	MatchSetup.round_s = 480.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.games_n = 1
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _finish(ok: bool) -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	BendLoadout.read_store_in_scripts = false
	if cfg == "store":
		AdvancementStore.path = AdvancementStore.PATH
		AdvancementStore.reload_file()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("%s %s" % [NAME, "DONE" if ok else "FAILED"])
	quit(0 if ok else 1)


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if mode == null or player == null:
		print("VMATCH ANOMALY no ring match")
		return _finish(false)
	mode.phase_changed.connect(_on_phase)
	mode.rules.ko.connect(_on_ko)
	if mode.phase == "COUNTDOWN":
		_spectate()
	var ok := true
	var all := PackedStringArray()
	for g in games:
		kos = []
		trace = PackedStringArray()
		_seen = [{}, {}]
		frame = 0
		if g > 0:
			mode._seed = _seed + g * 101
			mode._rng.seed = mode._seed
			mode._drop_foe()
			mode.restart()
			await physics_frame
		else:
			mode._seed = _seed
			mode._rng.seed = _seed
		var game_t := 0.0
		while mode.phase != "DONE" and game_t < GAME_LIMIT_S:
			await physics_frame
			frame += 1
			game_t += 1.0 / Engine.physics_ticks_per_second
			_sample()
			if player != null and is_instance_valid(player) and player.global_position.distance_to(Vector3(0.0, 60.0, 400.0)) > 1.0 and mode.phase != "DONE":
				_park()
		if mode.phase != "DONE":
			print("VMATCH ANOMALY game %d stalled" % g)
			ok = false
			break
		var casts := 0
		for s in 2:
			for k: String in _seen[s]:
				casts += int(_seen[s][k])
		trace.append("end winner=%d t=%.3f round=%d" % [mode.winner, game_t, mode.round])
		var h := "\n".join(trace).sha256_text()
		game_hashes.append(h)
		all.append_array(trace)
		print("VMATCH game=%d winner=%d game_s=%.2f lives_lost=%s events=%d casts=%d hash=%s" % [g, mode.winner, game_t, str(kos), trace.size(), casts, h.substr(0, 16)])
	var whole := "\n".join(all).sha256_text()
	print("VMATCH RESULT tag=%s cfg=%s element=%s n=%d hash=%s persist_ok=%d persist_bad=%d" % [tag, cfg, el, games, whole.substr(0, 32), persist_ok, persist_bad])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR) + "trace_%s.txt" % tag, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(all))
		f.close()
	_finish(ok)


func _sample() -> void:
	var bots: Array = [mate, mode.foe]
	for side in 2:
		var f: Variant = bots[side]
		if f == null or not is_instance_valid(f):
			continue
		var fb := f as NpcFighter
		if fb.brain == null or fb.brain.bending == null:
			continue
		var cb: Dictionary = fb.brain.bending.casts_by
		for k: String in cb:
			var now_n := int(cb[k])
			var was := int((_seen[side] as Dictionary).get(k, 0))
			if now_n != was:
				trace.append("f%d s%d cast %s n=%d" % [frame, side, k, now_n])
				(_seen[side] as Dictionary)[k] = now_n
		if frame % 10 == 0:
			var p := fb.global_position
			trace.append("f%d s%d pos %d,%d,%d" % [frame, side, roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)])


func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
			_seen = [{}, {}]
			if cfg == "store":
				var worn_ok := BendLoadout.picks_of(player) == ["fire.step.quick"] and BendLoadout.style_meta(player) == "boxing"
				var others_ok := true
				for b: Variant in [mate, mode.foe]:
					if b != null and is_instance_valid(b):
						others_ok = others_ok and BendLoadout.overlay_of(b as Node).is_empty() and BendLoadout.style_meta(b as Node) == ""
				if worn_ok and others_ok:
					persist_ok += 1
				else:
					persist_bad += 1
					print("VMATCH PERSIST BAD round=%d worn_ok=%s others_ok=%s picks=%s style=%s" % [mode.round, worn_ok, others_ok, BendLoadout.picks_of(player), BendLoadout.style_meta(player)])
		"FIGHT":
			_go_fight.call_deferred()
		"OVER", "DONE":
			if mate != null and is_instance_valid(mate):
				mate.held = true


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	var s := mode.side_of(b)
	kos.append(s)
	trace.append("f%d ko side=%d by_tag=%s" % [frame, s, _tag])


func _park() -> void:
	player.global_position = Vector3(0.0, 60.0, 400.0)
	player.velocity = Vector3.ZERO


func _spectate() -> void:
	var rules := mode.rules
	var pid := player.get_instance_id()
	if rules.state.has(pid):
		rules.state.erase(pid)
	(rules.sides[0] as Array).erase(player)
	player.is_dead = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_park()
	_drop_mate()
	var ring := mode.ring
	var xf := ring.spawn(mode.player_end, int(RingRules.num("bot_slot", 0.0)))
	_mate_seed += 13
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": mode.element,
			"weapon": "", "sidearm": "", "skill": mode.difficulty, "seed": _mate_seed, "y": ring.deck_y()}
	mate_squad = NpcSquad.spawn(lvl, RingMode.FACTIONS[0], 1, xf.origin, opts)
	mate = mate_squad.members[0] if mate_squad != null and not mate_squad.members.is_empty() else null
	if mate == null:
		return
	mate.flees = false
	mate.calm_s = INF
	mate.held = true
	mate.no_death = true
	mate.set(&"element", mode.element)
	Bending.of(mate).element = mode.element
	mode.join(mate, 0)
	var bend := mate.brain.bending
	if bend != null:
		bend.bounds_fn = rules.bounds_fn_for(mate)
		bend.edge_fn = rules.edge_along
	_seen[0] = {}


func _go_fight() -> void:
	if mate == null or not is_instance_valid(mate) or mode.foe == null or not is_instance_valid(mode.foe):
		return
	mate.held = false
	mate.brain.told(mode.foe, mode.foe.global_position)
	mode.foe.brain.told(mate, mate.global_position)


func _drop_mate() -> void:
	if mate_squad != null and is_instance_valid(mate_squad):
		if mate_squad.get_parent() != null:
			mate_squad.get_parent().remove_child(mate_squad)
		mate_squad.queue_free()
	mate_squad = null
	mate = null
