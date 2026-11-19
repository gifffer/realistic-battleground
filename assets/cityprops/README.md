# City props (CityProps.fbx)

Made by `tools/city/kit/build_city_kit.py` (Blender, run from the repo root):

    venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops [--preview <dir>]

Each piece is a few meshes, one per material layer, named `<Piece>_<Layer>`; the game colours
them (`src/server/Systems/City/PropKit.luau`, table LOOKS) and multiplies by the meshes' vertex
colours (the wear). Markers (tiny cubes, never shown): `<Piece>_Pivot` (the piece's origin:
the centre of its footprint on the floor, or on the wall face for wall pieces), optional
`<Piece>_Light` / `<Piece>_Fx`, and `Kit_Origin` / `Kit_Up` / `Kit_Out` (how the importer
turned and scaled the file). Axes: Roblox (Y up, the front faces -Z), studs.

Import it into Studio: see `docs/PROPS_FR.md`.

| Piece | Layers | Size x * y * z (studs) | Tris | What |
|---|---|---|---|---|
| `TrafficCone` | Plastic, Reflective, Rubber | 1.40 x 2.77 x 1.40 | 2848 | Road cone, 75 cm kind (2.8 tall, base 1.4 x 1.4): hollow orange shell, two reflective collars, square rubber base; grime low down, tyre marks up one side. |
| `TrafficConeWorn` | Plastic, Reflective, Rubber | 1.40 x 2.77 x 1.40 | 3184 | The same cone run over: a crease in its side, squashed oval, chewed tip, filthy. |
