extends SceneTree
## Review round 1 probe (read-only): does repeated spawn / stop / kill of every imported effect settle (pool bounded, no
## node / resource / orphan growth)? Checkpoints every 200 spawns after everything is killed and the frame loop settled.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_soak.gd

func _initialize() -> void:
	_run.call_deferred()


func _mon() -> String:
	return "nodes %d, resources %d, objects %d, orphans %d" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))]


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	var player := SpellFx.of(root)
	var ids := Array(SpellFx.effect_ids())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var holders: Array[Node3D] = []
	print("REVIEW soak, %d effects. start: %s" % [ids.size(), _mon()])
	var handles: Array = []
	for n in 1201:
		var id: String = ids[rng.randi() % ids.size()]
		var at := Vector3(rng.randf_range(-6, 6), 1.0, rng.randf_range(-6, 0))
		var mode := n % 4
		var h: SpellFx.Handle
		if mode == 0:
			var holder := Node3D.new()
			root.add_child(holder)
			holder.global_position = at
			holders.append(holder)
			h = SpellFx.spawn(id, holder, {"follow": true})
		else:
			h = SpellFx.spawn(id, at, {"scale": rng.randf_range(0.5, 2.0)})
		if h != null:
			handles.append(h)
		await process_frame
		# end some at once, stop others, free a holder under a follower
		if n % 3 == 0 and not handles.is_empty():
			(handles[rng.randi() % handles.size()] as SpellFx.Handle).kill()
		if n % 5 == 0 and not handles.is_empty():
			(handles[rng.randi() % handles.size()] as SpellFx.Handle).stop()
		if n % 7 == 0 and not holders.is_empty():
			var hd: Node3D = holders.pop_back()
			hd.queue_free()
		handles = handles.filter(func(x: SpellFx.Handle) -> bool: return x.is_playing())
		if n % 300 == 0 and n > 0:
			player.kill_all()
			for hd in holders:
				if is_instance_valid(hd):
					hd.free()
			holders.clear()
			handles.clear()
			for f in 4:
				await process_frame
			print("  after %4d spawns: %s | playing %d, idle pooled %d, SpellFx children %d" % [n, _mon(), player.playing_count(), player.idle_count(), player.get_child_count()])
	quit(0)
