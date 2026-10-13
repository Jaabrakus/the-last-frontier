# Spellbreak effects imported into Tidebreak

Everything under `assets/fx/spellbreak/` is taken from **Spellbreak** by **Proletariat Inc.** (Unreal Engine 4.22
Cascade particle systems, their textures, particle meshes and material parameter values), extracted from the
community Windows client. It is third-party content, not Tidebreak's own art. Keep this attribution with it.

- **Source archive:** the verified full-client backup `spellbreak-client-source.zip` (sha256 82a604de...439d), now
  on the external drive "The one" (`/Volumes/The one/Frontier_offload/Spellbreak_source_backup/`); see
  `docs/claude_fx_handoff.md` ("Source folder retirement / full backup").
- **Conversion:** `tools/reference_animation/extract_fx_closure_from_zip.py` (package closure),
  `fx_spec.py` (one runtime spec per particle system, the source's own baked distribution tables),
  `fx_materials.py` (material instances resolved through their parent chains),
  `artifacts/spellbreak_fx/tools/export_assets.py` (UE Viewer export: textures as PNG, meshes as glTF).
  Copied here by `tools/fx/import_spellbreak_fx.py`; files are unchanged copies of the browser's exports.
- **What is authored here (not Spellbreak's):** the shader math in `shaders/cascade/` and the family mappings in
  `data/fx/cascade_families/` (the cooked material graphs were stripped; see `artifacts/spellbreak_fx/README.md`),
  and the Cascade runtime `scripts/fx/cascade/`.
- **Licence:** the owner's note in `animations/SOURCE.md` (section "Elemental presentation polish (2026-10-08)",
  last line, "Spellbreak licence (2026-10-08)") records that Proletariat licensed all Spellbreak assets for use in
  Tidebreak, including public release. That note's pointer to the written grant still reads "[where you keep it]":
  the grant's location is not recorded in the repository yet. This file records attribution; it is not itself a
  licence.

<!-- third-party-packs: begin (rewritten by tools/fx/import_spellbreak_fx.py) -->
## Third-party packs inside the Spellbreak client

The client keeps some files under `MarketplaceAssets/<pack>/`. The folder name suggests content from Unreal Engine Marketplace packs by third-party authors rather than Proletariat's own art; the repository does not record their authors or terms, nor whether the Spellbreak licence noted in `animations/SOURCE.md` covers redistributing them. Check before a public release.

| Pack | Effects using it | Files |
| --- | --- | --- |
| `VFX_Toolkit_V1` | `P_Frozen_Explosion` | 5 textures/meshes (`assets/MarketplaceAssets/VFX_Toolkit_V1/`) |
<!-- third-party-packs: end -->

## Lightning bolt shading (textures read directly, 2026-10-09)

Tidebreak's own lightning bolt (`BendLooks.SB_BOLT` in `scripts/bending/bend_looks.gd`, shader
`shaders/cascade/lightning_bolt.gdshader`; the owner, 2026-10-09: "for lightning i like our lightning but maybe make it
look like spellbreaks or use its shaders") is shaded after Spellbreak's lightning materials and reads two textures of
this pool directly, not through an imported effect. Keep both files even if no imported effect lists them any more.
They are the same unchanged copies of the browser's exports (`artifacts/spellbreak_fx/assets/`) already in the pool.

| File (under `assets/`) | Source package | Spellbreak material slot | Used for |
| --- | --- | --- | --- |
| `VFX/Textures/T_f_GenericLighting_F.png` | `/Game/VFX/Textures/T_f_GenericLighting_F`, Spellbreak (Proletariat), community Windows client | "Lightning Bolt" of `MI_f_lightningBranchingBolt` (root `m_f_lightingToonErosion`; GauntletLightningMuzzle_FX, browser row 146) | the bolt's toon plateaus (white-hot core, sheath, fringe) |
| `VFX/Textures/T_f_SmokeHeight_Greyscale_Uncompressed.png` | `/Game/VFX/Textures/T_f_SmokeHeight_Greyscale_Uncompressed`, Spellbreak (Proletariat), community Windows client | "Noise 1" / "Noise 2" of `MI_f_lightningBranchingBolt`, `_Bolt3`, `_Bolt4` (rows 146 and 152 Shock2StrikeNew_FX) | the stepped crackle (UV noise) |

Parameter values taken from Spellbreak: FPS 15, noise strength 0.3, Noise Size Multiplier 0.77, the noise and bolt
panners, Edge Softness 0.1 and the toon erosion (`MI_f_lightningBranchingBolt3`/`4`, `artifacts/spellbreak_fx/materials.json`),
and the blue-violet HDR colour of the bolts' ColorOverLife in rows 146, 148 (LBolt_ProjectileBeam_WildRev2FX), 150
(Lightning_Shocked01_FxP) and 152. Tidebreak's own, not Spellbreak's: the bolt's geometry, path, forks, flicker and timing
(`ToonFx.lightning_strips`, `ToonFxPool.lightning`), the shader math (the cooked graphs were stripped), the band levels and
on-screen colours, the way it dies (the cut follows the fade from its first frame and the core goes before the sheath,
as our cel bolt dies; 2026-10-10), the calmer main stroke (less noise push, bands nearer a smooth profile), the violet
sparks and stars round it (`ToonFx` recipes `spark_sb`, `star_sb`: our particles, recoloured), and the short forks at the
hand, the charge and the strike (our forks, in the manner of row 146's "Lightning Mulit Center" and row 150's "Torso
Forks"). `BendLooks.SB_BOLT = false` restores the old cel bolt.

## Imported effects

One row per effect (source package = the runtime id used by `SpellFx.spawn`). Files: the effect's spec in
`specs/<id>.json`; its textures and meshes are in the shared pool `assets/` (paths mirror the source packages) and
listed per effect in `index.json`.

| Effect id (source package) | Source | Used for (bending_fx_map.json first picks) | Textures | Meshes | Imported |
| --- | --- | --- | --- | --- | --- |
| `g3/Content/VFX/Cosmetics/Triumph/Triump_Earth01_Ground_FxP` | Spellbreak (Proletariat), community Windows client, browser row 694 | earth earth_shove:push: kick-up (stone popped at the feet); earth rooted: root takes hold (one-shot when the caster goes still); earth stone_form:cannonball: stamp + push launch ('left kick, stamp, push'); earth stone_form:spike: rise: ground burst as the spike comes up (60% of the lock) | 6 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/FX_RocksTravelCharge` | Spellbreak (Proletariat), community Windows client, browser row 80 | earth earth_shove:push: grow (held past 0.45 s: a bigger stone); earth stone_form:spike: hang / charge while the lock is held | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/BoulderSmall_FX` | Spellbreak (Proletariat), community Windows client, browser row 77 | earth rock_jab:pebbles: pebble flight (three tumbling stones); earth rock_jab:pop: pop stone thrown with E (0.22 m, 34 m/s); earth stone_form:spike: lance flight (point first, pierces) | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Quests/Shared/SmkObscureS_FxP1` | Spellbreak (Proletariat), community Windows client, browser row 839 | earth earth_shove:push: hit (on a body); earth earth_shove:slam: hit on a body (spiked down at -70 deg); earth earth_wall:wall: hit / chunk torn off (wall face); earth rise:pillar: pillar hit (rise/pillar, set 9 m/s at 80 deg); earth rock_jab:air_hit: knee hit; earth rock_jab:pebbles: light hit; earth stone_form:spike: pierce impact (on a body; the spike flies on) | 12 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/BoulderMedium_FX` | Spellbreak (Proletariat), community Windows client, browser row 76 | earth earth_shove:push: shoved stone flight; earth stone_form:cannonball: boulder flight (arcs, gravity 6) | 6 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor` | Spellbreak (Proletariat), community Windows client, browser row 78 | earth clash:stone: two stones meet mid-air and break; earth earth_wall:wall: crumble (shot down, or a third wall); earth stone_form:cannonball: landing impact (heavy) | 15 | 7 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/Emote/PushUps/Emote_PushUp_FootDrag_FxP` | Spellbreak (Proletariat), community Windows client, browser row 558 | earth earth_skate:burrow: under-the-deck travel line (0.3 s); earth stone_form:cannonball: roll along the floor (after landing) | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/P_EarthShockwaveMuzzleFire` | Spellbreak (Proletariat), community Windows client, browser row 84 | earth earth_shove:push: push cast (two-hand push); earth rock_jab:pebbles: flick; earth stone_catch:catch: perfect catch flash (first 0.3 s) | 5 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/P_Shockwave_Earth_Fast_ToonUnlit` | Spellbreak (Proletariat), community Windows client, browser row 85 | earth earth_shove:column: pillar bursts up under the target (no mark beforehand); earth earth_wall:wall: rise along the foot (0.7 s); earth pillar:self: pillar rises under the caster; earth rise:pillar: pillar shoots up under the airborne caster (5.5 m in 0.45 s, leaning 20 deg); earth rock_jab:pop: pop hit (launches at 80 deg, stun 0.6) | 5 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/Movement/LandingDust_FX` | Spellbreak (Proletariat), community Windows client, browser row 157 | air air_blast/slice: dust line off the deck under a low air bolt (AirDust, < 1.5 m); air air_shield/shield: stone dropped at the feet (perfect vs stone); earth earth_shove:column: sinks 1.5 s later; earth rise:pillar: pillar sinks 0.4 s after the top; earth stone_form:drop: a raised or held stone falls to the deck and becomes loose | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Trails/DropImpact_FX` | Spellbreak (Proletariat), community Windows client, browser row 190 | air air_gust/slam: ground impact on the deck; earth earth_shove:slam: downward smash on the deck (when the deck is within 3 m); earth earth_skate:burrow: dive into the deck; water wave/slam: slam lands on the deck | 4 | 4 | 2026-10-09 |
| `g3/Content/Characters/Cloudburst/ObsidianPlummet/CB_ObsidianPlummet_Unified_FX` | Spellbreak (Proletariat), community Windows client, browser row 33 | earth earth_shove:slam: downward smear (the 0.12 s strike column) | 9 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Leap/Springstep_Finish02_FxP` | Spellbreak (Proletariat), community Windows client, browser row 144 | air air_jump/leap: landing; earth earth_skate:burrow: resurface; earth pillar:self: landing | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Leap/Springstep_Start01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 145 | air air_jump/leap: launch burst (12 m/s up); air air_jump/leap: rising trail; earth pillar:self: launch up and forward | 6 | 2 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/CloudBurst/StoneShaper/CB_StonShaper_Unified` | Spellbreak (Proletariat), community Windows client, browser row 539 | earth pillar:self: airborne trail; earth stone_catch:catch: thrown back (E again; faster each rally) | 6 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/Stoneskin02_FxP` | Spellbreak (Proletariat), community Windows client, browser row 86 | earth earth_wall:wall: shell (open-world mode only, 3 s); earth mend: stones set again on your own wall; earth patch: heal on self (earth flavour); earth pillar:self: pillar crumbles / sinks (1.5 s); earth stone_catch:catch: guard window (1.0 s, 3.5 m) | 6 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/Earth/Gauntlet_Stoneshaper_Idle01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 83 | earth rock_jab:pop: pop stone kept in the hand; earth stone_catch:catch: stone held (caught) | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Quests/ShrineBuffs/ShrineB_Earth_FxP` | Spellbreak (Proletariat), community Windows client, browser row 841 | earth rooted: rooted idle at the feet (standing still) | 8 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Lance_MuzzleFlash01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 134 | water water_whip: cast flash at the hands | 2 | 0 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/CloudBurst/RiversReflection/CB_RiversReflection_FxP` | Spellbreak (Proletariat), community Windows client, browser row 516 | water flow/surf: ridden wave under the body (gap); water rise/fountain: water trailing the rising body; water water_jet: small water bolt; water water_redirect: bolt swings round you and leaves; water water_whip: water bolt head in flight (steered); water wave/push: the cone surge (gap: shape donor); water wave/slam: water hammered down from the air [missed] | 4 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Lance_IceProjectile_Trail` | Spellbreak (Proletariat), community Windows client, browser row 133 | water flowing: the curve just after release; water ice: flight trail (heavy, long); water water_whip: stream trail (bends with Flowing) | 3 | 0 | 2026-10-09 |
| `g3/Content/Blueprints/Weapons/v3/FX/P_Water_Dissipate` | Spellbreak (Proletariat), community Windows client, browser row 21 | water water_jet: splash on hit / the Pop; water water_whip: impact splash on hit; water wave/push: hit splash on the pushed body; water wave/spout: water wells up low 0-0.35 s, no deck mark | 0 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Lance_ChargeUp01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 128 | water ice: lance forms in the hand (0.6 s lock) | 5 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Lance_IceProjectile` | Spellbreak (Proletariat), community Windows client, browser row 132 | water ice: spear in flight (point first) | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Lance_Squib` | Spellbreak (Proletariat), community Windows client, browser row 137 | water ice: impact / shatter; water water_redirect: perfect (on the beat) flash | 2 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/SlowedEnd_FX` | Spellbreak (Proletariat), community Windows client, browser row 141 | water ice: one-shot frost shed on the body (no slow look) | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Mana/ManaRegenHands_FX1` | Spellbreak (Proletariat), community Windows client, browser row 154 | water wave/push: grow: held past the click, water gathers | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireWall_Extinguish_Ice_FxP` | Spellbreak (Proletariat), community Windows client, browser row 101 | fire fire_wall/wall: put out by water; water wave/push: puts out fire in the cone (put_out) [missed]; water wave/slam: puts out fire under it (put_out) [missed] | 6 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Vapor/VaporCloud_FX` | Spellbreak (Proletariat), community Windows client, browser row 192 | fire fire_breath/breath: melts ice in the cone (melt: true); water water_shield: melted by fire (steam, puddle left); water wave/spout: column erupts and throws (gap) | 13 | 6 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/BoulderFrozen_Mist_FxP` | Spellbreak (Proletariat), community Windows client, browser row 125 | water flow/skate: 3 puddles left 1.2 m, 6 s (gap); water water_shield: standing (idle cold); water wave/slam: puddle left 1.6 m, 6 s (gap) | 0 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Ice_Skate_Footstep01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 140 | water flow/skate: push-off and slide at the feet; water flow/surf: spray at the feet / knock bump | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/Afterglow/Frostborn/Frostborn_AG_FxP` | Spellbreak (Proletariat), community Windows client, browser row 250 | water flow/skate: slide wake | 5 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Blizzard_Cyl1_FX1` | Spellbreak (Proletariat), community Windows client, browser row 122 | water water_shield: freezes up (rise) | 11 | 5 | 2026-10-09 |
| `g3/Content/Blueprints/Weapons/v3/FX/P_Frozen_Explosion` | Spellbreak (Proletariat), community Windows client, browser row 12 | water water_shield: shatter (shot down / a Boulder) | 1 | 4 | 2026-10-09 |
| `g3/Content/VFX/Props/Pickups_Armor/FX_SmallArmorUse` | Spellbreak (Proletariat), community Windows client, browser row 787 | air patch/patch: restore pop (the fresh pool taken back); water mend: own wall mended: next hit free; water patch: heal: restore burst on yourself (gap) | 13 | 7 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Blizzard_Cyl1_FX2` | Spellbreak (Proletariat), community Windows client, browser row 123 | water water_jet/air_hit: ring of water round the body; water water_redirect: guard window | 8 | 4 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireProjectile_Extinguish_Ice_FxP` | Spellbreak (Proletariat), community Windows client, browser row 100 | fire fire_parry/parry: ice caught on the beat: melted; water water_redirect: fire on the beat doused | 4 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Ice/Gauntlet_Frostborn_Idle01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 127 | water flowing: water ready at the hands (idle) | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Movement/ManaJump_FX` | Spellbreak (Proletariat), community Windows client, browser row 158 | air air_gust/slam: downward blast under the caster (-70 deg column); water rise/fountain: water bursts up under you (4.5 m launch) | 4 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/GauntletFireballMuzzle_FX` | Spellbreak (Proletariat), community Windows client, browser row 116 | fire fire_blast/punch: cast flash at the fist | 6 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 112 | fire fire_blast/punch: projectile in flight | 9 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fireball_Base_Impact01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 111 | fire fire_blast/punch: impact; fire fire_jab/embers: small hits | 4 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Gauntlet_Pyromancer_Idle01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 117 | fire fire_blast/fireball: grow / charge on the fist; fire fire_kick/kick: grow on the kicking foot (held past 0.45 s); fire passive/footwork: moving aura (hands and feet) | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fireball_Pyro_Projectile01_Translucent_FxP` | Spellbreak (Proletariat), community Windows client, browser row 115 | fire fire_blast/fireball: projectile in flight | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fireball_Pyro_Impact01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 114 | fire fire_blast/fireball: explosion | 5 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/FX_LightningCharge` | Spellbreak (Proletariat), community Windows client, browser row 90 | fire fire_arc/lightning: 2.2 s charge on the hands | 7 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Lightning/GauntletLightningMuzzle_FX` | Spellbreak (Proletariat), community Windows client, browser row 146 | fire fire_arc/lightning: 0.25 s flash and crack at release; fire fire_parry/parry: lightning caught and sent back | 10 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Lightning/LBolt_ProjectileBeam_WildRev2FX` | Spellbreak (Proletariat), community Windows client, browser row 148 | fire fire_arc/lightning: strike along the aim | 5 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Lightning/Lightning_Shocked01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 150 | fire fire_arc/lightning: hit on the target | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 107 | fire fire_jab/air_hit: melee flare burst at reach; fire fire_jab/embers: spray flash at the fist; fire fire_jets/jets: end / landing burst; fire fire_kick/kick: launch at the kicking foot; fire footwork/step: push-off burst at the feet | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fire_Ignited_Shockwave_Ogles` | Spellbreak (Proletariat), community Windows client, browser row 110 | fire fire_kick/kick: travelling wave of fire along the floor (grown: wider) | 5 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireBoulderImpact_FX` | Spellbreak (Proletariat), community Windows client, browser row 97 | fire fire_kick/kick: hits / is stopped by a wall; fire fire_kick/slam: slam impact on the deck (+ short 110 wave) | 11 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireIgnite_FX` | Spellbreak (Proletariat), community Windows client, browser row 99 | fire fire_kick/high_kick: flame crescent in flight; fire fire_wall/wall: burning the one who passes (entry pop) | 3 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fireball_Conflagration_FxP` | Spellbreak (Proletariat), community Windows client, browser row 113 | fire fire_kick/high_kick: flame trail behind it | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireBImpact_FX` | Spellbreak (Proletariat), community Windows client, browser row 96 | fire fire_kick/high_kick: impact | 5 | 1 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/Afterglow/PlunderingBlast/PlunderingBlast_AG_FxP` | Spellbreak (Proletariat), community Windows client, browser row 263 | fire footwork/step: short movement trail | 3 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fire_Firefly_Launch01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 109 | fire fire_breath/breath: short cone of fire (4.5 m, 45 deg); fire fire_jets/jets: launch blast; fire rise/jet: jet launch 7.5 m along the aim, then flight | 5 | 3 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/Fire_Firefly_Hands01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 108 | fire fire_jets/jets: jet flames at the hands and feet while flying | 3 | 0 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/CloudBurst/Pyromancer/CB_Pyromancer_TrailFillBFX` | Spellbreak (Proletariat), community Windows client, browser row 513 | fire fire_jets/jets: body trail | 8 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke` | Spellbreak (Proletariat), community Windows client, browser row 104 | fire fire_wall/wall: burning idle (5 s); fire fire_wall/wall: raise (spawn) | 14 | 4 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireWall_Extinguish_Wind_FxP` | Spellbreak (Proletariat), community Windows client, browser row 102 | fire fire_wall/wall: blown through by air | 1 | 0 | 2026-10-09 |
| `g3/Content/VFX/Quests/Shared/SmkObscureM_FxP` | Spellbreak (Proletariat), community Windows client, browser row 838 | fire fire_breath/breath: smoke screen left behind (5 s) | 11 | 3 | 2026-10-09 |
| `g3/Content/VFX/Quests/ShrineBuffs/ShrineB_Pyro_FxP` | Spellbreak (Proletariat), community Windows client, browser row 843 | fire patch/patch: restore aura on the body (1.0-1.5 s, standing) | 6 | 2 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/Triumph/Triumph_Fire01_Ball01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 702 | fire fire_jab/embers: 7 small bolts | 5 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/ExplosionGauntlet_VfxP_ConflagAmulet` | Spellbreak (Proletariat), community Windows client, browser row 95 | fire fire_parry/parry: perfect: flash and ring | 5 | 4 | 2026-10-09 |
| `g3/Content/VFX/Character/Fire/FireIgniteSh_FX` | Spellbreak (Proletariat), community Windows client, browser row 98 | fire fire_parry/parry: late or whiff puff | 2 | 0 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/WindMBlast_FX` | Spellbreak (Proletariat), community Windows client, browser row 202 | air air_blast/ball: cast flash at the hands (bigger push); air air_blast/slice: cast flash at the hand (the blade leaves); air air_gust/gust: cast blast at the hands; air air_palm/palm: palm cone blast (3.5 m, 40 deg) | 2 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/WindProj_FX` | Spellbreak (Proletariat), community Windows client, browser row 204 | air air_blast/ball: projectile in flight (wind ball, 28 m/s, r 0.35); air air_blast/slice: projectile in flight (thin fast blade, 45 m/s, r 0.12) | 4 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/WindExplode_Small_FX` | Spellbreak (Proletariat), community Windows client, browser row 201 | air air_blast/slice: impact (thin hit); air air_gust/gust: hit / knock on a body (base, grown); air air_palm/palm: hit puff; air air_shield/shield: perfect guard (bounced back, Clean); air air_wall/wall: deflect flash (shot blown up and aside) | 5 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/WindExplode_FX` | Spellbreak (Proletariat), community Windows client, browser row 200 | air air_blast/ball: impact / big knock burst; air air_palm/palm: pop (third jab that hits: the set knock); air air_wall/wall: wall end (4 s up, or replaced: one at a time); air passive/carried_wind: boosted hit (x1.15 knock) | 2 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/Gauntlet_Tempest_Idle01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 193 | air air_gust/gust: grow / charge-up while held; air passive/carried_wind: charged aura (after a dash, 0.8 s) | 4 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Squall/Squall_Lvl01_01_FxP` | Spellbreak (Proletariat), community Windows client, browser row 186 | air air_gust/gust: grow click (the ring snapping out at the hands); air air_palm/air_hit: spin swipe round the caster (r 1.2 m, 0.1 s); air air_shield/shield: whiff (a dull puff at the hands); air evade/slip: dash start burst at the feet; air passive/carried_wind: charge pop (the dash charges it); air wind_run/updraft: whirl push on bodies near (hit_r 1.2 m, set 4 m/s) | 1 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Flight/work/Flight_D_FX` | Spellbreak (Proletariat), community Windows client, browser row 121 | air air_gust/gust: travelling wave (2 m wide, 18 m/s, 14 m; grown 3 m / 18 m); air air_gust/pull: outgoing wave that reads as pulling | 1 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Mana/ManaRegen_FX` | Spellbreak (Proletariat), community Windows client, browser row 155 | air air_gust/pull: caught body dragged toward the caster | 1 | 1 | 2026-10-09 |
| `g3/Content/VFX/Character/Dash/DashTrail_FX` | Spellbreak (Proletariat), community Windows client, browser row 65 | air evade/slip: dash trail (light step) | 11 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Featherfall/FeatherFall02_FX` | Spellbreak (Proletariat), community Windows client, browser row 94 | air air_jump/leap: glide (slow fall, 4 s loop; open world only); air wind_run/updraft: glide after the lift (falls 3 m/s at most) | 8 | 2 | 2026-10-09 |
| `g3/Content/VFX/Character/Wind/TornadoNewSimple` | Spellbreak (Proletariat), community Windows client, browser row 198 | air air_wall/wall: standing wall body (4 s); air air_wall/wall: wall spawn (3 x 2.5 m, placed 2-6 m out) | 10 | 8 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/Triumph/Triump_Wind01_Ground_FxP` | Spellbreak (Proletariat), community Windows client, browser row 701 | air air_shield/shield: raise + stand round the body (r 2.2 m, 0.8 s); air patch/patch: mend aura on the caster; air wind_run/updraft: whirl lift (3.5 m in 0.45 s) | 3 | 3 | 2026-10-09 |
| `g3/Content/VFX/Combat/Gateway/Gateway_Prj_Hit_FxP` | Spellbreak (Proletariat), community Windows client, browser row 211 | air air_shield/shield: late guard (half gets through) | 2 | 2 | 2026-10-09 |
| `g3/Content/VFX/Environment/LobbyElementalShrines/LobbyShrine_Frostborn01_In_FxP` | Spellbreak (Proletariat), community Windows client, browser row 732 | water water_shield/ice_wall: freezes up (rise) (the map row's third pick; data/bending/sb_fx/water.json) | 8 | 2 | 2026-10-09 |
| `g3/Content/VFX/Cosmetics/CloudBurst/Conduit/CB_Conduit_B_FX` | Spellbreak (Proletariat), community Windows client, browser row 469 | fire fire_arc/lightning: strike along the aim (the map row's third pick; data/bending/sb_fx/fire.json) | 6 | 1 | 2026-10-09 |
