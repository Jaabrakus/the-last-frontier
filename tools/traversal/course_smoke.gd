extends SceneTree
## Loads the course headless, prints the bake report and the ledge / lane / beam counts.
func _initialize() -> void:
	change_scene_to_file("res://scenes/traversal_course.tscn")
	for i in 20:
		await physics_frame
	var c := current_scene
	while not c.ready_done:
		await physics_frame
	print("BAKE ", JSON.stringify(c.baker.report))
	for id in c.ledges.ledges:
		var lg: Dictionary = c.ledges.ledges[id]
		print("  ledge %d %s %s len %.2f top %s src %s links %d" % [id, lg.grip, lg.kind, lg.length, lg.top_class, str(lg.source).get_file(), c.ledges.links_from(id).size()])
	for id in c.ledges.lanes:
		print("  lane ", c.ledges.lanes[id].kind, " ", c.ledges.lanes[id].bottom, " -> ", c.ledges.lanes[id].top)
	for id in c.ledges.beams:
		print("  beam ", c.ledges.beams[id].a, " -> ", c.ledges.beams[id].b, " w ", c.ledges.beams[id].width)
	print("COURSE SMOKE OK")
	quit(0)
