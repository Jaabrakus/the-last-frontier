class_name CampLink
extends Node
## The camp in the world and the survival core (SurvivalBridge.camp; user 2026-09-27: "the campfire and lean-to just
## landed, but they don't warm you yet. They need to tell the bridge when you're near a lit fire or inside a shelter").
##
## Each built campfire (Campfire) and lean-to (a BuiltPiece of the "shelters" group) has a record in the core
## (SurvivalCamp: a fire with its fuel and state, a shelter with its quality) under a location tag of its own
## ("camp.fire.<piece>", "camp.shelter.<piece>"), so the core's fallback, the best fire or shelter at the player's
## location (the whole woods are one), never picks one the player is not at. Four times a second the core is told where
## the player is against them:
##   fire_id, fire_distance_m   the nearest campfire and how far off (none and 99 m beyond FIRE_M). A lit fire warms
##                              (SurvivalNeeds: +22 C at 1 m, +12 at 4 m, nothing at 10 m), dries within 2 m, thaws
##                              numb hands and feet (SurvivalExposure); cooking wants one lit (CampCooking)
##   in_shelter, shelter_id     under a lean-to's roof (BuildGeometry.under_lean_to), quality SHELTER_Q: out of the
##                              wind and the rain, +1.5 C a step, better sleep (SurvivalNeeds.sleep_quality); under a
##                              built roof (a roof piece overhead): walled round (enclosure(): ENCLOSED of the rays out
##                              meet a built wall, door, gate, hearth or palisade), a cabin, quality CABIN_Q; open sides,
##                              an open shelter (ROOF_Q: out of the rain, not the wind's cold)
##   indoors                    in a walled cabin with a lit hearth within INDOOR_M (Campfire.hearth): the core's
##                              indoor air (14 C, no wind, no rain) and an indoor night's sleep
##   bedding                    in a built bed (CampStation: the bough bed, the pole bed), its bedding: warmer while
##                              resting and asleep, a better sleep; with a shelter of 3 or more, a full night's rest
## A new game's context (the line camp: in a shelter, 1.5 m from a fire) is overwritten at once, so no fire or roof that
## is not there warms the player.
## The fire's fuel is its record's, in game minutes (Campfire.FUEL_MIN_PER_WOOD a stick): it burns on the core's clock,
## through a night's sleep too, and the core's wake rule holds (the fire a sleeper lay down by dies down: they wake).
## Sleep: rest_quality() is the core's sleep quality, FIRE_SLEEP_ADD more by a lit fire (its warmth through the night,
## and its smoke keeps the insects off: actions.json world_objects world.campfire insect_relief); SurvivalSleep averages
## it over the sleep and SurvivalBridge.grant_rest turns it into hours of WELL RESTED.

## A campfire this near is the player's fire (beyond it the table gives no warmth).
const FIRE_M := 10.0
## A built lean-to: a pole frame thatched with bark and brush keeps off the rain (the core's shelter rules: 2 blocks the
## wind, 3 keeps off the rain; its own quick brush lean-to is 2).
const SHELTER_Q := 3.0
const SHELTER_KIND := "brush_leanto"
## Under a built roof (the Cabin group's roof piece): a log cabin, better than the core's half-faced camp (4).
const CABIN_Q := 5.0
const CABIN_KIND := "cabin"
## A roof on open sides (a shed, a roof bay on its own): keeps the rain off (the core's rule: 3).
const ROOF_Q := 3.0
const ROOF_KIND := "roof"
## Walls round: rays out at chest height, how far, and the share of them that must meet a wall (a window or an open
## door lets one or two out of eight).
const ENCLOSE_RAYS := 8
const ENCLOSE_M := 7.0
const ENCLOSED := 0.74
const WALL_TYPES := ["wall", "wall_window", "wall_door", "post", "palisade", "palisade_gate", "hearth", "opening_cover", "opening_door", "opening_repair"]
## A lit hearth this near, under a roof: indoors.
const INDOOR_M := 7.0
## Sleep by a lit (or banked) fire within FIRE_SLEEP_M: this much better.
const FIRE_SLEEP_ADD := 0.15
const FIRE_SLEEP_M := 4.0
const EVERY_S := 0.25

var bridge: SurvivalBridge
## The context last told to the core (tests).
var told := {}
var _t := 0.0


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = EVERY_S
	refresh()


## Links the camp pieces to their records and tells the core where the player is against them (now).
func refresh() -> void:
	if bridge == null or bridge.core == null or bridge.player == null or not is_instance_valid(bridge.player):
		return
	var p := bridge.player.global_position
	var best: Campfire = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c == null or not c.is_inside_tree() or c.state == null:
			continue
		link_fire(c)
		var d := Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length()
		if d < bd:
			bd = d
			best = c
	var ctx := {"fire_id": "", "fire_distance_m": 99.0, "in_shelter": false, "shelter_id": "", "bedding": "", "indoors": false}
	if best and bd <= FIRE_M:
		ctx.fire_id = best.fire_id
		ctx.fire_distance_m = snappedf(bd, 0.05)
	var sh := shelter_over(p)
	if sh:
		ctx.in_shelter = true
		var roofed := sh is BuiltPiece and (sh as BuiltPiece).type == "roof"
		var walled := roofed and enclosure(p) >= ENCLOSED
		ctx.shelter_id = shelter_id(sh, walled)
		if walled and lit_hearth_near(p, INDOOR_M) != null:
			ctx.indoors = true
	var bed := bed_at(p)
	if bed:
		ctx.bedding = String(CampStation.BEDDING.get(bed.kind, ""))
	# woodpiles beside fires are their fuel stacks (Woodpile.sync)
	var claimed := {}
	for n in get_tree().get_nodes_in_group(Woodpile.GROUP):
		(n as Woodpile).sync(self, claimed)
	if ctx != told:
		told = ctx
		bridge.set_context(ctx.duplicate())


# --- Fires ----------------------------------------------------------------------------------------------------

## The campfire's record in the core, made when it has none (a new fire, or its record dropped or lost with a load):
## the fire's own laid wood and state go into it.
func link_fire(c: Campfire) -> String:
	var core := bridge.core
	var loc := _tag(c, "fire")
	if c.link == self and c.fire_id != "" and str(SurvivalCamp.fire(core, c.fire_id).get("location", "")) == loc:
		return c.fire_id
	var rec := SurvivalCamp.fire_at(core, loc)
	var id := str(rec.get("id", ""))
	if id == "":
		var fuel := c.fuel_min()
		id = SurvivalCamp.create_fire(core, loc, "out", fuel)
		if c.is_lit() and fuel > 0.0:
			SurvivalCamp.set_fire_state(core, id, "lit")
	c.attach(self, id)
	return id


func fire_record(id: String) -> Dictionary:
	return SurvivalCamp.fire(bridge.core, id) if bridge and bridge.core else {}


func set_fire_state(id: String, fire_state: String) -> void:
	SurvivalCamp.set_fire_state(bridge.core, id, fire_state)
	bridge.core.invalidate_modifiers()


func add_fuel(id: String, minutes: float) -> void:
	var f := fire_record(id)
	if not f.is_empty():
		f["fuel_min"] = float(f.get("fuel_min", 0.0)) + minutes
		bridge.core.invalidate_modifiers()


## The lit hearth fire nearest `pos` within `reach` m, or null.
func lit_hearth_near(pos: Vector3, reach: float) -> Campfire:
	var best: Campfire = null
	var bd := reach
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c == null or not c.hearth or not c.is_lit():
			continue
		var d := c.global_position.distance_to(pos)
		if d <= bd:
			bd = d
			best = c
	return best


## The lit campfire nearest `pos` within `reach` m (flat distance), or null.
func lit_fire_near(pos: Vector3, reach: float) -> Campfire:
	var best: Campfire = null
	var bd := reach
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c == null or not c.is_lit():
			continue
		var d := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if d <= bd:
			bd = d
			best = c
	return best


## F's line in a lit fire's prompt (CampCooking), "" when there is nothing to cook.
func cook_hint(player: Node) -> String:
	return bridge.cook.hint(player) if bridge and bridge.cook else ""


# --- Shelters ---------------------------------------------------------------------------------------------------

## The lean-to the player at `pos` is in (BuildGeometry.under_lean_to), else the built roof over them, or null.
func shelter_over(pos: Vector3) -> Node3D:
	for n in get_tree().get_nodes_in_group(&"shelters"):
		var s := n as Node3D
		if s == null or not s.is_inside_tree() or String(s.get("type")) != "lean_to":
			continue
		if BuildGeometry.under_lean_to(s.global_transform.affine_inverse() * pos):
			return s
	return roof_over(pos)


## The built roof piece right over `pos` (a ray up from the head), or null.
func roof_over(pos: Vector3) -> BuiltPiece:
	var pl := bridge.player
	if pl == null or not pl.is_inside_tree():
		return null
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.UP * 9.0)
	q.exclude = [pl.get_rid()]
	var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var p := BuildMode.piece_of(hit.collider)
	return p if p and p.type == "roof" else null


## The built bed the player at `pos` lies or stands in (CampStation.holds), or null.
func bed_at(pos: Vector3) -> CampStation:
	for n in get_tree().get_nodes_in_group(&"camp_stations"):
		var st := n as CampStation
		if st and st.kind in CampStation.BEDS and st.is_inside_tree() and st.holds(pos):
			return st
	return null


## How walled in `pos` is under a roof: the share of ENCLOSE_RAYS rays out at chest height that meet a built wall,
## door, gate, hearth or palisade within ENCLOSE_M.
func enclosure(pos: Vector3) -> float:
	var pl := bridge.player
	if pl == null or not pl.is_inside_tree():
		return 0.0
	var space := pl.get_world_3d().direct_space_state
	var from := pos + Vector3.UP * 1.2
	var hits := 0
	for i in ENCLOSE_RAYS:
		var a := TAU * i / ENCLOSE_RAYS
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(a), 0.0, sin(a)) * ENCLOSE_M)
		q.exclude = [pl.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var p := BuildMode.piece_of(hit.collider)
		if p and p.type in WALL_TYPES:
			hits += 1
	return float(hits) / float(ENCLOSE_RAYS)


## Where the player is now, in words: "in the lean-to", "in your cabin, warm by the hearth", "in your cabin", "under
## your roof", "" (the last told shelter).
func shelter_word() -> String:
	var sh: Dictionary = SurvivalUtil.dict(SurvivalCamp.shelters(bridge.core).get(str(told.get("shelter_id", ""))))
	if sh.is_empty() or not bool(told.get("in_shelter", false)):
		return ""
	match str(sh.get("type", "")):
		CABIN_KIND:
			return "in your cabin, warm by the hearth" if bool(told.get("indoors", false)) else "in your cabin"
		ROOF_KIND:
			return "under your roof"
	return "in the lean-to"


## The lean-to's shelter record in the core (made the first time the player is in it).
## The shelter's record in the core (made the first time the player is in it). A roof's is a cabin while it is
## `walled`, an open shelter while not: its kind and quality follow the walls built round it or taken down.
func shelter_id(s: Node3D, walled := false) -> String:
	var core := bridge.core
	var loc := _tag(s, "shelter")
	var roof := s is BuiltPiece and (s as BuiltPiece).type == "roof"
	var kind := (CABIN_KIND if walled else ROOF_KIND) if roof else SHELTER_KIND
	var q := (CABIN_Q if walled else ROOF_Q) if roof else SHELTER_Q
	var id := String(s.get_meta(&"survival_shelter", ""))
	var rec: Dictionary = SurvivalUtil.dict(SurvivalCamp.shelters(core).get(id)) if id != "" else {}
	if rec.is_empty() or str(rec.get("location", "")) != loc:
		rec = SurvivalCamp.shelter_at(core, loc)
	if rec.is_empty():
		id = SurvivalCamp.create_shelter(core, loc, kind, q)
		rec = SurvivalCamp.shelters(core)[id]
	id = str(rec.id)
	if roof and (str(rec.get("type", "")) != kind or float(rec.get("quality", 0.0)) != q):
		rec["type"] = kind
		rec["quality"] = q
		core.invalidate_modifiers()
	s.set_meta(&"survival_shelter", id)
	return id


# --- Sleep ------------------------------------------------------------------------------------------------------

## How well the player sleeps here now: the core's sleep quality (shelter, bedding, warmth), FIRE_SLEEP_ADD more by a
## lit or banked fire.
func rest_quality() -> float:
	var core := bridge.core
	var q := SurvivalNeeds.sleep_quality(core)
	if by_fire(FIRE_SLEEP_M):
		q += FIRE_SLEEP_ADD
	return q


## Whether the player's fire (the core's context) burns within `m` m.
func by_fire(m: float) -> bool:
	var f := SurvivalCamp.current_fire(bridge.core)
	var fs := str(f.get("state", ""))
	return (fs == "lit" or fs == "banked") and str(told.get("fire_id", "")) != "" \
			and float(told.get("fire_distance_m", 99.0)) <= m


## A location tag of the piece's own: the built piece's id (BuiltPiece.piece_id), else the node's.
static func _tag(n: Node, what: String) -> String:
	var piece: Node = n if n is BuiltPiece else n.get_parent()
	if piece is BuiltPiece and int(piece.get("piece_id")) > 0:
		return "camp.%s.%d" % [what, int(piece.get("piece_id"))]
	return "camp.%s.n%d" % [what, n.get_instance_id()]
