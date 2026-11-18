# Reference video 7

Analysed frame by frame at 15 fps. Contact sheets (3 s each, 9 frames per row, time on each tile): `docs/references/video7_*.jpg`.

VIDEO 7: what it is
- This is not gameplay from a gore or fighting game. It is an 8.7 s vertical TikTok clip with a fixed caption ("Claude now has the skills of a pro Roblox dev"). It shows an anime-style ability/ultimate VFX test running in Roblox Studio: a default grey R6 dummy on the plain baseplate with the default sky, and Studio UI strips visible.
- There is NO blood, NO gore, NO dismemberment, NO opponent, NO damage numbers and NO health UI. Sections 1, 2 and 4 below are what is useful here. Section 3 is empty.
- The source is small: 240x427 frames, and the game area is only about 240x100 px. Small particle details are uncertain.

1. ATTACKS AND ANIMATION, with a timeline (15 fps, frame = t*15+1)
- 0.00-1.27 s (frames 1-20): the dummy stands still in idle, camera behind it at mid distance. Nearly 1.3 s of nothing, which is the "before" shot.
- 1.33-1.67 s (5-6 frames): wind-up. The dummy turns, raises one arm, then crouches and lunges low toward the camera. The camera stays fixed. This is a short, readable anticipation of about 0.35 s.
- 1.73 s: hard cut on the very next frame to a close-up cutscene. No transition, no blend.
- 1.73-2.73 s (about 15 frames): first cutscene, shown as a series of extreme close-ups of the dummy's head and upper body.
  - The background is replaced by a solid red screen with radial speed lines (manga "focus lines").
  - The character is lit with hard rim light and almost silhouetted (black or dark body, orange and yellow fire light).
  - White cartoon smoke puffs with hard outlines hug the character.
  - Thick black ink-like lightning squiggles run across the frame.
  - Floating red "HA HA" text glyphs drift in the background (a laughing villain motif).
  - The camera slowly pushes in and orbits slightly. Each shot holds 2-4 frames.
  - Around 2.47-2.67 s the character is overexposed to pink/white (a charge-up glow) and drowns in white smoke.
  - At 2.73 s the red darkens and the dummy is lit cold blue-white: a colour transition frame.
- 2.80-3.33 s (about 9 frames): second cutscene. A full-screen blue vortex/tunnel with a shockwave ring is seen head-on: concentric white rings, cloud swirls and thin white lightning lines. A white ring expands from the centre at 2.93 s, then contracts and pulses. This is a "power gathering / entering a dimension" beat.
- 3.40 s: hard cut back to gameplay. The camera is now low and close, at the dummy's feet. The dummy, in silhouette, is engulfed in a blue-white ice/lightning crystal burst (a star-shaped flash of spiky shards).
- 3.40-4.13 s: the dummy rises and hovers. A spiky crystal/lightning aura grows around it, cyan arcs whip around, and the camera follows upward.
- 4.20 s: the dummy and big white shards fly toward the camera and fragment. These are shard meshes, not limbs. It reads as an ice-shatter or explosion.
- 4.33 s: a flat cyan star-shaped decal/burst appears on the ground at the impact point: a ground-slam marker.
- 4.40-4.93 s: a column of blue lightning and a ring of cartoon white smoke puffs (hard-edged, toon) on the ground. Small debris and sparks.
- 5.00 s: a third hard cut to the red radial speed-line background. The dummy is shown in a dynamic airborne pose, lit orange and red, surrounded by small glowing yellow star sparkles and purple-blue electric bits.
- 5.20-5.47 s: big thick yellow-white lightning bolts strike vertically through the frame. The dummy is black-silhouetted against them. Red "HA" glyphs again.
- 5.53 s: back to the baseplate. A red shockwave line and black squiggles cross the ground, with dark rock debris chunks and a grey dust cloud.
- 5.67 s: debris is airborne, and a huge yellow-white light pillar is at the edge of frame.
- 5.73 s: one near-full-screen white flash frame (the impact frame), covering about two thirds of the screen.
- 5.80-6.07 s: aftermath. The dummy, now white and glowing, is in a crouched landing pose. Red curling energy ribbons ("3"/"S" shapes), red rectangular particles, small "HA" glyphs and fading sparks surround it. The camera starts pulling back.
- 6.13-6.53 s: the camera dollies far back. Residual red shards, small white and yellow flashes and a thin yellow streak dissipate.
- 6.60-8.67 s: about 2 s of wide, static, empty aftermath. The dummy slowly walks away. All VFX are gone by about 6.7 s.
- Hit reactions (ragdoll, knockback, stagger): none visible. There is no target. "Impact" is conveyed purely by the white flash frame, the light pillar, debris and the camera cuts.

2. VFX TECHNIQUES IN THE CLIP (useful for ult/finisher style even in a gritty game)
- Cutscene "cut-in" camera: hard cuts, never blends, between gameplay camera, ECU (extreme close-up) cut-in and gameplay. Each cut-in is about 0.5-1.0 s, made of 2-4-frame shots.
- Background replacement during cut-ins: a solid colour (red, then blue) plus radial speed lines. Likely a skybox/sphere swap or a ScreenGui/Beam layer. Colour codes the phase: red = rage/charge, blue = release.
- Silhouette lighting: the character goes near black with saturated rim light. Probably Highlight or ColorCorrection contrast plus strong coloured PointLights.
- Toon smoke: opaque white puff particles with hard edges (not soft alpha), clinging to the body.
- Ink lightning: thick black jagged beams/trails. Thick yellow-white lightning bolts for the big hit.
- Text-as-VFX: floating red "HA" billboard glyphs in the background.
- Impact frame: one full-screen (or nearly) white frame at the climax (5.73 s), right after a light pillar.
- Ground decals: a cyan star burst at the slam point. Debris chunks, a grey dust cloud, a red shockwave line on the floor.
- Aftermath residue: lingering red ribbons and shards for about 0.5-0.8 s, then everything fades out cleanly. No persistent decals stay on the baseplate.
- Screen shake: hard to confirm at this resolution. The framing jumps between cuts, but no clear per-frame jitter is visible. No FOV punch is clearly visible. Possibly slow motion in the 3.4-4.2 s rise (the motion looks slowed), but unsure.
- UI feedback: none (no hit markers, no damage numbers).

3. GORE
- None. No blood, wounds, dismemberment, body pieces or corpse. The "shattering" at 4.20 s is white/ice shard meshes, not body parts, and the dummy is intact afterwards. Nothing in this clip informs the gore system.

4. SOUND (inferred) AND PACING
- Likely audio sync points:
  - Whoosh/charge sting at the 1.73 s cut-in.
  - Maniacal laugh during the red "HA" cut-in (1.73-2.7 s).
  - Bass swell or reversed hit into the blue vortex (2.8 s).
  - Crystal shatter or thunder crack at 3.40 s.
  - Ground slam boom at 4.33 s.
  - Second cut-in sting at 5.00 s.
  - Thunder at 5.2-5.4 s.
  - Biggest boom plus white-out at 5.73 s.
  - Then a near-silent tail.
- Pacing: about 1.7 s calm, then about 4 s of nonstop escalation with a cut every 0.3-1.0 s and three colour phases (red, blue, red/yellow), then about 2.5 s of calm wide aftermath. The intensity curve is quiet, escalate, white-out climax, long decompression.

5. KEY TAKEAWAYS (only partly relevant to a realistic gritty game: this is anime-style ability VFX)
- This clip is a stylised anime "ultimate" showcase, not a gore reference. Use it only for finisher/ultimate presentation ideas, and translate the colours and toon effects into a gritty palette.
- Short anticipation: about 5 frames (0.33 s) of a readable wind-up pose on the gameplay camera, then a hard cut on the next frame. No easing between cameras.
- Finisher cut-ins: 0.5-1.0 s of extreme close-ups made of 2-4-frame shots with a slow push-in, then a hard cut back to gameplay.
- During a cut-in, isolate the character: replace or darken the background (here, a solid colour with radial lines) and silhouette the body with hard rim light. For a gritty game, use a desaturated dark background with one warm rim light instead of red manga lines.
- Colour-code phases: a charge colour, then a release colour, then the impact colour. Each phase change happens on a cut.
- Climax impact: a light pillar or flash, then 1 full-screen white (or for gritty, a red or darkened) impact frame, then debris and dust.
- Ground-impact signature: a flat burst decal at the contact point, a ring of dust puffs, flying rock chunks, and a shockwave line along the floor.
- Aftermath residue lasts about 0.5-0.8 s (ribbons, sparks, small flashes), then the camera pulls back wide while everything fades. Total VFX lifetime after the climax is about 1 s.
- Pacing template: idle, about 0.3 s wind-up, about 3-4 s escalating sequence with a cut every 0.3-1.0 s, one climax white frame, about 2 s of calm wide decompression.
- No hit-stop, ragdoll, damage UI or gore can be learned here, so take those from the other reference videos.

Note: the frames are very low resolution (the game area is about 240x100 px), so fine particle shapes and any screen shake are uncertain.