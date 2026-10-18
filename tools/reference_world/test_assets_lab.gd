extends SceneTree
## Exercises the isolated lab through its native movement, equipment and caster.
## Godot --headless --path . -s tools/reference_world/test_assets_lab.gd -- --no-capture
## Add render=1 without --headless to save actual lab views (1280 x 720).
## Results stay under ignored artifacts; no appearance, gameplay save or source is written.

const LAB_SCENE := "res://scenes/labs/extracted_assets_lab.tscn"
const OUT := "res://artifacts/world_reference/character_fit/lab_preview"
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var lab: Node3D
var player: FrontierPlayer
var caster: SwayCaster
var checks := 0
var failures: Array[String] = []
var notes: Dictionary = {}
var released: Array[String] = []
var air_released: Array[String] = []
var observed_air_released: Array[String] = []
var view: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var error := change_scene_to_file(LAB_SCENE)
	_expect(error == OK, "lab scene loads")
	if error != OK:
		_finish()
		return
	await scene_changed
	lab = current_scene as Node3D
	player = lab.get("player") as FrontierPlayer
	caster = lab.get("caster") as SwayCaster
	_expect(player != null and caster != null, "native player and caster built")
	if player == null or caster == null:
		_finish()
		return
	# Drive the same controls interface used by the game/network, without OS focus.
	player.controls.from_input = false
	player.controls.release_all()
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	caster.cast_released.connect(func(id: String, _mode: String) -> void:
		released.append(id)
		if not player.is_on_floor():
			observed_air_released.append(id))
	caster.air_cast.connect(func(id: String, _mode: String) -> void: air_released.append(id))
	notes["physics_hz"] = Engine.physics_ticks_per_second
	await _frames(60)
	_expect(player.skeleton.get_bone_count() == 291, "canonical 291-bone player rig")
	_expect(player.anim != null and player.anim.active, "native animation graph active")
	_expect(player.appearance == null, "lab does not install persistent appearance/customizer")
	notes["initial_world"] = lab.get("reports").get("world", {})
	_test_world_textures()
	if _arg("capture_only") == "1":
		await _render_views()
		_finish()
		return
	if _arg("focus") == "contact":
		await _test_spell_target()
		_finish()
		return
	if _arg("focus") == "selected":
		await _test_selected_spell()
		_finish()
		return
	await _test_models()
	await _test_areas_and_movement()
	await _test_weapons()
	await _test_keyboard()
	await _test_casts()
	await _test_selected_spell()
	await _test_air_casts()
	await _test_spell_target()
	if _arg("render") == "1" and DisplayServer.get_name() != "headless":
		await _render_views()
	_finish()


func _test_models() -> void:
	var baseline: Mesh
	for model in [0, 1, 2, 1, 0, 1]:
		lab.call("select_model", model)
		await _frames(3)
		_expect(int(lab.get("selected_model")) == model, "model %d selected" % model)
		var current := lab.get("current_body") as CharacterBodyMesh
		var source := lab.get("source_body") as CharacterBodyMesh
		_expect(source != null, "source body available")
		if source == null:
			continue
		var active_count := 0
		for child: Node in player.skeleton.get_children():
			if child is CharacterBodyMesh and (child as CharacterBodyMesh).active:
				active_count += 1
		_expect(active_count == 1, "one body helper modifier owns model %d" % model)
		_expect(current.active == (model != 2) and source.active == (model == 2), "model modifier visibility contract")
		var fitted := current.part_meshes("fitted_hands")
		_expect(fitted.size() == (1 if model == 1 else 0), "one fitted hand part only in hybrid")
		_expect((current.report.get("missing", []) as Array).is_empty(), "current model has no missing bind bones")
		_expect((source.report.get("missing", []) as Array).is_empty(), "source model has no missing bind bones")
		_expect(float(source.report.get("max_bind_diff", INF)) < 0.001, "source inverse binds match canonical pose")
		if model == 0 and baseline == null:
			baseline = (current.part_meshes("head")[0] as MeshInstance3D).mesh
		if model == 0:
			_expect((current.part_meshes("head")[0] as MeshInstance3D).mesh == baseline, "current body restores original mesh after hybrid")
		if model == 1:
			var transfer: Dictionary = lab.get("reports").get("hand_transfer", {})
			_expect(bool(transfer.get("ok", false)), "hybrid transfer helper succeeds")
			_expect(int(transfer.get("native_triangles_removed", 0)) > 0, "native hand geometry removed in copied mesh")
			_expect((current.part_meshes("head")[0] as MeshInstance3D).mesh != baseline, "hybrid filters copied mesh only")
		for outfit in 3:
			lab.call("select_outfit", outfit)
			await _frames(2)
			_expect(int(lab.get("selected_outfit")) == outfit, "outfit %d selected on model %d" % [outfit, model])
			_expect(current.part_meshes("fitted_hands").size() == (1 if model == 1 else 0), "outfit change retains unique hand part")
			_expect(_owned_mesh_visibility(current, model != 2), "current owned parts visibility after outfit change")
			_expect(_mesh_visibility(source) == (source.meshes.size() if model == 2 else 0), "source mesh visibility after outfit change")
		if model in [1, 2]:
			_validate_skin(source if model == 2 else current, "model_%d" % model)
	notes["body_binding"] = (lab.get("source_body") as CharacterBodyMesh).report.duplicate(true)
	notes["hand_transfer"] = lab.get("reports").get("hand_transfer", {})


func _test_world_textures() -> void:
	var report: Dictionary = lab.get("reports").get("world", {})
	var found := {}
	for row: Dictionary in report.get("texture_sources", []):
		var role := String(row.get("role", ""))
		found[role] = true
		_expect(bool(row.get("loaded", false)), "world source texture hash/decode verified: " + role)
		_expect(not (row.get("material_usage", []) as Array).is_empty(), "world source texture actually assigned: " + role)
	_expect(found.size() == 6, "six decoded source texture roles loaded into test world")
	notes["world_textures"] = report.get("texture_sources", [])


func _validate_skin(body: CharacterBodyMesh, label: String) -> void:
	var bad := 0
	var vertices_seen := 0
	var max_weight_error := 0.0
	for instance: MeshInstance3D in body.meshes:
		if not is_instance_valid(instance) or instance.skin == null:
			bad += 1
			continue
		for bind in instance.skin.get_bind_count():
			var name := instance.skin.get_bind_name(bind)
			var bone := player.skeleton.find_bone(name) if name != &"" else instance.skin.get_bind_bone(bind)
			if bone < 0 or bone >= player.skeleton.get_bone_count():
				bad += 1
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / maxi(vertices.size(), 1)
			for vertex in vertices.size():
				vertices_seen += 1
				if not vertices[vertex].is_finite():
					bad += 1
				var total := 0.0
				for slot in stride:
					var index := vertex * stride + slot
					var weight := weights[index]
					if not is_finite(weight) or weight < 0.0:
						bad += 1
					if weight > 0.0 and (bones[index] < 0 or bones[index] >= instance.skin.get_bind_count()):
						bad += 1
					total += weight
				max_weight_error = maxf(max_weight_error, absf(total - 1.0))
	_expect(vertices_seen > 1000 and bad == 0, label + " vertices/skin indices/weights are finite and valid")
	_expect(max_weight_error < 0.001, label + " weights normalized")
	notes[label + "_skin"] = {"vertices": vertices_seen, "bad_values": bad, "max_weight_error": max_weight_error}


func _test_areas_and_movement() -> void:
	for spec: Array in [["map", 1], ["arena", 2]]:
		var area := String(spec[0])
		lab.call("select_model", int(spec[1]))
		lab.call("go_to", area)
		await _frames(90)
		_expect(String(lab.get("current_area")) == area, area + " teleport selects area")
		_expect(player.is_on_floor(), area + " spawn settles on ground collision")
		var floor_start := player.global_position
		player.controls.set_held(&"move_forward", true)
		await _seconds(1.5)
		player.controls.set_held(&"move_forward", false)
		var travelled := Vector2(player.global_position.x - floor_start.x, player.global_position.z - floor_start.z).length()
		_expect(travelled > 2.0, area + " native movement covers over 2 m after start transition")
		await _seconds(0.75)
		_expect(player.horizontal_speed() < 0.4, area + " native movement stops")
		var jump_start := player.global_position
		await physics_frame
		player.controls.set_held(&"jump", true)
		await _frames(2)
		player.controls.set_held(&"jump", false)
		var highest := player.global_position.y
		var airborne := false
		for frame in int(ceil(1.8 * Engine.physics_ticks_per_second)):
			await physics_frame
			highest = maxf(highest, player.global_position.y)
			airborne = airborne or not player.is_on_floor()
		_expect(airborne and highest - jump_start.y > 0.3, area + " native jump rises over 0.3 m")
		_expect(player.is_on_floor(), area + " jump returns to grounded movement")
		_expect(absf(player.global_position.y - jump_start.y) < 0.2, area + " landing remains near ground height")
		_expect(player.global_position.is_finite() and player.velocity.is_finite(), area + " movement remains finite")
		notes[area + "_motion"] = {"start": str(floor_start), "travelled_m": travelled,
			"jump_height_m": highest - jump_start.y, "landed": player.is_on_floor()}
	lab.call("select_model", 1)
	lab.call("select_outfit", 0)
	lab.call("go_to", "arena")
	await _frames(30)


func _test_weapons() -> void:
	for id: String in ["sword", "spear", "bow", "tomahawk", "sword", "spells"]:
		lab.call("select_weapon", id)
		var ready := await _wait_weapon(id)
		_expect(ready, id + " reaches native equipped/ready state")
		_expect(String(lab.get("selected_weapon")) == id, id + " lab selection agrees with native equipment")
		var active := 0
		for weapon: Weapon in player.weapons.values():
			if weapon.active:
				active += 1
		_expect(active <= 1, id + " has at most one active native weapon")
		if id in ["spear", "bow", "tomahawk"] and ready:
			_expect(player.weapon.model != null and player.weapon.model.is_visible_in_tree(), id + " drawn model visible")
			var parent := player.weapon.model.get_parent()
			_expect(parent is BoneAttachment3D, id + " attaches once through native hand socket")
			# Existing Bow/Throwable read Input LMB to draw; RMB lets down/cancels.
			Input.action_press("fire")
			await _seconds(0.4)
			_expect(player.weapon.aim > 0.05, id + " native LMB windup blend responds")
			Input.action_press("aim")
			await _frames(2)
			Input.action_release("aim")
			Input.action_release("fire")
			await _seconds(0.6)
		elif id == "sword" and ready:
			var hand_model := player.gather.get("_model_hand") as Node3D
			_expect(hand_model != null and hand_model.is_visible_in_tree(), "sword native saber hand model visible")
			expect_finite_pose("sword native grip")
		notes["weapon_" + id] = {"ready": ready, "native_key": player.weapon_key,
			"hands_free": player.hands_free, "tool": player.gather.in_hand(), "active_native_weapons": active}
	_expect(player.gather.in_hand() == "" and player.hands_free, "weapon-to-spell swap releases both hands")
	_expect(caster.readied_spell != "", "weapon-to-spell swap readies an actual spell")


func _wait_weapon(id: String) -> bool:
	for frame in int(ceil(8.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if id == "sword":
			if player.gather.in_hand() == "saber" and player.gather.phase == GatherTools.Phase.READY:
				return true
		elif id == "spells":
			if player.hands_free and player.gather.in_hand() == "" and caster.readied_spell != "":
				return true
		elif player.weapon_key == id and player.weapon != null and player.weapon.active \
				and not player.is_switching() and not player.weapon.is_equipping():
			return true
	return false


func _test_keyboard() -> void:
	for id: String in ["sword", "spear", "bow", "tomahawk", "spells"]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_1 + ["sword", "spear", "bow", "tomahawk", "spells"].find(id)
		key.pressed = true
		root.push_input(key)
		await _frames(2)
		key.pressed = false
		root.push_input(key)
		_expect(await _wait_weapon(id), "lab keyboard shortcut selects " + id)
	var panel := lab.get("_panel") as PanelContainer
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	var shown := panel.visible
	root.push_input(f1)
	await _frames(2)
	_expect(panel.visible != shown, "F1 toggles lab controls panel")
	f1.pressed = false
	root.push_input(f1)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await _frames(2)
	_expect(panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape exposes controls and frees cursor")
	esc.pressed = false
	root.push_input(esc)


func _test_casts() -> void:
	for element in 4:
		lab.call("select_element", element)
		# Use different ground positions; a previous spell may leave its real effects.
		lab.call("go_to", "arena")
		player.position += [Vector3(-5, 0, 5), Vector3(5, 0, 5), Vector3(-5, 0, -2), Vector3(5, 0, -2)][element]
		await _seconds(1.0)
		var element_name := String(Bending.ELEMENTS[element])
		_expect(Bending.of(player).element == element_name, element_name + " element selector reaches native caster")
		var before := released.size()
		player.controls.set_held(&"fire", true)
		var locked := false
		for frame in int(ceil(5.0 * Engine.physics_ticks_per_second)):
			await physics_frame
			if caster.state == SwayCaster.State.FULL:
				locked = true
				break
		var blocked := caster.blocked()
		_expect(locked, element_name + " quick spell locks through native controls (blocked=" + blocked + ")")
		player.controls.set_held(&"fire", false)
		await _seconds(2.0)
		_expect(released.size() > before, element_name + " quick spell releases native cast")
		expect_finite_pose(element_name + " cast and recovery")
		notes[element_name + "_cast"] = {"locked": locked, "releases": released.slice(before),
			"readied": caster.readied_spell, "blocked_before_release": blocked,
			"pose_phase": caster.pose.phase if caster.pose else ""}
	_expect(player.is_on_floor(), "all casts recover on arena ground")
	player.controls.set_held(&"move_right", true)
	var before_move := player.global_position
	await _seconds(1.5)
	player.controls.release_all()
	_expect(player.global_position.distance_to(before_move) > 2.0, "casting recovery permits movement after start transition")
	await _frames(35)


func _test_air_casts() -> void:
	for element in 4:
		lab.call("select_model", 1 if element % 2 == 0 else 2)
		lab.call("select_element", element)
		lab.call("go_to", "arena")
		player.position += [Vector3(-5, 0, 7), Vector3(5, 0, 7), Vector3(-5, 0, 0), Vector3(5, 0, 0)][element]
		await _seconds(1.5)
		var name := String(Bending.ELEMENTS[element])
		var before := observed_air_released.size()
		player.controls.set_held(&"fire", true)
		var locked := false
		for frame in int(ceil(5.0 * Engine.physics_ticks_per_second)):
			await physics_frame
			if caster.state == SwayCaster.State.FULL:
				locked = true
				break
		_expect(locked, name + " quick spell locks before jump")
		await physics_frame
		player.controls.set_held(&"jump", true)
		await _seconds(0.08)
		player.controls.set_held(&"jump", false)
		_expect(not player.is_on_floor(), name + " jump is airborne at cast release")
		player.controls.set_held(&"fire", false)
		await _seconds(2.0)
		_expect(observed_air_released.size() > before, name + " native quick cast releases while actual player is airborne")
		_expect(player.is_on_floor(), name + " air cast lands and recovers")
		expect_finite_pose(name + " fitted model airborne cast")
		notes[name + "_air_cast"] = {"locked": locked, "releases": observed_air_released.slice(before),
			"model": lab.get("selected_model"), "blocked": caster.blocked(), "round_3_gate": caster.r3()}
	player.controls.release_all()
	notes["round_3_air_signals"] = air_released.duplicate()


func _test_selected_spell() -> void:
	lab.call("select_model", 1)
	lab.call("select_element", 3)
	lab.call("select_spell", 0)
	lab.call("go_to", "arena")
	player.position += Vector3(-4, 0, 6)
	await _seconds(1.0)
	var selected := caster.readied_spell
	_expect(selected != "" and caster.has(selected), "spell selector readies a granted native spell")
	player.controls.release_all()
	var keyboard := DisplayServer.get_name() != "headless"
	player.controls.from_input = keyboard
	if keyboard:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	(lab.get("_panel") as PanelContainer).hide()
	if keyboard:
		Input.action_press("aim")
	else:
		player.controls.set_held(&"aim", true)
	var locked := false
	for frame in int(ceil(5.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if caster.state == SwayCaster.State.FULL:
			locked = true
			break
	_expect(locked and caster.move == selected, "RMB locks the selected spell")
	var before := released.size()
	if keyboard:
		Input.action_press("fire")
	else:
		player.controls.set_held(&"fire", true)
	await _frames(2)
	_expect(released.size() == before, "LMB does not prematurely release the held RMB spell")
	if InputMap.has_action("fire"):
		Input.action_release("fire")
	if InputMap.has_action("aim"):
		Input.action_release("aim")
	player.controls.release_all()
	await _seconds(2.0)
	_expect(released.size() > before and released[before] == selected, "RMB action hold and release casts selected native spell")
	player.controls.from_input = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	notes["selected_spell_cast"] = {"selected": selected, "locked": locked, "releases": released.slice(before),
		"keyboard_input": keyboard, "display_server": DisplayServer.get_name()}


func _test_spell_target() -> void:
	var target := lab.get("training_target") as FrontierPlayer
	_expect(target != null, "native spell contact target built")
	if target == null:
		return
	lab.call("select_model", 2)
	lab.call("select_element", 3)
	lab.call("select_weapon", "spells")
	lab.call("go_to", "arena")
	await _seconds(1.0)
	# The quick Palm cone has a 3.5 m damage reach, although its lock ray reaches 40 m.
	player.global_position = target.global_position + Vector3(0, 0.25, 2.6)
	player.velocity = Vector3.ZERO
	await _seconds(0.3)
	var before_hits := int(lab.get("target_hits"))
	var before_health := target.health
	var before_position := target.global_position
	var point := target.global_position + Vector3(0, 1.05, 0)
	for step in 6:
		var delta := point - player.camera.global_position
		player.yaw = atan2(-delta.x, -delta.z)
		player.pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
		await _frames(3)
	player.controls.set_held(&"fire", true)
	var locked := false
	for frame in int(ceil(5.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if caster.state == SwayCaster.State.FULL:
			locked = true
			break
	_expect(locked, "aimed quick spell locks facing actual contact target")
	player.controls.set_held(&"fire", false)
	await _seconds(2.0)
	var hits := int(lab.get("target_hits")) - before_hits
	var movement := target.global_position.distance_to(before_position)
	_expect(hits > 0 or target.health < before_health, "native spell actually hits target, beyond visual casting")
	_expect(target.velocity.is_finite() and target.global_position.is_finite(), "target contact/recovery remains finite")
	notes["spell_contact"] = {"hits": hits, "health_before": before_health, "health_after": target.health,
		"displacement_m": movement, "quick_spell": caster.quick_id(), "locked": locked}


func expect_finite_pose(label: String) -> void:
	var valid := true
	for bone in player.skeleton.get_bone_count():
		valid = valid and player.skeleton.get_bone_global_pose(bone).is_finite()
	_expect(valid, label + " keeps every skeleton transform finite")


func _render_views() -> void:
	root.size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	for spec: Array in [["map", 1, "spells", "terrain_current_body", "front"],
			["arena", 1, "spear", "arena_current_body_spear", "front"],
			["map", 1, "spells", "terrain_gameplay", "gameplay"],
			["arena", 1, "sword", "arena_fitted_hands_sword", "gameplay"]]:
		lab.call("select_model", int(spec[1]))
		lab.call("select_outfit", 0)
		lab.call("go_to", String(spec[0]))
		lab.call("select_weapon", String(spec[2]))
		await _wait_weapon(String(spec[2]))
		await _frames(60)
		if String(spec[4]) == "gameplay":
			view.set("source", player.camera)
			view.call("sync_camera")
		else:
			view.set("source", null)
			var target := player.global_position + Vector3(0, 0.95, 0)
			(view.get("camera") as Camera3D).global_position = player.global_position + Vector3(-2.3, 1.8, -3.2)
			(view.get("camera") as Camera3D).look_at(target)
			(view.get("camera") as Camera3D).fov = 42.0
		for frame in 3:
			await process_frame
		RenderingServer.force_draw(false)
		await process_frame
		var img := view.get_texture().get_image()
		var path := ProjectSettings.globalize_path(OUT.path_join(String(spec[3]) + ".png"))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		_expect(img != null and not img.is_empty() and img.get_size() == Vector2i(1280, 720), String(spec[3]) + " actual rendered frame")
		if img and not img.is_empty():
			_expect(img.save_png(path) == OK, String(spec[3]) + " capture saved")
			print("saved ", path)


func _mesh_visibility(body: CharacterBodyMesh) -> int:
	var count := 0
	for mesh: MeshInstance3D in body.meshes:
		if is_instance_valid(mesh) and mesh.is_visible_in_tree():
			count += 1
	return count


func _owned_mesh_visibility(body: CharacterBodyMesh, shown: bool) -> bool:
	var owned := {}
	for part: String in body.parts:
		for mesh: MeshInstance3D in body.part_meshes(part):
			owned[mesh] = true
			if mesh.is_visible_in_tree() != shown:
				return false
	for mesh: MeshInstance3D in body.meshes:
		if not owned.has(mesh) and mesh.is_visible_in_tree():
			return false # Legacy body stays hidden once the multipart outfit is dressed.
	return not owned.is_empty()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(int(ceil(seconds * Engine.physics_ticks_per_second)))


func _arg(key: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return ""


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
	else:
		print("ok: ", message)


func _finish() -> void:
	if player:
		player.controls.release_all()
	if InputMap.has_action("fire"):
		Input.action_release("fire")
	if InputMap.has_action("aim"):
		Input.action_release("aim")
	var report_file := "render_report.json" if _arg("capture_only") == "1" else "smoke_report.json"
	if _arg("focus") == "contact":
		report_file = "contact_report.json"
	elif _arg("focus") == "selected":
		report_file = "selected_spell_report.json"
	var path := ProjectSettings.globalize_path(OUT.path_join(report_file))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "notes": notes}, "\t"))
	print("ASSET LAB ", "PASSED" if failures.is_empty() else "FAILED", ": ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
