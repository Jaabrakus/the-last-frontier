extends SceneTree
## Select an external Frontier Legacy movement library; retain main's current action and carry patches.
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
const OVERRIDES := {
	"actor_b-p-jump-long": "ALSv2_JumpSeq_Idle",
 "actor_b-p-walk-fw": "ALS_N_Walk_F", "actor_b-p-walk-bw": "ALS_N_Walk_B",
 "actor_b-p-walk-fw-lt": "ALS_N_Walk_LF", "actor_b-p-walk-fw-rt": "ALS_N_Walk_RF",
 "actor_b-p-run-fw": "ALS_N_Run_F", "actor_b-p-run-bw": "ALS_N_Run_B",
 "actor_b-p-run-fw-lt": "ALS_N_Run_LF", "actor_b-p-run-fw-rt": "ALS_N_Run_RF",
 "actor_b-p-sprint-fw": "ALS_N_Sprint_F",
}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var style := "approved"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("style="): style = arg.trim_prefix("style=")
 assert(style in ["approved", "grounded", "athletic"])
 var suffix := "" if style == "approved" else "_" + style
 var libname := "frontier_legacy" + suffix
 var path := "res://animations_extra/Frontier_Legacy/"
 path += "Frontier_Legacy.res" if style == "approved" else style.capitalize() + "/Frontier_Legacy_" + style.capitalize() + ".res"
 var library: AnimationLibrary = load(path)
 var baseline: AnimationLibrary = load("res://.comparison-private/Actor_B_original.res")
 var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/actor_b_graph_original.json"))
 var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/actor_b_clip_metrics_original.json"))
 var overrides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/locomotion_main_updated.json"))
 var rows := []
 for alias: String in OVERRIDES:
  var name: String = Names.CLIPS[OVERRIDES[alias]]
  assert(baseline.has_animation(alias) and library.has_animation(name))
  var animation := library.get_animation(name)
  var previous := baseline.get_animation(alias)
  var speed := float(metrics.clips.get(alias, {}).get("travel", {}).get("speed", 0))
  var entry := {"lib": libname, "clip": name, "length": animation.length,
   "source_base_alias": alias, "source_agls_clip": OVERRIDES[alias]}
  if style == "approved" and speed > 0.0:
   entry["speed"] = speed
  elif speed > 0.0:
   # Preview timing variants: proportional speed estimate; contact tuning remains a production gate.
   entry["speed"] = speed * previous.length / animation.length
   entry["speed_estimate"] = "baseline speed scaled by authored cycle duration"
  overrides.clips[alias] = entry
  rows.append(entry)
 overrides["frontier_legacy_profile"] = style
 write_json("res://data/anim_author/locomotion_clips.json", overrides)
 write_json("res://.comparison-private/reports/game-import.json", {"profile": style, "clips": rows,
  "native_library_unchanged": true, "action_and_weapon_patches_retained": true,
  "scope": "10 locomotion/jump overrides plus bow and vault runtime adapters from frontier_legacy_gameplay.json; crouch locomotion, rifle and climbing remain comparison previews"})
 print("FRONTIER_LEGACY_GAME_READY style=", style, " overrides=", rows.size())
 quit()
func write_json(path: String, value: Variant) -> void:
 var f := FileAccess.open(path, FileAccess.WRITE)
 f.store_string(JSON.stringify(value, "\t") + "\n")
