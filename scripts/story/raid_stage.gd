class_name RaidStage
extends Node
## The Night of the Raid, staged (docs/main_story.md 10.1, mission 9: "3 a.m., 12 Nov 1757. Shots and an orange sky. Get
## whoever you can to the ford; the fort across the river holds. At your own clearing you are taken ... Your roof is set
## alight"; 6.3 item 8; 15 item 1: "a scripted run, a staged capture, and fire and ruin v1 on your own house").
##
##   var raid := RaidStage.begin(level, homestead, [farm_a, farm_b], {"ford": ford})
##   raid.captured.connect(...)        the player taken (Captivity; raid.leclerc the captor)
##   raid.house_alight.connect(...)    a torch put to the house the player built
##   MarchStage.begin(level, route, {"leclerc": raid.leclerc, "guards": raid.guards()})     (mission 10, after it)
##
## THE NIGHT: the clock moved on to opts hour (3 a.m.; -1 leaves it where it is: the mission's wait_for has brought it there),
## the survival core with it as a night passes; already within the hour (or just before it) it is left.
## THE FARMS: each set alight (FireSpread.ignite_area over FARM_FIRE_R); a farm with nothing there to burn (the Flatts layer
## not built yet) gets a stand-in farmhouse (a burnable log house, RaidFarm_<i> under the level, opts stand_ins) set alight
## instead. Over each the orange glow of a farm burning in the night sky (one additive card each, fading in, flickering: no
## light of its own, FireSpread keeps the one fire light). At each, RAIDERS_PER_FARM real fighters (NpcSquad: troupes de la
## marine and Canadian militia by turns, tag "raiders") hold on its far side from the homestead: they fight the player if
## they see him. The shots: a first volley over the farms (the musket's report, as StoryDirector's raid_night), then one now
## and then while the run lasts (SHOT_EVERY).
## THE RUN: those warned in The Third Warning (the story's flag WARNED_FLAG, 0-3; opts neighbours over it) wait crouched in
## the fields on the near side of their farms (StoryWalker, group NEIGHBOURS, tag "neighbour"); the player within CALL_M,
## one gets up and follows him (walking, running to keep up); brought within FORD_R of the ford, they wade over to the far
## bank (the fort's side, which holds) and are safe: `neighbour_saved`, `saved`, the story's flag SAVED_FLAG. One left
## waiting when the player is taken is not saved.
## THE CAPTURE (opts capture: "home", the default: the player back in his clearing (within HOME_R of the homestead) with no
## one following him, once he has been out of it (HOME_LEFT_M; with no one left to fetch HOME_WAIT_S at home will do, and
## RUN_MAX_S on he is taken there whatever is left undone); "now"; "manual": capture_now()): a party waiting out in the
## dark (Toussaint Leclerc, a Canadian, and two marines: StoryActors, scripted, their muskets carried low; a marine with
## no musket carries the torch) comes up from behind him and stands round him; Leclerc
## looks at him and says LINE (StoryBark: in French, which the player cannot read yet); TAKE_S on, Captivity.begin(player,
## leclerc, opts captivity): `captured`, and the raiders leave the farms (withdraw(): their squads freed; a captive bound is
## no one's foe, and the march goes up the bank past the farms). One of the marines lights a torch and takes it to the house
## the player built (his
## built pieces within HOUSE_R of the homestead, the roof first), holds it there TORCH_HOLD_S and it catches
## (FireSpread.ignite): `house_alight(n)`, n the pieces set alight (0: no house). Struck by the player before he is taken,
## the party wakes and fights (`resisted`): the capture is off (the mission's fail rule decides).
## A LOAD IN THE MIDDLE (opts resume, StorySlice: the stage made again once the save is in): the clock left where the save had
## it (opts hour -1), the farms' fires as the save kept them (no stand-in where a farm's own pieces are), the neighbours as
## they were (the story's flag WHO_FLAG: one brought over the ford is saved and not made again, one following follows again
## from the player's side; SAVED_FLAG counted from them), out of the clearing already when opts left_home; the player taken
## already (Captivity active again): no raiders and no one waiting, the party round him at once, Leclerc his captor again
## and the torch to the house if it is not alight yet.
## Freeing the stage (a retry) frees what it made but the stand-in farmhouses (FireSpread keeps their ruins by path) and the
## party handed on (handed_on()).

signal began
signal neighbour_saved(who: StoryWalker)
## The party has come out of the dark and stands round the player.
signal party_came
signal captured
signal house_alight(pieces: int)
signal resisted(by: Node)

const GROUP := &"raid_stage"
const NEIGHBOURS := &"raid_neighbours"
const WARNED_FLAG := "tf.warned_count"
const SAVED_FLAG := "tf.raid_saved"
## How each neighbour is getting on, kept for a load in the middle of the raid: {"<i>": "following" | "over" (at the ford)}.
const WHO_FLAG := "tf.raid_who"
const HOUR := 3.0
const LINE := "Pas celui-là. Il a bâti une maison."
const LECLERC := "Toussaint Leclerc"
const FARM_FIRE_R := 14.0
const RAIDERS_PER_FARM := 2
const RAIDER_FACTIONS := ["french_marine", "canadian_militia"]
## The raiders hold this far past their farm (away from the homestead); the neighbours wait this far on the near side.
const RAIDERS_PAST_M := 8.0
const NEIGHBOURS_NEAR_M := 32.0
const NEIGHBOURS_MAX := 3
const CALL_M := 9.0
const FORD_R := 10.0
## The far bank: this far west of the river's middle at the ford; the saved go on toward the fort and are gone after SAFE_S.
const FAR_BANK_M := 24.0
const SAFE_S := 25.0
const HOME_R := 14.0
## The capture waits till the player has been out of his clearing (this far from the homestead) and come back; with no one
## left waiting to fetch, HOME_WAIT_S at home is enough; RUN_MAX_S on, at home, he is taken whatever is left undone.
const HOME_LEFT_M := 22.0
const HOME_WAIT_S := 40.0
const RUN_MAX_S := 240.0
const HOUSE_R := 18.0
## The party waits this far from the homestead (out of the dark), comes up from PARTY_FROM_M behind the player and stands
## SURROUND_M round him; it is on him at the latest PARTY_MAX_S after it set off.
const PARTY_WAIT_M := 55.0
const PARTY_FROM_M := 16.0
const SURROUND_M := 2.4
## A spot round the player (or out where the party comes from) is taken when a built piece is within SPOT_CLEAR_M or
## something solid stands there; the turns tried round him (rad).
const SPOT_CLEAR_M := 1.4
const SPOT_TURNS := [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2]
const PARTY_MAX_S := 14.0
const TAKE_S := 1.8
const TORCH_HOLD_S := 2.5
const TORCH_MAX_S := 25.0
const SHOT_EVERY := Vector2(2.5, 7.0)
const GLOW_SIZE := Vector2(90.0, 42.0)
const GLOW_COLOR := Color(1.0, 0.42, 0.12)
const GLOW_ALPHA := 0.55
const GLOW_IN_S := 12.0
const NEIGHBOUR_LOOKS := ["palatine_f_a", "palatine_m_a", "palatine_f_b"]
const NEIGHBOUR_LINE := "Wir kommen!"
## Their places behind the player as they follow (his frame: x right, z behind).
const FOLLOW_SLOTS := [Vector3(-1.3, 0.0, 2.0), Vector3(1.3, 0.0, 2.2), Vector3(0.0, 0.0, 3.6)]

var level: Node
var player: FrontierPlayer
var homestead := Vector3.ZERO
var farms: Array[Vector3] = []
var ford := Vector3.ZERO
## "run", "party" (coming in), "capture" (round him, the line said), "torch", "done", "fight" (resisted).
var phase := ""
var capture_when := "home"
var fire: FireSpread
var squads: Array[NpcSquad] = []
## The neighbours (StoryWalker) and each one's state: {w, state: "waiting" | "following" | "crossing" | "safe" | "gone" (on
## to the fort, out of sight: w null), t, i}.
var neighbours: Array = []
var saved := 0
var leclerc: StoryActor
var marines: Array[StoryActor] = []
var torch_bearer: StoryActor
## The farms set alight (pieces and burnables that caught), and the stand-in farmhouses made.
var farm_fires := 0
var stand_ins: Array[Node3D] = []
var glows: Array[MeshInstance3D] = []
## The house's pieces set alight.
var house_lit := 0
var captivity: Captivity
var opts := {}

var _t := 0.0
var _phase_t := 0.0
var _shot_t := 0.0
var _place_t := 0.0
var _rng := RandomNumberGenerator.new()
var _came_from := Vector3.FORWARD
var _torch_to := Vector3.INF
var _torch_at := Vector3.INF
var _torch_hold := 0.0
var _house: Array[BuiltPiece] = []
var _handed := false
var _left_home := false


## The raid begun under `level`: the night, the farms alight, the raiders, the warned waiting, the party out in the dark.
## `farms`: Vector3s (or [x, z]). opts: hour (HOUR; -1 leaves the clock), ford (a Vector3; else the storyline's place
## "ford", else the rapid nearest the homestead), neighbours (over the story's count), who ([{name, look}] for the i-th
## neighbour: the family of the i-th farm; else NEIGHBOUR_LOOKS and "Neighbour"), capture ("home" | "now" | "manual"),
## captivity (Captivity.begin's opts), stand_ins (true), raiders_per_farm, seed; resume and left_home (a load in the
## middle: see the header).
static func begin(p_level: Node, p_homestead: Vector3, p_farms: Array, p_opts := {}) -> RaidStage:
	var s := RaidStage.new()
	s.name = "RaidStage"
	p_level.add_child(s)
	s.start(p_homestead, p_farms, p_opts)
	return s


static func find(tree: SceneTree) -> RaidStage:
	return tree.get_first_node_in_group(GROUP) as RaidStage if tree else null


## How many the player warned (the story's WARNED_FLAG, 0..NEIGHBOURS_MAX; 0 with no story running).
static func persuaded(tree: SceneTree) -> int:
	var d := StoryDirector.find(tree)
	var v: Variant = d.flag(WARNED_FLAG) if d != null else null
	return clampi(int(v) if v is int or v is float else 0, 0, NEIGHBOURS_MAX)


func _ready() -> void:
	add_to_group(GROUP)


func start(p_homestead: Vector3, p_farms: Array, p_opts := {}) -> void:
	opts = p_opts
	level = get_parent()
	var tree := get_tree()
	player = StoryObjectives.player(tree)
	_rng.seed = int(opts.get("seed", 1757))
	homestead = _ground(p_homestead)
	farms.clear()
	for f: Variant in p_farms:
		var v: Variant = f
		if f is Array and (f as Array).size() >= 2:
			v = Vector3(float(f[0]), 0.0, float(f[1]))
		if v is Vector3:
			farms.append(_ground(v))
	ford = _find_ford()
	capture_when = String(opts.get("capture", "home"))
	var resume := bool(opts.get("resume", false))
	_left_home = bool(opts.get("left_home", false))
	var cap := Captivity.find(tree)
	var taken := resume and cap != null and cap.is_active()
	var h := float(opts.get("hour", HOUR))
	if h >= 0.0:
		_set_hour(h)
	fire = FireSpread.of(tree)
	for i in farms.size():
		_burn_farm(i)
		if not taken:
			_raiders_at(i)
	if not taken:
		_volley()
		var n := int(opts.get("neighbours", persuaded(tree)))
		var who: Dictionary = _who() if resume else {}
		for i in clampi(n, 0, NEIGHBOURS_MAX):
			var st := String(who.get(str(i), ""))
			if st == "over":
				neighbours.append({"w": null, "state": "gone", "t": 0.0, "i": i})     # (over the ford before the save)
				saved += 1
				continue
			_neighbour(i)
			if st == "following" and player != null:
				var e: Dictionary = neighbours.back()
				var w := e.w as StoryWalker
				var slot: Vector3 = FOLLOW_SLOTS[_following() % FOLLOW_SLOTS.size()]
				var back := _behind(player)
				w.global_position = _ground(player.global_position + back * slot.z + back.cross(Vector3.UP) * -slot.x) \
						+ Vector3.UP * 0.05
				e.state = "following"
				w.follow(player, slot)
		if resume:
			var d := StoryDirector.find(tree)
			if d != null:
				d.set_flag(SAVED_FLAG, saved)
	_make_party()
	phase = "run"
	_phase_t = 0.0
	_shot_t = _rng.randf_range(SHOT_EVERY.x, SHOT_EVERY.y) + 12.0
	began.emit()
	if taken:
		_resume_taken()
	elif capture_when == "now":
		capture_now()


## The party comes for the player now (wherever he is).
func capture_now() -> void:
	if phase != "run":
		return
	_party_in()


## The raiders off the farms: their squads freed (at the capture: the player bound is no one's foe, and the march goes up
## the bank past the farms; StorySlice's march does it too). Again does nothing.
func withdraw() -> void:
	for s in squads:
		if s != null and is_instance_valid(s) and not s.is_queued_for_deletion():
			s.queue_free()
	squads.clear()


## The two marines (MarchStage's guards).
func guards() -> Array[StoryActor]:
	return marines.duplicate()


## Leclerc and the marines.
func party() -> Array[StoryActor]:
	var out: Array[StoryActor] = []
	if leclerc != null:
		out.append(leclerc)
	out.append_array(marines)
	return out


## The party handed on to another stage (MarchStage reparents them): this stage no longer drives them, but for the torch
## still being taken to the house (MarchStage sets off once it is: house_alight).
func handed_on() -> void:
	_handed = true


func neighbours_in(state: String) -> int:
	var n := 0
	for e: Dictionary in neighbours:
		if String(e.state) == state:
			n += 1
	return n


# ---------------------------------------------------------------- the night
func _set_hour(h: float) -> void:
	var tree := get_tree()
	var core := StoryObjectives._core(tree)
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig
	var clock: WorldClock = rig.clock_driver.clock if rig != null and rig.clock_driver != null else null
	var now := SurvivalClock.hour(core) if core != null else (clock.hour if clock != null else h)
	var ahead := fposmod(now - h, 24.0)
	if ahead <= 1.5 or ahead >= 23.75:
		return                                  # (within the hour, or a quarter before it)
	var dh := fposmod(h - now, 24.0)
	if core != null:
		core.advance(dh * 60.0)                 # (the sky follows the core: SurvivalBridge)
	elif clock != null:
		clock.set_time(h)


# ---------------------------------------------------------------- the farms
func _burn_farm(i: int) -> void:
	var at := farms[i]
	var caught := fire.ignite_area(at, FARM_FIRE_R) if fire != null else 0
	if caught == 0 and fire != null and bool(opts.get("stand_ins", true)) and not _has_pieces(at):
		var house := _farmhouse(i, at)
		if house != null and fire.ignite(house, house.global_position + Vector3.UP * 2.2):
			caught = 1
	farm_fires += caught
	glows.append(_glow(at))


## Built pieces at the farm (its own house, burning or burned already: a load in the middle of the raid): no stand-in there.
func _has_pieces(at: Vector3) -> bool:
	var w := BuildWorld.of(get_tree(), false)
	return w != null and not w.near(at, FARM_FIRE_R).is_empty()


## A stand-in farmhouse (until the Flatts layer is built): a log house with a shingled roof, burnable (FireSpread chars it
## and leaves it standing as a ruin), under the level as RaidFarm_<i>. One there already is taken (a ruin: none).
func _farmhouse(i: int, at: Vector3) -> Node3D:
	var nm := "RaidFarm_%d" % i
	var old := level.get_node_or_null(nm) as Node3D
	if old != null:
		return old if fire.burnable(old) else null
	var h := Node3D.new()
	h.name = nm
	h.add_to_group(FireSpread.BURNABLE_GROUP)
	var logs := StandardMaterial3D.new()
	logs.albedo_color = Color(0.34, 0.24, 0.16)
	logs.roughness = 0.95
	var shingle := StandardMaterial3D.new()
	shingle.albedo_color = Color(0.22, 0.18, 0.15)
	shingle.roughness = 0.9
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var wb := BoxMesh.new()
	wb.size = Vector3(6.0, 2.6, 4.6)
	walls.mesh = wb
	walls.material_override = logs
	walls.position.y = 1.3
	h.add_child(walls)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var pm := PrismMesh.new()
	pm.size = Vector3(5.2, 1.9, 6.6)          # (its ridge along the house: the prism's length is its z, turned to x)
	roof.mesh = pm
	roof.material_override = shingle
	roof.position.y = 2.6 + 0.95
	roof.rotation.y = PI * 0.5
	h.add_child(roof)
	var sb := StaticBody3D.new()
	sb.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 3.6, 4.6)
	cs.shape = bs
	cs.position.y = 1.8
	sb.add_child(cs)
	h.add_child(sb)
	level.add_child(h)
	h.global_position = at
	var to_home := homestead - at
	h.rotation.y = atan2(-to_home.x, -to_home.z) if Vector2(to_home.x, to_home.z).length() > 1.0 else 0.0
	stand_ins.append(h)
	return h


## The glow of a farm burning in the night sky: a card standing over it, turned to the camera about the vertical, added onto
## what is behind it (unshaded, no fog: it is the fire's own light on the smoke).
func _glow(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "RaidGlow"
	var q := QuadMesh.new()
	q.size = GLOW_SIZE
	q.center_offset = Vector3(0.0, GLOW_SIZE.y * 0.5 - 4.0, 0.0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	m.set(&"disable_fog", true)
	m.albedo_texture = _glow_texture()
	m.albedo_color = Color(GLOW_COLOR, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 8.0
	add_child(mi)
	mi.global_position = at
	return mi


static var _glow_tex: GradientTexture2D


static func _glow_texture() -> GradientTexture2D:
	if _glow_tex != null:
		return _glow_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 0.85, 0.7, 0.6), Color(1, 0.7, 0.5, 0.18), Color(1, 0.6, 0.4, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 1.0)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 64
	_glow_tex = t
	return t


func _raiders_at(i: int) -> void:
	var at := farms[i]
	var away := at - homestead
	away.y = 0.0
	away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
	var hold := _ground(at + away * RAIDERS_PAST_M)
	var faction := String(RAIDER_FACTIONS[i % RAIDER_FACTIONS.size()])
	var s := NpcSquad.spawn(self, faction, int(opts.get("raiders_per_farm", RAIDERS_PER_FARM)), hold,
			{"tag": "raiders", "hold": hold, "face": at, "spacing": 3.0, "seed": 1757 + i})
	if s != null:
		squads.append(s)


## A first volley over the farms: shots far and near, then a ragged fire (the musket's report, delayed: no node per shot).
func _volley() -> void:
	if farms.is_empty():
		return
	var t := 0.3
	for i in 18:
		var at := farms[_rng.randi() % farms.size()] + Vector3(_rng.randf_range(-30.0, 30.0), 2.0, _rng.randf_range(-30.0, 30.0))
		Sfx.play_3d(&"musket_shot", at, _rng.randf_range(-4.0, 1.0), _rng.randf_range(0.92, 1.05), {"delay": t})
		t += _rng.randf_range(0.15, 1.4) if i > 2 else _rng.randf_range(1.2, 2.4)


func _shot() -> void:
	if farms.is_empty():
		return
	var at := farms[_rng.randi() % farms.size()] + Vector3(_rng.randf_range(-35.0, 35.0), 2.0, _rng.randf_range(-35.0, 35.0))
	Sfx.play_3d(&"musket_shot", at, _rng.randf_range(-5.0, 0.0), _rng.randf_range(0.92, 1.05))


# ---------------------------------------------------------------- the run
func _find_ford() -> Vector3:
	var f: Variant = opts.get("ford")
	if f is Vector3:
		return _ground(f)
	var d := StoryDirector.find(get_tree())
	if d != null:
		var p: Variant = StoryObjectives.place_point({"place": "ford"}, d.places())
		if p is Vector3:
			return _ground(p)
	# the rapid nearest the homestead (the river's fords are its rapids)
	var best_z := homestead.z
	var bd := INF
	for r: Dictionary in WorldRiver.rapids():
		var dz := absf(float(r.z) - homestead.z)
		if dz < bd:
			bd = dz
			best_z = float(r.z)
	return _ground(Vector3(WorldRiver.x_at(best_z), 0.0, best_z))


func _far_bank(i: int) -> Vector3:
	var z := ford.z + (float(i) - 1.0) * 2.5
	var x := WorldRiver.x_at(z) - FAR_BANK_M if WorldRiver.has_water() else ford.x - FAR_BANK_M
	# (the fort's side is west of the river: toward the fort, from wherever the ford is)
	if homestead.x < ford.x:
		x = (WorldRiver.x_at(z) if WorldRiver.has_water() else ford.x) + FAR_BANK_M
	return _ground(Vector3(x, 0.0, z))


func _neighbour(i: int) -> void:
	if farms.is_empty():
		return
	var farm := farms[i % farms.size()]
	var to_home := homestead - farm
	to_home.y = 0.0
	var dir := to_home.normalized() if to_home.length() > 1.0 else Vector3.BACK
	var side := dir.cross(Vector3.UP).normalized()
	var at := farm + dir * NEIGHBOURS_NEAR_M + side * (float(i) - 1.0) * 3.0
	# the family of the farm it waits by (opts who: as The Third Warning showed them), else a neighbour of the presets
	var look := String(NEIGHBOUR_LOOKS[i % NEIGHBOUR_LOOKS.size()])
	var nm := "Neighbour"
	var who: Array = opts.get("who", [])
	if i < who.size() and who[i] is Dictionary:
		look = String((who[i] as Dictionary).get("look", look))
		nm = String((who[i] as Dictionary).get("name", nm))
	var w := StoryWalker.make(self, at, StoryWalker.settler_look(look),
			{"tag": "neighbour", "name": nm, "group": [NEIGHBOURS, WildlifeSpawner.PEOPLE], "face": farm,
			"node_name": "neighbour_%d" % i})
	w.crouch(true)
	neighbours.append({"w": w, "state": "waiting", "t": 0.0, "i": i})


func _neighbours(dt: float) -> void:
	for e: Dictionary in neighbours:
		var o: Variant = e.w
		if o == null or not is_instance_valid(o):
			continue
		var w := o as StoryWalker
		e.t = float(e.t) + dt
		match String(e.state):
			"waiting":
				if phase == "run" and player != null and _flat(player.global_position, w.global_position) <= CALL_M:
					e.state = "following"
					e.t = 0.0
					w.follow(player, FOLLOW_SLOTS[_following() % FOLLOW_SLOTS.size()])
					StoryBark.say(w, NEIGHBOUR_LINE, 2.5)
					_note(int(e.i), "following")
			"following":
				if _flat(w.global_position, ford) <= FORD_R:
					e.state = "crossing"
					e.t = 0.0
					w.go(_far_bank(int(e.i)), StoryWalker.RUN, 2.0)
					_note(int(e.i), "over")
			"crossing":
				if w.arrived():
					e.state = "safe"
					e.t = 0.0
					saved += 1
					var d := StoryDirector.find(get_tree())
					if d != null:
						d.set_flag(SAVED_FLAG, saved)
					var on := _far_bank(int(e.i)) + (_far_bank(int(e.i)) - ford).normalized() * 40.0
					w.go(_ground(on), StoryWalker.WALK, 2.0)
					neighbour_saved.emit(w)
			"safe":
				if float(e.t) > SAFE_S and (player == null or _flat(player.global_position, w.global_position) > 30.0):
					e.state = "gone"
					e.w = null
					w.queue_free()


func _following() -> int:
	return neighbours_in("following")


## The story's record of the neighbours (WHO_FLAG), for a load in the middle.
func _who() -> Dictionary:
	var d := StoryDirector.find(get_tree())
	var v: Variant = d.flag(WHO_FLAG) if d != null else null
	return (v as Dictionary).duplicate() if v is Dictionary else {}


func _note(i: int, state: String) -> void:
	var d := StoryDirector.find(get_tree())
	if d == null:
		return
	var who := _who()
	who[str(i)] = state
	d.set_flag(WHO_FLAG, who)


# ---------------------------------------------------------------- the party
func _make_party() -> void:
	var away := homestead - (ford if farms.is_empty() else _centroid(farms))
	away.y = 0.0
	away = away.normalized() if away.length() > 1.0 else Vector3.FORWARD
	var wait := homestead + away * PARTY_WAIT_M
	var side := away.cross(Vector3.UP).normalized()
	leclerc = StoryActor.make(self, "canadian_militia", wait, {"name": LECLERC, "tag": "leclerc", "face": homestead, "seed": 1757})
	marines.append(StoryActor.make(self, "french_marine", wait + side * 2.5, {"tag": "raid_marine", "face": homestead, "seed": 1758,
			"node_name": "marine_0"}))
	torch_bearer = StoryActor.make(self, "french_marine", wait - side * 2.5, {"tag": "raid_marine", "face": homestead, "seed": 1759,
			"weapon": "", "sidearm": "", "node_name": "marine_1"})
	marines.append(torch_bearer)
	for a in party():
		a.woke.connect(_on_woke)


## The party comes up from behind the player (out of his camera's view) toward him.
func _party_in() -> void:
	if player == null or leclerc == null:
		return
	var back := _clear_way(player.global_position, _behind(player))
	var right := back.cross(Vector3.UP).normalized()
	var from := player.global_position + back * PARTY_FROM_M
	_came_from = back
	var i := 0
	for a in party():
		var p := _ground(from + right * (float(i) - 1.0) * 2.8)
		if not _spot_clear(p):
			p = _free_spot(player.global_position, (p - player.global_position).normalized(), PARTY_FROM_M)
		a.global_position = p + Vector3.UP * 0.1
		a.velocity = Vector3.ZERO
		a.face_now(player.global_position)
		i += 1
	phase = "party"
	_phase_t = 0.0
	_place_t = 0.0


## Loaded with the player taken already: the party round him at once (no walk in from the dark), Leclerc his captor again
## (_take: Captivity.follow), the torch to the house if it is not alight yet.
func _resume_taken() -> void:
	if player == null or leclerc == null:
		return
	_came_from = _behind(player)
	var pts := _surround_points()
	var i := 0
	for a in party():
		a.global_position = pts[i] + Vector3.UP * 0.1
		a.velocity = Vector3.ZERO
		a.face_now(player.global_position)
		a.stand(player.global_position)
		i += 1
	leclerc.last_bark = LINE
	phase = "capture"
	_phase_t = 0.0
	_take()


## The way behind the player as he sees it (away from where his camera looks), flat.
func _behind(p: Node3D) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var b := cam.global_basis.z if cam != null else p.global_basis.z
	b.y = 0.0
	return b.normalized() if b.length() > 0.01 else Vector3.BACK


## Where each of the party stands round the player: Leclerc between him and where they came from, the marines at his sides;
## each turned a little round him off a spot something built stands on (a campfire, the lean-to, a wall: one he could not
## reach would leave Leclerc too far off for the talk that takes the player, and nothing would happen).
func _surround_points() -> Array:
	var c := player.global_position
	var out := []
	var k := 0
	for a in party():
		var ang := 0.0 if k == 0 else (1.95 if k == 1 else -1.95)
		out.append(_free_spot(c, _came_from.rotated(Vector3.UP, ang), SURROUND_M))
		k += 1
	return out


## The ground `r` from `c` along `d`, turned up to SPOT_TURN either way round `c` when something solid stands there (a
## built piece, a trunk, a rock); the straight one when every turn is taken.
func _free_spot(c: Vector3, d: Vector3, r: float) -> Vector3:
	for k: float in SPOT_TURNS:
		var p := _ground(c + d.rotated(Vector3.UP, k) * r)
		if _spot_clear(p):
			return p
	return _ground(c + d * r)


## The way the party comes in from (`d`, behind the player), turned round him while the last of the way (PARTY_FROM_M out
## to SURROUND_M from him) runs into something built or solid (a campfire, the lean-to, the house).
func _clear_way(c: Vector3, d: Vector3) -> Vector3:
	if player == null or not player.is_inside_tree():
		return d
	var space := player.get_world_3d().direct_space_state
	for k: float in SPOT_TURNS:
		var dd := d.rotated(Vector3.UP, k)
		var ok := true
		for h: float in [0.35, 1.0]:
			var a := _ground(c + dd * PARTY_FROM_M) + Vector3.UP * h
			var b := _ground(c + dd * (SURROUND_M - 0.4)) + Vector3.UP * h
			var q := PhysicsRayQueryParameters3D.create(a, b, 1, [player.get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and hit.collider is Node and not (hit.collider as Node).is_in_group(&"terrain"):
				ok = false
				break
		if ok:
			return dd
	return d


func _spot_clear(p: Vector3) -> bool:
	var w := BuildWorld.of(get_tree(), false)
	if w != null and not w.near(p, SPOT_CLEAR_M).is_empty():
		return false
	if player == null or not player.is_inside_tree():
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
	q.collision_mask = 1
	var ex: Array[RID] = [player.get_rid()]
	for a in party():
		if a != null and is_instance_valid(a):
			ex.append(a.get_rid())
	q.exclude = ex
	for h: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(q, 4):
		var col: Variant = h.get("collider")
		if col is Node and not (col as Node).is_in_group(&"terrain"):
			return false
	return true


func _party(dt: float) -> void:
	_place_t -= dt
	var pts := _surround_points()
	if _place_t <= 0.0:
		_place_t = 0.4
		var i := 0
		for a in party():
			a.walk_to(pts[i], StoryActor.JOG if _flat(a.global_position, pts[i]) > 4.0 else NpcFighter.WALK_SPEED, 0.5)
			i += 1
	var all_there := true
	var i2 := 0
	for a in party():
		if _flat(a.global_position, pts[i2]) > 1.2:
			all_there = false
		i2 += 1
	if all_there or _phase_t >= PARTY_MAX_S:
		# (one held up on the way, out of the camera's sight, is at his place: the talk that takes the player wants
		# Leclerc by him)
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var j := 0
		for a in party():
			if _flat(a.global_position, pts[j]) > 1.5 and (cam == null or not cam.is_position_in_frustum(a.global_position + Vector3.UP)):
				a.global_position = pts[j] + Vector3.UP * 0.1
				a.velocity = Vector3.ZERO
			j += 1
		for a in party():
			a.stand(player.global_position)
		phase = "capture"
		_phase_t = 0.0
		StoryBark.say(leclerc, LINE, 5.0)
		leclerc.last_bark = LINE
		party_came.emit()


func _take() -> void:
	captivity = Captivity.install(level)
	var cap_opts: Dictionary = opts.get("captivity", {})
	if not captivity.is_active():
		if not captivity.begin(player, leclerc, cap_opts):
			phase = "done"                     # (no one to take: the player dead meanwhile; the mission's death rule has it)
			return
	else:
		captivity.follow(leclerc)
	withdraw()
	phase = "torch"
	_phase_t = 0.0
	torch_bearer.carry_torch(true)
	_house = _house_pieces()
	if _house.is_empty():
		_torch_to = Vector3.INF
	else:
		_torch_to = _torch_spot()
		torch_bearer.walk_to(_torch_to, NpcFighter.WALK_SPEED, 0.6)
	captured.emit()
	if _house.is_empty():
		house_alight.emit(0)
		_after_torch()


## The player's built pieces that burn within HOUSE_R of the homestead, the roof first, then the nearest.
func _house_pieces() -> Array[BuiltPiece]:
	var out: Array[BuiltPiece] = []
	var w := BuildWorld.of(get_tree(), false)
	if w == null or fire == null:
		return out
	for p in w.near(homestead, HOUSE_R):
		if fire.burnable(p) and not fire.is_burning(p):
			out.append(p)
	var by := torch_bearer.global_position
	out.sort_custom(func(a: BuiltPiece, b: BuiltPiece) -> bool:
		var ra := a.type in ["roof", "gable"]
		var rb := b.type in ["roof", "gable"]
		if ra != rb:
			return ra
		return a.global_position.distance_squared_to(by) < b.global_position.distance_squared_to(by))
	return out


## Where the torch is held: at the house's edge nearest the bearer (its pieces' footprint, a little out from it).
func _torch_spot() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _house:
		var q := Vector2(p.global_position.x, p.global_position.z)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var mid := (lo + hi) * 0.5
	_torch_at = _ground(Vector3(mid.x, 0.0, mid.y))
	lo -= Vector2(2.2, 2.2)
	hi += Vector2(2.2, 2.2)
	# the edge of the footprint (grown) on the line from its middle to the bearer
	var b := Vector2(torch_bearer.global_position.x, torch_bearer.global_position.z)
	var d := b - mid
	if d.length() < 0.1:
		d = Vector2(1.0, 0.0)
	var half := (hi - lo) * 0.5
	var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	var c := mid + d * minf(t, 1.0)
	return _ground(Vector3(c.x, 0.0, c.y))


func _torch(dt: float) -> void:
	if _torch_to == Vector3.INF:
		return
	if _torch_hold <= 0.0 and (torch_bearer.arrived() or _flat(torch_bearer.global_position, _torch_to) < 1.0 or _phase_t > TORCH_MAX_S):
		torch_bearer.stand(_torch_at)
		_torch_hold = 0.001
	if _torch_hold > 0.0:
		_torch_hold += dt
		if _torch_hold >= TORCH_HOLD_S:
			_light_house()
			_after_torch()


## The house alight: the roof (where the torch is held) and the piece nearest the torch below it.
func _light_house() -> void:
	if _house.is_empty() or house_lit > 0:
		return
	var at := torch_bearer.global_position + Vector3.UP * 1.6 if torch_bearer != null and is_instance_valid(torch_bearer) else Vector3.INF
	var n := 0
	var low_done := false
	for p in _house:
		if not is_instance_valid(p):
			continue
		var is_roof := p.type in ["roof", "gable"]
		if n == 0 or (not is_roof and not low_done):
			var catch_at := Vector3.INF
			if at != Vector3.INF:
				var box := fire._box_of(p)
				catch_at = FireSpread._closest(box, at)
			if fire.ignite(p, catch_at):
				n += 1
				if not is_roof:
					low_done = true
		if n >= 2 and low_done:
			break
	house_lit = n
	house_alight.emit(n)


func _after_torch() -> void:
	phase = "done"
	_phase_t = 0.0
	if torch_bearer != null and is_instance_valid(torch_bearer) and player != null:
		torch_bearer.walk_to(_ground(player.global_position + _came_from.rotated(Vector3.UP, -1.95) * 3.0), NpcFighter.WALK_SPEED, 0.8)


func _on_woke(_a: StoryActor, by: Node) -> void:
	if phase in ["run", "party", "capture"] and (captivity == null or not captivity.is_active()):
		phase = "fight"
		for a in party():
			a.wake(by)
		resisted.emit(by)


# ---------------------------------------------------------------- each frame
func _process(dt: float) -> void:
	if phase == "":
		return
	_t += dt
	_phase_t += dt
	# the glow fades in as the farms take, and flickers
	var k := clampf(_t / GLOW_IN_S, 0.0, 1.0)
	for i in glows.size():
		var g := glows[i]
		if g == null or not is_instance_valid(g):
			continue
		var f := 0.82 + 0.1 * sin(_t * 2.3 + float(i) * 1.7) + 0.08 * sin(_t * 5.9 + float(i))
		(g.material_override as StandardMaterial3D).albedo_color.a = GLOW_ALPHA * k * f
	if phase in ["run", "party"]:
		_shot_t -= dt
		if _shot_t <= 0.0:
			_shot_t = _rng.randf_range(SHOT_EVERY.x, SHOT_EVERY.y)
			_shot()
	_neighbours(dt)
	if _handed and phase != "torch":
		return
	match phase:
		"run":
			if capture_when == "home" and player != null:
				var d := _flat(player.global_position, homestead)
				if d > HOME_LEFT_M:
					_left_home = true
				var ready := _left_home or (neighbours_in("waiting") == 0 and _phase_t >= HOME_WAIT_S) or _phase_t >= RUN_MAX_S
				if d <= HOME_R and _following() == 0 and ready:
					_party_in()
		"party":
			_party(dt)
		"capture":
			if _phase_t >= TAKE_S:
				_take()
		"torch":
			_torch(dt)


# ---------------------------------------------------------------- helpers
func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


static func _centroid(pts: Array[Vector3]) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / float(maxi(pts.size(), 1))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
