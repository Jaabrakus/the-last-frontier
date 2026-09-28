extends "res://features/tandem/demo.gd"
## First player holds crawl, invites with I; second player accepts with ENTER.
## Only this pair is visible. Switch back to Happy Baby + Plank with the UI button.

const CRAWL_GLB := preload("res://features/tandem/actor_b_crawl.glb")
const KNEEL_GLB := preload("res://features/tandem/actor_b_kneel.glb")

@export_group("Crawl partner placement")
## Local X is across the body; negative Z is behind the crawling player.
## Both actors share ground height (Y = 0).
@export var crawl_partner_offset := Vector3(0, 0, -0.30):
	set(value):
		crawl_partner_offset = value
		if is_instance_valid(crawl_pair):
			crawl_pair.partner_offset = value
@export_range(-180.0, 180.0, 1.0) var crawl_partner_rotation_degrees := 0.0:
	set(value):
		crawl_partner_rotation_degrees = value
		if is_instance_valid(crawl_pair):
			crawl_pair.partner_yaw = deg_to_rad(value)

## Delay between the kneeling flinch and the crawling player's response.
@export_range(0.0, 1.0, 0.01) var crawl_response_delay := 0.15:
	set(value):
		crawl_response_delay = value
		if is_instance_valid(crawl_pair):
			crawl_pair.crawl_response_delay = value

var crawl: TandemCrawlHold
var kneel: TandemKneelPose
var crawl_pair: TandemCrawlPair
var _auto_started := false


func _ready() -> void:
	auto = "--auto" in OS.get_cmdline_user_args()
	for binding: Array in [["tandem_crawl_hold", KEY_C], ["tandem_crawl_invite", KEY_I],
		["tandem_plank_dip", KEY_ENTER], ["tandem_plank_leave", KEY_BACKSPACE],
		["tandem_crawl_hit", KEY_F], ["tandem_crawl_backward", KEY_B], ["tandem_kneel_flinch", KEY_K]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var event := InputEventKey.new()
			event.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0], event)
	_stage()
	var camera := get_viewport().get_camera_3d()
	camera.position = Vector3(1.0, 1.75, 3.4)
	camera.look_at(Vector3(-0.35, 0.45, 0))
	var first := _mat(Vector3.ZERO, Color(0.9, 0.55, 0.35), CRAWL_GLB, Vector2(3.2, 0.9))
	var second := _mannequin(Vector3.ZERO, Color(0.35, 0.6, 0.85), KNEEL_GLB)
	crawl = TandemCrawlHold.new()
	crawl.anim_player = first.animation_player
	crawl.backward_clip = preload("res://features/tandem/crawl_backward_flinch.tres")
	crawl.drain_hold = 0.0
	crawl.recover_while_holding = true
	crawl.regain = 3.0
	crawl.rest_s = 0.75
	first.add_child(crawl)
	kneel = TandemKneelPose.new()
	kneel.anim_player = second.animation_player
	kneel.auto_start = false
	second.add_child(kneel)
	crawl_pair = TandemCrawlPair.new()
	crawl_pair.base_actor = first
	crawl_pair.base_hold = crawl
	crawl_pair.partner_actor = second
	crawl_pair.partner_pose = kneel
	crawl_pair.partner_offset = crawl_partner_offset
	crawl_pair.partner_yaw = deg_to_rad(crawl_partner_rotation_degrees)
	crawl_pair.crawl_response_delay = crawl_response_delay
	add_child(crawl_pair)
	crawl_pair.invitation_changed.connect(func(pending: bool):
		if pending:
			_flash("INVITE SENT"))
	crawl_pair.partner_joined.connect(func(): _flash("PARTNER JOINED"))
	crawl_pair.partner_left.connect(func(): _flash("PARTNER LEFT"))
	crawl.flinched.connect(func(cause: String): _flash("BACKWARD FLINCH" if cause == "backward" else "CRAWL FLINCH"))
	kneel.flinched.connect(func(): _flash("KNEEL FLINCH"))
	_ui()
	legend.text = "C: crawl    I: invite    ENTER: accept    BACKSPACE: leave    K: paired flinch    F: flinch    B: backward"


func _process(delta: float) -> void:
	clock += delta
	if auto:
		if clock > 1.0 and not _auto_started:
			crawl.start_hold()
			_auto_started = true
		if clock > 2.0 and clock - delta <= 2.0:
			crawl_pair.invite()
		if clock > 3.0 and clock - delta <= 3.0:
			crawl_pair.try_join()
		if clock > 7.0 and clock - delta <= 7.0:
			crawl_pair.request_partner_flinch()
		if clock > 10.0 and clock - delta <= 10.0:
			crawl.flinch()
		if clock > 14.0:
			crawl.let_go()
		if clock > 16.0:
			get_tree().quit()
	else:
		if Input.is_action_just_pressed("tandem_crawl_hold"):
			crawl.start_hold()
		if Input.is_action_just_released("tandem_crawl_hold"):
			crawl.let_go()
		if Input.is_action_just_pressed("tandem_plank_leave"):
			crawl_pair.leave()
		else:
			if Input.is_action_just_pressed("tandem_crawl_invite") and not crawl_pair.invite():
				_flash("HOLD C TO INVITE")
			if Input.is_action_just_pressed("tandem_plank_dip") and not crawl_pair.try_join():
				_flash("WAIT FOR AN INVITE")
		if Input.is_action_just_pressed("tandem_crawl_hit"):
			crawl.flinch()
		if Input.is_action_just_pressed("tandem_crawl_backward"):
			crawl.flinch_backward()
		if Input.is_action_just_pressed("tandem_kneel_flinch"):
			crawl_pair.request_partner_flinch()
	var state := "FLINCH" if crawl.is_flinching() else ("HOLD" if crawl.holding else "READY - hold C")
	status.text = "Crawl: %s    stamina %d%%" % [state, roundi(crawl.stamina / crawl.stamina_max * 100)]
	bar.value = crawl.stamina / crawl.stamina_max * 100
	pbar.value = kneel.stamina / kneel.stamina_max * 100
	if crawl_pair.occupied:
		pstatus.text = "Partner: KNEEL BEHIND" + (" - FLINCH" if kneel.is_flinching() else "")
	elif crawl_pair.invitation_pending:
		pstatus.text = "Partner: invited - ENTER to accept"
	elif crawl.holding:
		pstatus.text = "Partner: press I to invite"
	else:
		pstatus.text = "Partner: waiting for crawl"
	pstatus.text += "    stamina %d%%" % roundi(kneel.stamina / kneel.stamina_max * 100)
	flash_left -= delta
	flash.modulate.a = clampf(flash_left, 0.0, 1.0)


func _other_tandem_label() -> String:
	return "Switch to Happy Baby + Plank"


func _other_tandem_scene() -> String:
	return "res://features/tandem/demo.tscn"
