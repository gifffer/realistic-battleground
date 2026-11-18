# Art direction: what the attacks and the gore must look like

The player sent reference videos of other Roblox games to show the **feel** he wants. They were analysed frame by frame at 15 fps. Each video's full analysis is in `videoN.md` here, and contact sheets of its key moments are in `videoN_*.jpg` (3 s per sheet, the time is written on each frame).

**Take the timing, the layering and the persistence. Do not copy the games, their characters or their cartoon looks.** This game is realistic and gritty: dark, wet blood, real anatomy, dust and debris. No toon outlines, no anime auras, no pastel magic.

| # | What it is | Use it for |
|---|---|---|
| 1 | A stylised spell-VFX showcase (fire, ice, lightning, slash) on an arena | Impact grammar: flash, pop, hold, break-up. Ground marks that stay. |
| 2 | A first-person gun-gore sandbox on R6 dummies (a city street) | Wounds accumulating, wet wound meshes, the blood cloud on impact, splatter on walls and floor, pools, bodies that stay |
| 3 | A shotgun gore showcase on an R6 test dummy | Gore timing, blood mist colour, high-detail wound meshes on the blocky body, death freeze then ragdoll |
| 4 | An "awakening" transformation cinematic (no fight) | Awakening / ultimate staging: flash frame, desaturated world, smoke, FOV punch, ground eruptions |
| 5 | A battlegrounds-style anime finisher (no gore) | Heavy-hit timing: long wind-up then instant strike, knockback, wall crack decals, barrage rhythm, a different final hit |
| 6 | A wall-combo cutscene (anime battlegrounds, no gore) | Finisher cinematic structure: grab at a wall, 6-10 short shots with hard cuts, a still hold before the hit, impact frames, the result shown back in gameplay |
| 7 | An "ultimate" VFX test in Studio (anime, no gore) | Cut-in grammar: a short wind-up, close-up shots of 2-4 frames, the background darkened round the character, one climax flash, calm afterwards |
| 8 | A first-person execution of a downed R6 body (gore) | Gore that grows with each hit on the same part, blood mist, a volumetric pulped head, pools growing under the body, a slow deliberate pace, grading that makes the blood the most saturated thing |
| 9 | A long custom moveset showcase (battlegrounds, no gore) | Heavy impacts: flash + thin speed lines, floor slabs and dust that stay on slams, sparks of metal on stone, light hits stagger and heavy ones ragdoll, finisher beats of 0.3-0.8 s |
| 10 | An ultimate-ability showcase (anime, no gore) | A quiet lull before each big hit, a smear frame to hide a camera cut, impact = spark + speed lines + ring on the same frame, the aftermath held 0.5-1 s |
| 11 | A first-person execution of a downed R6 body (gore), close and slow | The pause before the payoff, gore building up shot by shot, everything staying, a 2 s held aftermath; NOT the see-through pink mist |
| 12 | Blender tutorial: realistic water droplets | How to model and light convincing liquid drops (for blood drops, wet wounds, pools). Also the look of a falling rain drop (clear bead, bright glint, dark refracting rim): `assets/rain/rain_drop.png` |
| 13 | Blender tutorial: rain ripples | Ripple rings on a liquid surface (drops landing in blood pools). Also the rain ripples on puddles and wet streets: `assets/rain/rain_ripple.png` |
| 14 | Blender tutorial: realistic glass | Glass material and shape (bottles, flasks, shards); **the city windows** (implemented: `CityGlass` + `GlassController`, see `docs/GLASS_FR.md`) |
| 15 | A custom R6 movement system | **The game's walk** (implemented: `MovementClips.Walk`): a quick power-march, high knees, arms pumping across the body, strong torso twist |

## The rules that come out of them

### Impacts
- **Contact frame:** a 1–2 frame flash at the contact point (white or slightly warm) with a point light, plus a short hitstop on heavy hits (2–4 frames). Never ease into an impact.
- **Pop, don't grow:** the main impact effect appears at full size in 0–1 frames. Only secondary layers (dust, rings, smoke) grow afterwards.
- **Layers fired together:**
  - the core flash;
  - a radial burst of thin sparks or streaks (about 4 frames);
  - a shockwave or dust ring along the floor (about 0.8 s);
  - debris or chunks with real weight, on ballistic arcs.
- **Heavy moves:**
  - a long, readable wind-up (10–13 frames), then an instant strike;
  - camera push-in or FOV punch on the hit (1–2 frames, ease back in about 0.3 s);
  - change the camera angle on major beats of a cinematic.
- **Knockback:** instant and big. The target is at full speed on the first frame after contact.
  - A body hitting a wall or the floor leaves a crack decal on the same frame, sized by the hit.
  - The decal stays for several seconds.
- **The last or killing hit must look different** from the others. That is where the blood burst or dismemberment goes.
- **Effects end by breaking up** (eroding, shedding droplets or shards), never by vanishing.
  - A rough split: about 10 % build-up and flash, 70 % hold with secondary motion, 20 % fast break-up.

### Gore
- **Timing:** the blood comes about 2 frames (≈130 ms) **after** the hit flash and camera kick, not on the same frame.
- **Damage accumulates where it lands:** every hit adds a wound or blood mark at the hit point and darkens the body there. After several hits the clothes are visibly soaked.
- **Wounds:** wet 3D geometry, not flat stickers.
  - Glossy dark-red craters with a torn rim and a layered red inside.
  - Organs (pink, veined) where the torso is opened.
  - The high-detail wound against the blocky R6 body is the look.
  - Wound meshes stay welded to their part and follow the ragdoll.
- **The blood cloud on impact:**
  - a dense dark-red mist with droplets, globs and small chunks;
  - wide and flat for head or heavy hits, a narrow jet for close body hits;
  - it expands and fades over 0.3–1 s.
- **Palette:**
  - mist: dark maroon to brown-black (about RGB 70–110 / 10–25 / 10–25);
  - fresh spray: up to about #b01515;
  - dried decals: #5a0000–#7a0a0a.
  - Saturated but dark, and wet (glossy).
- **Splatter:**
  - velocity-stretched streaks with "finger" splash shapes, 1–2 studs long, in the hit direction, on floors and walls;
  - on walls it runs down as drips over 1–2 s.
- **Pools:**
  - a pool spreads under a body over about 1 s;
  - big finishers leave a large stain of 1.5–2 m.
- **Persistence:** blood, chunks and bodies stay for a long time and are never cleaned up on screen.
  - Hitting a corpse opens new wounds and new sprays.
- **Death:**
  - freeze the body upright for about 0.4–0.5 s;
  - then go to a limp ragdoll that collapses and settles in about 0.4 s;
  - little bounce, no anime launch for a kill.
- **Point-blank gore** can splash the screen (a red overlay for about 2 frames, fading in about 0.5 s). Keep that for the heaviest hits.
- **Gore that progresses:** repeated hits on the same part escalate the wound in stages (mist, then smears, then a pulped mass), so each part tracks how damaged it is.
- **Volumetric damage:** a destroyed head is a lumpy cluster of wet red 3D parts covering the neck and upper chest, not a texture.
- **Downed and dying bodies already bleed:** a pool is already under someone who is down, so their state reads before the kill.
- **Grading:** a desaturated world with crushed blacks and warm low light, so the red blood is the most saturated thing on screen.
- **No damage numbers, no hit markers.** The feedback is the body, the blood, the camera and the sound.

### Finisher cinematics
- **Length:** 4-6 s in all.
- **Shots:** 6-10 shots of 2-12 frames each, joined by **hard cuts** (or a single smear frame hiding the cut), not slow pans.
  - The sequence: over the shoulder for the wind-up, a low wide shot for the impact, a close-up on the face or the wound, then an aftermath shot.
- **Hold before the hit:** a still, quiet shot of about 0.5 s (4-8 frames darker and calmer) right before the decisive blow. The contrast sells it.
- **Impact frames:** on the hit, 1-2 frame full-screen frames (solid or inverted, desaturated red / black / white for us), alternating 3-5 times over about 1 s.
- **During the cinematic:**
  - push the palette (desaturate the world, keep the blood red, darken it by 20-30 %);
  - hide the HUD.
- **Back to gameplay** exactly where the cutscene ends, with the result left in place:
  - the body slumped at the wall base;
  - a drag trail on the floor;
  - wall splatter;
  - dust and smoke lingering for 1 s or more.
- **Debris that stays:** on slams, 3-8 slabs and chunks of the floor's own material tumble and stay 5-10 s, with a dust billow for 1-2 s.
  - Metal dragged or hitting stone throws orange sparks.
- **Hit weight:** light hits only stagger the body; heavy enders switch to a ragdoll that slides or tumbles.

### Awakening / ultimates
- A 1-frame full-screen flash.
- Then the world goes desaturated (about -0.8) while the awakened fighter keeps his colours.
- Anticipation pose with a glow for about 0.2 s.
- Ground eruptions staggered 2–3 frames apart, each leaving a hole decal.
- Dark smoke that rises slowly.
- An FOV punch on the beats.
- Keep it short (3–5 s) so it suits PvP.

## Techniques (Blender tutorials 12-14)
Videos 12-14 are Blender tutorials. Their `videoN.md` files give the technique step by step (the settings read on screen) and what carries over to Roblox. Roblox has no custom shaders, so what carries over is:
- the geometry (rounded, smooth-shaded drops; ripple rings);
- baked highlights or rendered sprite sheets for particles;
- SurfaceAppearance maps;
- the Glass material with the right transparency and reflectance.

## Adding videos
The player will send more videos. For each one:
1. Extract frames at 15 fps (`ffmpeg -i video.mp4 -vf "fps=15,scale=240:-1" f/%04d.png`).
2. Make contact sheets and watch every frame.
3. Write `videoN.md` (what it is, attacks, hit VFX, gore, pacing, key takeaways) and add its key sheets here as JPEG.
4. Update this README.
