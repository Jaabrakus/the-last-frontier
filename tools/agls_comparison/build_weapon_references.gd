extends SceneTree
## Sample Frontier's real weapon graph for comparison actions, including its aim sweep and held draw.
const SPECS := {
 "ALS_Props_Bow_Aim_Sweep": ["bow", "stand", "sweep"],
 "ALS_Props_Bow_Aim_Sweep_Crouched": ["bow", "crouch", "sweep"],
 "ALS_Props_Rifle_Aim_Sweep": ["musket", "stand", "sweep"],
 "ALS_Props_Rifle_Aim_Sweep_Crouched": ["musket", "crouch", "sweep"],
 "ALS_Props_RecurveBow_Draw_Stand": ["bow", "stand", "draw"],
 "ALS_Props_RecurveBow_Draw_Crouch": ["bow", "crouch", "draw"],
 "ALS_Props_RecurveBow_Recoil": ["bow", "stand", "release"],
 "ALS_Props_Bow_Sheath_Stand": ["bow", "stand", "sheath"],
 "ALS_Props_Bow_Sheath_Crouch": ["bow", "crouch", "sheath"],
}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var agls: AnimationLibrary = load("res://animations_extra/AGLS_Preview.res")
 for profile in ["Original", "Updated"]:
  var rig := RigFixture.actor_b(root)
  var data := AnimGraphData.from_dicts(JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/actor_b_graph_original.json")), JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/actor_b_clip_metrics_original.json"))) if profile == "Original" else AnimGraphData.load_files()
  var idx := TreeBuilder.build(data, rig.ap, rig.sk)
  assert(idx.errors.is_empty(), str(idx.errors))
  rig.play(AnimationNodeBlendTree.new())
  idx.install(rig.tree)
  var output := AnimationLibrary.new()
  for name: String in SPECS:
   var spec: Array = SPECS[name]
   var inp := AnimInputs.new()
   inp.weapon_key = StringName(spec[0]); inp.crouched = spec[1] == "crouch"
   inp.alive = true; inp.on_floor = true; inp.wants_aim = spec[2] != "sheath"
   inp.weapon_aim = 1.0 if inp.wants_aim else 0.0
   var upper := UpperBody.new(data, rig.tree, idx)
   var lower := XFadeSelector.new(rig.tree, "L", idx.L_inputs, idx.L_seek)
   upper.set_lower_selector(lower); upper.set_weapon(inp.weapon_key); upper.snap(inp)
   var lower_id := StringName("aimidle__%s__%s" % [spec[0], spec[1]]) if inp.wants_aim else StringName("idle__%s" % spec[1])
   var duration := agls.get_animation(name).length
   lower.set_immediate(lower_id, 0.0)
   # Settle into the held aim; a release starts with a full draw.
   inp.charge = 1.0 if spec[2] == "release" else 0.0
   for warm in 8:
    upper.tick(inp, &"AIM_IDLE" if inp.wants_aim else &"IDLE", 1.0/60)
    lower.update(0); lower.write(); rig.tree.advance(1.0/60)
   if spec[2] == "release": upper.on_fired(inp.weapon_key)
   if spec[2] == "sheath": upper.on_holster(inp.weapon_key, duration)
   var animation := Animation.new(); animation.length = duration
   var tracks := []
   for b in rig.sk.get_bone_count():
    var path := NodePath("Skeleton3D:" + String(rig.sk.get_bone_name(b)))
    var p := animation.add_track(Animation.TYPE_POSITION_3D); animation.track_set_path(p, path)
    var r := animation.add_track(Animation.TYPE_ROTATION_3D); animation.track_set_path(r, path)
    tracks.append([p,r])
   var count := ceili(duration * 60)
   for k in count + 1:
    var phase := float(k)/count
    inp.aim_elev_deg = 70.0 * (1.0 - 2.0 * phase) if spec[2] == "sweep" else 0.0
    inp.aim_point = Vector3(0, data.chest_height(spec[1]), 0) + Vector3(0, sin(deg_to_rad(inp.aim_elev_deg)), cos(deg_to_rad(inp.aim_elev_deg))) * 25
    inp.charge = phase if spec[2] == "draw" else 0.0
    upper.snap(inp)
    lower.set_immediate(lower_id, phase)
    if inp.wants_aim: upper.A.set_immediate(StringName(idx.aim["%s/%s" % [spec[0], spec[1]]].input), phase)
    upper.tick(inp, &"AIM_IDLE" if inp.wants_aim else &"IDLE", duration/count if k > 0 else 0.0)
    lower.update(0); lower.write()
    rig.tree.advance(duration/count if k > 0 else 0.0); rig.tree.advance(0)
    var time := float(PackedFloat32Array([phase*duration])[0])
    for b in tracks.size():
     animation.position_track_insert_key(tracks[b][0], time, rig.sk.get_bone_pose_position(b))
     animation.rotation_track_insert_key(tracks[b][1], time, rig.sk.get_bone_pose_rotation(b).normalized())
   var source_names := []
   collect_clips(data.aim_tree(spec[0],spec[1]),source_names)
   for kind in ["charge", "fire"]:
    var c := data.runtime_clip(kind, spec[0] if kind == "charge" else "%s/%s" % [spec[0],spec[1]])
    if c != "" and not source_names.has(c): source_names.append(c)
   var ids := []
   for c: String in source_names:
    if rig.ap.has_animation(data.godot_anim(c)):
     ids.append(rig.ap.get_animation(data.godot_anim(c)).get_meta("native_asset_id", ""))
   animation.set_meta("native_asset_ids",ids)
   animation.set_meta("source_original_names",source_names)
   animation.set_meta("source_attribution",rig.ap.get_animation("actor_b/actor_b-p-rifle-idle-aim").get_meta("source_attribution", ""))
   animation.set_meta("derivation","Frontier " + profile + " weapon graph sampled for comparison; live grip/aim modifiers remain in gameplay")
   animation.set_meta("sample_rate",60.0); animation.set_meta("additive_source",false)
   output.add_animation(name,animation)
  assert(ResourceSaver.save(output,"res://animations_extra/Frontier_Weapon_" + profile + ".res") == OK)
  rig.root.queue_free()
  print("FRONTIER_WEAPON_REFERENCE_READY profile=",profile," clips=",output.get_animation_list().size())
 quit()
func collect_clips(value: Variant, out: Array) -> void:
 if value is Dictionary:
  for key in value:
   if key == "clip" and value[key] is String and not out.has(value[key]): out.append(value[key])
   else: collect_clips(value[key], out)
 elif value is Array:
  for item in value: collect_clips(item, out)
