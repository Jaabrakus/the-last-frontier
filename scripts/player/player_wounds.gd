class_name PlayerWounds
extends Node
## Bleeding and blunt force (user 2026-09-27: "losing health works as a blood lost system ... if I get shot then we
## lose health, but on top of that it is like a bar that loses power; if well rested it drains it to stop the
## bleeding"; "bleeding, that's what it's called, versus blunt force").
##
##   blunt     a falling tree, a club, a fall: the health comes off at once, and that is all
##   bleeding  a ball, an arrow, a blade, a bite: BLEED_NOW of it comes off at once, the rest is the POOL: blood still to
##             be lost. Each second the pool drains into lost health (DRAIN of it) and the wound closes on the rest
##             (CLOT of it, faster well rested, resting or asleep, much faster dressed with a poultice or salve), so the
##             pool shrinks from both ends until they meet and the bleeding stops. Normally about two thirds of the pool
##             is lost, well rested half, well rested and resting a third, dressed almost none.
## Drink (user 2026-09-27: "drunkenness should stop all blunt force but stacks bleeding"; "a little bit is an
## enhancement"): from merry on (DRUNK_STAGES),
## blunt force does not hurt at once; DRUNK_BLUNT of it goes on the pool instead, paid later and less. Bleeding
## wounds bleed as ever. The cost is the hangover (no well-rested boost: SurvivalBridge.rest_cap_h).
## A wound too big for the clotting to keep up with bleeds the player out ("You bled to death").
## The HUD shows the pool dark red behind the health bar (FrontierHUD).
## Where a hit lands (user 2026-09-27: "we can see if someone got shot in the stomach"): the nearest of the body's regions
## (REGIONS: the head, the chest, the stomach, each arm, hand, leg and foot, each a few bone segments of the skeleton) to
## the hit's point, and the front or the back by where it came from; `struck` tells LastingConditions, which keeps the
## wound there (its cost and its knitting) and the Condition tab's outline shows it.
##
##   var w := PlayerWounds.of(player)
##   w.take(30.0, source, point, direction)   # the kind from the source: bleed or blunt; where from the point
##   w.pool, w.bleeding()
##   w.dress(1.0)                # a poultice or a salve on it

signal bleeding_changed(on: bool)
## A bleeding wound taken (`amount` of health in it, the pool and what came off at once), and a dressing put on one
## (LastingConditions: a wound left undressed festers).
signal wounded(amount: float)
signal dressed
## A mortal wound that held (treated and survived): no longer mortal.
signal stabilized
## A hit that hurt: its region (REGIONS), "front" or "back", "bleed" or "blunt", and its health.
signal struck(region: String, side: String, kind: String, amount: float)

## A mortal wound (the heart, the cord high up; Anatomy.effect): a clock to death, stretched a long way by treatment (a
## poultice or a salve: dress; yarrow packed in: stanch) up to MORTAL_CAP, and a wound that is treated and survived
## STABLE_S long stops being mortal: it becomes the chest's lasting wound (LastingConditions) that heals as any other.
const MORTAL_DRESS_S := 30.0       ## a poultice adds this long (x its strength: a salve more)
const MORTAL_STANCH_S := 25.0      ## yarrow packed in adds this long (x the share it stanches)
const MORTAL_CAP := 120.0
const STABLE_S := 40.0             ## alive this long since the wound, and treated: it holds
const BLEED_NOW := 0.4
const DRAIN := 0.04          ## of the pool a second, into lost health
const CLOT := 0.02           ## of the pool a second, closed without loss (x clot_mult)
const REST_CLOT := 2.0       ## well rested
const SIT_CLOT := 2.0        ## resting or asleep (SurvivalSleep)
const DRESSED_CLOT := 40.0   ## a poultice or a salve on the wound
const DRESSED_S := 20.0      ## how long the dressing holds (a new wound after it bleeds again)
const STOP := 0.25           ## a pool this small has stopped
const DRUNK_STAGES := ["merry", "tipsy", "drunk", "senseless"]   ## a little drink is the enhancement (user)
const DRUNK_BLUNT := 0.5     ## of a blunt hit that goes on the pool while drunk (none of it at once)
## The body's regions: bone segments of the skeleton ([bone, the bone it runs to]) and a thickness (m) taken off the
## distance to them, so the trunk is not lost to the limbs lying against it.
const REGIONS := {
	"head": {"r": 0.1, "seg": [["neck", "heada"], ["heada", "headb"]]},
	"chest": {"r": 0.15, "seg": [["spinec", "spined"], ["spined", "neck"], ["l_clavicle", "l_shoulder"], ["r_clavicle", "r_shoulder"]]},
	"stomach": {"r": 0.15, "seg": [["pelvis", "spinea"], ["spinea", "spineb"], ["spineb", "spinec"]]},
	"l_arm": {"r": 0.05, "seg": [["l_shoulder", "l_elbow"], ["l_elbow", "l_wrist"]]},
	"r_arm": {"r": 0.05, "seg": [["r_shoulder", "r_elbow"], ["r_elbow", "r_wrist"]]},
	"l_hand": {"r": 0.04, "seg": [["l_wrist", "l_palm"]]},
	"r_hand": {"r": 0.04, "seg": [["r_wrist", "r_palm"]]},
	"l_leg": {"r": 0.08, "seg": [["l_upper_leg", "l_knee"], ["l_knee", "l_ankle"]]},
	"r_leg": {"r": 0.08, "seg": [["r_upper_leg", "r_knee"], ["r_knee", "r_ankle"]]},
	"l_foot": {"r": 0.05, "seg": [["l_ankle", "l_heel"], ["l_heel", "l_ball"]]},
	"r_foot": {"r": 0.05, "seg": [["r_ankle", "r_heel"], ["r_heel", "r_ball"]]},
}

var player: Node
var pool := 0.0
## A mortal wound (the heart, the cord high up): seconds left, and the health lost each second so it ends with them.
var mortal_left := 0.0
var mortal_age := 0.0
var treated := false
var _dressed := 0.0
var _was := false


static func of(p: Node) -> PlayerWounds:
	var w := p.get_node_or_null("Wounds") as PlayerWounds
	if w == null:
		w = PlayerWounds.new()
		w.name = "Wounds"
		w.player = p
		p.add_child(w)
	return w


## "blunt", "bleed" or "" (no wound: a death the survival rules decide) for a hit from `source`. A source can say
## itself with a `damage_kind` meta ("blunt" / "bleed").
static func kind_of(source: Node) -> String:
	if source == null:
		return "blunt"
	if source.has_meta(&"damage_kind"):
		return String(source.get_meta(&"damage_kind"))
	if source is FelledTree:
		return "blunt"
	if source is SurvivalBridge:
		return ""
	return "bleed"


## A hit of `damage` from `source` at `point`, going `direction`: the health that comes off now (the caller takes it); a
## bleeding wound's pool is kept here. Where it landed is told (struck).
func take(damage: float, source: Node, point := Vector3.INF, direction := Vector3.ZERO, bleed_mult := 1.0) -> float:
	var kind := kind_of(source)
	if kind != "" and damage > 0.0:
		struck.emit(region_at(player, point), side_of(player, direction), kind, damage)
	if kind == "blunt" and drunk():
		pool += damage * DRUNK_BLUNT
		return 0.0
	if kind != "bleed":
		return damage
	pool += damage * (1.0 - BLEED_NOW) * bleed_mult     # (what it tore through: Anatomy.effect)
	_dressed = 0.0
	wounded.emit(damage)
	return damage * BLEED_NOW


## The region (REGIONS) of `p`'s body nearest `point` ("chest" with no skeleton or no point).
static func region_at(p: Node, point: Vector3) -> String:
	var sk := p.get("skeleton") as Skeleton3D if p else null
	if sk == null or not point.is_finite():
		return "chest"
	var best := "chest"
	var best_d := INF
	for region: String in REGIONS:
		var r: Dictionary = REGIONS[region]
		for sg: Array in r.seg:
			var a := sk.find_bone(String(sg[0]))
			var b := sk.find_bone(String(sg[1]))
			if a < 0 or b < 0:
				continue
			var pa := sk.global_transform * sk.get_bone_global_pose(a).origin
			var pb := sk.global_transform * sk.get_bone_global_pose(b).origin
			var d := point.distance_to(Geometry3D.get_closest_point_to_segment(point, pa, pb)) - float(r.r)
			if d < best_d:
				best_d = d
				best = region
	return best


## "front" when a hit going `direction` came at `p` from ahead (as its hit reactions have it), else "back".
static func side_of(p: Node, direction: Vector3) -> String:
	var n := p as Node3D
	if n == null or direction.length_squared() < 1e-8:
		return "front"
	return "front" if (-direction).dot(-n.global_basis.z) >= 0.0 else "back"


## The place a region's wound counts at (LastingConditions.PLACES): a hand is its arm's, a foot its leg's.
static func place_of(region: String) -> String:
	return {"l_hand": "l_arm", "r_hand": "r_arm", "l_foot": "l_leg", "r_foot": "r_leg"}.get(region, region)


func bleeding() -> bool:
	return pool > STOP


## Drunk enough that blunt force does not hurt at once (cond.drunk merry or worse).
func drunk() -> bool:
	var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	return b != null and b.core != null and SurvivalConditions.stage_of(b.core, "cond.drunk") in DRUNK_STAGES


## A poultice or a salve on the wound: it closes within seconds (`strength` 1: a poultice; more for a salve).
func dress(strength := 1.0) -> void:
	_extend(MORTAL_DRESS_S * strength)
	_dressed = DRESSED_S * strength
	dressed.emit()


## Something packed into the wound (yarrow): `frac` of the blood still to lose closes at once.
func stanch(frac: float) -> void:
	_extend(MORTAL_STANCH_S * clampf(frac, 0.0, 1.0))
	pool *= 1.0 - clampf(frac, 0.0, 1.0)
	if pool < STOP:
		pool = 0.0
	_notify()


func clot_mult() -> float:
	var m := 1.0
	var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	if b:
		if b.is_healing_rest():
			m *= REST_CLOT
		if b.sleeper and (b.sleeper.sleeping or b.sleeper.resting):
			m *= SIT_CLOT
	if _dressed > 0.0:
		m *= DRESSED_CLOT
	return m


## Dead in `secs` unless treated: the health runs down to it, on their feet.
func set_mortal(secs: float) -> void:
	if secs <= 0.0 or (mortal_left > 0.0 and mortal_left <= secs):
		return
	mortal_left = secs
	if mortal_age <= 0.0:
		treated = false
	bleeding_changed.emit(true)


## Treatment stretches the clock (a poultice, a salve, yarrow), up to MORTAL_CAP.
func _extend(secs: float) -> void:
	if mortal_left <= 0.0:
		return
	mortal_left = minf(mortal_left + secs, MORTAL_CAP)
	treated = true
	var n: Variant = player.get("interactor")
	if n != null:
		n.notice("The wound holds a while longer", 2.5)


func mortal() -> bool:
	return mortal_left > 0.0


func clear() -> void:
	mortal_left = 0.0
	mortal_age = 0.0
	treated = false
	pool = 0.0
	_dressed = 0.0
	_notify()


func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if bool(player.get("is_dead")):
		if pool > 0.0:
			clear()
		return
	_dressed = maxf(0.0, _dressed - dt)
	if mortal_left > 0.0:
		mortal_age += dt
		if treated and mortal_age >= STABLE_S:
			# treated and survived: it holds. What is left is a wound like any other (the chest's, LastingConditions)
			mortal_left = 0.0
			mortal_age = 0.0
			treated = false
			stabilized.emit()
			var n: Variant = player.get("interactor")
			if n != null:
				n.notice("The bleeding has slowed: you will live if you rest", 4.0)
		else:
			mortal_left = maxf(0.0, mortal_left - dt)
			var hp := float(player.get("health"))
			# the health runs down to nothing as the clock does (a poultice's healing only buys the time it adds)
			player.call(&"lose_blood", hp / maxf(mortal_left + dt, dt) * dt if mortal_left > 0.0 else hp + 1.0)
	if pool <= 0.0:
		return
	var lost := minf(pool * DRAIN * dt, pool)
	var closed := pool * CLOT * clot_mult() * dt
	pool = maxf(0.0, pool - lost - closed)
	if pool < STOP:
		pool = 0.0
	if lost > 0.0:
		player.call(&"lose_blood", lost)
	_notify()


func _notify() -> void:
	var on := bleeding()
	if on != _was:
		_was = on
		bleeding_changed.emit(on)
