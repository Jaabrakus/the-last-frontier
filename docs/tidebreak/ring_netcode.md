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
| NetBendCaster | a BendCaster from a cast event: its tape's answers in order, its seed's dice |
| NetCasts | record a cast (its tape), send it, run it on another machine; the lock's course for the puppet's pose |
| NetSpells | who decides, the names, the host's words and the hits sent to the owners (with their application) |
| NetMatch | the match mirrored; falls reported, respawns ordered (R1 d) |

The game's own code gets one-line seams, each a no-op offline: BendEffects.apply, the entity constructors, BendBolt's and
BendZone's meetings, BendR3.deliver and BendStatus' body effects, RingMoves, SwayCaster, RingMode and RingRules. Offline
nothing changes (every existing test keeps passing).

## As built (R1 a, R1 b)

**The tape.** A cast is recorded where it lands (SwayCaster._apply_grown: NetCasts.begin .. end round SwayEffects.apply).
While it runs, every question its caster is asked is kept in order under its name (PlayerBendCaster: chest, facing,
aim_ray, aim_point, aim_target, assist_target, target_point, launch_point, side_sign, held_side, held_move, jump_held; the
outermost question only, so one that asks another is kept once), with the modes and tiers it gave by move, and its dice
are drawn from the cast's seed. The event carries the tape, the seed, the move, its variation and tier, grown, airborne,
the release time on the caster's own clock (what the host's hit tells him back is in it), the target's net id, the lock
point, where he stood, his velocity and facings, whether a bind held his feet and his Carried wind. Another machine runs it
on the caster's puppet (NetCasts.run): his NetBendCaster answers from the tape in the same order (the same code asks the
same questions), the puppet stands where he stood while it runs, his SwayCaster is pinned to the variation. A question
asked after the run (a volley's later bolts, Flowing's steer, a stone following his aim) is answered from his streamed
state (NetBody's aim slot: the point his crosshair is on). The puppet wears the caster's loadout (his hello's picks and
style), so his twists are his.

**Names.** Every spell thing made while a cast runs is named "<peer>:<seq>:<n>" in the order it is made (BendBolt,
BendZone, FormRaised, FormStone); a volley's and a throw's later parts are made in the cast's run again (NetSpells.with).
A zone the host makes by a decision outside a cast (steam, a parry's puddle) is named in a run of its own and made on the
others by its word.

**Ghosts.** Only the host decides (NetSpells.decides). A ghost bolt flies and steers, ends on the world and on a raised
wall at once with its look (the host's will be the same), and passes bodies, stones, other bolts and zones until the host's
word; a ghost zone decides nothing (_every, _stones, _wind_push, on_bolt, guard_take, cone_mult, lightning_back), its own
ends (its life, its owner gone, its owner's drop) its own. A cast's synchronous run does on every machine what it does to
the things it finds (one fire wall at a time, put out, melt, a chunk torn from a wall): the same things are there. A
decision outside a cast is the host's (NetSpells.decide: done there and told).

**The host's words** (NetSpells.word, reliable, to every other machine): "end" (a bolt or zone ended by a decision: why
and where; a bolt's look played there), "bolt" (a bolt changed by a meeting: its state, compared each frame; a Turn's
swing begun round the guard and left again, a new kind, a fire taken, its numbers halved, a new caster), "guard" (a
guard's result: BendZone.report on every machine, the HUD and the look), "wall_hit" (a raised wall worn), "zone" (a zone
made by a decision).

**Hits** (NetSpells.forward, to the body's owner): the host's BendR3.deliver on a puppet sends "hit" (its owner takes it on
his own body: BendR3.take, hurt then knock then his lock told; RingRules.on_hit runs there: his %, his launch, his float,
bind or soak), and the hitter's side to the hitter's owner ("hit_by": the jab string as the host keeps it, the step, his
SwayCaster's note of the hit; "jab_guarded"). BendStatus' other effects on a puppet go the same way: hurt, knock, root,
slow, rescue, a parry's cast share ("cast_mult": the guarder's 0.85, the parried caster's 1.15), a whiff, Carried wind, a
Wind Prison's catch ("imprison"). A body's own effects (a heal, Patch, cleanse, anchor, a dash's motion) are its owner's
only (NetSpells.owns). Only the host may send hits (RingNet._hit is the authority's).

**The puppet's lock.** The caster's lock goes to the others as it goes (start, full, grew, cast, broken, fizzled): the
puppet's SwayCaster plays it (its state and signals: SwayPose poses him, FormCast draws his circle at his feet) and never
locks by itself; his E comes with his state (NetBody's keys), so his guard stands held as long as he holds it.

**Stones** (NetStones). A stone a cast makes is made by its run on every machine (a kick-up, a raised Spike or Boulder: the
lock's fill is recorded and run like a cast, "raise", and so is a switch's reshape; a chunk torn from a wall). One the host
makes by a decision (a catch's held stone, a stone dropped loose, earth's Pop stone) is named in a run of its own and told in
full. Only the host rolls stones: each named stone tells its state (shape, place, phase, its holder, its loose maker, its
raiser by net id, its catch's numbers) when a decision changes it, while it rolls and when it rests; the others keep theirs
still and follow. A flight (GustLift) is run alike everywhere (its throw is in a cast's run, or the host's "heave" word for
the Fissure's): a ghost's passes bodies and bursts on the world, and the host's word stops it (the stone's state) or bursts
it where the host's did (its "end"). A raised stone's grow and drop go with the lock's course.

**Still to come in R1:** body attacks decided by a joiner's own machine (a ledge attack, the Rise's hit: through the host to
the victim's owner); the jab string's end on a victim's machine back to the hitter's (RingRules.string_ended); the match
mirror (R1 d); lag compensation (R1 e).

## Phases

| Phase | What | Test |
|---|---|---|
| R1 a | the session: host and join into a 1v1 % ring, the second fighter a remote human; bodies streamed, puppets animated (built) | `tests/net/test_ring_net_pair.gd` |
| R1 b | casts: every spell predicted, run by the host, ghosted elsewhere; names; the host's words about spells (built but stones) | `tests/net/test_ring_net_casts.gd` |
| R1 c | hits and body effects to their owners; % and knock-ups, binds, prisons, soaks, guards and parry rewards online (the spells' built with R1 b; body attacks, strings, stones to come) | `test_ring_net_hits.gd` |
| R1 d | the match mirrored: phases, clock, lives, falls, respawns, rounds, the screens | `test_ring_net_match.gd` |
| R1 e | lag compensation: cast fast-forward, rewound hits, guard timing; a simulated 80 ms link | `test_ring_net_lag.gd` |
| R2 | 2v2 and 4v4 online, bots filling empty slots, more than one remote human, spectators | |
| R3 | the player-run server: a headless export with the graphics stripped, start scripts per format, server.json (port, players, format, rounds, time, arena, bots, password, twists allowed), the main menu's Join row (address, recent servers), the host's match settings, admin commands | |
| later | Steam relay and invites (no port forwarding), reconnect, a server list | |

## Not copied

Spellbreak's executable, pak, data and protocol: compiled and theirs. What we took from its kit is how a community runs it,
read from its PDFs and its two JSON files (RemoteConfig.json: modes on and off, the stores and quests off, every talent
unlocked; PlayerBlob.json: an offline profile with everything unlocked), which no part of this game reads.
