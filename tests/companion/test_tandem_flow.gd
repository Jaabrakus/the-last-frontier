extends SceneTree
## The yoga together through the household's TandemLink on the real level (the stand-in body, the lead's and partner's poses): for
## each pose (yoga, puppy) and each leader (spouse, player) the pair connects, then the pose ends and her own body is back.
##   Godot --headless --path . -s tests/companion/test_tandem_flow.gd -- survival=on
var fails := 0


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 300:
		await physics_frame
	var h := Household.find(self)
	var p: FrontierPlayer = current_scene.get_node_or_null("Player")
	if h == null or h.sc == null or h.body == null or p == null:
		print("NO HOUSEHOLD")
		quit(1)
		return
	p.ignore_mouse_capture = true
	var link := h.link
	link._bind(h.sc)
	for pose in ["yoga", "puppy"]:
		for who in ["spouse", "player"]:
			if pose == "yoga" and who == "player":
				continue        # (the player's own Happy Baby is started by the player's keys: not driven from here)
			# she stands beside the player
			h.body.global_position = p.global_position + (-p.global_basis.z) * 1.6 + Vector3.UP * 0.1
			await physics_frame
			link.prewarm()
			await physics_frame
			link._begin_pose(pose, who)
			var ok := false
			var waited := false
			for i in 900:
				await physics_frame
				link._start_tick(1.0 / 60.0)
				if who == "spouse" and link._waiting_join:
					waited = true
					break
				if link._paired():
					ok = true
					break
			if who == "spouse":
				_c(waited and not link._paired(), "%s led by her: she holds the pose and waits, the player is not taken in" % pose)
				var pt := TandemProxy.controller_of(p)
				for i in 1200:
					await physics_frame
					link._start_tick(1.0 / 60.0)
					if i % 10 == 0:
						if pose == "puppy":
							var ev := InputEventKey.new()
							ev.physical_keycode = KEY_I
							ev.pressed = true
							link._unhandled_input(ev)
						else:
							pt.join_nearby()
					if link._paired():
						ok = true
						break
			_c(ok, "%s led by %s: the pair connects (stand-in %s)" % [pose, who, "shown" if is_instance_valid(link.proxy) and link.proxy.visible else "hidden"])
			if ok and pose == "puppy" and is_instance_valid(link._pup_pair):
				var pp = link._pup_pair
				var spot: Vector3 = pp.player.global_position + pp.player.skeleton.get_parent().global_basis * pp.partner_offset
				var d := Vector2(pp.partner.global_position.x - spot.x, pp.partner.global_position.z - spot.z).length()
				_c(d < 0.15, "puppy by %s: the partner kneels in her place behind her (%.2f m off)" % [who, d])
				var tp: Node = p.get_node("TandemPoses")
				if who == "spouse":
					await physics_frame
					_c(tp._pair_mode() == "puppy" and tp._pair_stamina().x >= 0.0, "puppy behind her: the pair's stamina bars show (%s)" % [tp._pair_stamina()])
					_c(tp._keys != null and tp._keys.visible and tp._keys.text.contains("behind her"), "puppy behind her: the keys are on screen")
					var s0: float = pp.partner_stamina
					pp.react()
					_c(pp.partner_stamina < s0, "puppy: K costs the partner stamina (%.0f -> %.0f)" % [s0, pp.partner_stamina])
			if ok:
				_c(is_instance_valid(link.proxy) and link.proxy.visible and not h.body.visible, "%s by %s: the stand-in is shown and she is put away" % [pose, who])
			link._stop_poses()
			link._park_end()
			for i in 120:
				await physics_frame
			_c(h.body.visible, "%s by %s: her own body is back" % [pose, who])
	print("TANDEM FLOW TEST ", "FAILED" if fails > 0 else "PASSED")
	quit(1 if fails > 0 else 0)


func _c(ok: bool, what: String) -> void:
	print("  ", "ok  " if ok else "FAIL", " ", what)
	if not ok:
		fails += 1
