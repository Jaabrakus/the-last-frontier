extends SceneTree
## Bake a backward recoil for the kneeling tandem partner from the imported kneel loop: the answer to the
## crawling lead's backward flinch. The knees, shins and feet stay at the reference pose; the upper body rocks back
## toward the back of the actor, quickly, and settles again.
## Run: Godot --headless --path . --script res://features/tandem/tools/author_kneel_backward.gd

const LENGTH := 0.8
const DISTANCE := 0.09
const WEIGHTS := {
	"pelvis": 0.2, "spinea": 0.35, "spineb": 0.6, "spinec": 0.85, "spined": 1.0,
	"neck": 1.05, "heada": 1.1, "headb": 1.1,
	"l_upper_leg": 0.0, "r_upper_leg": 0.0,
	"l_knee": 0.0, "r_knee": 0.0,
	"l_shoulder": 1.0, "r_shoulder": 1.0,
	"l_elbow": 0.5, "r_elbow": 0.5,
	"l_wrist": 0.0, "r_wrist": 0.0,
}

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var actor := load("res://features/tandem/actor_b_kneel.glb").instantiate() as Node3D
	root.add_child(actor)
	var skeleton := actor.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	player.play("actor_b-kneel-stick")
	player.seek(0.0, true)
	player.pause()
	var reference: Array[Transform3D] = []
	var weights: Array[float] = []
	var count := skeleton.get_bone_count()
	for bone in count:
		reference.append(skeleton.get_bone_global_pose(bone))
		weights.append(weight_for(skeleton, bone))
	var animation := Animation.new()
	animation.resource_name = "Kneel backward recoil"
	animation.length = LENGTH
	var skeleton_path := player.get_node(player.root_node).get_path_to(skeleton)
	for bone in count:
		var path := NodePath(String(skeleton_path) + ":" + skeleton.get_bone_name(bone))
		var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, path)
		var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_track, path)
	for frame in 49:
		var time := LENGTH * frame / 48.0
		# Quick recoil, then a longer eased recovery.
		var phase := time / 0.16 if time < 0.16 else (LENGTH - time) / (LENGTH - 0.16)
		var strength := smoothstep(0.0, 1.0, clampf(phase, 0.0, 1.0))
		var poses: Array[Transform3D] = reference.duplicate()
		for bone in count:
			poses[bone].origin.z -= DISTANCE * weights[bone] * strength
		for bone in count:
			var children := skeleton.get_bone_children(bone)
			if not children.is_empty():
				var child := children[0]
				var before := reference[child].origin - reference[bone].origin
				var after := poses[child].origin - poses[bone].origin
				if before.length_squared() > 0.000001 and after.length_squared() > 0.000001:
					poses[bone].basis = Basis(Quaternion(before.normalized(), after.normalized())) * reference[bone].basis
		for bone in count:
			var parent := skeleton.get_bone_parent(bone)
			var local := poses[bone] if parent < 0 else poses[parent].affine_inverse() * poses[bone]
			animation.position_track_insert_key(bone * 2, time, local.origin)
			animation.rotation_track_insert_key(bone * 2 + 1, time, local.basis.get_rotation_quaternion())
	var result := ResourceSaver.save(animation, "res://features/tandem/kneel_backward_flinch.tres")
	print("Backward kneel clip saved: ", result)
	quit(result)

func weight_for(skeleton: Skeleton3D, bone: int) -> float:
	var current := bone
	while current >= 0:
		var name := skeleton.get_bone_name(current)
		if WEIGHTS.has(name):
			return float(WEIGHTS[name])
		current = skeleton.get_bone_parent(current)
	return 0.0
