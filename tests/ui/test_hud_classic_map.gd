extends SceneTree
## The classic HUD's map corner and chat (HudClassicMap: HudMinimap, MinimapBake, HudQuestTracker, HudChatLog; the owner
## 2026-10-03: "can the hud be similar to world of warcraft vanilla?") on the level with the survival rules, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_hud_classic_map.gd -- survival=on hud=classic
##
##   install   the classic style puts the minimap, the tracker and the chat on the HUD; the compass and the toasts at the
##             right step aside; a second install is the same one
##   bake      the map's picture bakes (threaded) over every square with ground, at MinimapBake.M_PER_PX; the river blue,
##             the closed woods dark green, the stockade's wall dark, the open meadow lighter; a second bake comes from the
##             cache, the same picture; the shader has it
##   follow    the map's middle is the player (moved: it follows within a tick), the shader's centre with it; ahead of the
##             view is up on the disc; the zoom steps in and out (the keys, clamped) and eases there
##   markers   the story's place (a gold diamond), a contact, fighters in COMBAT and SUSPICIOUS (not IDLE, not dead), the
##             horses that are the player's, read ten times a second into fixed arrays (no growth)
##   tracker   the mission (StoryHUD.set_mission) in the tracker: its title, step, count and the distance to its place;
##             StoryHUD's own lines step aside; "New mission" in the chat
##   log       a toast lands in the log ("+2 Firewood": loot), none at the right; a skill's level (rewritten as it rises);
##             a survival skill's whole level; an interactor notice; a line said nearby with the speaker's name, none from
##             far off; the same notice twice is one line
##   remove    the minimal HUD back: the compass, the toasts, StoryHUD's lines
## Ends with "HUD CLASSIC MAP TEST OK (<n> checks)" or "HUD CLASSIC MAP TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var hud: FrontierHUD
var m: HudClassicMap
var story: StoryDirector


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func settle(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await settle(30)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	hud = player.hud if player else null
	story = StoryDirector.find(self)
	check(hud != null and story != null, "the level has the HUD and the story director (survival=on)")
	if hud == null:
		_end()
		return
	player.ignore_mouse_capture = true
	await _test_install()
	if m == null:
		_end()
		return
	await _test_bake()
	await _test_follow()
	await _test_markers()
	await _test_tracker()
	await _test_log()
	await _test_remove()
	_end()


func _test_install() -> void:
	m = HudClassicMap.find(hud)
	check(ClassicSkin.is_classic() and m != null, "hud=classic: the map corner is on the HUD")
	if m == null:
		return
	check(m.minimap != null and m.tracker != null and m.chat != null, "the minimap, the quest tracker and the chat log")
	check(HudClassicMap.install(hud) == m, "a second install is the same one")
	var compass := hud.find_child("Compass", true, false) as Control
	check(compass != null and not compass.visible, "the minimal HUD's compass steps aside")
	check(not hud.toasts_shown, "the toasts at the right step aside")
	var sr := m.get_global_rect()                # (the screen: headless it has no size, the corners hold all the same)
	var mr := m.minimap.get_global_rect()
	check(absf(mr.end.x - (sr.end.x - HudClassicMap.MARGIN)) < 0.5 and absf(mr.position.y - sr.position.y) < 20.0,
			"the minimap at the top right (%s in %s)" % [mr, sr])
	var cr := m.chat.get_global_rect()
	check(absf(cr.position.x - (sr.position.x + HudClassicMap.MARGIN)) < 0.5 and absf(cr.end.y - (sr.end.y - HudClassicMap.MARGIN)) < 0.5,
			"the chat log at the bottom left (%s)" % cr)


func _test_bake() -> void:
	var b := m.minimap.bake
	b.wait()
	await settle(2)
	check(b.done and b.texture != null and b.image != null, "the map's picture is baked (%.0f ms%s)" % [b.ms, ", cached" if b.cached else ""])
	if not b.done:
		return
	var want := Vector2i(int(ceil(b.rect.size.x / MinimapBake.M_PER_PX)), int(ceil(b.rect.size.y / MinimapBake.M_PER_PX)))
	check(b.image.get_size() == want, "at %.0f m a pixel over every square (%s, %s)" % [MinimapBake.M_PER_PX, b.image.get_size(), b.rect])
	for sq in FrontierTerrain.squares():
		var o := FrontierTerrain.square_origin(sq)
		check(b.rect.has_point(Vector2(o.x, o.z)), "square %s is on it" % sq)
	# a fresh bake here (no cache): its time, and what lies where
	var fresh := MinimapBake.new()
	var t0 := Time.get_ticks_usec()
	fresh.start(false, false)
	print("  (a fresh bake: %.0f ms, %s)" % [(Time.get_ticks_usec() - t0) / 1000.0, fresh.image.get_size()])
	var img := fresh.image
	if WorldRiver.has_water():
		var z := 0.0
		var x := WorldRiver.x_at(z)
		var c := _px(fresh, Vector2(x, z))
		check(c.b > c.r + 0.05, "the river's middle is blue (%s)" % c)
	var meadow := Vector2(0, 22)          # (the fort's clearing outside its south wall, off the range lane: open ground)
	var wood := _densest(fresh)
	var cw := _px(fresh, wood)
	check(cw.g > cw.r and cw.get_luminance() < 0.33, "the closed woods dark green at %s (%s)" % [wood, cw])
	if not FrontierTerrain.open_ground:
		var cwall := _px(fresh, Vector2(FrontierStructures.FORT_HALF, 0.0))
		check(cwall.get_luminance() < 0.22, "the stockade's east wall a dark rule (%s)" % cwall)
		var cgate := _px(fresh, Vector2(0.0, -FrontierStructures.FORT_HALF))
		check(cgate.get_luminance() > 0.3, "the gate open in the north wall (%s)" % cgate)
	var cm := _px(fresh, meadow)
	check(cm.get_luminance() > cw.get_luminance() + 0.12, "the open ground lighter than the woods (%s)" % cm)
	# the cache: the same picture, loaded
	var again := MinimapBake.new()
	again.start(false, true)
	check(again.cached and again.image.get_size() == img.get_size(), "a second bake comes from the cache (%.0f ms)" % again.ms)
	var same := true
	for p: Vector2 in [Vector2(10, 10), Vector2(300, 120), Vector2(700, 300)]:
		if p.x < img.get_width() and p.y < img.get_height():
			same = same and img.get_pixelv(Vector2i(p)).is_equal_approx(again.image.get_pixelv(Vector2i(p)))
	check(same, "the cached picture is the baked one")
	var mat := m.minimap._map.material as ShaderMaterial
	check(mat.get_shader_parameter(&"map_tex") == b.texture, "the minimap's shader has the picture")


func _px(b: MinimapBake, xz: Vector2) -> Color:
	var uv := b.uv_of(xz)
	return b.image.get_pixel(clampi(int(uv.x * b.image.get_width()), 0, b.image.get_width() - 1),
			clampi(int(uv.y * b.image.get_height()), 0, b.image.get_height() - 1))


## The most closed wood near the fort (a point of forest_density ~1, off the river and the flat zones).
func _densest(b: MinimapBake) -> Vector2:
	var best := Vector2(-150, 150)
	var bd := -1.0
	for i in 20:
		for j in 20:
			var p := Vector2(-300.0 + i * 30.0, -300.0 + j * 30.0)
			var d := FrontierTerrain.forest_density(p.x, p.y)
			if d > bd and not FrontierTerrain.in_flat_zone(p.x, p.y):
				bd = d
				best = p
	return best


func _test_follow() -> void:
	var mm := m.minimap
	var to := Vector3(60.0, 0.0, 70.0)
	to.y = FrontierTerrain.height_at(to.x, to.z) + 0.1
	player.global_position = to
	player.velocity = Vector3.ZERO
	await settle(10)
	check(mm.centre.distance_to(Vector2(to.x, to.z)) < 1.5, "the map's middle follows the player (%s)" % mm.centre)
	var mat := mm._map.material as ShaderMaterial
	var cu: Vector2 = mat.get_shader_parameter(&"centre_uv")
	check(cu.distance_to(mm.bake.uv_of(mm.centre)) < 0.002, "the shader's centre with it (%s)" % cu)
	var ahead := mm.to_disc(mm.centre + mm.fwd * 40.0)
	check(absf(ahead.x) < 0.5 and ahead.y < -10.0, "ahead of the view is up on the disc (%s)" % ahead)
	var right := mm.to_disc(mm.centre + Vector2(-mm.fwd.y, mm.fwd.x) * 40.0)
	check(right.x > 10.0 and absf(right.y) < 0.5, "the view's right is right (%s)" % right)
	var cam := root.get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_basis.z
		check(Vector2(f.x, f.z).normalized().dot(mm.fwd) > 0.99, "the map turns with the camera's heading")
	var z0 := mm.zoom_i
	_key(KEY_EQUAL)
	check(mm.zoom_i == z0 - 1, "= zooms in")
	for i in 8:
		_key(KEY_MINUS)
	check(mm.zoom_i == HudMinimap.ZOOMS.size() - 1, "- zooms out, to the last step (%d)" % mm.zoom_i)
	await settle(40)
	check(absf(mm.radius_m - float(HudMinimap.ZOOMS[-1])) < 1.0, "and eases there (%.0f m)" % mm.radius_m)
	mm.zoom_i = HudMinimap.ZOOM_DEFAULT
	await settle(40)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	m.minimap._unhandled_key_input(e)


## A stand-in fighter: its marks are methods, as NpcFighter's are.
class Fighter extends Node3D:
	var st := "IDLE"
	var dead := false

	func state_name() -> String:
		return st

	func is_dead() -> bool:
		return dead


func _test_markers() -> void:
	var mm := m.minimap
	var base := player.global_position
	story.hud.marker_at = base + Vector3(30, 0, -20)
	var contact := Node3D.new()
	contact.add_to_group(StoryContact.CONTACTS)
	current_scene.add_child(contact)
	contact.global_position = base + Vector3(-10, 0, 5)
	var foes: Array[Fighter] = []
	for st: String in ["COMBAT", "SUSPICIOUS", "IDLE", "COMBAT"]:
		var f := Fighter.new()
		f.st = st
		f.add_to_group(NpcFighter.GROUP)
		current_scene.add_child(f)
		f.global_position = base + Vector3(15, 0, 15)
		foes.append(f)
	foes[3].dead = true
	mm._scan_t = 0.0
	await settle(12)
	check(mm.count_of(HudMinimap.Mark.STORY) == 1, "the story's place on the map")
	check(mm.count_of(HudMinimap.Mark.CONTACT) >= 1, "a contact's lantern")
	check(mm.count_of(HudMinimap.Mark.FOE) == 1 and mm.count_of(HudMinimap.Mark.WARY) == 1,
			"a fighter in COMBAT red, one SUSPICIOUS a ring, none IDLE or dead (%d, %d)" % [mm.count_of(HudMinimap.Mark.FOE),
			mm.count_of(HudMinimap.Mark.WARY)])
	var mounts := 0
	for n in get_nodes_in_group(HorseMount.GROUP):
		if n is HorseMount and (n as HorseMount).horse != null:
			mounts += 1
	check(mm.count_of(HudMinimap.Mark.HORSE) == mounts, "the player's horses (%d)" % mounts)
	var sp := mm.to_disc(Vector2(story.hud.marker_at.x, story.hud.marker_at.z))
	check(sp.length() > 1.0 and sp.length() < HudMinimap.DIAMETER, "the story's diamond lies on the disc (%s)" % sp)
	check(mm.mark_pos.size() == HudMinimap.MAX_MARKS and mm.mark_kind.size() == HudMinimap.MAX_MARKS, "the marker arrays do not grow")
	foes[0].st = "IDLE"
	await settle(10)
	check(mm.count_of(HudMinimap.Mark.FOE) == 0, "a fighter calmed: off the map")
	for f in foes:
		f.queue_free()
	contact.queue_free()
	story.hud.marker_at = null
	await settle(10)
	check(mm.count_of(HudMinimap.Mark.STORY) == 0 and mm.count_of(HudMinimap.Mark.CONTACT) == 0, "gone again")


func _test_tracker() -> void:
	var tr := m.tracker
	var at := player.global_position + Vector3(0, 0, -120)
	story.hud.set_mission("The Clearing", "Fell a pine by the fort", "1 / 3", [])
	story.hud.marker_at = at
	story.hud.marker_dist = -1.0
	await settle(12)
	check(tr.visible and tr._title.text == "THE CLEARING" and tr._text.text == "Fell a pine by the fort" and tr._count.text == "1 / 3",
			"the tracker shows the mission, its step and count (%s / %s / %s)" % [tr._title.text, tr._text.text, tr._count.text])
	check(absf(tr.dist - 120.0) < 3.0 and tr._way_text == "%d m" % roundi(tr.dist), "and the way to its place (%s)" % tr._way_text)
	check(story.hud.tracker_shown and not story.hud._title.visible and not story.hud._text.visible,
			"StoryHUD's own mission lines step aside")
	check(m.chat.last_text() == "New mission: The Clearing" and m.chat.last_kind() == "quest", "\"New mission\" in the chat (%s)" % m.chat.last_text())
	var tb := tr.get_global_rect()
	var mb := m.minimap.get_global_rect()
	check(tb.position.y >= mb.end.y - 0.5 and absf(tb.end.x - mb.end.x) < 12.0, "under the minimap, to its edge (%s / %s)" % [tb, mb])
	story.hud.marker_dist = 42.0
	await settle(8)
	check(tr._way_text == "42 m", "the step's own distance when it has one (%s)" % tr._way_text)
	story.hud.set_mission("", "", "", [])
	story.hud.marker_at = null
	await settle(8)
	check(not tr.visible, "no mission: no tracker")


func _test_log() -> void:
	var chat := m.chat
	var n0 := hud._toasts.get_child_count()
	hud.toast("+2 Firewood", "firewood")
	await settle(2)
	check(chat.last_text() == "+2 Firewood" and chat.last_kind() == "loot", "a toast lands in the log (%s, %s)" % [chat.last_text(), chat.last_kind()])
	check(hud._toasts.get_child_count() == n0, "and not at the right")
	hud.toast("Woodcutting 5", "ui:skill_woodcutting", "level:woodcutting")
	await settle(1)
	var n := chat.lines.size()
	hud.toast("Woodcutting 6  ·  Apprentice", "ui:skill_woodcutting", "level:woodcutting")
	await settle(1)
	check(chat.last_kind() == "skill" and chat.last_text() == "Woodcutting 6  ·  Apprentice" and chat.lines.size() == n,
			"a skill's level, rewritten as it rises (%s)" % chat.last_text())
	var b := SurvivalBridge.find(self)
	if b != null and b.core != null:
		b.core.skill_changed.emit("hunting", 11.9, 12.05)
		await settle(1)
		check(chat.last_kind() == "skill" and chat.last_text().begins_with("Your skill in ") and chat.last_text().ends_with("12"),
				"a survival skill's whole level (%s)" % chat.last_text())
		var before := chat.lines.size()
		b.core.skill_changed.emit("hunting", 12.05, 12.2)
		await settle(1)
		check(chat.lines.size() == before, "not a part of one")
	player.interactor.notice("The torch went out.")
	await settle(1)
	check(chat.last_text() == "The torch went out." and chat.last_kind() == "notice", "an interactor notice (%s)" % chat.last_text())
	var count := chat.lines.size()
	player.interactor.notice("The torch went out.")
	await settle(1)
	check(chat.lines.size() == count, "the same notice twice is one line")
	var near := Node3D.new()
	near.set_meta(&"display_name", "Leclerc")
	current_scene.add_child(near)
	near.global_position = player.global_position + Vector3(4, 0, 0)
	StoryBark.say(near, "Mind the river ice")
	await settle(1)
	var last: Dictionary = chat.lines.back()
	check(String(last.text) == "Mind the river ice" and String(last.kind) == "say" and String(last.who) == "Leclerc",
			"a line said nearby, with the speaker's name (%s: %s)" % [last.who, last.text])
	var far := Node3D.new()
	current_scene.add_child(far)
	far.global_position = player.global_position + Vector3(400, 0, 0)
	count = chat.lines.size()
	StoryBark.say(far, "Halloo the house!")
	await settle(1)
	check(chat.lines.size() == count, "none from far off")
	near.queue_free()
	far.queue_free()
	check(chat.panel_a > 0.2, "the log's backing shows while it is busy (%.2f)" % chat.panel_a)
	var t := chat.lines[0].node as Control
	chat._now += HudChatLog.LINE_S + HudChatLog.FADE_S + 1.0
	await settle(2)
	check(t.modulate.a < 0.01, "an old line has faded")


func _test_remove() -> void:
	HudClassicMap.remove(hud)
	await settle(2)
	var compass := hud.find_child("Compass", true, false) as Control
	check(HudClassicMap.find(hud) == null and compass.visible and hud.toasts_shown, "removed: the compass and the toasts back")
	story.hud.set_mission("The Clearing", "Fell a pine", "", [])
	await settle(1)
	check(not story.hud.tracker_shown and story.hud._title.visible and story.hud._text.visible, "StoryHUD's lines back")
	story.hud.set_mission("", "", "", [])


func _end() -> void:
	if fails.is_empty():
		print("HUD CLASSIC MAP TEST OK (%d checks)" % checks)
	else:
		print("HUD CLASSIC MAP TEST FAILED %d/%d" % [fails.size(), checks])
		for f in fails:
			print("   - ", f)
	quit(0 if fails.is_empty() else 1)
