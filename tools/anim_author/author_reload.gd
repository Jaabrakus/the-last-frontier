extends SceneTree
## The flintlock musket's whole reload, this project's own animation (user 2026-09-28/29: "we need to create a new
## reload animation for ramrod and etc what musket would be like"; the ramrod worked "right hand on the tip of the gun"
## with the gun in the other hand, standing, walking or crouched; "make the animation the same time as the reload
## timer", the timer "like 6.3s"; "the right arm is too straight when ramrodding"), posed by
## tools/anim_author/pose_solver.gd from the musket's own geometry (tools/models/musket.py), one clip for each of
## Musket.reload_stages' five steps, on the cues of their sounds (WeaponAudio RELOAD["musket"], scaled to the steps'
## seconds). Times below are seconds into the reload (6.3 s):
##   bite    0.0  the gun brought down to the priming position at the right side (the lock at the breast, the pan up,
##                the muzzle forward and up, the left hand under the forestock); the right thumb half-cocks and flicks
##                the frizzen open (0.25); the hand to the cartridge pouch at the right hip (0.39), a cartridge up to the
##                mouth and bitten (0.73), torn away
##   prime   1.0  powder shaken into the pan (1.11 .. 1.45); the frizzen pulled shut (1.64); the gun cast about (1.9):
##                raised upright in the left hand and let down slanted across the front, the left hand sliding up the
##                barrel (leaning out to the left, the butt out low; the muzzle before the right side of the chest)
##   pour    2.2  the cartridge over the muzzle, the powder poured (2.36 .. 2.75), the ball and the paper pressed in
##                (3.17); the right hand takes the ramrod's head and draws it in tugs (3.3)
##   ram     3.6  drawn out, turned end for end, three strokes down the bore (4.22, 4.57, 4.91), tugged up out of it
##   return  5.3  out of the bore, turned back, pushed home down its pipes; the right hand lets go and drops to the wrist
##                of the stock as the left raises the gun upright before him, sliding down the barrel; brought down
##                across the chest to the carry (the thumb full-cocks it at 6.11: MusketReload)
## The right fist holds the rod thumb down the barrel throughout (a hammer grip: it rams down, and the rod turned end
## for end spins in the fingers: the hand never flips over), and works close to the right shoulder (the elbow bent).
## Two of each: standing (walking too) and crouched ("-crouch": the game's kneel; the gun lower and flatter, its butt
## by the ground, swept about the butt when it is cast about and brought back; the chest leaning over the knees). Each
## is posed on the game's own root for its stance (GAME, measured in the game), so the upper body the game lays over
## its legs is the one posed here; each starts and ends on the game's relaxed carry for its stance (the hands, the
## gun, the chest and the head), so the game's pose hands over and takes over without a jump.
## The musket is carried by the right hand's prop bone where the key puts it (pose_solver "rhand" and "lhand" with the
## "musket" hold); the hands go where they work. The cock, the frizzen and the paper cartridge are the game's
## (MusketReload); the ramrod is keyed here, in the musket model's frame.
##   preview: Godot --path . -s tools/anim_author/author_reload.gd -- preview out=<abs dir> [stance=crouch] [at=0.2,...]
##            views of the pose at those moments (seconds into the reload, 0 .. 6.3), with the musket and its ramrod;
##            each moment's views in <out>/r_<k>_<view>.png; per moment the gun's lowest point, how far each hand is
##            from where it was sent and how far the right one reaches from its shoulder; focus=r|l: close on that hand
##   film:    Godot --path . -s tools/anim_author/author_reload.gd -- film out=<abs dir> [stance=crouch] [fps=15] [ram=...]
##            [views=front,right,back,left]
##            the whole reload as the bake makes it (the plan, the solve, the arms cleaned), played on the character
##            frame by frame: <out>/f_<n>_<front|right>.png
##   bake:    Godot --headless --path . -s tools/anim_author/author_reload.gd -- bake
##            both stances' five steps into animations_extra/Frontier_Own.res beside the clips there (STEPS' names and
##            their "-crouch" twins), 30 fps, with the ramrod's place (tracks "Props:ramrod": position and rotation in
##            the musket model's frame)

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const Swings := preload("res://tools/anim_author/author_swings.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const OUT_LIB := "res://animations_extra/Frontier_Own.res"
const FPS := 30.0
## The five steps' seconds (Musket.reload_stages'; the clips are time-scaled to the steps' own in the game).
const STEPS := [["own-musket-load-bite", 1.0], ["own-musket-load-prime", 1.2], ["own-musket-load-pour", 1.4],
		["own-musket-load-ram", 1.7], ["own-musket-load-return", 1.0]]
const TOTAL := 6.3
## The crouched twins' names: the standing ones' with this after them.
const CROUCH_SUFFIX := "-crouch"
## Clips of the earlier takes on this reload, dropped from the library at the bake.
const STALE := ["own-musket-reload-", "own-musket-ram"]
## The gun's beats: to the priming position; cast about; brought back up (upright at RET_UP) to the carry.
const PRIME_FROM := 0.02
const PRIME_AT := 0.3
const CAST_FROM := 1.75
const CAST_AT := 2.2
const RET_FROM := 5.8
const RET_UP := 6.04
const RET_AT := 6.26
## The ramrod's: drawn from its pipes; home again (the right hand lets go of it).
const DRAW_FROM := 3.3
const ROD_HOME := 5.88

# The musket model's frame (tools/models/musket.py): +X the lock side, +Y up, -Z toward the muzzle; the origin at the
# wrist of the stock (where the right hand grips it).
const MUZZLE := Vector3(0.0, 0.035, -1.298)
const PAN := Vector3(0.029, 0.0372, -0.1445)
const FRIZZEN := Vector3(0.03, 0.0335, -0.168)
## The middle of the barrel and the stock under it, near the muzzle (the model's y): what the left fist closes round.
const BARREL_Y := 0.025
const RR_HEAD := Vector3(0.0, 0.015766, -1.286)       ## the ramrod's head, stowed (its origin; the rod runs +Z)
const RR_LEN := 1.151
## The butt plate's toe (the model's frame): what rests on the ground.
const BUTT := Vector3(0.0, -0.07, 0.29)
## How far the fingers curl (pose_solver "fist"): round a barrel, not through it. The hands hold by the hole it leaves
## (pose_solver.fist_rel()): the rod, the barrel and the cartridge run through the fist.
const FIST := 0.9
## The mouth from the head bone (at its rest: body space, from the bone), where the cartridge is bitten.
const MOUTH_REST := Vector3(0.0, 0.09, 0.11)

## The game's own pose in the relaxed musket carry, standing and crouched (measured in the game with the musket out:
## the player's skeleton space, the bones' global poses): the root the upper body rides on, the top spine bone and the
## head, the musket (its model's frame: [origin, x, y, z]), the left wrist on the forestock, and (the preview's legs
## only) the ankles [x, z, lift].
const GAME := {
	"stand": {
		"root": [Vector3(0.04341, 0.905388, 0.030164), Quaternion(-0.726281, -0.033311, -0.029235, 0.685967)],
		"spined": Quaternion(-0.751086, 0.016455, -0.014438, 0.659842),
		"headb": Quaternion(-0.712111, -0.048497, 0.019623, 0.700115),
		"gun": [Vector3(-0.077855, 1.124345, 0.236369), Vector3(-0.575647, 0.817662, -0.007654),
				Vector3(-0.038855, -0.036702, -0.998571), Vector3(-0.816774, -0.574527, 0.052898)],
		"l_wrist": [Vector3(0.248802, 1.289752, 0.150643), Quaternion(0.152366, 0.272557, 0.90823, -0.278596)],
		"feet": {"l": [0.149, -0.051, 0.0], "r": [-0.159, 0.031, 0.0]},
	},
	"crouch": {
		"root": [Vector3(-0.016208, 0.369142, -0.118301), Quaternion(-0.649355, -0.010259, -0.004368, 0.760404)],
		"spined": Quaternion(-0.221698, -0.015578, 0.083431, 0.971415),
		"headb": Quaternion(-0.634899, 0.04854, 0.021658, 0.770764),
		"gun": [Vector3(-0.148436, 0.268772, 0.159972), Vector3(-0.698817, 0.326836, 0.636265),
				Vector3(-0.050794, 0.864587, -0.499908), Vector3(-0.713495, -0.381663, -0.587587)],
		"l_wrist": [Vector3(0.145968, 0.44946, 0.308707), Quaternion(-0.064744, -0.216602, 0.899583, -0.373686)],
		"feet": {"l": [0.111, 0.134, 0.0], "r": [-0.116, -0.262, 0.066]},
		"knees": {"l": [0.1, 0.0, 1.0], "r": [0.0, -0.5, 1.0]},
	},
}
## Each stance's own places (body space, the ground at y 0):
##   prime    the priming position [the lock, the muzzle's way, the lock side's way (up: the pan up)]
##   cast     upright on the way to slanted [the lock, the gun's way] (its turn halfway between the two)
##   ram      slanted for the loading [the muzzle, its way, the barrel's top: away from him, the rod's side to him]
##   up       upright on the way back [the lock, the gun's way, the barrel's top: toward his right, the lock to the
##            front, half turned from slanted (the rod's side to him) to carried (the barrel's top to him)]
##   pouch    the cartridge pouch at the right hip
##   chest_*  the chest's turn [yaw, pitch]: priming, slanted, upright; "head" the head's pitch over the standing one's
##   bar      where on the barrel (the model's z) the left fist holds the gun slanted
##   bar_low  how far down the barrel the left fist has slid with the gun upright on the way back
##   butt     the gun cast about and brought back about its butt (kept down by the ground) rather than the left fist
const LOOK := {
	"stand": {"prime": [Vector3(-0.14, 1.08, 0.2), Vector3(0.3, 0.5, 0.81), Vector3(-0.3, 1.0, 0.0)],
		"cast": [Vector3(0.0, 0.8, 0.34), Vector3(0.05, 1.0, 0.05)],
		# (user 2026-10-01, a test: the gun front to back like the spear, "drop the stock to the ground": on the left side,
		# the butt on the ground behind, the muzzle up before the chest; it was [(-0.04, 1.22, 0.26), (-0.703, 0.643, -0.301)],
		# slanted across the front with the butt out to the front left)
		# (then "stick the left hand out a little": the gun, and the left hand on it, 8 cm further out to the left; then the
		# hands' work swapped, "the right does the primer, then pulls it back in the left position but mirrored for the
		# right, and then the left hand does the ramrod": the same place mirrored to the right side)
		# (the left arm, crossing over, could not reach the rod 0.4 m up from a muzzle out at the right side, 20-29 cm short:
		# the muzzle 14 cm right of the middle and leaned in toward the left hand, the butt out behind on the right, clear
		# of the hip; the chest turned toward it, "chest" below)
		"ram": [Vector3(-0.14, 1.18, 0.3), Vector3(0.258, 0.724, 0.639), Vector3(0.0, 0.3, 1.0)],
		"up": [Vector3(-0.06, 0.86, 0.36), Vector3(0.18, 0.98, -0.05), Vector3(-1.0, 0.18, 0.0)],
		"pouch": Vector3(-0.21, 0.97, 0.02),
		"chest_prime": [-12.0, 8.0], "chest": [-20.0, 6.0], "chest_up": [0.0, 6.0], "head": 0.0, "bar": -1.1,
		"bar_low": -0.7},
	# (crouched: the muzzle at the shoulder as standing, so the gun flatter, its butt just off the ground: user
	# 2026-09-28 "crouch reload gun needs to be lower")
	"crouch": {"prime": [Vector3(-0.12, 0.6, 0.16), Vector3(0.5, 0.25, 0.8), Vector3(-0.3, 1.0, 0.0)],
		"cast": [Vector3(0.0, 0.42, 0.32), Vector3(0.05, 1.0, 0.04)],
		# (the test above, crouched: it was [(-0.02, 0.84, 0.3), (-0.8, 0.45, -0.4)])
		# (then "the crouch we can lower, and the left hand": 10 cm lower and further out; "a little more": 8 cm more;
		# then mirrored to the right side, as standing)
		# (and leaned in toward the left hand, as standing; then "keep the right hand in front of the player, angle the gun down":
		# the muzzle 12 cm further forward and 6 cm lower, the gun flatter, the chest leaned and turned further over it so the
		# left hand still reaches the rod)
		"ram": [Vector3(-0.06, 0.72, 0.22), Vector3(0.26, 0.435, 0.862), Vector3(0.0, 0.3, 1.0)],
		"up": [Vector3(-0.06, 0.42, 0.34), Vector3(0.12, 0.98, 0.06), Vector3(-1.0, 0.1, 0.0)],
		"pouch": Vector3(-0.26, 0.44, -0.1),
		"chest_prime": [-12.0, 24.0], "chest": [-28.0, 32.0], "chest_up": [0.0, 28.0], "head": 0.0, "bar": -1.16,
		"bar_low": -0.5,
		"butt": true},
}

var args := {}
var stance := "stand"
var G_CARRY: Transform3D
var G_PRIME: Transform3D
var G_CAST: Transform3D
var G_RAM: Transform3D
var G_UP: Transform3D
## The left fist's grip on the forestock in the musket model's frame, as the game's carry holds it.
var FORESTOCK := Transform3D()
## Where the left fist holds the barrel with the gun slanted, and has slid down it with the gun upright on the way
## back (the model's frame; the fist's +Y up the barrel).
var BARREL_GRIP := Vector3.ZERO
var BARREL_LOW := Vector3.ZERO
## Where the right fist holds the barrel while the left hand works the ramrod: below the left's grip (the model's frame).
var BARREL_GRIP_R := Vector3.ZERO
var POUCH := Vector3.ZERO
var MOUTH := Vector3.ZERO             ## body space, at the bite
var HIPS := {}                       ## the pose's "hips": the game's root for the stance
var HB := Basis()                    ## the hips' turn
var CHEST_CARRY := Basis()           ## the chest's turn in body space: carried (the game's), priming, slanted, upright
var CHEST_PRIME := Basis()
var CHEST_RAM := Basis()
var CHEST_UP := Basis()
var HEAD_CARRY := Basis()            ## the head's turn over the chest's, carried (the game's)
var FIST_REL := {}                   ## side -> the fist's hole in the wrist's frame (pose_solver.fist_rel())
var PROP_REL := {}                   ## side -> the hand's prop bone in the wrist's frame, at rest
var _right: Array                    ## the right hand's track: [[t, Callable(t) -> [at, way, edge]], ...]
var _left: Array


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	if args.has("bake"):
		await _bake()
	elif args.has("film"):
		await _film()
	else:
		await _preview()
	quit()


# --- the musket's places -------------------------------------------------------------------------------------------

## The musket model's frame in body space: its lock at `origin`, the muzzle along `muzzle`, the barrel's top along `top`.
static func gun(origin: Vector3, muzzle: Vector3, top: Vector3) -> Transform3D:
	var z := -muzzle.normalized()
	var y := (top - z * top.dot(z)).normalized()
	return Transform3D(Basis(y.cross(z).normalized(), y, z), origin)


## As gun(), turned by the way its lock side (the model's +X) faces.
static func gun_x(origin: Vector3, muzzle: Vector3, side: Vector3) -> Transform3D:
	var z := -muzzle.normalized()
	var x := (side - z * side.dot(z)).normalized()
	return Transform3D(Basis(x, z.cross(x).normalized(), z), origin)


## The stance's places: the game's frames, the gun's keys, the hips, the chest and the head, the hands' tracks.
func _stance(solver, st: String) -> void:
	stance = st
	var gm: Dictionary = GAME[st]
	var lk: Dictionary = LOOK[st]
	var gv: Array = gm.gun
	G_CARRY = Transform3D(Basis(gv[1], gv[2], gv[3]).orthonormalized(), gv[0])
	var pr: Array = lk.prime
	G_PRIME = gun_x(pr[0], pr[1], pr[2])
	var rm: Array = lk.ram
	if args.has("ram"):
		# (a trial loading place: ram=mx,my,mz,dx,dy,dz, the muzzle and its way)
		var v := str(args.ram).split(",")
		rm = [Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5])),
				Vector3(float(v[6]), float(v[7]), float(v[8])) if v.size() >= 9 else rm[2]]
	var g := gun(Vector3.ZERO, rm[1], rm[2])
	g.origin = (rm[0] as Vector3) - g.basis * MUZZLE
	G_RAM = g
	# the stock swung back (user 2026-10-01: "angle the stock back" so it does not stick out in front during the reload,
	# the left hand kept where it is, "like a ball joint"): the slanted gun turned about the left fist's grip on the barrel,
	# about the upright, by stock_back degrees (the butt from out in front round to the left, then behind)
	var sb := float(args.get("stock_back", lk.get("stock_back", 0.0)))
	if str(args.get("parallel", lk.get("parallel", false))) in ["true", "True", "1"]:
		# (user 2026-10-01: "the musket parallel to the user", the hands where they are: the gun across the body in its
		# side-to-side plane, the butt straight out to the left rather than out in front; the turn that takes the butt's
		# horizontal way onto the left)
		var bz := G_RAM.basis.z
		sb = rad_to_deg(atan2(bz.z, bz.x))
	if absf(sb) > 1e-3:
		var piv := G_RAM * Vector3(0.0, 0.0, float(args.get("bar", lk.bar)))
		var turn := Basis(Vector3.UP, deg_to_rad(sb))
		G_RAM = Transform3D(turn * G_RAM.basis, piv + turn * (G_RAM.origin - piv))
	var ca: Array = lk.cast
	var mid := Basis(G_PRIME.basis.get_rotation_quaternion().slerp(G_RAM.basis.get_rotation_quaternion(), 0.5))
	G_CAST = gun(ca[0], ca[1], mid.y)
	var up: Array = lk.up
	G_UP = gun(up[0], up[1], up[2])
	BARREL_GRIP = Vector3(0.0, 0.0, float(args.get("bar", lk.bar)))
	BARREL_LOW = Vector3(0.0, 0.0, float(lk.bar_low))
	BARREL_GRIP_R = Vector3(0.0, 0.0, float(args.get("bar_r", lk.get("bar_r", float(lk.bar) + 0.2))))
	POUCH = lk.pouch
	var rest: Dictionary = solver.rest
	# the right fist is the torch's (the knife attack HandHolds lays under the torch hold, its first key): a hammer grip
	# that closes round the rod and the cartridge on this body's hand (the solver's own curl splayed open on it; the user
	# 2026-09-29: "the ramrod motion can use the same grip as holding the torch", "the hands need to look like it's
	# holding the ramrod"); the rod and the cartridge run through its hole
	if not solver.finger_pose.has("r"):
		solver.finger_pose["r"] = _clip_fingers(solver.sk, "r", RIGHT_FIST_CLIP)
	for side: String in ["r", "l"]:
		FIST_REL[side] = solver.fist_rel(side, FIST)
		PROP_REL[side] = (rest[side + "_wrist"] as Transform3D).affine_inverse() * rest[side + "_hand_prop_attachment"]
	var root: Array = gm.root
	var rr: Transform3D = rest["root"]
	HB = (Basis(root[1] as Quaternion) * rr.basis.inverse()).orthonormalized()
	var ha: Array = Solver.angles(HB)
	HIPS = {"pos": _a((root[0] as Vector3) - rr.origin), "yaw": ha[0], "pitch": ha[1], "roll": ha[2]}
	var cp: Array = lk.chest_prime
	var ch: Array = lk.chest
	if args.has("chest"):
		ch = Array(str(args.chest).split(",")).map(func(x: String) -> float: return float(x))
	var cu: Array = lk.chest_up
	CHEST_PRIME = Solver.euler(float(cp[0]), float(cp[1]), 0.0)
	CHEST_RAM = Solver.euler(float(ch[0]), float(ch[1]), 0.0)
	CHEST_UP = Solver.euler(float(cu[0]), float(cu[1]), 0.0)
	CHEST_CARRY = (Basis(gm.spined as Quaternion) * (rest["spined"] as Transform3D).basis.inverse()).orthonormalized()
	HEAD_CARRY = (CHEST_CARRY.inverse() * Basis(gm.headb as Quaternion) * (rest["headb"] as Transform3D).basis.inverse()).orthonormalized()
	var lw: Array = gm.l_wrist
	var rel: Transform3D = (rest["l_wrist"] as Transform3D).affine_inverse() * rest["l_hand_prop_attachment"]
	FORESTOCK = G_CARRY.affine_inverse() * (Transform3D(Basis(lw[1] as Quaternion), lw[0]) * rel)
	# the mouth where the head is at the bite (the body alone posed)
	var bite := 0.73
	solver.pose({"hips": HIPS, "chest": _turn_key(HB.inverse() * chest_at(bite)), "head": _turn_key(head_at(bite)),
			"feet": gm.feet})
	var hb: Transform3D = solver.g("headb")
	var hr: Transform3D = rest["headb"]
	MOUTH = hb.origin + hb.basis * (hr.basis.inverse() * MOUTH_REST)
	_tracks()
	print("RELOAD %s: hips %s, forestock (model frame) %s, mouth %s, the right fist's hole (wrist frame) %s" % [st,
			HIPS, FORESTOCK.origin.snappedf(0.001), MOUTH.snappedf(0.001), FIST_REL.r])


const RIGHT_FIST_CLIP := "actor_b/atk-actor_b-knife-v-thug-hit1-intro"


## A hand's finger and thumb rotations in a clip at its first key: {bone: local rotation}.
func _clip_fingers(sk: Skeleton3D, side: String, clip: String) -> Dictionary:
	var out := {}
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	for ap: AnimationPlayer in aps:
		if not ap.has_animation(clip):
			continue
		var a := ap.get_animation(clip)
		for i in a.get_track_count():
			if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var bn := String(a.track_get_path(i).get_concatenated_subnames())
			if bn.begins_with(side + "_") and ["thumb", "index", "middle", "ring", "pinky"].any(func(k: String) -> bool: return bn.contains(k)) \
					and sk.find_bone(bn) >= 0:
				out[bn] = a.rotation_track_interpolate(i, 0.0)
		break
	if out.is_empty():
		push_warning("author_reload: no %s fingers in %s" % [side, clip])
	return out


static func _turn_key(b: Basis) -> Dictionary:
	var a: Array = Solver.angles(b)
	return {"yaw": a[0], "pitch": a[1], "roll": a[2]}


static func xf_lerp(a: Transform3D, b: Transform3D, u: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, u))


static func smooth(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## A piecewise path through [[t, value], ...] (floats, Vector3s or Transform3Ds), eased smooth between the keys.
static func path(keys: Array, t: float) -> Variant:
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i in keys.size() - 1:
		var t0 := float(keys[i][0])
		var t1 := float(keys[i + 1][0])
		if t <= t1:
			var u := smooth((t - t0) / maxf(t1 - t0, 1e-4))
			var a = keys[i][1]
			var b = keys[i + 1][1]
			if a is Transform3D:
				return xf_lerp(a, b, u)
			if a is Vector3:
				return (a as Vector3).lerp(b, u)
			return lerpf(float(a), float(b), u)
	return keys[keys.size() - 1][1]


## A turn's path (as path(), the turns slerped).
static func turn_path(keys: Array, t: float) -> Basis:
	return (path(keys.map(func(k: Array) -> Array: return [k[0], Transform3D(k[1], Vector3.ZERO)]), t) as Transform3D).basis


static func _keyed(times: Array, values: Array) -> Array:
	var out := []
	for i in times.size():
		out.append([times[i], values[i]])
	return out


## One sweep from `a` through `b` to `c` without stopping at `b`: splines (Catmull-Rom; the turn's spherical) through
## the three, `b` halfway, placed by the model point `piv` (turned about it).
static func sweep(a: Transform3D, b: Transform3D, c: Transform3D, u: float, piv: Vector3) -> Transform3D:
	var pa := a * piv
	var pb := b * piv
	var pc := c * piv
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	var qc := c.basis.get_rotation_quaternion()
	var p: Vector3
	var q: Quaternion
	if u < 0.5:
		p = pa.cubic_interpolate(pb, pa, pc, u * 2.0)
		q = qa.spherical_cubic_interpolate(qb, qa, qc, u * 2.0)
	else:
		p = pb.cubic_interpolate(pc, pa, pc, u * 2.0 - 1.0)
		q = qb.spherical_cubic_interpolate(qc, qa, qc, u * 2.0 - 1.0)
	var bs := Basis(q.normalized())
	return Transform3D(bs, p - bs * piv)


## Where the musket is at `t` (seconds into the reload): from the carry to the priming position; cast about to slanted
## (upright on the way, turning about the left fist, crouched about the butt); slanted until the rod is nearly home;
## raised upright and brought across to the carry.
func gun_at(t: float) -> Transform3D:
	var butt: bool = LOOK[stance].has("butt")
	if t < CAST_FROM:
		return path([[PRIME_FROM, G_CARRY], [PRIME_AT, G_PRIME]], t)
	if t < CAST_AT:
		return sweep(G_PRIME, G_CAST, G_RAM, smooth((t - CAST_FROM) / (CAST_AT - CAST_FROM)),
				BUTT if butt else Vector3(0.0, 0.0, -0.62))
	if t <= RET_FROM:
		return G_RAM
	if t >= RET_AT:
		return G_CARRY
	return sweep(G_RAM, G_UP, G_CARRY, smooth((t - RET_FROM) / (RET_AT - RET_FROM)), BUTT if butt else BARREL_LOW)


# --- the ramrod ------------------------------------------------------------------------------------------------------

## The ramrod at `t`: [its transform in the musket model's frame, the point the right hand holds (model frame) or null].
## Stowed under the barrel it runs +Z from its head; out of the muzzle is -Z (up the slant). The right hand stays at
## the muzzle: the rod comes out in tugs (the fist pulls it 0.38 m, goes back to the muzzle, pulls again), is turned
## end for end away from the loader (the model's +Y), goes in and is rammed in three strokes, the fist sliding back up
## the rod between them; then tugged out, turned back and pushed home.
func rod_at(t: float) -> Array:
	var mz := MUZZLE.z
	# stowed (the fist at its head by the muzzle as it takes it)
	if t < DRAW_FROM:
		return [Transform3D(Basis(), RR_HEAD), RR_HEAD + Vector3(0, 0, -0.02)]
	# drawn in three tugs ("ramrod_draw" at 3.3 and 3.66)
	if t < 3.85:
		var tk := [DRAW_FROM, 3.45, 3.52, 3.64, 3.72, 3.85]
		var out: float = path(_keyed(tk, [0.0, 0.38, 0.38, 0.76, 0.76, RR_LEN]), t)
		var gz: float = path(_keyed(tk, [RR_HEAD.z - 0.02, RR_HEAD.z - 0.4, mz - 0.04, mz - 0.42, mz - 0.04, mz - 0.43]), t)
		return [Transform3D(Basis(), RR_HEAD + Vector3(0, 0, -out)), Vector3(0, RR_HEAD.y, gz)]
	# turned end for end (its head from out along the slant, through away from the loader, to down at the muzzle)
	if t < 3.98:
		return _rod_turn(smooth((t - 3.85) / 0.13), RR_LEN - 0.43, 0.38, Vector3(0, RR_HEAD.y, mz - 0.43),
				Vector3(0, MUZZLE.y, mz - 0.38))
	# rammed: three strokes (the cues at 4.22, 4.57, 4.91), the fist sliding back up the rod between them
	if t < 4.95:
		var sk := [3.98, 4.218, 4.36, 4.566, 4.7, 4.914]
		return _in_bore(path(_keyed(sk, [0.0, 0.35, 0.35, 0.7, 0.7, 1.1]), t),
				path(_keyed(sk, [0.38, 0.38, 0.73, 0.73, 1.13, 1.13]), t))
	# tugged out of the bore in three ("ramrod_return" at 5.34)
	if t < 5.44:
		var ok := [4.98, 5.1, 5.16, 5.28, 5.34, 5.44]
		return _in_bore(path(_keyed(ok, [1.1, 0.72, 0.72, 0.34, 0.34, -0.05]), t),
				path(_keyed(ok, [1.13, 1.13, 0.76, 0.76, 0.38, 0.38]), t))
	# turned back (its head out again), its tail to the pipes' mouth
	if t < 5.54:
		return _rod_turn(1.0 - smooth((t - 5.44) / 0.1), RR_LEN - 0.43, 0.38, Vector3(0, RR_HEAD.y, mz - 0.43),
				Vector3(0, MUZZLE.y, mz - 0.43))
	# home down its pipes: pushed in two, the fist sliding back up the rod between them, and its head pushed home
	var keys := [5.54, 5.64, 5.69, 5.79, 5.82, ROD_HOME]
	var out2: float = path(_keyed(keys, [RR_LEN, 0.76, 0.76, 0.37, 0.37, 0.0]), t)
	var grip: Variant = null
	if t < ROD_HOME:
		grip = Vector3(0, RR_HEAD.y, path(_keyed(keys, [mz - 0.43, mz - 0.04, mz - 0.42, mz - 0.03, RR_HEAD.z - 0.39,
				RR_HEAD.z - 0.02]), t))
	return [Transform3D(Basis(), RR_HEAD + Vector3(0, 0, -out2)), grip]


## In the bore, its head `depth` down from the muzzle, the fist `d` from its head.
func _in_bore(depth: float, d: float) -> Array:
	var head := Vector3(0, MUZZLE.y, MUZZLE.z + depth)
	return [Transform3D(Basis(Vector3.RIGHT, PI), head), head + Vector3(0, 0, -d)]


## Turning end for end: u 0 its head out along the slant (the rod +Z from the head, held `d0` from it at grip0), u 1 its
## head down at the muzzle (-Z, held `d1` from it at grip1), through across the slant away from the loader (+Y) at u 0.5.
func _rod_turn(u: float, d0: float, d1: float, grip0: Vector3, grip1: Vector3) -> Array:
	var ang := PI * u
	var basis := Basis(Vector3.RIGHT, -ang)                     # (+Z turned toward +Y, then to -Z: the rod's +Z)
	var dir := basis.z
	var grip := grip0.lerp(grip1, u) + Vector3(0.0, 0.06, 0.0) * sin(ang)
	var d := lerpf(d0, d1, u)
	return [Transform3D(basis, grip - dir * d), grip]


# --- the hands -------------------------------------------------------------------------------------------------------

## A hand's target on the gun (the model's frame: the point, the fist's +Y, the edge), following it.
func _on_gun(p: Vector3, way: Vector3, edge := Vector3.ZERO) -> Callable:
	return func(t: float) -> Array:
		var g := gun_at(t)
		return [g * p, (g.basis * way).normalized(), g.basis * edge]


## A hand's target in body space.
static func _at(p: Vector3, way: Vector3, edge := Vector3.ZERO) -> Callable:
	return func(_t: float) -> Array: return [p, way.normalized(), edge]


## The right hand on the wrist of the stock, as the game holds it (its prop bone there: its fist's hole where that
## puts it).
func _grip() -> Callable:
	return func(t: float) -> Array:
		return _held("r", gun_at(t) * Solver.MUSKET.affine_inverse())


## [at, way, edge] for the fist's hole with the hand's prop bone at `prop`.
func _held(side: String, prop: Transform3D) -> Array:
	var h := prop * (PROP_REL[side] as Transform3D).affine_inverse() * (FIST_REL[side] as Transform3D)
	return [h.origin, h.basis.y.normalized(), -h.basis.z]


## A hand on the ramrod (the left, since the hands' work was swapped), thumb down the barrel; once it is home, where it let
## go of it.
func _rod() -> Callable:
	return func(t: float) -> Array:
		var at: Variant = rod_at(t)[1]
		var g := gun_at(t)
		if at == null:
			g = gun_at(ROD_HOME)
			at = RR_HEAD + Vector3(0, 0, -0.02)
		return [g * (at as Vector3), (g.basis * Vector3(0, 0, 1)).normalized(), Vector3.ZERO]


## The left hand on the forestock as the carry has it.
func _fore() -> Callable:
	return func(t: float) -> Array:
		return _held("l", gun_at(t) * FORESTOCK)


## The left hand as the game's carry holds the forestock (from below, the fingers round it: measured in the game, it
## reads right), slid along the stock to `z` (the model's z; the full stock runs almost to the muzzle, z -1.19): while
## the gun is loaded the left hand holds it there the same way (user 2026-09-29: the fist closed under the barrel, the
## barrel over the knuckles, "looks crazy").
func _fore_at(z: float) -> Callable:
	return func(t: float) -> Array:
		var slid := Transform3D(FORESTOCK.basis, Vector3(FORESTOCK.origin.x, FORESTOCK.origin.y, z))
		return _held("l", gun_at(t) * slid)


## The left fist round the barrel at `z` (the model's z) with the gun stood up to be loaded: the barrel through the
## fist's hole, its thumb up it toward the muzzle, turned about it as the wrist is straightest (pose_solver's
## wrist_neutral), a little toward the carry's turn (`keep`: how much). The carry's grip slid up the barrel held it 40
## degrees off the barrel's line and folded the hand back off the forearm (the user 2026-09-29: "the wrist still
## bends in weird ways, not natural").
func _barrel(z: float, keep: float, side := "l") -> Callable:
	return func(t: float) -> Array:
		var g := gun_at(t)
		var way := (g.basis * Vector3(0.0, 0.0, -1.0)).normalized()
		var edge := Vector3.ZERO
		if side == "l":
			var carry: Vector3 = _fore_at(z).call(t)[2]
			edge = (carry - way * carry.dot(way)).normalized() * keep
		return [g * Vector3(0.0, BARREL_Y, z), way, edge]


## The hands' tracks (for the stance: set by _stance()).
func _tracks() -> void:
	var down := Vector3(0, 0, 1)                  # (the fist's +Y down the barrel: the cartridge's end toward the muzzle)
	var mouth_at := MOUTH + Vector3(0.0, -0.05, 0.05)
	var hold := MOUTH + Vector3(-0.08, -0.3, 0.12)
	_right = [
		[0.0, _grip()], [0.18, _grip()],
		# the frizzen flicked open by the thumb ("frizzen_open" 0.25)
		[0.25, _on_gun(FRIZZEN + Vector3(0.05, 0.03, -0.03), Vector3(0, 0, -1))],
		[0.29, _on_gun(FRIZZEN + Vector3(0.07, 0.06, 0.02), Vector3(0, 0, -1))],
		# a cartridge from the pouch ("cartridge_draw" 0.39)
		[0.36, _at(POUCH + Vector3(0, 0.03, 0), Vector3(0, 1, 0))], [0.41, _at(POUCH, Vector3(0, 1, 0))],
		# up to the mouth and bitten ("cartridge_bite" 0.73), torn away
		[0.7, _at(mouth_at, MOUTH - mouth_at)], [0.77, _at(mouth_at, MOUTH - mouth_at)],
		[0.86, _at(mouth_at + Vector3(-0.07, -0.05, 0.04), Vector3(0.2, 1, 0.3))],
		# powder shaken into the pan ("powder_pour_pan" 1.11), the frizzen pulled shut ("frizzen_close" 1.64)
		[1.02, _on_gun(PAN + Vector3(0.1, 0.03, 0.0), Vector3(-1, 0.2, 0))],
		[1.1, _on_gun(PAN + Vector3(0.07, 0.02, 0.0), Vector3(-1, 0, 0))],
		[1.28, _on_gun(PAN + Vector3(0.07, 0.02, -0.02), Vector3(-1, 0, 0.2))],
		[1.45, _on_gun(PAN + Vector3(0.07, 0.02, 0.0), Vector3(-1, 0, 0))],
		[1.54, _on_gun(FRIZZEN + Vector3(0.06, 0.04, -0.05), Vector3(0, 0, 1))],
		[1.64, _on_gun(FRIZZEN + Vector3(0.06, 0.03, 0.02), Vector3(0, 0, 1))],
		# the gun cast about, the cartridge held at the chest out of its way, then over the muzzle
		[1.8, _at(hold, Vector3(0, 1, 0.3))], [2.04, _at(hold, Vector3(0, 1, 0.3))],
		[2.2, _on_gun(MUZZLE + Vector3(0, 0.02, -0.12), down)],
		# poured ("powder_pour_barrel" 2.36), the ball and the paper pressed in ("ball_seat" 3.17)
		[2.36, _on_gun(MUZZLE + Vector3(0, 0.0, -0.09), down)], [2.55, _on_gun(MUZZLE + Vector3(0, 0.01, -0.1), down)],
		[2.75, _on_gun(MUZZLE + Vector3(0, 0.0, -0.09), down)],
		[2.9, _on_gun(MUZZLE + Vector3(0, 0.0, -0.1), down)], [3.17, _on_gun(MUZZLE + Vector3(0, 0.0, -0.04), down)],
		# (user 2026-10-01: the hands' work swapped for the ramrod) down the barrel to hold the gun, below the left hand,
		# which takes the ramrod; it raises the gun upright as the rod goes home, and goes back to the wrist of the stock
		# for the carry (full cock 6.11)
		[DRAW_FROM, _barrel(BARREL_GRIP_R.z, 0.0, "r")], [RET_FROM, _barrel(BARREL_GRIP_R.z, 0.0, "r")],
		[RET_UP, _barrel(BARREL_LOW.z, 0.0, "r")], [RET_AT, _grip()], [TOTAL, _grip()],
	]
	_left = [
		[0.0, _fore()], [CAST_FROM + 0.24, _fore()],
		# the barrel held under the muzzle while the right hand pours; then the ramrod's head taken (it is at the hand),
		# the rod worked and pushed home; back to the forestock for the carry
		[CAST_AT, _barrel(BARREL_GRIP.z, 0.15)], [3.17, _barrel(BARREL_GRIP.z, 0.15)],
		[DRAW_FROM, _rod()], [ROD_HOME, _rod()], [RET_AT, _fore()], [TOTAL, _fore()],
	]


## A hand along its track at `t`: [place, way, edge], eased from one target to the next (each where it is at `t`).
static func track(keys: Array, t: float) -> Array:
	if t <= float(keys[0][0]):
		return (keys[0][1] as Callable).call(t)
	for i in keys.size() - 1:
		var t1 := float(keys[i + 1][0])
		if t <= t1:
			var t0 := float(keys[i][0])
			var u := smooth((t - t0) / maxf(t1 - t0, 1e-4))
			var a: Array = (keys[i][1] as Callable).call(t)
			if u <= 0.0:
				return a
			var b: Array = (keys[i + 1][1] as Callable).call(t)
			return [(a[0] as Vector3).lerp(b[0], u), (a[1] as Vector3).slerp(b[1], u).normalized(),
					(a[2] as Vector3).lerp(b[2], u)]
	return (keys[keys.size() - 1][1] as Callable).call(t)


## The chest's turn in body space at `t`.
func chest_at(t: float) -> Basis:
	return turn_path([[0.0, CHEST_CARRY], [PRIME_AT, CHEST_PRIME], [CAST_FROM, CHEST_PRIME], [CAST_AT, CHEST_RAM],
			[RET_FROM, CHEST_RAM], [RET_UP, CHEST_UP], [RET_AT, CHEST_CARRY]], t)


## The head's turn over the chest's at `t`: at the pan, the cartridge to the mouth, at the pan, at the muzzle (up at
## the rod as it is drawn), back to the carry.
func head_at(t: float) -> Basis:
	var nod := float(LOOK[stance].head)
	var e := func(yaw: float, pitch: float) -> Basis: return Solver.euler(yaw, pitch + nod, 0.0)
	return turn_path([[0.0, HEAD_CARRY], [PRIME_AT, e.call(-10.0, 25.0)], [0.5, e.call(-12.0, 8.0)],
			[0.73, e.call(-16.0, 0.0)], [0.86, e.call(-6.0, 12.0)], [1.02, e.call(-10.0, 28.0)], [CAST_FROM, e.call(-10.0, 28.0)],
			[CAST_AT, e.call(-8.0, 18.0)], [3.17, e.call(-8.0, 20.0)], [3.6, e.call(-8.0, 8.0)], [3.85, e.call(-8.0, 6.0)],
			[3.98, e.call(-8.0, 20.0)], [RET_FROM, e.call(-8.0, 18.0)], [RET_UP, e.call(0.0, 12.0)], [RET_AT, HEAD_CARRY]], t)


## The solver's key at `t`: [key, the gun, the right hand's place, the left's].
func pose_at(t: float) -> Array:
	var g := gun_at(t)
	var h := track(_right, t)
	var lh := track(_left, t)
	var gm: Dictionary = GAME[stance]
	var p := {
		"hips": HIPS,
		"chest": _turn_key(HB.inverse() * chest_at(t)),
		"head": _turn_key(head_at(t)),
		"feet": gm.feet,
		"tool": {"grip": _a(g.origin), "haft": _a(g.basis.y), "edge": _a(-g.basis.z),
			"lhand": {"at": _a(lh[0]), "haft": _a(lh[1]), "edge": _a(lh[2]), "rel": FIST_REL.l},
			"rhand": {"at": _a(h[0]), "haft": _a(h[1]), "edge": _a(h[2]), "rel": FIST_REL.r}},
		"fist": FIST,
	}
	if gm.has("knees"):
		p["knees"] = gm.knees
	return [p, g, h[0], lh[0]]


static func _a(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## A hand's fist's hole (FIST_REL), skeleton space: where what it holds is.
func hand_grip(solver, side := "r") -> Transform3D:
	return solver.g(side + "_wrist") * (FIST_REL[side] as Transform3D)


## The musket's lowest point at `g` (its model's box's corners: the butt's toe, near enough).
static func lowest(g: Transform3D, box: AABB) -> float:
	var y := INF
	for i in 8:
		y = minf(y, (g * box.get_endpoint(i)).y)
	return y


# --- preview ---------------------------------------------------------------------------------------------------------

func _character() -> Array:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	return [n, sk]


static func _box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if m.name == "Ramrod" or m.get_parent().name == "Ramrod":
			continue
		var rel := Transform3D()
		var x: Node = m
		while x != n:
			rel = (x as Node3D).transform * rel
			x = x.get_parent()
		var b := rel * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _preview() -> void:
	var out := str(args.get("out", "user://reload"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.56, 0.45)
	floor.material_override = fm
	world.add_child(floor)
	var ch := _character()
	var sk: Skeleton3D = ch[1]
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	solver.hold = "musket"
	solver.wrist_neutral = true
	solver.neutral_tilt = {"r": true}
	_stance(solver, str(args.get("stance", "stand")))
	var musket := WeaponModels.build("musket")
	world.add_child(musket)
	var rod := musket.find_child("Ramrod", true, false) as Node3D
	var box := _box(musket)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(360, 440))
	var cam: Camera3D = view.camera
	cam.fov = 40.0
	await process_frame
	var moments: Array = Array(str(args.get("at", "0,0.15,0.3,0.39,0.55,0.73,0.86,1.1,1.3,1.64,1.8,1.95,2.1,2.2,2.36,2.9,3.17,3.45,3.64,3.85,3.92,4.22,4.36,4.57,4.91,5.1,5.34,5.49,5.64,5.8,5.92,6.04,6.15,6.3")).split(",", false)).map(func(x: String) -> float: return float(x))
	var mf := FileAccess.open(out + "/moments.txt", FileAccess.WRITE)
	mf.store_string(",".join(moments.map(func(x: float) -> String: return "%.3f" % x)))
	mf.close()
	var up := 0.6 if stance == "crouch" else 1.1
	for k in moments.size():
		var t: float = moments[k]
		var r := pose_at(t)
		solver.reset_neutral()
		solver.pose(r[0])
		sk.force_update_all_bone_transforms()
		var prop := sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment"))
		musket.global_transform = sk.global_transform * prop * Solver.MUSKET
		if rod:
			rod.transform = rod_at(t)[0]
		var rg := hand_grip(solver, "r").origin
		print("RELOAD t %.2f  lowest %.2f  right off by %.3f  left off by %.3f  right reach %.2f" % [t,
				lowest(r[1], box), rg.distance_to(r[2]), hand_grip(solver, "l").origin.distance_to(r[3]),
				rg.distance_to(solver.g("r_shoulder").origin)])
		for side in ["front", "right"]:
			var base := Vector3(0.05, up, 0.15)
			var off := Vector3(-1.1, 0.35, 2.3) if side == "front" else Vector3(-2.5, 0.3, 0.6)
			if args.has("focus"):
				# (close on a hand: focus=r or focus=l)
				base = hand_grip(solver, str(args.focus)).origin
				off = (Vector3(-0.3, 0.12, 0.5) if side == "front" else Vector3(-0.55, 0.1, 0.05))
			cam.global_position = base + off
			cam.look_at(base)
			for i in 3:
				await process_frame
				# (a window hidden behind others stops drawing: the views went stale)
				if not DisplayServer.window_can_draw():
					RenderingServer.force_draw(false)
			view.get_texture().get_image().save_png(out + "/r_%02d_%s.png" % [k, side])
	print("RELOAD PREVIEW %s %d moments -> %s" % [stance, moments.size(), out])


# --- film ------------------------------------------------------------------------------------------------------------

func _film() -> void:
	var out := str(args.get("out", "user://reload_film"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.56, 0.45)
	floor.material_override = fm
	world.add_child(floor)
	var ch := _character()
	var sk: Skeleton3D = ch[1]
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	solver.hold = "musket"
	solver.wrist_neutral = true
	solver.neutral_tilt = {"r": true}
	var st := str(args.get("stance", "stand"))
	_stance(solver, st)
	# the clips as the bake makes them
	solver.reset_neutral(true)
	solver.neutral_mode = "collect"
	var tc := 0.0
	for s: Array in STEPS:
		for f in int(round(float(s[1]) * FPS)) + 1:
			solver.pose(pose_at(tc + minf(float(f) / FPS, float(s[1])))[0])
		tc += float(s[1])
	solver.plan_neutral()
	solver.neutral_mode = "replay"
	solver.reset_neutral()
	var chain := Swings._chain_bones(sk)
	var clips: Array = []
	var t0 := 0.0
	for s: Array in STEPS:
		clips.append([t0, float(s[1]), _bake_step(solver, sk, chain, "Skeleton3D", t0, float(s[1]))])
		t0 += float(s[1])
	var musket := WeaponModels.build("musket")
	world.add_child(musket)
	var rod := musket.find_child("Ramrod", true, false) as Node3D
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(360, 440))
	var cam: Camera3D = view.camera
	cam.fov = 40.0
	await process_frame
	var fps := float(args.get("fps", 15.0))
	var up := 0.6 if stance == "crouch" else 1.1
	var n := int(round(TOTAL * fps))
	for k in n + 1:
		var t := minf(float(k) / fps, TOTAL)
		var c: Array = clips[clips.size() - 1]
		for cc: Array in clips:
			if t <= float(cc[0]) + float(cc[1]) + 1e-4:
				c = cc
				break
		var a: Animation = c[2]
		var lt := clampf(t - float(c[0]), 0.0, a.length)
		for ti in a.get_track_count():
			var path := String(a.track_get_path(ti))
			if not path.begins_with("Skeleton3D:"):
				continue
			var b := sk.find_bone(path.get_slice(":", 1))
			if b < 0:
				continue
			if a.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(ti, lt))
			elif a.track_get_type(ti) == Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(ti, lt))
		sk.force_update_all_bone_transforms()
		var prop := _fk_pose(sk, sk.find_bone("r_hand_prop_attachment"))
		musket.global_transform = sk.global_transform * prop * Solver.MUSKET
		if rod:
			rod.transform = rod_at(t)[0]
		for side: String in str(args.get("views", "front,right")).split(","):
			var base := Vector3(0.05, up, 0.15)
			var off: Vector3 = {"front": Vector3(-1.1, 0.35, 2.3), "right": Vector3(-2.5, 0.3, 0.6),
					"back": Vector3(1.0, 0.35, -2.3), "left": Vector3(2.5, 0.3, 0.6)}[side]
			cam.global_position = base + off
			cam.look_at(base)
			for i in 3:
				await process_frame
				if not DisplayServer.window_can_draw():
					RenderingServer.force_draw(false)
			view.get_texture().get_image().save_png(out + "/f_%03d_%s.png" % [k, side])
	print("RELOAD FILM %s %d frames -> %s" % [stance, n + 1, out])


## A bone's skeleton-space transform from the skeleton's local poses (not its cached globals).
static func _fk_pose(sk: Skeleton3D, b: int) -> Transform3D:
	var x := Transform3D(Basis(sk.get_bone_pose_rotation(b)), sk.get_bone_pose_position(b))
	var par := sk.get_bone_parent(b)
	return x if par < 0 else _fk_pose(sk, par) * x


# --- bake ------------------------------------------------------------------------------------------------------------

func _bake() -> void:
	var ch := _character()
	var sk: Skeleton3D = ch[1]
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	solver.hold = "musket"
	solver.wrist_neutral = true
	solver.neutral_tilt = {"r": true}
	var box := _box(WeaponModels.build("musket"))
	var ref_lib := load("res://animations_extra/Actor_B_from_A.res") as AnimationLibrary
	var ref := ref_lib.get_animation(ref_lib.get_animation_list()[0])
	var path_pre := str(ref.track_get_path(0)).get_slice(":", 0)
	var lib := AnimationLibrary.new()
	lib.resource_name = "frontier_own"
	var was := load(OUT_LIB) as AnimationLibrary
	if was:
		for a: StringName in was.get_animation_list():
			var stale := false
			for p: String in STALE:
				stale = stale or String(a).begins_with(p)
			if not stale:
				lib.add_animation(a, was.get_animation(a))
	var chain := Swings._chain_bones(sk)
	for st: String in ["stand", "crouch"]:
		_stance(solver, st)
		var low := INF
		var t := 0.0
		while t <= TOTAL + 1e-4:
			low = minf(low, lowest(gun_at(t), box))
			t += 1.0 / FPS
		# the hands' grips planned over the whole reload first (pose_solver wrist_neutral: every frame, as the bake
		# poses them), then posed along the plan
		solver.reset_neutral(true)
		solver.neutral_mode = "collect"
		var tc := 0.0
		for s: Array in STEPS:
			for f in int(round(float(s[1]) * FPS)) + 1:
				solver.pose(pose_at(tc + minf(float(f) / FPS, float(s[1])))[0])
			tc += float(s[1])
		solver.plan_neutral()
		solver.neutral_mode = "replay"
		solver.reset_neutral()
		var t0 := 0.0
		for s: Array in STEPS:
			var nm := StringName(str(s[0]) + (CROUCH_SUFFIX if st == "crouch" else ""))
			if lib.has_animation(nm):
				lib.remove_animation(nm)
			lib.add_animation(nm, _bake_step(solver, sk, chain, path_pre, t0, float(s[1])))
			print("baked %s: %.2f s from %.2f" % [nm, float(s[1]), t0])
			t0 += float(s[1])
		print("  %s: the gun's lowest point %.2f m" % [st, low])
	print(ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS))


func _bake_step(solver, sk: Skeleton3D, chain: Dictionary, path_pre: String, t0: float, length: float) -> Animation:
	var n := int(round(length * FPS))
	var anim := Animation.new()
	anim.length = length
	anim.set_meta(&"authored", "Frontier: this project's own key poses (tools/anim_author/author_reload.gd)")
	anim.set_meta(&"source", "none: not extracted from any game")
	var rot := {}
	var posi := {}
	var rod_p := []
	for f in n + 1:
		var t := minf(float(f) / FPS, length)
		var r := pose_at(t0 + t)
		solver.pose(r[0])
		for b in sk.get_bone_count():
			var nm := sk.get_bone_name(b)
			if not chain.has(nm):
				continue
			if not rot.has(nm):
				rot[nm] = []
			(rot[nm] as Array).append([t, sk.get_bone_pose_rotation(b)])
			if nm in ["root", "r_hand_prop_attachment"]:
				if not posi.has(nm):
					posi[nm] = []
				(posi[nm] as Array).append([t, sk.get_bone_pose_position(b)])
		rod_p.append([t, (rod_at(t0 + t)[0] as Transform3D)])
	_clean_arms(sk, rot, posi)
	_fingers_to_carry(sk, rot, t0, length)
	for nm: String in rot:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(path_pre + ":" + nm))
		for k: Array in rot[nm]:
			anim.rotation_track_insert_key(tr, float(k[0]), k[1])
	for nm: String in posi:
		var tr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tr, NodePath(path_pre + ":" + nm))
		for k: Array in posi[nm]:
			anim.position_track_insert_key(tr, float(k[0]), k[1])
	var rp := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(rp, NodePath("Props:ramrod"))
	var rr := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rr, NodePath("Props:ramrod"))
	for k: Array in rod_p:
		var x: Transform3D = k[1]
		anim.position_track_insert_key(rp, float(k[0]), x.origin)
		anim.rotation_track_insert_key(rr, float(k[0]), x.basis.get_rotation_quaternion())
	return anim


# --- the arms, cleaned (user 2026-09-30: "the reload animation, it's too jittery") ----------------------------------------
## The solver poses each frame on its own and shares the arm's turn between the shoulder, the elbow and the wrist as it
## finds it: frame to frame the share flipped (the elbow and the wrist 40-117 deg off the line through their neighbours,
## the hand itself steady). Rebuilt here as a body's arm moves (the reference motion: the elbow a pure hinge about its
## own axis, no twist; the forearm's roll in the wrist): each frame the hand (the wrist's place and turn, so the gun) is
## kept as solved, the elbow put where the solved elbows are, smoothed over ELBOW_SMOOTH frames (and set at the arm's
## length from the shoulder and the wrist), the upper arm pointed at it with the hinge across the arm's plane, the elbow
## bent about its hinge alone, and the wrist turned to the hand.
const ELBOW_SMOOTH := 2.0
const HAND_SMOOTH := 1.5
## The elbow's hinge in its own rest frame (the mocap clips' bend axis).
const ELBOW_HINGE := Vector3(-0.06, -1.0, 0.0)


func _clean_arms(sk: Skeleton3D, rot: Dictionary, posi: Dictionary) -> void:
	var n := (rot.values()[0] as Array).size()
	for s: String in ["r", "l"]:
		var sh := sk.find_bone(s + "_shoulder")
		var el := sk.find_bone(s + "_elbow")
		var wr := sk.find_bone(s + "_wrist")
		if sh < 0 or el < 0 or wr < 0 or not rot.has(s + "_shoulder") or not rot.has(s + "_elbow") or not rot.has(s + "_wrist"):
			continue
		var cl := sk.get_bone_parent(sh)
		var r_el := sk.get_bone_rest(el)
		var r_wr := sk.get_bone_rest(wr)
		var l1 := r_el.origin.length()
		var l2 := r_wr.origin.length()
		var d_u := r_el.origin.normalized()            # the upper arm's way, in its own frame
		var d_f := r_wr.origin.normalized()            # the forearm's, in the elbow's
		var hinge := ELBOW_HINGE.normalized()
		var hinge_u := (r_el.basis * hinge).normalized()   # the hinge in the upper arm's frame, the elbow at rest
		# the solved frames: the clavicle's place, the shoulder, the elbow and the wrist (skeleton space)
		var cg: Array[Transform3D] = []
		var sp: Array[Vector3] = []
		var ep: Array[Vector3] = []
		var wg: Array[Transform3D] = []
		for f in n:
			var c := _fk(sk, cl, rot, posi, f)
			var u := c * Transform3D(Basis(rot[s + "_shoulder"][f][1] as Quaternion), sk.get_bone_rest(sh).origin)
			var e := u * Transform3D(Basis(rot[s + "_elbow"][f][1] as Quaternion), r_el.origin)
			var w := e * Transform3D(Basis(rot[s + "_wrist"][f][1] as Quaternion), r_wr.origin)
			cg.append(c)
			sp.append(u.origin)
			ep.append(e.origin)
			wg.append(w)
		# the gun's own place (the hand's prop bone, solved: its path is the planned one, smooth), kept as it is below
		var prop: String = s + "_hand_prop_attachment"
		var palm := sk.find_bone(s + "_palm")
		var keep_prop := rot.has(prop) and posi.has(prop) and palm >= 0 and rot.has(s + "_palm")
		var prop_g: Array[Transform3D] = []
		if keep_prop:
			for f in n:
				prop_g.append(wg[f] * Transform3D(Basis(rot[s + "_palm"][f][1] as Quaternion), sk.get_bone_rest(palm).origin)
						* Transform3D(Basis(rot[prop][f][1] as Quaternion), posi[prop][f][1] as Vector3))
		# the hand's own path smoothed (the solver's hand shook too, and the gun with it): over HAND_SMOOTH frames, the
		# turn and the place, in the skeleton's space (the left hand on the gun is smoothed alike, so it stays on it)
		var wsm: Array[Transform3D] = []
		for f in n:
			var acc_p := Vector3.ZERO
			var acc_q := Vector4.ZERO
			var ref := wg[f].basis.get_rotation_quaternion()
			var ws0 := 0.0
			for k in range(maxi(0, f - 5), mini(n, f + 6)):
				var g := exp(-0.5 * pow(float(k - f) / HAND_SMOOTH, 2.0))
				var q := wg[k].basis.get_rotation_quaternion()
				if q.dot(ref) < 0.0:
					q = -q
				acc_p += wg[k].origin * g
				acc_q += Vector4(q.x, q.y, q.z, q.w) * g
				ws0 += g
			acc_q = acc_q.normalized()
			wsm.append(Transform3D(Basis(Quaternion(acc_q.x, acc_q.y, acc_q.z, acc_q.w)), acc_p / ws0))
		wg = wsm
		# the elbows smoothed, in the clavicle's frame (the body's own sway stays)
		var el_c: Array[Vector3] = []
		for f in n:
			el_c.append(cg[f].affine_inverse() * ep[f])
		for f in n:
			var acc := Vector3.ZERO
			var ws := 0.0
			for k in range(maxi(0, f - 6), mini(n, f + 7)):
				var g := exp(-0.5 * pow(float(k - f) / ELBOW_SMOOTH, 2.0))
				acc += el_c[k] * g
				ws += g
			var pole := cg[f] * (acc / ws)
			# the elbow at the arm's lengths, on the side of the smoothed one
			var a := sp[f]
			var w := wg[f].origin
			var aw := w - a
			var d := clampf(aw.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
			var ax := aw.normalized()
			var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
			var perp := (pole - a) - ax * (pole - a).dot(ax)
			perp = perp.normalized() if perp.length() > 1e-5 else (ep[f] - a - ax * (ep[f] - a).dot(ax)).normalized()
			var e := a + (ax * ca + perp * sqrt(1.0 - ca * ca)) * l1
			# the upper arm: its way to the elbow, the hinge across the arm's plane (the side the elbow bends to)
			var e1 := (e - a).normalized()
			var nrm := e1.cross((w - e).normalized()).normalized()
			var best := Basis()
			var best_q := Quaternion()
			var best_ok := false
			for sign in [1.0, -1.0]:
				var ub := _frame_to(d_u, hinge_u, e1, nrm * sign)
				var eb := ub * r_el.basis
				var tgt := (eb.inverse() * (w - e)).normalized()
				# the bend about the hinge carrying the forearm's way to the wrist
				var th := _signed(d_f, tgt, hinge)
				if th >= -0.05:
					best = ub
					best_q = Quaternion(hinge, th)
					best_ok = true
					break
			if not best_ok:
				continue
			var cb := cg[f].basis.orthonormalized()
			var u_local := (cb.inverse() * best).get_rotation_quaternion()
			var e_local := (r_el.basis.get_rotation_quaternion() * best_q).normalized()
			var fg := best * Basis(e_local)
			var w_local := (fg.orthonormalized().inverse() * wg[f].basis.orthonormalized()).get_rotation_quaternion()
			rot[s + "_shoulder"][f][1] = u_local
			rot[s + "_elbow"][f][1] = e_local
			rot[s + "_wrist"][f][1] = w_local
			if keep_prop:
				var pg := wg[f] * Transform3D(Basis(rot[s + "_palm"][f][1] as Quaternion), sk.get_bone_rest(palm).origin)
				var pl := pg.affine_inverse() * prop_g[f]
				rot[prop][f][1] = pl.basis.orthonormalized().get_rotation_quaternion()
				posi[prop][f][1] = pl.origin
		# (keyed rotations kept on one side of the sphere, frame to frame)
		for b in [s + "_shoulder", s + "_elbow", s + "_wrist", prop]:
			if not rot.has(b):
				continue
			var arr: Array = rot[b]
			for f in range(1, n):
				var q: Quaternion = arr[f][1]
				if (arr[f - 1][1] as Quaternion).dot(q) < 0.0:
					arr[f][1] = -q


## A basis taking the local pair (a, b) onto the pair (ta, tb) (each orthonormalized against its first).
static func _frame_to(a: Vector3, b: Vector3, ta: Vector3, tb: Vector3) -> Basis:
	var b1 := (b - a * b.dot(a)).normalized()
	var tb1 := (tb - ta * tb.dot(ta)).normalized()
	var src := Basis(a, b1, a.cross(b1))
	var dst := Basis(ta, tb1, ta.cross(tb1))
	return dst * src.inverse()


## The angle (rad) about `axis` from `v` to `t` (both projected on the plane across it).
static func _signed(v: Vector3, t: Vector3, axis: Vector3) -> float:
	var a := (v - axis * v.dot(axis)).normalized()
	var b := (t - axis * t.dot(axis)).normalized()
	return atan2(axis.dot(a.cross(b)), a.dot(b))


## A bone's skeleton-space transform at frame `f` of the sampled locals (the rest for bones not sampled).
func _fk(sk: Skeleton3D, b: int, rot: Dictionary, posi: Dictionary, f: int) -> Transform3D:
	var nm := sk.get_bone_name(b)
	var r := sk.get_bone_rest(b)
	var q: Quaternion = rot[nm][f][1] if rot.has(nm) else r.basis.get_rotation_quaternion()
	var o: Vector3 = posi[nm][f][1] if posi.has(nm) else r.origin
	var x := Transform3D(Basis(q), o)
	var par := sk.get_bone_parent(b)
	return x if par < 0 else _fk(sk, par, rot, posi, f) * x


## The fingers onto the carry's own grip over the reload's last FINGER_EASE seconds (user 2026-10-01: the hands "squeeze" the gun as
## the reload hands back to the carry: fading from the reload's fist to the carry's grip, the fingers passed through a looser hand
## on the way, 398 -> 213 -> 262 deg of curl on the right). Ending on the carry's grip, the fade-out has nothing left to change.
const FINGER_EASE := 0.3
const CARRY_GRIP := {"stand": "actor_b-p-rifle-run-arms", "crouch": "actor_b-p-rifle-crouch-run-arms"}


func _fingers_to_carry(sk: Skeleton3D, rot: Dictionary, t0: float, length: float) -> void:
	if t0 + length < TOTAL - 1e-3:
		return
	var lib := load("res://animations/Actor_B.res") as AnimationLibrary
	var cn: String = CARRY_GRIP.get(stance, CARRY_GRIP.stand)
	if not lib.has_animation(cn):
		cn = CARRY_GRIP.stand
	var carry := lib.get_animation(cn)
	for nm: String in rot:
		if not (nm.begins_with("l_") or nm.begins_with("r_")):
			continue
		if not ["thumb", "index", "middle", "ring", "pinky"].any(func(f: String) -> bool: return nm.contains(f)):
			continue
		var ci := carry.find_track(NodePath("Skeleton3D:" + nm), Animation.TYPE_ROTATION_3D)
		if ci < 0:
			continue
		var g: Quaternion = carry.rotation_track_interpolate(ci, 0.0).normalized()
		for k: Array in rot[nm]:
			var u := smooth((t0 + float(k[0]) - (TOTAL - FINGER_EASE)) / FINGER_EASE)
			if u > 0.0:
				var q: Quaternion = k[1]
				if q.dot(g) < 0.0:
					q = -q
				k[1] = q.slerp(g, u).normalized()
