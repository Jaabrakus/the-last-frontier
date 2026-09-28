extends SceneTree
## The inventory (Tab) with the torch stack in the pack and its icon (push n01b). Needs a window:
##   Godot --path . --resolution 1280x720 -s tests/torch/tools/inventory_shot.gd -- out=<png> [rightclick=1]
## rightclick=1 right-clicks the torch stack (a torch in hand when the screen closes) and closes the screen.

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var p: FrontierPlayer = current_scene.get_node("Player")
	p.ignore_mouse_capture = true
	for i in 90:
		await physics_frame
	var s := InventoryScreen.open_for(p)
	for i in 60:
		await process_frame
	var torch_cell: Control = null
	for c in s._pack_grid.get_children():
		if String(c.get("kind")) == "torch":
			torch_cell = c
	print("torch stack in the pack: ", torch_cell != null, " count ", s.inv.pack_count("torch"), " icon ",
			torch_cell != null and torch_cell.get("_icon").texture != null)
	if args.get("rightclick", "0") == "1" and torch_cell:
		s.use_item("torch")
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var out: String = args.get("out", "user://inventory_torch.png")
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	if args.get("rightclick", "0") == "1":
		s.close()
		for i in 30:
			await physics_frame
		print("after closing: torch in hand ", p.torch.holding(), " lit ", p.torch.holding() and p.torch.held.lit, " pack ", p.torch.count())
	quit()
