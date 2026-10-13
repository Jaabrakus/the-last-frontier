extends SceneTree
## The lobby's Play online (MainMenu._open_online; RingNet, docs/tidebreak/ring_netcode.md), headless, no ring loaded (the
## menu's launch goes to MainMenu.launch_hook):
##   Godot --headless --path . -s tests/net/test_ring_net_menu.gd
##   the row       "Play online" in the rundown under Practice, Your look still the last row (the keys' Up from the foot)
##   the screen    Host a match (this machine's addresses on its line), the address field (the last one joined, else
##                 127.0.0.1), Join
##   Host          into the ring (the hook: RING_SCENE) as a 1 v 1 match, RingNet.incoming the host's on its port
##   Join          the address typed kept for next time, into the ring as a 1 v 1 match, RingNet.incoming a join of it
## Last line "RING NET MENU PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

const OWN_CFG := "user://ring_net_menu_test.cfg"

var checks := 0
var fails: Array[String] = []
var launched: Array = []


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RING NET MENU FAILED (watchdog)")
		quit(2))
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RingNet.address_cfg()))
	GameSettings.path = OWN_CFG
	MainMenu.launch_hook = func(p: String) -> void: launched.append(p)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(8)
	var m := current_scene as MainMenu
	check(m != null, "the main menu")
	if m == null:
		return _end()
	# ---- the row
	var rows: Array = []
	for c in m._items.get_children():
		if c is Button:
			rows.append(c)
	var names := rows.map(func(b: Node) -> String: return String(b.name))
	var online := m._items.find_child("Online", true, false) as Button
	var practice_i := names.find("Practice")
	check(online != null and names.find("Online") == practice_i + 1 and String(names.back()) == "YourLook",
			"Play online under Practice, Your look still last (%s)" % str(names))
	# ---- the screen
	m._open_online()
	await frames(2)
	var host := m._panel.find_child("HostOnline", true, false) as Button
	var addr := m._panel.find_child("OnlineAddress", true, false) as LineEdit
	var join := m._panel.find_child("JoinOnline", true, false) as Button
	check(host != null and addr != null and join != null and addr.text == "127.0.0.1",
			"Host a match, the address field (%s), Join" % [addr.text if addr else "none"])
	# ---- Host
	MatchSetup.format = "2v2"
	launched.clear()
	host.pressed.emit()
	await frames(2)
	check(launched == [MainMenu.RING_SCENE] and String(RingNet.incoming.get("role", "")) == "host"
			and int(RingNet.incoming.get("port", 0)) == RingNet.PORT and MatchSetup.format == "1v1" and MatchSetup.incoming,
			"Host: into the ring as a 1 v 1, hosting on port %d (%s)" % [RingNet.PORT, str(RingNet.incoming)])
	RingNet.incoming = {}
	MatchSetup.incoming = false
	# ---- Join
	m._open_online()
	await frames(2)
	addr = m._panel.find_child("OnlineAddress", true, false) as LineEdit
	join = m._panel.find_child("JoinOnline", true, false) as Button
	addr.text = "192.168.1.20"
	launched.clear()
	join.pressed.emit()
	await frames(2)
	check(launched == [MainMenu.RING_SCENE] and String(RingNet.incoming.get("role", "")) == "join"
			and String(RingNet.incoming.get("address", "")) == "192.168.1.20" and MatchSetup.format == "1v1",
			"Join: into the ring as a 1 v 1, joining 192.168.1.20 (%s)" % str(RingNet.incoming))
	check(RingNet.last_address() == "192.168.1.20", "the address kept for next time (%s)" % RingNet.last_address())
	RingNet.incoming = {}
	MatchSetup.incoming = false
	_end()


func _end() -> void:
	MainMenu.launch_hook = Callable()
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RingNet.address_cfg()))
	if fails.is_empty() and checks > 0:
		print("RING NET MENU PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET MENU FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
