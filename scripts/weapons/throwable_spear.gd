class_name ThrowableSpear
extends Throwable
## Throwing spear, thrown overhand like a javelin. Heavy and deadly up close, slow
## to wind up, with a pronounced arc past twenty metres; two are carried (one in
## hand, one slung). It flies point first and sticks in wood, straw, targets and
## soft ground; a glancing hit or stone skips it off.
##
## Numbers: experimental hand-thrown spears leave the hand at roughly 12-20 m/s and
## still hit hard out to about 20 m (design doc section 1 has the sources); here a
## quick throw is 13 m/s and a full wind-up 22 m/s.


func _init() -> void:
	super()
	display_name = "Throwing Spear"
	ammo_kind = "spear"
	model_kind = "spear"
	projectile_kind = "spear"
	equip_time = 0.6
	move_speed_mult = 0.95
	windup_time = 0.55
	min_windup = 0.15
	release_time = 0.25
	follow_time = 0.55
	draw_time = 0.9
	min_speed = 13.0
	max_speed = 22.0
	flight_gravity = 9.8
	flight_drag = 0.012
	min_damage = 60.0
	max_damage = 130.0
	count = 2
	max_count = 2
	spread_base = 0.35
	spread_move = 3.0
	spread_undercharge = 3.5
	# THROW2 (user playtest 2026-09-25: "hold it above the shoulder"): the overhand javelin carry, the hand
	# above the shoulder (the graph table's carry_overrides: the throw raise's middle key on the arm),
	# the spear level with its point forward.
	carry_rot_deg = Vector3(-3.0, 0.0, 0.0)
	# THROW2 fix 2: with the arm lowered in front (sprinting: the graph's pick-up sprint arm; landings) the spear
	# is held across the body: the point 5 deg up and 55 deg across to the left, the butt out to the right past
	# the right hip. The review build's port (38 deg up, 22 across) put the butt through the right thigh in a
	# diagonal sprint and the point through the head in a jump. It fades back to level as the fist goes behind the
	# shoulder (a jump's arm swing) and swings in and out over 0.25 s (it snapped in one frame at a take-off); the
	# carry (level and across) turns with 0.4 of the hips' yaw, low-passed over 0.15 s, so it follows the body into
	# strafes and diagonal runs (tests/anim/test_throw_carry.gd measures every direction bank, jumps and drops).
	carry_low_rot_deg = Vector3(5.0, 55.0, 0.0)
	carry_low_band = Vector2(0.05, 0.17)
	carry_low_back = Vector2(0.05, 0.2)
	carry_low_time = 0.25
	carry_follow_hips = 0.4
	carry_follow_time = 0.15
	aim_tilt_deg = 0.0                          # Along the throw line.
	# THROW2 review: a switch draws the spear like the long gun whose draw it plays: slung on the back from
	# its balance point, then along the gun's path (swung over the left shoulder, across the body) held near
	# its butt (0.9 m behind the balance point, the butt end 0.09 m past the hand; THROW2 fix 2: the review
	# build's 0.8 m came in after the swing had passed the head, with the rear 0.8 m of the shaft past the neck)
	# until the right hand has it, then turned from the gun's line into the carry and slid through the hand to the
	# balance point over the second half of the draw. A holster runs it backwards. Crouched the gun's own path
	# goes through the lap: the hold is 0.95 m (the butt end 0.04 m past the hand). A draw that never takes the
	# gun to the sling (the throw cycle's next spear; crouched draws after the pistol or the atlatl) shows the
	# spear in the hand from mid-draw, crouched once the fist is up near the shoulder.
	switch_path = SwitchPath.SOURCE
	switch_blend = Vector2(0.55, 1.0)
	source_near = Vector2(0.06, 0.15)
	source_hold = 0.9
	source_hold_in = Vector2(0.15, 0.3)
	source_hold_crouch = 0.95
	source_fallback_from = 0.5
	source_fallback_drop_crouch = 0.12
	# The graph's draw for the spear (PlayerAnim reads the graph table; this table is documentation):
	# the long-gun draw from the back (spear pair slung on the back, loadout_design.md 5.2).
	clips["draw"] = "actor_b-lg-stealth-draw^idle--arm-r"
	clips["equip"] = "actor_b-lg-stealth-draw^idle--arm-r"


func _configure_projectile(p: ThrownProjectile, _origin: Vector3, _dir: Vector3, _speed: float) -> void:
	p.flight = ThrownProjectile.Flight.POINT_FIRST
	p.stick_speed = 7.0
	p.stick_depth = 0.14             # Straw, soft ground.
	p.stick_depth_wood = 0.06        # A forged point bites a few centimetres into timber.
	p.stick_max_incidence_deg = 70.0
	p.blunt_damage = 15.0
	p.whoosh_pitch = 0.62
	p.impact_gain = 3.2
