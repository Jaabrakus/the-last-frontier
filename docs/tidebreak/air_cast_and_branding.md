# Airborne casting and Tidebreak branding

Local implementation and verification completed 8 October 2026. This repair addresses the owner's jump-and-Spike report, airborne attack availability, Hammer timing and the public title-screen rebrand.

## Jump and cast behavior

Spike had two separate problems. A stone raised on the deck retained its ground position when the player jumped; a fresh airborne Spike also needed 1.10 seconds of charge, longer than the measured normal jump's roughly 0.90 seconds of airtime. The stone now follows the player's hands through takeoff. Airborne Spike charges in 0.60 seconds, including during movement, and launches toward the existing crosshair target.

| Change | Before | After |
|---|---|---|
| Ground-raised stone taken into a jump | Actual launch 0.703m below airborne feet | Actual launch 1.300m above feet; target hit before landing |
| Fresh airborne Spike | 1.10s nominal charge; release 0.183s after landing | 0.60s nominal charge; measured release at 0.608s; actual stone hurl 0.017s later, before landing |
| Moving airborne Spike | No baseline moving case | Same 0.608s measured release; actual airborne target hit |
| Hammer | 0.35s nominal charge | 0.25s nominal charge; measured 0.258s stationary / 0.333s moving |
| Short-hop Hammer strike margin before landing | 0.108s | 0.200s |

The movement penalty remains 0.75 for Hammer. Spike's ground charge and Boulder's charge remain 1.10 seconds; only airborne Spike receives the 0.60-second lock and full moving fill. Damage, knockback, hitboxes and active windows were not changed by this repair. The data diff is limited to `moves.stone_form.mode_air_lock_s`, `moves.stone_form.mode_air_moving_mult` and `moves.earth_shove.mode_lock_s.slam` in [moves.json](../../data/sway/moves.json).

[SwayCaster](../../scripts/sway/sway_caster.gd) preserves earned charge time when taking off, landing or switching Spike/Boulder. It retains excess earned time without converting a percentage into free charge, and retains the release-window timer across landing/refill. Queued and automatic casts share the stun, dodge, landing-lag and ground restrictions. [FormEffects](../../scripts/sway/form_effects.gd) attaches the already-raised stone to the airborne caster without creating another stone or charging another cost.

Attacks can be cast while jumping, including Fire Breath. Walls, terrain construction and healing need ground. The gate uses spell behavior rather than treating every spell on keys 4/5 as grounded. [BendStrip](../../scripts/ui/bend_strip.gd) and the ring help use the same distinction.

For simple casting, select a move and **tap right-click**: the cast queues and fires when fully charged and allowed. Holding and releasing remains available. The eight-minute Lives round limit is unchanged, and Practice has no round timer. The measured improvement concerns the charge window inside a jump; human reaction timing and competitive element balance have not been established by these checks.

## Title screen and public name

The application/window title, boot splash, main menu, loading views and current product documentation now use **Tidebreak**. The first screen says “Elemental arena combat” and “Early playable demo · In development”. Its artwork is copied unchanged from this project's rendered arena palette captures; [asset records](../../assets/ui/tidebreak/SOURCE.md) identify those inputs.

Public creator labels now say “base outfit”, “Game daylight”, “Classic clothing” and “Survival skills”; the old hunter preset is displayed as “Hunter: musket and bow”. The clothing and loadout generators use the matching labels. The public menu leads to arena play, beginner options, appearance, settings and credits. Legacy world methods remain available to development tools. The former README is preserved in [the prototype archive](../archive/prototype_readme.md).

Existing profile storage is preserved through an explicit custom user-directory name in [project.godot](../../project.godot). The actual macOS run still uses `/Users/kiwimango/Library/Application Support/Godot/app_userdata/Frontier`; settings, saves and character choices were not moved. Windows/Linux directory settings follow the documented platform convention but were not executed here. Internal classes, resource paths, save schemas and historical records retain their compatibility identifiers. [Godot's persistent data-path documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#accessing-persistent-user-data-user) describes the custom directory setting.

## Verification and evidence

| Check | Result | Evidence |
|---|---|---|
| Casting state, ground gates, charge credit, HUD and release restrictions | 55/55 | [Casting checks](../../artifacts/tidebreak_air_cast_checks/README.md) |
| Additional timing/stun and landing release-window checks | 11/11 | Same casting record |
| Actual controller-input jumps, projectile flight and contact | 37/37 across ten cases | [Real-input record](../../artifacts/tidebreak_air_cast/README.md) |
| Rendered side and player views | 28/28 each across six cases | Same real-input record |
| Menu and match setup | 64/64 and 115/115 | [Rebrand record](../../artifacts/tidebreak_rebrand/README.md) |
| Final combined Godot script/scene check | 864 valid, zero failures | [Final verification](../../artifacts/tidebreak_rebrand/final_integration/verification.json) |
| Final display-label JSON and Python generator syntax | All pass; no GDScript changed after compilation | Same final verification |

The real-input probe uses stock Practice movement, gravity, cast inputs and target collision. It positions the fixture before a case, then performs ordinary jumps without suspending the player, teleporting during a jump or forcing a hit. Source snapshots and hashes show the final headless and rendered runs used the same runtime/data. The short-hop Hammer case verifies pose strike and landing margin; stationary and moving full-jump cases separately verify actual target contact.

Both views were visually reviewed for takeoff, airborne action, target response and landing. The normal camera is steep at the close Hammer fixture and pennants obscure some frames; the side view shows the feet/contact clearly. This is diagnostic evidence, not a camera-quality claim or a promotional trailer. The [nine-second silent clip](../../artifacts/tidebreak_air_cast/air_cast_proof_silent.mp4) is 720p60 with 540 frames, normal game speed, exact 1/60-second timestamps and no black or repeated frames. It retains the diagnostic HUD and has no promotional pixel-policy watermark. The prior trailers were not regenerated by this task.

The final compile and menu capture logs are clean. Focused runtime logs retain animation-loop and shutdown resource diagnostics. One timing/stun partition emitted “Lambda capture at index 1 was freed”; its cause was not established and this repair does not claim to fix it. The retained legacy-world menu test also logged two headless material-null errors while all assertions passed. Full logs and baseline failures remain in the evidence folders; they have not been rewritten as clean runs.

The [combined delivery record](../../artifacts/tidebreak_air_cast_branding/README.md) links the final source hashes, scoped data comparison and original root-edit snapshots. No exported package or deployed build was produced by this task.
