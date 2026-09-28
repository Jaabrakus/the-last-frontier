class_name SurvivalRuntime
extends Node
## Optional integration node: owns one SurvivalCore and drives it with real time. It is not in any scene yet; the
## player, HUD and world workflows can add it (or an autoload of it) when they wire survival in, then read `core` and
## connect to its signals. It does nothing a caller could not do by hand: update(delta) each frame, pause in menus,
## autosave on sleep and on quit.

@export var background_id := ""
@export var save_slot := "default"
@export var autosave_on_sleep := true
@export var autosave_on_quit := true
@export var run_seed := 0
## Later milestones' rows merged from data/survival/backlog (for example ["M3"] for fishing, frogs and foraging).
@export var backlog_milestones: PackedStringArray = PackedStringArray()

signal core_ready(core: SurvivalCore)

var core: SurvivalCore


func _ready() -> void:
	if core == null:
		new_game()


func new_game(bg: String = "", opts: Dictionary = {}) -> SurvivalCore:
	var o := opts.duplicate()
	if run_seed != 0 and not o.has("seed"):
		o["seed"] = run_seed
	if not o.has("backlog_milestones"):
		o["backlog_milestones"] = Array(backlog_milestones)
	_attach(SurvivalCore.new_game(bg if bg != "" else background_id, o))
	return core


func load_game(slot: String = "", name: String = "manual") -> bool:
	var c := SurvivalSave.load_slot(slot if slot != "" else save_slot, name)
	if c == null:
		return false
	_attach(c)
	return true


func save_game(name: String = "manual") -> Error:
	return SurvivalSave.save(core, save_slot, name) if core != null else ERR_UNCONFIGURED


func set_paused(p: bool) -> void:
	if core != null:
		core.paused = p


func _attach(c: SurvivalCore) -> void:
	if core != null and core.autosave_requested.is_connected(_on_autosave_requested):
		core.autosave_requested.disconnect(_on_autosave_requested)
	core = c
	core.autosave_requested.connect(_on_autosave_requested)
	core_ready.emit(core)


func _process(delta: float) -> void:
	if core != null:
		core.update(delta)


func _on_autosave_requested(_reason: String) -> void:
	if autosave_on_sleep and core != null and not core.is_dead():
		SurvivalSave.autosave(core, save_slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_on_quit and core != null and not core.is_dead():
		SurvivalSave.autosave(core, save_slot)
