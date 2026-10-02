extends SceneTree
## Where the saber's grip is against the right fist (user 2026-10-01: "the handle point is not in the hand"): the saber drawn on the
## axe's clips (GatherModels._saber), the distance from the grip's middle to the fist's hole (PoseSolver.fist_rel) printed through
## the draw, the carry and a side and a chop swing; the same for the felling axe at its carry grip.
##   Godot --headless --path . -s tools/perf/saber_grip_probe.gd
const Solver := preload("res://tools/anim_author/pose_solver.gd")
var player: FrontierPlayer
var hole: Transform3D


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 150:
		await physics_frame
	player = current_scene.get_node_or_null("Player")
	# the fist's hole in the wrist's frame, on a spare skeleton at rest
	var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	await process_frame
	var sk2 := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	hole = Solver.new(sk2).fist_rel("r")
	actor.queue_free()
	for bn in ["r_wrist", "r_palm", "r_hand_prop_attachment"]:
		var ba := BoneAttachment3D.new()
		ba.name = "probe_" + bn
		ba.bone_name = bn
		player.skeleton.add_child(ba)
	for kind in ["felling_axe", "saber"]:
		var inv := InventoryState.from_player(player)
		inv.add("saber", 1)
		player.inventory_pack = inv.pack.duplicate(true)
		var gt: GatherTools = player.gather
		gt.take_out(kind)
		for i in 400:
			await physics_frame
			if gt.phase == GatherTools.Phase.READY:
				break
		await _frames(30)
		_report(kind, "carry")
		for sw in ["side", "chop"]:
			gt.target = {"type": "pose", "i": -1, "src": "", "pos": player.global_position - player.global_basis.z * 1.3, "radius": 0.3, "dist": 1.0}
			gt.call(&"_start_swing", sw)
			var s: Dictionary = gt.get("_swing")
			for f: float in [0.3, 0.7, 1.0]:
				for i in 300:
					await physics_frame
					if float(s.get("u", 0.0)) >= f * float(s.impact):
						break
				_report(kind, "%s %.0f%%" % [sw, f * 100.0])
			gt.target = {}
			for i in 400:
				await physics_frame
				if gt.phase == GatherTools.Phase.READY:
					break
		gt.put_away()
		for i in 400:
			await physics_frame
			if gt.phase == GatherTools.Phase.IDLE:
				break
	quit()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _report(kind: String, what: String) -> void:
	var gt: GatherTools = player.gather
	var m: Node3D = gt.get("_model_hand")
	var sk := player.skeleton
	var fist := (sk.get_node("probe_r_wrist") as Node3D).global_transform * hole
	if m == null:
		print("PROBE %s %s: no model" % [kind, what])
		return
	# the right hand (its prop bone, and the fist's hole) in the model's own frame: how far up the haft from the knob, how far off its line
	var inv := m.global_transform.affine_inverse()
	var prop := inv * (sk.get_node("probe_r_hand_prop_attachment") as Node3D).global_position
	var palm := inv * (sk.get_node("probe_r_palm") as Node3D).global_position
	var fh := inv * fist.origin
	var saber_grip := -1.0
	var sn := m.get_child(0) as Node3D if m.get_child_count() > 0 else null
	if kind == "saber" and sn:
		saber_grip = (m.global_transform.affine_inverse() * sn.global_position - fh).length()
	if saber_grip >= 0.0:
		print("PROBE saber grip middle %.3f m from the fist's hole" % saber_grip)
	print("PROBE %-11s %-10s prop up %.2f off %.2f | palm up %.2f off %.2f | fist up %.2f off %.2f  (pipe %.2f)" % [kind, what, prop.y, Vector2(prop.x, prop.z).length(),
			palm.y, Vector2(palm.x, palm.z).length(), fh.y, Vector2(fh.x, fh.z).length(), float(gt.get("_pipe_w"))])
