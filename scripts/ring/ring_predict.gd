class_name RingPredict
## Where a launch takes a body in Tidebreak's % ring (round 3, smash_r3 spec §2.2, §9.3, §14.3; MOVE's file, stubbed by
## SEAMS): pure static, mirroring smash_r3/lead_model.py v2 (gravity, the carry's decay, the recovery, the curtain plane). The
## bots read it to finish, and the tests check it against the model.
##   flight(v, hitstun_s, from, element) -> {lands: "deck" | "edge" | "water", travel_m, t}
##   would_ko(tag, target, from, dir, range_m, air) -> bool    a hit of `tag` on `target` now would take a life
##   ko_pct(tag, target, from, dir, range_m, air) -> float     the % at which it would (a search 0-300 over RingRules.launch_v)
## Until MOVE fills it: everything lands on the deck and nothing ever KOs.


## Where a body launched at `v` from `from` with `hitstun_s` of hitstun comes down (`element`: its recovery).
static func flight(_v: Vector3, _hitstun_s: float, _from: Vector3, _element: String) -> Dictionary:
	return {"lands": "deck", "travel_m": 0.0, "t": 0.0}


## A hit of `tag` on `target` now, from `from` going `dir`, would KO him.
static func would_ko(_tag: String, _target: Node, _from: Vector3, _dir: Vector3, _range_m := 0.0, _air := false) -> bool:
	return false


## The % at which a hit of `tag` on `target` from `from` going `dir` would KO him (INF: never).
static func ko_pct(_tag: String, _target: Node, _from: Vector3, _dir: Vector3, _range_m := 0.0, _air := false) -> float:
	return INF
