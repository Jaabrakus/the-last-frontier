# Unfun gameplay: running notes

The owner, 2026-10-10: "keep notes of un fun gameplay". One line of evidence per item, newest first within each list. When an
item is fixed, move it to **Fixed** with its commit. Sources: the cheese hunt (real headless matches against hard bots, 5+
seeds, probes in `tools/ring/cheese/`), the team-fight films (`tools/ring/team_fight_film.gd`), and the owner's own play.

## Open

| # | What | Evidence | Idea |
|---|---|---|---|
| 2 | **Guard does not stop fire's Embers.** | Against a dummy holding guard or shield, Embers lands 76-81% and keeps it stunned 55-60%; shield up it took *more* (3.6 vs 3.0 %/s); 445 guards, 193 of them "perfect", still hit 85 times in 22 s. Clip: "Embers through guard" | Guard blocks Embers' bolts (each bolt checked against the guard), or the guard's beat counts the volley as one hit |
| 3 | **Shove spam beat skilled play (earth).** Earth's 2 is now the **Fissure** (the owner, 2026-10-10): a crack along the deck like fire's Kick, which a jump clears; the Shove's push is gone | Before: Shove alone won 5 of 5 vs hard water, 15 falls to 1; varied expert play won 4 of 5, 14 to 10 | Re-run `tools/ring/cheese/spam/spam_probe.gd` with the Fissure before calling it fixed |
| 4 | **Earth bots cannot hit a hopping player.** | Hopping in place cuts damage from a hard earth bot from 3.5 to 1.3 %/s and turns a 0:7 loss even; no effect on the other elements' bots | The earth bot switches to anti-air (Pebbles, air hits) when its target keeps jumping |
| 5 | **4v4: lots of launches, few falls.** | Film 2026-10-10: 33 launches in 40 s, 1 fall; five of eight at 100-122%. (Full games: lives ~2 min, games 4-5.5 min, so it is slow rather than broken) | Launch reach scaled to the bigger decks, or fewer pieces catching flyers; measure before changing |
| 6 | **Effects cover the screen in 4v4.** | Film: water arcs, fire and smoke from several fighters fill the player's view | Other fighters' effects smaller or fainter in team formats; the player's own full |
| 7 | **The deck gets cluttered.** | Scorch and burrow marks pile up and read like holes; with 4 grates a line in 4v4 the floor is hard to read by mid-match | Marks fade sooner, fewer at once, lighter in the Soft look |
| 8 | **Every bot looks like the same man.** | The ring factions still draw from the old 1765 game's 8 presets: all men, English / Scots-Irish / Dutch / French; seven near-twins in 4v4 under names like Tariq, Itzel, Hoa | Draw from the creator's whole range, women and men of many peoples |
| 9 | **The cream side blends into the pale deck (Soft look).** | 4v4 wide shots: teal pops, cream fighters on the pale stone and honey planks are hard to pick out | A deeper deck in team formats, more element colour on the cream side, or a darker study colour for it |
| 10 | **Earth casts still pin the caster** for their whole clip: the wall's stomp-rise, the Boulder, the raise, the kick-up, the uproot | poses.json root true (fire's kicks freed 2026-10-10) | Same as fire: held to the strike, free after (root "strike") -- owner to decide |
| 14 | **Air's Gust drawn far wider than it hits.** | The wind arc was drawn ~9 m across for a 2 m wave | Fixed in the look (below); the grown Gust is now the Air Lance |
| 11 | **Earth columns as perches.** | Films: fighters standing on top of earth columns over the fight | Measure: time on top, hits taken there; a column that sinks sooner when stood on |
| 12 | The Ruins pieces look like greybox; the waterfall walls are flat striped walls; the Soft sky is empty | Films | Art passes (not gameplay) |
| 13 | `tests/ring/test_ring_feel.gd` fails 2 checks (the feel-on camera identity; the return striking its foe) | Fails the same with click_queue true and the stones back: predates 2026-10-10 | Trace separately |

## Fixed

| What | Fix | Commit |
|---|---|---|
| Edge-stand stall: take a life, stand on the lip, the bot waits in its edge-guard and the clock wins it for you (5 of 6 matches won on time, the bot waiting 414-443 s) | Bots attack someone standing on the lip: EDGEGUARD only when he is off the deck and in the air (NpcRingMind). The wait fell to ~20 s a match; matches end by falls | the Fissure and Lance commit (2026-10-10) |
| Shove's push spam (earth) | Earth's 2 became the Fissure, a crack along the deck that a jump clears (the owner's call); a loose stone the crack runs under is thrown on, so the deck's stones stay earth's ammo. Spam not yet re-measured (open #3) | the Fissure and Lance commit (2026-10-10) |
| Air's Gust drawn ~9 m wide for a 2 m wave; the grown Gust a bigger wave still | The look trimmed to what it hits (look_r); held long, the Gust grows into the Air Lance, a wind spear thrown overhand | the Fissure and Lance commit (2026-10-10) |
| Mashing a cast button fired every move at its top rate ("click and forget"; Embers 112 casts in 22 s) | Hold to cast: hold until the lock is full, then let go; a tap does nothing (E and key 3 keep their tap; a hit never costs the cast). Cast times unchanged | b133a780 |
| Fire's Kick and High Kick pinned the caster for the whole clip | Held through the wind-up, free once it has struck; legs back to walking (no sliding) | b133a780 |
| Deck boulders (sockets) | Removed from every arena (ring.json sockets.at, formats' sockets_at) | b133a780 |
| A team-mate wore the other side's cream (Soft look) | Side by team (SoftLook.side_of) | 4fc42666 |
| Freed-object script errors in team fights (spectator camera; a stone bursting under the aim) | Guards in RingMode.in_play and SwayCaster._thread_end | ad71c64c |

## Tested, not cheese

Grabbing the ledge to block a recovery; Slamming over the lip; camping the respawn spout; walls at the lip (kept 3.5-4.25 m in);
ganging up in 4v4 (no stun chain over 2 s); camping the Ruins perch (knocked off 4 times); hiding behind Ruins cover (bots flank).
