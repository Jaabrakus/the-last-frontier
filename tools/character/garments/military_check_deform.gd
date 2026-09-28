extends "res://tools/character/check_body_deform.gd"
## tools/character/check_body_deform.gd with each part's own limits: a surface whose name
## has an entry in its catalog fragment's "deform_limits" ({surface: [collapse share,
## flip share, stretch share, max edge ratio]}, next to the glb) uses those; everything
## else (skin, hair, legacy materials) keeps check_body_deform's tables. The scan itself,
## the clips, the metrics and the skirt-hang rule are check_body_deform's, unchanged.
##
##   Godot --headless --path <Frontier> -s tools/character/garments/military_check_deform.gd -- \
##       parts=res://assets/character/body/body.glb,res://assets/character/garments/military/br_breeches.glb sex=0
##
## Works for any catalog garment with "deform_limits" (the military, militia and woodlands
## fragments carry them). Prints CHECK PASSED / CHECK FAILED like the base check, and one
## "limits:" line per part saying where its limits came from.

var _part_limits := {}


func _limit(lab: String) -> Array:
	if _part_limits.is_empty() and args.has("parts"):
		_load_part_limits()
	if _part_limits.has(lab):
		return _part_limits[lab]
	return super._limit(lab)


func _load_part_limits() -> void:
	_part_limits["__loaded"] = []
	for p in String(args.parts).split(","):
		var frag := String(p).get_basename() + ".json"
		if not FileAccess.file_exists(frag):
			continue
		var e = JSON.parse_string(FileAccess.get_file_as_string(frag))
		if not (e is Dictionary) or not e.has("deform_limits"):
			continue
		var dl: Dictionary = e.deform_limits
		for surf: String in dl:
			_part_limits[surf] = dl[surf]
			print("  limits: %s from %s %s" % [surf, frag.get_file(), str(dl[surf])])
