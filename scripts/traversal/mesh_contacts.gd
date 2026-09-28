class_name TravMeshContacts
extends RefCounted
## CPU skinning of the RENDERED hands, feet and knees of the player body (CharacterBodyMesh,
## assets/character/actor_b_body.glb) for the traversal contact checks and the contact-probe
## calibration (tools/traversal/calibrate_contact_probes.gd).
##
##   var mc := TravMeshContacts.build(body)                  # body: CharacterBodyMesh on the rig
##   var g := mc.full_globals(bone_globals)                  # + the driven helper bones (as in game)
##   var pts := mc.skin("l_hand", g)                         # skeleton-space vertex positions
##
## Limb regions (dominant skin bone of each vertex; the same rules as the calibration):
##   l/r_hand  Body mesh, skin material: wrist, palm, metacarpals, fingers and thumb
##   l/r_foot  Clothes mesh, shoe / leggings / brass: heel, ball, ankle, and the shoe upper
##   l/r_knee  Clothes mesh (breeches, leggings, garter) within KNEE_R of the bind knee joint
## Skinning is linear blend skinning with the body's own binds: p = sum w_k G[b_k] inv_bind_k v,
## i.e. exactly what the GPU draws for the globals `g` (use full_globals() so the forearm
## twist helpers are driven the way CharacterBodyMesh drives them in game).

const HAND_BONES := ["wrist", "palm", "thumba", "thumbb", "thumbc", "index_metacarpal", "indexa", "indexb", "indexc",
		"middle_metacarpal", "middlea", "middleb", "middlec", "ring_metacarpal", "ringa", "ringb", "ringc",
		"pinkya", "pinkyb", "pinkyc", "pinkyd"]
const FOOT_BONES := ["heel", "ball", "ankle"]
const FOOT_MATERIALS := ["shoe", "leggings", "brass"]
const KNEE_MATERIALS := ["breeches", "leggings", "garter"]
const KNEE_R := 0.12
const LIMBS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee"]

var body: CharacterBodyMesh
var skeleton: Skeleton3D
## limb -> {bind: PackedVector3Array (skin space), bones: PackedInt32Array (4 / vertex),
##          weights: PackedFloat32Array (4 / vertex), offs: PackedVector3Array (4 / vertex:
##          inv_bind_k * v), mesh: String, helper_w: PackedFloat32Array}
var limbs := {}


static func build(p_body: CharacterBodyMesh) -> TravMeshContacts:
	var mc := TravMeshContacts.new()
	mc.body = p_body
	mc.skeleton = p_body.skeleton
	# Plain Arrays while collecting (a Packed*Array inside a Dictionary is copied on access).
	var acc := {}
	for limb in LIMBS:
		acc[limb] = {"bind": [], "bones": [], "weights": [], "offs": [], "helper_w": [], "dom": []}
	var sk := mc.skeleton
	var knee_bind := {}
	for side in ["l", "r"]:
		var kb := sk.find_bone(side + "_knee")
		knee_bind[side] = p_body._bind[kb].origin if p_body._bind.has(kb) else Vector3.ZERO
	for mi: MeshInstance3D in p_body.meshes:
		var am := mi.mesh as ArrayMesh
		var skin: Skin = mi.skin
		if am == null or skin == null:
			continue
		var mname := str(mi.name)
		if not mname in ["Body", "Clothes"]:
			continue
		for s in am.get_surface_count():
			var mat := am.surface_get_material(s)
			var label := mat.resource_name if mat else ""
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			for i in v.size():
				var best := 0
				for k in nb:
					if w[i * nb + k] > w[i * nb + best]:
						best = k
				var dom_bone := skin.get_bind_bone(bo[i * nb + best])
				var dom := sk.get_bone_name(dom_bone)
				var side := dom.substr(0, 1)
				if not (dom.begins_with("l_") or dom.begins_with("r_")):
					continue
				var part := dom.substr(2)
				var limb := ""
				if mname == "Body" and label == "skin" and part in HAND_BONES:
					limb = side + "_hand"
				elif mname == "Clothes" and label in FOOT_MATERIALS and (part in FOOT_BONES or (label == "shoe" and part == "knee")):
					limb = side + "_foot"
				elif mname == "Clothes" and label in KNEE_MATERIALS and part in ["knee", "upper_leg"] \
						and v[i].distance_to(knee_bind[side]) <= KNEE_R:
					limb = side + "_knee"
				if limb == "":
					continue
				var L: Dictionary = acc[limb]
				var hw := 0.0
				if not L.has("skin"):
					L["skin"] = skin
				var tw := 0.0
				for k in 4:
					if k < nb:
						var wk := w[i * nb + k]
						var bi := skin.get_bind_bone(bo[i * nb + k])
						var bn := sk.get_bone_name(bi)
						tw += wk
						# Forearm twist helpers follow the wrist's roll (the probes substitute the wrist
						# for them); any other helper weight excludes the vertex from the probes.
						if (bn.contains("twist") or bn.contains("helper")) and not bn.contains("forarm_twist"):
							hw += wk
						(L.bones as Array).append(bi)
						(L.weights as Array).append(wk)
						(L.offs as Array).append(skin.get_bind_pose(bo[i * nb + k]) * v[i])
					else:
						(L.bones as Array).append(dom_bone)
						(L.weights as Array).append(0.0)
						(L.offs as Array).append(Vector3.ZERO)
				(L.bind as Array).append(v[i])
				(L.helper_w as Array).append(hw / maxf(tw, 1e-6))
				(L.dom as Array).append(dom)
	for limb in LIMBS:
		var A: Dictionary = acc[limb]
		mc.limbs[limb] = {"skin": A.get("skin"), "bind": PackedVector3Array(A.bind), "bones": PackedInt32Array(A.bones),
				"weights": PackedFloat32Array(A.weights), "offs": PackedVector3Array(A.offs),
				"helper_w": PackedFloat32Array(A.helper_w), "dom": PackedStringArray(A.dom)}
	return mc


## Inverse bind (skin space -> bone space) of skeleton bone `bone` in `skin`.
static func inv_bind(skin: Skin, bone: int) -> Transform3D:
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == bone:
			return skin.get_bind_pose(i)
	return Transform3D.IDENTITY


func count(limb: String) -> int:
	return (limbs[limb].bind as PackedVector3Array).size()


## Bone globals (skeleton space, one Transform3D per bone) with the body's driven helper bones.
func full_globals(g: Array) -> Array:
	var out := g.duplicate()
	var res: Array = body._drive(out, Vector3.DOWN)
	var bones: PackedInt32Array = res[0]
	for i in bones.size():
		out[bones[i]] = res[1][i]
	return out


## Skinned vertex positions of `limb` (skeleton space) for the globals `g` (Array indexed by bone).
func skin(limb: String, g: Array) -> PackedVector3Array:
	var L: Dictionary = limbs[limb]
	var bones: PackedInt32Array = L.bones
	var ws: PackedFloat32Array = L.weights
	var offs: PackedVector3Array = L.offs
	var n := (L.bind as PackedVector3Array).size()
	var out := PackedVector3Array()
	out.resize(n)
	for i in n:
		var acc := Vector3.ZERO
		for k in 4:
			var wk := ws[4 * i + k]
			if wk > 0.0:
				acc += ((g[bones[4 * i + k]] as Transform3D) * offs[4 * i + k]) * wk
		out[i] = acc
	return out


## Body regions other than the hands and feet (fix round 3, 2026-09-25; review: only hands and feet
## were checked, while the shimmy's hat went 15 cm into the wall and the 3 m climb's arms 11-15 cm
## into the face): every skinned mesh of the body (Body, Clothes, Gear, Hat, Hair, Face), each vertex
## by its dominant bone into head (face, hair, hat), gear, l/r_shin, l/r_thigh (the coat's skirt
## rides the thigh bones), l/r_forearm, l/r_uparm or torso (the rest), decimated to one vertex per
## `cell` of the bind pose. regions[name] = {bones, weights, offs (4 per vertex), dom: {bone: radius}
## (the region's dominant bones and the farthest of their vertices, for a cheap proximity test)}.
var regions := {}
const REGION_HAND := ["wrist", "palm", "thumba", "thumbb", "thumbc", "index_metacarpal", "indexa", "indexb", "indexc",
		"middle_metacarpal", "middlea", "middleb", "middlec", "ring_metacarpal", "ringa", "ringb", "ringc",
		"pinkya", "pinkyb", "pinkyc", "pinkyd"]


static func region_of(mesh: String, mat: String, dom: String) -> String:
	if mesh in ["Face", "Hair", "Hat"]:
		return "head"
	if mesh == "Gear":
		return "gear"
	var side := dom.substr(0, 2) if dom.begins_with("l_") or dom.begins_with("r_") else ""
	var part := dom.substr(2) if side != "" else dom
	if side != "":
		var s := side.substr(0, 1)
		if part in REGION_HAND:
			return s + "_hand"
		if part in ["heel", "ball", "ankle"]:
			return s + "_foot"
		if part == "knee" or part.begins_with("knee"):
			return s + "_foot" if mat == "shoe" else s + "_shin"
		if part.begins_with("upper_leg"):
			return s + "_thigh"
		if part == "elbow" or part.begins_with("forarm") or part.begins_with("elbow"):
			return s + "_forearm"
		if part.begins_with("shoulder") or part in ["deltoid", "bicep_helper", "tricep_helper"]:
			return s + "_uparm"
		return "torso"
	if dom in ["headb", "heada", "neck", "wrinklemaps", "throat", "jaw"]:
		return "head"
	return "torso"


func build_regions(cell := 0.03) -> void:
	regions = {}
	var acc := {}
	var sk := skeleton
	for mi: MeshInstance3D in body.meshes:
		var am := mi.mesh as ArrayMesh
		var skin: Skin = mi.skin
		if am == null or skin == null:
			continue
		var mname := str(mi.name)
		for s in am.get_surface_count():
			var mat := am.surface_get_material(s)
			var label := mat.resource_name if mat else ""
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			for i in v.size():
				var best := 0
				for k in nb:
					if w[i * nb + k] > w[i * nb + best]:
						best = k
				var dom_bone := skin.get_bind_bone(bo[i * nb + best])
				var reg := region_of(mname, label, sk.get_bone_name(dom_bone))
				if reg.ends_with("_hand") or reg.ends_with("_foot"):
					continue
				if not acc.has(reg):
					acc[reg] = {"cells": {}, "bones": [], "weights": [], "offs": [], "dom": {}}
				var R: Dictionary = acc[reg]
				var key := Vector3i(floori(v[i].x / cell), floori(v[i].y / cell), floori(v[i].z / cell))
				if (R.cells as Dictionary).has(key):
					continue
				R.cells[key] = true
				for k in 4:
					if k < nb and w[i * nb + k] > 0.0:
						(R.bones as Array).append(skin.get_bind_bone(bo[i * nb + k]))
						(R.weights as Array).append(w[i * nb + k])
						(R.offs as Array).append(skin.get_bind_pose(bo[i * nb + k]) * v[i])
					else:
						(R.bones as Array).append(dom_bone)
						(R.weights as Array).append(0.0)
						(R.offs as Array).append(Vector3.ZERO)
				var bind_o: Vector3 = body._bind[dom_bone].origin if body._bind.has(dom_bone) else v[i]
				R.dom[dom_bone] = maxf(float((R.dom as Dictionary).get(dom_bone, 0.0)), bind_o.distance_to(v[i]))
	for reg: String in acc:
		var A: Dictionary = acc[reg]
		regions[reg] = {"bones": PackedInt32Array(A.bones), "weights": PackedFloat32Array(A.weights), "offs": PackedVector3Array(A.offs),
				"dom": A.dom, "n": (A.cells as Dictionary).size()}


## Skinned vertex positions of a body region (skeleton space) for the globals `g`.
func skin_region(reg: String, g: Array) -> PackedVector3Array:
	var L: Dictionary = regions[reg]
	var bones: PackedInt32Array = L.bones
	var ws: PackedFloat32Array = L.weights
	var offs: PackedVector3Array = L.offs
	var n := int(L.n)
	var out := PackedVector3Array()
	out.resize(n)
	for i in n:
		var acc := Vector3.ZERO
		for k in 4:
			var wk := ws[4 * i + k]
			if wk > 0.0:
				acc += ((g[bones[4 * i + k]] as Transform3D) * offs[4 * i + k]) * wk
		out[i] = acc
	return out


## Globals of the live skeleton (animated pose outside the update; inside a modifier the
## modified pose) as an Array indexed by bone.
static func live_globals(sk: Skeleton3D) -> Array:
	var g := []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		g[b] = sk.get_bone_global_pose(b)
	return g
