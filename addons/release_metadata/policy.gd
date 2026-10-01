@tool
extends RefCounted
## Export policy only. Never saves over a source asset or edits its cached Resource.
## Explicit field lists avoid deleting functional fields such as source, additive_source,
## sample_rate, graph IDs, clip names, alias tables, transitions or motion samples.

const ANIMATION_FIELDS := [
	&"source_attribution", &"native_asset_id", &"native_asset_ids", &"source_native_asset_id",
	&"original_name", &"original_names", &"source_library", &"source_file", &"source_actor",
	&"target_actor", &"retarget", &"conversion", &"disc_offset", &"tool", &"authored",
	&"source_names", &"source",
]
const TABLE_FIELDS := [
	"source_attribution", "attribution", "authorization", "provenance",
	"native_asset_id", "native_asset_ids", "source_native_asset_id",
]
const TABLE_PREFIXES := [
	"res://animations/", "res://data/traversal/", "res://data/loadout/", "res://data/climb/",
]


static func is_animation_table(path: String) -> bool:
	if path.get_extension() != "json":
		return false
	for prefix: String in TABLE_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


const Rights := preload("res://addons/release_metadata/rights.gd")


static func copy_resource(resource: Resource) -> Resource:
	var copy := _copy_resource(resource)
	Rights.stamp(copy)
	return copy


static func _copy_resource(resource: Resource) -> Resource:
	if resource is AnimationLibrary:
		var source := resource as AnimationLibrary
		var copy := source.duplicate(false) as AnimationLibrary
		_remove_resource_fields(copy)
		for name in source.get_animation_list():
			var animation := _copy_resource(source.get_animation(name)) as Animation
			Rights.stamp(animation)
			copy.remove_animation(name)
			copy.add_animation(name, animation)
		return copy
	if resource is Animation:
		var copy := resource.duplicate(false) as Animation
		_remove_resource_fields(copy)
		return copy
	return null


static func _remove_resource_fields(resource: Resource) -> void:
	for field: StringName in ANIMATION_FIELDS:
		if resource.has_meta(field):
			resource.remove_meta(field)
	# JSON aliases and the skeleton's bind-rest source are separate from Animation metadata.
	# Preserve every field that is not explicitly listed above.


static func copy_table(value: Variant) -> Variant:
	if value is Dictionary:
		var copy := {}
		for key: Variant in value:
			if str(key) not in TABLE_FIELDS:
				copy[key] = copy_table(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item: Variant in value:
			copy.append(copy_table(item))
		return copy
	return value


static func copy_animation_table(path: String, data: Variant) -> Variant:
	var copy: Variant = copy_table(data)
	# This specific root object is an authoring record, not a state-machine source edge.
	if path == "res://data/climb/climb_tree.json" and copy is Dictionary:
		copy.erase("source")
	return copy


static func strip_bind_rest_ids(node: Node) -> bool:
	# Only called on an export scene instance, never on the open editor scene.
	var changed := false
	if node is Skeleton3D and node.has_meta(&"bind_rest"):
		var stamp: Variant = node.get_meta(&"bind_rest")
		if stamp is Dictionary and stamp.has("native_asset_id"):
			var copy: Dictionary = stamp.duplicate(true)
			copy.erase("native_asset_id")
			node.set_meta(&"bind_rest", copy)
			changed = true
	for child in node.get_children():
		changed = strip_bind_rest_ids(child) or changed
	return changed
