extends SceneTree
## Lists every structure collider of the Frontier level (the fort, the range, the dummies'
## stands: everything except the Terrain, Vegetation and Player subtrees) and compares it
## with a saved baseline, so structure work (package D) can prove the collision layout is
## unchanged. Headless is fine:
##
##   Godot --headless --path . -s tools/environment/dump_colliders.gd -- --no-capture \
##       [out=<file.json>] [compare=res://tools/environment/baselines/colliders_baseline.json]
##
## Each entry: shape type, size (box size / radius+height / ...), global position and basis
## (rounded to 1 mm / 1e-4), the body's "surface" and "hit_part" meta and its class. With
## compare= it prints every missing / extra / changed collider and ends with
## COLLIDERS MATCH or COLLIDERS DIFFER (exit 0 / 1). Moving dummies are sampled at load time.
## baselines/colliders_baseline.json: 81 entries since the textured fort was wired in
## (2026-09-25): the original 59, package D's 21 extras and the cabin roof prism. The 59-entry
## placeholder baseline is kept as baselines/colliders_baseline_59_placeholder.json.

const SKIP := ["Terrain", "Vegetation", "Player", "EnvironmentRig"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var entries := []
	_collect(current_scene, entries)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	print("colliders: %d" % entries.size())
	if args.has("out"):
		var f := FileAccess.open(String(args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(entries, " "))
		f.close()
		print("wrote ", args["out"])
	var ok := true
	if args.has("compare"):
		ok = _compare(entries, String(args["compare"]))
		print("COLLIDERS MATCH" if ok else "COLLIDERS DIFFER")
	quit(0 if ok else 1)


func _collect(n: Node, out: Array) -> void:
	if n.get_parent() == current_scene and String(n.name) in SKIP:
		return
	var cs := n as CollisionShape3D
	if cs and cs.shape and not cs.disabled:
		var body := cs.get_parent() as CollisionObject3D
		var t := cs.global_transform
		var e := {
			"shape": cs.shape.get_class(),
			"size": _size(cs.shape),
			"pos": _r3(t.origin, 1000.0),
			"basis": [_r3(t.basis.x, 1e4), _r3(t.basis.y, 1e4), _r3(t.basis.z, 1e4)],
			"body": body.get_class() if body else "",
			"surface": String(body.get_meta(&"surface", "")) if body else "",
			"hit_part": String(body.get_meta(&"hit_part", "")) if body else "",
		}
		e["key"] = "%s %s %s" % [e.shape, str(e.pos), str(e.size)]
		out.append(e)
	for c in n.get_children():
		_collect(c, out)


func _size(s: Shape3D) -> Array:
	if s is BoxShape3D:
		return _r3((s as BoxShape3D).size, 1000.0)
	if s is CylinderShape3D:
		return [snappedf((s as CylinderShape3D).radius, 0.001), snappedf((s as CylinderShape3D).height, 0.001)]
	if s is CapsuleShape3D:
		return [snappedf((s as CapsuleShape3D).radius, 0.001), snappedf((s as CapsuleShape3D).height, 0.001)]
	if s is SphereShape3D:
		return [snappedf((s as SphereShape3D).radius, 0.001)]
	if s is ConvexPolygonShape3D:
		return [(s as ConvexPolygonShape3D).points.size()]
	if s is ConcavePolygonShape3D:
		return [(s as ConcavePolygonShape3D).get_faces().size()]
	return []


func _r3(v: Vector3, k: float) -> Array:
	return [roundf(v.x * k) / k, roundf(v.y * k) / k, roundf(v.z * k) / k]


func _compare(now: Array, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("cannot read ", path)
		return false
	var base: Array = JSON.parse_string(f.get_as_text())
	var by_key := {}
	for e: Dictionary in base:
		by_key[e.key] = e
	var seen := {}
	var ok := true
	for e: Dictionary in now:
		if not by_key.has(e.key):
			print("  EXTRA   ", e.key, " surface=", e.surface)
			ok = false
			continue
		seen[e.key] = true
		var b: Dictionary = by_key[e.key]
		if str(b.basis) != str(e.basis) or b.surface != e.surface or b.hit_part != e.hit_part:
			print("  CHANGED ", e.key, " basis/meta: ", b.basis, " ", b.surface, " -> ", e.basis, " ", e.surface)
			ok = false
	for k: String in by_key:
		if not seen.has(k):
			print("  MISSING ", k)
			ok = false
	print("baseline %d, now %d" % [base.size(), now.size()])
	return ok
