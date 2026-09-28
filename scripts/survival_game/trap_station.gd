class_name TrapStation
extends Node3D
## A trap on the line (user 2026-09-28, "trapping lines": "set snares and steel traps, walk the line each morning, and
## carry the pelts to trade"): what a placed trap piece (BuiltPiece: trap_steel, trap_snare, trap_deadfall; the build
## menu's Traps) does, worked through the survival rules' trap line (SurvivalTrapLine: each dawn a catch by species,
## season, the site and how well it was set; a catch left out is taken by scavengers, an unvisited trap springs, fresh
## snow buries sets; the trapping cell's animals thin out and come back). An E interactable, like the stations:
##   placed     E sets it: the rules' trap.*_set job and its Trapping and Fishing check. A steel trap, a length of
##              cordage or a set of deadfall stakes goes from the pack into it; a snare wants young trees near to bend
##              (WildlifeSpawner.cover), a deadfall a hatchet or an axe in the kit. Where it stands grades the site
##              (site_here: by water or along thick cover a run, "good"; the woods "fair"; the open "poor"), less near
##              a camp fire; the cell is the rules' 4 x 4 over each square (cell_at).
##   set        E checks it (a visit keeps it from springing); hold E takes it up (a steel trap back to the pack)
##   holding    the catch lies in it (TrapCatch): E takes it, knelt the whole way: the check collects the carcass, the
##              knife skins a furbearer's pelt (fur.skin, graded by the check) and dresses the meat
##              (butcher.field_dress: small game, a hare's or a raccoon's), into the pack; the trap is set again
##   sprung     gone off empty (or its catch taken by scavengers, or buried in snow): E sets it again
## The rules' record keeps the trap (the survival save); the piece's place is kept in it ("pos"), so the piece finds its
## record again after a load. Taking the piece down (here, or in build mode) takes the record up. The look: the piece's
## own mesh set; BuildGeometry.trap_mesh sprung, with the catch in it.

const KINDS := ["trap_steel", "trap_snare", "trap_deadfall"]
## The rules' trap type, its set action, and what goes into it from the pack.
const TYPE := {"trap_steel": "steel_land", "trap_snare": "snare", "trap_deadfall": "deadfall"}
const SET_ACTION := {"trap_steel": "trap.steel_land_set", "trap_snare": "trap.snare_set", "trap_deadfall": "trap.deadfall_set"}
const ITEM := {"trap_steel": "steel_trap", "trap_snare": "cordage", "trap_deadfall": "stake_set"}
const NAME := {"trap_steel": "steel trap", "trap_snare": "snare", "trap_deadfall": "deadfall"}
## The world's trapping cells (the rules' 16): a 4 x 4 over each square.
const CELLS := 4
## The site: a run by water within WATER_RUN_M, or along thick cover (WildlifeSpawner.cover at COVER_RUN); the woods
## (cover at COVER_WOODS) a trail; else off it. Young trees to bend for a snare: cover at SAPLINGS.
const WATER_RUN_M := 7.0
const COVER_RUN := 0.55
const COVER_WOODS := 0.2
const SAPLINGS := 0.25
## A record this near the piece is its own (relinking after a load).
const RELINK_M := 0.6

var kind := ""
var interact_reach := 2.2
## The rules' trap record's id ("": placed, not set).
var trap_id := ""
## The last work's result {what, ok, text, got} (tests).
var last := {}

var _bridge: SurvivalBridge
var _job := ""
var _what := ""
var _moved := ""
var _saved_ctx := {}
var _got := {}
var _sp := ""
var _catch: Node3D
var _sprung: MeshInstance3D
var _shown := "-"
var _poll := 0.0


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(&"trap_line")
	_relink.call_deferred()
	var w := BuildWorld.of(get_tree(), false)
	if w and not w.changed.is_connected(_on_world_changed):
		w.changed.connect(_on_world_changed)


func bridge() -> SurvivalBridge:
	if _bridge == null or not is_instance_valid(_bridge):
		_bridge = SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	return _bridge


func piece() -> BuiltPiece:
	return get_parent() as BuiltPiece


func record() -> Dictionary:
	var b := bridge()
	if b == null or b.core == null or trap_id == "":
		return {}
	return SurvivalTrapLine.trap(b.core, trap_id)


## "": placed, not set (or its record gone: a steel trap lost off the line); else the rules' state: set, holding,
## sprung, buried.
func state() -> String:
	var r := record()
	return "" if r.is_empty() else String(r.get("state", ""))


func catch_species() -> String:
	return String(record().get("catch", "")) if state() == "holding" else ""


## After a load: the rules' record standing here.
func _relink() -> void:
	var b := bridge()
	if b == null or b.core == null or trap_id != "":
		return
	for id: String in SurvivalTrapLine.trap_ids(b.core):
		var p: Variant = SurvivalTrapLine.trap(b.core, id).get("pos")
		if p is Array and (p as Array).size() == 3 and Vector3(float(p[0]), float(p[1]), float(p[2])).distance_to(global_position) < RELINK_M:
			trap_id = id
			break


## The piece taken down in build mode: its record taken up with it (a steel trap back to the pack).
func _on_world_changed() -> void:
	if is_inside_tree() or trap_id == "" or _bridge == null or not is_instance_valid(_bridge):
		return
	var tid := trap_id
	trap_id = ""
	if _bridge.core and not SurvivalTrapLine.trap(_bridge.core, tid).is_empty():
		SurvivalTrapLine.remove_trap(_bridge.core, tid, true)
		if kind == "trap_steel" and _bridge.player:
			_to_pack(_bridge.player, "item.trap.steel", "steel_trap")


# --- The place ---------------------------------------------------------------------------------------------------

## The rules' trapping cell of a place (0..15): its square's 4 x 4.
static func cell_at(pos: Vector3) -> int:
	var s := WorldSquares.size_m()
	var c := WorldSquares.center_of(WorldSquares.square_at(pos))
	var ix := clampi(int(floor((pos.x - c.x + s * 0.5) / s * CELLS)), 0, CELLS - 1)
	var iz := clampi(int(floor((pos.z - c.z + s * 0.5) / s * CELLS)), 0, CELLS - 1)
	return iz * CELLS + ix


## The site as the rules grade it: "good" a run (by water, along thick cover), "fair" a trail in the woods, "poor" off.
static func site_here(tree: SceneTree, pos: Vector3) -> String:
	if water_near(pos, WATER_RUN_M):
		return "good"
	var cv := cover_at(tree, pos)
	if cv >= COVER_RUN:
		return "good"
	return "fair" if cv >= COVER_WOODS else "poor"


static func cover_at(tree: SceneTree, pos: Vector3) -> float:
	var sp := tree.get_first_node_in_group(&"wildlife_spawner") as WildlifeSpawner if tree else null
	return sp.cover(pos.x, pos.z) if sp else 0.4


static func water_near(pos: Vector3, r: float) -> bool:
	if not WorldRiver.has_water():
		return false
	if WorldRiver.surface_at(pos.x, pos.z) != WorldRiver.NO_WATER:
		return true
	for a in 8:
		var q := pos + Vector3(cos(a * TAU / 8.0), 0.0, sin(a * TAU / 8.0)) * r
		if WorldRiver.surface_at(q.x, q.z) != WorldRiver.NO_WATER:
			return true
	return false


## Metres to the nearest campfire (the rules' camp penalty: a trap near a camp takes less).
func camp_distance() -> float:
	var best := 9999.0
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		if n is Node3D:
			best = minf(best, (n as Node3D).global_position.distance_to(global_position))
	return best


# --- E -----------------------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.15


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var out: Array = []
	var pc := piece()
	if pc and (_sprung == null or not _sprung.visible):
		out.append_array(pc.highlight_targets())
	if _sprung and _sprung.visible:
		out.append(_sprung)
	if _catch:
		out.append_array(_catch.find_children("*", "MeshInstance3D", true, false))
	return out


func interact_prompt(player: Node) -> String:
	var b := bridge()
	if b == null or b.core == null or _build_mode_on() or _job != "":
		return ""
	var nm := String(NAME.get(kind, "trap"))
	match state():
		"":
			var item := String(ITEM[kind])
			if Campfire._pack_count(player, item) <= 0:
				return "Set the %s (needs %s)" % [nm, InventoryState.name_of(item).to_lower()]
			return "Set the %s (%s site)" % [nm, site_here(get_tree(), global_position)]
		"set":
			return "Check the %s" % nm
		"holding":
			return "Take the %s from the %s" % [species_name(catch_species()), nm]
		"buried":
			return "Dig out the %s and set it again" % nm
		"sprung":
			return "Set the %s again (sprung empty)" % nm
	return ""


func interact_actions(player: Node) -> Array:
	var first := interact_prompt(player)
	if first == "":
		return []
	return [{"id": "", "text": first}, {"id": "take_up", "text": "Take up the %s" % String(NAME.get(kind, "trap"))}]


func interact_action(player: Node, id: String) -> void:
	if id == "take_up":
		take_up(player)
	else:
		interact(player)


func interact(player: Node) -> void:
	match state():
		"":
			set_trap(player)
		"holding":
			take_catch(player)
		_:
			check(player)


func _build_mode_on() -> bool:
	return is_instance_valid(BuildMode.current) and BuildMode.current.active


static func species_name(sp: String) -> String:
	return "hare" if sp == "small" else sp


# --- The work ----------------------------------------------------------------------------------------------------

## Sets it (the rules' set job and its check). False when it cannot start.
func set_trap(player: Node) -> bool:
	var b := bridge()
	if b == null or b.core == null or b.work.working or SurvivalJobs.is_running(b.core) or state() != "":
		return false
	var item := String(ITEM[kind])
	if Campfire._pack_count(player, item) <= 0:
		b._notice("You need %s to set it" % InventoryState.name_of(item).to_lower())
		return false
	var cover := cover_at(get_tree(), global_position)
	if kind == "trap_snare" and cover < SAPLINGS:
		b._notice("No young trees here to bend for a snare")
		return false
	trap_id = ""
	# what goes into it: from the pack into the rules' kit, for the job to take
	var m := b.pack_item(item)
	var inv := InventoryState.from_player(player)
	inv.take(item, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	SurvivalInventory.add(b.core, String(m.item), float(m.get("qty", 1.0)))
	_moved = item
	var near := ["node.trail"]
	if cover >= SAPLINGS:
		near.append("node.sapling_stand")
	_saved_ctx = {"near": b.core.state.context.get("near", []), "cell": b.core.state.context.get("cell", -1)}
	b.set_context({"near": near, "cell": cell_at(global_position)})
	var params := {"cell": cell_at(global_position), "site": site_here(get_tree(), global_position), "bait": "none",
			"camp_distance_m": camp_distance()}
	return _start(String(SET_ACTION[kind]), params, "Setting the %s" % String(NAME[kind]), "set")


## A visit: the rules' trap.check (a set trap kept from springing; a sprung or buried one set again).
func check(_player: Node = null) -> bool:
	var b := bridge()
	if trap_id == "" or b == null or b.work.working or SurvivalJobs.is_running(b.core):
		return false
	var text := "Checking the %s" % String(NAME[kind]) if state() == "set" else "Setting the %s again" % String(NAME[kind])
	return _start("trap.check", {"trap_id": trap_id}, text, "check")


## The catch taken: the check collects the carcass, then the knife (a furbearer's pelt, the meat).
func take_catch(_player: Node = null) -> bool:
	var b := bridge()
	if state() != "holding" or b.work.working or SurvivalJobs.is_running(b.core):
		return false
	_sp = catch_species()
	_got = {}
	return _start("trap.check", {"trap_id": trap_id}, "Taking the %s from the %s" % [species_name(_sp), String(NAME[kind])], "catch")


## Takes it up: the rules' record gone (a steel trap back to the pack), the piece taken down.
func take_up(player: Node) -> void:
	var b := bridge()
	if b == null or b.core == null or _job != "":
		return
	if trap_id != "":
		var tid := trap_id
		trap_id = ""
		SurvivalTrapLine.remove_trap(b.core, tid, true)
		if kind == "trap_steel":
			_to_pack(player, "item.trap.steel", "steel_trap")
		b._notice("You take up the %s" % String(NAME[kind]))
	var w := BuildWorld.of(get_tree(), false)
	if w and piece():
		w.remove_piece(piece())


func _start(action: String, params: Dictionary, text: String, what: String) -> bool:
	var b := bridge()
	var r := b.core.start_job(action, params)
	if not bool(r.get("ok", false)):
		_give_back()
		_restore_ctx()
		var rs: Array = r.get("reasons", [])
		b._notice("You cannot do that now: %s" % (String(rs[0]) if not rs.is_empty() else String(r.get("reason", "not now"))))
		return false
	_job = action
	_what = what
	if not b.core.job_finished.is_connected(_on_finished):
		b.core.job_finished.connect(_on_finished)
	if not b.core.job_interrupted.is_connected(_on_interrupted):
		b.core.job_interrupted.connect(_on_interrupted)
	if b.work.working:
		# the next job of the same kneel (the knife after the catch is taken)
		b.work.go_on(action, text)
		return true
	if not b.work.begin(global_position, "low", text, 0.0, action, _on_work_end):
		b.core.cancel_job("moved")
		_job = ""
		_give_back()
		_restore_ctx()
		return false
	return true


func _on_finished(res: Dictionary) -> void:
	if _job == "" or String(res.get("action", "")) != _job:
		return
	var b := bridge()
	_job = ""
	match _what:
		"set":
			_restore_ctx()
			var tid := String(res.get("trap_id", ""))
			if tid != "":
				trap_id = tid
				SurvivalTrapLine.trap(b.core, tid)["pos"] = [global_position.x, global_position.y, global_position.z]
				_moved = ""
				_result("set", true, "The %s is set: a %s site" % [String(NAME[kind]), String(res.get("site", ""))], {})
			else:
				_give_back()
				var notes: Array = res.get("notes", [])
				_result("set", false, ("It will not set: %s" % String(notes[0])) if not notes.is_empty() else "It will not set: try again", {})
		"check":
			_result("check", bool(res.get("reset", false)), ("The %s is set again" % String(NAME[kind])) if bool(res.get("reset", false))
					else ("You fumble the reset: the %s stays sprung" % String(NAME[kind])), {})
		"catch":
			var cid := String(res.get("carcass_id", ""))
			if cid == "":
				_result("catch", false, "Nothing in the %s now" % String(NAME[kind]), {})
				return
			if not bool(res.get("reset", false)):
				_got["fumbled"] = 1
			_knife(cid)
		"skin", "dress":
			for item: String in SurvivalUtil.dict(res.get("gained")):
				var k := b.pack_kind_of(item)
				if k != "":
					var n := _to_pack(b.player, item, k)
					if n > 0:
						_got[k] = int(_got.get(k, 0)) + n
			var cid2 := String(res.get("carcass_id", ""))
			if _what == "skin" and cid2 != "":
				_knife(cid2)
			else:
				_caught()


## The knife's next work on the carcass: skin a pelt first, then dress the meat; nothing left, done.
func _knife(cid: String) -> void:
	var b := bridge()
	var rec := SurvivalCamp.carcass(b.core, cid)
	if rec.is_empty():
		_caught()
		return
	var sp := species_name(_sp)
	var ok := false
	if SurvivalCamp.carcass_has_pelt(b.core, rec) and not bool(rec.get("skinned", false)):
		ok = _start("fur.skin", {"carcass_id": cid}, "Skinning the %s" % sp, "skin")
	elif not bool(rec.get("dressed", false)):
		ok = _start("butcher.field_dress", {"carcass_id": cid}, "Dressing the %s" % sp, "dress")
	else:
		_caught()
		return
	if not ok:
		_caught()


func _caught() -> void:
	var fumbled := _got.has("fumbled")
	_got.erase("fumbled")
	var text := "You take the %s: %s" % [species_name(_sp), CampStation._got_text(_got) if not _got.is_empty() else "nothing worth keeping"]
	if fumbled:
		text += "; the %s stays sprung" % String(NAME[kind])
	_result("catch", not _got.is_empty(), text, _got.duplicate())


func _on_interrupted(job: Dictionary, reason: String) -> void:
	if _job == "" or String(job.get("action", "")) != _job:
		return
	# going from fed to peckish (the core's wake rule for any worse need): the work goes on where it was
	if reason.contains("peckish") and bool(bridge().core.start_job(_job, SurvivalUtil.dict(job.get("params"))).get("ok", false)):
		return
	_job = ""
	_give_back()
	_restore_ctx()
	_result(_what, false, "You stop: %s" % reason, _got.duplicate())
	if bridge().work.working:
		bridge().work.stop("interrupted")


func _on_work_end(ok: bool) -> void:
	if ok or _job == "":
		return
	# stopped by the player: the core cancelled the job; what went into the trap comes back
	_job = ""
	_give_back()
	_restore_ctx()
	_result(_what, false, "", _got.duplicate())


## A trap not set: what went into it back to the pack.
func _give_back() -> void:
	if _moved == "":
		return
	var b := bridge()
	if b and b.core and b.player:
		var m := b.pack_item(_moved)
		if not m.is_empty() and SurvivalInventory.count(b.core, String(m.item)) >= float(m.get("qty", 1.0)) - 0.001:
			var inv := InventoryState.from_player(b.player)
			SurvivalInventory.remove(b.core, String(m.item), float(m.get("qty", 1.0)))
			inv.add(_moved, 1)
			b.player.set("inventory_pack", inv.pack.duplicate(true))
	_moved = ""


func _restore_ctx() -> void:
	if not _saved_ctx.is_empty() and bridge():
		bridge().set_context(_saved_ctx)
	_saved_ctx = {}


## Moves the rules' whole units of `item` to the pack as `pack_kind`; how many.
func _to_pack(player: Node, item: String, pack_kind: String) -> int:
	var b := _bridge if _bridge and is_instance_valid(_bridge) else bridge()
	var m := b.pack_item(pack_kind)
	var per := float(m.get("qty", 1.0)) if not m.is_empty() else 1.0
	var units := floori(SurvivalInventory.count(b.core, item) / per + 0.0001)
	if units <= 0:
		return 0
	SurvivalInventory.remove(b.core, item, float(units) * per)
	var inv := InventoryState.from_player(player)
	inv.add(pack_kind, units)
	player.set("inventory_pack", inv.pack.duplicate(true))
	return units


func _result(what: String, ok: bool, text: String, got: Dictionary) -> void:
	last = {"what": what, "ok": ok, "text": text, "got": got}
	var b := bridge()
	if b and text != "":
		b._notice(text)


# --- The look ----------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_poll -= dt
	if _poll > 0.0:
		return
	_poll = 0.5
	refresh_look()


## The piece's own mesh while set (or not yet set), the sprung one otherwise, the catch in it.
func refresh_look() -> void:
	var st := state()
	var sp := catch_species()
	var key := st + "|" + sp
	if key == _shown:
		return
	_shown = key
	var sprung := st in ["holding", "sprung", "buried"]
	var pc := piece()
	if pc:
		for v: Variant in pc.highlight_targets():
			if v is GeometryInstance3D:
				(v as GeometryInstance3D).visible = not sprung
	if sprung and _sprung == null:
		_sprung = MeshInstance3D.new()
		_sprung.name = "Sprung"
		_sprung.mesh = BuildGeometry.trap_mesh(kind, true)
		add_child(_sprung)
	if _sprung:
		_sprung.visible = sprung
	if _catch:
		_catch.queue_free()
		_catch = null
	if sp != "":
		_catch = TrapCatch.build(sp, String(TrapCatch.POSE.get(kind, "side")))
		_catch.name = "Catch"
		_catch.transform = TrapCatch.place_in(kind, sp)
		add_child(_catch)
