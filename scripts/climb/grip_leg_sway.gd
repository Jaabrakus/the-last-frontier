class_name GripLegSway
extends SkeletonModifier3D
## Physics-based leg sway while gripping (user 2026-09-27: "the legs shaking like that wasnt the orignal one it was more
## sway and physics based"): each leg is a two-link chain hanging from its hip, the knee and the ankle point masses with
## inertia and gravity, held to the bone lengths and kept off the gripped surface, and pulled back toward the animated
## pose by a spring: stiff when calm (the grip pose shows as animated), slack when shaken (`shake`: the legs lag, trail
## and swing as the body is jerked about, and hang when the body is flung off the surface). The thigh and shin bones
## turn to point at the simulated knee and ankle; the feet keep their animated turn. PlayerGrip sets `shake` and the
## surface plane every tick, and fades `influence` in and out.

const LEGS := [["l_upper_leg", "l_knee", "l_ankle"], ["r_upper_leg", "r_knee", "r_ankle"]]
## How far off the surface the knee and the ankle stay (m).
const SKIN := 0.07

## 0 calm .. 1 shaken hard.
var shake := 0.0
## The gripped surface (world): the chain stays on its outer side.
var plane_on := false
var plane_point := Vector3.ZERO
var plane_normal := Vector3.UP
## The spring back to the animated pose (1/s): calm and fully shaken.
var pull_calm := 16.0
var pull_shaken := 2.2
var gravity := 9.8

var _ids: Array = []
var _pos: Array = []            ## per leg: [knee, ankle] (world)
var _prev: Array = []
var _fresh := true


## Starts the chains over from the animated pose (after a jump in the body's placement).
func reset() -> void:
	_fresh = true


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		for leg: Array in LEGS:
			var ids := [sk.find_bone(leg[0]), sk.find_bone(leg[1]), sk.find_bone(leg[2])]
			if ids.has(-1):
				return
			_ids.append(ids)
			_pos.append([Vector3.ZERO, Vector3.ZERO])
			_prev.append([Vector3.ZERO, Vector3.ZERO])
	var dt := clampf(get_process_delta_time(), 1.0 / 240.0, 1.0 / 20.0)
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var k := lerpf(pull_calm, pull_shaken, clampf(shake, 0.0, 1.0))
	var damp := exp(-1.4 * k * dt)
	for li in _ids.size():
		var ids: Array = _ids[li]
		var hg := sk.get_bone_global_pose(ids[0])
		var kg := sk.get_bone_global_pose(ids[1])
		var ag := sk.get_bone_global_pose(ids[2])
		var H := xf * hg.origin
		var targets := [xf * kg.origin, xf * ag.origin]
		var l1 := hg.origin.distance_to(kg.origin)
		var l2 := kg.origin.distance_to(ag.origin)
		var p: Array = _pos[li]
		var q: Array = _prev[li]
		if _fresh:
			for j in 2:
				p[j] = targets[j]
				q[j] = targets[j]
		# Verlet: inertia (damped by the spring's pull), gravity, the spring toward the animated pose
		for j in 2:
			var cur: Vector3 = p[j]
			var vel: Vector3 = (cur - (q[j] as Vector3)) * damp
			var acc: Vector3 = Vector3.DOWN * gravity + ((targets[j] as Vector3) - cur) * k * k
			q[j] = cur
			p[j] = cur + vel + acc * dt * dt
		# the bone lengths, and off the surface
		for it in 3:
			var kn: Vector3 = p[0]
			var an: Vector3 = p[1]
			kn = H + (kn - H).normalized() * l1 if (kn - H).length_squared() > 1e-8 else targets[0]
			an = kn + (an - kn).normalized() * l2 if (an - kn).length_squared() > 1e-8 else targets[1]
			if plane_on:
				var dk := (kn - plane_point).dot(plane_normal)
				if dk < SKIN:
					kn += plane_normal * (SKIN - dk)
				var da := (an - plane_point).dot(plane_normal)
				if da < SKIN:
					an += plane_normal * (SKIN - da)
			p[0] = kn
			p[1] = an
		# the thigh at the simulated knee, the shin at the simulated ankle (skeleton space)
		var kd := inv * (p[0] as Vector3)
		var ad := inv * (p[1] as Vector3)
		var from1 := (kg.origin - hg.origin).normalized()
		var to1 := (kd - hg.origin).normalized()
		var hip := Transform3D(Basis(Quaternion(from1, to1)) * hg.basis, hg.origin)
		sk.set_bone_global_pose(ids[0], hip)
		var kn2 := hip * (hg.affine_inverse() * kg)
		var an2 := kn2 * (kg.affine_inverse() * ag)
		var from2 := (an2.origin - kn2.origin).normalized()
		var to2 := (ad - kn2.origin).normalized()
		sk.set_bone_global_pose(ids[1], Transform3D(Basis(Quaternion(from2, to2)) * kn2.basis, kn2.origin))
	_fresh = false
