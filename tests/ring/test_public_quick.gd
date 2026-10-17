extends SceneTree
## The public (web) build's starting quick spells (MatchSetup.PUBLIC_QUICK; the owner, 2026-10-16: the browser game "feels nothing
## like" his: his left button holds the Boulder, the Kick, the Slice and the Whip): each is a real quick spell of its element (a
## move of its keys at one of its variations), so MatchSetup.quick_of can start a fresh profile on it.
##   Godot --headless --path . -s tests/ring/test_public_quick.gd
## Ends with "PUBLIC QUICK PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

func _init() -> void:
	var checks := 0
	var fails: Array[String] = []
	for el: String in Bending.ELEMENTS:
		var s := String(MatchSetup.PUBLIC_QUICK.get(el, ""))
		var id := s.get_slice("/", 0)
		var mode := s.get_slice("/", 1) if s.contains("/") else ""
		checks += 1
		var ok := s != "" and MatchSetup.quick_ok(el, id, mode)
		print(("  ok   " if ok else "  FAIL ") + "%s: %s is one of its quick spells" % [el, s])
		if not ok:
			fails.append(el)
	print(("PUBLIC QUICK PASSED (%d checks)" if fails.is_empty() else "PUBLIC QUICK FAILED (%d checks)") % checks)
	quit(0 if fails.is_empty() else 1)
