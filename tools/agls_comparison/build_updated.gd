extends SceneTree
## Freeze main's current clip selection beside the original reference; never write to main.
const Mapping := preload("res://tools/agls_comparison/author_upper.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var original: AnimationLibrary = load("res://animations_extra/Frontier_Comparison_Reference.res")
 var updated: AnimationLibrary = load("res://.comparison-private/Frontier_main_updated.res")
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/locomotion_main_updated.json"))
 var weapons: AnimationLibrary = load("res://animations_extra/Frontier_Weapon_Updated.res")
 var output := AnimationLibrary.new()
 var records := []
 for name in original.get_animation_list():
  var alias: String = Mapping.REFERENCES[String(name)]
  var entry: Dictionary = config.clips.get(alias, {})
  var animation := updated.get_animation(entry.clip) if entry.get("lib") == "frontier_locomotion" else original.get_animation(name)
  if weapons.has_animation(name): animation = weapons.get_animation(name)
  assert(animation != null, "Main preview clip missing: " + str(entry))
  output.add_animation(name, animation)
  records.append({"agls_comparison": name, "main_alias": alias, "main_override": entry, "differs_from_original": not entry.is_empty()})
 assert(ResourceSaver.save(output, "res://animations_extra/Frontier_Updated_Comparison.res") == OK)
 var f := FileAccess.open("res://.comparison-private/reports/main-comparison.json", FileAccess.WRITE)
 f.store_string(JSON.stringify({"snapshot_commit": FileAccess.get_file_as_string("res://.comparison-private/main_snapshot_commit.txt").strip_edges(),
  "snapshot_library_sha256": FileAccess.get_sha256("res://.comparison-private/Frontier_main_updated.res"), "clips": records}, "\t") + "\n")
 print("FRONTIER_UPDATED_COMPARISON_READY clips=", records.size())
 quit()
