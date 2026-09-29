class_name Intimacy
extends RefCounted
## The intimacy gauge with the spouse (user 2026-09-28: "an intimacy gauge with the spouse; when it is full the player can ask
## for tandem yoga"). Logic only: the value (0..1) lives on SpouseCore (`intimacy`, `intimacy_cd`, saved); this class holds
## the rules (data/companion/intimacy.json): what fills it (time together, talk, meals, small gifts, finished jobs, each
## with per-source cooldowns and daily caps), what drains it (days apart), the words for its levels, whether yoga may
## be asked (gate) and who leads (the woman). The node side is TandemLink; the flow of an offer or request is YogaFlow.
## All times are game minutes.

const PATH := "res://data/companion/intimacy.json"
const DEFAULTS := {"start": 0.1, "full_at": 0.999, "near_m": 6.0, "together_per_min": 0.0006, "together_day_cap": 0.2,
		"talk": 0.02, "talk_cooldown_min": 60.0, "meal_shared": 0.03, "meal_cooked_bonus": 0.02, "meal_kcal": 120.0,
		"meal_cooldown_min": 120.0, "cooked_recent_min": 360.0, "gift": 0.008, "gift_cooldown_min": 60.0, "job": 0.01,
		"job_day_cap": 0.05, "day_cap": 0.4, "away_grace_days": 2.0, "drain_per_day": 0.03, "floor": 0.05,
		"after_session": 0.35, "cooldown_hours": 0.0, "offer_at": 0.999, "decline_fade": 0.3, "decline_drain_per_hour": 0.05,
		"offer_range_m": 12.0, "offer_check_s": 5.0, "call_range_m": 40.0, "danger_m": 45.0, "combat_s": 30.0,
		"calm_hours": [0.0, 24.1], "come_m": 2.9, "follow_timeout_s": 0.0, "start_timeout_s": 10.0,
		"poses": [{"id": "crawl", "name": "The crawl"}, {"id": "yoga", "name": "Happy Baby"},
				{"id": "wide", "name": "Wide Kneel on the Reverse Plank"}],
		"levels": [{"upto": 1.01, "word": "Close"}], "fills_line": "", "reasons": {}}
## The order the gate looks at its reasons in.
const REASONS := ["minor", "dead", "not_full", "cooldown", "night", "danger", "combat", "far", "busy"]

var sc: SpouseCore
var cfg := {}
var _last_talk := -1e12
var _last_meal := -1e12
var _last_gift := -1e12
var _day := -1
var _gain_today := 0.0
var _together_today := 0.0
var _job_today := 0.0
var _away_min := 0.0


static func load_cfg() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if d is Dictionary:
		for k in d:
			out[k] = d[k]
	return out


func _init(core: SpouseCore = null, config := {}) -> void:
	sc = core
	cfg = config if not config.is_empty() else load_cfg()


## Who leads the tandem pose: the woman. `spouse_is_male` (SpouseCore.is_male()): the husband joins a player who is a
## woman ("player" leads); a wife leads for a male player ("spouse" leads).
static func leader_for(spouse_is_male: bool) -> String:
	return "player" if spouse_is_male else "spouse"


func leader() -> String:
	return leader_for(sc.is_male())


# ---------------------------------------------------------------- the value
func value() -> float:
	return sc.intimacy


func full() -> bool:
	return sc.intimacy >= float(cfg.full_at)


func level_word() -> String:
	var v := sc.intimacy
	for l: Dictionary in cfg.levels:
		if v < float(l.upto):
			return String(l.word)
	return String((cfg.levels[cfg.levels.size() - 1] as Dictionary).word)


## The level's index (0 = lowest), for the spoken lines.
func level_index() -> int:
	var v := sc.intimacy
	for i in cfg.levels.size():
		if v < float((cfg.levels[i] as Dictionary).upto):
			return i
	return cfg.levels.size() - 1


func _roll(now: float) -> void:
	var d := int(floorf(now / 1440.0))
	if d != _day:
		_day = d
		_gain_today = 0.0
		_together_today = 0.0
		_job_today = 0.0


## Adds up to `amount` within the day's overall cap (and `cap_left`, a source's own cap); returns what went in.
func _add(amount: float, now: float, cap_left := INF) -> float:
	_roll(now)
	var room := minf(float(cfg.day_cap) - _gain_today, cap_left)
	var got := clampf(minf(amount, room), 0.0, 1.0 - sc.intimacy)
	if got <= 0.0:
		return 0.0
	sc.intimacy += got
	_gain_today += got
	return got


## Time passes (`dm` game minutes): the cooldowns run down; near her (both awake) the gauge fills slowly; days apart it
## drains very slowly, never below its floor.
func tick(dm: float, near: bool, both_awake: bool, now: float) -> void:
	if dm <= 0.0:
		return
	sc.intimacy_cd = maxf(sc.intimacy_cd - dm, 0.0)
	# a declined offer: the gauge powers down slowly by `decline_fade` (what is left to shed is kept in intimacy_offer_cd)
	if sc.intimacy_offer_cd > 0.0:
		var shed := minf(sc.intimacy_offer_cd, float(cfg.decline_drain_per_hour) * dm / 60.0)
		sc.intimacy_offer_cd -= shed
		sc.intimacy = maxf(float(cfg.floor), sc.intimacy - shed)
	_roll(now)
	if near:
		_away_min = 0.0
		if both_awake:
			_together_today += _add(float(cfg.together_per_min) * dm, now, float(cfg.together_day_cap) - _together_today)
	else:
		_away_min += dm
		if _away_min > float(cfg.away_grace_days) * 1440.0 and sc.intimacy > float(cfg.floor):
			sc.intimacy = maxf(float(cfg.floor), sc.intimacy - float(cfg.drain_per_day) * dm / 1440.0)


## She was talked to (a Talk tab reply): once per cooldown. Returns what went in.
func on_talk(now: float) -> float:
	if now - _last_talk < float(cfg.talk_cooldown_min):
		return 0.0
	_last_talk = now
	return _add(float(cfg.talk), now)


## The player ate (a meal) with her near; more if she cooked something lately.
func on_meal(now: float, cooked_recently: bool) -> float:
	if now - _last_meal < float(cfg.meal_cooldown_min):
		return 0.0
	_last_meal = now
	return _add(float(cfg.meal_shared) + (float(cfg.meal_cooked_bonus) if cooked_recently else 0.0), now)


## The player put food in the store: a little.
func on_gift(now: float) -> float:
	if now - _last_gift < float(cfg.gift_cooldown_min):
		return 0.0
	_last_gift = now
	return _add(float(cfg.gift), now)


## She finished a household job.
func on_job(now: float) -> float:
	_roll(now)
	var got := _add(float(cfg.job), now, float(cfg.job_day_cap) - _job_today)
	_job_today += got
	return got


# ---------------------------------------------------------------- yoga
## After a session: the gauge drops to `after_session` (never up) and the cooldown starts.
func finish_session() -> void:
	sc.intimacy = minf(sc.intimacy, float(cfg.after_session))
	sc.intimacy_cd = float(cfg.cooldown_hours) * 60.0


func calm_hour(hour: float) -> bool:
	return hour >= float(cfg.calm_hours[0]) and hour < float(cfg.calm_hours[1])


## Why yoga cannot be had now ("" when it can). ctx: hour, busy, danger, combat, dist (to the player), alive (default true).
## `stop_ok`: the player asked, so she puts a job down (busy is not a reason then).
func gate(ctx: Dictionary, stop_ok := false) -> String:
	if bool(ctx.get("minor", false)):
		return "minor"      # adults only (AdultsOnly): never with a child or a teen
	if not bool(ctx.get("alive", true)):
		return "dead"
	if not full():
		return "not_full"
	if sc.intimacy_cd > 0.0:
		return "cooldown"
	return calm_reason(ctx, stop_ok)


## Only the conditions of the moment (not the gauge): what ends a yoga follow.
func calm_reason(ctx: Dictionary, stop_ok := false) -> String:
	if not calm_hour(float(ctx.get("hour", 12.0))):
		return "night"
	if bool(ctx.get("danger", false)):
		return "danger"
	if bool(ctx.get("combat", false)):
		return "combat"
	if float(ctx.get("dist", 0.0)) > float(cfg.call_range_m):
		return "far"
	if bool(ctx.get("busy", false)) and not stop_ok:
		return "busy"
	return ""


## An offer may be made now: the gauge is full, not powering down after a decline, calm, she is not at a job and
## is near the player.
func offer_ok(ctx: Dictionary) -> bool:
	if bool(ctx.get("minor", false)):
		return false
	return sc.intimacy >= float(cfg.offer_at) and sc.intimacy_offer_cd <= 0.0 \
			and float(ctx.get("dist", 1e9)) <= float(cfg.offer_range_m) and gate(ctx, false) == ""


## A declined offer (user 2026-09-28: "if decline then it slowly powers down"): no cooldown, the gauge just runs down a little.
func on_declined() -> void:
	sc.intimacy_offer_cd = float(cfg.decline_fade)


func reason_text(key: String) -> String:
	return String((cfg.reasons as Dictionary).get(key, "Not now"))


func fills_line() -> String:
	return String(cfg.fills_line)
