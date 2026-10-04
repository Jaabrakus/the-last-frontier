class_name Anatomy
extends Node3D
## The skeleton map under every body (user 2026-09-30, from a ragdoll video: "we dont need a x ray we just need a underlay where
## each person has a skeleton map"), and since 2026-10-03 the body every shot is worked out in (the user, of another game's body
## viewer: "i want that to be how our game detects hits and etc they have a perfect skeleton mesh"): the fitted body of BodyModel
## (bones as they are, the organs, the brain and brainstem, the cord, the great vessels and the limbs' arteries and veins, the
## flesh), one per kind of body, shared, read only.
##
## One Anatomy a body (attach_to: under its skeleton), light: it keeps the body's shots and makes nothing to draw until the map
## is shown (N, show_map) or the body is inspected (InspectView); nothing of it runs per frame.
##   add_wound(point, direction, damage)   a hit: the round's path through the body (BodyModel.trace: the shapes it crosses in
##                       order, the energy each takes, in, out or stopped), the labels of what it did ("Heart, punctured",
##                       "Left femoral artery, cut", "Spinal cord, badly injured at T10", "Left rib 5, fractured"), what it
##                       comes to (effect: the damage table) and the shot kept (shots: entry, exit or stop, the path, every
##                       structure crossed; the latest flagged). What struck is Hit.shot's (a ball, an arrow, a thrown spear, a
##                       blade; its speed and mass), else a ball of the damage's energy. A line that crosses none of the body
##                       grazes the flesh it passes within GRAZE_M of, else it is a clean miss (fx.missed: the coarse collider
##                       caught it, the body was not there; the fighters and the animals take nothing from it); a hit a script
##                       deals with no round (Hit.shot empty), and any on the player's own body, always lands (the nearest flesh)
##   effect(hits, damage)                  the damage table (see DAMAGE below): the brain or brainstem dead at once, the heart and
##                       the aorta down in seconds, the arteries fast and pulsing, the veins slower, the lungs slow and the
##                       breath short, the cord by its level (C1-C4 dead, to T6 mortal and down, below that the legs), a long
##                       bone broken (an arm cannot hold, a leg limps or gives), the gut a slow bleed, muscle light
##   the map (N)          the bones, organs, vessels and cord drawn under the faded skin, a mesh a bone (BodyMeshes), and each
##                       shot's channel (a red line) with its label, all riding the bones (the animation, the ragdoll)
##
##   humans    the player's and the fighters' rig (Actor_B)
##   animals   the stand-in quadrupeds' rig (Back, Torso2, Neck1, FrontUpperLeg.L ..; bison, deer, wolf, fox)
## All sizes are metres: the skeleton's own scale (the animals' armature is 38x) is taken out in each shape's frame.

## On or off for every body (N).
static var shown := false
## The hit-cam's slow-mo (off for films: the trailer sets it so).
static var slowmo_on := true

const WOUND := Color(0.92, 0.05, 0.05, 0.95)
## How far the body's skin fades while the map is shown (0 solid .. 1 gone).
const SKIN_FADE := 0.72
## The map's colours' strength (the parts' own alpha times this).
const MAP_ALPHA := 0.85
## How fast a flesh wound loses blood against the base drain (PlayerWounds.DRAIN).
const FLESH_DRAIN := 0.7
## Mortal wounds: dead in this many seconds untreated, on their feet till then (treatment stretches it: PlayerWounds).
const MORTAL_HEART_S := 8.0
const MORTAL_CORD_S := 12.0
const MORTAL_AORTA_S := 15.0
const MORTAL_CAROTID_S := 30.0
## A line that misses every shape of the body by no more than this (m) grazes the nearest flesh.
const GRAZE_M := 0.035
## A brief slow-down of time on a mortal hit: scale and real seconds (not in headless runs or tests).
const SLOWMO := Vector2(0.3, 0.55)
## THE DAMAGE TABLE (the user, 2026-10-03: "damage comes from what it crossed"). Organs and vessels by name (a vessel by its name
## without its side): [the animals' wound kind (WildlifeSpecies.WOUNDS), damage x, blood lost x, drain x (PlayerWounds.DRAIN: how
## fast it goes), mortal clock (s, 0 none)]. Nicked (the round's edge only), a vessel's drain and blood are NICKED of it, no clock.
const DAMAGE := {
	"Brain": ["head", 2.5, 1.0, 1.0, 0.0],
	"Brainstem": ["head", 2.5, 1.0, 1.0, 0.0],
	"Heart": ["heart", 2.0, 2.5, 3.0, MORTAL_HEART_S],
	"Left lung": ["lungs", 1.3, 1.8, 1.7, 0.0],
	"Right lung": ["lungs", 1.3, 1.8, 1.7, 0.0],
	"Liver": ["gut", 1.3, 2.0, 1.3, 0.0],
	"Spleen": ["gut", 1.3, 2.0, 1.3, 0.0],
	"Left kidney": ["gut", 1.3, 2.0, 1.3, 0.0],
	"Right kidney": ["gut", 1.3, 2.0, 1.3, 0.0],
	"Stomach": ["gut", 1.0, 1.5, 0.5, 0.0],
	"Intestines": ["gut", 1.0, 1.5, 0.5, 0.0],
	"Aorta": ["heart", 1.6, 3.0, 3.5, MORTAL_AORTA_S],
	"Superior vena cava": ["artery", 1.3, 2.2, 2.5, 0.0],
	"Inferior vena cava": ["artery", 1.3, 2.2, 2.5, 0.0],
	"Vena cava": ["artery", 1.3, 2.2, 2.5, 0.0],
	"carotid artery": ["artery", 1.4, 2.5, 3.0, MORTAL_CAROTID_S],
	"subclavian artery": ["artery", 1.2, 2.2, 2.8, 0.0],
	"iliac artery": ["artery", 1.2, 2.2, 2.8, 0.0],
	"femoral artery": ["artery", 1.2, 2.2, 2.8, 0.0],
	"brachial artery": ["artery", 1.1, 1.8, 2.2, 0.0],
	"popliteal artery": ["artery", 1.1, 1.8, 2.2, 0.0],
	"radial artery": ["", 1.0, 1.3, 1.2, 0.0],
	"ulnar artery": ["", 1.0, 1.3, 1.2, 0.0],
	"jugular vein": ["vein", 1.1, 1.6, 1.6, 0.0],
	"subclavian vein": ["vein", 1.0, 1.4, 1.4, 0.0],
	"iliac vein": ["vein", 1.0, 1.4, 1.4, 0.0],
	"femoral vein": ["vein", 1.0, 1.4, 1.4, 0.0],
	"brachial vein": ["vein", 1.0, 1.2, 1.1, 0.0],
	"popliteal vein": ["vein", 1.0, 1.2, 1.1, 0.0],
}
const NICKED := 0.6
## Bones: a long bone of a leg broken leaves this of the walk (1 whole; the femur gives way under the weight), chipped LIMP_CHIPPED.
## (An animal's foreleg bones are its legs': the humerus, the radius, the cannons.)
const LIMP := {"femur": 0.45, "tibia": 0.6, "fibula": 0.85, "foot": 0.7, "kneecap": 0.6, "Pelvis": 0.5, "humerus": 0.55,
		"radius": 0.6, "fore cannon": 0.6, "hind cannon": 0.6}
const LIMP_CHIPPED := 0.85
## The animals' wound kinds, worst last.
const RANK := {"": 0.0, "graze": 1.0, "leg": 2.0, "vein": 2.5, "gut": 3.0, "lungs": 4.0, "artery": 4.5, "head": 5.0, "spine": 6.0,
		"heart": 7.0}

var skeleton: Skeleton3D
var model: BodyModel
var human := false
## Every shot into this body, in order: {n, rec (BodyModel.trace), lines, fx (effect), hits, damage, kind, speed, energy, graze,
## missed, latest, point, dir, at_ms}.
var shots: Array[Dictionary] = []
## The old record ({point, dir, lines} a wound) for what still reads it.
var wounds: Array[Dictionary] = []
## What the last shot went through, in order from the entry: [{name, kind ("organ" "cord" "bone" "rib" "vessel" "flesh" "miss"),
## sub, res, lvl, vessel, side, limb}] (one row a structure).
var last_hits: Array[Dictionary] = []
var last_shot: Dictionary = {}
## The player's own body: a line the capsule caught but the body did not is a graze, never a clean miss (the player's hit takes
## the damage its effect says; a nothing would still be a blow felt, a spell or a swing broken off for it).
var on_player := false
## The drawn parts: {name, kind, node (a marker at its middle, riding its bone), i (the shape)}; made on first read (the map).
var parts: Array[Dictionary]:
	get:
		_build_view()
		return _parts

var _parts: Array[Dictionary] = []
var _built := false
var _attach := {}                     ## bone index -> BoneAttachment3D
var _mat: StandardMaterial3D
var _shot_nodes: Array[Node] = []


## The anatomy of the body on `sk` (a human rig: bones "spined", "heada"; else a quadruped's), or null when the rig is not known.
static func attach_to(sk: Skeleton3D) -> Anatomy:
	if sk == null:
		return null
	var existing := sk.get_node_or_null(^"Anatomy") as Anatomy
	if existing:
		return existing
	var m := BodyModel.of(sk)
	if m == null:
		return null
	var a := Anatomy.new()
	a.name = "Anatomy"
	a.skeleton = sk
	a.model = m
	a.human = m.human
	a.visible = false
	var n: Node = sk
	while n != null and not a.on_player:
		a.on_player = n is FrontierPlayer
		n = n.get_parent()
	sk.add_child(a)
	if shown:
		a.show_map(true)
	return a


## The anatomy already on `sk` (null none: nothing has hit it).
static func of(sk: Skeleton3D) -> Anatomy:
	return sk.get_node_or_null(^"Anatomy") as Anatomy if sk != null else null


func _enter_tree() -> void:
	add_to_group(&"anatomy")


# ---------------------------------------------------------------------------------------------------------------------
# Wounds


## A round that struck at `point` going `direction`: its path through the body worked out (BodyModel.trace), kept (shots), what it
## did in words (returned: the label's lines) and in effect (last_hits for effect()). `shot`: what struck ({kind, speed, mass});
## {} Hit.shot's, else a ball of `damage`'s energy. `_reach` is no longer used (the round's energy decides how far it goes).
func add_wound(point: Vector3, direction: Vector3, damage := 50.0, _reach := -1.0, shot := {}) -> Array[String]:
	var dir := direction.normalized() if direction.length_squared() > 1e-8 else Vector3.DOWN
	var sh: Dictionary = shot if not shot.is_empty() else Hit.shot
	var rnd := BodyModel.round_of(sh, damage)
	if String(rnd.kind) == "blunt":
		last_hits.clear()
		last_shot = {}
		return []
	var rec := model.trace(skeleton, point, dir, rnd)
	var graze := ""
	var graze_i := -1
	if bool(rec.missed):
		# (a clean miss only for a round that was really fired, Hit.shot's: a hit a script deals, with no round, still lands)
		graze_i = _near_flesh(point, dir, on_player or sh.is_empty())
		graze = String(model.shapes[graze_i].name) if graze_i >= 0 else ""
	var hits := _hits_of(rec, graze)
	var lines := lines_of(rec, hits, graze, human)
	last_hits = hits
	var fx := effect(hits, damage)
	var entry := {"n": shots.size() + 1, "rec": rec, "lines": lines, "fx": fx, "hits": hits, "damage": damage, "kind": rnd.kind,
			"speed": float(rnd.speed), "energy": float(rnd.energy), "graze": graze, "missed": bool(rec.missed) and graze == "",
			"latest": true, "point": point, "dir": dir, "at_ms": Time.get_ticks_msec(),
			"entry_a": (rec.holes[0] as Dictionary).a if not (rec.holes as Array).is_empty() else _anchor_near(point, graze_i)}
	for s in shots:
		s.latest = false
	shots.append(entry)
	last_shot = entry
	wounds.append({"point": point, "dir": dir, "lines": lines})
	if _built:
		_draw_shot(entry)
	return lines


## The flesh shape nearest the line (within GRAZE_M of it; `any`: at any distance), -1 none.
func _near_flesh(point: Vector3, dir: Vector3, any := false) -> int:
	var best := -1
	var best_d := INF if any else GRAZE_M
	var a := point - dir * model.back
	var b := point + dir * model.reach
	var ov := BodyModel.overrides(skeleton)
	var memo := {}
	for i in model.shapes.size():
		var s := model.shapes[i]
		if String(s.kind) != "flesh":
			continue
		var w := model.shape_world(skeleton, i, ov, memo)
		var sz := s.s as Vector3
		var r := maxf(sz.x, sz.z) if String(s.t) != "cap" else sz.x
		var half := sz.y if String(s.t) != "ell" else 0.0
		var ax := w.basis.y.normalized()
		var d := BodyModel._seg_dist(a, b, w.origin - ax * half, w.origin + ax * half) - r
		if d < best_d:
			best_d = d
			best = i
	return best


func _anchor_near(point: Vector3, i: int) -> Dictionary:
	var ov := BodyModel.overrides(skeleton)
	var memo := {}
	if i >= 0:
		return BodyModel.anchor(skeleton, int(model.shapes[i].bone), point, ov, memo)
	var best := 0
	var bd := INF
	for b: int in model.groups:
		var d := (skeleton.global_transform * BodyModel.pose(skeleton, b, ov, memo)).origin.distance_to(point)
		if d < bd:
			bd = d
			best = b
	return BodyModel.anchor(skeleton, best, point, ov, memo)


## The rows of a record (one a structure, in order from the entry, the worst result kept): for effect().
func _hits_of(rec: Dictionary, graze: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bool(rec.missed):
		if graze != "":
			out.append({"name": graze, "kind": "flesh", "sub": "", "res": "grazed", "lvl": 0})
		else:
			out.append({"name": "Missed", "kind": "miss", "sub": "", "res": "", "lvl": 0})
		return out
	var at := {}
	for row: Dictionary in rec.crossed:
		var shp := model.shapes[int(row.i)]
		var key := String(row.name) + ("@%d" % int(row.lvl) if String(row.kind) == "cord" else "")
		var h := {"name": String(row.name), "kind": "rib" if String(shp.get("sub", "")) == "rib" else String(row.kind),
				"sub": String(shp.get("sub", "")), "res": String(row.res), "lvl": int(row.lvl), "vessel": String(shp.get("vessel", "")),
				"side": String(shp.get("side", "")), "limb": String(shp.get("limb", "")), "e_in": float(row.e_in),
				"dep": float(row.get("dep", 0.0)), "lodged": bool(row.get("lodged", false))}
		if at.has(key):
			var old: Dictionary = out[int(at[key])]
			if _worse(String(h.res), String(old.res)):
				old.res = h.res
			if String(old.sub) == "process" and String(h.sub) == "vertebra":
				old.sub = "vertebra"          # (the arch or the body too: the cord's)
			old.dep = float(old.dep) + float(h.dep)
			old.lodged = bool(old.lodged) or bool(h.lodged)
			continue
		at[key] = out.size()
		out.append(h)
	return out


static func _worse(a: String, b: String) -> bool:
	var order := {"": 0, "torn": 1, "grazed": 2, "bruised": 2, "nicked": 3, "chipped": 3, "punctured": 4, "cut": 5, "injured": 5,
			"fractured": 5}
	return int(order.get(a, 0)) > int(order.get(b, 0))


## A level's name: C1..C7, T1..T12 (an animal's T1..T13), L1.. (`lvl` 1 at the head).
static func level_tag(lvl: int, is_human := true) -> String:
	var nt := 12 if is_human else 13
	if lvl <= 7:
		return "C%d" % maxi(lvl, 1)
	if lvl <= 7 + nt:
		return "T%d" % (lvl - 7)
	return "L%d" % (lvl - 7 - nt)


## The label's lines for a record: each structure the round crossed, in order from the entry, in words ("Heart, punctured",
## "Left femoral artery, cut", "Spinal cord, badly injured at T10", "Left rib 5, fractured"), the flesh only when nothing else
## was hit, and where it went: "Through and through" or "Ball lodged in the left femur".
static func lines_of(rec: Dictionary, hits: Array, graze := "", is_human := true) -> Array[String]:
	var lines: Array[String] = []
	if bool(rec.get("missed", false)):
		if graze != "":
			lines.append("%s, grazed" % graze)
		return lines
	var notable := hits.filter(func(h: Dictionary) -> bool: return String(h.kind) != "flesh")
	for h: Dictionary in (notable if not notable.is_empty() else hits):
		var nm := String(h.name)
		match String(h.kind):
			"cord":
				lines.append("Spinal cord, %s at %s" % ["badly injured" if String(h.res) == "injured" else "bruised", level_tag(int(h.lvl), is_human)])
			"flesh":
				lines.append("%s, flesh wound" % nm)
			_:
				lines.append("%s, %s" % [nm, String(h.res)])
		if lines.size() >= 6:
			break
	var what: String = {"ball": "Ball", "arrow": "Arrow", "dart": "Dart", "spear": "Spear", "tomahawk": "Blade", "blade": "Blade"}.get(
			String((rec.round as Dictionary).get("kind", "ball")), "Ball")
	if Vector3(rec.exit) != Vector3.INF:
		lines.append("Through and through")
	elif Vector3(rec.stop) != Vector3.INF and String(rec.stopped_in) != "":
		var where := String(rec.stopped_in)
		lines.append("%s lodged in the %s" % [what, where.to_lower() if not where.contains("vertebra") and not where.begins_with("T") else where])
	return lines


## What a wound that went through `hits` (last_hits) comes to, for a blow of `damage`: {
##   lethal      dead at once (the brain, the brainstem, the cord at C1-C4)
##   mortal_s    a mortal wound: dead in this many seconds, on their feet till then (the heart 8, the aorta 15, the cord to T6 12, a
##               carotid 30; the soonest of them; treatment stretches it: PlayerWounds)
##   dmg_mult    x the blow's damage (what it tore through; muscle alone 0.8, a graze 0.4, a clean miss 0)
##   bleed_mult  x the blood it loses after
##   drain_mult  how fast the blood goes (x PlayerWounds.DRAIN): the arteries fastest, then the heart and great veins, the lungs, the
##               liver and kidneys, the gut slow, a flesh wound slower still (FLESH_DRAIN)
##   artery      a main artery cut: the bleed pulses; vein: a vein cut; breath: a lung (the breath is short: no running)
##   legs, down  the cord below C4 cut, or both legs broken: the legs are gone, down for good; cord_lvl its level (1 at C1)
##   limb        a limb's bone broken ("" none, the player's maiming reads it: "Left femur", "Left shin", "Left foot"); arm: an
##               arm's bone broken (it cannot hold or aim); leg: a leg's; limp: what is left of the walk (1 whole)
##   kind        an animal's wound kind (WildlifeSpecies.WOUNDS: heart, artery, lungs, spine, head, gut, vein, leg, graze), "" none
##   why         the structure that decided it; missed: a clean miss (the coarse collider caught it, the body was not there) }
static func effect(hits: Array, damage: float) -> Dictionary:
	var out := {"lethal": false, "mortal_s": 0.0, "dmg_mult": 1.0, "bleed_mult": 1.0, "drain_mult": -1.0, "legs": false, "down": false,
			"limb": "", "arm": "", "leg": "", "limp": 1.0, "kind": "", "why": "", "artery": false, "vein": false, "breath": false,
			"cord_lvl": 0, "missed": false, "graze": false}
	var serious := damage >= 25.0
	var levels: Array[int] = []
	var organ_dr := -1.0
	var other_dr := -1.0
	var notable := false
	var mortal := INF
	var legs_broken := {}
	for h: Dictionary in hits:
		var nm := String(h.name)
		var res := String(h.get("res", ""))
		var hk := String(h.kind)
		var kind := ""
		var dm := 1.0
		var bm := 1.0
		var dr := FLESH_DRAIN
		var vital := false
		match hk:
			"miss":
				out.missed = true
				out.dmg_mult = 0.0
				out.drain_mult = 0.0
				out.bleed_mult = 0.0
				return out
			"flesh":
				if res == "grazed":
					out.graze = true
					kind = "graze"
					dm = 0.4
					dr = 0.4
				else:
					dm = 0.8
			"organ", "vessel":
				var row: Array = DAMAGE.get(nm, DAMAGE.get(_stem(nm), []))
				if row.is_empty():
					row = ["gut", 1.0, 1.5, 0.8, 0.0]
				var nick := res == "nicked" or res == "grazed"
				kind = String(row[0])
				dm = float(row[1])
				bm = float(row[2]) * (NICKED if nick else 1.0)
				dr = float(row[3]) * (NICKED if nick else 1.0)
				vital = true
				if nm == "Brain" or nm == "Brainstem":
					if res != "grazed" and (res == "punctured" or serious):
						out.lethal = true
				elif float(row[4]) > 0.0 and not nick and (res != "" or serious):
					mortal = minf(mortal, float(row[4]))
				if hk == "vessel":
					if String(h.get("vessel", "")) == "vein" or nm.contains("vein") or nm.contains("vena"):
						out.vein = true
					else:
						out.artery = true
				if nm.ends_with("lung"):
					out.breath = true
			"cord":
				vital = true
				if res == "injured" or (res == "" and serious):
					kind = "spine"
					dm = 1.5
					dr = 1.0
					var lv := int(h.get("lvl", 0))
					if lv <= 0:
						lv = _level(nm.get_slice("injured at ", 1))
					levels.append(lv)
				else:
					dm = 1.2
			"bone", "rib":
				notable = true
				var sub := String(h.get("sub", ""))
				var broke := res == "fractured" or (res == "" and serious)
				if nm == "Skull" or sub == "skull":
					kind = "head"
					dm = 1.5
				elif sub == "jaw" or nm == "Jaw":
					dm = 1.2
				elif nm.contains("vertebra"):
					dm = 1.5
					if broke and sub != "process":
						# (a round through a vertebra's body or the arch round the canal breaks into it: the cord at that level; a
						# spinous or transverse process broken off does not)
						kind = "spine"
						var lv2 := int(h.get("lvl", 0))
						levels.append(lv2 if lv2 > 0 else _level(nm.get_slice(" ", 0)))
				elif hk == "rib" or sub == "rib" or nm == "Sternum" or nm.ends_with("scapula") or nm == "Sacrum":
					dm = 1.1
				else:
					var limb := String(h.get("limb", ""))
					var stem := _stem(nm)
					if nm == "Pelvis":
						limb = "leg"
						stem = "Pelvis"
					elif nm.ends_with("clavicle"):
						limb = "arm"
					if limb == "arm" and broke:
						out.arm = nm
						out.limb = nm
						kind = "leg"
					elif limb == "leg":
						kind = "leg"
						var lp := float(LIMP.get(stem, 0.7)) if broke else LIMP_CHIPPED
						out.limp = minf(float(out.limp), lp)
						if broke:
							out.leg = nm
							out.limb = _common(nm)
							if lp <= 0.6:
								legs_broken[String(h.get("side", nm.get_slice(" ", 0)))] = true
		if hk != "flesh":
			notable = true
		if float(RANK.get(kind, 0.0)) > float(RANK.get(String(out.kind), 0.0)):
			out.kind = kind
			out.why = nm
		out.dmg_mult = maxf(float(out.dmg_mult), dm) if hk != "flesh" else float(out.dmg_mult)
		out.bleed_mult = maxf(float(out.bleed_mult), bm)
		if vital:
			organ_dr = maxf(organ_dr, dr)
		else:
			other_dr = maxf(other_dr, dr)
	if not notable and not hits.is_empty():
		# muscle only: light (a graze lighter still)
		out.dmg_mult = 0.4 if bool(out.graze) else 0.8
	out.dmg_mult = minf(float(out.dmg_mult), 3.0)
	out.drain_mult = organ_dr if organ_dr >= 0.0 else (other_dr if other_dr >= 0.0 else FLESH_DRAIN)
	if mortal < INF:
		out.mortal_s = mortal
	if not levels.is_empty():
		# the cord at the highest level it was hurt: C1-C4 the breath stops (dead); to T6 the breath fails (mortal) and the body
		# goes down; below that the legs go, down for good
		levels.sort()
		var lvl: int = levels[0]
		out.cord_lvl = lvl
		if lvl <= 4:
			out.lethal = true
		elif lvl <= 13:
			out.mortal_s = minf(float(out.mortal_s), MORTAL_CORD_S) if float(out.mortal_s) > 0.0 else MORTAL_CORD_S
			out.legs = true
			out.down = true
		else:
			out.legs = true
			out.down = true
	if legs_broken.size() >= 2:
		out.down = true
	return out


## A name without its side ("Left femoral artery" -> "femoral artery").
static func _stem(nm: String) -> String:
	if nm.begins_with("Left "):
		return nm.substr(5)
	if nm.begins_with("Right "):
		return nm.substr(6)
	return nm


## The bone's everyday name for the player's notes ("Left tibia" -> "Left shin").
static func _common(nm: String) -> String:
	for b: String in ["tibia", "fibula"]:
		if nm.ends_with(b):
			return nm.replace(b, "shin")
	return nm


## A vertebra's number down the whole column: C1..C7 1..7, T1..T12 8..19, L1..L5 20..24 ("T10" -> 17).
static func _level(tag: String) -> int:
	var n := int(tag.substr(1))
	if tag.begins_with("C"):
		return n
	if tag.begins_with("T"):
		return 7 + n
	return 19 + n


## The wound report: the lines a channel went through, as one line ("Heart, punctured  ·  Lung, punctured").
static func report(lines: Array) -> String:
	return "  ·  ".join(lines.slice(0, 3))


## Time slows for SLOWMO.y real seconds (a clean kill, a mortal wound): the hit seen. Not headless.
static func slowmo(tree: SceneTree) -> void:
	# (not in a shared world: time is everyone's there, one machine's slow motion would put it out of step)
	var ns := NetSession.find(tree) if tree else null
	if ns != null and ns.in_session():
		return
	if not slowmo_on or tree == null or DisplayServer.get_name() == "headless" or Engine.time_scale < 0.99:
		return
	Engine.time_scale = SLOWMO.x
	tree.create_timer(SLOWMO.y, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


# ---------------------------------------------------------------------------------------------------------------------
# The map (N)


## Every body's underlay on or off (the N key); bodies built since follow.
static func set_shown(on: bool, tree: SceneTree, fade_s := 0.0) -> void:
	shown = on
	for n in tree.get_nodes_in_group(&"anatomy"):
		(n as Anatomy).show_map(on, fade_s)


## The map on or off for this body: the body's skin fades so it can be seen inside (and comes back). `fade_s` > 0: it comes
## in (or goes) over that long (a film's). Hidden, what was drawn for it is let go (nothing of it stays to update).
func show_map(on: bool, fade_s := 0.0) -> void:
	if on:
		_build_view()
	visible = on or fade_s > 0.0
	var skin: Array[MeshInstance3D] = []
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		if not is_ancestor_of(mi):
			skin.append(mi as MeshInstance3D)
	for g in skin:
		if on and not g.has_meta(&"anatomy_was"):
			g.set_meta(&"anatomy_was", g.transparency)
	var apply := func(k: float) -> void:
		# k 0 .. 1 toward the map shown
		for g in skin:
			if is_instance_valid(g) and g.has_meta(&"anatomy_was"):
				var was := float(g.get_meta(&"anatomy_was"))
				g.transparency = lerpf(was, maxf(was, SKIN_FADE), k)
		if _mat:
			_mat.albedo_color.a = MAP_ALPHA * k
		if k <= 0.0:
			visible = false
			for g in skin:
				if is_instance_valid(g) and g.has_meta(&"anatomy_was"):
					g.remove_meta(&"anatomy_was")
			_free_view()
	if fade_s > 0.0 and is_inside_tree():
		var tw := create_tween()
		tw.tween_method(apply, 0.0 if on else 1.0, 1.0 if on else 0.0, fade_s)
	else:
		apply.call(1.0 if on else 0.0)


func _attach_for(bone: int) -> BoneAttachment3D:
	if not _attach.has(bone):
		var ba := BoneAttachment3D.new()
		ba.name = "A_%d" % bone
		add_child(ba)
		ba.use_external_skeleton = true
		ba.external_skeleton = ba.get_path_to(skeleton)
		ba.bone_idx = bone
		# (placed now: a skeleton at rest for good is never updated again; as the body shows it, a ragdoll's pose over its own)
		ba.transform = BodyModel.pose(skeleton, bone, BodyModel.overrides(skeleton), {})
		_attach[bone] = ba
	return _attach[bone]


## The map drawn: a mesh a bone (its shapes merged, in their colours; the flesh not drawn: the faded skin is it), a marker at each
## shape's middle (parts), each shot's channel and label.
func _build_view() -> void:
	if _built or model == null or skeleton == null:
		return
	_built = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = Color(1, 1, 1, MAP_ALPHA)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 40                 # (depth-tested: it lies inside the body, the skin faded over it)
	for b: int in model.groups:
		var list: Array = []
		var xfs: Array = []
		var cols: Array = []
		var ba := _attach_for(b)
		for i: int in model.groups[b].list:
			var s := model.shapes[i]
			var marker := MeshInstance3D.new()       # (no mesh: a place, read as the parts' nodes always were)
			ba.add_child(marker)
			marker.transform = s.xf
			_parts.append({"name": String(s.name), "kind": String(s.kind), "node": marker, "i": i})
			if String(s.kind) == "flesh":
				continue
			list.append(s)
			xfs.append(s.xf)
			cols.append(_colour(s))
		if list.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = BodyMeshes.merged(list, xfs, cols)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(mi)
	for e in shots:
		_draw_shot(e)


## A shape's colour on the map.
static func _colour(s: Dictionary) -> Color:
	var c: Color = s.col
	match String(s.kind):
		"bone":
			c.a = 0.22 if String(s.get("sub", "")) == "skull" else 0.55
		"organ":
			c.a = 0.7
		"vessel":
			c.a = 0.8
		"cord":
			c.a = 0.85
	return c


func _free_view() -> void:
	if not _built:
		return
	_built = false
	for ba: BoneAttachment3D in _attach.values():
		if is_instance_valid(ba):
			ba.queue_free()
	_attach.clear()
	_parts.clear()
	_shot_nodes.clear()
	_mat = null


## A shot's channel (a red line from where it went in to where it came out or stopped) and its label, on the bone nearest each.
func _draw_shot(e: Dictionary) -> void:
	var rec: Dictionary = e.rec
	var lines: Array = e.lines
	var ov := BodyModel.overrides(skeleton)
	var memo := {}
	var a := BodyModel.where(skeleton, e.entry_a, ov, memo)
	var b := Vector3.INF
	var end_a: Dictionary = {}
	if not (rec.path as Array).is_empty():
		end_a = (rec.path as Array)[-1]
		b = BodyModel.where(skeleton, end_a, ov, memo)
	var ba := _attach_for(int((e.entry_a as Dictionary).b))
	if b != Vector3.INF and a.distance_to(b) > 0.005:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.006
		cyl.bottom_radius = 0.006
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 6
		cyl.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = WOUND
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.render_priority = 41
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(mi)
		var y := (b - a).normalized()
		var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
		mi.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
		_shot_nodes.append(mi)
	if lines.is_empty():
		return
	var l := Label3D.new()
	l.text = "\n".join(lines)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true          # (a label reads through the body)
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.font_size = 26
	l.outline_size = 8
	l.modulate = Color(1, 1, 1, 0.95)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.render_priority = 60
	ba.add_child(l)
	l.global_position = a + Vector3.UP * 0.12
	l.global_basis = Basis.IDENTITY
	_shot_nodes.append(l)
