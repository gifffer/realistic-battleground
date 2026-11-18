# Realistic Battleground: notes for every Claude session

A realistic, gritty, gore-heavy Roblox fighting game: R6 characters, server-authoritative combat, Rojo, Wally, StyLua, Selene, Luau `--!strict`. Reply to the player in short French; all in-game text is English. Docs for the player are in French (`docs/*_FR.md`).

## What the game must look like
Before any work on attacks, animations, VFX, gore or cinematics, read **`docs/references/README.md`**. It holds the art direction taken from the reference videos the player sent, frame by frame:
- impact timing, flash frames and hitstop;
- how blood sprays, lands and stays;
- what wounds and dismemberment show;
- death and ragdoll;
- awakening staging.

Each video's full analysis and key frames are next to it. Keep the timing, layering and persistence, never the cartoon or anime looks: here everything is realistic (real anatomy, Z-Anatomy data in `tools/wounds/anatomy/`, dark wet blood).

## When the player asks for something specific
Before building it, **search the web and study tutorials until you really understand how it is done**: Roblox DevForum, the Creator Hub docs, articles, video tutorials (their transcripts or descriptions), open-source examples. Then build it the way it's done well, not a first guess.

Reference videos the player sends: extract them at about 15 fps and look at every frame (contact sheets). The steps are in `docs/references/README.md`.

## Tools
- **Blender works headless in Python**: `python3 -m venv venv && venv/bin/pip install bpy numpy scipy matplotlib pillow`, then `venv/bin/python -I script.py`. `venv/` is not committed.
  - Gore pieces: `tools/wounds/` (build with `venv/bin/python -I tools/wounds/build_wound_kit.py assets/wounds`).
  - Dr. Rift's gear: `tools/rift/`.
  - The alleys (east of the ring, along the viaduct) and the street-weapon spawn markers: `venv/bin/python -I tools/city/alleys.py` regenerates `src/server/Systems/City/AlleyData.luau` (merged into the city's data by `City/init.luau`; the city itself comes from citygen.py, not in the repo).
  - Render previews (Cycles CPU) and LOOK at them before calling something done.
- **Any change to an FBX asset:** give the player a zip of its folder (e.g. `assets/wounds/`) so he can re-import it in Studio.
- **Checks before every push:** `stylua --check src` and `selene src`. Both are run by CI, and a Selene error fails it. Also run luau-lsp if you have it.

## Working rules
- Only `gifffer/realistic-battleground`.
- Fetch the latest `main` before coding. One branch per feature; never push to `main`; never merge or delete a branch without the player asking.
- Never change a branch you didn't create, or code synced from Studio.

## Still to do (only when the player asks)
- Make the punch (M1) animations better, and polish some other animations.
