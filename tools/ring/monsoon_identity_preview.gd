extends "res://tools/character/body_preview.gd"
## Render the actual dressed bodies and release geometry from front and three-quarter views.

func _initialize() -> void:
	out = "res://artifacts/monsoon_identity"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await _studio()
	current_scene = world
	for sex: float in [0.0, 1.0]:
		for i in 4:
			var el: String = ["earth", "water", "fire", "air"][i]
			var lk := {"sex": sex, "melanin": 0.38,
					"outfit": PlayerAppearance.arena_outfit(el, sex)}
			var c := _character(Vector3((i - 1.5) * 1.35, 0.0, 0.0), 0.0, lk)
			var b := c[3] as CharacterBodyMesh
			b.remove_part("body")
			PlayerAppearance.dress(b, lk)
			var glyph := MeshInstance3D.new()
			glyph.mesh = MonsoonIdentity.mesh(el)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = MonsoonIdentity.accent(el)
			glyph.material_override = mat
			world.add_child(glyph)
			glyph.position = Vector3((i - 1.5) * 1.35, 2.15, 0.0)
			glyph.rotation.x = PI * 0.5
			glyph.scale = Vector3.ONE * 0.4
			chars.append([glyph])
		await _frames(12)
		for v in ["front", "turn"]:
			_look_at(Vector3(0.0, 1.1, 0.0), Vector3(0.0 if v == "front" else 3.0, 0.4, 10.0), 34.0)
			await _shot("identity_%s_%s" % ["f" if sex < 0.5 else "m", v])
		await _clear()
	# Render the real pooled shader at early, middle and late moments.
	_look_at(Vector3.ZERO, Vector3(0.0, 5.0, 0.5), 45.0)
	var pool := ToonFxPool.of(world)
	pool.set_process(false)
	for t: float in [0.05, 0.45, 0.85]:
		for child: Node in pool.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
		for i in 4:
			var el: String = ["earth", "water", "fire", "air"][i]
			var mi := pool.play("monsoon_seal", Transform3D(Basis.IDENTITY, Vector3((i - 1.5) * 1.5, 0, 0)),
					0.32, 0.75, 1.0, MonsoonIdentity.accent(el), Color.WHITE, MonsoonIdentity.mesh(el))
			mi.set_instance_shader_parameter(&"t", t)
		await _shot("release_%02d" % int(t * 100))
	print("MONSOON IDENTITY PREVIEW DONE")
	quit()
