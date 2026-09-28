extends SceneTree
## Penetration of the stowed items (SlingRig, every preset, every item on the body) into the skinned body,
## the limbs and each other over the surveyed poses:
##
##   Godot --headless --path . -s tests/loadout/test_stow_penetration.gd -- [out=/abs/report.json] [samples=6]
##   (about 1-2 min; run it under a hard time limit)
##
## Exit 0 and "STOW PENETRATION TEST OK" when every check passes.
##
## Method = the design survey's (tools/loadout/measure_body_fit.gd): the 70 clips of its CLIPS list (idle,
## walk, run, sprint, crouch, aim, throw, carry, reload, jump, land, vault, climb, ladder, ledge), the same
## samples per clip, partial clips over the same bases; the outer surface of the legacy outfit (Clothes and
## Gear, torso rows, outward normals, the old horn left out) skinned with the helper bones driven
## (CharacterBodyMesh.skinning_globals()); signed distance = median plane distance of the 5 nearest outer
## vertices; limb capsules = the survey's (body_fit.json radii). The item capsules are carry_gear.json's
## capsules_bind carried by the RUNTIME placement of each copy (bulk, back layering, two-anchor, the yield
## to limbs and back items, solved per sample like the survey).
##
## Thresholds (loadout_design.md "How to read the clearances" and design_fit_check.json):
##   - body surface and limbs, per placement and group (locomotion, crouch, weapon use, traversal): no worse
##     than the design's own measured value for that placement and group minus 1 cm (design_fit_check.json
##     placements.*.groups), i.e. the runtime keeps what the design measured; a value that is still clean
##     (>= -1 cm) always passes. Traversal clips run in the rig's traversal state and are held to the
##     design's residual after that item's traversal policy (carry_gear.json points.*.traversal);
##     An arm (forearm or hand) swinging over an item that hangs on the belt is held to the design's
##     accepted worst case instead (-7.5 cm, loadout_design.md 2.1: "accept a brief sleeve-over-butt
##     overlap"; the item yields on its hook);
##   - item against item, in play clips (locomotion, crouch, weapon use): back items over back items (rigid
##     on the same bone) >= -1 cm (clean); every other pair >= the contact limit (-3.5 cm) or, where the
##     design's own pair gap was already worse, no worse than that minus 1 cm. Traversal pairs are reported.
## The limb check leaves out the clip meant to reach the item (design_fit_check.json
## placements.*.expected_reach_clips_excluded, and the bow nock reach for items behind the right shoulder).

const LIMBS := {
	"r_upper_arm": ["r_shoulder", "r_elbow"], "r_forearm": ["r_elbow", "r_wrist"], "r_hand": ["r_wrist", "r_middlea"],
	"l_upper_arm": ["l_shoulder", "l_elbow"], "l_forearm": ["l_elbow", "l_wrist"], "l_hand": ["l_wrist", "l_middlea"],
	"r_thigh": ["r_upper_leg", "r_knee"], "r_shin": ["r_knee", "r_ankle"], "l_thigh": ["l_upper_leg", "l_knee"],
	"l_shin": ["l_knee", "l_ankle"], "head": ["neck", "headb"],
}
const LIMB_TRIM := {"r_thigh": 0.25, "l_thigh": 0.25}
const GROUPS := {"idle": "locomotion", "walk": "locomotion", "run": "locomotion", "sprint": "locomotion", "crouch": "crouch",
		"aim": "weapon_use", "throw": "weapon_use", "carry": "weapon_use", "reload": "weapon_use", "jump": "traversal",
		"land": "traversal", "vault": "traversal", "climb": "traversal", "ladder": "traversal", "ledge": "traversal"}
const REACH_BEHIND_R_SHOULDER := ["actor_b-p-bow-reload--part"]
const TOL_CM := 1.0
const CLEAN_CM := -1.0
const CONTACT_CM := -3.5
## An arm swinging over an item hanging on the belt (it yields on its hook, sleeve over wood): the
## design's accepted worst case (loadout_design.md 2.1, the right-hip pistol in walk-fw, -7.5 cm).
const ARM_OVER_HANGING_CM := -7.5
const ARM_LIMBS := ["r_forearm", "r_hand", "l_forearm", "l_hand"]

var _fails: Array[String] = []
var _checks := 0
var args := {}
var sk: Skeleton3D
var body: CharacterBodyMesh
var poser: LoadoutClipPoser
var surf: SlingBodySurface
var limb_r := {}
var bi := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var t0 := Time.get_ticks_msec()
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	poser = LoadoutClipPoser.new(sk, ap)
	poser.in_place = false
	await process_frame
	await process_frame
	for b in sk.get_bone_count():
		bi[sk.get_bone_name(b)] = b
	var data := LoadoutData.get_default()
	limb_r = data.limb_radii()
	surf = SlingBodySurface.from_body(body)
	var fit := data.fit()
	var clips := _clip_list()
	var rigs := {}
	for pid in data.preset_ids():
		var rig := SlingRig.new()
		root.add_child(rig)
		rig.setup(sk, body, Loadout.from_preset(String(pid)), {"auto": false})
		for it: Dictionary in rig.loadout.items:
			rig.snap_stowed(String(it.id))
		rigs[String(pid)] = rig
	var worst := {}   # pid -> key -> group -> {surf: [cm, clip], limb: [cm, limb, clip]}
	var pairs := {}   # pid -> "a | b" -> {play: [cm, clip], trav: [cm, clip]}
	var n_samples := 0
	var per := int(args.get("samples", "6"))
	for spec: Array in clips:
		var clip: String = spec[0]
		var cat: String = spec[1]
		var grp: String = GROUPS.get(cat, "locomotion")
		var L := poser.length(clip)
		if L <= 0.0:
			continue
		var n := 1 if L < 0.05 else mini(per, maxi(2, int(round(L / 0.1)) + 1))
		for j in n:
			var t := L * j / maxf(1.0, float(n - 1)) if n > 1 else 0.0
			var layers: Array = []
			if String(spec[2]) != "":
				layers.append([spec[2], 0.0])
				layers.append([clip, t, "partial"])
			else:
				layers.append([clip, t])
			poser.pose(layers)
			var g := body.skinning_globals()
			surf.skin_all(g)
			var segs := _segs(g)
			n_samples += 1
			for pid: String in rigs:
				var rig: SlingRig = rigs[pid]
				# the runtime state policy of the move (loadout_design.md 6.5): traversal clips run in the
				# rig's traversal state (push / swing / yield per item), everything else standing
				var want := "traversal" if grp == "traversal" else "stand"
				if rig.state != want:
					rig.set_state(want)
				rig.update_now(0.0, g)
				var posed := {}
				for e: SlingRig.Entry in rig.entries:
					if e.shown <= 0:
						continue
					var caps := rig.caps_at(e, e.world)
					posed[e.key] = caps
					var s_cl := INF
					for c: Array in caps:
						for k in 5:
							var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 4.0)
							s_cl = minf(s_cl, float(surf.sdist(p)[0]) - float(c[2]))
					var excl: Array = fit.get("placements", {}).get(e.key, {}).get("expected_reach_clips_excluded", [])
					var skip_limbs := excl.has(clip) or (e.point in ["quiver", "long_B"] and REACH_BEHIND_R_SHOULDER.has(clip))
					var l_cl := INF
					var l_name := ""
					if not skip_limbs:
						for ln: String in segs:
							for c: Array in caps:
								var d := float(SlingRig._closest_seg_seg(c[0], c[1], segs[ln][0], segs[ln][1])[0]) - float(c[2]) - float(limb_r.get(ln, 0.05))
								if d < l_cl:
									l_cl = d
									l_name = ln
					_keep(worst, pid, e.key, grp, s_cl, l_cl, l_name, clip)
				var keys := posed.keys()
				for a in keys.size():
					for b in range(a + 1, keys.size()):
						var ka: String = keys[a]
						var kb: String = keys[b]
						var d := INF
						for ca: Array in posed[ka]:
							for cb: Array in posed[kb]:
								d = minf(d, float(SlingRig._closest_seg_seg(ca[0], ca[1], cb[0], cb[1])[0]) - float(ca[2]) - float(cb[2]))
						var pk := _pair_key(ka, kb)
						if not pairs.has(pid):
							pairs[pid] = {}
						if not pairs[pid].has(pk):
							pairs[pid][pk] = {}
						var cls := "trav" if grp == "traversal" else "play"
						if not pairs[pid][pk].has(cls) or d < float(pairs[pid][pk][cls][0]):
							pairs[pid][pk][cls] = [d, clip]
	var report := _judge(worst, pairs, fit, rigs)
	report["samples"] = n_samples
	report["clips"] = clips.size()
	report["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	if args.has("out"):
		var f := FileAccess.open(String(args.out), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, " "))
			f.close()
	print("penetration: %d clips, %d samples, %d presets, %.0f s" % [clips.size(), n_samples, rigs.size(), report.seconds])
	for pid: String in rigs:
		(rigs[pid] as SlingRig).free()
	if _fails.is_empty():
		print("STOW PENETRATION TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		print("STOW PENETRATION TEST FAILED (%d of %d checks)" % [_fails.size(), _checks])
		quit(1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)


func _segs(g: Array) -> Dictionary:
	var out := {}
	for ln: String in LIMBS:
		var a := (g[int(bi[LIMBS[ln][0]])] as Transform3D).origin
		var b := (g[int(bi[LIMBS[ln][1]])] as Transform3D).origin
		out[ln] = [a.lerp(b, float(LIMB_TRIM.get(ln, 0.0))), b]
	return out


static func _pair_key(a: String, b: String) -> String:
	return "%s | %s" % [a, b] if a < b else "%s | %s" % [b, a]


func _keep(worst: Dictionary, pid: String, key: String, grp: String, s: float, l: float, ln: String, clip: String) -> void:
	if not worst.has(pid):
		worst[pid] = {}
	if not worst[pid].has(key):
		worst[pid][key] = {}
	var w: Dictionary = worst[pid][key]
	if not w.has(grp):
		w[grp] = {"surf": [INF, ""], "limb": [INF, "", ""]}
	if s < float(w[grp].surf[0]):
		w[grp].surf = [s, clip]
	if l < float(w[grp].limb[0]):
		w[grp].limb = [l, ln, clip]


## The survey's clip list (tools/loadout/measure_body_fit.gd CLIPS): [clip, category, base].
func _clip_list() -> Array:
	var src := "res://tools/loadout/measure_body_fit.gd"
	var out: Array = []
	var text := FileAccess.get_file_as_string(src)
	var start := text.find("const CLIPS := [")
	var end := text.find("]\n## Extra clip sets", start)
	if start < 0 or end < 0:
		push_warning("could not read the survey clip list; using a short list")
		return [["actor_b-p-stealth-idle", "idle", ""], ["actor_b-p-run-fw", "run", ""], ["actor_b-p-crouch-idle", "crouch", ""]]
	var re := RegEx.new()
	re.compile("\\[\"([^\"]+)\", \"([^\"]+)\", \"([^\"]*)\", \"([^\"]*)\"\\]")
	for m in re.search_all(text.substr(start, end - start)):
		if _disabled_move_clip(m.get_string(1)):
			continue
		out.append([m.get_string(1), m.get_string(2), m.get_string(3)])
	return out


## Clips of the traversal moves the player keeps disabled until they are fixed
## (Player_Animation_Project/graph_analysis/traversal/READY_FOR_INTEGRATION.md: climb_hang_3m,
## gap_jumps / long_jump, wall_shimmy, squeeze): the player never plays them, so the carried gear is not
## judged on them.
const DISABLED_MOVE_CLIPS := ["-3m^ledge-hang", "ledge-hang", "long-jump", "gap-jump", "shimmy", "squeeze"]


static func _disabled_move_clip(clip: String) -> bool:
	for k: String in DISABLED_MOVE_CLIPS:
		if clip.contains(k):
			return true
	return false


func _design_pair(fit: Dictionary, a: String, b: String) -> Dictionary:
	var pg: Dictionary = fit.get("pair_gaps", {})
	for k in ["%s | %s" % [a, b], "%s | %s" % [b, a]]:
		if pg.has(k):
			return pg[k]
	return {}


func _judge(worst: Dictionary, pairs: Dictionary, fit: Dictionary, rigs: Dictionary) -> Dictionary:
	var rep := {"placements": {}, "pairs": {}, "tolerance_cm": TOL_CM}
	var pl: Dictionary = fit.get("placements", {})
	for pid: String in worst:
		rep.placements[pid] = {}
		for key: String in worst[pid]:
			var d: Dictionary = pl.get(key, {}).get("groups", {})
			var out := {}
			for grp: String in worst[pid][key]:
				var w: Dictionary = worst[pid][key][grp]
				var s_cm := float(w.surf[0]) * 100.0
				var l_cm := float(w.limb[0]) * 100.0 if float(w.limb[0]) < INF else 99.0
				var ds := float(d.get(grp, {}).get("surface_cm", -99.0))
				var dl := float(d.get(grp, {}).get("limb_cm", -99.0))
				if grp == "traversal":
					# traversal: the design's residual after the item's traversal policy (carry_gear.json
					# points.*.traversal.residual_cm, loadout_design.md 6.5), for surface and limbs alike
					var kk := key.split(".")
					var tr: Dictionary = LoadoutData.get_default().point(kk[0], kk[1]).get("traversal", {})
					if tr.has("residual_cm"):
						ds = minf(ds, float(tr.residual_cm))
						dl = minf(dl, float(tr.residual_cm))
				out[grp] = {"surface_cm": snappedf(s_cm, 0.1), "surface_clip": w.surf[1], "design_surface_cm": ds,
						"limb_cm": snappedf(l_cm, 0.1), "limb": w.limb[1], "limb_clip": w.limb[2], "design_limb_cm": dl}
				# no worse than the design measured (1 cm tolerance), and never fail a value that is still clean
				_check(s_cm >= minf(ds - TOL_CM, CLEAN_CM), "%s %s %s: surface %.1f cm (design %.1f) at %s" % [pid, key, grp, s_cm, ds, w.surf[1]])
				var l_lim := minf(dl - TOL_CM, CLEAN_CM)
				var kk := key.split(".")
				var hanging := float(LoadoutData.get_default().point(kk[0], kk[1]).get("yield_deg", 0.0)) > 0.0 or kk[1] == "powder_horn"
				if hanging and ARM_LIMBS.has(String(w.limb[1])):
					l_lim = minf(l_lim, ARM_OVER_HANGING_CM)
				out[grp]["limb_limit_cm"] = snappedf(l_lim, 0.1)
				_check(l_cm >= l_lim, "%s %s %s: limb %.1f cm %s (design %.1f, limit %.1f) at %s" % [pid, key, grp, l_cm, w.limb[1], dl, l_lim, w.limb[2]])
			rep.placements[pid][key] = out
	for pid: String in pairs:
		rep.pairs[pid] = {}
		var rig: SlingRig = rigs[pid]
		var layer := {}
		for e: SlingRig.Entry in rig.entries:
			layer[e.key] = LoadoutData.layer_of(e.point)
		for pk: String in pairs[pid]:
			var ab := pk.split(" | ")
			var p: Dictionary = pairs[pid][pk]
			var play_cm := float(p.get("play", [INF, ""])[0]) * 100.0
			var trav_cm := float(p.get("trav", [INF, ""])[0]) * 100.0
			var dp := _design_pair(fit, ab[0], ab[1])
			var d_play := float(dp.get("loco", {}).get("gap_cm", 99.0))
			var both_back := int(layer.get(ab[0], 0)) > 0 and int(layer.get(ab[1], 0)) > 0
			# Two back items: no worse than the design measured either (user decision 2026-09-25: the gear
			# rests on the back, "none of the back gear is on the back, it floats above it"; the back
			# layering lifts an item at most SlingRig.layer_max_lift_m, so crossing items may overlap as
			# much as the design's own placement had them, e.g. bow | quiver -6.3 cm).
			var limit := minf(CLEAN_CM, d_play - TOL_CM) if both_back else minf(CONTACT_CM, d_play - TOL_CM)
			rep.pairs[pid][pk] = {"play_cm": snappedf(play_cm, 0.1), "play_clip": p.get("play", [0, ""])[1], "trav_cm": snappedf(trav_cm, 0.1),
					"trav_clip": p.get("trav", [0, ""])[1], "design_play_cm": d_play, "limit_cm": snappedf(limit, 0.1), "both_back": both_back}
			_check(play_cm >= limit, "%s %s: items %.1f cm apart at worst (limit %.1f, design %.1f) at %s" % [pid, pk, play_cm, limit, d_play, p.get("play", [0, ""])[1]])
	return rep
