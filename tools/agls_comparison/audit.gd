extends SceneTree
const Mapping := preload("res://tools/agls_comparison/author_frontier.gd")
const Installer := preload("res://tools/agls_comparison/install_game.gd")
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var baseline: AnimationLibrary = load("res://.comparison-private/Actor_B_original.res")
 var native: AnimationLibrary = load("res://animations/Actor_B.res")
 var agls: AnimationLibrary = load("res://animations_extra/AGLS_Preview.res")
 var approved: AnimationLibrary = load("res://animations_extra/Frontier_Legacy/Frontier_Legacy.res")
 var data := AnimGraphData.load_files()
 var failures := []
 var originals_equal := FileAccess.get_sha256("res://animations/Actor_B.res") == FileAccess.get_sha256("res://.comparison-private/Actor_B_original.res")
 if not originals_equal: failures.append("Native library bytes changed")
 var names_equal := baseline.get_animation_list() == native.get_animation_list()
 if not names_equal: failures.append("Trimmed native clip set changed")
 var overrides := []
 for alias: String in Installer.OVERRIDES:
  var path := data.godot_anim(alias)
  if not String(path).begins_with("frontier_legacy/"): failures.append("Runtime alias not using approved Legacy: " + alias)
  var name: String = Names.CLIPS[Installer.OVERRIDES[alias]]
  var a := baseline.get_animation(alias); var b := approved.get_animation(name)
  if Mapping.position_signature(a) != Mapping.position_signature(b) or (alias != "actor_b-p-jump-long" and Mapping.leg_signature(a) != Mapping.leg_signature(b)): failures.append("Approved gait contacts changed: " + alias)
  overrides.append({"alias":alias,"effective_path":path})
 var identities_retained := true
 for source_name: String in Names.CLIPS:
  var original := agls.get_animation(source_name)
  var animation := approved.get_animation(Names.CLIPS[source_name])
  if original.get_meta("source_asset_sha256") != animation.get_meta("agls_source_sha256"):
   identities_retained = false; failures.append("AGLS identity missing: " + source_name)
  if not animation.has_meta("native_asset_id") and not animation.has_meta("native_asset_ids"):
   identities_retained = false; failures.append("Frontier identity missing: " + source_name)
 var counts := {}
 for style in ["Grounded","Athletic"]:
  var library: AnimationLibrary = load("res://animations_extra/Frontier_Legacy/" + style + "/Frontier_Legacy_" + style + ".res")
  if library.get_animation_list() != approved.get_animation_list(): failures.append("Style clip set differs: " + style)
  var changed := 0
  for name in library.get_animation_list():
   var a := library.get_animation(name)
   if a.get_meta("style_motion_changed",false): changed += 1
   if a.get_meta("agls_source_sha256") != approved.get_animation(name).get_meta("agls_source_sha256"):
    identities_retained = false; failures.append("Style lost source identity: " + String(name))
  counts[style] = {"clips":library.get_animation_list().size(),"authored_motion_clips":changed}
 var weapons: AnimationLibrary = load("res://animations_extra/Frontier_Legacy/Frontier_Legacy_Weapons.res")
 var report := {"native_clip_count":native.get_animation_list().size(),"native_library_bytes_unchanged":originals_equal,
  "trimmed_clip_set_identical":names_equal,"native_library_sha256":FileAccess.get_sha256("res://animations/Actor_B.res"),
  "approved_clips":approved.get_animation_list().size(),"agls_clips":agls.get_animation_list().size(),"source_identities_retained":identities_retained,
  "styles":counts,"weapon_export_clips":weapons.get_animation_list().size(),"effective_overrides":overrides,"failures":failures}
 var f := FileAccess.open("res://.comparison-private/reports/library-audit.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"\t") + "\n")
 print("FRONTIER_LEGACY_AUDIT ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
