class_name BagModels
extends RefCounted
## Procedural models of the bags (PlayerBags; the owner 2026-10-03, "WoW-style bags"), for the inventory icons
## (ItemIcons: the camera looks at a model's side from +X, up +Y, so a bag's face is at +X and its width along Z): the
## haversack, the linen satchel, the knapsack, the blanket roll, the portmanteau, the hunting pouch, the game bag and the
## simples bag. 1750s things in linen, canvas, wool and leather, drawn our own way (no assets); the leather and brass of
## the classic HUD (ClassicSkin) in the buckles.

const KINDS := ["haversack", "linen_satchel", "knapsack", "blanket_roll", "portmanteau", "hunting_pouch", "game_bag", "simples_bag"]


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	var leather := GearModels._mat("bag_leather", Color(0.36, 0.22, 0.12), 0.7, 0.0)
	var brass := GearModels._mat("bag_brass", Color(0.78, 0.6, 0.3), 0.35, 0.8)
	match kind:
		"haversack":
			# a wide haversack of unbleached linen gone brown with use: the bag, a deep flap with a brass button, the long strap
			var linen := GearModels._mat("linen_haversack", Color(0.62, 0.55, 0.4), 0.95, 0.0)
			var seam := GearModels._mat("linen_seam", Color(0.42, 0.36, 0.26), 0.95, 0.0)
			GearModels._box(root, Vector3(0.05, 0.24, 0.32), Vector3.ZERO, linen)
			GearModels._sphere(root, Vector3(0.028, 0.04, 0.16), Vector3(0, -0.12, 0), linen)
			var flap := GearModels._box(root, Vector3(0.012, 0.15, 0.326), Vector3(0.03, 0.05, 0), linen)
			flap.rotation.z = -0.06
			GearModels._box(root, Vector3(0.013, 0.006, 0.326), Vector3(0.033, -0.022, 0), seam)
			GearModels._sphere(root, Vector3(0.008, 0.014, 0.014), Vector3(0.04, -0.012, 0), brass)
			_strap(root, Vector3(0.0, 0.12, -0.15), Vector3(0.0, 0.12, 0.15), Vector3(0, 0.2, 0), 0.014, seam)
		"linen_satchel":
			# a narrow satchel of bleached linen, taller than wide, its short flap tied shut with a cord, a blue check band
			var linen := GearModels._mat("linen_satchel", Color(0.9, 0.87, 0.78), 0.95, 0.0)
			var check := GearModels._mat("linen_check", Color(0.3, 0.38, 0.55), 0.95, 0.0)
			var cord := GearModels._mat("satchel_cord", Color(0.55, 0.45, 0.3), 0.9, 0.0)
			GearModels._box(root, Vector3(0.04, 0.26, 0.17), Vector3.ZERO, linen)
			GearModels._sphere(root, Vector3(0.022, 0.03, 0.085), Vector3(0, -0.13, 0), linen)
			var flap := GearModels._box(root, Vector3(0.01, 0.08, 0.174), Vector3(0.025, 0.09, 0), linen)
			flap.rotation.z = -0.05
			GearModels._box(root, Vector3(0.012, 0.025, 0.172), Vector3(0.024, -0.06, 0), check)
			GearModels._limb(root, Vector3(0.032, 0.05, 0.0), Vector3(0.032, 0.0, 0.0), 0.003, cord)
			GearModels._limb(root, Vector3(0.032, 0.0, 0.0), Vector3(0.034, -0.03, 0.025), 0.0025, cord)
			GearModels._limb(root, Vector3(0.032, 0.0, 0.0), Vector3(0.034, -0.028, -0.02), 0.0025, cord)
			_strap(root, Vector3(0.0, 0.13, -0.08), Vector3(0.0, 0.13, 0.08), Vector3(0, 0.24, 0), 0.008, linen)
		"knapsack":
			# a painted canvas knapsack: the body, a deep flap with a painted roundel, two shoulder straps, a rolled top
			var canvas := GearModels._mat("knap_canvas", Color(0.62, 0.22, 0.14), 0.85, 0.0)
			var paint := GearModels._mat("knap_paint", Color(0.85, 0.74, 0.46), 0.8, 0.0)
			var flap_c := GearModels._mat("knap_flap", Color(0.54, 0.18, 0.11), 0.85, 0.0)
			GearModels._box(root, Vector3(0.12, 0.32, 0.28), Vector3.ZERO, canvas)
			var flap := GearModels._box(root, Vector3(0.014, 0.2, 0.29), Vector3(0.066, 0.07, 0), flap_c)
			flap.rotation.z = -0.05
			var ring := GearModels._cyl(0.06, 0.06, 0.006, Vector3(0.075, 0.07, 0), paint)
			ring.rotation.z = PI * 0.5
			root.add_child(ring)
			var dot := GearModels._cyl(0.03, 0.03, 0.007, Vector3(0.077, 0.07, 0), canvas)
			dot.rotation.z = PI * 0.5
			root.add_child(dot)
			for sd: float in [-1.0, 1.0]:
				_strap(root, Vector3(-0.06, 0.15, 0.08 * sd), Vector3(-0.06, -0.14, 0.09 * sd), Vector3(-0.08, 0, 0), 0.016, leather)
				GearModels._box(root, Vector3(0.01, 0.018, 0.024), Vector3(-0.065, -0.12, 0.09 * sd), brass)
			var roll := GearModels._cyl(0.035, 0.035, 0.3, Vector3(0, 0.18, 0), GearModels._mat("knap_roll", Color(0.4, 0.36, 0.3), 0.9, 0.0))
			roll.rotation.x = PI * 0.5
			root.add_child(roll)
		"blanket_roll":
			# a red wool blanket rolled tight, two ties, the sling over it, the blanket's stripe at each end
			var wool := GearModels._mat("roll_wool", Color(0.55, 0.14, 0.1), 0.95, 0.0)
			var stripe := GearModels._mat("roll_stripe", Color(0.12, 0.1, 0.1), 0.95, 0.0)
			var cord := GearModels._mat("roll_cord", Color(0.72, 0.62, 0.45), 0.9, 0.0)
			var body := GearModels._cyl(0.07, 0.07, 0.46, Vector3.ZERO, wool)
			body.rotation.x = PI * 0.5
			root.add_child(body)
			for z: float in [-0.2, 0.2]:
				var st := GearModels._cyl(0.0705, 0.0705, 0.02, Vector3(0, 0, z), stripe)
				st.rotation.x = PI * 0.5
				root.add_child(st)
			for z: float in [-0.12, 0.12]:
				var tie := GearModels._cyl(0.073, 0.073, 0.012, Vector3(0, 0, z), cord)
				tie.rotation.x = PI * 0.5
				root.add_child(tie)
			_strap(root, Vector3(0, 0.06, -0.12), Vector3(0, 0.06, 0.12), Vector3(0, 0.16, 0), 0.006, cord)
		"portmanteau":
			# a leather valise lying long: the round body, end caps, two straps with brass buckles, the handle
			var dark := GearModels._mat("port_leather", Color(0.24, 0.14, 0.08), 0.6, 0.0)
			var body := GearModels._cyl(0.09, 0.09, 0.42, Vector3.ZERO, dark)
			body.rotation.x = PI * 0.5
			root.add_child(body)
			for z: float in [-0.215, 0.215]:
				var cap := GearModels._cyl(0.094, 0.094, 0.014, Vector3(0, 0, z), leather)
				cap.rotation.x = PI * 0.5
				root.add_child(cap)
			for z: float in [-0.11, 0.11]:
				var band := GearModels._cyl(0.093, 0.093, 0.026, Vector3(0, 0, z), leather)
				band.rotation.x = PI * 0.5
				root.add_child(band)
				GearModels._box(root, Vector3(0.012, 0.03, 0.034), Vector3(0.093, 0.0, z), brass)
			_strap(root, Vector3(0, 0.09, -0.05), Vector3(0, 0.09, 0.05), Vector3(0, 0.045, 0), 0.008, leather)
		"hunting_pouch":
			# a small leather shot pouch: a rounded flap, a brass button, a strap, an antler powder measure on a thong
			var tan := GearModels._mat("pouch_leather", Color(0.46, 0.3, 0.16), 0.75, 0.0)
			GearModels._box(root, Vector3(0.035, 0.15, 0.16), Vector3.ZERO, tan)
			GearModels._sphere(root, Vector3(0.02, 0.03, 0.08), Vector3(0, -0.075, 0), tan)
			var flap := GearModels._sphere(root, Vector3(0.008, 0.07, 0.082), Vector3(0.02, 0.025, 0), leather)
			flap.rotation.z = -0.05
			GearModels._sphere(root, Vector3(0.008, 0.01, 0.01), Vector3(0.03, -0.035, 0), brass)
			_strap(root, Vector3(0, 0.075, -0.075), Vector3(0, 0.075, 0.075), Vector3(0, 0.22, 0), 0.008, leather)
			var bone := GearModels._mat("pouch_antler", Color(0.82, 0.76, 0.62), 0.7, 0.0)
			GearModels._limb(root, Vector3(0.025, 0.04, 0.09), Vector3(0.03, -0.06, 0.12), 0.0015, tan)
			GearModels._limb(root, Vector3(0.03, -0.06, 0.12), Vector3(0.03, -0.1, 0.125), 0.012, bone)
		"game_bag":
			# a netted bag hanging from a rawhide band: the band, a grid of cords swelling to the bottom, a fringe
			var hide := GearModels._mat("game_band", Color(0.66, 0.56, 0.4), 0.8, 0.0)
			var net := GearModels._mat("game_net", Color(0.74, 0.66, 0.5), 0.9, 0.0)
			GearModels._box(root, Vector3(0.03, 0.05, 0.3), Vector3(0, 0.12, 0), hide)
			var rows := 5
			var cols := 7
			var pts := []
			for r in rows + 1:
				var t := float(r) / rows
				var y := 0.095 - t * 0.27
				var half := 0.15 + 0.03 * sin(t * PI)
				var bulge := 0.02 + 0.05 * sin(t * PI * 0.9)
				var row := []
				for c in cols:
					var u := float(c) / (cols - 1)
					row.append(Vector3(bulge, y, -half + u * half * 2.0))
				pts.append(row)
			for r in rows:
				for c in cols:
					if c + 1 < cols:
						GearModels._limb(root, pts[r][c], pts[r + 1][c + 1], 0.0022, net)
					if c - 1 >= 0:
						GearModels._limb(root, pts[r][c], pts[r + 1][c - 1], 0.0022, net)
			for c in range(0, cols, 2):
				var a: Vector3 = pts[rows][c]
				GearModels._limb(root, a, a + Vector3(0.0, -0.06, 0.0), 0.003, hide)
			_strap(root, Vector3(0, 0.145, -0.14), Vector3(0, 0.145, 0.14), Vector3(0, 0.18, 0), 0.009, hide)
		"simples_bag":
			# a buckskin herb pouch, its mouth gathered by a drawstring, the cord's ends hanging; sprigs of dried herbs out of
			# the mouth to one side, a red wool binding round the middle
			var buck := GearModels._mat("simples_buck", Color(0.7, 0.55, 0.36), 0.85, 0.0)
			var cord := GearModels._mat("simples_cord", Color(0.4, 0.26, 0.14), 0.85, 0.0)
			var stem := GearModels._mat("simples_stem", Color(0.42, 0.36, 0.2), 0.85, 0.0)
			var leaf := GearModels._mat("simples_leaf", Color(0.36, 0.44, 0.24), 0.85, 0.0)
			var binding := GearModels._mat("simples_binding", Color(0.66, 0.2, 0.14), 0.7, 0.0)
			GearModels._sphere(root, Vector3(0.06, 0.07, 0.1), Vector3(0, -0.03, 0), buck)
			root.add_child(GearModels._cyl(0.03, 0.06, 0.06, Vector3(0, 0.05, 0), buck))
			root.add_child(GearModels._cyl(0.034, 0.034, 0.012, Vector3(0, 0.07, 0), cord))
			var band := GearModels._cyl(0.0605, 0.0605, 0.012, Vector3(0, -0.04, 0), binding)
			band.scale = Vector3(1.0, 1.0, 1.65)
			root.add_child(band)
			GearModels._limb(root, Vector3(0.03, 0.07, 0.02), Vector3(0.045, -0.02, 0.055), 0.0025, cord)
			GearModels._limb(root, Vector3(0.03, 0.07, 0.025), Vector3(0.05, 0.0, 0.07), 0.0025, cord)
			for i in 3:
				var tip := Vector3(0.0, 0.16 + 0.015 * i, -0.03 - 0.035 * i)
				GearModels._limb(root, Vector3(0.0, 0.07, -0.01 * i), tip, 0.002, stem)
				for j in 3:
					var at := Vector3(0.0, 0.07, -0.01 * i).lerp(tip, 0.55 + 0.2 * j)
					var l := GearModels._sphere(root, Vector3(0.004, 0.006, 0.012), at + Vector3(0, 0, 0.006 * (1 - 2 * (j % 2))), leaf)
					l.rotation.x = 0.6 * (1 - 2 * (j % 2))
	return root


## A strap from `a` to `b` bowed out by `bow` at its middle (up over the bag; back, for a knapsack's shoulder straps), in
## a few round pieces.
static func _strap(root: Node3D, a: Vector3, b: Vector3, bow: Vector3, r: float, mat: Material) -> void:
	var n := 8
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + bow * sin(t * PI)
		GearModels._limb(root, prev, p, r, mat)
		prev = p
