class_name FlintlockPistol
extends Firearm
## Flintlock pistol. Quick to bring up and deadly up close, inaccurate past
## twenty paces, and still a single shot with a slow reload.


func _init() -> void:
	super()
	display_name = "Flintlock Pistol"
	hand = Hand.RIGHT
	equip_time = 0.3
	move_speed_mult = 1.0
	damage = 70.0
	muzzle_speed = 190.0
	ball_drag = 0.45
	hang_fire = 0.07
	recoil_pitch_deg = 4.0
	recoil_yaw_deg = 1.2
	smoke_scale = 0.75
	pan_distance = 0.22
	reserve = 10
	spread_base = 0.9
	spread_move = 2.0
	spread_air = 5.0
	crouch_mult = 0.75
	aim_mult = 0.6
	fire_bloom = 2.0
	aim_fov_mult = 0.9
	aim_speed_mult = 0.7
	aim_yaw_offset_deg = 3.5
	aim_pitch_offset_deg = 7.6
	aim_yaw_offset_crouch_deg = 2.1
	aim_pitch_offset_crouch_deg = 10.2
	aim_in_time = 0.2
	aim_out_time = 0.25
	spread_unaimed = 4.0
	# anim-overlay-player-weapon-base-pistol layers (right arm + weight).
	relaxed = {
		"idle": ["actor_b-r-arm-gun-idle", 1.0],
		"walk": ["actor_b-r-arm-gun-idle", 0.5],
		"run": ["actor_b-r-arm-gun", 0.7],
		"sprint": ["actor_b-r-arm-gun", 0.7],
		"crouch_idle": ["actor_b-r-arm-gun-crouch-idle", 1.0],
		"crouch_walk": ["actor_b-r-arm-gun-crouch-idle", 0.5],
	}
	reload_stages = [
		["reload_begin", 0.8, "Half-cocking"],
		["reload_mid", 1.2, "Powder and ball"],
		["reload_end", 0.9, "Priming the pan"],
	]
	clips = {
		# Hand + prop-bone layer over the aim pose (places the weapon in the hands).
		"aim_walk": "actor_b-p-pistol-aim-walk",
		"aim_walk_crouch": "actor_b-p-pistol-aim-crouch-walk",
		"hands": "actor_b-pistol-aim--hands",
		"hands_crouch": "actor_b-pistol-aim--hands",
		"aim": "actor_b-p-pistol-aim-idle",
		"aim_crouch": "actor_b-p-pistol-aim-idle-crouch",
		"up": "actor_b-p-pistol-aim-up",
		"down": "actor_b-p-pistol-aim-down",
		"up_crouch": "actor_b-p-pistol-aim-crouch-up",
		"down_crouch": "actor_b-p-pistol-aim-crouch-down",
		"fire": "actor_b-p-pistol-fire--add",
		"reload_begin": "actor_b-p-pistol-rev-reload-begin--part",
		"reload_mid": "actor_b-p-pistol-rev-reload-mid--part",
		"reload_end": "actor_b-p-pistol-rev-reload-over--part",
	}
