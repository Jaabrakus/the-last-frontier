@tool
extends EditorExportPlugin

const Policy := preload("res://addons/release_metadata/policy.gd")
const Rights := preload("res://addons/release_metadata/rights.gd")
var _release := false
var _resources := 0
var _tables := 0


func _get_name() -> String:
	return "FrontierReleaseMetadata"


func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_release = not is_debug
	_resources = 0
	_tables = 0
	if _release:
		# the rights notice at the package root, in the machine-readable forms (Rights)
		add_file("res://tdmrep.json", Rights.tdmrep_json().to_utf8_buffer(), false)
		for p: String in [Rights.NOTICE_PATH, Rights.EULA_PATH]:
			if FileAccess.file_exists(p):
				add_file(p, FileAccess.get_file_as_bytes(p), false)


func _begin_customize_resources(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return _release


func _begin_customize_scenes(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return _release


func _get_customization_configuration_hash() -> int:
	# Include the implementation so cached exports are invalidated when policy changes.
	return (FileAccess.get_sha256("res://addons/release_metadata/policy.gd") +
			FileAccess.get_sha256("res://addons/release_metadata/export_plugin.gd") +
			FileAccess.get_sha256("res://addons/release_metadata/rights.gd") + FileAccess.get_sha256(Rights.NOTICE_PATH)).hash()


func _customize_resource(resource: Resource, _path: String) -> Resource:
	if not _release:
		return null
	var copy := Policy.copy_resource(resource)
	if copy != null:
		_resources += 1
	return copy


func _customize_scene(scene: Node, _path: String) -> Node:
	if not _release:
		return null
	Policy.strip_bind_rest_ids(scene)
	Rights.stamp(scene)   # every exported scene's root carries the rights notice
	return scene


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _release or not Policy.is_animation_table(path):
		return
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		push_error("Release metadata: cannot parse %s: %s" % [path, json.get_error_message()])
		return
	var copy: Variant = Policy.copy_animation_table(path, json.data)
	# Full precision preserves runtime sample coordinates through the JSON round trip.
	add_file(path, JSON.stringify(copy, "", true, true).to_utf8_buffer(), false)
	skip()
	_tables += 1


func _export_end() -> void:
	if _release:
		print("Release animation metadata: %d resources customized, %d tables exported (resources may be cached)." %
				[_resources, _tables])
	_release = false
