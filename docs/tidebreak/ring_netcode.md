# Ring netcode: Tidebreak online, community and player-run servers

The owner, 2026-10-11, after reading Spellbreak Community Edition's server kit: "we can copy to use for our community servers or
player run servers", and "make sure its the best code in the game spellbreak was the best multiple spells and then spell
fusions and etc.. that game was magic". This is the design; it is built in phases (below), each with a two-process test.

What is copied from Spellbreak is the *model*, never its code or content: a server players run themselves, one match per
process, joined by address, a host who sets the match, bots that fill the empty slots, an admin console, no dependence on
any service of ours (its community kit replaced every online service with local files). Its netcode is compiled into its
pak; ours is our own, in Godot.

## What has to hold

- **Every spell online exactly as offline.** The same code runs a cast everywhere (no second, "network" version of any
  move): bolts, waves, cones, zones, walls, pillars, stones, guards, binds, knock-ups, prisons, soaks, clashes, fusions.
- **Your own fighter never waits for the network.** Moving, jumping, locking and casting are as instant online as offline.
- **One truth about every spell.** Who a spell hit, whether a guard was perfect, which of two bolts won a clash, where a
  wall stood: decided once, by the host, and the same on every screen.
- **Fair under latency.** Hits judged against where the caster saw his target (lag compensation, bounded), a guard judged
  by when it was raised, not when its news arrived.
- **No backend.** A match needs only the players' machines (and a player-run server when they want one): no accounts, no
  service; names, looks and skill trees travel with the player, each server sets its own rules.

## Authority

| What | Decided by | Why |
|---|---|---|
| A body: its movement (RingMoves), its knock and hitstun (BendKnock), its % and the launch a hit gives it (RingRules.on_hit for that body), its binds, floats, soaks and prisons, its locks and casts (SwayCaster) | its **owner**: your machine for your fighter, the host for the bots | zero input lag; every movement and % rule stays the local code it is |
| Every spell entity (bolts, zones, walls, pillars, stones, strikes) and every meeting between spells and bodies: hits, guards, catches, send-backs, clashes, walls worn down | the **host** | one truth; interactions between two players' spells cannot be decided on two machines |
| The match: phase, clock, rounds, lives, falls, respawns, score, sudden death | the **host** | one referee |
| What a hit does to a body | the body's **owner**, from the host's word that it was hit | the % rules run once, where the body lives |

A dedicated server is a host with no fighter of its own: it runs the match, the spells and the bots; every human is remote.
A player who hosts from his game is the same host with his own fighter in it.

## The flow

**Bodies.** Each owner streams its bodies 30 times a second (unreliable, ordered): place, velocity, yaw, pitch, the
RingMoves mode and its clip, the knock state, the status flags (bound, floating, soaked, imprisoned, intangible), the
cast pose. Everyone else shows each remote body as a **puppet** 100 ms in the past (interpolated between two states,
extrapolated a little on loss): its RingMoves and SwayCaster in puppet mode (set from the stream, simulating nothing), its
SwayPose animating from them by the same code as a local fighter's, its status looks made locally when a flag turns on.
The host keeps a short history of every body (1 s) for lag compensation.

**Casts.** A cast is an event, not a set of entities. Its caster's machine sends what BendEffects.apply needs to run it
again: the move, the mode, the grown flag, the dash and side choices, the aim (from, dir, flat, point, the target's net
id), the launch point, the dice seed, the worn loadout's key, the time it was cast. Then:
- the **caster's machine** runs it at once as a *prediction*: the visuals only (ghost mode below), no hit;
- the **host** runs it for real through a NetBendCaster (a BendCaster answering from the event: aim, launch point, dice) on
  the caster's puppet, its entities fast-forwarded by the cast's age (its owner's latency, bounded) so they stand where the
  caster sees his;
- every **other machine** runs it in ghost mode when the host passes it on, fast-forwarded by its own latency.
The same code with the same inputs makes the same entities in the same order on every machine: each gets the id
<cast>:<n>, so the host's later word about one names it everywhere.

**Ghost mode.** On a machine that is not the host, every spell entity flies, grows, lights and sounds exactly as it does
offline, and keeps its colliders (a wall blocks you, a pillar lifts you), but decides nothing: no hit, no meeting with
another spell, no guard, no catch, no wear. It runs until the host's word ends it or turns it.

**The host's words about spells** (reliable): an entity *ended* (its id, why: a hit, a guard, a clash, a wall, its range;
where), *turned* (a send-back, a Turn's swing, a redirect: its new place, velocity and owner), *caught* and *held* (a stone
and its holder), *worn* (a wall's wear, its crumble), a stone's place a few times a second while it is loose. Each machine
plays the ending's own look where the host says it ended (a bolt that overshot by a frame is put back first).

**Hits.** The host's BendR3.deliver on a body it does not own is not applied there: it goes to the body's owner (the
caster and the body by net id, the damage, the point, the direction, the knock, the hit info), who runs the same
BendR3.deliver on his own body: RingRules.on_hit (his %), BendKnock (his launch), his binds, floats and soaks. The other
effects a spell has on a body go the same way: a Wind Prison's catch, a rescue, a guard's result and its parry reward, a
Carried wind. A body attack (a ledge attack, the Rise's hit) is decided by the attacker's owner and sent the same way.

**The match.** The host's RingMode runs the match; every other machine's is a mirror (phase, clock, round, score, lives,
%, the falls) and decides nothing. A body's owner sees it fall (RingRules.ko on his own body) and tells the host, who
counts the life, holds the body out and, when its time comes, tells the owner where it respawns.

**Time.** Every message carries the sender's clock; each machine keeps the host's clock (ping and pong every second,
offset and round trip smoothed). Lag compensation: a cast's age is how long ago its caster cast it on the host's clock
(at most 150 ms counted); a hit is judged against the body history at the caster's view (the host's now, minus the
caster's latency and the 100 ms of interpolation he sees, at most 200 ms back); a guard's perfect window is measured from
when its owner raised it.

## Code

`scripts/net/ring/`, one class a job, each with a header of its contract:

| Class | Job |
|---|---|
| RingNet | the ring's session: host, join, a dedicated server, the peers and the competitors they own, the clock, the RPC hub |
| NetClock | the host's clock on every machine |
| NetBody | a body's state: write it, read it, the puppet's buffer and interpolation, the host's history |
| NetBendCaster | a BendCaster from a cast event |
| NetCasts | send a cast, predict it, run it on the host, pass it on, run it as a ghost |
| NetSpells | entity ids, ghost mode, the host's words about spells and their application |
| NetHits | a body effect sent to its owner and run there |
| NetMatch | the match mirrored; falls reported, respawns ordered |

The game's own code gets one-line seams, each a no-op offline: BendEffects.apply, the entity constructors, BendBolt's and
BendZone's meetings, BendR3.deliver and BendStatus' body effects, RingMoves, SwayCaster, RingMode and RingRules. Offline
nothing changes (every existing test keeps passing).

## Phases

| Phase | What | Test |
|---|---|---|
| R1 a | the session: host and join into a 1v1 % ring, the second fighter a remote human; bodies streamed, puppets animated | `tests/net/test_ring_net_pair.gd` |
| R1 b | casts: every spell predicted, run by the host, ghosted elsewhere; ids; the host's words about spells | `test_ring_net_casts.gd` |
| R1 c | hits and body effects to their owners; % and knock-ups, binds, prisons, soaks, guards and parry rewards online | `test_ring_net_hits.gd` |
| R1 d | the match mirrored: phases, clock, lives, falls, respawns, rounds, the screens | `test_ring_net_match.gd` |
| R1 e | lag compensation: cast fast-forward, rewound hits, guard timing; a simulated 80 ms link | `test_ring_net_lag.gd` |
| R2 | 2v2 and 4v4 online, bots filling empty slots, more than one remote human, spectators | |
| R3 | the player-run server: a headless export with the graphics stripped, start scripts per format, server.json (port, players, format, rounds, time, arena, bots, password, twists allowed), the main menu's Join row (address, recent servers), the host's match settings, admin commands | |
| later | Steam relay and invites (no port forwarding), reconnect, a server list | |

## Not copied

Spellbreak's executable, pak, data and protocol: compiled and theirs. What we took from its kit is how a community runs it,
read from its PDFs and its two JSON files (RemoteConfig.json: modes on and off, the stores and quests off, every talent
unlocked; PlayerBlob.json: an offline profile with everything unlocked), which no part of this game reads.
