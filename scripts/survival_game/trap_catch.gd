class_name TrapCatch
extends RefCounted
## What a trap on the line holds (TrapStation, user 2026-09-28 "trapping lines"): the dead catch, a procedural body in
## its species' colours (the rules' trap species: mink, marten, fisher, fox, raccoon, wolf, and "small", a hare), laid
## in the sprung trap (place_in): beside a steel trap by the foreleg in its jaws, hung by the neck from a snare's
## sprung pole, pinned belly-down under a deadfall's log. Built standing (body along +X, the head forward, feet down
## -Y) and turned to lie. The project's own (no assets).

## len: nose to rump (m); h: the body's depth; fur, belly; tail: its length (share of len) and thickness; ear: height;
## leg: length; snout: how long the muzzle.
const LOOK := {
	"mink": {"len": 0.4, "h": 0.07, "fur": Color(0.2, 0.12, 0.07), "belly": Color(0.25, 0.16, 0.1), "tail": 0.4, "tail_r": 0.018, "ear": 0.012, "leg": 0.05, "snout": 0.8},
	"marten": {"len": 0.52, "h": 0.09, "fur": Color(0.34, 0.23, 0.14), "belly": Color(0.86, 0.62, 0.3), "tail": 0.42, "tail_r": 0.03, "ear": 0.022, "leg": 0.07, "snout": 0.9},
	"fisher": {"len": 0.75, "h": 0.13, "fur": Color(0.14, 0.1, 0.08), "belly": Color(0.3, 0.25, 0.2), "tail": 0.45, "tail_r": 0.04, "ear": 0.022, "leg": 0.1, "snout": 0.9},
	"fox": {"len": 0.68, "h": 0.19, "fur": Color(0.78, 0.36, 0.12), "belly": Color(0.95, 0.92, 0.88), "tail": 0.6, "tail_r": 0.055, "ear": 0.06, "leg": 0.24, "snout": 1.4},
	"raccoon": {"len": 0.6, "h": 0.2, "fur": Color(0.44, 0.41, 0.37), "belly": Color(0.6, 0.56, 0.5), "tail": 0.42, "tail_r": 0.045, "ear": 0.035, "leg": 0.14, "snout": 1.0},
	"wolf": {"len": 1.15, "h": 0.36, "fur": Color(0.46, 0.44, 0.4), "belly": Color(0.78, 0.76, 0.72), "tail": 0.4, "tail_r": 0.065, "ear": 0.07, "leg": 0.45, "snout": 1.4},
	"small": {"len": 0.42, "h": 0.15, "fur": Color(0.5, 0.42, 0.32), "belly": Color(0.85, 0.82, 0.76), "tail": 0.06, "tail_r": 0.03, "ear": 0.1, "leg": 0.12, "snout": 0.8},
}
## Where each trap holds its catch (BuildGeometry._trap sprung): the noose at the end of the cord from the snare
## pole's tip, the deadfall's log.
const SNARE_NOOSE := BuildGeometry.SNARE_TIP - Vector3(0.0, 0.5, 0.0)
const DEADFALL_Z := 0.08
## How the body lies in each trap (build's `pose`).
const POSE := {"trap_steel": "side", "trap_snare": "hang", "trap_deadfall": "flat"}


static func look(sp: String) -> Dictionary:
	return LOOK.get(sp, LOOK.small)


## `pose`: "side" (on its side, the legs limp), "hang" (by the neck, the legs trailing), "flat" (belly-down, splayed).
static func build(sp: String, pose := "side") -> Node3D:
	var lk := look(sp)
	var root := Node3D.new()
	root.name = "Catch"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var L := float(lk.len)
	var h := float(lk.h)
	var a := L * 0.3
	var fur := GearModels._mat("catch_fur_" + sp, lk.fur, 0.95, 0.0)
	var belly := GearModels._mat("catch_belly_" + sp, lk.belly, 0.95, 0.0)
	var dark := GearModels._mat("catch_dark", Color(0.08, 0.07, 0.06), 0.9, 0.0)
	# the torso, the paler belly under it
	GearModels._sphere(body, Vector3(a, h * 0.5, h * 0.45), Vector3.ZERO, fur)
	GearModels._sphere(body, Vector3(a * 0.85, h * 0.36, h * 0.38), Vector3(0.0, -h * 0.16, 0.0), belly)
	# the neck, the head and the muzzle
	var hr := h * (0.36 if sp == "small" else 0.34)
	var hx := a + hr * 0.9
	GearModels._limb(body, Vector3(a * 0.7, h * 0.05, 0.0), Vector3(hx, h * 0.12, 0.0), h * 0.26, fur)
	GearModels._sphere(body, Vector3(hr, hr * 0.9, hr * 0.85), Vector3(hx, h * 0.14, 0.0), fur)
	var sn := float(lk.snout)
	GearModels._sphere(body, Vector3(hr * 0.6 * sn, hr * 0.42, hr * 0.42), Vector3(hx + hr * 0.75 * sn, h * 0.06, 0.0), belly if sp == "fox" or sp == "wolf" else fur)
	GearModels._sphere(body, Vector3(hr * 0.14, hr * 0.14, hr * 0.14), Vector3(hx + hr * 1.3 * sn, h * 0.08, 0.0), dark)
	if sp == "raccoon":
		# the mask across the eyes
		GearModels._box(body, Vector3(hr * 0.5, hr * 0.3, hr * 1.75), Vector3(hx + hr * 0.45, h * 0.22, 0.0), dark)
	# the ears (a hare's long, laid back along the neck)
	var ear := float(lk.ear)
	for sz: float in [-1.0, 1.0]:
		if sp == "small":
			var e0 := Vector3(hx - hr * 0.1, h * 0.14 + hr * 0.7, sz * hr * 0.3)
			GearModels._sphere(body, Vector3(ear * 0.5, ear * 0.1, ear * 0.2), e0 + Vector3(-ear * 0.45, ear * 0.08, sz * 0.01), fur)
		else:
			GearModels._sphere(body, Vector3(ear * 0.35, ear * 0.5, ear * 0.3), Vector3(hx - hr * 0.2, h * 0.14 + hr * 0.8 + ear * 0.35, sz * hr * 0.45), fur)
	# the legs: limp, trailing or splayed
	var leg := float(lk.leg) + h * 0.2
	for p: Vector3 in [Vector3(a * 0.65, 0, 1), Vector3(a * 0.65, 0, -1), Vector3(-a * 0.65, 0, 1), Vector3(-a * 0.65, 0, -1)]:
		var top := Vector3(p.x, -h * 0.25, p.z * h * 0.28)
		var d := Vector3(0.0, -leg, p.z * h * 0.05)
		match pose:
			"hang":
				d = Vector3(-leg * 0.8, -leg * 0.5, p.z * h * 0.08)
			"flat":
				d = Vector3(leg * 0.45 * signf(p.x), -h * 0.1, p.z * leg * 0.85)
		GearModels._limb(body, top, top + d, h * 0.11, fur)
	# the tail
	var tl := float(lk.tail) * L
	var t0 := Vector3(-a * 0.95, h * 0.05, 0.0)
	var t1 := t0 + Vector3(-tl, -h * 0.15, 0.0)
	if sp == "small":
		GearModels._sphere(body, Vector3(0.03, 0.03, 0.03), t0 + Vector3(-0.02, 0.02, 0.0), belly)
	else:
		GearModels._limb(body, t0, t1, float(lk.tail_r), fur)
		if sp == "fox":
			GearModels._sphere(body, Vector3(0.05, 0.04, 0.04), t1, belly)
		elif sp == "raccoon":
			for i in 4:
				var q := t0.lerp(t1, 0.25 + i * 0.2)
				GearModels._sphere(body, Vector3(0.022, float(lk.tail_r) * 1.1, float(lk.tail_r) * 1.1), q, dark)
	return root


## The catch's place in the sprung trap `kind`'s frame (TrapStation's).
static func place_in(kind: String, sp: String) -> Transform3D:
	var lk := look(sp)
	var L := float(lk.len)
	var h := float(lk.h)
	var a := L * 0.3
	match kind:
		"trap_snare":
			# hung by the neck from the noose, head up, turned a little on the cord
			var b := Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, PI * 0.5)
			return Transform3D(b, SNARE_NOOSE - b * Vector3(a + h * 0.3, h * 0.1, 0.0))
		"trap_deadfall":
			# belly-down under the log across its back, the head out toward the trigger
			var b2 := Basis(Vector3.UP, -PI * 0.5)
			return Transform3D(b2, Vector3(0.05, h * 0.3, DEADFALL_Z - a * 0.2))
	# a steel trap: on its side beside the trap, a foreleg in the jaws
	var b3 := Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, PI * 0.5)
	var foot := Vector3(a * 0.65, -h * 0.25 - float(lk.leg) - h * 0.2, h * 0.28)
	var at := Vector3(0.0, 0.06, 0.0) - b3 * foot
	at.y = maxf(at.y, h * 0.45)
	return Transform3D(b3, at)
