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
- **No damage numbers, no hit markers.** The feedback is the body, the blood, the camera and the sound.

### Awakening / ultimates
- A 1-frame full-screen flash.
- Then the world goes desaturated (about -0.8) while the awakened fighter keeps his colours.
- Anticipation pose with a glow for about 0.2 s.
- Ground eruptions staggered 2–3 frames apart, each leaving a hole decal.
- Dark smoke that rises slowly.
- An FOV punch on the beats.
- Keep it short (3–5 s) so it suits PvP.

## Adding videos
The player will send more videos. For each one:
1. Extract frames at 15 fps (`ffmpeg -i video.mp4 -vf "fps=15,scale=240:-1" f/%04d.png`).
2. Make contact sheets and watch every frame.
3. Write `videoN.md` (what it is, attacks, hit VFX, gore, pacing, key takeaways) and add its key sheets here as JPEG.
4. Update this README.
