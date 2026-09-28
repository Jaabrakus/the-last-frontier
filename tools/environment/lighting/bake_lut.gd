extends SceneTree
## Bakes the colour-grade LUT (scripts/world/env/grade_lut.gd) into
## assets/environment/lut/frontier_grade_64_<hash>.png plus its .import (3D texture, 8x8 slices,
## lossless, no mipmaps). Old bakes in that folder are removed. Headless:
##
##   Godot --headless --path . -s tools/environment/lighting/bake_lut.gd [-- out=<dir>]
##   Godot --headless --path . --import          # then import the new PNG
##
## Prints "LUT BAKED <path>" at the end.

const GradeLut := preload("res://scripts/world/env/grade_lut.gd")

const IMPORT := """[remap]

importer="3d_texture"
type="CompressedTexture3D"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
slices/horizontal=8
slices/vertical=8
"""


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var n := GradeLut.BAKED_SIZE
	var grid := 8
	var t0 := Time.get_ticks_msec()
	var sheet := Image.create(n * grid, n * grid, false, Image.FORMAT_RGBA8)
	for b in n:
		var s := GradeLut.slice_image(n, b, GradeLut.DEFAULT_PARAMS)
		sheet.blit_rect(s, Rect2i(0, 0, n, n), Vector2i((b % grid) * n, (b / grid) * n))
	var path := GradeLut.baked_path()
	var dir: String = args.get("out", GradeLut.BAKED_DIR)
	path = dir.path_join(path.get_file())
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	# Remove stale bakes (other parameter hashes).
	for f in DirAccess.get_files_at(abs_dir):
		if f.begins_with("frontier_grade_") and not f.begins_with(path.get_file()):
			DirAccess.remove_absolute(abs_dir.path_join(f))
			print("removed stale ", f)
	sheet.save_png(ProjectSettings.globalize_path(path))
	var f := FileAccess.open(ProjectSettings.globalize_path(path) + ".import", FileAccess.WRITE)
	f.store_string(IMPORT % path)
	f.close()
	print("LUT baked in %d ms: %d^3, hash %s" % [Time.get_ticks_msec() - t0, n, GradeLut.params_hash(GradeLut.DEFAULT_PARAMS)])
	print("LUT BAKED ", path)
	quit()
