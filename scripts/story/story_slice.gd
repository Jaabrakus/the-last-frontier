class_name StorySlice
extends Node
## The vertical slice wired (docs/main_story.md 15 item 1: Two Fires, missions 1-12 and 14 on the valley's two baked
## squares): the stages built alongside (RaidStage, MarchStage, WreckFall, RookWalk, SwayCaster, StoryLayer) called from
## the missions' data (data/story/missions/two_fires.json `_flow.new_effects`, the `lock_cast` kind), and put back after
## a load. StoryEffects hands it the effects; StoryObjectives the lock_cast kind; StoryDirector calls storyline_began()
## as a storyline begins or a save brings it back, and restore() once that save is all in.
##
## THE EFFECTS (each safe to do again: a mission's retry does its start effects again, freeing what they made first):
##   title_card   {text, title?}: a card before the mission's intro cards (StoryDirector.lead_cards)
##   raid_staged  {home, ford, farms, capture, hour?, who? {farm place: {name, look}}}: RaidStage.begin; the warned families'
##                farms first (its i-th neighbour waits by its i-th farm, so the ones waiting are the ones who listened, each
##                in the name and look `who` gives his family's farm: those The Third Warning showed); after a load the raid
##                goes on as it was (RaidStage's resume: the clock left, the neighbours as they were, taken already or not)
##   march        {route [[x, z], ...], captor_tag, camp}: MarchStage.begin with the raid's Leclerc and its two marines; the
##                raid's raiders off the farms (RaidStage.withdraw); the camp's fire kept (CAMP_FIRE_FLAG) for a load
##   wreck_fall   {place, camp?, tear_s?}: the second fire (the owner, 2026-10-02: "two air ships fighting, they break the
##                sky and one crashes down"): SkyBattle.begin seen from the camp (the place `camp`, raiders_camp by default)
##                over the place (the 1757 layer's level bench there, wreck_site, and its yaw when the layer is on): two
##                sky ships fight high in the camp's north-north-east sky; the great shot strikes the sky beside the
##                wonder's giant (its sky_mark: WonderLook.giant_dir, where it stands that night) and the sky cracks there
##                (SkyTear.begin, held: a small star of cracks while the cutter falls; the battle's flashes on it:
##                SkyTear.flash) and the story's flag `wonder` is set (the reveal: no wonder_reveal after it); the cutter
##                falls burning into the pines (WreckFall.begin_from: the existing fall, and the wreck); as it lands the
##                tear is let go and runs on over the rest of tear_s (TEAR_S), opening over the giant first, then the whole
##                sky; the hunter climbs into the break and is gone. The camp: the guards stop watching the captives, all
##                of them follow the fight (the guards' muskets up at it, Leclerc craning, Jost on his feet: MarchStage
##                look_at_point), shout at its beats (MarchStage.cry: the guns, the sky struck, the cutter hit) and as the
##                cutter comes down the guards break for the pines, Leclerc shouting after them (MarchStage.scatter). The
##                weather is held clear (clear_sky) through the look up at the broken sky. The player keeps control.
##                Where it lies is kept (WRECK_FLAG) as it begins; a save made while the battle is on (in the watch step,
##                the sky not yet open: SKY_OPEN_FLAG) loads with the battle played again from its start. A step with
##                `hold`: "sky_battle" (Two Fires' watch) counts its seconds only once the cutter is down and the sky open
##                (held), never fails meanwhile, and its marker is on the fight (watch_point)
##   clear_sky    {until}: the weather clear now and held so until the mission is past its step `until` (CLEAR_FLAG keeps
##                what it was: then it comes back in, softly); a load holds it again
##   rook_join    {to, via?}: Rook (no shadow, tag rook) walks from where the wreck pinned him toward `to` by `via` (RookWalk:
##                the wolves come at the first `via` point, his Gust drives them off: the flag GUSTED_FLAG); {place}: he
##                stands there
##   sway_grant   {move}: SwayCaster.grant(move): the spell goes to the Tab screen's Spells list (the player drags it onto 1-9)
##   end_stages   {stages: ["raid", "march", "rook", "lesson"]}: those stages gone from the world (the raid over, the camp
##                scattered, Rook to the cellar, First Lesson's targets off the ice)
##   people       {place, face? [dx, dz], who: [{tag, name, look (a peoples preset), child?, at [dx, dz], face?}]}: the
##                people a talk at the place is with, standing there (StoryWalker, group story_people; none of them fight)
##                while the mission lasts; the flag HERE_FLAG + tag holds the place meanwhile (a contact of the same person
##                elsewhere hides by it: Margaretha's post at the fort, `"if": "!tf.here.margaretha"`)
##   cache_back   {}: what The Third Warning's cache keeps (tf.cache.<kind> = how many) given back (once a mission)
## What an effect made is the mission's (StoryDirector.keep_spawned): gone on a retry; a save keeps that it was there, and a
## load makes it again (after the whole save is in: the player's place, the captivity).
## THE LOCK: `lock_cast` steps count SwayCaster's casts on the target's tag; a missing target of First Lesson (the lantern,
## the hat on its post, a wolf running across the ice) is put at the step's place. The first lock on the wreck's spar lets
## the stranger crawl out from under it (WreckFall.spar_cast; the Sway lifts the spar itself and sets it down at
## spar_aside(): out along its length from the hull and past his feet, clear of him).
## AFTER A LOAD (restore): the wreck laid where it fell (its spar lying aside once lifted, the stranger gone with you after
## that night), and the sky open (the flag `wonder`); the camp round its fire (where it was: CAMP_FIRE_FLAG) while the player
## is still its captive in Two Fires, its eyes on the wreck once it has come down; the weather held clear again (clear_sky).
## A save made during the battle (Two Fires' watch step, the sky not yet open: no SKY_OPEN_FLAG) plays the battle again from
## its start (the sky shut again, no wreck laid: the fire step's wreck_fall once more), so no load skips the reveal.

const GROUP := &"story_slice"
const WRECK_FLAG := "tf.wreck"
const GUSTED_FLAG := "tf.rook_gusted"
## The march's crust has been shared (MarchStage.crust_shared): a march begun again after a load does not share another.
const CRUST_FLAG := "tf.crust_shared"
## Where the raiders' camp fire was lit ([x, z]): a load puts it back there.
const CAMP_FIRE_FLAG := "tf.camp_fire"
## The people effect's walker of `tag` stands at a place (HERE_FLAG + tag: the place's name) while its mission lasts.
const HERE_FLAG := "tf.here."
## The cache given back (cache_back).
const CACHE_PREFIX := "tf.cache."
## The spar set down out along its length from the hull, and past the stranger's feet (m): clear of him and of the hull.
const SPAR_OUT_M := 4.0
const SPAR_FEET_M := 1.6
## The layer's bench is taken for the wreck when it is this near the place named.
const BENCH_M := 40.0
## First Lesson's targets: where each stands from the step's place (east bank: +x away from the river).
const LANTERN_OFF := Vector3(-3.0, 0.0, -4.0)
const HAT_OFF := Vector3(1.5, 0.0, 6.0)
const WOLF_TAG := "wolf"
## The running wolf crosses this far out from the place, along z, and is sent across again whenever it stands.
const WOLF_RUN := Vector3(7.0, 0.0, 22.0)
const WATCH_S := 0.5
## The people effect's walkers (gone again once the mission that made them is over).
const PEOPLE_GROUP := &"slice_people"
## The story's flag for the sky opened (StoryDirector: kept in the save, a load opens the sky at once).
const WONDER_FLAG := "wonder"
## The sky battle is over and the sky open (the watch's hold let go): a load in the watch step without it plays the battle
## again.
const SKY_OPEN_FLAG := "tf.sky_open"
## The weather held clear (clear_sky): [the weather it was, the step it is held through, the mission].
const CLEAR_FLAG := "tf.clear_sky"
## The sky battle's tear: the seconds it would take from the point struck to the wonder holding all of it (SkyTear.begin;
## the effect's tear_s), at the battle's clock. It is held small while the cutter falls (SkyTear's hold) and runs on as
## it lands: ~12 s from the landing to the whole sky open (the wonder fading in over its last 30 %, SkyTear.REVEAL_AT).
const TEAR_S := 13.0
## A step's `hold` while the sky battle is on (held).
const HOLD_BATTLE := "sky_battle"

var director: StoryDirector
var caster: SwayCaster
var _t := 0.0
var _wolf: WildAnimal
var _wolf_t := 0.0
var _wolf_side := 1.0
## A sky battle has been begun and its hold not yet seen let go (SKY_OPEN_FLAG then).
var _battle_on := false


static func find(tree: SceneTree) -> StorySlice:
	return tree.get_first_node_in_group(GROUP) as StorySlice if tree else null


# --- The director's hooks -------------------------------------------------------------------------------------------

## A storyline has begun (or a save brought it back): its world layer (the storyline's world.layer: StoryLayer.apply; a
## load finds the pieces already there), the player's Sway caster, and this node under the director.
static func storyline_began(d: StoryDirector) -> StorySlice:
	var tree := d.get_tree()
	var layer := String((d.line.get("world", {}) as Dictionary).get("layer", "")) if d.line.get("world") is Dictionary else ""
	if layer != "" and tree.current_scene != null:
		StoryLayer.apply(tree.current_scene, layer)
	var s := d.get_node_or_null("Slice") as StorySlice
	if s == null:
		s = StorySlice.new()
		s.name = "Slice"
		s.director = d
		d.add_child(s)
	s._install_caster()
	return s


## After a load (deferred: the player, the captivity and the rest of the save are in by then): the wreck, the camp.
## Test jumps (StoryDirector.jump_at, the user arg story_at=): a mission's date and hour for the new game's clock.
const JUMPS := {
	"m.tf.two_fires": {"year": 1757, "day": "nov_mid", "hour": 20.6},
}


## The world as a jumped-to mission finds it (a new game started at it: StoryDirector.jump_at). Two Fires: the raiders'
## camp at its fire, the player bound beside Leclerc, the battle's models loading.
static func jump_setup(d: StoryDirector, id: String) -> void:
	if d == null or not is_instance_valid(d) or not d.is_inside_tree():
		return
	var tree := d.get_tree()
	var level := tree.current_scene
	var player := StoryObjectives.player(tree)
	match id:
		"m.tf.two_fires":
			SkyBattle.preload_models()
			var camp: Variant = _place(d, "raiders_camp")
			if not (camp is Vector3) or player == null:
				push_warning("Story: no camp or player for the jump to %s" % id)
				return
			player.global_position = _ground((camp as Vector3) + Vector3(2.5, 0.0, 1.5)) + Vector3.UP * 0.1
			var ms := MarchStage.begin(level, [camp], {"camp": camp, "march_hours": 0.0, "crust_at": -1.0})
			var cap := Captivity.install(level)
			if cap and not cap.active:
				cap.begin(player, ms.leclerc if ms else null, {"notice": ""})
			print("STORY JUMP %s: at the raiders' camp, bound" % id)


static func restore(d: StoryDirector) -> void:
	if d == null or not is_instance_valid(d) or not d.is_inside_tree():
		return
	var tree := d.get_tree()
	var level := tree.current_scene
	var id := String(d.mission().get("id", ""))
	_free_hands(StoryObjectives.player(tree))
	if id in ["m.tf.march", "m.tf.two_fires"]:
		SkyBattle.preload_models()                    # (the battle to come: its models on a worker thread meanwhile)
	var w: Variant = d.flag(WRECK_FLAG)
	_wreck_place(d)
	_hold_weather(d)
	# saved while the battle was on (the watch, the sky not yet open): it plays again from its start, the sky shut again
	var replay := w is Array and id == "m.tf.two_fires" and d.phase == StoryDirector.Phase.STEPS \
			and d.step_i == d._step_index("watch") and not StoryObjectives.truthy(d.flag(SKY_OPEN_FLAG))
	if replay:
		d.set_flag(WONDER_FLAG, null)
		var rig0 := d._rig()
		if rig0 != null:
			rig0.set_wonder(0.0)
		w = null
	if w is Array and not StoryObjectives.truthy(d.flag(WONDER_FLAG)):
		# (a game from before the battle, whose sky opened later at the keel: the wreck down, the sky open)
		d.set_flag(WONDER_FLAG)
		var rig := d._rig()
		if rig != null:
			rig.set_wonder(1.0)
	if w is Array and (w as Array).size() >= 3 and WreckFall.find(tree) == null:
		var at := _ground(Vector3(float(w[0]), 0.0, float(w[1])))
		var later := d._mission_index(id) > d._mission_index("m.tf.man_no_shadow")
		var wf := WreckFall.place_wreck(level, at, float(w[2]), 0.0 if later else 1.0)
		if wf != null:
			_spar_meta(wf)
			if StoryObjectives.truthy(d.flag("tf.spar_lifted")):
				set_spar_down(wf)                       # (lying aside where the Sway set it: the stranger up)
				if id != "m.tf.two_fires" and wf.rook() != null:
					_hide(wf.rook())                    # (he walked off with you that night)
	# the camp at its fire, the player its captive still (Two Fires before the slip)
	if id == "m.tf.two_fires" and d.phase == StoryDirector.Phase.STEPS and d.step_i <= d._step_index("slip") \
			and MarchStage.find(tree) == null:
		var camp: Variant = _place(d, "raiders_camp")
		if camp is Vector3:
			var mo := {"camp": camp, "march_hours": 0.0, "crust_at": -1.0}
			var cf: Variant = d.flag(CAMP_FIRE_FLAG)
			if cf is Array and (cf as Array).size() >= 2:
				mo["fire_at"] = _ground(Vector3(float(cf[0]), 0.0, float(cf[1])))
			MarchStage.begin(level, [camp], mo)
			var wf := WreckFall.find(tree)
			if wf != null and not replay:
				camp_looks_at(tree, wf.at)              # (the fire has come down: nobody watches the captives)
	if replay:
		var e := _mission_effect(d, "wreck_fall")
		_wreck_fall(d, e if not e.is_empty() else {"do": "wreck_fall", "place": "wreck"})


## The first effect of kind `what` among the mission's steps' effects ({} none).
static func _mission_effect(d: StoryDirector, what: String) -> Dictionary:
	for st: Variant in d.mission().get("steps", []):
		if not (st is Dictionary):
			continue
		for e: Variant in (st as Dictionary).get("effects", []):
			if e is Dictionary and String((e as Dictionary).get("do", "")) == what:
				return e
	return {}


func _ready() -> void:
	add_to_group(GROUP)


func _install_caster() -> void:
	var p := StoryObjectives.player(get_tree())
	if p == null:
		return
	caster = SwayCaster.install(p)
	if not caster.cast.is_connected(_on_cast):
		caster.cast.connect(_on_cast)


## A cast landed: the first lock on the wreck's spar lets the stranger out (the Sway's lift moves the spar).
func _on_cast(move: String, target: Node3D) -> void:
	if move != "first_lock" or target == null or not is_instance_valid(target) or not target.has_meta(&"pins"):
		return
	var wf := WreckFall.find(get_tree())
	if wf != null and wf.spar() == target:
		wf.spar_cast()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = WATCH_S
	if caster == null or not is_instance_valid(caster):
		_install_caster()
	_watch_wolf(WATCH_S)
	_watch_people()
	_watch_battle()
	_watch_weather()


## While the ships fight (and the cutter comes down), the camp's eyes follow them (its fall's landing turns them to the
## wreck: _wreck_fall). The battle over and the sky open (the watch's hold let go): SKY_OPEN_FLAG.
func _watch_battle() -> void:
	if _battle_on and not battle_on(get_tree()):
		_battle_on = false
		var d := director if director != null and is_instance_valid(director) else StoryDirector.find(get_tree())
		if d != null:
			d.set_flag(SKY_OPEN_FLAG)
	var sb := SkyBattle.find(get_tree())
	if sb == null or sb.is_queued_for_deletion():
		return
	var wf := sb.wreck_fall
	if wf == null or not is_instance_valid(wf) or not wf.is_landed():
		camp_looks_at(get_tree(), sb.focus())


## The weather held clear (CLEAR_FLAG) while the mission is not past the step it names; past it, let go: the weather it
## was comes back in (softly: the clear spell ends and that kind follows, its clouds easing in).
func _watch_weather() -> void:
	var d := director if director != null and is_instance_valid(director) else StoryDirector.find(get_tree())
	if d == null or not (d.flag(CLEAR_FLAG) is Array):
		return
	var hold: Array = d.flag(CLEAR_FLAG)
	var dn := _day_night(d)
	if _within(d, hold):
		if dn != null:
			_keep_clear(dn)
		return
	d.set_flag(CLEAR_FLAG, null)
	if dn == null:
		return
	var was := String(hold[0]) if hold.size() > 0 else "clear"
	var k := WeatherSystem.KIND_NAMES.find(was)
	var w: WeatherSystem = dn.weather
	if k > 0 and w != null:
		w.next_kind = k as WeatherSystem.Kind
		w.next_known = true
		w.kind_hours = w.kind_duration


## The people effect's walkers go once the mission that put them there is over (and their HERE_FLAG with them).
func _watch_people() -> void:
	var d := director if director != null and is_instance_valid(director) else StoryDirector.find(get_tree())
	var mid := String(d.mission().get("id", "")) if d != null else ""
	for n in get_tree().get_nodes_in_group(PEOPLE_GROUP):
		if String(n.get_meta(&"slice_mission", "")) != mid and not n.is_queued_for_deletion():
			if d != null:
				d.set_flag(HERE_FLAG + String(StoryObjectives._prop(n, "tag")), null)
			n.queue_free()


# --- The effects ----------------------------------------------------------------------------------------------------

## The slice's effects (StoryEffects.do_one hands them here); `key` is where the effect is in the mission.
static func effect(d: StoryDirector, e: Dictionary, key := "") -> void:
	match String(e.get("do", "")):
		"title_card":
			d.lead_cards.append({"title": String(e.get("title", "")), "text": String(e.get("text", ""))})
		"raid_staged":
			_raid_staged(d, e, key)
		"march":
			_march(d, e, key)
		"wreck_fall":
			_wreck_fall(d, e)
		"rook_join":
			_rook_join(d, e, key)
		"sway_grant":
			var p := StoryObjectives.player(d.get_tree())
			if p == null:
				push_warning("Story: no player to grant %s" % String(e.get("move", "")))
				return
			var c := SwayCaster.install(p)
			c.grant(String(e.get("move", "")))   # (into the Spells list: readied only from the hotbar, the owner's rule)
		"end_stages":
			end_stages(d.get_tree(), e.get("stages", ["raid", "march", "rook"]))
		"people":
			_people(d, e, key)
		"cache_back":
			cache_back(d)
		"clear_sky":
			_clear_sky(d, e)


## The raid on the east bank (RaidStage): the home, the ford and the farms by their places; the warned families' farms
## first (tf.warned.<family>: "farm_brenner" is the Brenners'), so RaidStage's waiting neighbours are the ones warned.
static func _raid_staged(d: StoryDirector, e: Dictionary, key: String) -> void:
	var tree := d.get_tree()
	var home: Variant = _place(d, String(e.get("home", "homestead")))
	if not (home is Vector3):
		push_warning("Story: raid_staged has no home place %s" % String(e.get("home", "homestead")))
		return
	var warned: Array = []
	var rest: Array = []
	var who: Array = []                               # (the warned families' people, in their farms' order)
	var who_by: Dictionary = e.get("who", {}) if e.get("who") is Dictionary else {}
	for n: Variant in e.get("farms", []):
		var p: Variant = _place(d, String(n))
		if not (p is Vector3):
			push_warning("Story: raid_staged: no place %s" % String(n))
			continue
		var family := String(n).trim_prefix("farm_")
		if StoryObjectives.truthy(d.flag("tf.warned." + family)):
			warned.append(p)
			who.append(who_by.get(String(n), {}))
		else:
			rest.append(p)
	var opts := {"capture": String(e.get("capture", "home")), "who": who}
	var ford: Variant = _place(d, String(e.get("ford", "ford")))
	if ford is Vector3:
		opts["ford"] = ford
	if e.has("hour"):
		opts["hour"] = float(e.hour)
	_when_in(tree, func(after_load: bool) -> void:
		var old := RaidStage.find(tree)
		if old != null:
			old.remove_from_group(RaidStage.GROUP)
			old.queue_free()
		var o := opts.duplicate()
		if after_load:
			# (the raid goes on as the save had it: the clock where it was, not on to the next 3 a.m.; the neighbours as they
			# were; out of the clearing already from the ford on; taken already, or the party on its way, from `taken` on)
			o["hour"] = -1.0
			o["resume"] = true
			var fi := d._step_index("ford")
			o["left_home"] = fi >= 0 and d.step_i >= fi
			var ti := d._step_index("taken")
			if ti >= 0 and d.step_i >= ti:
				o["capture"] = "now"
		var raid := RaidStage.begin(tree.current_scene, home, warned + rest, o)
		d.keep_spawned(raid, key, e))


## The forced march (MarchStage) behind the raid's Leclerc (else the one tagged captor_tag, else one made) with its two
## marines; after a load the route from the point nearest the player on.
static func _march(d: StoryDirector, e: Dictionary, key: String) -> void:
	var tree := d.get_tree()
	SkyBattle.preload_models()                        # (the second fire's ships and wreck loading while they march)
	var route: Array = []
	for xz: Variant in e.get("route", []):
		if xz is Array and (xz as Array).size() >= 2:
			route.append(_ground(Vector3(float(xz[0]), 0.0, float(xz[1]))))
	var opts := {}
	var camp: Variant = _place(d, String(e.get("camp", "")))
	if camp is Vector3:
		opts["camp"] = camp
	var tag := String(e.get("captor_tag", "leclerc"))
	_when_in(tree, func(after_load: bool) -> void:
		var raid := RaidStage.find(tree)
		var lead: Node = raid.leclerc if raid != null and _usable(raid.leclerc) else null
		if lead == null:
			lead = StoryObjectives._first_living(StoryObjectives.targets({"tag": tag}, tree))
		if lead is StoryActor and _usable(lead):
			opts["leclerc"] = lead
		if raid != null:
			var gs: Array = []
			for g in raid.guards():
				if _usable(g):
					gs.append(g)
			opts["guards"] = gs
		var r := route
		var p := StoryObjectives.player(tree)
		if after_load and p != null and route.size() > 1:
			r = _route_ahead(route, p.global_position)
		var old := MarchStage.find(tree)
		if old != null:
			old.remove_from_group(MarchStage.GROUP)     # (a stage left over: the new one takes over; it goes after)
		var m := MarchStage.begin(tree.current_scene, r, opts)
		if old != null and old != m:
			old.queue_free()
		if raid != null:
			raid.withdraw()                           # (no raiders left on the farms the column passes)
		m.arrived.connect(func() -> void:
			if m.camp_fire != null and is_instance_valid(m.camp_fire):
				d.set_flag(CAMP_FIRE_FLAG, [m.camp_fire.global_position.x, m.camp_fire.global_position.z]))
		# the crust once: shared before a load, not again on the way that is left
		if StoryObjectives.truthy(d.flag(CRUST_FLAG)):
			m.crust_given = true
		m.crust_shared.connect(func() -> void: d.set_flag(CRUST_FLAG))
		d.keep_spawned(m, key, e))


## The second fire: two sky ships fight over the valley, seen from the camp; the sky struck open where the great shot
## bursts (SkyTear, the flag `wonder`); the cutter falls burning and comes down at the place (the layer's bench beside it
## when there is one, turned to lie along it): the wreck. Where it lies kept in the story's flags as it begins; the
## camp's eyes on the fight, then on the wreck. The battle is the mission's (a retry frees it), not the save's.
static func _wreck_fall(d: StoryDirector, e: Dictionary) -> void:
	var tree := d.get_tree()
	var at: Variant = _place(d, String(e.get("place", "wreck")))
	if not (at is Vector3):
		push_warning("Story: wreck_fall has no place %s" % String(e.get("place", "")))
		return
	var heading := WreckFall.DEFAULT_HEADING
	if StoryLayer.active_id() != "":
		var bench := StoryLayer.place("wreck_site")
		if bench != Vector3.INF and _flat(bench, at) <= BENCH_M:
			at = bench
			var yaw: Variant = StoryLayer.load_layer(StoryLayer.active_id()).get("wreck_yaw")
			if yaw is float or yaw is int:
				heading = deg_to_rad(float(yaw) + 90.0)    # (the layer's hull runs along its x; the wreck's along its z)
	d.set_flag(WRECK_FLAG, [(at as Vector3).x, (at as Vector3).z, heading])
	_wreck_place(d)
	var camp: Variant = _place(d, String(e.get("camp", "raiders_camp")))
	if not (camp is Vector3):
		var p := StoryObjectives.player(tree)
		camp = p.global_position if p != null else (at as Vector3)
	var old := WreckFall.find(tree)
	if old != null:                                   # (a retry: the wreck that lay there comes down again)
		old.remove_from_group(WreckFall.GROUP)
		old.queue_free()
	# the reveal's sky: clear through the look up at it (clear_sky), and shut (a retry, a battle played again after a
	# load: the flag `wonder` is not set, the sky the last one opened is closed again)
	_clear_sky(d, {"until": "look"})
	var rig := d._rig()
	if rig != null and not StoryObjectives.truthy(d.flag(WONDER_FLAG)):
		var tr := rig.get_node_or_null(SkyTear.NODE_NAME) as SkyTear
		if tr != null and tr.running:
			tr.running = false
			tr.amount = 0.0
			tr._push_tear(0.0)
		if rig.wonder > 0.0:
			rig.set_wonder(0.0)
	var sb := SkyBattle.begin(tree.current_scene, _ground(camp), at, {"heading": heading, "sky_mark": WonderLook.giant_dir(rig)})
	if sb == null:
		push_warning("Story: wreck_fall: no sky battle")
		return
	d.keep_spawned(sb)                                # (a retry's: gone with it; not saved: a load plays it again)
	var sl := find(tree)
	if sl != null:
		sl._battle_on = true
	var tear_s := float(e.get("tear_s", TEAR_S))
	sb.opened_fire.connect(func() -> void: _camp_cry(tree, "fire"))
	sb.tear_point.connect(func(dir: Vector3) -> void:
		_sky_struck(d, dir, tear_s / maxf(sb.speed, 0.01))
		_camp_cry(tree, "sky"))
	sb.cutter_hit.connect(func() -> void: _camp_cry(tree, "hit"))
	sb.sky_flash.connect(func(amount: float, dir: Vector3) -> void:
		var r := d._rig() if is_instance_valid(d) else null
		if r != null:
			SkyTear.flash(r, amount, dir))
	sb.cutter_falling.connect(func(wf: WreckFall) -> void:
		if wf != null and is_instance_valid(wf):
			wf.landed.connect(_landed.bind(wf), CONNECT_ONE_SHOT))
	sb.finished.connect(func() -> void:
		if is_instance_valid(d):
			SkyTear.let_go(d._rig()))                 # (never held past the battle)
	camp_looks_at(tree, sb.focus())


## The great shot has struck the sky toward `dir` (from the camp): it cracks there and is held small while the cutter
## falls (SkyTear's hold), then runs on over `secs` and the wonder holds it after; the sky has opened for good (the flag
## `wonder`, as wonder_reveal's).
static func _sky_struck(d: StoryDirector, dir: Vector3, secs: float) -> void:
	if d == null or not is_instance_valid(d):
		return
	d.set_flag(WONDER_FLAG)
	var rig := d._rig()
	if rig != null:
		SkyTear.begin(rig, dir, secs, -1.0, true)


## The cutter is down: the tear let go (it runs on: the sky opens), the wreck's spar let fall clear of the stranger when
## lifted, the camp's eyes on the wreck and its guards breaking for the pines.
static func _landed(wf: WreckFall) -> void:
	if wf == null or not is_instance_valid(wf) or not wf.is_inside_tree():
		return
	var tree := wf.get_tree()
	var level := tree.current_scene
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig if level != null else null
	if rig != null:
		SkyTear.let_go(rig)
	_spar_meta(wf)
	var m := MarchStage.find(tree)
	if m != null:
		m.scatter(wf.at)
	else:
		camp_looks_at(tree, wf.at)


## The camp's shouts at a beat of the sky battle (MarchStage.cry).
static func _camp_cry(tree: SceneTree, beat: String) -> void:
	var m := MarchStage.find(tree) if tree != null else null
	if m != null:
		m.cry(beat)


## Whether a step is held (its `hold`; StoryObjectives' stay_unseen counts its seconds only once it is not, and does not
## fail meanwhile): "sky_battle" while the sky battle is on (battle_on: Two Fires' watch goes on until the cutter is down
## and the sky open).
static func held(step: Dictionary, tree: SceneTree) -> bool:
	match String(step.get("hold", "")):
		HOLD_BATTLE:
			return battle_on(tree)
	return false


## The sky battle is on: the ships fighting or the cutter on its way down, or the sky it struck still tearing open.
static func battle_on(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var sb := SkyBattle.find(tree)
	if sb != null and not sb.is_queued_for_deletion():
		var wf := sb.wreck_fall
		if wf == null or not is_instance_valid(wf) or not wf.is_landed():
			return true
	var level := tree.current_scene
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig if level != null else null
	var tear := rig.get_node_or_null(SkyTear.NODE_NAME) as SkyTear if rig != null else null
	return tear != null and tear.running


## Where a held step's marker points (null: its own): the fight (SkyBattle.focus) until the cutter is down, then where the
## sky broke (the tear's point, beside the giant).
static func watch_point(tree: SceneTree) -> Variant:
	if tree == null:
		return null
	var sb := SkyBattle.find(tree)
	if sb != null and not sb.is_queued_for_deletion():
		var wf := sb.wreck_fall
		if wf == null or not is_instance_valid(wf) or not wf.is_landed():
			return sb.focus()
		return sb.tear_aim()
	var level := tree.current_scene
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig if level != null else null
	var tear := rig.get_node_or_null(SkyTear.NODE_NAME) as SkyTear if rig != null else null
	var p := StoryObjectives.player(tree)
	if tear != null and tear.running and p != null:
		return p.global_position + tear.dir * SkyBattle.TEAR_M
	return null


## The weather clear now and held so through the mission's step `until` (CLEAR_FLAG keeps what it was; _watch_weather lets
## it go after). Clear already: not forced again (no snap).
static func _clear_sky(d: StoryDirector, e: Dictionary) -> void:
	SkyBattle.prepare(d.get_tree().current_scene)     # (Two Fires begins, its fire talk open: the battle made ready)
	var dn := _day_night(d)
	if dn == null:
		return
	if not (d.flag(CLEAR_FLAG) is Array):
		var w: WeatherSystem = dn.weather
		var was := "storm" if w.front_active else WeatherSystem.KIND_NAMES[w.kind]
		d.set_flag(CLEAR_FLAG, [was, String(e.get("until", "look")), String(d.mission().get("id", ""))])
	_keep_clear(dn, true)


## After a load: the weather clear again while its hold is on.
static func _hold_weather(d: StoryDirector) -> void:
	var hold: Variant = d.flag(CLEAR_FLAG)
	var dn := _day_night(d)
	if hold is Array and dn != null and _within(d, hold):
		_keep_clear(dn, true)


## Clear now (forced only when it is not), and kept so: the clear spell's hours held at their start (no next spell brewing),
## not a cloud in it (a clear spell's empty sky: clouds_spell 0; a cloud at night is a black blot on the open sky). `snap`:
## the clouds gone at once (the mission's start, a load), else they thin away.
static func _keep_clear(dn: DayNight, snap := false) -> void:
	var w: WeatherSystem = dn.weather
	if w.kind != WeatherSystem.Kind.CLEAR or w.front_active:
		dn.force_weather("clear")
		snap = true
	w.kind_hours = 0.0
	w.next_known = false
	if w.clouds_spell > 0.0:
		w.clouds_spell = 0.0
	if snap:
		w._snap_look(dn.clock.hour)


## Whether the mission is still in its weather hold (CLEAR_FLAG's [was, until step, mission]): its intro cards (the hold
## is set as it begins, before them), its steps up to `until`, a fail's card before its retry.
static func _within(d: StoryDirector, hold: Array) -> bool:
	var mid := String(hold[2]) if hold.size() > 2 else "m.tf.two_fires"
	if String(d.mission().get("id", "")) != mid:
		return false
	if d.phase == StoryDirector.Phase.INTRO or d.phase == StoryDirector.Phase.FAILED:
		return true
	if d.phase != StoryDirector.Phase.STEPS:
		return false
	var ui := d._step_index(String(hold[1]) if hold.size() > 1 else "look")
	return ui < 0 or d.step_i <= ui


static func _day_night(d: StoryDirector) -> DayNight:
	var rig := d._rig() if d != null and is_instance_valid(d) else null
	var dn := rig.clock_driver if rig != null else null
	return dn if dn != null and is_instance_valid(dn) and dn.weather != null else null


## The storyline's place "wreck" moved onto the hull where it came down (WRECK_FLAG): the steps there and the marker
## find the ship itself (in the director's copy of the storyline; a load puts it there again).
static func _wreck_place(d: StoryDirector) -> void:
	var w: Variant = d.flag(WRECK_FLAG)
	var pl: Variant = d.line.get("places")
	if w is Array and (w as Array).size() >= 2 and pl is Dictionary:
		(pl as Dictionary)["wreck"] = [float(w[0]), float(w[1])]


## The camp's guards stop watching the captives and look where the fire came down (Leclerc too), and keep looking there
## (MarchStage.look_at_point: the camp's own placing does not turn them back).
static func camp_looks_at(tree: SceneTree, at: Vector3) -> void:
	var m := MarchStage.find(tree)
	if m != null:
		m.look_at_point(at)


## The spar is let fall clear of the stranger when the Sway lifts it (spar_aside).
static func _spar_meta(wf: WreckFall) -> void:
	var s := wf.spar() if wf != null and is_instance_valid(wf) else null
	if s != null and not s.has_meta(&"sway_lift_to"):
		s.set_meta(&"sway_lift_to", spar_aside(wf))


## Where the spar's middle is set down: SPAR_OUT_M along its own length out from the hull (its inner end off the hull's side)
## and SPAR_FEET_M across, past the stranger's feet (it lay across his thighs), on the ground there.
static func spar_aside(wf: WreckFall) -> Vector3:
	var s := wf.spar()
	var out := wf.frame.basis.x
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
	var feet := wf.frame.basis.z
	var r := wf.rook()
	if r != null and is_instance_valid(r):
		var f := r.bone_pos("pelvis") - r.bone_pos("heada")
		f.y = 0.0
		if f.length() > 0.2:
			feet = f
	feet.y = 0.0
	feet = feet.normalized() if feet.length() > 0.01 else Vector3.BACK
	var p := s.global_position + out * SPAR_OUT_M + feet * SPAR_FEET_M
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + WreckFall.SPAR_R + 0.05, p.z)


## The spar lying where the Sway set it down (a load after the first lock): level on the ground at spar_aside, still; the
## stranger up (WreckFall.spar_cast: he gets up, unless he is hidden after).
static func set_spar_down(wf: WreckFall) -> void:
	var s := wf.spar()
	if s == null:
		return
	var at: Vector3 = s.get_meta(&"sway_lift_to") if s.has_meta(&"sway_lift_to") else spar_aside(wf)
	var ax := s.global_basis.x
	ax.y = 0.0
	ax = ax.normalized() if ax.length() > 0.01 else Vector3.RIGHT
	s.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	s.freeze = true
	s.global_transform = Transform3D(Basis(ax, Vector3.UP, ax.cross(Vector3.UP)), at)
	wf.spar_cast()


## Rook: standing at `place`, or walking from the wreck toward `to` by `via` (a RookJourney: his walks, his wolves).
static func _rook_join(d: StoryDirector, e: Dictionary, key: String) -> void:
	var tree := d.get_tree()
	if e.has("place"):
		var at: Variant = _place(d, String(e.place))
		if not (at is Vector3):
			push_warning("Story: rook_join has no place %s" % String(e.place))
			return
		_when_in(tree, func(_after_load: bool) -> void:
			end_stages(tree, ["rook"])
			var p := StoryObjectives.player(tree)
			var face: Vector3 = p.global_position if p != null else Vector3.INF
			var r := RookWalk.make_rook(tree.current_scene, at, face)
			d.keep_spawned(r, key, e))
		return
	var to: Variant = _place(d, String(e.get("to", "")))
	if not (to is Vector3):
		push_warning("Story: rook_join has no place %s" % String(e.get("to", "")))
		return
	var via: Array = []
	for n: Variant in e.get("via", []):
		var v: Variant = _place(d, String(n))
		if v is Vector3:
			via.append(v)
	_when_in(tree, func(after_load: bool) -> void:
		end_stages(tree, ["rook"])
		var p := StoryObjectives.player(tree)
		var start: Vector3 = p.global_position if p != null else (to as Vector3)
		var wf := WreckFall.find(tree)
		if not after_load and wf != null and wf.rook() != null and is_instance_valid(wf.rook()) and wf.rook().visible:
			start = wf.rook().global_position
			_hide(wf.rook())                            # (his body walks on as Rook: the one the wreck pinned stays down)
		elif p != null:
			var side := ((to as Vector3) - start).cross(Vector3.UP)
			start += side.normalized() * 1.6 if side.length() > 0.1 else Vector3.RIGHT * 1.6
		var j := RookJourney.new()
		j.name = "RookJourney"
		j.legs.assign((via if not after_load else []) + [to])
		tree.current_scene.add_child(j)
		j.start(start)
		d.keep_spawned(j, key, e))


## The people a talk is with, standing at the place for as long as the mission lasts (its retry and a load make them again).
static func _people(d: StoryDirector, e: Dictionary, key: String) -> void:
	var tree := d.get_tree()
	var at: Variant = _place(d, String(e.get("place", "")))
	if not (at is Vector3):
		push_warning("Story: people has no place %s" % String(e.get("place", "")))
		return
	var mid := String(d.mission().get("id", ""))
	var face0: Array = e.get("face", [0.0, 0.0])
	_when_in(tree, func(_after_load: bool) -> void:
		var made: Array = []
		for who: Variant in e.get("who", []):
			if not (who is Dictionary):
				continue
			var p: Dictionary = who
			var off: Array = p.get("at", [0.0, 0.0])
			var spot := (at as Vector3) + Vector3(float(off[0]), 0.0, float(off[1]))
			var fo: Array = p.get("face", face0)
			var face := (at as Vector3) + Vector3(float(fo[0]), 0.0, float(fo[1]))
			var child := bool(p.get("child", false))
			var preset := String(p.get("look", "palatine_m_a"))
			var tag := String(p.get("tag", "person"))
			for old in tree.get_nodes_in_group(PEOPLE_GROUP):
				if String(StoryObjectives._prop(old, "tag")) == tag:
					old.queue_free()                   # (made again: one of each)
			var w := StoryWalker.make(tree.current_scene, spot, StoryWalker.person_look(preset, tag, child, mid),
					{"tag": tag, "name": String(p.get("name", tag.capitalize())), "size": 0.7 if child else 1.0,
					"group": [&"story_people", PEOPLE_GROUP, WildlifeSpawner.PEOPLE], "face": face, "node_name": tag})
			w.set_meta(&"slice_mission", mid)
			d.set_flag(HERE_FLAG + tag, String(e.get("place", "")))     # (her post elsewhere hides meanwhile)
			made.append(w)
		d.keep_spawned(made, key, e))


## Stages gone from the world: "raid" (RaidStage and what it made), "march" (MarchStage: Leclerc, the guards, Jost, the
## camp's fire), "rook" (Rook's walk and Rook), "lesson" (First Lesson's lantern, hat and post, and its wolf).
static func end_stages(tree: SceneTree, stages: Variant) -> void:
	var list: Array = stages if stages is Array else [stages]
	for s: Variant in list:
		match String(s):
			"raid":
				var r := RaidStage.find(tree)
				if r != null:
					r.remove_from_group(RaidStage.GROUP)
					r.queue_free()
			"march":
				var m := MarchStage.find(tree)
				if m != null:
					m.remove_from_group(MarchStage.GROUP)
					m.queue_free()
			"rook":
				for n in tree.get_nodes_in_group(&"story_people"):
					if String(StoryObjectives._prop(n, "tag")) == "rook" and not n.is_queued_for_deletion():
						n.queue_free()
				for n in tree.get_nodes_in_group(RookWalk.GROUP):
					n.queue_free()
				var scene := tree.current_scene
				if scene != null:
					for c in scene.get_children():
						if c is RookJourney and not c.is_queued_for_deletion():
							c.queue_free()
			"lesson":
				var scene := tree.current_scene
				if scene != null:
					for c in scene.get_children():
						if (c is LessonLantern or c is LessonPost) and not c.is_queued_for_deletion():
							c.queue_free()
				var sl := find(tree)
				if sl != null and sl._wolf != null and is_instance_valid(sl._wolf):
					sl._wolf.queue_free()
					sl._wolf = null


## What the cache kept given back (The Third Warning buried it: tf.cache.<kind> = how many, pack kinds): each into the pack,
## with its note on screen; tf.cache_back once it is (the record of what was buried stays). StoryEffects does it once a
## mission (a retry does not give it twice).
static func cache_back(d: StoryDirector) -> int:
	var n := 0
	for k: Variant in d.flags.keys():
		var ks := String(k)
		if not ks.begins_with(CACHE_PREFIX):
			continue
		var v: Variant = d.flags[k]
		var count := int(v) if (v is int or v is float) else (1 if StoryObjectives.truthy(v) else 0)
		if count > 0:
			StoryEffects.give(d.get_tree(), ks.trim_prefix(CACHE_PREFIX), count)
			n += count
	if n > 0:
		d.set_flag("tf.cache_back")
	return n


## The captives loose (end_captivity): Jost, slipped away with the player (tf.jost_free), keeps beside him.
static func captives_loose(d: StoryDirector) -> void:
	var m := MarchStage.find(d.get_tree())
	var p := StoryObjectives.player(d.get_tree())
	if m == null or m.jost == null or not is_instance_valid(m.jost) or p == null:
		return
	if StoryObjectives.truthy(d.flag("tf.jost_free")):
		m.jost.crouch(false)
		m.jost.follow(p, MarchStage.JOST_SLOT)


# --- The lock_cast kind ---------------------------------------------------------------------------------------------

## StoryObjectives.begin for a lock_cast step: its target made at its place when it is one of First Lesson's and missing;
## the casts counted from now (SwayCaster.lock_cast_begin).
static func lock_cast_begin(step: Dictionary, tree: SceneTree) -> Dictionary:
	var tag := String(step.get("target", step.get("target_tag", "")))
	var d := StoryDirector.find(tree)
	var at: Variant = StoryObjectives.place_point(step, d.places()) if d != null else null
	if at is Vector3 and tree.current_scene != null:
		ensure_target(tree, tag, at)
	var s := step
	if not step.has("target"):
		s = step.duplicate()
		s["target"] = tag
	return SwayCaster.lock_cast_begin(s)


## ... and its check: SwayCaster's, the marker on the target (else the place).
static func lock_cast_check(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant) -> Dictionary:
	var s := step
	if not step.has("target"):
		s = step.duplicate()
		s["target"] = String(step.get("target_tag", ""))
	var r := SwayCaster.lock_cast_check(s, base, tree)
	if r.get("at") == null:
		if String(s.target) == WOLF_TAG:
			var sl := find(tree)
			if sl != null and sl._wolf != null and is_instance_valid(sl._wolf) and not sl._wolf.is_dead():
				r["at"] = sl._wolf.global_position
		if r.get("at") == null:
			r["at"] = at
	return r


## First Lesson's targets, made at `at` when none with the tag is in the world: the lantern on the ice (put out by a Gust),
## the hat on a post (blown off it), a wolf running across (the watcher sends one across while the step is on).
static func ensure_target(tree: SceneTree, tag: String, at: Vector3) -> Node3D:
	for n in tree.get_nodes_in_group(SwayCaster.TARGET_GROUP):
		if n is Node3D and SwayCaster.tag_of(n) == tag and not n.is_queued_for_deletion():
			return n
	var level := tree.current_scene
	match tag:
		"lesson_lantern":
			var l := LessonLantern.new()
			l.name = "LessonLantern"
			level.add_child(l)
			l.global_position = _on_top(at + LANTERN_OFF) + Vector3.UP * 0.2
			return l
		"lesson_hat":
			var post := LessonPost.new()
			post.name = "LessonPost"
			level.add_child(post)
			post.global_position = _on_top(at + HAT_OFF)
			return post.hat
		WOLF_TAG:
			var s := find(tree)
			if s != null:
				return s._send_wolf(at)
	return null


## While a lock_cast step on a wolf is on: one wolf running across the ice in front of the place, sent across again each
## time it stands; let go once the step is over.
func _watch_wolf(dt: float) -> void:
	var d := director if director != null and is_instance_valid(director) else StoryDirector.find(get_tree())
	var on := d != null and d.phase == StoryDirector.Phase.STEPS and String(d.step().get("kind", "")) == "lock_cast" \
			and String(d.step().get("target", d.step().get("target_tag", ""))) == WOLF_TAG
	if not on:
		if _wolf != null and is_instance_valid(_wolf):
			_wolf_t += dt
			if _wolf_t > 15.0 and not _wolf.is_dead():
				_wolf.queue_free()
				_wolf = null
		return
	_wolf_t = 0.0
	var at: Variant = StoryObjectives.place_point(d.step(), d.places())
	if not (at is Vector3):
		return
	if _wolf == null or not is_instance_valid(_wolf) or _wolf.is_dead() or _flat(_wolf.global_position, at) > 70.0:
		_send_wolf(at)
	elif _wolf.state != WildAnimal.State.FLEE:
		# (it stands: sent back across, running from a point beyond it on its own side)
		var side := signf(_wolf.global_position.z - (at as Vector3).z)
		if side == 0.0:
			side = 1.0
		_wolf._start_flee(_ground(_wolf.global_position + Vector3(0.0, 0.0, side * 12.0)))


## A wolf put down at one end of the run and sent across it (it runs from a point behind it).
func _send_wolf(at: Vector3) -> WildAnimal:
	if _wolf != null and is_instance_valid(_wolf):
		_wolf.queue_free()
	var a := WildlifeSpecies.make(WOLF_TAG)
	a.name = "LessonWolf"
	a.setup(WOLF_TAG, null, null, 1757)
	get_tree().current_scene.add_child(a)
	var from := at + Vector3(WOLF_RUN.x, 0.0, _wolf_side * WOLF_RUN.z)
	a.global_position = _ground(from) + Vector3.UP * 0.05
	a.rotation.y = atan2(0.0, _wolf_side)            # (facing across the run)
	a._start_flee(_ground(from + Vector3(0.0, 0.0, _wolf_side * 12.0)))
	_wolf = a
	_wolf_side = -_wolf_side
	return a


# --- Helpers --------------------------------------------------------------------------------------------------------

## Calls `fn(after_load)` now, or (a save being applied: the player, the captivity still to come) once it is all in.
static func _when_in(tree: SceneTree, fn: Callable) -> void:
	var sg := SaveGame.find(tree)
	if sg != null and sg.loading:
		fn.bind(true).call_deferred()
	else:
		fn.call(false)


static func _place(d: StoryDirector, name: String) -> Variant:
	if name == "":
		return null
	return StoryObjectives.place_point({"place": name}, d.places())


## The route from the point nearest `p` on (a march begun again after a load goes on from where it was).
static func _route_ahead(route: Array, p: Vector3) -> Array:
	var best := 0
	var bd := INF
	for i in route.size():
		var dd := _flat(route[i], p)
		if dd < bd:
			bd = dd
			best = i
	if best < route.size() - 1 and _flat(route[best + 1], p) < _flat(route[best + 1], route[best]):
		best += 1                                     # (past the nearest already: on to the next)
	return route.slice(best)


## The hands empty when the weapon in them is not the player's to carry (the captors kept it: Captivity.end(false)): a
## fresh level hands the loadout's weapon out drawn, and the player part's toggle_hands_free cannot holster one that is not
## carried, so it stays in the hands after a load (and the Sway's casting hand is not free).
static func _free_hands(p: FrontierPlayer) -> void:
	if p == null or p.hands_free or p.weapon == null or not p.weapon.active or p.is_carried(p.weapon_key) or p.is_switching():
		return
	if p.quick != null:
		p.quick.drop()
	p.weapon.unequip()
	p.hands_free = true
	if p.anim:
		p.anim.hands_free = true
	if p.gear:
		p.gear.sling_all()


## A person still to be had: in the world, alive, not on its way out (a retry's freed stage has taken its own out).
static func _usable(n: Variant) -> bool:
	return n is Node and is_instance_valid(n) and (n as Node).is_inside_tree() and not (n as Node).is_queued_for_deletion() \
			and not StoryObjectives.is_dead(n)


static func _hide(n: Node3D) -> void:
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	for c in n.find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).disabled = true


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


## On the ground or on the water there (the frozen river's ice in winter), whichever is higher.
static func _on_top(p: Vector3) -> Vector3:
	var h := FrontierTerrain.height_at(p.x, p.z)
	if WorldRiver.has_water():
		h = maxf(h, WorldRiver.surface_at(p.x, p.z))
	return Vector3(p.x, h, p.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Rook's walk ----------------------------------------------------------------------------------------------------

## Rook walking the player on, leg by leg (RookWalk each; the wolves on the first leg, coming as he nears its end: the
## raid's dead stock), the flag GUSTED_FLAG once his Gust has driven them off. Freeing it frees him and his walks.
class RookJourney:
	extends Node

	var legs: Array[Vector3] = []
	var rook: StoryWalker
	var walk: RookWalk
	var leg := 0

	func start(at: Vector3) -> void:
		if legs.is_empty():
			return
		rook = RookWalk.make_rook(self, at, legs[0])
		_begin_leg()

	func _begin_leg() -> void:
		var to := legs[leg]
		var opts := {}
		if leg == 0 and legs.size() > 1:
			var m := Vector2(to.x - rook.global_position.x, to.z - rook.global_position.z).length()
			opts = {"wolves_after_s": 1.0e9, "wolves_after_m": maxf(m - 20.0, 0.0)}
		walk = RookWalk.begin(self, rook, to, opts)
		if leg > 0:
			walk.phase = "after"                     # (the wolves were the first leg's)
			walk.fled = true
		walk.wolves_fled.connect(_on_fled.bind(walk))
		walk.done.connect(_on_done.bind(walk), CONNECT_ONE_SHOT)

	func _on_fled(w: RookWalk) -> void:
		if is_instance_valid(w) and w.casts > 0:
			var d := StoryDirector.find(get_tree())
			if d != null:
				d.set_flag(StorySlice.GUSTED_FLAG)

	func _on_done(w: RookWalk) -> void:
		leg += 1
		if leg >= legs.size():
			return
		if is_instance_valid(w):
			w.queue_free()
		_begin_leg()


# --- First Lesson's targets -----------------------------------------------------------------------------------------

## A lit lantern set on the ice (a Sway target, tag lesson_lantern): a Gust pushes it and puts it out.
class LessonLantern:
	extends RigidBody3D

	var lit := true
	var _glass: StandardMaterial3D
	var _light: OmniLight3D

	func _ready() -> void:
		mass = 1.2
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		add_to_group(SwayCaster.TARGET_GROUP)
		set_meta(&"sway_tag", "lesson_lantern")
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.22, 0.34, 0.22)
		cs.shape = bx
		add_child(cs)
		var tin := StandardMaterial3D.new()
		tin.albedo_color = Color(0.2, 0.18, 0.16)
		tin.metallic = 0.6
		tin.roughness = 0.5
		for y: float in [-0.16, 0.16]:
			var cap := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.1 if y < 0.0 else 0.04
			cm.bottom_radius = 0.12
			cm.height = 0.04 if y < 0.0 else 0.07
			cap.mesh = cm
			cap.material_override = tin
			cap.position.y = y
			add_child(cap)
		var glass := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.085
		gm.bottom_radius = 0.085
		gm.height = 0.28
		glass.mesh = gm
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.emission_enabled = true
		_glass.emission = Color(1.0, 0.62, 0.25)
		_glass.emission_energy_multiplier = 2.5
		glass.material_override = _glass
		add_child(glass)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.68, 0.36)
		_light.light_energy = 1.4
		_light.omni_range = 6.0
		_light.shadow_enabled = false
		_light.position.y = 0.05
		add_child(_light)

	## Gust (SwayCaster's cast): the flame goes out.
	func sway_cast(_move: String, _caster: Node) -> void:
		if not lit:
			return
		lit = false
		_light.visible = false
		_glass.emission_enabled = false
		_glass.albedo_color = Color(0.35, 0.33, 0.3, 0.6)
		if Sfx.has(&"torch_snuff"):
			Sfx.play_3d(&"torch_snuff", global_position, -4.0)


## A post with an old hat on it; the hat (a Sway target, tag lesson_hat) is blown off by a Gust.
class LessonPost:
	extends StaticBody3D

	var hat: RigidBody3D

	func _ready() -> void:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.36, 0.27, 0.19)
		wood.roughness = 0.95
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.06
		cy.height = 1.4
		cs.shape = cy
		cs.position.y = 0.7
		add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.07
		cm.height = 1.4
		mi.mesh = cm
		mi.material_override = wood
		mi.position.y = 0.7
		add_child(mi)
		hat = RigidBody3D.new()
		hat.name = "Hat"
		hat.mass = 0.3
		hat.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		hat.freeze = true
		hat.add_to_group(SwayCaster.TARGET_GROUP)
		hat.set_meta(&"sway_tag", "lesson_hat")
		var felt := StandardMaterial3D.new()
		felt.albedo_color = Color(0.13, 0.11, 0.1)
		felt.roughness = 1.0
		var hs := CollisionShape3D.new()
		var hc := CylinderShape3D.new()
		hc.radius = 0.2
		hc.height = 0.13
		hs.shape = hc
		hat.add_child(hs)
		var brim := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.22
		bm.bottom_radius = 0.22
		bm.height = 0.015
		brim.mesh = bm
		brim.material_override = felt
		brim.position.y = -0.05
		hat.add_child(brim)
		var crown := MeshInstance3D.new()
		var crm := CylinderMesh.new()
		crm.top_radius = 0.1
		crm.bottom_radius = 0.12
		crm.height = 0.12
		crown.mesh = crm
		crown.material_override = felt
		crown.position.y = 0.02
		hat.add_child(crown)
		add_child(hat)
		hat.position = Vector3(0.0, 1.47, 0.0)
