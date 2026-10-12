class_name NetClock
extends RefCounted
## The host's clock on every machine (docs/tidebreak/ring_netcode.md, "Time"): every message about the ring carries a time on
## it, so a body's states are placed in order, a cast's age is known, a hit is judged where its caster saw his target.
##   now()          seconds on the host's clock: the host's own monotonic time; a client's plus its measured offset
##   rtt            the round trip to the host (s; 0 on the host), its latency() half of it
##   ping(), pong   a client asks the host's time once a second (RingNet sends and answers); each answer is a sample: the
##                  offset is the host's time plus half the round trip less the time it came back, and the sample with the
##                  shortest round trip of the last WINDOW wins (the one least bent by queueing); the offset moves to it at
##                  once the first time, then eases (no jump of a body's history when a better sample comes)
## Seconds are floats from Time.get_ticks_usec: one clock for everything here, never the wall clock.

## Samples kept (the last this many answers: ~8 s at one a second).
const WINDOW := 8
## How far the offset moves toward a new best each sample (a share; the first sample sets it at once).
const EASE := 0.35

var rtt := 0.0
var offset := 0.0
var synced := false
var _samples: Array[Vector2] = []          # (x: the round trip, y: the offset it gave)


## Seconds on this machine's own monotonic clock.
static func local() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


## Seconds on the host's clock (the host: its own).
func now() -> float:
	return local() + offset


## One way to the host, as measured (s).
func latency() -> float:
	return rtt * 0.5


## An answer to a ping sent at local time `sent` (this machine's clock), the host's time `host_t` when it answered.
func pong(sent: float, host_t: float) -> void:
	var back := local()
	var r := maxf(back - sent, 0.0)
	_samples.append(Vector2(r, host_t + r * 0.5 - back))
	if _samples.size() > WINDOW:
		_samples.pop_front()
	var best := _samples[0]
	for s in _samples:
		if s.x < best.x:
			best = s
	rtt = best.x if not synced else lerpf(rtt, best.x, EASE)
	offset = best.y if not synced else lerpf(offset, best.y, EASE)
	synced = true


## The host's clock is this machine's (a host, a dedicated server, offline).
func be_host() -> void:
	rtt = 0.0
	offset = 0.0
	synced = true
	_samples.clear()
