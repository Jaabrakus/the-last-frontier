extends SceneTree
## Drives tests/horse/ride_demo.tscn with simulated input and saves gameplay-camera
## screenshots (needs a window):
##
##   Godot --path . --resolution 1280x720 -s tests/horse/ride_demo_shots.gd -- out=/tmp/ride
##
## Sequence: cruise trot from a stand, spur to canter and gallop, hold sprint, steer left,
## jump, stop, rear. Prints the gait timeline and fails if a phase is not reached.

var out := "user://ride_demo_shots"
var fails := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://tests/horse/ride_demo.tscn")
	await _phys(10)
	var demo := current_scene
	var horse: Horse = demo.horse
	horse.gait_changed.connect(func(o: int, n: int) -> void:
		print("  t=%.2f s  %s -> %s at %.2f m/s" % [Time.get_ticks_msec() / 1000.0, Horse.GAIT_CLIPS[o], Horse.GAIT_CLIPS[n], horse.speed]))
	await _shot("00_idle")
	Input.action_press("move_forward")
	await _phys(360)
	await _shot("01_trot")
	_expect(horse.gait == Horse.Gait.TROT, "trot after 3 s of W (got %s)" % Horse.GAIT_CLIPS[horse.gait])
	await _tap("sprint")
	await _phys(300)
	await _shot("02_canter")
	_expect(horse.gait == Horse.Gait.CANTER, "canter after one spur (got %s)" % Horse.GAIT_CLIPS[horse.gait])
	await _tap("sprint")
	await _phys(360)
	await _shot("03_gallop")
	_expect(horse.gait == Horse.Gait.GALLOP, "gallop after two spurs (got %s)" % Horse.GAIT_CLIPS[horse.gait])
	Input.action_press("sprint")
	await _phys(360)
	await _shot("04_sprint")
	_expect(horse.gait == Horse.Gait.SPRINT, "sprint while holding Shift at gallop (got %s)" % Horse.GAIT_CLIPS[horse.gait])
	Input.action_release("sprint")
	Input.action_press("move_left")
	await _phys(180)
	await _shot("05_turn_gallop")
	Input.action_release("move_left")
	await _phys(120)
	await _tap("jump")
	await _phys(70)
	await _shot("06_jump_air")
	_expect(horse.one_shot == "jump", "jump one-shot playing")
	await _phys(200)
	Input.action_release("move_forward")
	await _phys(900)
	_expect(horse.gait == Horse.Gait.IDLE, "back to idle after releasing W (got %s)" % Horse.GAIT_CLIPS[horse.gait])
	await _tap("jump")
	await _phys(250)
	await _shot("07_rear")
	_expect(horse.one_shot == "rear", "rear from a stand")
	Input.action_press("move_right")
	await _phys(700)
	await _shot("08_turn_in_place")
	Input.action_release("move_right")
	print("RIDE DEMO %s %s" % ["OK" if fails.is_empty() else "FAILED", fails])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		fails.append(msg)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _phys(2)
	Input.action_release(action)


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)
