extends "res://tools/character/body_preview.gd"
## Six seconds at normal clip speed: old looping fall beside the sustained runtime fall.
const Rig := preload("res://tests/anim/lib/rig_fixture.gd")
var rigs: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	out = "res://artifacts/fluidity"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await _studio()
	for i in 2:
		var lk := {"sex": 0.0, "melanin": 0.38, "outfit": PlayerAppearance.arena_outfit("air", 0.0)}
		var c := _character(Vector3(-0.85 if i == 0 else 0.85, 0, 0), -25.0, lk)
		(c[3] as CharacterBodyMesh).remove_part("body")
		PlayerAppearance.dress(c[3], lk)
		var rig := Rig.new()
		rig.root = c[0]
		rig.sk = c[1]
		rig.ap = c[2]
		rig.lib_name = "actor_b"
		var builder := TreeBuilder.new()
		builder.data = AnimGraphData.load_files()
		builder.ap = rig.ap
		builder.sk = rig.sk
		builder.idx = TreeIndex.new()
		builder.opts = {"carry": "none"}
		for lib: String in builder.data.override_libraries():
			if not rig.ap.has_animation_library(lib):
				rig.ap.add_animation_library(lib, load(builder.data.override_libraries()[lib]))
		var bt := AnimationNodeBlendTree.new()
		var rec := {"node": "fall", "layers": []}
		builder._build_single(bt, {"clip": "actor_b-p-fall", "loop": true, "layers": {}}, rec)
		if i == 0:
			(bt.get_node("clip") as AnimationNodeAnimation).loop_mode = Animation.LOOP_LINEAR
		var clip := rig.ap.get_animation(builder.data.godot_anim("actor_b-p-fall"))
		rig.play(bt, {"ts/scale": 1.0 / clip.length})
		rigs.append(rig)
	var label := Label.new()
	label.text = "BEFORE: REPEATING FALL                          AFTER: SUSTAINED FALL"
	label.position = Vector2(200, 65)
	label.add_theme_font_size_override("font_size", 22)
	root.add_child(label)
	_look_at(Vector3(0, 1.0, 0), Vector3(0, 0.15, 6.2), 34.0)
	for frame in 360:
		for rig in rigs:
			rig.advance(1.0 / 60.0)
		await process_frame
		if frame in [112, 124, 240]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("fall_%03d.png" % frame))
	print("FALL PREVIEW DONE")
	quit()
