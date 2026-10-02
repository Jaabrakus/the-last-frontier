extends SceneTree
## The sprint vault's free arm toned down (user 2026-10-01: "for low vault we need to tone down the right arm"): the vault's
## four chained clips (own-sprint-vault-1 .. -4, Frontier_Traversal.res, tools/anim_author/blender/install_traversal.gd)
## taken as one motion, the right arm's turns (RIGHT_ARM) brought to KEEP of their swing about the eased line from the
## vault's first pose to its last (so the chain still joins, and the vault begins and ends where it did); written beside
## them as "<clip>-calm" and wired in data/anim_author/traversal_clips.json in their place. The mirrored vault (the right
## hand planting, TravMoveMirror) is made from the same clips: its free arm, the left, is the one toned there.
##   Godot --headless --path . -s tools/anim_author/calm_vault_arm.gd [-- keep=0.5]
## (install_traversal.gd rewrites the table: run this after it.)

const LIB := "res://animations_extra/Frontier_Traversal.res"
const TABLE := "res://data/anim_author/traversal_clips.json"
const CLIPS := ["own-sprint-vault-1", "own-sprint-vault-2", "own-sprint-vault-3", "own-sprint-vault-4"]
const RIGHT_ARM := ["r_chest", "r_clavicle", "r_scapula", "r_trap", "r_shoulder", "r_deltoid", "r_elbow", "r_wrist"]
const KEEP := 0.5
const FPS := 30.0


func _initialize() -> void:
	var keep := KEEP
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("keep="):
			keep = float(a.get_slice("=", 1))
	var lib := load(LIB) as AnimationLibrary
	var src: Array[Animation] = []
	for c in CLIPS:
		src.append(lib.get_animation(c))
	var out: Array[Animation] = []
	for a in src:
		out.append(a.duplicate(true) as Animation)
	var total := 0.0
	for a in src:
		total += a.length
	for b: String in RIGHT_ARM:
		# the bone's turn over the whole vault, frame by frame across the clips (one hemisphere)
		var frames: Array = []                 # [clip index, t in clip, t in vault, q]
		var t0 := 0.0
		for ci in src.size():
			var a := src[ci]
			var ti := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
			if ti < 0:
				frames = []
				break
			var n := int(round(a.length * FPS))
			for f in n + 1:
				var t := minf(f / FPS, a.length)
				var q := a.rotation_track_interpolate(ti, t).normalized()
				if not frames.is_empty() and (frames[frames.size() - 1][3] as Quaternion).dot(q) < 0.0:
					q = -q
				frames.append([ci, t, t0 + t, q])
			t0 += a.length
		if frames.is_empty():
			continue
		var q0: Quaternion = frames[0][3]
		var q1: Quaternion = frames[frames.size() - 1][3]
		for ci in out.size():
			var ti := out[ci].find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
			while out[ci].track_get_key_count(ti) > 0:
				out[ci].track_remove_key(ti, 0)
		for fr: Array in frames:
			var u := float(fr[2]) / total
			var line := q0.slerp(q1, u * u * (3.0 - 2.0 * u))
			var ti := out[int(fr[0])].find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
			out[int(fr[0])].rotation_track_insert_key(ti, float(fr[1]), line.slerp(fr[3] as Quaternion, keep).normalized())
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	for ci in CLIPS.size():
		var nm := StringName(CLIPS[ci] + "-calm")
		out[ci].set_meta(&"authored", "Frontier: own-sprint-vault with the free arm toned down (tools/anim_author/calm_vault_arm.gd, keep %.2f)" % keep)
		if lib.has_animation(nm):
			lib.remove_animation(nm)
		lib.add_animation(nm, out[ci])
		for g: String in table.clips:
			if String(table.clips[g]) == "frontier_traversal/" + CLIPS[ci]:
				table.clips[g] = "frontier_traversal/" + String(nm)
				print("wired %s -> %s" % [g, nm])
	print(ResourceSaver.save(lib, LIB, ResourceSaver.FLAG_COMPRESS))
	var f := FileAccess.open(TABLE, FileAccess.WRITE)
	f.store_string(JSON.stringify(table))
	f.close()
	quit()
