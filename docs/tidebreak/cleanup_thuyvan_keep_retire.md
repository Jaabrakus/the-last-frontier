# The Thủy Vân session's explicit keep/retire list (2026-10-05; from its thuyvan_plan/inventory.md and plan §5)

Thủy Vân has NO firearms (no gunpowder in the owner's world).

## KEEP (Thủy Vân reuses)
core/; the player controller + player/anim core (only the gun modules go); the character body, ragdoll, wounds;
animations/ and animations_extra/; traversal/; climb/ (grip, perches, tree climb); net/; save/ engine; world/nav pathing;
world/env (sky, weather, clock — retune); settings; fx/ (minus powder smoke); interact/ engine; inventory, hotbar, equip
wheel, how_to, HUD and menus (reskin); the audio engine + MusicDirector + tools/music; survival core/engine; the
companion/household engine; rts/; world/water (WorldRiver, RiverWater) and boats/WaterSurface; boats/ (all); the building
engine + StoreLedger; gathering, forage and farming engines; fishing/; wildlife/fish; the wildlife engine + the bison
generator (becomes buffalo); horse/ (few horses); torch/; fire/; story_layer + the story ENGINE (StoryDirector,
Objectives, Effects, Dialogue, Contact, Bark, Walker, Actor; Captivity if a mission needs it); the customizer engine and
the cloth2 pipeline; tattoo + PeopleEmblem systems; the terrain engine + bake tools; the vegetation engine; the
structures kit (StructureMeshKit etc.); CC0 Poly Haven assets (owner: CC0 stays); the BOW, the THROWING SPEAR,
Projectile and the Weapon base (the saber pose becomes the dao); all of Tidebreak (sway/, bending, ring, npc_bending).

## RETIRE (safe to delete from Thủy Vân's side)
- Firearms: weapons/ guns (Musket, FlintlockPistol, Firearm, OverUnder*, MusketReload, MusketButtGround, ballistics,
  gun WeaponModels, data/weapons range_research); gun-only anim modules (left_grip_ik and other gun IK/aim pieces,
  JogAimArm's musket use); WeaponAudio's gun sounds; Fx powder smoke; NPC muskets; HuntKit guns. Keep the player building
  and animating with the bow and spear after removal (gun removal is flagged as an animation-regression risk).
- Loadout: loadout/ (SlingRig, powder horn, cartridge box) and data/loadout.
- Old story/setting content: story stages RaidStage, MarchStage, RookWalk, SkyBattle, WreckFall, StorySlice and the Two
  Fires/1757 story data; fort and range (FrontierStructures, FortHollow, FortGate, FortPieces/Plan, PalisadeCuts,
  TargetDummy, data/building/fort_*); mammoth (StandInGiant, MammothTemper/Butchery, assets/wildlife/ice_age); the wonder
  sky and sky galleons; docs main_story.md, maps.md, peoples_world.md.
- Old peoples content: the 35 real peoples' content (creator emblems, groups, presets, recruit region_peoples) and the
  invented test peoples (Downbelowers, Driftborn, Keelfolk, the Etched); period garments (colonial, frontier, military,
  militia, woodlands, drift and the other real-people sets) and period hair (bag wig, queue, chonmage, qing queue);
  real-people tattoos.
- Duel: duel/ (the musket duel) — only after MatchSetup's use of DuelMode paths is cut.

## UNDECIDED / NOT YET (the Thủy Vân greybox runs on these until cutover — do NOT delete now)
frontier_level.gd (thuyvan_level is a trimmed copy calling the same systems); the baked terrain, data/world/squares.json
and its river block (r1_grey reuses them); North American vegetation, wildlife species, forage plants and crops (retire
as replacements land); the garments the Mountain Folk preset uses today; the frontier music cues and bird ambience;
thuyvan's baseline tests tests/world/test_river.gd, test_story_layer.gd, tests/wildlife/test_fish.gd,
tests/boats/test_boat.gd, tests/fishing/test_fishing.gd; snow/ and RiverIce (only if the owner wants a cold high
Trường Sơn); the 1765 survival calendar/data (rewrite, don't delete); tests mentioning frontier content (re-stage, don't
delete); the Sway/Form naming (rename, don't delete).

## Housekeeping already done by the Thủy Vân session (on the owner's request)
Removed the unused worktrees: arena-8v8 (its uncommitted 8v8 work committed onto its branch as 3f9fdaa first), the
three rejected look-revision worktrees (stray files committed first), wf_1890677f-aae-2 (R2 KITS finish, merged). All
branches kept. Locked worktrees and Codex's Frontier_wt/agls-comparison untouched.
