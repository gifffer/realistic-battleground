# Reference video 11

Analysed frame by frame at 15 fps. Contact sheets: `docs/references/video11_*.jpg`.

VIDEO 11: "RedShooter" Roblox FPS TikTok, about 11.1 s, portrait. It is a first-person execution of a downed R6 character with a pistol fitted with a holographic sight (EOTech-style). The burned-in captions stay on screen the whole time ("roblox power of imagination", "there we go david basuski !"), and a "REDSHOOTER" watermark is at the bottom from 2.4 s. There is no melee or walk animation in this clip: it is a gun-kill and gore-persistence reference.

TIMELINE (15 fps)
- 0.00–0.53 s: Close, low handheld camera on a downed R6 body lying on asphalt (black torso, tan limbs, red/grey cap). The camera drifts and rotates around the head. Soft low sun, long shadows. A small dark blood smear is already on the ground at the lower left. Muted, desaturated grade.
- 0.60–1.13 s: Near-static hold on the body (head and cap on the torso). Only slight handheld sway. The pacing is slow and deliberate, like a stalker standing over the victim.
- 1.20–2.33 s: The camera pans and walks around the head with strong close-up framing. A detached limb or block lies a few studs away in the background, so earlier dismemberment stays in the scene as persistent debris. Around 1.6 s a weapon edge starts entering from the left.
- 2.40–3.33 s: The pistol is raised into view from the bottom right with the tan R6 arm. It settles into an aim-down-sights pose over 4–5 frames, with the holo sight framing the head at point-blank range. The aim then holds on target for about 0.8 s (3.0–3.33 s) as a deliberate pause before the shot.
- SHOT 1, 3.40 s: One frame of orange-yellow muzzle flash and burst right at the head, with a slight warm light on the surroundings.
  - 3.47–3.53 s: Strong recoil. The gun kicks up and right, so the sight leaves the frame and the camera shows mostly the arm block. Two frames of heavy blur and kick.
  - 3.60–3.73 s: Recovery. The gun settles back, but slightly offset.
  - 3.73 s: A dark red mist or blood cloud appears around the head. The head and cap now read as dark red.
  - 3.8–4.8 s: Steady hold. The red mass around the head grows and stays. The camera drifts subtly.
- SHOT 2, 5.07 s: A larger white-yellow starburst flash, about 1 frame at full brightness. At 5.13 s there is an orange afterglow plus a big recoil rotation (the gun cants and rises).
  - 5.20–5.33 s: Return. The head area shows a thicker red spray cloud, which is clearly volumetric (soft particles, not a decal).
- SHOT 3, 6.20 s: Flash again, the biggest and whitest starburst. Then:
  - 6.27–6.47 s: 3 frames of exaggerated recoil (the gun fills a third of the screen and the camera rolls).
  - 6.5–7.2 s: The head has become an irregular mass of dark red with bright red rims (meaty chunks or a cluster of particles). The tan "neck" block remains.
- SHOT 4, 7.33 s: A smaller, quicker flash, with recoil at 7.40–7.53.
  - 7.60–8.6 s: Silver ejected casings or a magazine fall into view and lie on the ground near the body (7.6 s onwards). They become persistent props.
  - The blood mass is now larger, glistening with highlights, and spreads onto the torso and ground.
- 8.67–8.80 s: The gun is lowered or turned away (the sight swings down-left out of frame). The camera tilts down.
- 8.80–11.07 s: A long, quiet hold on the aftermath:
  - The headless or destroyed-head R6 body, with a large dark red wet mass where the head was and blood soaking the torso. Specular glints suggest wetness.
  - A silver magazine or suppressor-like cylinder lies on the ground next to it.
  - Tiny white specks (dust, debris or shell bits) drift at 10.0–10.4 s.
  - No further animation, only very slight camera drift. The watermark fades out over the last ~6 frames (10.7–11.07 s).
  - The scene is dark and moody, with low-key lighting.

VFX / GORE SUMMARY
- Muzzle flash: a single-frame starburst (white core, orange fringe) with a 1-frame orange afterglow. It lights the gun and the target briefly.
- Recoil: very large camera and viewmodel kick (2–3 frames up and roll), then a 3–4 frame ease-back to rest. The fire rate is slow and deliberate: about 1.1–1.7 s between shots.
- Impact: no visible tracer or spark on the flesh. The hit reads through a red volumetric mist that appears 3–5 frames after the shot and then thickens and persists.
- Gore accumulates shot by shot: shot 1 gives mist, shot 2 a thicker cloud, shot 3 a ruined head mass, shot 4 spreading wetness. Nothing fades.
- Persistence: blood, the destroyed head, casings and the earlier severed limb all stay for the whole clip. The final 2+ s is a held "look at what you did" shot.
- Camera: handheld, close, low. It circles the victim before the kill. There are no cuts, no slow motion and no zoom punch-ins. The aftermath ends on a tilt down.
- Pacing: about 3 s of approach and tension, 5.5 s of four spaced shots, then about 2.5 s of lingering aftermath.

KEY TAKEAWAYS (for our realistic, gritty game)
1. Build an execution or finisher beat: approach, hold aim for about 0.6–0.8 s of tension, then the hit. The pause before the payoff is what sells it. Apply the same principle to melee finishers: wind-up hold, then strike.
2. Make the impact flash exactly 1 frame at full intensity (white core, warm fringe), then a 1-frame warm afterglow, plus a brief PointLight pulse (about 0.05 s) on the surroundings. Keep it a real muzzle or impact flash, not a stylized anime starburst. Shrink the 8-point "star" shape into an irregular, physically plausible flash.
3. Recoil and camera kick: 2–3 frames of sharp displacement and roll, then a 3–4 frame ease-out back to rest, with a small residual offset. Use this camera-shake profile for heavy punches and kicks too: fast attack, slower settle.
4. Blood should lag the hit by 2–4 frames and then build. Mist first, then heavier particles, then wet pooling. Don't spawn the full gore state at frame 0.
5. Gore must accumulate per hit on the same body part: escalating damage states (graze, open wound, destroyed). This maps directly onto our wound kit and stage system.
6. Persistence is key. Blood mass, severed limbs, casings or debris stay in the world for the whole encounter, so the earlier dismemberment is still visible later. Keep debris and decals with long lifetimes and a cap on how many exist, not quick fades.
7. Dark, wet blood: deep maroon with bright specular highlights on the rims, matching our "dark wet blood" direction. Avoid the cloudy, transparent pink-red particle smoke look seen in shot 1–2 mist. Use denser, darker droplets and wet surfaces instead.
8. Do NOT copy the head becoming a blob of semi-transparent red particles. In our game a destroyed head should show real anatomy (Z-Anatomy skull fragments, exposed tissue, neck stump), modelled as gore pieces, not a particle cloud.
9. Hold on the aftermath for about 2 s: a slow camera drift and a tilt down to the corpse after a kill. This is good for our death cam or kill cam. Add no UI clutter, slow-mo or flashy text.
10. Lighting sells the mood: low-key, desaturated, long shadows, small warm muzzle or impact light against a cold, dark scene. Use a ColorCorrection with lower saturation and slight contrast during kill moments.
11. Spaced, deliberate hits (about 1.2–1.7 s apart) feel heavier than spam. Give heavy or finisher attacks long recovery and readable hitstop instead of rapid flurries.
12. Not relevant or not to copy: the burned-in TikTok captions and watermark, the cartoon R6 cap and face, the gun-FPS viewmodel (we are a melee or fighting game). The video holds no walk-cycle data, so it cannot serve as a walk-animation reference.

Files: (local frames, not in the repo) v11_sheet00.png to (local frames, not in the repo) v11_sheet03.png, frames in (local frames, not in the repo) f11/ (167 frames).