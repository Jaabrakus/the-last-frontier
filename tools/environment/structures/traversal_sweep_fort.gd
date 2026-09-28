extends "res://tools/traversal/level_detection_sweep.gd"
## The traversal level sweep (tools/traversal/level_detection_sweep.gd, used as is) run against the
## REAL fort and range colliders: FrontierStructures (colliders only, as headless) instead of the
## sweep's own copy of the old placeholder _fort() / _range(). Everything else is the sweep's code:
## the same terrain, the same vegetation (the structures get their own rng seeded 1776, so the
## sweep's vegetation rng is untouched and the forest matches its usual runs), the same approaches
## and the same table. Each fort body gets a readable review_kind ("Cabin box 7x3x5", "roof prism",
## "ExtraColliders chimney_top", ...).
##
## The sweep always writes res://data/traversal/reports/level_detection.json, which belongs to the
## traversal workflow. Run this ONLY in an APFS clone of the project, never in the project itself:
##
##   cp -cR ~/Downloads/Frontier <scratch>/Frontier_sweep
##   Godot --headless --path <scratch>/Frontier_sweep -s tools/environment/structures/traversal_sweep_fort.gd \
##       -- --no-capture clone=1 [fort=placeholder]
##
## fort=placeholder runs the sweep's own placeholder copy (the same-code "before"). Without clone=1
## it refuses to run. Added 2026-09-25 with the cabin roof collider / no_traverse tag.


func _initialize() -> void:
	if not "clone=1" in OS.get_cmdline_user_args():
		printerr("traversal_sweep_fort.gd: run it in an APFS clone of the project with clone=1 (it writes the traversal report)")
		quit(2)
		return
	await super()


func _fort() -> void:
	if "fort=placeholder" in OS.get_cmdline_user_args():
		print("FORT placeholder copy (the sweep's own)")
		super()
		return
	var srng := RandomNumberGenerator.new()
	srng.seed = 1776
	var s := FrontierStructures.new()
	s.name = "Structures"
	s.visuals = false
	level.add_child(s)
	s.build(WorldSettings.preset("low"), srng)
	var n := 0
	for node in s.find_children("*", "CollisionShape3D", true, false):
		var body := (node as CollisionShape3D).get_parent() as CollisionObject3D
		if body == null or body.has_meta("review_kind"):
			continue
		body.set_meta("review_kind", _label(body, node as CollisionShape3D))
		n += 1
	print("FORT FrontierStructures colliders: %d bodies labelled" % n)


func _range() -> void:
	if "fort=placeholder" in OS.get_cmdline_user_args():
		super()


func _label(body: CollisionObject3D, cs: CollisionShape3D) -> String:
	var dummy: Node = body
	while dummy and not dummy is TargetDummy:
		dummy = dummy.get_parent()
	if dummy:
		return "dummy %s" % String(body.get_meta(&"hit_part", "?"))
	var group := String(body.get_parent().name)
	var bname := String(body.name)
	if bname == "cabin_roof":
		return "Cabin roof prism (no_traverse)"
	if not bname.begins_with("@") and not bname.begins_with("StaticBody"):
		return "%s %s" % [group, bname]
	var size := ""
	if cs.shape is BoxShape3D:
		var v: Vector3 = (cs.shape as BoxShape3D).size
		size = "box %sx%sx%s" % [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
	elif cs.shape is CylinderShape3D:
		size = "cyl r%s h%s" % [snappedf((cs.shape as CylinderShape3D).radius, 0.01), snappedf((cs.shape as CylinderShape3D).height, 0.01)]
	else:
		size = cs.shape.get_class()
	if group == "Walkway" and cs.shape is BoxShape3D and absf(body.rotation.x) > 0.1:
		size = "ramp"
	if cs.has_meta(&"trav") and bool((cs.get_meta(&"trav") as Dictionary).get("no_traverse", false)):
		size += " (no_traverse)"
	if group == "Palisade":
		return "Palisade wall"
	return "%s %s" % [group, size]
