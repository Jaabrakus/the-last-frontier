extends SceneTree
## Vaulting with a lit torch (user 2026-09-26: "fix the vault for the torch equip just sling the torch or unequip and
## equip when the animation is over"): the torch leaves the hand for the move, nothing falls to the ground, and it is
## back in the hand, lit, after the move (the long gun back in the left hand).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/traversal/test_vault_torch.gd
## "VAULT TORCH TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _initialize() -> void:
	for gait in ["run", "sprint"]:
		var h := VaultSpeedHarness.new(self)
		var info := {"held_before": false, "min_during": true, "moves": 0, "after": false, "lit": false, "side": "", "dropped": -1}
		h.setup = func(p: FrontierPlayer) -> void:
			p.torch.take_out(true)
			for i in 180:
				await physics_frame
			info.held_before = p.torch.holding()
		var watch := func() -> void:
			while h.player == null:
				await process_frame
			var seen := false
			while is_instance_valid(h.player):
				await physics_frame
				if not is_instance_valid(h.player) or h.player.torch == null:
					return
				var showing: bool = h.player.traversal != null and h.player.traversal.showing
				if showing:
					seen = true
					info.moves = int(info.moves) + 1
					if h.player.torch.holding():
						info.min_during = false
				elif seen:
					# the move is over: give the handoff time, then look (before the harness frees the player)
					for i in 150:
						await physics_frame
						if not is_instance_valid(h.player):
							return
					var pl := h.player
					info.after = pl.torch.holding()
					info.lit = pl.torch.holding() and pl.torch.held.lit
					info.side = str(pl.anim.torch_ik.side)
					info.dropped = root.find_children("*", "DroppedTorch", true, false).size()
					return
		watch.call()
		await h.run("wall70", gait)
		for i in 60:
			await physics_frame
		_check(bool(info.held_before), "%s: the torch lit in the hand before the vault" % gait)
		_check(int(info.moves) > 0, "%s: a vault played (%d ticks)" % [gait, int(info.moves)])
		_check(bool(info.min_during), "%s: the torch is out of the hand during the move" % gait)
		_check(bool(info.after) and bool(info.lit), "%s: back in the hand, lit, after the move" % gait)
		_check(int(info.dropped) == 0, "%s: nothing dropped on the ground (%d)" % [gait, int(info.dropped)])
		_check(str(info.side) == "r", "%s: the torch in the right hand (%s)" % [gait, str(info.side)])
		h.release_all()
	if _fails.is_empty():
		print("VAULT TORCH TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("VAULT TORCH TEST FAILED (%d of %d)" % [_fails.size(), _checks])
		quit(1)
