class_name ThrowableTomahawk
extends Throwable
## Tomahawk, thrown overhand with a locked wrist so it turns end over end: about one
## turn in the first four metres (13-14 ft, five or six paces), two turns at about
## eight, three at about twelve. It sticks only when the blade meets the target;
## otherwise the haft or the poll hits and it bounces off for a knock.
##
## Two heads from the same tomahawk.glb, identical in hand and in flight:
##   pipe = false  trade tomahawk with a spike on the poll: the common iron trade
##                 hatchet / belt axe of the 1750s frontier (default)
##   pipe = true   pipe tomahawk: a pipe bowl on the poll and a drilled haft, a prestige
##                 and diplomatic piece (recorded as early as 1700)
## Set `pipe` before ThrowableKit.install builds the model (ThrowableKit.create("tomahawk_pipe")
## does). Both hand back as ammo kind "tomahawk".
##
## `spin_assist` stands in for the thrower's judgement of distance: between
## `assist_range.x` and `assist_range.y` metres the spin is trimmed so a whole number
## of turns lands the blade first (1 = always, 0 = raw physics). Past that range it
## spins at its natural rate and sticking is luck. Close quarters (melee) is for later.

@export var pipe := false:
	set(v):
		pipe = v
		model_kind = "tomahawk_pipe" if v else "tomahawk"
		projectile_kind = model_kind
		display_name = "Pipe Tomahawk" if v else "Tomahawk"
@export var spin_assist := 1.0
@export var metres_per_turn := 4.2
@export var assist_range := Vector2(2.5, 15.0)
## Wind-up: the head drawn back over the shoulder (degrees from upright).
@export var cock_deg := 70.0


func _init() -> void:
	super()
	ammo_kind = "tomahawk"
	pipe = false               # Sets display_name, model_kind and projectile_kind.
	equip_time = 0.35
	move_speed_mult = 1.0
	windup_time = 0.35
	min_windup = 0.1
	release_time = 0.22
	follow_time = 0.484        # release_time * 2.2: the throw chain at one rate (Throwable.throw_anim_rate).
	draw_time = 0.5
	min_speed = 9.0
	max_speed = 14.0
	flight_gravity = 9.8
	flight_drag = 0.03
	min_damage = 45.0
	max_damage = 85.0
	count = 2
	max_count = 2
	spread_base = 0.5
	spread_move = 2.5
	spread_undercharge = 2.5
	aim_in_time = 0.2          # THROW2 review: the graph's aim request fade (0.2 s), which the aim-in adds to
	# THROW2 (user playtest 2026-09-25: "held like a pistol"): carried like a hatchet, the fist round the
	# haft, head up, blade forward. The carry grip is Actor_B's knife ready grip (the first frame of
	# atk-actor_b-knife-v-thug-hit1-intro, saber_model.md 3.5; the graph table's carry_overrides lay it on
	# the hand with the machete carry arm), and the model turns with the fist: its haft (+Y, towards the
	# head) along the grip's finger channel (prop +Y), its cutting edge (-Z) on the finger side (prop -Z),
	# the fist 6.2 cm above the haft end (the model origin). Axes measured on the knife clips in the prop
	# frame (saber_model.md 3.2: grip axis (+0.105, +0.994, -0.022), finger side (+0.33, -0.06, -0.94)).
	carry_in_fist = true
	fist_basis = Basis(Vector3(0.9376, -0.0916, 0.3353), Vector3(0.105, 0.994, -0.022), Vector3(-0.331, 0.060, 0.942)).orthonormalized()
	grip_clip_carry = "atk-actor_b-knife-v-thug-hit1-intro"
	grip_sample_carry = 0.0
	carry_rot_deg = Vector3(-130.0, 0.0, 0.0)   # Unused with carry_in_fist (the pre-THROW2 carry: haft forward and down).
	aim_tilt_deg = cock_deg
	# Draw / take the next one from the back of the belt (the graph table's action_overrides: the
	# thrown-object draw molotov-pack-draw; this table is documentation, PlayerAnim reads the graph).
	clips["equip"] = "actor_b-p-molotov-draw^idle--part"
	clips["draw"] = "actor_b-p-molotov-draw^idle--part"
	clips["hands"] = "actor_b-p-fingers-brick"
	clips["hands_carry"] = "atk-actor_b-knife-v-thug-hit1-intro"
	# THROW2 review: at the belt (the start of the draw, the end of the put-away) the fist is turned thumb
	# down, which laid the head into the right hip and buttock; the haft stands up (and out to the right and
	# back) in the hand there instead, the edge to the rear, handing over to the carry over the middle of the
	# draw (0.25-0.75; the put-away runs it backwards).
	switch_path = SwitchPath.STOW
	switch_blend = Vector2(0.25, 0.75)
	stow_up = Vector3(0.4, 0.85, -0.3)
	stow_edge = Vector3(0.0, 0.0, -1.0)
	# THROW2 fix 2: the stood-up tomahawk shows once the fist is at the back of the belt. The throw cycle's next
	# tomahawk is drawn from the follow-through: the fist sweeps across the front of the belly to the side of the
	# hip and never gets behind it, where the stood-up haft put the head in the chest; it shows in the fist from
	# the middle of that draw instead.
	stow_behind = 0.08


## The head swings from over the shoulder to upright as the arm comes through.
func _release_swing_deg(u: float) -> float:
	return -cock_deg * clampf(u, 0.0, 1.0)


## Leaves the hand upright, blade toward the target (the orientation it sticks in after
## whole turns).
func _launch_basis(dir: Vector3) -> Basis:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 1e-4:
		flat = -player.global_basis.z
	return Basis.looking_at(flat.normalized(), Vector3.UP)


func _configure_projectile(p: ThrownProjectile, origin: Vector3, dir: Vector3, speed: float) -> void:
	p.flight = ThrownProjectile.Flight.SPINNING
	p.spin_rate = spin_for(origin, dir * speed)
	p.edge_window_deg = 50.0
	p.stick_speed = 5.0
	p.stick_depth = 0.035
	p.blunt_damage = 12.0
	p.restitution = 0.35
	p.whoosh_pitch = 0.5
	p.impact_gain = 3.0


## Spin (rad/s) for a throw leaving `origin` with velocity `vel`.
func spin_for(origin: Vector3, vel: Vector3) -> float:
	var natural := TAU * vel.length() / metres_per_turn
	if spin_assist <= 0.0 or player == null:
		return natural
	var excl: Array[RID] = [player.get_rid()]
	var hit := ThrownProjectile.predict_impact(player.get_world_3d(), origin, vel, flight_gravity, flight_drag, excl)
	if hit.is_empty():
		return natural
	var t: float = hit.time
	var dist := origin.distance_to(hit.point)
	if t < 0.05 or dist < assist_range.x or dist > assist_range.y:
		return natural
	var turns := maxf(roundf(natural * t / TAU), 1.0)
	return lerpf(natural, TAU * turns / t, clampf(spin_assist, 0.0, 1.0))
