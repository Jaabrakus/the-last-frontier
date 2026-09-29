class_name WildGroup
extends RefCounted
## A herd or a pack (scripts/wildlife) and its shared mind (the animal "brains", user 2026-09-26: "routines, memory, herd
## roles and food chain"; WildPlanner decides, the members carry it out):
##   roles     the leader (a doe leads a herd, a wolf the pack) picks where the group goes; the others follow it in a
##             loose file; while a herd feeds one member stands SENTRY (head up, keen-eyed) and the post goes round
##   activity  what the group is doing: FEED, BED (rest in cover), PATROL (wolves roam their range), HUNT (wolves after a
##             herd), EAT (at a carcass: wolves, a fox), TRACK (wolves on a wounded animal's blood trail); `dest` is
##             where
##   memory    danger: the places where the group met danger (a shot, the player close, a member killed), fading over
##             DANGER_S; they push its feeding and bedding places away and make it jumpy (nerves())
##   alarm     one member that bolts flags its tail and the herd goes with it

## (appended only: saves keep the activity as its number)
enum Activity { FEED, BED, PATROL, HUNT, EAT, TRACK }

## A danger memory fades to a third over this many seconds (game time).
const DANGER_S := 600.0
const SENTRY_S := Vector2(25.0, 40.0)

var species := "deer"
var members: Array[WildAnimal] = []
## The centre of the group's range; moves when danger drives it off.
var home := Vector3.ZERO
## Wolves: the home the pack had before hunger drew it toward the fort (INF: not yet moved; WildPlanner._drift).
var home0 := Vector3.INF
var activity := Activity.FEED
## Where the group is heading / doing its activity.
var dest := Vector3.ZERO
var dest_set := false
var activity_since := 0.0
## Game time (s) of the last alarm and where the danger was.
var alarm_time := -1e9
var alarm_pos := Vector3.ZERO
## Predators: members lost or badly hurt; at 2 the pack gives up and leaves.
var losses := 0
## The pack has worn a player down and draws off to shadow him (WildAnimal._shadowing) till he is whole again.
var shadowing := false
## The pack's alpha (user 2026-09-27: "make one wolf a alpha wolf? and if that one is injured or killed it makes the
## other wolves run away until they get a new alpha wolf"): the strongest wolf, larger and darker (WildAnimal.
## make_alpha); it leads. Hurt badly or killed (alpha_down) the pack is routed: every wolf runs from the danger and
## none hunts until ROUT_S have passed, when the strongest left (never one that was alpha and fell) takes its place.
const ROUT_S := 60.0
var alpha: WildAnimal
var routed_until := -1e9
## [{pos, t, w}]
var danger: Array[Dictionary] = []
## The sentry (herds, while feeding) and when the post changes.
var sentry: WildAnimal
var sentry_until := 0.0
## Wolves: the animal the pack is hunting, the carcass it (or a fox) is eating (any carcass: WildlifeSpawner).
var prey: WildAnimal
var hunt_since := 0.0
var carcass: Node3D
## Wolves on a blood trail (TRACK): the wounded animal whose drops they follow, when they last had its scent, and when
## they began to wait off its carcass for the player to leave it (-1 not waiting).
var trail_of: WildAnimal
var trail_seen := 0.0
var trail_wait := -1.0
## Trails given up (the kill gone, eaten, lost): {instance id: till when} they are not taken up again.
var trails_left := {}
## Wolves on a trail in the snow (TRACK with snow_trail; WildPlanner._snow_track): whose prints they follow (SnowPrints
## kinds: deer, bison, boot) and the game time (core minutes) of the last print they came to.
var snow_trail := false
var snow_kind := ""
var snow_t := 0.0
## Wolves: till when they are after the player for the kill he took from them (WildPlanner, WildAnimal._predator).
var after_player_until := -1e9
## Wolves: when the pack last howled.
var last_howl := -1e9


func alive() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for m in members:
		if is_instance_valid(m) and not m.is_dead():
			out.append(m)
	return out


## The leader: a pack's alpha; else the first living member of the highest lead (WildlifeSpecies "lead": a doe before a
## buck in a herd).
func leader() -> WildAnimal:
	if is_instance_valid(alpha) and not alpha.is_dead():
		return alpha
	var best: WildAnimal = null
	for m in alive():
		if best == null or float(m.data.get("lead", 1.0)) > float(best.data.get("lead", 1.0)):
			best = m
	return best


func is_leader(a: WildAnimal) -> bool:
	return leader() == a


## The alpha is hurt badly or killed: the pack is routed till `now` + ROUT_S; it has no alpha till then.
func alpha_down(now: float) -> void:
	if is_instance_valid(alpha):
		alpha.set_meta(&"fallen_alpha", true)
		alpha.make_alpha(false)
	alpha = null
	routed_until = now + ROUT_S
	shadowing = false


## Whether the pack is routed now. Its time over, the strongest wolf left (not a fallen alpha) becomes the new alpha.
func is_routed(now: float) -> bool:
	if now < routed_until:
		return true
	if WildlifeSpecies.brain(species) == "pack" and (alpha == null or not is_instance_valid(alpha) or alpha.is_dead()):
		pick_alpha()
	return false


## The strongest living wolf (its health; never a fallen alpha) is made the alpha.
func pick_alpha() -> void:
	var best: WildAnimal = null
	for m in alive():
		if m.get_meta(&"fallen_alpha", false):
			continue
		if best == null or m.health > best.health:
			best = m
	alpha = best
	if best:
		best.make_alpha(true)


func raise_alarm(pos: Vector3, now: float) -> void:
	alarm_time = now
	alarm_pos = pos


func alarmed(now: float, within := 4.0) -> bool:
	return now - alarm_time < within


## Index of `a` among the living members (spreads a pack, places the followers).
func slot_of(a: WildAnimal) -> int:
	return maxi(alive().find(a), 0)


func centroid() -> Vector3:
	var c := Vector3.ZERO
	var al := alive()
	for m in al:
		c += m.global_position
	return c / maxf(al.size(), 1.0) if not al.is_empty() else home


# --- Memory --------------------------------------------------------------------------------------

## Remembers danger at pos (weight w: 1 a close call, 0.7 a shot heard, 1.5 a member killed).
func remember(pos: Vector3, w: float, now: float) -> void:
	for d in danger:
		if (d.pos as Vector3).distance_to(pos) < 25.0:
			d.w = maxf(_weight(d, now), 0.0) + w
			d.t = now
			d.pos = pos
			return
	danger.append({"pos": pos, "t": now, "w": w})
	if danger.size() > 12:
		danger.pop_front()


func _weight(d: Dictionary, now: float) -> float:
	return float(d.w) * exp(-(now - float(d.t)) / DANGER_S)


## How much remembered danger lies on pos (0 = none; ~1 = the site of a close call, recently).
func danger_at(pos: Vector3, now: float, radius := 80.0) -> float:
	var s := 0.0
	for d in danger:
		var k := 1.0 - (d.pos as Vector3).distance_to(pos) / radius
		if k > 0.0:
			s += _weight(d, now) * k
	return s


## Jumpiness from recent danger: 1 calm .. 2 very skittish (scales how fast the animals take alarm).
func nerves(now: float) -> float:
	var s := 0.0
	for d in danger:
		s += _weight(d, now)
	return clampf(1.0 + 0.4 * s, 1.0, 2.0)


# --- Roles ---------------------------------------------------------------------------------------

## The sentry post goes round the herd while it feeds (nobody while it does something else).
func update_sentry(now: float, rng: RandomNumberGenerator) -> void:
	var al := alive()
	if activity != Activity.FEED or al.size() < 2:
		sentry = null
		return
	if sentry == null or not is_instance_valid(sentry) or sentry.is_dead() or now >= sentry_until:
		var i := (al.find(sentry) + 1) % al.size() if sentry and is_instance_valid(sentry) else rng.randi() % al.size()
		sentry = al[i]
		sentry_until = now + rng.randf_range(SENTRY_S.x, SENTRY_S.y)
