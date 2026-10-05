extends SceneTree
## The duel's hotbar (DuelMode.bar_now; the user, 2026-10-04: "we need to make the spells in the hotbar for the 1v1"; "remove
## the guns in 1v1 its just spells"): once the start's kit is placed, the bar is every spell and nothing else, the first
## readied with the hands free, and a spell slot readies its spell.
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_duel_bar.gd -- mode=duel

var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _go() -> void:
	for i in 20:
		await process_frame
	var p := current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(p != null and DuelMode.find(self) != null, "the level is a duel")
	for i in int((Hotbar.KIT_S + 1.0) * Engine.physics_ticks_per_second):
		await physics_frame
	var bar := Hotbar.of(p)
	var ok := true
	var line := PackedStringArray()
	var want := DuelMode.bar_now()
	for i in want.size():
		var e := bar.entry(i)
		line.append("%d %s" % [i + 1, String(e.get("id", "-"))])
		ok = ok and String(e.get("kind", "")) == String(want[i][0]) and String(e.get("id", "")) == String(want[i][1])
	for i in range(want.size(), Hotbar.SLOTS):
		ok = ok and not bar.filled(i)
	_expect(ok, "the bar: " + ", ".join(line) + ", the rest empty")
	var c0 := SwayCaster.of(p)
	_expect(p.hands_free and c0 != null and c0.readied_spell == String(want[0][1]), "no weapon in hand, the first readied (%s)" % (c0.readied_spell if c0 else "-"))
	_expect(not p.is_usable("musket") and not p.is_usable("pistol"), "the guns cannot be drawn")
	var c := SwayCaster.of(p)
	bar.take(2)                                  # (key 3: the earth's Pillar)
	await physics_frame
	_expect(c != null and c.readied_spell == String(want[2][1]), "key 3 readies %s (%s)" % [want[2][1], c.readied_spell if c else "no caster"])
	print("DUEL BAR " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)
