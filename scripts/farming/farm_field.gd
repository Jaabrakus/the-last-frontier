class_name FarmField
extends Node3D
## Farming (user 2026-09-28: "add farming into the game"; picked: a growing season sped up, hoe any open ground, the
## Three Sisters plus tobacco and flax, a crafted hoe). data/farming/farming.json.
##
## Beds: a square of ground (bed_m) on the world's grid, broken out of open ground with the hoe or the digging stick
## (GatherTools: with the tool in the hand, LMB at the ground in front, target type "ground"; strokes of work by the
## Husbandry skill; the grass goes from it). Open ground is not rock, water, a steep slope, a tree's or a building's
## place; the ground is frozen from December to February.
## A worked bed is sown with E from the seed in the pack (hold E for the list: the Three Sisters when you have corn,
## bean and squash seed, or one crop), from March to October. It grows on the survival core's clock, so a sleep moves
## it on: sprouts, young plants, grown, ripe, in the sowing's grow_days (3 to 4 game days: a third of a month each).
## Weeds come up a third and two thirds of the way; hoeing them out (the hoe again, LMB) raises the harvest, rain on
## the growing bed raises it a little more. Frost (from November) kills whatever is not ripe; E clears the dead plants.
## E on a ripe bed harvests it: the crop into the pack by the yields, a little seed saved back, and the bed is ready to
## sow again. Each step trains Husbandry (GatherSkills), which raises the yield.
## A new character (not a start with nothing) finds a pouch of seed in the pack (seed_pouch), once.
##
## The beds are records in the survival core's world (core.state.world.farm.beds, key "i,j"), so they are saved and
## loaded with it; without a core (a bare test level) they are kept here, on an own clock.
##
##   var farm := FarmField.find(tree)
##   farm.strike(key, power)          # a hoe stroke on a bed (GatherTools)
##   farm.ground_candidates(p, view, hoe_in_hand)   # what the hoe can work in front of the player

signal harvested(key: String, got: Dictionary)
signal changed(key: String)

const GROUP := &"farm_field"
const DATA_PATH := "res://data/farming/farming.json"
const SKILL := "husbandry"
const MAX_ANGLE := 70.0
const HILLS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]
const STAGE_AT := [0.15, 0.5, 1.0]
## Real seconds to a game minute without a core (the core's own rate: 2.4 real minutes a game hour).
const FALLBACK_MIN_PER_S := 60.0 / 144.0

var data := {}
var bed_m := 2.0
## The beds: key "i,j" -> {i, j, work, till, sow, sown, hoed, weed_work, rain, dead}.
var beds := {}
var rng := RandomNumberGenerator.new()

var _core: SurvivalCore
var _player: FrontierPlayer
var _nodes := {}           ## key -> Node3D
var _drawn := {}           ## key -> the state drawn ("till:stage:weeds:dead:sow")
var _offer := {}
var _own_min := 0.0        ## the clock without a core
var _last_min := -1.0
var _last_day := -1
var _tick := 0.0
var _busy := false
## The grass blocker map the beds were last cleared into, and a redraw of it since (a building piece placed or taken
## down: BuildWorld redraws the map from its own copy, the beds' clearing lost), frame it was asked on.
var _grass_tex: ImageTexture
var _grass_dirty_frame := -1
var _build_hooked := false


static func find(tree: SceneTree) -> FarmField:
	return tree.get_first_node_in_group(GROUP) as FarmField if tree else null


static func load_data() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	return d if d is Dictionary else {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	data = load_data()
	bed_m = float(data.get("bed_m", 2.0))
	rng.seed = 1765


# --- The clock and the core ------------------------------------------------------------------------------------

func _bridge() -> SurvivalBridge:
	return SurvivalBridge.find(get_tree()) if is_inside_tree() else null


## Game minutes now (the core's, else this field's own).
func now_min() -> float:
	return float(_core.state.minutes) if _core != null else _own_min


func _in_window(key: String) -> bool:
	var w: Array = data.get(key, [])
	if _core == null or w.size() < 2:
		return key == "sow_window"       # (no calendar: sowing is always open, no frost, no frozen ground)
	return SurvivalClock.in_window(_core, w)


func frozen() -> bool:
	return _in_window("frozen_window")


func can_sow_now() -> bool:
	return _in_window("sow_window") and not _in_window("frost_window")


## The core changed (a new game, a load): the beds are its records now, redrawn.
func _attach(c: SurvivalCore) -> void:
	_core = c
	if c != null:
		var w: Dictionary = c.state.world
		if not w.has("farm") or not (w.farm is Dictionary):
			w["farm"] = {"beds": {}, "pouch": false}
		var f: Dictionary = w.farm
		if not f.has("beds") or not (f.beds is Dictionary):
			f["beds"] = {}
		beds = f.beds
	_last_min = now_min()
	_last_day = -1
	for k: String in _nodes.keys():
		(_nodes[k] as Node).queue_free()
	_nodes.clear()
	_drawn.clear()
	for k: String in beds:
		_redraw(k)


## The seed pouch of a new character (once: the core's farm record remembers it; not for a start with nothing).
func _give_pouch() -> void:
	if _core == null or _player == null or not is_instance_valid(_player):
		return
	var f: Dictionary = _core.state.world.farm
	if bool(f.get("pouch", false)):
		return
	f["pouch"] = true
	var b := _bridge()
	if b and b.is_bare():
		return
	var inv := InventoryState.from_player(_player)
	var pouch: Dictionary = data.get("seed_pouch", {})
	for k: String in pouch:
		inv.add(k, int(pouch[k]))
	_player.inventory_pack = inv.pack.duplicate(true)


# --- The frame ---------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as FrontierPlayer
	var b := _bridge()
	var c: SurvivalCore = b.core if b else null
	if c != _core or (c != null and not is_same(beds, (c.state.world.get("farm", {}) as Dictionary).get("beds"))):
		_attach(c)
	if _core == null:
		_own_min += delta * FALLBACK_MIN_PER_S
	_offer = _find_offer()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_step_time(b)


## Rain on the growing beds, the frost, the drawn stages.
func _step_time(b: SurvivalBridge) -> void:
	if _core != null and not bool((_core.state.world.farm as Dictionary).get("pouch", false)):
		_give_pouch()
	var now := now_min()
	var dmin := maxf(now - _last_min, 0.0) if _last_min >= 0.0 else 0.0
	_last_min = now
	_keep_grass_clear()
	var wet := _core != null and SurvivalWeather.is_wet(_core)
	var day := SurvivalClock.abs_day(_core) if _core else int(now / 1440.0)
	var frost := day != _last_day and _in_window("frost_window")
	_last_day = day
	for k: String in beds:
		var r: Dictionary = beds[k]
		if String(r.get("sow", "")) != "" and not bool(r.get("dead", false)):
			if wet and progress(k) < 1.0:
				r["rain"] = float(r.get("rain", 0.0)) + dmin / 60.0
			if frost and progress(k) < 1.0:
				r["dead"] = true
				changed.emit(k)
		if _state_key(k) != String(_drawn.get(k, "")):
			_redraw(k)


# --- Beds ---------------------------------------------------------------------------------------------------------

static func key_of(i: int, j: int) -> String:
	return "%d,%d" % [i, j]


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / bed_m), floori(p.z / bed_m))


func center_of(i: int, j: int) -> Vector3:
	var x := (i + 0.5) * bed_m
	var z := (j + 0.5) * bed_m
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func bed_center(key: String) -> Vector3:
	var r: Dictionary = beds.get(key, {})
	if r.is_empty():
		var ij := key.split(",")
		return center_of(int(ij[0]), int(ij[1]))
	return center_of(int(r.i), int(r.j))


## How far along the bed's crop is: 0 sown .. 1 ripe (0 with nothing sown).
func progress(key: String) -> float:
	var r: Dictionary = beds.get(key, {})
	var sw := String(r.get("sow", ""))
	if sw == "":
		return 0.0
	var days := float(data.sowings.get(sw, {}).get("grow_days", 4.0))
	return clampf((now_min() - float(r.get("sown", 0.0))) / (days * SurvivalClock.MIN_PER_DAY), 0.0, 1.0)


func stage_of(key: String) -> int:
	var p := progress(key)
	for s in STAGE_AT.size():
		if p < float(STAGE_AT[s]):
			return s
	return 3


## Weeds up and not yet hoed out (0 .. 2): one a third of the way, one two thirds, until the crop is ripe.
func weeds_due(key: String) -> int:
	var r: Dictionary = beds.get(key, {})
	if String(r.get("sow", "")) == "" or bool(r.get("dead", false)):
		return 0
	var p := progress(key)
	if p >= 1.0:
		return 0
	var n := 0
	for t in data.get("weed_thresholds", [0.33, 0.66]):
		if p >= float(t):
			n += 1
	return maxi(n - int(r.get("hoed", 0)), 0)


func state_of(key: String) -> String:
	var r: Dictionary = beds.get(key, {})
	if r.is_empty():
		return "ground"
	if float(r.get("till", 0.0)) < 1.0:
		return "breaking"
	if String(r.get("sow", "")) == "":
		return "tilled"
	if bool(r.get("dead", false)):
		return "dead"
	return "ripe" if progress(key) >= 1.0 else "growing"


## Ground fit for a bed: on the terrain in the world, gentle, dry, clear of trees, rocks and buildings.
func ground_ok(i: int, j: int) -> bool:
	var c := center_of(i, j)
	var half := bed_m * 0.5
	if absf(c.x) > FrontierTerrain.WORLD_HALF - 10.0 or absf(c.z) > FrontierTerrain.WORLD_HALF - 10.0:
		return false
	for o: Vector2 in [Vector2.ZERO, Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		var q := Vector3(c.x + o.x * 0.9, 0.0, c.z + o.y * 0.9)
		if FrontierTerrain.normal_at(q.x, q.z).y < float(data.get("max_slope_y", 0.9)):
			return false
		if WorldRiver.depth_at(q) > 0.0:
			return false
	var hv := VegHarvest.find(get_tree())
	if hv:
		for d: Dictionary in hv.near(c, half + 0.5):
			var pos: Vector3 = d.pos
			var rr := float(d.get("radius", 0.3)) + 0.15
			if absf(pos.x - c.x) < half + rr and absf(pos.z - c.z) < half + rr:
				return false
	if not is_inside_tree():
		return true
	var box := BoxShape3D.new()
	box.size = Vector3(bed_m - 0.1, 1.0, bed_m - 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, c + Vector3.UP * 0.8)
	if _player and is_instance_valid(_player):
		q.exclude = [_player.get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var col := hit.collider as Node
		if col == null or col.is_in_group(&"terrain") or col is CharacterBody3D:
			continue
		return false
	return true


# --- The hoe (GatherTools) -----------------------------------------------------------------------------------------

## What the hoe can work in front of the player: the beds in reach that want breaking or weeding, and (`in_hand`: the
## hoe out) the open ground where it aims. GatherTools candidate dictionaries (type "ground").
func ground_candidates(p: Vector3, view: Vector3, in_hand: bool) -> Array:
	var out: Array = []
	var reach := float(data.get("reach_m", 2.2))
	var c0 := cell_of(p)
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var k := key_of(c0.x + di, c0.y + dj)
			if not beds.has(k):
				continue
			var st := state_of(k)
			if st == "breaking" or (st == "growing" and weeds_due(k) > 0):
				var cd := _describe(k, p)
				if float(cd.dist) <= reach:
					out.append(cd)
	if in_hand:
		var aim := p + view * float(data.get("aim_m", 1.3))
		var cell := cell_of(aim)
		var k := key_of(cell.x, cell.y)
		if not beds.has(k):
			var cd := _describe(k, p)
			cd["point"] = Vector3(aim.x, FrontierTerrain.height_at(aim.x, aim.z), aim.z)
			cd["dist"] = 0.4
			cd["fresh"] = true
			out.append(cd)
		elif state_of(k) in ["tilled", "ripe", "dead"] or (state_of(k) == "growing" and weeds_due(k) == 0):
			pass
	return out


## A bed as a GatherTools target ({} when there is nothing for the hoe to do there now).
func describe(key: String, p: Vector3) -> Dictionary:
	if beds.has(key):
		var st := state_of(key)
		if not (st == "breaking" or (st == "growing" and weeds_due(key) > 0)):
			return {}
	var d := _describe(key, p)
	if not beds.has(key):
		d["dist"] = 0.4
		d["fresh"] = true
	return d


func _describe(key: String, p: Vector3) -> Dictionary:
	var c := bed_center(key)
	var half := bed_m * 0.5
	var nearest := Vector3(clampf(p.x, c.x - half, c.x + half), c.y, clampf(p.z, c.z - half, c.z + half))
	var dist := Vector2(nearest.x - p.x, nearest.z - p.z).length()
	var pt := c if dist < 0.3 else nearest.lerp(c, 0.35)
	pt.y = FrontierTerrain.height_at(pt.x, pt.z)
	return {"type": "ground", "src": "farm", "key": key, "i": hash(key), "pos": c, "radius": half, "dist": dist,
			"point": pt, "normal": Vector3.UP, "name": "ground"}


## The bottom prompt for a hoe target.
func hoe_prompt(key: String) -> String:
	if frozen():
		return "The ground is frozen hard"
	var st := state_of(key)
	match st:
		"ground":
			var ij := key.split(",")
			if not ground_ok(int(ij[0]), int(ij[1])):
				return "No room for a bed here"
			return "Break ground for a bed"
		"breaking":
			return "Break ground for a bed  %d%%" % int(float(beds[key].till) * 100.0)
		"growing":
			var r: Dictionary = beds[key]
			var w := float(r.get("weed_work", 0.0)) / float(data.get("weed_work", 2.0))
			return "Hoe the weeds out of the %s%s" % [_crops_words(String(r.sow)), "" if w <= 0.0 else "  %d%%" % int(w * 100.0)]
	return ""


## A stroke of the hoe (or the digging stick) worth `power`: breaks ground (a new bed where there was none), or hoes
## out the weeds. {event: "", "broke", "tilled", "weeded", "frozen", "blocked"}.
func strike(key: String, power: float) -> Dictionary:
	if frozen():
		return {"event": "frozen"}
	var ij := key.split(",")
	var i := int(ij[0])
	var j := int(ij[1])
	if not beds.has(key):
		if not ground_ok(i, j):
			return {"event": "blocked"}
		beds[key] = {"i": i, "j": j, "work": 0.0, "till": 0.0, "sow": "", "sown": 0.0, "hoed": 0, "weed_work": 0.0,
				"rain": 0.0, "dead": false}
		_clear_grass([Vector2i(i, j)])
	var r: Dictionary = beds[key]
	var ev := "broke"
	match state_of(key):
		"breaking":
			r["work"] = float(r.get("work", 0.0)) + power
			r["till"] = clampf(float(r.work) / float(data.get("till_work", 5.0)), 0.0, 1.0)
			if float(r.till) >= 1.0:
				ev = "tilled"
		"growing":
			if weeds_due(key) <= 0:
				return {"event": ""}
			r["weed_work"] = float(r.get("weed_work", 0.0)) + power
			ev = ""
			if float(r.weed_work) >= float(data.get("weed_work", 2.0)):
				r["weed_work"] = 0.0
				r["hoed"] = int(r.get("hoed", 0)) + 1
				ev = "weeded"
		_:
			return {"event": ""}
	_redraw(key)
	changed.emit(key)
	return {"event": ev}


# --- Sowing and harvesting (E) -------------------------------------------------------------------------------------

func sowing_name(id: String) -> String:
	return String(data.sowings.get(id, {}).get("name", id))


## The sowings the pack has seed for, best first (the Three Sisters when there is seed for all three).
func sowings_for(p: Node) -> Array:
	var out: Array = []
	if p == null:
		return out
	var inv := InventoryState.from_player(p)
	for id: String in data.get("order", []):
		var need: Dictionary = data.sowings[id].get("seeds", {})
		var ok := true
		for s: String in need:
			if inv.pack_count(s) < int(need[s]):
				ok = false
		if ok:
			out.append(id)
	return out


## Sows `id` in the bed (the seed out of the pack). False when it cannot.
func sow(key: String, id: String, p: Node) -> bool:
	if state_of(key) != "tilled" or not can_sow_now() or not data.sowings.has(id) or not (id in sowings_for(p)):
		return false
	var inv := InventoryState.from_player(p)
	var need: Dictionary = data.sowings[id].seeds
	for s: String in need:
		inv.take(s, int(need[s]))
	p.set("inventory_pack", inv.pack.duplicate(true))
	var r: Dictionary = beds[key]
	r["sow"] = id
	r["sown"] = now_min()
	r["hoed"] = 0
	r["weed_work"] = 0.0
	r["rain"] = 0.0
	r["dead"] = false
	_award("sown")
	_redraw(key)
	changed.emit(key)
	return true


## What a ripe bed gives now: {pack kind: count} (the crops by the yields, the weeding, the rain and the skill; a little
## seed saved back).
func harvest_yield(key: String) -> Dictionary:
	var r: Dictionary = beds[key]
	var sw: Dictionary = data.sowings.get(String(r.sow), {})
	var mult := float(data.get("yield_base", 0.8)) + float(data.get("yield_per_weeding", 0.1)) * mini(int(r.get("hoed", 0)), 2)
	mult *= 1.0 + float(data.get("rain_bonus", 0.1)) * clampf(float(r.get("rain", 0.0)) / float(data.get("rain_hours_full", 12.0)), 0.0, 1.0)
	mult *= 1.0 + float(data.get("skill_yield_at_100", 0.5)) * _skill_level() / 100.0
	mult *= float(sw.get("bonus", 1.0))
	var sisters := (sw.get("crops", []) as Array).size() > 1
	var got := {}
	for c: String in sw.get("crops", []):
		var cd: Dictionary = data.crops[c]
		var y: Array = cd.get("sisters_yield", cd.yield) if sisters else cd.yield
		var n := maxi(roundi(rng.randi_range(int(y[0]), int(y[1])) * mult), 1)
		got[String(cd.item)] = int(got.get(String(cd.item), 0)) + n
		var sb: Array = cd.get("seed_back", [1, 1])
		var sn := rng.randi_range(int(sb[0]), int(sb[1]))
		if sn > 0:
			got[String(cd.seed)] = int(got.get(String(cd.seed), 0)) + sn
	return got


## Harvests a ripe bed into the pack; the bed is worked ground again, ready to sow. {kind: count}, {} when not ripe.
func harvest(key: String, p: Node) -> Dictionary:
	if state_of(key) != "ripe":
		return {}
	var got := harvest_yield(key)
	var g: Variant = p.get("gather") if p else null
	for k: String in got:
		if g is GatherTools:
			(g as GatherTools).give(k, int(got[k]))
		else:
			var inv := InventoryState.from_player(p)
			inv.add(k, int(got[k]))
			p.set("inventory_pack", inv.pack.duplicate(true))
	_award("harvest")
	_clear(key)
	harvested.emit(key, got)
	return got


## The bed back to worked, empty ground (after a harvest, or the frost-killed plants pulled).
func _clear(key: String) -> void:
	var r: Dictionary = beds[key]
	r["sow"] = ""
	r["dead"] = false
	r["hoed"] = 0
	r["weed_work"] = 0.0
	r["rain"] = 0.0
	_redraw(key)
	changed.emit(key)


# --- The interactor (E) ------------------------------------------------------------------------------------------

## The bed E offers now: {key, point, text, can, act}, or {}. Beds the hoe works (breaking ground, weeds up with a hoe
## to hand) are GatherTools' to offer.
func _find_offer() -> Dictionary:
	var p := _player
	if p == null or p.is_dead or p.riding != null or _busy or beds.is_empty():
		return {}
	var yaw := p.yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var reach := float(data.get("reach_m", 2.2))
	var c0 := cell_of(p.global_position)
	var best := {}
	var best_s := INF
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var k := key_of(c0.x + di, c0.y + dj)
			if not beds.has(k):
				continue
			var st := state_of(k)
			if st == "breaking":
				continue
			var d := _describe(k, p.global_position)
			if float(d.dist) > reach:
				continue
			var to: Vector3 = d.pos - p.global_position
			var ang := 0.0
			if float(d.dist) > 0.2 and Vector2(to.x, to.z).length() > 0.3:
				ang = rad_to_deg(fwd.angle_to(Vector3(to.x, 0.0, to.z).normalized()))
				if ang > MAX_ANGLE:
					continue
			var s := ang / MAX_ANGLE + float(d.dist) / reach
			if s < best_s:
				best_s = s
				best = {"key": k, "point": d.point, "state": st}
	if best.is_empty():
		return {}
	var k2 := String(best.key)
	var r: Dictionary = beds[k2]
	match String(best.state):
		"tilled":
			var opts := sowings_for(p)
			if not can_sow_now():
				best["can"] = false
				best["text"] = "Worked ground (too late in the year to sow)" if not frozen() else "Worked ground (frozen)"
			elif opts.is_empty():
				best["can"] = false
				best["text"] = "Worked ground (no seed in the pack)"
			else:
				best["can"] = true
				best["act"] = "sow:" + String(opts[0])
				best["text"] = String(data.sowings[opts[0]].text) + _late_note(String(opts[0]))
		"growing":
			if weeds_due(k2) > 0 and _has_hoe():
				return {}
			best["can"] = false
			best["text"] = "%s growing%s" % [_crops_words(String(r.sow)).capitalize(), _when_ripe(k2)]
		"ripe":
			best["can"] = true
			best["act"] = "harvest"
			best["text"] = "Harvest the %s" % _crops_words(String(r.sow))
		"dead":
			best["can"] = true
			best["act"] = "clear"
			best["text"] = "Pull up the frost-killed %s" % _crops_words(String(r.sow))
	return best


func _has_hoe() -> bool:
	var g: Variant = _player.get("gather") if _player else null
	return g is GatherTools and (g as GatherTools).owns("hoe")


func _crops_words(sw: String) -> String:
	var cs: Array = data.sowings.get(sw, {}).get("crops", [])
	var names: Array = []
	for c: String in cs:
		names.append(String(data.crops[c].name))
	if names.size() <= 1:
		return String(names[0]) if not names.is_empty() else sw
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + String(names[-1])


## " (ripe in about 2 days)" and weeds, for a growing bed's line.
func _when_ripe(key: String) -> String:
	var r: Dictionary = beds[key]
	var days := float(data.sowings.get(String(r.sow), {}).get("grow_days", 4.0)) * (1.0 - progress(key))
	var when := "ripe by tomorrow" if days <= 1.0 else "ripe in about %d days" % ceili(days)
	var w := weeds_due(key)
	return " (%s%s)" % [when, ", weeds coming up: hoe them out" if w > 0 else ""]


## A warning on a late sowing: it will not ripen before the frost.
func _late_note(id: String) -> String:
	if _core == null:
		return ""
	var fw: Array = data.get("frost_window", [])
	if fw.is_empty():
		return ""
	var until := SurvivalClock.days_until(_core, String(fw[0]))
	if until >= 0 and float(until) < float(data.sowings[id].get("grow_days", 4.0)):
		return "  (late: the frost may take it)"
	return ""


func interact_point() -> Vector3:
	return _offer.get("point", Vector3.INF)


func distance_from(pt: Vector3) -> float:
	if _offer.is_empty():
		return INF
	var q: Vector3 = _offer.point
	return Vector2(q.x - pt.x, q.z - pt.z).length()


func interact_prompt(_p: Node) -> String:
	return String(_offer.get("text", ""))


## No glow: the prompt names the bed.
func highlight_targets() -> Array:
	return []


## The hold-E list on a worked bed: every sowing the pack has seed for.
func interact_actions(p: Node) -> Array:
	if _offer.is_empty() or String(_offer.get("state", "")) != "tilled" or not bool(_offer.get("can", false)):
		return []
	var out: Array = []
	for id: String in sowings_for(p):
		out.append({"id": "sow:" + id, "text": String(data.sowings[id].text) + _late_note(id)})
	return out


func interact_action(p: Node, id: String) -> void:
	_do(p, String(_offer.get("key", "")), id)


func interact(p: Node) -> bool:
	if _offer.is_empty():
		return false
	if not bool(_offer.get("can", false)):
		_notice(String(_offer.get("text", "")))
		return false
	return _do(p, String(_offer.key), String(_offer.get("act", "")))


## Sowing, harvesting and clearing are a little work on the knees (StationWork's bar), done when it fills.
func _do(p: Node, key: String, act: String) -> bool:
	if key == "" or act == "" or _busy:
		return false
	var b := _bridge()
	var secs := 3.0 if act.begins_with("sow:") else (4.0 if act == "harvest" else 2.0)
	var text := "Sowing the %s" % sowing_name(act.trim_prefix("sow:")) if act.begins_with("sow:") else \
			("Harvesting the %s" % _crops_words(String(beds[key].sow)) if act == "harvest" else "Pulling up the dead plants")
	var finish := func(ok: bool) -> void:
		_busy = false
		if ok:
			_finish(p, key, act)
	if b and b.work and b.work.begin(bed_center(key), "low", text, secs, "", finish):
		_busy = true
		return true
	_finish(p, key, act)
	return true


func _finish(p: Node, key: String, act: String) -> void:
	if not beds.has(key):
		return
	if act.begins_with("sow:"):
		var id := act.trim_prefix("sow:")
		if sow(key, id, p):
			_notice("Sown: %s. Ripe in about %d days." % [sowing_name(id), int(data.sowings[id].get("grow_days", 4.0))])
	elif act == "harvest":
		harvest(key, p)
	elif act == "clear" and state_of(key) == "dead":
		_clear(key)


func _notice(text: String) -> void:
	var it: Variant = _player.get("interactor") if _player else null
	if it and (it as Node).has_method(&"notice"):
		(it as Node).call(&"notice", text)


# --- Skill -----------------------------------------------------------------------------------------------------

func _skills() -> GatherSkills:
	var g: Variant = _player.get("gather") if _player else null
	return (g as GatherTools).skills if g is GatherTools else null


func _skill_level() -> float:
	var s := _skills()
	return float(s.level(SKILL)) if s else 0.0


func _award(event: String) -> void:
	var s := _skills()
	if s:
		s.award(SKILL, s.xp(SKILL, event))


# --- Drawing ------------------------------------------------------------------------------------------------------

func _state_key(key: String) -> String:
	var r: Dictionary = beds.get(key, {})
	return "%d:%d:%d:%s:%s" % [int(float(r.get("till", 0.0)) * 10.0), stage_of(key), weeds_due(key), r.get("dead", false), r.get("sow", "")]


func _redraw(key: String) -> void:
	if not beds.has(key):
		return
	var old: Variant = _nodes.get(key)
	if old is Node and is_instance_valid(old):
		(old as Node).queue_free()
	_drawn[key] = _state_key(key)
	if DisplayServer.get_name() == "headless":
		return
	var r: Dictionary = beds[key]
	var c := bed_center(key)
	var root := Node3D.new()
	root.name = "Bed_" + key.replace(",", "_")
	add_child(root)
	root.global_position = c
	var till := float(r.get("till", 0.0))
	var sw := String(r.get("sow", ""))
	var hills: Array = [] if till < 1.0 or sw == "flax" else HILLS
	var soil := MeshInstance3D.new()
	soil.name = "Soil"
	soil.mesh = FarmModels.bed_mesh(bed_m * clampf(0.45 + 0.55 * till, 0.45, 1.0), hills,
			func(x: float, z: float) -> float: return FrontierTerrain.height_at(c.x + x, c.z + z) - c.y, clampf(till, 0.3, 1.0), hash(key))
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(soil)
	if sw != "":
		var stage := stage_of(key)
		var dead := bool(r.get("dead", false))
		var crops: Array = data.sowings.get(sw, {}).get("crops", [])
		for h in HILLS.size():
			var hp: Vector2 = HILLS[h]
			var v := (hash(key) + h) % 3
			for cr: String in crops:
				if cr == "squash" and crops.size() > 1 and h % 2 == 1:
					continue                     # (the sisters' squash in every other hill: its vines fill the rest)
				var kind := cr
				if cr == "beans" and not ("corn" in crops):
					kind = "bush_beans"
				var mi := MeshInstance3D.new()
				mi.mesh = FarmModels.crop_mesh(kind, stage, v, dead)
				root.add_child(mi)
				var hy := FrontierTerrain.height_at(c.x + hp.x, c.z + hp.y) - c.y + (0.07 if sw != "flax" else 0.02)
				mi.position = Vector3(hp.x, hy, hp.y)
				mi.rotation.y = float((hash(key) + h * 97) % 628) / 100.0
		if weeds_due(key) > 0:
			var wm := MeshInstance3D.new()
			wm.mesh = FarmModels.weeds_mesh(hash(key) % 3)
			root.add_child(wm)
			wm.position = Vector3(0.0, 0.03, 0.0)
	_nodes[key] = root


## The beds keep the grass off: cleared again when the level's blocker map is new (the level built, a load) or has been
## redrawn by BuildWorld (a piece placed or taken down).
func _keep_grass_clear() -> void:
	if not _build_hooked:
		var bw := BuildWorld.of(get_tree(), false) if is_inside_tree() else null
		if bw:
			bw.changed.connect(func() -> void: _grass_dirty_frame = Engine.get_process_frames())
			_build_hooked = true
	var tex := _blocker_tex()
	if tex == null or beds.is_empty():
		return
	var redrawn := _grass_dirty_frame >= 0 and Engine.get_process_frames() > _grass_dirty_frame + 2
	if tex == _grass_tex and not redrawn:
		return
	_grass_dirty_frame = -1
	var cells: Array = []
	for k: String in beds:
		cells.append(Vector2i(int(beds[k].i), int(beds[k].j)))
	_clear_grass(cells)


func _blocker_tex() -> ImageTexture:
	var terrain := get_parent().get_node_or_null("Terrain") if get_parent() else null
	var g: Variant = terrain.get("grass") if terrain else null
	if not (g is FrontierGrass) or (g as FrontierGrass).material == null:
		return null
	var tex: Variant = (g as FrontierGrass).material.get_shader_parameter("blocker_map")
	return tex as ImageTexture


## The grass off the beds at `cells` (the terrain's grass blocker map, as ForageField clears it under the plants).
func _clear_grass(cells: Array) -> void:
	var tex := _blocker_tex()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.get_format() != Image.FORMAT_R8:
		return
	var n := img.get_width()
	var buf := img.get_data()
	var res := FrontierGrass.BLOCK_RES
	var half := FrontierGrass.BLOCK_HALF
	for c: Vector2i in cells:
		var x0 := c.x * bed_m - 0.1
		var z0 := c.y * bed_m - 0.1
		var i0 := clampi(int(floor((x0 + half) / res)), 0, n - 1)
		var i1 := clampi(int(floor((x0 + bed_m + 0.2 + half) / res)), 0, n - 1)
		var j0 := clampi(int(floor((z0 + half) / res)), 0, n - 1)
		var j1 := clampi(int(floor((z0 + bed_m + 0.2 + half) / res)), 0, n - 1)
		for jj in range(j0, j1 + 1):
			for ii in range(i0, i1 + 1):
				buf[jj * n + ii] = 255
	tex.update(Image.create_from_data(n, n, false, Image.FORMAT_R8, buf))
	_grass_tex = tex
