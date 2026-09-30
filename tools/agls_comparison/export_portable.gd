extends SceneTree
## Standalone libraries: 12 selected movement clips plus seven bow actions embedded per preset.
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
const MOVES := ["ALS_N_Walk_F","ALS_N_Run_F","ALS_N_Sprint_F","ALSv2_JumpSeq_Idle","ALSv2_N_Vault_1m_LH","ALSv2_N_Vault_1m_RH","ALS_N_Walk_B","ALS_N_Walk_LF","ALS_N_Walk_RF","ALS_N_Run_B","ALS_N_Run_LF","ALS_N_Run_RF"]
const BOWS := ["ALS_Props_Bow_Aim_Sweep", "ALS_Props_Bow_Aim_Sweep_Crouched", "ALS_Props_RecurveBow_Draw_Stand", "ALS_Props_RecurveBow_Draw_Crouch", "ALS_Props_RecurveBow_Recoil", "ALS_Props_Bow_Sheath_Stand", "ALS_Props_Bow_Sheath_Crouch"]
const OUTPUT := "res://animations_extra/Frontier_Legacy/Portable/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var reports := []
 for style: String in ["Approved","Grounded","Athletic","Bow"]:
  var path := "res://animations_extra/Frontier_Legacy/"
  path += "Frontier_Legacy.res" if style in ["Approved", "Bow"] else style + "/Frontier_Legacy_" + style + ".res"
  var source: AnimationLibrary = load(path)
  var output := AnimationLibrary.new()
  var rows := []
  var selected: Array = BOWS.duplicate() if style == "Bow" else MOVES + BOWS
  for name: String in selected:
   var action: String = Names.CLIPS[name]
   assert(source.has_animation(action))
   var clip := source.get_animation(action)
   output.add_animation(action,clip)
   rows.append({"name":action,"duration":clip.length,"source_agls_clip":name,"source_agls_sha256":clip.get_meta("agls_source_sha256"),"variant_identity":clip.get_meta("variant_identity")})
  output.set_meta("frontier_legacy_portable",true)
  output.set_meta("frontier_legacy_style",style.to_lower())
  output.set_meta("clip_count",selected.size())
  output.set_meta("skeleton_contract","Frontier Actor_B bone names, bind rest and Skeleton3D track path")
  output.set_meta("derivation","Frontier / AGLS authored blend; per-clip source identities retained")
  output.set_meta("all_animation_resources_embedded",true)
  var filename: String = "Frontier_Legacy_Movement" + ("" if style == "Approved" else "_" + style) + ".res"
  if style == "Bow": filename = "Frontier_Legacy_Bow.res"
  var destination: String = OUTPUT + filename
  assert(ResourceSaver.save(output,destination,ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS) == OK)
  var deps := ResourceLoader.get_dependencies(destination)
  assert(deps.is_empty(),"Portable resource has external dependencies: " + str(deps))
  reports.append({"file":filename,"preset":style,"sha256":FileAccess.get_sha256(destination),"external_dependencies":Array(deps),"clips":rows})
  print("FRONTIER_PORTABLE_READY file=",filename," clips=",rows.size())
 var f := FileAccess.open(OUTPUT + "manifest.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"primary_file":"Frontier_Legacy_Movement.res","format":"Godot AnimationLibrary with embedded Animation resources","target":"Godot 4.7.2 / Frontier Actor_B skeleton","movement_clip_count":MOVES.size(),"bow_clip_count":BOWS.size(),"libraries":reports},"\t") + "\n")
 quit()
