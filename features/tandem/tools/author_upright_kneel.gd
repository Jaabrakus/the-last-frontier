extends SceneTree
## Preserve the original kneel's breathing/reactions, correcting the idle torso to vertical.
const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
func _initialize() -> void: call_deferred("bake")
func bake() -> void:
	var actor: Node3D = load("res://features/tandem/actor_b_kneel.glb").instantiate()
	root.add_child(actor)
	var sk: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("actor_b-kneel-stick")
	ap.seek(0.0, true)
	ap.pause()
	var spine := sk.find_bone("spinea")
	var parent := sk.get_bone_parent(spine)
	var up := sk.get_bone_global_pose(sk.find_bone("neck")).origin - sk.get_bone_global_pose(spine).origin
	var correction := Quaternion(up.normalized(), Vector3.UP)
	print("UPRIGHT_KNEEL correction degrees=", rad_to_deg(up.angle_to(Vector3.UP)))
	var back := AnimationLibrary.new()
	back.add_animation("backward", CLIPS.retarget(load("res://features/tandem/kneel_backward_flinch.tres"), ap, sk))
	ap.add_animation_library("source_reaction", back)
	for spec: Array in [["idle", "actor_b-kneel-stick"], ["flinch", "actor_b-kneel-stick-flinch"], ["backward", "source_reaction/backward"]]:
		var clip := ap.get_animation(spec[1]).duplicate(true) as Animation
		var path := NodePath(String(ap.get_node(ap.root_node).get_path_to(sk)) + ":spinea")
		for i in range(clip.get_track_count() - 1, -1, -1):
			if clip.track_get_type(i) == Animation.TYPE_ROTATION_3D and clip.track_get_path(i).get_subname(0) == &"spinea":
				clip.remove_track(i)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		var frames := int(ceil(clip.length * 30.0))
		for frame in frames + 1:
			var time := clip.length * frame / frames
			ap.play(spec[1])
			ap.seek(time, true)
			ap.pause()
			var parent_q := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
			var local := parent_q.inverse() * correction * parent_q * sk.get_bone_pose_rotation(spine)
			clip.rotation_track_insert_key(track, time, local.normalized())
		clip.loop_mode = Animation.LOOP_LINEAR if spec[0] == "idle" else Animation.LOOP_NONE
		assert(ResourceSaver.save(clip, "res://features/tandem/kneel_upright_" + spec[0] + ".tres") == OK)
		print("UPRIGHT_KNEEL_BAKED ", spec[0], " original channels preserved except spine rotation")
	quit()
