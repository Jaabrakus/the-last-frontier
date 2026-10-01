class_name Musket
extends Firearm
## Smoothbore flintlock musket. One heavy, accurate shot when standing still
## or crouched, then a long, exposed reload: bite the cartridge, prime the pan,
## pour powder down the barrel, ram the ball, return the rod. The reload's own
## animation, the ramrod, the cartridge and the lock: MusketReload (a child).


func _ready() -> void:
	var r := MusketReload.new()
	r.name = "Reload"
	r.gun = self
	add_child(r)


func _init() -> void:
	super()
	display_name = "Flintlock Musket"
	hand = Hand.RIGHT
	equip_time = 0.7
	move_speed_mult = 0.92
	damage = 120.0
	muzzle_speed = 320.0
	ball_drag = 0.25
	hang_fire = 0.1
	recoil_pitch_deg = 5.5
	smoke_scale = 1.3
	pan_distance = 1.05
	reserve = 12
	spread_base = 0.15
	spread_move = 3.5
	spread_air = 9.0
	crouch_mult = 0.7
	aim_mult = 0.35
	fire_bloom = 2.5
	aim_fov_mult = 0.75
	fire_shake = 0.75         # (the heavy charge: a hard jolt that settles over a third of a second)
	fire_shake_s = 0.35
	aim_yaw_offset_deg = 4.9
	aim_pitch_offset_deg = 1.0
	aim_yaw_offset_crouch_deg = 4.4
	aim_pitch_offset_crouch_deg = 1.8
	aim_in_time = 0.35
	aim_out_time = 0.3
	spread_unaimed = 5.0
	# anim-overlay-player-weapon-base-long-gun layers (arms pose + weight).
	relaxed = {
		"idle": ["actor_b-p-rifle-run-arms", 1.0],
		"walk": ["actor_b-p-rifle-run-arms", 0.8],
		"run": ["actor_b-p-rifle-run-arms", 0.8],
		"sprint": ["actor_b-p-rifle-run-arms", 0.9],
		"crouch_idle": ["actor_b-p-rifle-crouch-idle-arms", 1.0],
		"crouch_walk": ["actor_b-p-rifle-crouch-run-arms", 0.8],
	}
	# 6.3 s in all (user 2026-09-29: "the timer is suppose to be like 6.3s"; it was 8.2 s, then 5.6 s for "20s for 3
	# fires"). Every step is MusketReload's own animation, time-scaled to these.
	reload_stages = [
		["reload_begin", 1.0, "Biting cartridge"],
		["reload_mid", 1.2, "Priming the pan"],
		["reload_mid", 1.4, "Pouring powder"],
		["reload_mid", 1.7, "Ramming ball"],
		["reload_end", 1.0, "Returning ramrod"],
	]
	clips = {
		# Hand + prop-bone layer over the aim pose (places the weapon in the hands).
		"aim_walk": "actor_b-p-rifle-aim-walk",
		"aim_walk_crouch": "actor_b-p-rifle-aim-crouch-walk",
		"hands": "actor_b-p-rifle-idle-aim--hands",
		"hands_crouch": "actor_b-p-rifle-aim-crouch-idle--hands",
		"aim": "actor_b-p-rifle-idle-aim",
		"aim_crouch": "actor_b-p-rifle-aim-crouch-idle",
		"up": "actor_b-p-rifle-idle-aim-up--add",
		"down": "actor_b-p-rifle-idle-aim-down--add",
		"up_crouch": "actor_b-p-rifle-idle-crouch-aim-up--add",
		"down_crouch": "actor_b-p-rifle-idle-crouch-aim-down--add",
		"fire": "actor_b-p-rifle-idle-aim-fire--add",
		"fire_crouch": "actor_b-p-rifle-idle-crouch-aim-fire--add",
		"reload_begin": "actor_b-p-rifle-idle-aim-reload-begin--part",
		"reload_begin_crouch": "actor_b-p-rifle-idle-crouch-aim-reload-begin--part",
		"reload_mid": "actor_b-p-rifle-idle-aim-reload-mid--part",
		"reload_mid_crouch": "actor_b-p-rifle-idle-crouch-aim-reload-mid--part",
		"reload_end": "actor_b-p-rifle-idle-aim-reload-over--part",
		"reload_end_crouch": "actor_b-p-rifle-idle-crouch-aim-reload-over--part",
		"equip": "actor_b-lg-stealth-draw^idle--arm-r",
	}
