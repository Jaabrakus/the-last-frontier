class_name SaveGame
extends Node
## Saving and loading the game (user 2026-09-27: "autosave + quick save"). One file a slot in DIR (JSON: the format,
## a version, meta, and each system's part from SaveParts; the survival core's through its bridge, DeathRule's own).
##
##   F5      quick save (the "quick" slot)
##   F9      load the latest save (quick or auto), rebuilding the level and applying it on top
##   auto    when the player wakes from sleep, every AUTOSAVE_S, after a respawn, and on quit (the "auto" slot)
##   launch  the game continues the latest save when there is one (user arg new_game: a new game; the main menu
##           will choose, later)
##
## Loading: the level is built fresh from its seeds (the forest, the fort, the animals), then, a few frames on (the
## wildlife's first stocking, the demo racks and the forage are made deferred), each part is applied in PARTS order.
## A save of another forest layout keeps everything but the felled trees and the forage, and says so.
## Off in tool and test runs (-s) unless they pass save=on (and then it never continues a save on its own, and saves in
## TEST_DIR, not over the player's saves).

signal saved(slot: String)
signal loaded(slot: String)

const GROUP := &"save_game"
const DIR := "user://saves/frontier/"
## Where tool and test runs (-s, save=on) save: never over the player's own saves.
const TEST_DIR := "user://saves/frontier_test/"
const SLOTS := ["quick", "auto"]
const AUTOSAVE_S := 300.0
## Frames the level is given before a save is applied to it.
const APPLY_AFTER_FRAMES := 8
## The parts, in the order they are applied.
const PARTS := ["survival", "sky", "vegetation", "building", "fort", "items", "wildlife", "horse", "wheelbarrow", "cart", "forage", "household", "player", "death"]

## A save to apply to the next level that loads (load_slot sets it and rebuilds the level).
static var pending: Dictionary = {}
static var pending_slot := ""
## The latest save is continued once, at the game's first level.
static var _launched := false

var level: Node
var death: DeathRule
## Why a part was not applied at the last load ("The forest has changed ...").
var notes: Array = []
var loading := false
var last_saved_slot := ""
var _auto_t := AUTOSAVE_S
var _was_sleeping := false
var _soon := ""
var _soon_t := 0.0


static func enabled() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("save="):
			var v := s.get_slice("=", 1)
			return v != "off" and v != "0"
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


## The folder the slots are in (TEST_DIR in script runs).
static func dir() -> String:
	return TEST_DIR if _is_script_run() else DIR


static func _is_script_run() -> bool:
	var args := OS.get_cmdline_args()
	return "-s" in args or "--script" in args


static func _has_arg(name: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == name or a.trim_prefix("--").begins_with(name + "="):
			return true
	return false


static func find(tree: SceneTree) -> SaveGame:
	return tree.get_first_node_in_group(GROUP) as SaveGame if tree else null


func setup(p_level: Node, p_death: DeathRule) -> void:
	level = p_level
	death = p_death


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not pending.is_empty():
		var doc := pending
		var slot := pending_slot
		pending = {}
		GameSettings.set_run(bool((doc.get("meta", {}) as Dictionary).get("iron", false)))
		_apply.call_deferred(doc, slot)
	elif not _launched and not _is_script_run() and not _has_arg("new_game"):
		var slot := latest_slot()
		if slot != "":
			var doc := read_slot(slot)
			if not doc.is_empty():
				GameSettings.set_run(bool((doc.get("meta", {}) as Dictionary).get("iron", false)))
				_apply.call_deferred(doc, slot)
	_launched = true


# --- Autosave and the keys ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if get_tree().paused or loading:
		return
	_auto_t -= delta
	if _auto_t <= 0.0:
		_auto_t = AUTOSAVE_S
		save_game("auto")
	var b := SurvivalBridge.find(get_tree())
	var sleeping := b != null and b.sleeper != null and b.sleeper.sleeping
	if _was_sleeping and not sleeping:
		save_soon("auto")               # woke up: a new day's save
	_was_sleeping = sleeping
	if _soon != "":
		_soon_t -= delta
		if _soon_t <= 0.0:
			var s := _soon
			_soon = ""
			save_game(s)


## Saves `slot` a moment from now (after a respawn or waking settles).
func save_soon(slot: String) -> void:
	_soon = slot
	_soon_t = 0.6


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.shift_pressed or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	if GameSettings.iron_man() and (k.physical_keycode == KEY_F5 or k.physical_keycode == KEY_F9):
		get_viewport().set_input_as_handled()
		_tell("Iron Man: no quick save or load")
		return
	if k.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		if save_game("quick") == OK:
			_tell("Saved")
	elif k.physical_keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		if not load_latest():
			_tell("No save to load")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not loading:
		save_game("auto")


# --- Saving ------------------------------------------------------------------------------------------------

## The whole save: meta and every part.
func build_doc(slot := "") -> Dictionary:
	var parts := {}
	for part: String in PARTS:
		parts[part] = _save_part(part)
	var meta := {"saved_unix": Time.get_unix_time_from_system(), "slot": slot, "godot": Engine.get_version_info().string,
			"iron": GameSettings.iron_man()}
	var b := SurvivalBridge.find(get_tree())
	if b:
		meta["date"] = SurvivalClock.date_string(b.core)
		meta["time"] = SurvivalClock.time_string(b.core)
	return {"format": SaveParts.FORMAT, "version": SaveParts.VERSION, "meta": meta, "parts": parts}


## Writes `slot` (not while dead, loading or with no level). OK, or why not.
func save_game(slot: String) -> Error:
	var p: FrontierPlayer = level.get_node_or_null("Player") if level else null
	if level == null or loading or p == null or p.is_dead:
		return ERR_UNAVAILABLE
	var doc := build_doc(slot)
	DirAccess.make_dir_recursive_absolute(dir())
	var path := dir() + slot + ".json"
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(doc, "", false, true))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return err
	last_saved_slot = slot
	saved.emit(slot)
	return OK


## Every save gone (Iron Man: the character died).
static func erase_all() -> void:
	for slot: String in SLOTS:
		var path := dir() + slot + ".json"
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func read_slot(slot: String) -> Dictionary:
	var path := dir() + slot + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or String((d as Dictionary).get("format", "")) != SaveParts.FORMAT:
		return {}
	return d


## The slot saved last ("" when there is none).
static func latest_slot() -> String:
	var best := ""
	var bt := -1.0
	for s: String in SLOTS:
		var d := read_slot(s)
		if d.is_empty():
			continue
		var t := float((d.get("meta", {}) as Dictionary).get("saved_unix", 0.0))
		if t > bt:
			bt = t
			best = s
	return best


# --- Loading -----------------------------------------------------------------------------------------------

func load_latest() -> bool:
	var s := latest_slot()
	return s != "" and load_slot(s)


## Rebuilds the level and applies `slot` to it.
func load_slot(slot: String) -> bool:
	var doc := read_slot(slot)
	if doc.is_empty():
		return false
	pending = doc
	pending_slot = slot
	loading = true
	get_tree().paused = false
	get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)
	return true


## Applies a save to this freshly built level (after it settles).
func _apply(doc: Dictionary, slot: String) -> void:
	loading = true
	for i in APPLY_AFTER_FRAMES:
		await get_tree().process_frame
	notes = []
	var parts: Dictionary = doc.get("parts", {})
	for part: String in PARTS:
		if not parts.has(part):
			continue
		var d: Dictionary = parts[part] if parts[part] is Dictionary else {}
		_load_part(part, d)
	loading = false
	_auto_t = AUTOSAVE_S
	var meta: Dictionary = doc.get("meta", {})
	print("SaveGame: loaded the %s save (%s %s)%s" % [slot, String(meta.get("date", "")), String(meta.get("time", "")),
			"; " + "; ".join(notes) if not notes.is_empty() else ""])
	_tell("Loaded: %s %s" % [String(meta.get("date", "")), String(meta.get("time", ""))] if meta.has("date") else "Loaded")
	for n in notes:
		_tell(String(n))
	loaded.emit(slot)


func _save_part(part: String) -> Dictionary:
	match part:
		"survival": return SaveParts.save_survival(level)
		"sky": return SaveParts.save_sky(level)
		"vegetation": return SaveParts.save_vegetation(level)
		"building": return SaveParts.save_building(level)
		"fort": return SaveParts.save_fort(level)
		"items": return SaveParts.save_items(level)
		"wildlife": return SaveParts.save_wildlife(level)
		"horse": return SaveParts.save_horse(level)
		"wheelbarrow": return SaveParts.save_wheelbarrow(level)
		"cart": return SaveParts.save_cart(level)
		"forage": return SaveParts.save_forage(level)
		"household": return SaveParts.save_household(level)
		"player": return SaveParts.save_player(level)
		"death": return death.save_data() if death else {}
	return {}


func _load_part(part: String, d: Dictionary) -> void:
	match part:
		"survival": SaveParts.load_survival(level, d)
		"sky": SaveParts.load_sky(level, d)
		"vegetation": SaveParts.load_vegetation(level, d, notes)
		"building": SaveParts.load_building(level, d)
		"fort": SaveParts.load_fort(level, d)
		"items": SaveParts.load_items(level, d)
		"wildlife": SaveParts.load_wildlife(level, d)
		"horse": SaveParts.load_horse(level, d)
		"wheelbarrow": SaveParts.load_wheelbarrow(level, d)
		"cart": SaveParts.load_cart(level, d)
		"forage": SaveParts.load_forage(level, d)
		"household": SaveParts.load_household(level, d)
		"player": SaveParts.load_player(level, d)
		"death":
			if death:
				death.load_data(d)


func _tell(text: String) -> void:
	var p: Node = level.get_node_or_null("Player") if level else null
	var it: Node = p.get("interactor") if p else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)
	var huds := level.find_children("*", "FrontierHUD", true, false) if level else []
	if not huds.is_empty() and huds[0].has_method(&"toast"):
		huds[0].call(&"toast", text)
