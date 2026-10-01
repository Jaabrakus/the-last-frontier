# Multiplayer co-op: readiness and plan

Status 2026-10-01: no networking in the game yet. This is the plan `SurvivalCore` and `WildlifeSpawner` already refer to.

## Goal

16 players, two teams of 8 (user 2026-10-01: "16 people is a good amount, I want 8v8"; it was ~100 before), with play
identical to single player (user: "an exact local-like structure, no differences at all"): the same character, weapons,
building and world. Not cross-play. (P8 below was written for 100; at 16 most of it is optional.)

## Architecture

- **One code path.** Single player is a server with one player on the same machine: the same server code runs the world
  whether 1 or 100 people are in it, so there is nothing that only works offline or only online.
- **Dedicated server for big sessions, server-authoritative.** At 100 players no one player's machine can host: a headless
  Godot server process owns the world (AI, wildlife, households, building, items, damage, the clock, the save). Small
  groups can still host from a player's game (the same server code, in-process). Clients send controls and requests and
  display what the server replicates. Nobody else decides a hit, a cut, a pickup or a death.
- **Interest management (needed for 100).** Each client only receives what is near it (players, animals, pieces, items in
  a radius / the cells round it); far-away things are not sent and not simulated in detail.
- **No full animation on the server.** The player's AnimationTree costs ~2 ms a frame (test_tree_build, headless); 100 of
  them is 200 ms, far over a 16 ms frame. The server runs movement and simplified hit volumes; every client animates only
  the players near it, with animation LOD for distant ones (fewer layers, lower rate, no IK).
- **Godot's high-level multiplayer API**: `MultiplayerSpawner` for players, animals, projectiles and pickups;
  `MultiplayerSynchronizer` for per-entity state; `@rpc` for one-off commands and events.
- **Transport**: ENet (direct IP / LAN) while developing; GodotSteam (Steam lobbies, invites, relay, no port forwarding)
  for players. The game code talks only to `MultiplayerPeer`, so the transport is a swap at the end.
- **Client-side prediction for your own character only**: you move and animate at once on your machine; the host checks
  and corrects. Everyone else is interpolated from snapshots ~100 ms behind.

## What is already in place

| Piece | Where | Why it helps |
|---|---|---|
| Controls are an object, not `Input` | `scripts/player/player_controls.gd` (`PlayerControls`, `from_input`, `set_held`) | The player already runs from whatever holds its actions (it was built for the duel AI "and later by the network"). A remote player is `from_input = false` fed by RPC. |
| Animation is driven from a small input record | `scripts/player/anim/anim_inputs.gd` (`AnimInputs`: velocity, wish, crouch, aim, weapon, events) | Remote players do not need bone data: replicate these few fields and run `PlayerAnim` locally on every machine. |
| Survival is a pure logic hub | `scripts/survival/survival_core.gd` (commands in, signals out, no nodes, no `Engine.time_scale`, fixed-quantum clock) | It can run only on the host. It was written as "the same code that will host co-op". |
| The world is data | `SaveParts` (`scripts/save/save_parts.gd`): player, survival, sky, vegetation, building, items, wildlife, horse | The same records are what a joining player needs: the save doubles as the join snapshot. |
| Building is ids and records | `BuildWorld` / `BuiltPiece` / `PalisadeCuts` (`scripts/building/`) | Pieces and cuts are records with ids, applied by functions; easy to make host commands. |
| Wildlife knows about sessions | `scripts/wildlife/wildlife_spawner.gd` (`_is_session()`, untouched carcass cleanup only in multiplayer) | One rule already written for co-op. |

## What assumes one player

Measured on the tree 2026-10-01 (434 scripts):

- **"The player" is looked up as one node**: `get_first_node_in_group("player")` in 11 scripts (snow prints and cover,
  river ice and water, forage, farming, boats, nav, carcasses, horse haul), `get_node("Player")` in 5, and a `player`
  reference passed into ~75 scripts at setup (`WildlifeSpawner.setup(player, ...)`, the household, the horse).
- **`Input` read directly** in 32 scripts outside `PlayerControls`: weapons (`firearm.gd`, `bow.gd`, `throwable.gd`,
  `over_under.gd`), gathering, fishing, foraging, field dressing, butchery, torches, boats, horse tools (wheelbarrow, log
  pull, foot drag), build mode, interaction, survival stations, cooking, sleep, vices, the household and worker orders.
- **The camera**: `get_viewport().get_camera_3d()` in 31 places (aim rays, prompts, LOD). Fine on each machine for its
  own player; wrong anywhere the host uses it to decide something for another player.
- **Pausing the world**: `get_tree().paused` in 44 places (pause menu, inventory, chests, character creator, boat
  puzzles). A shared world cannot pause for one player.
- **Time scale**: `Engine.time_scale` in the anim debug overlay and the anatomy kill slow-motion (`scripts/fx/anatomy.gd`).
- **Time skips**: sleep (`scripts/survival_game/survival_sleep.gd`) runs game hours in a few real seconds.
- **Static state**: 221 `static var`s; most are mesh / data caches (harmless), but any that hold world state are
  per-process and need checking.

## The plan, phase by phase

Each phase ends with something two people can play on a LAN.

### P0: decisions and plumbing

- Decide: player count (4?), Steam only or also direct IP, drop-in mid-game, whose character a joiner plays (their own
  save's character vs a fresh one), what happens to the host's single-player save.
- A `Net` node in the level (no autoload, like the rest of the game): host / join / leave, peer list, a `is_host()` and
  `authority_of(node)` helper, the session flag `WildlifeSpawner` already checks.
- Main menu: Host and Join (IP field now, Steam friends later).

### P1: two players see each other

- Spawn one `FrontierPlayer` per peer (`MultiplayerSpawner`); the local one keeps the camera, HUD and `from_input = true`;
  remote ones get `controls.from_input = false` and no camera or HUD.
- Each client sends its controls (held actions, move vector, yaw, pitch) every physics tick; the host simulates every
  player and replicates position, velocity, yaw, pitch and the `AnimInputs` fields; each machine runs `PlayerAnim` from
  them. Your own player predicts and is corrected.
- Character look (`scripts/customizer/`, loadout) sent once on join.
- Done when: two players walk, run, crouch, jump and aim around the fort and see each other animate correctly.

### P2: weapons and damage

- Firing is a request: the client plays its own muzzle, sound and recoil at once; the host spawns the projectile
  (`scripts/weapons/projectile.gd`, thrown weapons), runs `Hit.deliver`, wounds, maiming and deaths, and replicates
  results (impacts, blood, ragdolls from `scripts/fx/bone_ragdoll.gd`, death).
- Move the weapons' direct `Input` reads onto `player.controls`.
- Reloads, draws and nocks are actions the host confirms (ammo and arrows are the host's).
- Anatomy slow-motion off in sessions (or local camera only, never `Engine.time_scale`).
- Done when: both players hunt the same deer and shoot each other with the right damage on both screens.

### P3: the shared world

- Everything that changes the world becomes a host command with the acting player's id: build placements and repairs
  (`BuildMode` -> `BuildWorld`), palisade cuts (`PalisadeCuts.strike`), felling and gathering (`GatherTools`), doors and
  gates, pickups, drops, chests, stockpiles, foraging and farming, fishing catches.
- Prompts and aim rays stay on the client; the host re-checks reach and line of sight before applying.
- Replication: a spawner for built pieces and items; small RPC events for cuts, doors, felled trees.
- The 11 `get_first_node_in_group("player")` users take "the nearest player" or "every player" (snow prints for every
  player, water and ice for every body in them, forage and farming per acting player).
- Done when: one player builds a wall, the other cuts a window in it, both see the same thing, and it saves.

### P4: survival per player, one clock

- `SurvivalState` holds one player's records today; make it world records + a record per player id. The host runs the
  core for all of them; each client gets its own needs, conditions, skills and inventory for its HUD.
- One shared clock and weather on the host. Sleep: time only skips when every player is asleep; otherwise sleeping
  restores without the skip.
- Menus stop pausing the tree in sessions (inventory, chests, crafting, puzzles keep the world running; the pause menu
  becomes "leave / settings").
- Done when: both players get hungry, eat, cook, craft and sleep through a night together.

### P5: AI and animals

- Wildlife, the horse, the wife and the household, workers and hunts run on the host only; clients display them
  (snapshot interpolation for bodies, animation from replicated state as for players).
- The spawner's "near the player" rules (`ACTIVE_D`, `VISIBLE_D`, restock distance) become "near any player".
- Orders to the household and workers (`household.gd`, `worker_orders.gd`) become requests; decide who may order her.
- Riding, boats and hauling (`horse/`, `boats/`): the host owns the mount; the rider sends controls through it.
- Done when: both players ride, hunt with the wife, and give her orders.

### P6: saves and joining mid-game

- The host's save is the world; each joiner's character (look, loadout, skills, inventory) is kept per player id in it.
- Join snapshot: the host sends the `SaveParts` records, the joiner builds the world from them, then live replication
  takes over.
- Iron Man mode and death rules (`scripts/save/death_rule.gd`) per player.

### P7: Steam

- GodotSteam addon, Steam lobby -> `SteamMultiplayerPeer`; invite and join from the friends list; relay for NAT.
- Steam app id, achievements later.

### P8: scale to 100

- Headless dedicated server build (no rendering, no audio, no player animation; hit volumes from a cheap pose).
- Interest management by world cells; per-client relevance for players, wildlife, pieces, items.
- Animation LOD on clients; server tick and snapshot rates tuned; bandwidth budget per client.
- Load test with bot players (the controls object already takes an AI: `MeleeDuelAI`) at 25, 50, 100.
- Hosting: where the servers run and who pays (a rented machine or a cloud host per world).

## Risks

- **100 players is a different game technically**: the household, wildlife ecology and one shared clock were designed for
  one person. With 100, one clock and one sleep rule for everyone (time cannot skip), many households or one shared one,
  and wildlife spread over a world big enough for 100 all need design decisions, not just code.

- **Traversal and climbing** (`scripts/traversal/`, `scripts/climb/`): animation-driven moves with their own timing;
  they must run predicted on the owning client and look smooth on others. The hardest part of P1-P2.
- **Bandwidth**: per-player `AnimInputs` is small, but wildlife herds, ragdolls and many built pieces add up. Use
  relevance (only what is near each player) and send ragdolls as start impulses, not bone streams.
- **Sessions running in parallel**: this is a cross-cutting refactor touching most systems while other work lands every
  day. Do it phase by phase, each behind the session flag, so single player keeps working at every step.
- **Physics determinism**: never assume clients simulate the same; the host's result is the truth.

## Order of work and size

P0-P1 first (the foundation everything else builds on, about one focused stretch of work), then P2 and P3, which make it a
game. P4-P5 are the long tail; P6-P7 finish it. Every phase keeps single player unchanged.
