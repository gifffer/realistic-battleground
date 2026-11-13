# Dr. Rift's gear (RiftGear.fbx)

Made by `tools/rift/build_rift_gear.py` (Blender, run from the repo root):

    venv/bin/python -I tools/rift/build_rift_gear.py assets/rift [--preview <dir>]

Pieces, one mesh per material, named `<Piece>_<Layer>`:

| Piece | What | Space |
|---|---|---|
| `Arm` | the cyborg left arm and the gravity glove (shoulder dome, servos, pistons, hoses, power cell, articulated fingers, the `Palm` emitter) | Left Arm (1 x 2 x 1) |
| `Eye` | the ocular implant on the right eye (bezel, lens, plate in the skin, temple module, antenna, cable) | Head, classic head at scale 1.25 |
| `RayGun` | the ray gun (orange glow), muzzle marker `RayGun_Tip` | Right Arm, barrel along -Y |
| `PortalGun` | the portal gun (green glow, glass bulb), muzzle marker `PortalGun_Tip` | Right Arm, barrel along -Y |
| `Flask` | the potion flask: `Glass`, `Liquid`, `Cork` | its centre |

Layers: `Steel`, `SteelDark`, `Chrome`, `Brass`, `Rubber`, `Glow`, `Palm`, `Glass`, `Liquid`, `Cork`
(the game colours them: `src/client/Combat/RiftAssets.luau`).
Markers (tiny cubes, never shown): `<Piece>_Pivot`, `RayGun_Tip`, `PortalGun_Tip`, `Arm_PalmPoint`,
`Arm_Cell` and `Eye_Lens` (where their green lights go),
and `Kit_Origin` / `Kit_Up` / `Kit_Out` (how the importer turned and scaled the file).

Import it into Studio: see `docs/RIFT_FR.md`.
