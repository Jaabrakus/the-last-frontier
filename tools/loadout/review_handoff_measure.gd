extends SceneTree
## Independent handoff check for the loadout review: draws and puts away every drawable item of every
## preset (stand and crouch, the draw set's source clips where they exist, else the rig's timer), at 60
## frames/s, and follows what is SHOWN: the visible node of the item (its stowed unit, the moving copy, or
## the in-hand model), through its model-space bounding box corners carried into skeleton space by that
## node's own transform chain. Reports per run: the largest frame-to-frame jump of the shown item and the
## step at each change of the shown node against the motion the frame before (a pop is a step much larger
## than the motion around it), frames where the item shows twice or not at all, and whether the stowed
## copies of the OTHER items jump (the back stack settling when an item leaves or rejoins it).
##
##   Godot --headless --path . -s tools/loadout/review_handoff_measure.gd -- [out=/abs/report.json] [presets=a,b]
##   (run it under a hard time limit)
##
## Provenance: the rig, clips and bind pose are Actor_B.

const FPS := 60.0
const DRAWABLE := ["musket", "bow", "pistol", "spear_pair", "tomahawk", "atlatl"]

var args := {}
var sk: Skeleton3D
var body: CharacterBodyMesh
var poser: LoadoutClipPoser
var report := {"runs": []}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	poser = LoadoutClipPoser.new(sk, ap)
	await process_frame
	await process_frame
	var data := LoadoutData.get_default()
	var want: Array = String(args.get("presets", ",".join(data.preset_ids()))).split(",", false)
	var worst := {"pop_ratio": 0.0, "jump_cm": 0.0, "double": 0, "vanish": 0, "other_cm": 0.0}
	for pid: String in want:
		var rig := SlingRig.new()
		root.add_child(rig)
		rig.setup(sk, body, Loadout.from_preset(pid), {"auto": false})
		for it: Dictionary in rig.loadout.items:
			if not String(it.kind) in DRAWABLE or rig.entries_of(String(it.id)).is_empty():
				continue
			var side: String = (rig.entries_of(String(it.id))[0] as SlingRig.Entry).hold
			var att := BoneAttachment3D.new()
			att.bone_name = SlingRig.PROPS[side]
			sk.add_child(att)
			var m := SlingModels.unit("spear" if String(it.kind) == "spear_pair" else String(it.kind))
			m.transform = SlingRig.HAND_OFFSET
			att.add_child(m)
			rig.set_hand_model(String(it.id), m)
		for it: Dictionary in rig.loadout.items:
			if not String(it.kind) in DRAWABLE or rig.entries_of(String(it.id)).is_empty():
				continue
			for stance in ["stand", "crouch"]:
				var r := _run(rig, pid, String(it.id), stance)
				report.runs.append(r)
				worst.pop_ratio = maxf(worst.pop_ratio, float(r.worst_pop_ratio))
				worst.jump_cm = maxf(worst.jump_cm, float(r.max_jump_cm))
				worst.double += int(r.double_frames)
				worst.vanish += int(r.vanish_frames)
				worst.other_cm = maxf(worst.other_cm, float(r.other_max_step_cm))
		rig.free()
	report["worst"] = worst
	if args.has("out"):
		var f := FileAccess.open(String(args.out), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
		f.close()
	for r: Dictionary in report.runs:
		print("%-16s %-10s %-6s %-6s jump %5.1f cm  pop x%4.1f at %-18s double %d vanish %d  others %4.1f cm" % [r.preset, r.item, r.stance, r.clips,
				r.max_jump_cm, r.worst_pop_ratio, r.worst_pop_at, r.double_frames, r.vanish_frames, r.other_max_step_cm])
	print("HANDOFF REVIEW: %d runs; worst pop ratio %.1f, largest frame jump %.1f cm, double %d, vanish %d, other items' largest step %.1f cm" % [
			report.runs.size(), worst.pop_ratio, worst.jump_cm, worst.double, worst.vanish, worst.other_cm])
	quit(0)


func _pose(layers: Array) -> Array:
	poser.pose(layers)
	return body.skinning_globals()


func _run(rig: SlingRig, pid: String, id: String, stance: String) -> Dictionary:
	for it: Dictionary in rig.loadout.items:
		rig.snap_stowed(String(it.id))
	var es := rig.entries_of(id)
	var e: SlingRig.Entry = es[es.size() - 1]
	var dc := LoadoutDrawClips.new(e.ds, stance, poser)
	var base := "actor_b-p-crouch-idle" if stance == "crouch" else "actor_b-p-stealth-idle"
	var driven := dc.ok
	var hm: Node3D = rig.hand_models.get(id)
	var box := _local_box(hm)
	var dt := 1.0 / FPS
	var frames: Array = []   # [label, points(Array[Vector3]), others(Dictionary key->Vector3)]
	# settle the rig at the start pose (the yields and the layering blend)
	for k in 30:
		rig.update_now(dt, _pose([[base, 0.3]]))
	var take := e.shown - 1
	rig.begin_draw(id, {"driven": driven, "stance": stance})
	var draw_s := dc.draw_length() if driven else 1.0
	var n := int(ceil(draw_s / rig.rate * FPS)) + 20
	for k in n:
		var tn := minf(k * dt * rig.rate, draw_s)
		var layers: Array = [[base, 0.3]]
		if driven:
			layers.append_array(dc.draw_layers(tn))
		var g := _pose(layers)
		if driven:
			rig.drive(id, dc.draw_role(tn), dc.draw_phase(tn))
		rig.update_now(dt, g)
		frames.append(_sample(rig, e, take, hm, box, g))
	rig.begin_holster(id, {"driven": driven, "stance": stance})
	var hs := dc.equip_s if driven else 1.0
	# the put-away is the equip clip backwards, then the graph's holster_finish clip (as the preview plays
	# it when nothing follows); without it the arm would snap back to the base pose at the junction
	var fin := dc.finish if driven else ""
	var fs := poser.length(fin) if fin != "" else 0.0
	n = int(ceil((hs + fs) / rig.rate * FPS)) + 30
	for k in n:
		var tn := minf(k * dt * rig.rate, hs + fs)
		var layers: Array = [[base, 0.3]]
		if driven:
			layers.append_array(dc.holster_layers(tn if fin != "" else minf(tn, hs - 0.0005), fin))
		var g := _pose(layers)
		if driven:
			rig.drive(id, dc.holster_role(minf(tn, hs + 0.001)), dc.holster_phase(tn))
		rig.update_now(dt, g)
		frames.append(_sample(rig, e, take, hm, box, g))
	# analysis
	var res := {"preset": pid, "item": id, "stance": stance, "clips": "clips" if driven else "timer", "max_jump_cm": 0.0,
			"worst_pop_ratio": 0.0, "worst_pop_at": "", "double_frames": 0, "vanish_frames": 0, "other_max_step_cm": 0.0, "changes": []}
	for i in frames.size():
		var f: Dictionary = frames[i]
		if int(f.count) > 1:
			res.double_frames += 1
		if int(f.count) == 0:
			res.vanish_frames += 1
		if i == 0:
			continue
		var p: Dictionary = frames[i - 1]
		if int(f.count) == 1 and int(p.count) == 1:
			var step := _max_move(p.pts, f.pts)
			res.max_jump_cm = maxf(res.max_jump_cm, step * 100.0)
			if String(f.node) != String(p.node):
				var before := _max_move(frames[i - 2].pts, p.pts) if i >= 2 and int(frames[i - 2].count) == 1 else 0.0
				var after := _max_move(f.pts, frames[i + 1].pts) if i + 1 < frames.size() and int(frames[i + 1].count) == 1 else 0.0
				var ref := maxf(maxf(before, after), 0.005)
				var ratio := step / ref
				res.changes.append({"at": "%s->%s" % [p.node, f.node], "frame": i, "step_cm": snappedf(step * 100.0, 0.01),
						"before_cm": snappedf(before * 100.0, 0.01), "after_cm": snappedf(after * 100.0, 0.01)})
				if ratio > float(res.worst_pop_ratio):
					res.worst_pop_ratio = ratio
					res.worst_pop_at = "%s->%s" % [p.node, f.node]
		for key in f.others:
			if (p.others as Dictionary).has(key):
				res.other_max_step_cm = maxf(res.other_max_step_cm, ((f.others[key] as Vector3).distance_to(p.others[key])) * 100.0)
	if String(args.get("trace", "")) == "%s:%s:%s" % [pid, id, stance]:
		for i in range(1, frames.size()):
			var f: Dictionary = frames[i]
			var p: Dictionary = frames[i - 1]
			var step := _max_move(p.pts, f.pts) if int(f.count) == 1 and int(p.count) == 1 else -1.0
			var hstep := (f.hand as Vector3).distance_to(p.hand)
			print("  f%03d %-7s mode %-8s item step %6.1f cm  hand step %5.1f cm  item ang %5.1f deg  hand ang %5.1f deg  %s" % [i, f.node, f.mode, step * 100.0, hstep * 100.0,
					rad_to_deg((f.rot as Quaternion).angle_to(p.rot)), rad_to_deg((f.hrot as Quaternion).angle_to(p.hrot)), f.dbg])
	res.max_jump_cm = snappedf(res.max_jump_cm, 0.01)
	res.worst_pop_ratio = snappedf(res.worst_pop_ratio, 0.01)
	res.other_max_step_cm = snappedf(res.other_max_step_cm, 0.01)
	return res


## What shows of the item this frame: the visible node among the in-hand model, the moving copy and the
## stowed unit `take`, and its box corners in skeleton space; plus a reference point of every other
## entry's stowed copy (the stack settling).
func _sample(rig: SlingRig, e: SlingRig.Entry, take: int, hm: Node3D, box: Array, g: Array) -> Dictionary:
	var shown: Array = []
	if hm and hm.visible:
		shown.append(["hand", hm])
	if e.flyer and is_instance_valid(e.flyer) and e.flyer.visible:
		shown.append(["copy", e.flyer])
	if take >= 0 and take < e.units.size():
		var u: Node3D = e.units[take]
		if u.visible and e.holder.visible and e.root.visible:
			shown.append(["stowed", u])
	var pts: Array = []
	var node := ""
	var rot := Quaternion.IDENTITY
	if shown.size() >= 1:
		node = shown[0][0]
		var X := _skel_xf(shown[0][1], g)
		rot = X.basis.get_rotation_quaternion()
		for c: Vector3 in box:
			pts.append(X * c)
	var hand := (g[sk.find_bone(SlingRig.PROPS[e.hand])] as Transform3D).origin
	var hrot := (g[sk.find_bone(SlingRig.PROPS[e.hold])] as Transform3D).basis.get_rotation_quaternion()
	var others := {}
	for o: SlingRig.Entry in rig.entries:
		if o == e or o.holder == null:
			continue
		others[o.key] = _skel_xf(o.holder, g) * Vector3(0, 0, 0)
	return {"count": shown.size(), "node": node, "pts": pts, "others": others, "rot": rot, "hand": hand, "hrot": hrot, "dbg": "ph %.3f %s w %.3f gap %.1f cm  shown-vs-visual %.1f cm %.1f deg  unit %s" % [e.phase, e.role, rig._holster_weight(e) if e.mode == SlingRig.Mode.HOLSTER else rig._draw_weight(e), e.visual.origin.distance_to((e.world * e.last_unit).origin) * 100.0,
			(_skel_xf(shown[0][1], g).origin.distance_to(e.visual.origin) * 100.0) if shown.size() > 0 else -1.0,
			rad_to_deg(_skel_xf(shown[0][1], g).basis.get_rotation_quaternion().angle_to(e.visual.basis.get_rotation_quaternion())) if shown.size() > 0 else -1.0,
			str(e.last_unit.origin)], "mode": SlingRig.Mode.keys()[e.mode]}


func _max_move(a: Array, b: Array) -> float:
	var m := 0.0
	for i in mini(a.size(), b.size()):
		m = maxf(m, (a[i] as Vector3).distance_to(b[i]))
	return m


## Corners of the model's bounding box in its own frame (the moving copy, the in-hand model and the stowed
## unit are the same model).
func _local_box(m: Node3D) -> Array:
	var aabb := AABB()
	var first := true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != m:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb := xf * mi.mesh.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var out: Array = []
	for i in 8:
		out.append(aabb.get_endpoint(i))
	return out


func _skel_xf(n: Node3D, g: Array) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is BoneAttachment3D:
			return (g[sk.find_bone(String((cur as BoneAttachment3D).bone_name))] as Transform3D) * xf
		if cur == sk:
			return xf
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
