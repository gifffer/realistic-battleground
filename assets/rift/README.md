# Dr. Rift's gear (RiftGear.fbx)

Made by `tools/rift/build_rift_gear.py` (Blender, run from the repo root):

    venv/bin/python -I tools/rift/build_rift_gear.py assets/rift [--preview <dir>]

Pieces, one mesh per material, named `<Piece>_<Layer>`:

| Piece | What | Space |
|---|---|---|
| `Arm` | the cyborg left arm and the gravity glove (shaped like an arm: pauldron, upper arm, elbow servo, forearm tapering to the wrist with the power cell, a hand hanging palm toward the body with four fingers and a thumb, the `Palm` emitter in the palm; pistons, hoses) | Left Arm (1 x 2 x 1); the game measures it and fits it on the real arm anyway (`RiftGear.luau`, `fitArm`) |
| `RayGun` | the ray gun (orange glow), muzzle marker `RayGun_Tip` | Right Arm, barrel along -Y |
| `PortalGun` | the portal gun (green glow, glass bulb), muzzle marker `PortalGun_Tip` | Right Arm, barrel along -Y |
| `Flask` | the potion flask: `Glass`, `Liquid`, `Cork` | its centre |

Layers: `Steel`, `SteelDark`, `Chrome`, `Brass`, `Rubber`, `Glow`, `Palm`, `Glass`, `Liquid`, `Cork`
(the game colours them: `src/client/Combat/RiftAssets.luau`).
Markers (tiny cubes, never shown): `<Piece>_Pivot`, `RayGun_Tip`, `PortalGun_Tip`, `Arm_PalmPoint`,
`Arm_Cell` (where its green light goes),
and `Kit_Origin` / `Kit_Up` / `Kit_Out` (how the importer turned and scaled the file).

Import it into Studio: see `docs/RIFT_FR.md`.
