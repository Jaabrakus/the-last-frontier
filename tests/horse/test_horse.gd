extends SceneTree
## Horse checks (headless):
##
##   Godot --headless --path . -s tests/horse/test_horse.gd -- [out=/path/report.json] [contact=12] [skip_contact=1]
##
## 1. Asset: horse.glb has the socket bones, every clip with the rider clip's length, the
##    short-stride variants, a 14-14.2 hand horse (withers 1.42-1.47 m measured on the mesh)
##    and the rider attach point on its seat.
## 2. Gait clips (tools/horse/gait_check.py diagnostics in horse_meta.json, ground frame),
##    straight and curved (turning) variants: no stance slip, no hoof teleport, no skating (a
##    hoof within 1 cm of the ground moving), swing ends from the exact stance windows (mean
##    ground speed over the 1/30 s before touchdown well below the body speed: swing
##    retraction; the hoof comes down onto the ground, not skimming in), swing clearance and
##    no toe drag, no sinking, leg reach, neck lower and stretched at speed. Revision 4: the
##    hind legs' hip swing against the pelvis per gait, the pelvis motion, the export key
##    rate, and the playback check: the clip as the engine plays the exported keys (linear
##    interpolation), sampled at 240 Hz with the shipped hoof mesh, in the build (horse_meta
##    playback) and here in the engine (CPU-skinned Hooves mesh): hoof sinking and the drift
##    of hoof points that stay on the ground.
## 3. Per clip, Actor_B rider on the horse through HorseRiderLink (rider phase = horse phase):
##    - bounce phase: the saddle's vertical motion s(t) against the rider's pelvis relative
##      to the saddle u(t), phase of the vertical harmonic (k = bounces per clip); a
##      consistency check (the saddle curve is built from the rider bounce, horse.md 1.5);
##    - impact lag: the rider's sharpest pelvis drop against the nearest hoof touchdown
##      (consistency check: the footfalls were placed from the same rider clips);
##    - contact (CPU skinning of both meshes): seat gap between the breeches and the
##      saddle seat, penetration of the rider's legs / hands / coat into the horse and
##      tack, gap of the knees and calves to the horse, ball of the foot to the stirrup
##      tread (foot IK), the rider's face and hands against the neck and mane.
## 1b. Look: every surface has its material, the six coat variants apply, the triangle
##    budget, automatic LODs on the skin, and the baked coat textures decode with Godot's
##    tangent frame (normal-map / flow convention).
## 4. Controller: cruise speeds reached from below and from above, gait order, no slip zone
##    at any speed (throttle sweep and hard acceleration / braking), no interrupted
##    cross-fades, yaw rate against the turn radius per gait, planted-hoof skid in turns (with
##    the curved variants blended in), a real jump over a 0.7 m rail (root and collider leave
##    the ground, landing), jump at canter speed, stop, idle turn, rear, Alt walk restore,
##    mount points, rider-horse phase lock.
## Prints one line per check and HORSE TESTS PASSED / FAILED; writes a JSON report.

const Rig := preload("res://tests/horse/horse_test_rig.gd")
const CYCLES := {"idle": 1, "walk": 4, "trot": 2, "canter": 2, "gallop": 1, "sprint": 10}
const CLIPS := ["idle", "walk", "trot", "canter", "gallop", "sprint", "turn_l", "jump", "rear"]
const GAIT_DIAG := ["walk", "walk_s", "trot", "trot_s", "canter", "canter_s", "gallop", "gallop_s", "sprint", "turn_l",
		"jump", "rear", "walk_tl", "walk_tr", "walk_s_tl", "walk_s_tr", "trot_tl", "trot_tr", "trot_s_tl", "trot_s_tr",
		"canter_tl", "canter_tr", "canter_s_tl", "canter_s_tr", "gallop_tl", "gallop_tr", "gallop_s_tl", "gallop_s_tr",
		"sprint_tl", "sprint_tr"]
const SOCKET_BONES := ["root", "saddle", "passenger", "stirrup_l", "stirrup_r", "stirrup_iron_l", "stirrup_iron_r", "bit",
		"head", "hoof_l", "hhoof_r"]
const HOOVES := {"LF": "hoof_l", "RF": "hoof_r", "LH": "hhoof_l", "RH": "hhoof_r"}
const TOUCH_Y := 0.064        # coronet height (m) below which a hoof counts as down
const CELL := 0.04
const TACK := ["Saddle", "SaddleCloth", "Girth"]
const OCC := 0.01
## Clips where Actor_B stands in the stirrups (two-point seat), measured from the clips.
const TWO_POINT := ["gallop", "sprint", "jump"]
## Tolerances (see the report for the values).
const PHASE_TOL := 0.06       # fraction of a bounce cycle
const SEAT_PEN_TOL := 0.035   # m: breeches may sink this far into the padded seat
const SEAT_GAP_TOL := 0.04    # m: and float at most this high above it
const LEG_PEN_TOL := 0.03     # m
const FOOT_TOL := 0.02        # m ball joint to stirrup tread (after foot IK)
const HANDS_TOL := 0.04       # m
const FACE_GAP_MIN := 0.04    # m rider face / head to the horse's neck and mane
const WITHERS := Vector2(1.42, 1.47)
## Gait diagnostics (metres, m/s, ratios)
const SKATE_TOL := 0.2        # m/s: a hoof within 1 cm of the ground moves under 7 mm a frame
## Mean ground speed over the 1/30 s before touchdown / body speed, per gait (exact stance
## windows). Retraction brings a walking or trotting hoof nearly to rest before it lands; at
## the canter and gallop the leg's reach limits how far the hoof can be swung back, so it
## lands with some forward speed (a real galloping hoof slides a little on impact too).
## Revision 4: the realistic hind leg (hip swing capped, shorter than before) cannot swing
## the galloping hoof back as far, so it lands with more forward speed and a flatter approach.
const TD_RATIO_TOL := {"walk": 0.25, "trot": 0.25, "canter": 0.45, "gallop": 0.62, "sprint": 0.62, "jump": 0.85}
const TD_ANGLE_MIN := 18.0    # deg: the last 1/30 s before touchdown comes down onto the ground
const TD_ANGLE_MIN_FAST := 14.0   # deg, gallop, sprint and the jump landing
## Hind leg: largest swing of the femur against the pelvis (deg), sampled at 240 Hz (review:
## about 40 at the walk and trot, 60-70 at the gallop; a real horse 30-45 / 60-70).
const HIP_ROM_TOL := {"walk": 42.0, "trot": 45.0, "canter": 55.0, "gallop": 68.0, "sprint": 68.0}
## Pelvis pitch and roll range (deg, ground frame) at least, walk and trot (review: about
## +-3-4 deg pitch at the walk, +-2-3 deg with roll at the trot).
const PELVIS_MIN := {"walk": Vector2(5.0, 3.0), "trot": Vector2(4.0, 4.0)}
## Playback (exported keys, linear interpolation, 240 Hz, shipped hoof mesh)
const PLAY_SINK_TOL := 0.008  # m below the ground
const PLAY_DRIFT_TOL := 0.008 # m a hoof point that stays on the ground moves
## gallop, sprint and jump: the hoof lands with some forward speed (the swing cannot bring it
## to rest at 10-13 m/s), and slides about a centimetre on impact, as a real galloping hoof does
const PLAY_DRIFT_TOL_FAST := 0.015
const FAST_KEY_RATE := 110.0  # keys per second at least: trot, canter, gallop, sprint, jump
const DRAG_TOL := 0.02        # m of swing travel with the sole under 2 cm
const MID_CLEAR := 0.03       # m lowest sole height over mid-swing
const STRETCH_TOL := 1.02
const NECK_DROP := {"canter": 10.0, "gallop": 10.0, "sprint": 12.0}   # deg lower than idle, at least
## Controller
const CRUISE_TOL := 0.08
const SLIP_TOL := 0.02        # m/s |speed - rate x blended clip speed|
const RAIL_H := 0.7
const LOOK_TRI_BUDGET := 50000   ## LOD0 triangles of the whole horse with tack and hair
const SKID_TOL := 0.02        # extra ground speed of the toes on the ground in a full-steer turn, x the speed

var r
var fails := 0
var checks := 0
var report := {"clips": {}, "controller": {}, "checks": []}
var args := {}
var horse_sf := []
var mane_sf := []
var rider_sf := []
var saddle_map := {}
var tread := {}
var tread_model := {}
var tack_sf := []
## Rigid tack (saddle frame) as ray-parity occupancy: column (x, z) -> sorted y hits,
## row (y, z) -> sorted x hits, 1 cm spacing.
var occ_y := {}
var occ_x := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	r = Rig.new()
	await r.build(self, true)
	await physics_frame
	_asset_checks()
	_look_checks()
	horse_sf = Rig.horse_surfaces(r.horse, ["HorseBody"])
	mane_sf = Rig.horse_surfaces(r.horse, ["Mane", "Forelock"])
	tack_sf = Rig.horse_surfaces(r.horse, TACK)
	rider_sf = Rig.rider_surfaces(r.body, ["Clothes/breeches", "Clothes/leggings", "Clothes/shoe", "Body/skin",
			"Clothes/coat"])
	_build_saddle_map()
	_build_tack_occupancy()
	var socks: Dictionary = r.horse.meta.get("sockets", {})
	for s in ["l", "r"]:
		var a: Array = socks.get("stirrup_tread_" + s, [0, 0, 0])
		var att: Array = socks.get("saddle", [0, 1.37, 0])
		tread[s] = Vector3(a[0] - att[0], a[1] - att[1], a[2] - att[2])
		# the model is under the Visual node; skeleton space = model space
		tread_model[s] = Vector3(a[0], a[1], a[2])
	_gait_checks()
	_engine_playback()
	if args.get("skip_contact", "0") != "1":
		for c in CLIPS:
			report.clips[c] = _measure(c)
	await _controller()
	if args.get("skip_contact", "0") != "1":
		print("\nclip     bounce-err  impact-lag  seat-gap min/mean/max   legs-pen  knee/calf gap  foot-tread  IK corr  hands  face   coat")
		for c in CLIPS:
			var m: Dictionary = report.clips[c]
			var k: Dictionary = m.contact
			print("%-8s %7s ms %8s ms  %6.3f %6.3f %6.3f   %6.3f   %5.3f %5.3f    %5.3f     %5.3f   %5.3f  %5.3f  %5.3f" % [c,
					str(m.get("bounce_phase_error_ms", "-")), str(m.get("impact_lag_ms", "-")), k.seat_gap_min,
					k.seat_gap_mean, k.seat_gap_max, k.legs_max_pen, k.knee_gap, k.calf_gap, k.foot_to_tread_max,
					k.foot_ik_max, k.hands_max_pen, k.face_gap_min, k.coat_max_pen])
	var out: String = args.get("out", "user://horse_report.json")
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, " "))
		f.close()
		print("report: ", ProjectSettings.globalize_path(out))
	print("HORSE TESTS %s (%d/%d checks passed)" % ["PASSED" if fails == 0 else "FAILED", checks - fails, checks])
	quit(0 if fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("%s %s" % ["PASS" if ok else "FAIL", msg])
	report.checks.append({"ok": ok, "msg": msg})


# ---------------------------------------------------------------------------
## Look: materials, coat variants, triangle budget, LODs and the tangent-space convention
## of the baked coat textures.
func _look_checks() -> void:
	var h: Horse = r.horse
	var HL := Horse.HorseLook
	var unmapped := []
	var tris := {}
	var total := 0
	for mi: MeshInstance3D in h.visual.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null or not HL.MATERIALS.has(m.resource_name) or mi.get_surface_override_material(s) == null:
				unmapped.append("%s/%d" % [mi.name, s])
			var idx: PackedInt32Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			tris[String(mi.name)] = tris.get(String(mi.name), 0) + idx.size() / 3
			total += idx.size() / 3
	report["look_triangles"] = tris
	report["look_triangles_total"] = total
	_check(unmapped.is_empty(), "every surface has its horse / tack material (unmapped %s)" % [unmapped])
	_check(total <= LOOK_TRI_BUDGET and int(tris.get("HorseBody", 0)) <= 30000,
			"triangle budget: %d total (budget %d), skin %d, hair cards %d, tack %d" % [total, LOOK_TRI_BUDGET,
			int(tris.get("HorseBody", 0)), int(tris.get("Mane", 0)) + int(tris.get("Forelock", 0)) + int(tris.get("Tail", 0)) +
			int(tris.get("Feathers", 0)), total - int(tris.get("HorseBody", 0)) - int(tris.get("Mane", 0)) -
			int(tris.get("Forelock", 0)) - int(tris.get("Tail", 0)) - int(tris.get("Feathers", 0)) - int(tris.get("Hooves", 0)) -
			int(tris.get("Eyes", 0))])
	# automatic LODs of the skin (Godot import, meshes/generate_lods)
	var body: MeshInstance3D = h.visual.find_child("HorseBody", true, false)
	var surf: Dictionary = RenderingServer.mesh_get_surface(body.mesh.get_rid(), 0)
	var lods := []
	for l: Dictionary in surf.get("lods", []):
		lods.append(int((l.get("index_data", PackedByteArray()) as PackedByteArray).size() / (4 if surf.get("vertex_count", 0) > 65535 else 2) / 3))
	report["look_skin_lods"] = lods
	_check(lods.size() >= 2, "skin has automatic LODs: %s triangles" % [lods])
	# coat variants: per-instance parameters on the skin, hair and hooves
	var cbad := []
	for c: String in HL.COATS:
		h.coat = c
		var want: Dictionary = HL.COATS[c]
		var mane: MeshInstance3D = h.visual.find_child("Mane", true, false)
		var hooves: MeshInstance3D = h.visual.find_child("Hooves", true, false)
		if body.get_instance_shader_parameter("coat_body") != want.coat_body or \
				mane.get_instance_shader_parameter("hair_color") != want.hair_color or \
				hooves.get_instance_shader_parameter("hoof_dark") != want.hoof_dark:
			cbad.append(c)
	h.coat = "bay"
	_check(cbad.is_empty() and HL.COATS.size() == 6, "coat variants %s applied (failed %s)" % [HL.coats(), cbad])
	# tangent-space convention: the hair direction the bake stored at sample texels, decoded
	# with Godot's tangent frame (binormal = cross(normal, tangent) * w), matches the 3D
	# direction the bake meant (horse_meta.json look.texture_check)
	var samples: Array = h.meta.get("look", {}).get("texture_check", [])
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/horse/textures/horse_coat_flow.png"))
	var arr := body.mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var T: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
	var good := 0
	var angles := []
	for sm: Dictionary in samples:
		var p := Vector3(sm.p[0], sm.p[2], -float(sm.p[1]))
		var best := -1
		var bd := 1e9
		for i in V.size():
			var d := V[i].distance_squared_to(p)
			if d < bd:
				bd = d
				best = i
		var uv := Vector2(sm.uv[0], 1.0 - float(sm.uv[1]))
		var px := img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
				clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
		var t := Vector3(T[4 * best], T[4 * best + 1], T[4 * best + 2])
		var nrm := N[best]
		var bn := nrm.cross(t) * T[4 * best + 3]
		var f := (t * (px.r * 2.0 - 1.0) + bn * (px.g * 2.0 - 1.0)).normalized()
		var want := Vector3(sm.flow[0], sm.flow[2], -float(sm.flow[1]))
		var ang := rad_to_deg(f.angle_to(want))
		angles.append(snappedf(ang, 1.0))
		if ang < 30.0:
			good += 1
	report["look_texture_check_deg"] = angles
	_check(samples.size() >= 10 and good >= int(samples.size() * 0.8),
			"coat textures decode with Godot's tangent frame: %d / %d samples within 30 deg %s" % [good, samples.size(), angles])


func _asset_checks() -> void:
	var h: Horse = r.horse
	var missing := []
	for b in SOCKET_BONES:
		if h.skeleton.find_bone(b) < 0:
			missing.append(b)
	_check(missing.is_empty(), "horse.glb has socket / leg bones (missing %s), %d bones" % [missing, h.skeleton.get_bone_count()])
	var att := h.get_saddle_transform()
	_check(absf(att.origin.y - float(h.meta.attach_height)) < 0.002 and att.basis.is_equal_approx(h.visual.global_basis),
			"saddle attach rest at %.3f m (meta %.2f), axes = model axes" % [att.origin.y, float(h.meta.attach_height)])
	var bad := []
	for c: String in h.meta.clips:
		var info: Dictionary = h.meta.clips[c]
		if not h.anim_player.has_animation(c):
			bad.append(c + " missing")
			continue
		var L := h.anim_player.get_animation(c).length
		if absf(L - float(info.length)) > 0.5 / 30.0:
			bad.append("%s %.3f != %.3f" % [c, L, float(info.length)])
		var rc: String = Horse.RIDER_CLIPS.get(c, "")
		if not rc.is_empty() and r.link.has_clip(rc) and info.get("kind", "") != "rear":
			var Lr: float = r.link.rider_clip_length(rc)
			if c.begins_with("turn") or c == "idle":
				continue
			if absf(Lr - L) > 0.5 / 30.0:
				bad.append("%s %.3f vs rider %s %.3f" % [c, L, rc, Lr])
	_check(bad.is_empty(), "every horse clip present with the rider clip's length %s" % [bad])
	var rear_rider: String = Horse.RIDER_CLIPS.rear
	_check(r.link.has_clip(rear_rider), "rear rider clip %s available (tools/retarget prototype library)" % rear_rider)
	# short-stride variants: same timing as their gait clip, shorter stride
	var vbad := []
	for g in range(1, Horse.GAIT_CLIPS.size()):
		var sc: String = Horse.SHORT_CLIPS[g]
		if sc.is_empty():
			continue
		var gc: String = Horse.GAIT_CLIPS[g]
		var a: Dictionary = h.meta.clips.get(gc, {})
		var b: Dictionary = h.meta.clips.get(sc, {})
		if b.is_empty() or not h.anim_player.has_animation(sc) or absf(float(a.length) - float(b.length)) > 1e-3 \
				or float(b.design_speed) >= float(a.design_speed):
			vbad.append(sc)
	_check(vbad.is_empty(), "short-stride variants present with their gait's timing %s" % [vbad])
	# size: withers height measured on the skin mesh (rest), rider attach point on the seat
	var wy := -1.0
	for sf in Rig.horse_surfaces(h, ["HorseBody"]):
		for v in sf.v as PackedVector3Array:
			if absf(v.x) < 0.08 and v.z > 0.35 and v.z < 0.6:
				wy = maxf(wy, v.y)
	report["withers_mesh"] = snappedf(wy, 0.001)
	var inches := wy / 0.0254
	_check(wy >= WITHERS.x and wy <= WITHERS.y, "withers %.3f m = %d hands %.1f in (target 14-14.2 hh, %.2f-%.2f m); meta %.2f m" % [
			wy, int(inches / 4.0), inches - 4.0 * int(inches / 4.0), WITHERS.x, WITHERS.y, float(h.meta.get("withers_height", 0.0))])
	var sizes := {}
	for g in [Horse.Gait.WALK, Horse.Gait.TROT, Horse.Gait.CANTER, Horse.Gait.GALLOP, Horse.Gait.SPRINT]:
		sizes[Horse.GAIT_CLIPS[g]] = h.gait_band(g)
	report["gait_bands"] = var_to_str(sizes)
	print("gait no-slip bands (m/s): ", sizes)


func _gait_checks() -> void:
	var h: Horse = r.horse
	var idle_neck := float(h.meta.clips.idle.diagnostics.get("neck_elevation_deg", 0.0))
	var rows := {}
	for c: String in GAIT_DIAG:
		var d: Dictionary = h.meta.clips.get(c, {}).get("diagnostics", {})
		if d.is_empty():
			_check(false, "%s: gait diagnostics missing in horse_meta.json" % c)
			continue
		var v := float(d.get("ground_speed", 0.0))
		var td = d.get("td_speed_win")
		var ratio := float(td) / v if td != null and v > 0.5 else 0.0
		rows[c] = {"v": v, "slip": d.stance_slip, "frame_jump": d.frame_jump, "skate": d.skate,
				"touchdown_win": td, "td_ratio": snappedf(ratio, 0.01), "td_height": d.get("td_height_win"),
				"td_angle": d.get("td_angle_min"), "liftoff_win": d.get("lo_speed_win"),
				"touchdown_keyframe": d.touchdown_speed, "mid_min": d.swing_mid_min,
				"drag": d.swing_drag_m, "sink": d.sink, "stretch": d.stretch, "neck": d.neck_elevation_deg}
		var ok := float(d.stance_slip) <= 0.002 and float(d.skate) <= SKATE_TOL and float(d.swing_drag_m) <= DRAG_TOL \
				and float(d.sink) >= -0.003 and float(d.stretch) <= STRETCH_TOL + (0.01 if c == "jump" else 0.0)
		if c != "rear" and c != "jump":
			ok = ok and (d.swing_mid_min == null or float(d.swing_mid_min) >= MID_CLEAR)
		# teleport: no hoof moves more per frame than its swing needs (a minimum-jerk swing
		# peaks at 1.9x its mean speed: stride over swing time, plus the body speed)
		var info: Dictionary = h.meta.clips.get(c, {})
		var lim := 0.25
		if info.has("stride_length") and float(info.stride_length) > 0.0:
			var t_sw := (1.0 - maxf(float(info.duty[0]), float(info.duty[1]))) * float(info.stride_s)
			# the stride plus the lift (a short stride with a high lift and the hoof's
			# breakover roll moves the lowest point of the hoof further than the stride)
			lim = 2.4 * (float(info.stride_length) + 0.1) / t_sw / 30.0 + 0.03
		elif c == "jump":
			lim = 2.6 * v / 30.0 + 0.12
		var tele := float(d.frame_jump) <= lim
		_check(ok and tele, "%s gait (v %.2f m/s): stance slip %.4f m/frame, max hoof step %.3f m/frame (limit %.3f), skate %.2f m/s, " % [
				c, v, float(d.stance_slip), float(d.frame_jump), lim, float(d.skate)] +
				"swing mid clearance %s m, toe drag %.3f m, sink %.4f m, leg reach %.3f" % [
				str(d.swing_mid_min), float(d.swing_drag_m), float(d.sink), float(d.stretch)])
		var base := Horse.base_clip(c)
		if v > 1.0 and TD_RATIO_TOL.has(base):
			var ang := float(d.get("td_angle_min", 0.0))
			var amin := TD_ANGLE_MIN_FAST if base in ["gallop", "sprint", "jump"] else TD_ANGLE_MIN
			_check(ratio <= TD_RATIO_TOL[base] and ang >= amin,
					"%s: swing ends: over the 1/30 s before touchdown the hoof moves %.2f m/s = %.2f x body speed (limit %.2f; retraction) and comes down from %.3f m (approach %.0f deg); first 1/30 s after lift-off %.2f m/s" % [
					c, float(td), ratio, TD_RATIO_TOL[base], float(d.get("td_height_win", 0.0)), ang, float(d.get("lo_speed_win", 0.0))])
		var jr: Dictionary = d.get("joint_rom", {})
		if HIP_ROM_TOL.has(base) and not jr.is_empty() and not (c.ends_with("_tl") or c.ends_with("_tr")):
			_check(float(jr.hip) <= HIP_ROM_TOL[base], "%s: hind hip swing against the pelvis %.1f deg (limit %.0f; stifle %.0f, hock %.0f, fetlock %.0f deg)" % [
					c, float(jr.hip), HIP_ROM_TOL[base], float(jr.stifle), float(jr.hock), float(jr.fetlock)])
		var pb: Dictionary = d.get("playback", {})
		if not pb.is_empty():
			_check(float(pb.sink) <= PLAY_SINK_TOL and float(pb.drift) <= (PLAY_DRIFT_TOL_FAST if base in ["gallop", "sprint", "jump"] else PLAY_DRIFT_TOL),
					"%s playback (%.0f Hz keys, linear, sampled at 240 Hz, shipped hoof): sink %.4f m, ground-contact drift %.4f m, contact step speed median %.3f / p95 %.3f m/s" % [
					c, float(pb.key_rate), float(pb.sink), float(pb.drift), float(pb.slide_p50), float(pb.slide_p95)])
		if PELVIS_MIN.has(c):
			var pm: Vector2 = PELVIS_MIN[c]
			_check(float(d.get("pelvis_pitch_range", 0.0)) >= pm.x and float(d.get("pelvis_roll_range", 0.0)) >= pm.y,
					"%s: pelvis pitch range %.1f deg, roll range %.1f deg (ground frame; at least %.0f / %.0f)" % [
					c, float(d.get("pelvis_pitch_range", 0.0)), float(d.get("pelvis_roll_range", 0.0)), pm.x, pm.y])
		if NECK_DROP.has(c):
			var drop := idle_neck - float(d.neck_elevation_deg)
			_check(drop >= NECK_DROP[c] and drop <= 25.0, "%s: neck %.1f deg above the horizon, %.1f deg lower than idle (%.1f): lowered and stretched" % [
					c, float(d.neck_elevation_deg), drop, idle_neck])
	# export key rate of the fast gaits (review: 30 Hz keys let the hooves sink and slide
	# between keys)
	var kbad := []
	for c: String in h.meta.clips:
		var base := Horse.base_clip(c)
		if not (base in ["trot", "canter", "gallop", "sprint", "jump"]) or not h.anim_player.has_animation(c):
			continue
		var an := h.anim_player.get_animation(c)
		var most := 0
		for tr in an.get_track_count():
			most = maxi(most, an.track_get_key_count(tr))
		var rate_k := float(most - 1) / maxf(an.length, 1e-3)
		if rate_k < FAST_KEY_RATE:
			kbad.append("%s %.0f/s" % [c, rate_k])
	_check(kbad.is_empty(), "fast gaits and the jump keyed at %.0f+ keys per second in the imported glb %s" % [FAST_KEY_RATE, kbad])
	# walk hind swing: lifted early and clear (review: hind hooves dragging)
	var wl: Dictionary = h.meta.clips.walk.diagnostics.legs
	for leg in ["LH", "RH"]:
		var L: Dictionary = wl[leg]
		_check(float(L.swing_peak) >= 0.10 and float(L.swing_peak_at) <= 0.45 and float(L.swing_drag_m) <= DRAG_TOL,
				"walk %s swing: peak %.3f m at s %.2f, drag %.3f m" % [leg, float(L.swing_peak), float(L.swing_peak_at), float(L.swing_drag_m)])
	report["gait_diagnostics"] = rows


## The clips as the engine plays them (revision 4): the imported glb animation (its keys,
## interpolated by the AnimationPlayer) sampled at 240 Hz through force_clip, the Hooves mesh
## CPU-skinned, in the ground frame (straight clips: the ground moves back at the clip speed;
## the jump's root lift is applied by force_clip): the deepest hoof point below the ground,
## and how far a hoof point that stays on the ground drifts from where it touched down.
func _engine_playback() -> void:
	var h: Horse = r.horse
	var sfs := Rig.horse_surfaces(h, ["Hooves"])
	if sfs.is_empty():
		_check(false, "engine playback: no Hooves mesh")
		return
	# the lower part of each hoof only (the rest cannot reach the ground)
	var full: Dictionary = sfs[0]
	var sv: PackedVector3Array = full.v
	var nb: int = full.nb
	var keep := PackedInt32Array()
	for i in sv.size():
		if sv[i].y < 0.03:
			keep.append(i)
	var v2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var b2 := PackedInt32Array()
	var w2 := PackedFloat32Array()
	for i in keep:
		v2.append(sv[i])
		n2.append((full.n as PackedVector3Array)[i])
		for k in nb:
			b2.append((full.bo as PackedInt32Array)[i * nb + k])
			w2.append((full.w as PackedFloat32Array)[i * nb + k])
	var sf := {"v": v2, "n": n2, "bo": b2, "w": w2, "nb": nb, "bind": full.bind}
	var rows := {}
	for c in ["walk", "trot", "canter", "gallop", "sprint", "jump"]:
		var info: Dictionary = h.meta.clips.get(c, {})
		var L := float(info.get("length", 1.0))
		var vel := float(info.get("design_speed", 0.0))
		var n := int(round(minf(L, 1.2) * 240.0))
		var start := {}
		var sink := 0.0
		var drift := 0.0
		for i in n + 1:
			var t := float(i) / 240.0
			h.force_clip(c, t / L)
			var P: PackedVector3Array = Rig.skin_horse(h, sf)[0]
			for k in P.size():
				var p := P[k]
				var gy := p.y - h.global_position.y
				var g := Vector2(p.x, p.z - vel * t)
				sink = maxf(sink, -gy)
				if gy < 0.005:
					if start.has(k):
						drift = maxf(drift, g.distance_to(start[k]))
					else:
						start[k] = g
				else:
					start.erase(k)
		rows[c] = {"sink": snappedf(sink, 0.0001), "drift": snappedf(drift, 0.0001)}
		var dtol := PLAY_DRIFT_TOL_FAST if c in ["gallop", "sprint", "jump"] else PLAY_DRIFT_TOL
		_check(sink <= PLAY_SINK_TOL and drift <= dtol, "%s in the engine (glb keys, 240 Hz, Hooves mesh): hoof sink %.4f m, ground-contact drift %.4f m (limit %.3f; includes the landing slide)" % [
				c, sink, drift, dtol])
	h.force_clip("idle", 0.0)
	report["engine_playback"] = rows


# ---------------------------------------------------------------------------
func _attach_inv() -> Transform3D:
	return r.horse.get_saddle_transform().affine_inverse()


func _rider_bone(name: String) -> Vector3:
	var sk: Skeleton3D = r.rider_sk
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin


func _build_saddle_map() -> void:
	r.pose("idle", 0.0)
	var inv := _attach_inv()
	for sf in tack_sf:
		if sf.name != "Saddle":
			continue
		var P: PackedVector3Array = Rig.skin_horse(r.horse, sf)[0]
		for p in P:
			var q := inv * p
			var key := Vector2i(roundi(q.x / 0.01), roundi(q.z / 0.01))
			saddle_map[key] = maxf(saddle_map.get(key, -9.0), q.y)


func _build_tack_occupancy() -> void:
	r.pose("idle", 0.0)
	var inv := _attach_inv()
	var ntri := 0
	for sf in tack_sf:
		var P: PackedVector3Array = Rig.skin_horse(r.horse, sf)[0]
		var mi: MeshInstance3D = r.horse.visual.find_child(sf.name, true, false)
		var idx: PackedInt32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var Q := PackedVector3Array()
		for p in P:
			Q.append(inv * p)
		for t in idx.size() / 3:
			var a := Q[idx[3 * t]]
			var b := Q[idx[3 * t + 1]]
			var c := Q[idx[3 * t + 2]]
			ntri += 1
			_rasterize(a, b, c, 0, 2, 1, occ_y)   # vertical rays: columns (x, z), hits in y
			_rasterize(a, b, c, 1, 2, 0, occ_x)   # lateral rays: rows (y, z), hits in x
	for d in [occ_y, occ_x]:
		for k in d:
			var arr: PackedFloat32Array = d[k]
			arr.sort()
			d[k] = arr
	print("tack occupancy: %d triangles, %d columns, %d rows" % [ntri, occ_y.size(), occ_x.size()])


## Intersects the lines along axis `w` through the grid points (u, v) with triangle abc.
static func _rasterize(a: Vector3, b: Vector3, c: Vector3, u: int, v: int, w: int, out: Dictionary) -> void:
	var u0 := ceili(minf(a[u], minf(b[u], c[u])) / OCC)
	var u1 := floori(maxf(a[u], maxf(b[u], c[u])) / OCC)
	var v0 := ceili(minf(a[v], minf(b[v], c[v])) / OCC)
	var v1 := floori(maxf(a[v], maxf(b[v], c[v])) / OCC)
	var den := (b[v] - c[v]) * (a[u] - c[u]) + (c[u] - b[u]) * (a[v] - c[v])
	if absf(den) < 1e-12:
		return
	for iu in range(u0, u1 + 1):
		for iv in range(v0, v1 + 1):
			var pu := iu * OCC
			var pv := iv * OCC
			var l1 := ((b[v] - c[v]) * (pu - c[u]) + (c[u] - b[u]) * (pv - c[v])) / den
			var l2 := ((c[v] - a[v]) * (pu - c[u]) + (a[u] - c[u]) * (pv - c[v])) / den
			var l3 := 1.0 - l1 - l2
			if l1 < 0.0 or l2 < 0.0 or l3 < 0.0:
				continue
			var key := Vector2i(iu, iv)
			var arr: PackedFloat32Array = out.get(key, PackedFloat32Array())
			arr.append(l1 * a[w] + l2 * b[w] + l3 * c[w])
			out[key] = arr


## Depth of q inside the rigid tack (0 when outside): the smaller of the vertical and
## the lateral depth, both from ray parity.
func _tack_depth(q: Vector3) -> float:
	var dy := _parity_depth(occ_y, Vector2i(roundi(q.x / OCC), roundi(q.z / OCC)), q.y)
	if dy <= 0.0:
		return 0.0
	var dx := _parity_depth(occ_x, Vector2i(roundi(q.y / OCC), roundi(q.z / OCC)), q.x)
	return minf(dy, dx) if dx > 0.0 else 0.0


static func _parity_depth(d: Dictionary, key: Vector2i, x: float) -> float:
	if not d.has(key):
		return 0.0
	var arr: PackedFloat32Array = d[key]
	var i := 0
	while i + 1 < arr.size():
		if x > arr[i] and x < arr[i + 1]:
			return minf(x - arr[i], arr[i + 1] - x)
		i += 2
	return 0.0


func _saddle_height(x: float, z: float) -> float:
	var best := -9.0
	var cx := roundi(x / 0.01)
	var cz := roundi(z / 0.01)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			best = maxf(best, saddle_map.get(Vector2i(cx + dx, cz + dz), -9.0))
	return best


func _measure(clip: String) -> Dictionary:
	var h: Horse = r.horse
	var info: Dictionary = h.meta.clips.get(clip, {})
	var frames := int(info.get("frames", 31))
	var L := float(info.get("length", 1.0))
	var loops: bool = info.get("loop", false)
	var n := frames - 1 if loops else frames
	var step := maxi(1, n / 140)
	var ts: Array[float] = []
	var s_y: Array[float] = []
	var u_y: Array[float] = []
	var world_pelvis: Array[float] = []
	var cor := {}
	for leg in HOOVES:
		cor[leg] = []
	for i in range(0, n, step):
		var ph := float(i) / float(frames - 1)
		r.pose(clip, ph)
		var att: Transform3D = h.get_saddle_transform()
		var pel := _rider_bone("pelvis")
		ts.append(ph * L)
		s_y.append(att.origin.y)
		u_y.append((att.affine_inverse() * pel).y)
		world_pelvis.append(pel.y)
		for leg in HOOVES:
			cor[leg].append(h.get_bone_global(HOOVES[leg]).origin.y)
	var res := {"length": L, "frames": frames, "samples": ts.size(), "rider_clip": h.rider_clip()}
	res.saddle_p2p = _p2p(s_y)
	res.rider_rel_pelvis_p2p = _p2p(u_y)
	res.rider_world_pelvis_p2p = _p2p(world_pelvis)
	# touchdowns (times) per leg
	var td := {}
	for leg in HOOVES:
		var ys: Array = cor[leg]
		var lst := []
		for i in ys.size():
			var prev: float = ys[(i - 1 + ys.size()) % ys.size()] if loops else (ys[i - 1] if i > 0 else 9.0)
			if ys[i] < TOUCH_Y and prev >= TOUCH_Y:
				lst.append(snappedf(ts[i], 0.001))
		td[leg] = lst
	res.touchdowns = td
	if loops and CYCLES.has(clip) and clip != "idle":
		var k: int = CYCLES[clip]
		var ps := _harmonic_phase(s_y, k)
		var pu := _harmonic_phase(u_y, k)
		var err := wrapf(ps - pu, -PI, PI) / TAU
		var cyc := L / k
		res.bounce_phase_error_cycles = snappedf(err, 0.0001)
		res.bounce_phase_error_ms = snappedf(err * cyc * 1000.0, 0.1)
		res.saddle_harmonic_amp = snappedf(_harmonic_amp(s_y, k), 0.0001)
		res.rider_harmonic_amp = snappedf(_harmonic_amp(u_y, k), 0.0001)
		# impact: steepest pelvis drop relative to the saddle, vs the last touchdown before it
		var best := 0
		var best_d := 1e9
		for i in u_y.size():
			var d: float = u_y[(i + 1) % u_y.size()] - u_y[(i - 1 + u_y.size()) % u_y.size()]
			if d < best_d:
				best_d = d
				best = i
		var t_imp := ts[best]
		var lag := 1e9
		var who := ""
		for leg in td:
			for t0: float in td[leg]:
				var dl := fposmod(t_imp - t0, cyc)
				if dl > cyc * 0.5:
					dl -= cyc
				if absf(dl) < absf(lag):
					lag = dl
					who = leg
		res.impact_time = snappedf(t_imp, 0.001)
		res.impact_lag_ms = snappedf(lag * 1000.0, 0.1) if who != "" else null
		res.impact_nearest_touchdown = who
		_check(absf(err) <= PHASE_TOL, "%s: saddle bounce vs rider bounce phase error %.3f cycle (%.0f ms), amp saddle %.3f rider %.3f" % [
				clip, err, err * cyc * 1000.0, res.saddle_harmonic_amp, res.rider_harmonic_amp])
	res.contact = _contact(clip, frames, L, loops)
	var c: Dictionary = res.contact
	if clip in TWO_POINT:
		# the rider rises out of the saddle (two-point seat): only no sinking into it
		_check(c.seat_gap_min >= -SEAT_PEN_TOL,
				"%s: seat gap %.3f .. %.3f m (mean %.3f; two-point seat, hovering is authored)" % [
					clip, c.seat_gap_min, c.seat_gap_max, c.seat_gap_mean])
	else:
		_check(c.seat_gap_min >= -SEAT_PEN_TOL and c.seat_gap_max <= SEAT_GAP_TOL,
				"%s: seat gap (breeches - saddle seat) %.3f .. %.3f m (mean %.3f)" % [clip, c.seat_gap_min, c.seat_gap_max, c.seat_gap_mean])
	_check(c.legs_max_pen <= LEG_PEN_TOL,
			"%s: legs into horse/tack max %.3f m (%s), %.1f%% of leg vertices > 1 cm; knee gap %.3f m, calf gap %.3f m; hands %.3f; coat skirt %.3f (info)" % [
				clip, c.legs_max_pen, c.legs_worst, c.legs_pen_pct, c.knee_gap, c.calf_gap, c.hands_max_pen, c.coat_max_pen])
	_check(c.hands_max_pen <= HANDS_TOL, "%s: rider hands into the horse's neck max %.3f m" % [clip, c.hands_max_pen])
	_check(c.face_gap_min >= FACE_GAP_MIN, "%s: rider face / head to the horse's neck and mane min %.3f m (%s)" % [
			clip, c.face_gap_min, c.face_worst])
	if clip != "rear":
		_check(c.foot_to_tread_max <= FOOT_TOL, "%s: ball of foot on the stirrup tread (fixed leathers + foot IK): mean %.3f max %.3f m, IK moved the foot up to %.3f m" % [
				clip, c.foot_to_tread_mean, c.foot_to_tread_max, c.foot_ik_max])
	return res


func _contact(clip: String, frames: int, L: float, loops: bool) -> Dictionary:
	var n := int(args.get("contact", "12"))
	if clip == "rear":
		n = int(n * 1.5)
	var seat_min := 1e9
	var seat_max := -1e9
	var seat_sum := 0.0
	var legs_pen := 0.0
	var legs_worst := ""
	var pen_count := 0
	var leg_count := 0
	var hands_pen := 0.0
	var coat_pen := 0.0
	var knee_gap := 1e9
	var calf_gap := 1e9
	var foot_sum := 0.0
	var foot_max := 0.0
	var foot_n := 0
	var ik_max := 0.0
	var face_gap := 1e9
	var face_worst := ""
	var per_frame := []
	var pen_by := {}
	for j in n:
		var ph := float(j) / float(n) if loops else float(j) / float(n - 1)
		r.pose(clip, ph)
		var inv := _attach_inv()
		# horse vertices near the rider into a hash (attach frame)
		var grid := {}
		var flank := PackedVector3Array()
		var HP := PackedVector3Array()
		var HN := PackedVector3Array()
		var HS := PackedInt32Array()
		var si := -1
		# neck, head and mane ahead of the rider (face clearance), 0.1 m cells
		var fgrid := {}
		var FP := PackedVector3Array()
		var FN := PackedVector3Array()
		for sf in horse_sf + mane_sf:
			si += 1
			var pn: Array = Rig.skin_horse(r.horse, sf)
			var P: PackedVector3Array = pn[0]
			var N: PackedVector3Array = pn[1]
			var is_skin: bool = si < horse_sf.size()
			for i in P.size():
				var q := inv * P[i]
				if q.z > 0.05 and q.y > -0.45 and absf(q.x) < 0.4:
					var fk := Vector3i(floori(q.x / 0.1), floori(q.y / 0.1), floori(q.z / 0.1))
					var fc: PackedInt32Array = fgrid.get(fk, PackedInt32Array())
					fc.append(FP.size())
					fgrid[fk] = fc
					FP.append(q)
					FN.append(inv.basis * N[i])
				if not is_skin or absf(q.x) > 0.6 or q.y < -1.0 or q.y > 0.5 or absf(q.z) > 1.1:
					continue
				var idx := HP.size()
				HP.append(q)
				HN.append(inv.basis * N[i])
				HS.append(si)
				var key := Vector3i(floori(q.x / CELL), floori(q.y / CELL), floori(q.z / CELL))
				var cell: PackedInt32Array = grid.get(key, PackedInt32Array())
				cell.append(idx)
				grid[key] = cell   # packed arrays are values: store the appended copy
				if absf(q.x) > 0.12 and q.y < 0.0:
					flank.append(q)
		for sf in tack_sf:
			for p in Rig.skin_horse(r.horse, sf)[0] as PackedVector3Array:
				var q := inv * p
				if absf(q.x) > 0.12 and q.y < 0.0 and q.y > -1.0:
					flank.append(q)
		var head := inv * _rider_bone("heada")
		ik_max = maxf(ik_max, maxf(r.link.foot_correction[0], r.link.foot_correction[1]))
		var palm := [inv * _rider_bone("l_palm"), inv * _rider_bone("r_palm")]
		var frame_seat := 1e9
		var sub := 0
		for sf in rider_sf:
			var P2: PackedVector3Array = Rig.skin_rider(r.body, r.rider_sk, sf)[0]
			var part: String = sf.name
			for p in P2:
				var q := inv * p
				if part == "Body/skin":
					if q.distance_to(head) < 0.2:
						sub += 1
						if sub % 3 == 0:
							var fg := _face_dist(fgrid, FP, FN, q)
							if fg < face_gap:
								face_gap = fg
								face_worst = "face y%.2f z%.2f @%.2f" % [q.y, q.z, ph]
						continue
					if q.distance_to(palm[0]) > 0.12 and q.distance_to(palm[1]) > 0.12:
						continue
				# hugging: inner knee (breeches, low and wide) and calf (leggings, mid height)
				if (part == "Clothes/breeches" and q.y < -0.12 and absf(q.x) > 0.18) or \
						(part == "Clothes/leggings" and q.y < -0.30 and q.y > -0.50):
					sub += 1
					if sub % 3 == 0:
						var g2 := _min_dist(flank, q)
						if part == "Clothes/breeches":
							knee_gap = minf(knee_gap, g2)
						else:
							calf_gap = minf(calf_gap, g2)
				var td_ := _tack_depth(q)
				if td_ > 0.0:
					match part:
						"Clothes/coat":
							coat_pen = maxf(coat_pen, td_)
						"Body/skin":
							hands_pen = maxf(hands_pen, td_)
						_:
							if td_ > 0.01:
								pen_count += 1
								pen_by["tack"] = pen_by.get("tack", 0) + 1
							if td_ > legs_pen:
								legs_pen = td_
								legs_worst = "%s y%.2f x%.2f z%.2f into tack @%.2f" % [part.get_slice("/", 1), q.y, q.x,
										q.z, ph]
				var near3 := _nearest3(grid, HP, q)
				var hit: int = near3[0]
				if part == "Clothes/breeches" and absf(q.x) < 0.10 and absf(q.z) < 0.10:
					var hs := _saddle_height(q.x, q.z)
					if hs > -5.0:
						frame_seat = minf(frame_seat, q.y - hs)
				if hit < 0:
					continue
				# signed distance from the nearest vertex; on thin decimated tack the nearest
				# vertex can sit on the far face, so the sign is the vote of the 3 nearest
				var d := (q - HP[hit]).dot(HN[hit])
				var votes := 0
				for k in near3:
					if k >= 0 and (q - HP[k]).dot(HN[k]) < 0.0:
						votes += 1
				if votes < 2:
					d = absf(d)
				var dist := q.distance_to(HP[hit])
				match part:
					"Clothes/coat":
						coat_pen = maxf(coat_pen, -d)
					"Body/skin":
						hands_pen = maxf(hands_pen, -d)
					_:
						leg_count += 1
						if d < -0.01:
							pen_count += 1
						if -d > legs_pen:
							legs_pen = -d
							legs_worst = "%s y%.2f x%.2f z%.2f into %s @%.2f" % [part.get_slice("/", 1), q.y, q.x, q.z,
									horse_sf[HS[hit]].name, ph]
						if d < -0.01:
							pen_by[horse_sf[HS[hit]].name] = pen_by.get(horse_sf[HS[hit]].name, 0) + 1
		if frame_seat < 1e8:
			seat_min = minf(seat_min, frame_seat)
			seat_max = maxf(seat_max, frame_seat)
			seat_sum += frame_seat
		per_frame.append(snappedf(frame_seat, 0.001))
		for s in ["l", "r"]:
			var ball := inv * _rider_bone(s + "_ball")
			var sb: int = r.horse.skeleton.find_bone("stirrup_iron_" + s)
			var tr_w: Vector3 = r.horse.skeleton.global_transform * (r.horse.skeleton.get_bone_global_pose(sb) * \
					(r.horse.skeleton.get_bone_global_rest(sb).affine_inverse() * tread_model[s]))
			var dd := ball.distance_to(inv * tr_w + Vector3(0, HorseRiderLink.SOLE, 0))
			foot_sum += dd
			foot_max = maxf(foot_max, dd)
			foot_n += 1
	return {"samples": n, "seat_gap_min": snappedf(seat_min, 0.001), "seat_gap_max": snappedf(seat_max, 0.001),
			"seat_gap_mean": snappedf(seat_sum / maxf(per_frame.size(), 1), 0.001), "seat_gap_per_sample": per_frame,
			"legs_max_pen": snappedf(legs_pen, 0.001), "legs_worst": legs_worst,
			"legs_pen_pct": snappedf(100.0 * pen_count / maxf(leg_count, 1), 0.1), "legs_pen_by_surface": pen_by,
			"knee_gap": snappedf(knee_gap, 0.001), "calf_gap": snappedf(calf_gap, 0.001),
			"hands_max_pen": snappedf(hands_pen, 0.001), "coat_max_pen": snappedf(coat_pen, 0.001),
			"face_gap_min": snappedf(minf(face_gap, 0.1), 0.001), "face_worst": face_worst,
			"foot_ik_max": snappedf(ik_max, 0.001),
			"foot_to_tread_mean": snappedf(foot_sum / maxf(foot_n, 1), 0.001), "foot_to_tread_max": snappedf(foot_max, 0.001)}


## Signed distance (m, negative inside) from q to the nearest neck / head / mane vertex
## within 0.1 m (0.1 when none is that close).
static func _face_dist(fgrid: Dictionary, FP: PackedVector3Array, FN: PackedVector3Array, q: Vector3) -> float:
	var c := Vector3i(floori(q.x / 0.1), floori(q.y / 0.1), floori(q.z / 0.1))
	var bd := 0.01
	var best := -1
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var key := c + Vector3i(dx, dy, dz)
				if not fgrid.has(key):
					continue
				for i in fgrid[key] as PackedInt32Array:
					var d2 := q.distance_squared_to(FP[i])
					if d2 < bd:
						bd = d2
						best = i
	if best < 0:
		return 0.1
	return sqrt(bd) if (q - FP[best]).dot(FN[best]) >= 0.0 else -sqrt(bd)


static func _min_dist(pts: PackedVector3Array, q: Vector3) -> float:
	var bd := 1e9
	for p in pts:
		bd = minf(bd, q.distance_squared_to(p))
	return sqrt(bd)


## Indices of the 3 nearest horse vertices within 8 cm (-1 where missing), nearest first.
func _nearest3(grid: Dictionary, HP: PackedVector3Array, q: Vector3) -> Array:
	var c := Vector3i(floori(q.x / CELL), floori(q.y / CELL), floori(q.z / CELL))
	var best := [-1, -1, -1]
	var bd := [0.0064, 0.0064, 0.0064]
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for dz in range(-2, 3):
				var key := c + Vector3i(dx, dy, dz)
				if not grid.has(key):
					continue
				for idx in grid[key] as PackedInt32Array:
					var d2 := q.distance_squared_to(HP[idx])
					if d2 < bd[2]:
						if d2 < bd[0]:
							best = [idx, best[0], best[1]]
							bd = [d2, bd[0], bd[1]]
						elif d2 < bd[1]:
							best = [best[0], idx, best[1]]
							bd = [bd[0], d2, bd[1]]
						else:
							best[2] = idx
							bd[2] = d2
	return best


static func _p2p(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	return snappedf(a.max() - a.min(), 0.0001)


static func _harmonic_phase(a: Array[float], k: int) -> float:
	var re := 0.0
	var im := 0.0
	var n := a.size()
	for i in n:
		var ang := TAU * k * i / n
		re += a[i] * cos(ang)
		im -= a[i] * sin(ang)
	return atan2(im, re)


static func _harmonic_amp(a: Array[float], k: int) -> float:
	var re := 0.0
	var im := 0.0
	var n := a.size()
	for i in n:
		var ang := TAU * k * i / n
		re += a[i] * cos(ang)
		im -= a[i] * sin(ang)
	return 2.0 * sqrt(re * re + im * im) / n


# ---------------------------------------------------------------------------
func _controller() -> void:
	var h: Horse = r.horse
	h.force_clip("")
	h.global_position = Vector3.ZERO
	h.rotation = Vector3.ZERO
	var rep := {}
	var seq := []
	var cb := func(_o: int, n_: int) -> void:
		seq.append(Horse.GAIT_CLIPS[n_])
	h.gait_changed.connect(cb)
	var st := {"slip_max": 0.0, "slip_at": "", "phase_err": 0.0}
	# let the fade out of the last forced pose (contact checks) finish before counting
	h.drive(0.0, 0.0)
	await _run(60, st)
	var fades0: int = h.blender.interrupted_fades
	# cruise per gait from a stand, then the sprint
	for g in [Horse.Gait.WALK, Horse.Gait.TROT, Horse.Gait.CANTER, Horse.Gait.GALLOP]:
		h.set_cruise_gait(g)
		h.drive(1.0, 0.0)
		await _run(600, st)
		var ok: bool = h.gait == g and absf(h.speed - Horse.CRUISE[g]) < CRUISE_TOL
		_check(ok, "cruise %s: gait %s at %.2f m/s (cruise %.1f), clip %s rate %.2f, full stride %.2f" % [
				Horse.GAIT_CLIPS[g], Horse.GAIT_CLIPS[h.gait], h.speed, Horse.CRUISE[g], h.clip, h.rate, h.stride_w])
		rep["cruise_" + Horse.GAIT_CLIPS[g]] = {"gait": Horse.GAIT_CLIPS[h.gait], "speed": snappedf(h.speed, 0.01),
				"rate": snappedf(h.rate, 0.001), "stride_w": snappedf(h.stride_w, 0.001)}
	_check(h.speed > 10.0 and h.speed > 5.6 * 1.75, "gallop cruise %.1f m/s is clearly faster than the player's 5.6 m/s sprint" % h.speed)
	h.drive(Horse.CRUISE[Horse.Gait.SPRINT] / Horse.CRUISE[Horse.Gait.GALLOP], 0.0)
	await _run(480, st)
	_check(h.gait == Horse.Gait.SPRINT and absf(h.speed - Horse.CRUISE[Horse.Gait.SPRINT]) < CRUISE_TOL,
			"sprint throttle reaches %s at %.2f m/s (rate %.2f)" % [Horse.GAIT_CLIPS[h.gait], h.speed, h.rate])
	rep.cruise_sprint = {"speed": snappedf(h.speed, 0.01), "rate": snappedf(h.rate, 0.001)}
	rep.gait_sequence_up = seq.duplicate()
	_check(seq == ["walk", "trot", "canter", "gallop", "sprint"], "gait changes going up in order without flicker: %s" % [seq])
	# hard braking from the sprint to a stand (S held)
	seq.clear()
	h.drive(-1.0, 0.0)
	await _run(600, st)
	rep.gait_sequence_down = seq.duplicate()
	_check(h.gait == Horse.Gait.IDLE and h.speed < 0.01 and seq == ["gallop", "canter", "trot", "walk", "idle"],
			"hard braking to a stand in order: %s (%.2f m/s)" % [seq, h.speed])
	# every cruise gait is also reached from the gait above (the cruise speeds lie outside
	# the up / down shift hysteresis)
	var from_above := {}
	var fa_ok := true
	for g in [Horse.Gait.WALK, Horse.Gait.TROT, Horse.Gait.CANTER, Horse.Gait.GALLOP]:
		h.set_cruise_gait(g + 1)
		h.drive(1.0, 0.0)
		await _run(480, st)
		h.set_cruise_gait(g)
		await _run(480, st)
		var ok_g: bool = h.gait == g and absf(h.speed - Horse.CRUISE[g]) < CRUISE_TOL
		fa_ok = fa_ok and ok_g
		from_above[Horse.GAIT_CLIPS[g]] = "%s %.2f m/s" % [Horse.GAIT_CLIPS[h.gait], h.speed]
	rep.cruise_from_above = from_above
	_check(fa_ok, "cruise gaits reached from the gait above: %s" % [from_above])
	# throttle sweep at every cruise gait: the planted hooves never slide at any speed
	var sweep := []
	for g in [Horse.Gait.WALK, Horse.Gait.TROT, Horse.Gait.CANTER, Horse.Gait.GALLOP]:
		h.set_cruise_gait(g)
		for thr in [0.15, 0.35, 0.55, 0.75, 0.9]:
			h.drive(thr, 0.0)
			await _run(240, st)
			sweep.append([snappedf(h.speed, 0.01), Horse.GAIT_CLIPS[h.gait], snappedf(h.rate, 0.01), snappedf(h.stride_w, 0.01)])
	rep.throttle_sweep = sweep
	h.drive(0.0, 0.0)
	await _run(600, st)
	var rbad := []
	var rates: Dictionary = st.get("rates", {})
	for gname: String in rates:
		var rv: Vector2 = rates[gname]
		var lo := 0.65 if gname == "walk" else 0.85
		var hi := 1.08 if gname == "sprint" else 1.15
		if rv.x < lo - 1e-3 or rv.y > hi + 1e-3:
			rbad.append("%s %.2f-%.2f" % [gname, rv.x, rv.y])
	rep.rate_ranges = var_to_str(rates)
	_check(rbad.is_empty() and not rates.is_empty(), "rider clip rate within 0.85-1.15 (walk from 0.65, sprint to 1.08) over cruise, braking and the throttle sweep: %s %s" % [
			rates, rbad])
	_check(st.slip_max <= SLIP_TOL, "no slip zone: max |speed - rate x stride speed| %.4f m/s over cruise, sprint, braking and a throttle sweep of %d speeds (%s)" % [
			st.slip_max, sweep.size(), st.slip_at])
	rep.slip_max = st.slip_max
	var fades: int = h.blender.interrupted_fades - fades0
	_check(fades == 0, "no gait cross-fade interrupted by the next change (%d%s), min gait dwell %.2f s" % [fades,
			(": " + h.blender.last_interrupt) if fades > 0 else "", Horse.MIN_DWELL])
	_check(st.phase_err < 0.5 / 30.0, "consistency: the rider clip time follows the horse phase (max error %.4f s)" % st.phase_err)
	rep.rider_phase_lock_max_error_s = st.phase_err
	# yaw rate per gait against the turn radius, and planted-hoof skid in the turn
	var turns := {}
	for g in [Horse.Gait.WALK, Horse.Gait.TROT, Horse.Gait.CANTER, Horse.Gait.GALLOP]:
		h.set_cruise_gait(g)
		h.drive(1.0, 0.0)
		await _run(420, st)
		var base: Dictionary = await _turn_skid(120)
		var y0 := h.rotation.y
		h.drive(1.0, 1.0)
		await _run(60, st)
		y0 = h.rotation.y
		var skid: Dictionary = await _turn_skid(120)
		var yr := rad_to_deg(wrapf(h.rotation.y - y0, -PI, PI)) / 1.0
		var want := rad_to_deg(h.max_yaw_rate(g, h.speed))
		var radius := h.speed / maxf(deg_to_rad(yr), 1e-3)
		var rmin := h.min_turn_radius(g, 0.0)
		turns[Horse.GAIT_CLIPS[g]] = {"speed": snappedf(h.speed, 0.01), "yaw_deg_s": snappedf(yr, 0.1), "radius_m": snappedf(radius, 0.01),
				"radius_min_m": rmin, "curve_weight": snappedf(h.curve, 0.01), "hoof_skid_m_s": skid,
				"hoof_speed_running_straight_m_s": base}
		var extra := float(skid.mean) - float(base.mean)
		_check(absf(yr - want) < 2.0 and radius >= rmin - 0.05 and extra <= SKID_TOL * h.speed,
				"%s full steer at %.2f m/s: %.1f deg/s (limit %.1f), turn radius %.2f m (min %.1f), curved variants at %.2f; toes on the ground move %.3f m/s mean (%.3f running straight: +%.1f %% of the speed; the straight clips alone would skid them sideways at up to %.2f m/s)" % [
				Horse.GAIT_CLIPS[g], h.speed, yr, want, radius, rmin, h.curve, float(skid.mean), float(base.mean),
				100.0 * extra / h.speed, float(skid.straight)])
		h.drive(1.0, 0.0)
		await _run(60, st)
	rep.turns = turns
	# jump over a 0.7 m rail at the gallop, requested well before it
	h.drive(0.0, 0.0)
	await _run(600, st)
	h.global_position = Vector3.ZERO
	h.rotation = Vector3.ZERO
	var fence := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(6.0, 0.08, 0.08)
	cs.shape = bx
	fence.add_child(cs)
	var post := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(6.0, RAIL_H - 0.04, 0.02)
	post.shape = pb
	post.position = Vector3(0, -(RAIL_H - 0.04) * 0.5 - 0.04, 0)
	fence.add_child(post)
	fence.position = Vector3(0, RAIL_H - 0.04, -45.0)
	r.world.add_child(fence)
	h.set_cruise_gait(Horse.Gait.GALLOP)
	h.drive(1.0, 0.0)
	var jr := {"requested": false, "started_at": 0.0, "max_root_y": 0.0, "v0": 0.0, "v_after": 0.0, "landed": false,
			"feet_max_y": 0.0, "start_speed": 0.0, "rate": 0.0}
	h.landed.connect(func(_p: Vector3) -> void: jr.landed = true)
	var sp_prev := h.speed
	jr["max_dv"] = 0.0
	for i in 1500:
		await physics_frame
		if h._jump_pending > 0.0 or h.one_shot == "jump":
			jr.max_dv = maxf(jr.max_dv, absf(h.speed - sp_prev))
		sp_prev = h.speed
		var dz := -h.global_position.z
		if not jr.requested and dz > 45.0 - 9.0:
			jr.requested = h.request_jump()
		if h.one_shot == "jump" and jr.started_at == 0.0:
			jr.started_at = 45.0 - dz
			jr.start_speed = h.speed
			jr.rate = h.jump_rate
		jr.max_root_y = maxf(jr.max_root_y, h.global_position.y)
		jr.feet_max_y = maxf(jr.feet_max_y, h._feet_shape.position.y - h._feet_r)
		if dz > 52.0:
			break
	jr.v_after = h.speed
	jr["end_z"] = -h.global_position.z
	r.world.remove_child(fence)
	fence.queue_free()
	rep.jump = jr
	_check(float(jr.max_dv) <= (Horse.JUMP_ADJUST + 0.5) / Engine.physics_ticks_per_second,
			"jump approach: the speed is brought into the jump band gradually (largest change %.3f m/s per tick, %.1f m/s^2)" % [
			float(jr.max_dv), float(jr.max_dv) * Engine.physics_ticks_per_second])
	_check(jr.requested and jr.max_root_y > 0.12 and jr.landed and jr.end_z > 47.0 and jr.v_after > 0.85 * jr.start_speed,
			"jump over a %.1f m rail: started %.2f m before it at %.2f m/s (rate %.2f), root rose %.2f m, feet collider %.2f m, landed %s, past the rail at %.2f m/s" % [
			RAIL_H, jr.started_at, jr.start_speed, jr.rate, jr.max_root_y, jr.feet_max_y, str(jr.landed), jr.v_after])
	# the jump from a canter speed: the clip slows to the jump band and the arc is higher
	h.drive(0.0, 0.0)
	await _run(600, st)
	h.set_cruise_gait(Horse.Gait.CANTER)
	h.drive(1.0, 0.0)
	await _run(360, st)
	var jc := {"ok": h.request_jump()}
	var t_j := 0
	var ymax := 0.0
	while (h.one_shot == "jump" or h._jump_pending > 0.0) and t_j < 600:
		await physics_frame
		t_j += 1
		ymax = maxf(ymax, h.global_position.y)
	jc["rate"] = h.jump_rate
	jc["root_apex"] = ymax
	jc["predicted"] = h.jump_root_lift(0.605, h.jump_rate)
	rep.jump_canter = jc
	_check(jc.ok and absf(ymax - jc.predicted) < 0.03, "canter jump: rate %.2f, root apex %.3f m (clip arc %.3f m)" % [
			jc.rate, ymax, jc.predicted])
	# stop
	seq.clear()
	h.drive(0.0, 0.0)
	await _run(900, st)
	_check(h.gait == Horse.Gait.IDLE and h.speed < 0.01, "stops to idle (%s, %.2f m/s); down shifts %s" % [
			Horse.GAIT_CLIPS[h.gait], h.speed, seq])
	# idle turn in place
	h.drive(0.0, 1.0)
	await _run(120, st)
	var y1 := h.rotation.y
	await _run(240, st)
	var idle_rate := rad_to_deg(wrapf(h.rotation.y - y1, -PI, PI)) / 2.0
	_check(h.clip == "turn_l" and absf(idle_rate - 22.5) < 2.0 and h.speed < 0.01,
			"idle turn: clip %s at %.1f deg/s (turn clip baked for 22.5)" % [h.clip, idle_rate])
	rep.idle_turn_rate = snappedf(idle_rate, 0.1)
	h.drive(0.0, 0.0)
	await _run(60, st)
	# rear
	var reared := h.request_rear()
	var rt := 0
	var moved := 0.0
	var p0 := h.global_position
	while h.one_shot == "rear" and rt < 700:
		await physics_frame
		rt += 1
		moved = maxf(moved, h.global_position.distance_to(p0))
	_check(reared and absf(rt / 120.0 - 4.0) < 0.05 and moved < 0.05, "rear one-shot %.2f s, drift %.3f m" % [rt / 120.0, moved])
	# Alt walk: held -> walk, released -> the cruise gait from before
	HorseInput.ensure()
	h.set_cruise_gait(Horse.Gait.CANTER)
	h.player_input = true
	Input.action_press("walk")
	await _run(3, st)
	var during := h.cruise_gait
	Input.action_release("walk")
	await _run(3, st)
	var after := h.cruise_gait
	h.player_input = false
	_check(during == Horse.Gait.WALK and after == Horse.Gait.CANTER, "Alt walk: cruise %s while held, %s after release" % [
			Horse.GAIT_CLIPS[during], Horse.GAIT_CLIPS[after]])
	# mount points
	var att := h.get_saddle_transform()
	var ml := h.get_mount_point(Horse.LEFT)
	var local := h.visual.global_transform.affine_inverse() * ml.origin
	var face := ml.basis.z
	var to_horse := (Vector3(att.origin.x, ml.origin.y, att.origin.z) - ml.origin).normalized()
	_check(absf(local.x - 0.69) < 0.01 and absf(local.z - 0.18) < 0.01 and absf(ml.origin.y - h.global_position.y) < 0.02 and face.dot(to_horse) > 0.9,
			"mount point left: model (%.2f, %.2f, %.2f), faces the flank (dot %.2f)" % [local.x, local.y, local.z, face.dot(to_horse)])
	var side := h.nearest_mount_side(ml.origin + Vector3(0.2, 0, 0))
	_check(side == Horse.LEFT, "nearest mount side from the left point = LEFT (%d)" % side)
	report.controller = rep


## Runs n physics frames, tracking the worst slip between the body speed and the clip's
## no-slip speed (rate x blended stride speed) and the rider phase lock.
func _run(n: int, st: Dictionary) -> void:
	var h: Horse = r.horse
	for i in n:
		await physics_frame
		if not h.one_shot.is_empty() or h.gait == Horse.Gait.IDLE:
			continue
		var g := h.gait
		var vl := h.clip_speed(Horse.GAIT_CLIPS[g])
		var sc: String = Horse.SHORT_CLIPS[g]
		var vs := h.clip_speed(sc) if not sc.is_empty() else vl
		var clip_v := h.rate * (vs + h.stride_w * (vl - vs))
		var slip := absf(h.speed - clip_v)
		if h.clip != Horse.GAIT_CLIPS[g]:
			slip = 0.0      # the clip switches on the next tick
		else:
			var rr: Dictionary = st.get("rates", {})
			var key: String = Horse.GAIT_CLIPS[g]
			var cur: Vector2 = rr.get(key, Vector2(INF, -INF))
			rr[key] = Vector2(minf(cur.x, h.rate), maxf(cur.y, h.rate))
			st["rates"] = rr
		if slip > st.slip_max:
			st.slip_max = slip
			st.slip_at = "%s v %.2f rate %.2f w %.2f" % [Horse.GAIT_CLIPS[g], h.speed, h.rate, h.stride_w]
		var rl: float = r.link.rider_clip_length(h.rider_clip())
		var at: float = r.link.blender.active_time()
		if r.link.blender.active_clip() == HorseRiderLink.full_clip(h.rider_clip()):
			var d := absf(at / rl - h.phase)
			st.phase_err = maxf(st.phase_err, minf(d, 1.0 - d) * rl)


## Toe (front of the sole) of each hoof, global.
func _toes() -> Dictionary:
	var h: Horse = r.horse
	var sk := h.skeleton
	var out := {}
	var tt: Dictionary = h.meta.get("sockets", {}).get("hoof_toes", {})
	for leg in tt:
		var b := sk.find_bone(String(tt[leg][0]))
		var a: Array = tt[leg][1]
		out[leg] = sk.global_transform * (sk.get_bone_global_pose(b) * (sk.get_bone_global_rest(b).affine_inverse() * Vector3(a[0], a[1], a[2])))
	return out


## Ground speed (m/s) of the planted hooves while turning: per frame the worst horizontal
## speed of a toe that is on the ground (< 1 cm) at both ends of the frame, as the mean and
## the maximum over n frames; plus the lateral skid the straight clips alone would have
## (the yaw rate times the toe's distance ahead of or behind the root).
func _turn_skid(n: int) -> Dictionary:
	var h: Horse = r.horse
	var prev := {}
	var worst := 0.0
	var acc := 0.0
	var cnt := 0
	var straight := 0.0
	for i in n:
		await physics_frame
		var fr := 0.0
		var toes := _toes()
		for leg in toes:
			var p: Vector3 = toes[leg]
			if prev.has(leg) and p.y - h.global_position.y < 0.01 and prev[leg].y - h.global_position.y < 0.01:
				var d: Vector3 = p - prev[leg]
				fr = maxf(fr, Vector2(d.x, d.z).length() * Engine.physics_ticks_per_second)
			prev[leg] = p
			var ahead := (p - h.global_position).dot(-h.global_basis.z)
			straight = maxf(straight, absf(h.yaw_speed * ahead))
		worst = maxf(worst, fr)
		acc += fr
		cnt += 1
	return {"mean": snappedf(acc / maxf(cnt, 1), 0.001), "max": snappedf(worst, 0.001), "straight": snappedf(straight, 0.01)}
