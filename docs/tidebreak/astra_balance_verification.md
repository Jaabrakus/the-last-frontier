# Balance verification — 2026-10-07

**Candidate C is installed after passing the predeclared 144-game finite-sample screen.** All five fixed samples are included: 12 games for each ordered cross-element pairing, 72 personal appearances per element, normal bots, no mirrors or draws. The earlier 72-game screen failed narrowly and remains recorded below; exactly 72 fresh replication games were declared before their outcomes were inspected. The 40–60% personal-win / 20–30% pooled-share band was not changed.

| Installed C | Wins / personal appearances | Personal 1v1 win rate (aim 50%) | Share of all 144 wins (aim 25%) | Credited stock share |
|---|---:|---:|---:|---:|
| Earth | 29/72 | 40.3% | 20.1% | 47.4% |
| Water | 43/72 | 59.7% | 29.9% | 52.3% |
| Fire | 32/72 | 44.4% | 22.2% | 48.8% |
| Air | 40/72 | 55.6% | 27.8% | 51.4% |

The installed gameplay changes are **Air Ball's base lock 0.75 seconds, Gust's per-mode lock 0.45 seconds, and Fire's stock-ring NPC spacing `[2,6]` m**. Slice stays 0.5, Pull/Slam 0.35. Damage, launch growth, weight, Earth Catch/return/rally and projectile geometry are unchanged from the inherited baseline. The slower Air commitments preserve powerful finishers while offering a longer response window. Fire moves closer for its existing short-range kit; its weight and Ember spread were not increased or narrowed.

Earth and Water remain near the screening edges, and the matrix still shows strong matchup differences. This is an observed normal-bot screen around the owner's 25% pooled target, **not proof of exact equality or human skill curves**. Median game time was 340.5 seconds. Strings still have median 1, and the broader historical soak/diversity targets are not all met. Full [144-game report and matchup matrix](../../artifacts/tidebreak_balance/final_c_144_report.md) and [machine-readable report](../../artifacts/tidebreak_balance/final_c_144_report.json) retain every result. The [original 72-game failure](../../artifacts/tidebreak_balance/combined_c_report.md) is preserved separately.

Reproducibility evidence is durable in [primary C](../../artifacts/tidebreak_balance/primary_c/manifest.json), [holdout C](../../artifacts/tidebreak_balance/holdout_c/manifest.json), and replication shards [107300](../../artifacts/tidebreak_balance/replication_c_107300/manifest.json), [127300](../../artifacts/tidebreak_balance/replication_c_127300/manifest.json), [147300](../../artifacts/tidebreak_balance/replication_c_147300/manifest.json): complete logs, exact runtime-override harnesses, source/effective-config snapshots, hashes and realized seed schedules. No script errors or changed snapshotted source were found during the samples. Shard 147300 also retained sandbox log-file, certificate and process-priority startup warnings; all its games completed normally. The directory is git-ignored and has `.gdignore` so source snapshots cannot register duplicate Godot classes.

The independent quantitative regression was repaired to the inherited calibration and passed 36/36 with no relaxed tolerances. Launch arithmetic, one-volley counting, staling, 16 guard pairs, Catch/return/rally and Patch restrictions remain checked. The [before/after tests and canonical log](../../artifacts/tidebreak_balance/quantitative/manifest.json) preserve the original 9 stale-reference failures and successful repair. C's real Pop→Gust probe passes 8/8 at 0% and 150%; the installed canonical rechecks are recorded below. Neither check substitutes for human playtesting or the full beginner gate.

## Historical inherited baseline

The inherited baseline **did not meet the 40–60% non-mirror win target**. This is a measured current-build baseline, not the historical Water 94% / Air 0% result. Character presentation and beginner onboarding are verified separately. No gameplay data was changed during this baseline.

| Element | Cross-element wins | Personal 1v1 win rate | Credited lives won / decided | Life share |
|---|---:|---:|---:|---:|
| Earth | 9 / 18 | 50.0% | 44 / 89 | 49.4% |
| Water | 8 / 18 | 44.4% | 41 / 86 | 47.7% |
| Fire | 7 / 18 | **38.9%** | 41 / 86 | 47.7% |
| Air | 12 / 18 | **66.7%** | 48 / 87 | 55.2% |

The owner subsequently clarified the goal as **25% of pooled wins per equally represented element**, with different skill curves. In these 36 cross-element games the pooled shares were Earth **9/36 = 25.0%**, Water **8/36 = 22.2%**, Fire **7/36 = 19.4%**, Air **12/36 = 33.3%**. The per-element win percentages in the table use a different denominator: 18 appearances each. Including the mirrors, the pooled totals were Earth 12/48 = 25.0%, Water 11/48 = 22.9%, Fire 10/48 = 20.8%, Air 15/48 = 31.3%. Fairness is judged primarily on cross-element games so guaranteed mirror wins do not hide imbalance.

Across both seats and all three passes: Earth beat Water 1/6, Fire 3/6 and Air 5/6; Water beat Fire 3/6 and Air 0/6; Fire beat Air 1/6. The results show strong matchup differences; they do not establish one uniform power multiplier as the cause.

All 48 games reached DONE: 36 cross-element games and 12 mirrors. Game duration was **149–451 seconds, median 317 seconds**, within the 240–420-second median target. Mirror seat-0 / seat-1 wins were Earth 1/2, Water 0/3, Fire 2/1 and Air 1/2. Three mirrors per element are insufficient to establish a seat bias. Every lost stock was credited to the opponent in this sample.

The string distribution over all 48 games was **4,305 one-hit, 137 two-hit, and 22 three-or-more-hit strings**: 96.4% single hits, median **1**, below the target of 2. The log combines lengths 3 and above; it cannot verify the exact longest string. Individual life duration, recovery success, healing share and the complete soak targets were not measured by this quick-run script.

| Cross-element launch events / casts | Observed count |
|---|---:|
| Water Geyser | 317 / 376 |
| Water Wave, including grown | 287 / 472 |
| Fire Kick, including grown | 137 / 436 |
| Fire Punch, including grown | 129 / 371 |
| Air Ball | 205 / 624 |
| Air Gust, including grown | 303 / 796 |

These are the test's `BAL HITS` launch events, not damage totals or a controlled measurement of hit probability. Water's high contact count does not imply the historical 94% win rate persists. Air Ball delivered **25/48 (52.1%)** of Air's cross-element KOs; Gust delivered 19, grown Gust 1, and Slice 3. This makes Air Ball a specific tuning candidate, while leaving Air's poor Earth matchup relevant.

The maximum per-game share of one cast key, including mirrors, was Earth **40.0%** (`stone_catch/catch`), Water 24.7%, Fire 29.1%, Air 25.5%. Earth exceeds the latest HANDOFF target of 30%. Catch and its E-return share one counted key. Do not weaken Catch or rally merely to lower this count: switching more returns to Shove changes their lock time (0.5 seconds versus Catch's 0.2 before modifiers). Across cross-element games, Earth used 10 distinct cast keys, Water 12, Fire 12 and Air 11.

Reproduction:

```sh
GODOT_TIMEOUT=1250 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . \
  -s tests/ring/test_balance.gd -- mirrors=1 passes=3 limit_s=1200
```

Godot 4.7.2 Mono; stock rules, 3 lives, 480-second fight clock, time scale 1, 120 physics ticks/second, normal bots (the current `MatchSetup.difficulty` default), isolated `user://test_balance.cfg`, no player participation. The test calls `seed(1750)`, starts its private bot-seed base at **9100**, assigns the round seed as that base plus `101 * completed_games`, and adds 13 to the base when creating each spectator-side bot. No explicit `seed=` argument was passed; `seed=7300` gives the same starting base. Three passes repeat the ordered 16 pairings with advancing seeds, rather than resetting the same seed each pass.

The measured rules had `stock.pct_scale = 0.95`, weights Earth 1.0 / Water 0.95 / Fire 1.1 / Air 0.9, Air Ball growth 16, and Air's generic `* → jab` follow-up absent. Input snapshots are in `/private/tmp/frontier-astra-verify/balance48-inputs`; rules SHA-256 `0ee8da604d3a28b208df52745b9b127a519ffc773edf8b1b9c9d582770989d6c`, AI data SHA-256 `c493b7dd8f03a113539690c2220a2b7fea6921fc00b54ce97ab8f1b73fea54cc`.

The runner exited 0 with **BALANCE PASSED (6 checks)**. That is only its smoke gate: `tests/ring/test_balance.gd` caps credited-life share at 70%, and checks game wins only after 24 games per element, also against an upper 70% limit. This run has 18 games per element; neither the required 40–60% win band nor the string/diversity targets were gated. **The smoke pass is not balance acceptance.** There were no `SCRIPT ERROR` lines. Shutdown reported 394 leaked ObjectDB instances and six resources still in use; these remain separate cleanup findings.

Full log: `/private/tmp/frontier-astra-verify/balance-48.log`. Parsed per-game/per-move results: `/private/tmp/frontier-astra-verify/balance-48.analysis.json`. Parser: `/private/tmp/frontier-astra-verify/analyze_balance.py`.

## Rejected candidate A

Candidate A changed only runtime data: Air Ball growth 16 → 14.5 and Fire weight 1.10 → 1.15. No canonical gameplay file was edited. The primary sample used explicit `seed=7300`, `difficulty=normal`, `mirrors=1`, `passes=3`; its 48 games again gave 18 cross-element appearances per element. A separately snapshotted holdout used fresh `seed=27300`, `mirrors=0`, `passes=3`, normal difficulty, and an isolated settings file: 36 games, also 18 appearances per element.

| Element | Primary personal wins | Primary pooled share (36) | Holdout personal wins | Holdout pooled share (36) |
|---|---:|---:|---:|---:|
| Earth | 10/18 = 55.6% | 27.8% | 7/18 = 38.9% | 19.4% |
| Water | 8/18 = 44.4% | 22.2% | 7/18 = 38.9% | 19.4% |
| Fire | 7/18 = 38.9% | 19.4% | 9/18 = 50.0% | 25.0% |
| Air | 11/18 = 61.1% | 30.6% | 13/18 = 72.2% | 36.1% |

**A is rejected:** neither sample meets the 40–60% personal-win screen, and the independent sample leaves Air stronger. Primary credited-life shares were Earth 45/88 (51.1%), Water 44/88 (50.0%), Fire 39/86 (45.3%), Air 46/86 (53.5%). Primary median duration was 308 seconds; strings were 4,430/159/17 in the one/two/three-plus buckets. Air Ball still produced 20/46 Air KOs. Holdout median duration was 348.5 seconds; strings 3,541/114/6, median 1. Both completed without script errors and passed only the legacy smoke gate.

Even a primary Earth mirror whose two element-specific overrides should not affect combat differed from the earlier baseline. The seeded harness is not demonstrated to be bit-identical between runs; do not attribute every changed outcome solely to the candidate values. The full primary log is `/private/tmp/frontier-astra-verify/balance-candidate-a-48.log`; independent artifacts and realized seed schedule are in `/private/tmp/frontier-astra-verify/holdout_candidate_a_27300`.

## Fire range probe and candidate B

Before choosing B, a geometry probe fired **480 first Ember volleys**: 40 fixed seeds (`88100 + trial * 101`) per cell, distances 3/5/8 m, aim scatter 0°/2.2°, spread 9°/6°. It used the real effect and stock-damage path, a held Air target, no guard, fresh stale ledger and an isolated config. This is a projectile-geometry test using `BodyBendCaster`, not full moving-opponent AI performance. The stock scale is 0.95, so a complete seven-pellet volley gives 6.65%.

| At normal 2.2° aim scatter | 3 m mean % / any hit | 5 m mean % / any hit | 8 m mean % / any hit |
|---|---:|---:|---:|
| Current 9° spread | 4.8688 / 40 of 40 | 2.1138 / 36 of 40 | 1.5675 / 38 of 40 |
| Probe-only 6° spread | 6.1275 / 40 of 40 | 3.4200 / 39 of 40 | 1.8525 / 33 of 40 |

The current spread rewards close play. B therefore changes Fire's stock-ring NPC spacing from `[3,8]` to `[2,6]` m, leaving player spread and damage untouched. Its other isolated change gives Air Ball its own **0.75-second lock**, up from Slice's shared 0.5-second base; Slice remains 0.5. Air Ball's growth stays **16** and Fire's weight stays **1.10**. This preserves large finishing launches while adding commitment to Ball. Earth Catch, return and rally are untouched. B was tested in isolation and is not accepted; its complete results follow below.

B uses the same 48-game primary schedule (`seed=7300`, normal, mirrors=1, passes=3) and a fresh independent 36-game holdout (`seed=47300`, normal, mirrors=0, passes=3). Both use a 1,200-second in-test watchdog and a 1,250-second wrapper timeout; settings files and snapshots are distinct. B logs actual damage per tag in addition to casts, launches, KOs, strings, seeds and NPC string decisions. Source and hashes, including the rendering-only trail-cleanup fix, were saved before launch in `/private/tmp/frontier-astra-verify/candidate-b-inputs`; primary harness `/private/tmp/frontier-astra-verify/balance_candidate_b.gd`. No canonical gameplay data has been changed for B.

Do not change combo timing merely to chase the string median. Early candidate-A string diagnostics showed many planned strings but few delivered follow-ups; this remains a separate, incomplete investigation. Full fairness and skill curves require more than one normal-bot sample. Root's `tools/ring/balance_report.py --require-balanced` checks complete equal ordered schedules with at least three games per ordered pairing and the explicit 40–60% personal-win screen; its two denominators are distinct from the legacy smoke gate.


## Candidate B result: not accepted

Both predeclared samples completed without script errors or changed input hashes: primary 48/48, holdout 36/36. Each has 36 cross-element games and 18 personal appearances per element. Combining them gives **72 cross-element games, 36 appearances each**, with the primary's 12 mirrors excluded.

| Element | Primary personal wins | Holdout personal wins | Combined personal wins | Combined pooled share of 72 |
|---|---:|---:|---:|---:|
| Earth | 8/18 = 44.4% | 9/18 = 50.0% | 17/36 = 47.2% | 23.6% |
| Water | 7/18 = 38.9% | 9/18 = 50.0% | 16/36 = 44.4% | 22.2% |
| Fire | 11/18 = 61.1% | 6/18 = 33.3% | 17/36 = 47.2% | 23.6% |
| Air | 10/18 = 55.6% | 12/18 = 66.7% | 22/36 = 61.1% | 30.6% |

Combined credited-stock shares were Earth 48.5%, Water 48.8%, Fire 49.7%, Air 52.9%. The pooled screen still fails Air's win rate. Fire's strongly differing samples are a reason to avoid a broad Fire buff based only on the holdout. All counts are finite-sample observations, not exact underlying win probabilities.

| Winner against opponent, both seats | Earth | Water | Fire | Air |
|---|---:|---:|---:|---:|
| Earth | — | 4/12 | 5/12 | 8/12 |
| Water | 8/12 | — | 6/12 | 2/12 |
| Fire | 7/12 | 6/12 | — | 4/12 |
| Air | 4/12 | 10/12 | 8/12 | — |

Primary median duration was 312.5 seconds, holdout 345 seconds. Across all 84 games, strings totaled 7,836 one-hit / 384 two-hit / 26 three-plus, still median 1. Primary's largest cast share was 39.1% for Earth Catch/return; that mechanic was not changed. Air's91 cross-element KOs split Ball 41, Gust 37, grown Gust 6, Slice 7: Ball commitment did not remove satisfying KOs, but Gust remains a major quick finisher.

Actual damage logging adds context to launch counts. Across the 12 Air–Water games, Air dealt 4,984.3% and credited 34 KOs (146.6 damage per KO); Water dealt 4,735.8% and credited 24 KOs (197.3 per KO). Air Gust supplied 1,734.5% from 219 launches/489 casts and 15 KOs; Ball 902.5% from 120 launches/321 casts and 17 KOs. Across Air–Fire, Air Gust supplied 17 KOs plus 3 grown, Ball 10; Fire's High Kick made 198 casts but only 17 launches, 184.9% damage and zero KOs. Damage per KO is an aggregate efficiency observation, not a measured victim launch threshold.

These findings motivate two separate investigations without changing force: Gust's current 0.35-second base lock versus Wave/Kick 0.6, and High Kick's NPC lead estimate versus its real lob flight. Do not combine both changes before isolating their effects. No candidate-B changes were installed in canonical data.

Reports: `/private/tmp/frontier-astra-verify/candidate-b-primary-report.md`, `/private/tmp/frontier-astra-verify/candidate-b-pooled-report.md`; corresponding JSON files retain the full matrix. Independent holdout artifacts, all 36 realized seed records, source/effective-config manifests and actual per-tag damage are under `/private/tmp/frontier-astra-verify/holdout_candidate_b_47300`. Primary full log: `/private/tmp/frontier-astra-verify/balance-candidate-b-48.log`.

## Candidate C: completed predeclared validation

C retains B's Fire spacing and Air Ball commitment, and changes only the normal Gust mode's base lock from 0.35 to 0.45 seconds. Pull and Slam stay 0.35, and all damage, growth, weights, Catch, return and rally rules remain intact. The real `test_r3_combo.gd` probe passed 8/8: Pop→Gust remains a true string at 0% and 150%, with impact 0.55 seconds after Pop rather than 0.45. Slice's previously false string remains false; the test was not relaxed.

Before inspecting any C outcomes, acceptance was set to the unchanged **40–60% personal win screen (20–30% pooled share)** over **72 equally scheduled cross-element games**: two 36-game sets, each of 12 ordered pairings ×3, normal difficulty, no mirrors. Primary CLI seed 67300 and independent holdout seed 87300 are both fresh. Each set has 18 appearances per element, combined 36. Individual sets and matrices will also be reported; there will be no mid-run tuning or selection of favorable games. In-test watchdog 1200 seconds, wrapper 1250 seconds, separate settings and source/effective-config snapshots. Primary harness `/private/tmp/frontier-astra-verify/balance_candidate_c.gd`; combo log `/private/tmp/frontier-astra-verify/combo-c.log`; source snapshot `/private/tmp/frontier-astra-verify/candidate-c-inputs`.

The separate Fire High Kick NPC lead mismatch is recorded in `/private/tmp/frontier-astra-verify/candidate-b-fire-air-diagnosis.md`. It is not mixed into C: pooled Fire won 17/36 in B, and the residual Air advantage spans both Fire and Water.

Durable source finding for that follow-up: `scripts/bending/bend_effects.gd:270` supplies nominal speed 22 to `NpcBendCaster.target_point`; `scripts/npc/npc_bend_caster.gd:72` leads horizontally using distance/speed. The ground crescent instead uses `scripts/bending/bend_throw.gd:69` and its `lob_velocity` solver at line 126: a 2 m apex with gravity 9. At equal start/target height, that is 1.333 s flight, compared with the nominal 0.136–0.273 s at example distances 3–6 m. The airborne straight variant follows another path, and the balance cast bucket does not distinguish variants. Primary High Kick versus Air was 96 casts/7 launches/78.9% damage/0 KOs; holdout 102/10/106.0%/0. These observations establish a prediction/trajectory mismatch and repeated low output, not the cause of every missed cast. A future isolated moving-target probe should compare actual flight, miss offset and hits at 3/6/10/16 m, separately for ground lob and airborne straight, preserving difficulty lead/scatter, force and player aim.


C completed 72/72 games with no script errors or changed snapshotted inputs. Primary seed 67300 gave Earth 6/18, Water 14/18, Fire 7/18, Air 9/18; independent seed 87300 gave Earth 8/18, Water 8/18, Fire 10/18, Air 10/18. Combined credited-stock shares were 45.8%, 52.6%, 50.3%, 51.1%, respectively. Duration range 201–470 seconds, median 347 seconds. Strings totaled 7,238 one-hit / 288 two-hit / 38 three-plus, still median 1. Largest per-game cast shares were Earth 32.2%, Water 30.8%, Fire 28.5%, Air 26.2%; Earth Catch/return and Water guard account for the first two, so those counts do not establish offensive spam. Distinct cast keys were 10/12/12/11. Air's 89 KOs were Ball 39, Gust 37, Slice 11, grown Gust 1 and Palm 1. The full finishing force remained available, but the broader historical string/diversity targets are not all met.

| C wins against each opponent, both sets and seats | Earth | Water | Fire | Air |
|---|---:|---:|---:|---:|
| Earth | — | 3/12 | 3/12 | 8/12 |
| Water | 9/12 | — | 8/12 | 5/12 |
| Fire | 9/12 | 4/12 | — | 4/12 |
| Air | 4/12 | 7/12 | 8/12 | — |

The original 72-game screen is a recorded failure. No further parameter change is justified merely by a one-result near miss; any additional frozen-C replication must be declared before its outcomes are inspected, retain all previous C games, and keep the same screening band.

## Completed frozen C replication, declared before outcomes

Exactly 72 additional games were run as three independent 24-game shards: seeds 107300, 127300, 147300, each of all 12 ordered cross-element pairings ×2, normal difficulty, no mirrors. Each copies the validated C harness and changes only its settings filename. The final screen uses **all 144 C games**, preserving every original and replication result, the same complete/equal-schedule requirements, and the same 40–60% personal / 20–30% pooled band. No C parameter changes or interim outcome-based decisions are allowed.

The quantitative test repair was installed and its canonical command passed 36/36 before replication snapshots were taken; gameplay data remained untouched until all 144 outcomes were evaluated. Per-shard logs, exact harnesses, source/effective snapshots, hashes and realized seeds are kept in `artifacts/tidebreak_balance/replication_c_107300/`, `replication_c_127300/` and `replication_c_147300/`. Both independently run shards remained sealed until their processes finished.

The three replication shards completed 24/24 each without script errors or changed input hashes. Wins by Earth/Water/Fire/Air were 5/9/4/6 at seed 107300, 3/9/4/8 at 127300, and 7/3/7/7 at 147300; each element appeared 12 times per shard. Every game was included in the final 144-game report. Total string buckets were 14,229 one-hit / 579 two-hit / 71 three-plus. The normal-bot matrix remains asymmetric: Earth beats Air 17/24 but Fire 5/24; Water beats Earth 17/24 and Fire 16/24 but Air 10/24. Preserve those limits when describing this result.

Final installation matched the tested effective JSON exactly apart from refreshed explanatory fields. Canonical post-install checks passed: `test_r3_combo.gd -- real=on` 8/8 (Pop→Gust true at 0% and 150%) and `test_ring_pct.gd -- mode=ring element=earth foe=water` 36/36, all metric flags true, no script errors. See the [installed configuration manifest](../../artifacts/tidebreak_balance/installed_c_manifest.json), [canonical combo log](../../artifacts/tidebreak_balance/quantitative/combo_installed_c.log) and [canonical quantitative log](../../artifacts/tidebreak_balance/quantitative/pct_installed_c.log). Existing teardown ObjectDB/resource warnings remain separate from those passing checks.
