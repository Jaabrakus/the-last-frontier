# Woolly mammoth (Riley Kuhlman, "Low Poly Ice Age", CC0)

`mammoth.glb` is made from `ToExport/blend/Mammoth.blend` (the pack's own source file) of **"Low Poly Ice Age"** by
Riley Kuhlman (https://rkuhlf-assets.itch.io/ice-age). The pack page states: "Copyright is CC0, so you can use it for
whatever you want, commercial or noncommercial. Credit is not required, but would be greatly appreciated" (credited in
CREDITS.md).

- Downloaded 2026-09-27 with the owner's approval ("okay do both"), as a free ("name your own price", $0, no account)
  download from itch.io: `IceAge.zip`, 2491634 bytes, SHA-256
  513590a24b40c3bfa43d94dc85a233547803c6cbb346216569f0c7a48977d892. The whole zip (the mammoth, a sabre-tooth tiger and
  a giant sloth, as .fbx, .blend and .obj) is kept outside the project in `~/Downloads/Frontier_assets_staging/ice_age/`.
- The pack's model: one skinned low-poly mesh (materials "Wool" and "Tusks") on a 37-bone "metarig" with three clips,
  Idle, Walk (in place) and HeadShake; about 4.3 m tall at the head as modelled. (The pack's `Mammoth.fbx`,
  819308 bytes, SHA-256 b3ded5a0a0140b9f16605db026a4744b7840888a4ee41ca1d9173b307f341dde, was used first.)
- Added here (2026-09-27), made in Blender on the model's own rig by `tools/wildlife/mammoth_clips.py` (IK baked to
  keys): eight weak-point clips (the user: "we need weak point animations if they shoot the behind the leg it falls on
  one knee"), Kneel/Rise for each leg (KneelFront_L ... RiseHind_R), and three attacks (the user: "they will attack us
  charge at us and swing there trunk", "do a ground stomp"): TrunkSwing_L, TrunkSwing_R and Stomp; and its death
  (the user: "we have to chop it in pieces when we skin it and butcher it"): Die_L, Die_R. For the butchering the
  mesh's faces are parted into materials of their own (the tusks Tusk_L / Tusk_R, each flank's hide Hide_L / Hide_R;
  copies of Tusks and Wool). Then its turns (the user: "lets do the mammoth add turns into blender for them"): Turn_L,
  Turn_R, a quarter turn on the spot each, the feet stepping round in order; and its meals (the user: "eating and
  drinking clips as well", "eating uses trunk to pick up grass and leaves from tress and ground", "they use there trunk
  to blow water into there mouths"): Eat (the trunk to the ground, curled up to the mouth), Drink (a long draw, then
  two squirts blown into the mouth) and Browse (the trunk raised to a tree's leaves and a tug). The rig and the three
  original clips are unchanged.
- `mammoth.glb` (the whole mammoth with the twenty-one clips, glTF binary, facing +Z): 847380 bytes, SHA-256
  ed8c62b80084681714333435182949eb21e9fabc614335b6df91768e79af445e. Remake it with:
  `Blender -b Mammoth.blend --python tools/wildlife/mammoth_clips.py -- mammoth.glb`.

Used by the climbing yard's mammoth (`scripts/climb/stand_in_giant.gd`), scaled 1.2.
