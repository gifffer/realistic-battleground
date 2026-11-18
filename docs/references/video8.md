# Reference video 8

Analysed frame by frame at 15 fps. Contact sheets (3 s each, 9 frames per row, time on each tile): `docs/references/video8_*.jpg`.

VIDEO 8: overview (11.1 s, 167 frames at 15 fps, source only 240x427 px, so fine detail is limited)
This is a first-person execution clip, not melee. A downed R6 character lies on the asphalt: black outfit, tan blocky limbs, red/grey cap, head wrapped in a red bandana. He is already hurt, with blood on the ground at frame 1 and a small red-bordered HUD panel bottom-left (unreadable, perhaps a "down/bleeding" or injury status). The player walks around him, raises a rifle with a holographic red-dot sight and fires 4 aimed single shots at the head and upper body from point-blank range. Each shot adds red mist, and the head and torso end up as a dark-red pulpy mass. A dropped silver pistol lies next to the body. TikTok captions ("roblox power of imagination", "there we go david basuski !") and a "REDSHOOTER" watermark are editing overlays, not game UI. The low-key art direction does most of the work: a warm low sun, long hard shadows, dark asphalt with a tile grid, and a desaturated, slightly crushed image.

1. ATTACKS / ANIMATIONS (gun execution)
- 0.00–1.13 s: the victim lies on his side, limp. There is no writhing; the body settles slightly as the camera moves (likely ragdoll, unsure whether he is still alive or "downed"). The camera walks close and circles around him, about 1–2 studs from the head.
- 1.20–2.40 s: the camera sweeps low over the body (handheld head-bob feel, slight tilt). A gun hand (tan blocky arm) enters frame bottom-left around 1.6 s.
- 2.47–3.33 s: weapon-raise animation, about 12 frames (0.8 s), unhurried. The rifle comes up from bottom-right into ADS with a holographic sight. The aim settles on the head over about 4 frames. It is deliberate, with no quick-scope; the slowness sells "execution".
- Shots: 3.40 s (frame 52), 5.07 s (frame 77), 6.20 s (frame 94), 7.33 s (frame 111). The gap between shots is about 1.1–1.7 s, slow and deliberate, one shot per beat.
- Recoil per shot: on the shot frame the weapon kicks up and right and rotates toward the camera. The sight body fills the right half of the screen on frames +1 to +3 (3.47–3.60 s, 6.27–6.40 s, 7.40–7.53 s), then recovers back to ADS over about 4–6 frames (0.3–0.4 s). Recoil is a big rotation plus a backward/sideways offset of the viewmodel. The camera itself barely moves.
- Victim reaction to each shot: almost none at the body level. It is already a ragdoll on the ground; a small twitch/jolt of the head part is possible but hard to see. The reaction is carried by the gore VFX, not by animation.
- 8.60–8.93 s: the player lowers or drops the weapon. The sight swings down and out of frame bottom-left by about 8.73 s. The camera then looks down at the result and holds steady to the end (9.0–11.1 s, about 2 s of "admire the result" hold). This hold is a deliberate pacing beat.

2. HIT VFX
- Muzzle flash on the shot frame only (1 frame, about 66 ms): a bright yellow-white star shape with an orange core, about 1/4 of the screen width, at the barrel just left of the sight. Frame +1 shows a smaller orange glow/ember (3.47 s, 5.13 s, 6.27 s); by frame +2 it is gone. The flash briefly lights the nearby geometry warm orange (lighting pop, possibly a PointLight).
- No screen shake beyond the weapon recoil, no FOV punch, no hitmarker, no damage numbers, no slow-mo. The clean UI is part of the realism.
- Impact on the flesh: a dark-red blood mist puff at the impact point, visible from frame +2 to +3 after the shot (3.53–3.73 s). It is a soft, semi-transparent cloud about the size of the head that expands slightly and fades over about 0.5–1 s. Some dark-red mist lingers around the head for several seconds (3.7–4.8 s, faint).
- No sparks or concrete dust visible, so the shots all hit the body (unsure whether there are any ground-impact effects).
- Colour grading: low sun, high contrast, dark shadows, slightly desaturated colours except the blood and the red cap, which stand out. Possibly a slight bloom on the muzzle flash.

3. GORE
- Before the shots (0.00 s): a dark-red blood decal/pool under the body, already present (visible bottom-left of frame 1 and next to the HUD panel). The colour is dark, desaturated crimson, not bright red.
- Shot 1 (3.40 s): a red mist cloud. Afterward the head/bandana area shows red smears and the head shape starts to look broken. From around 3.7 s there is a red "fuzzy" blood volume around the head.
- Shots 2–3 (5.07 and 6.20 s): each adds a mist puff and enlarges the red mass. By 6.6 s the head and upper torso are covered by a lumpy dark-red mass that is clearly 3D (shaded, with highlights), like chunks of flesh/gore mesh or many overlapping blood parts. It is not a flat decal; it has volume and specular highlights (wet look).
- Shot 4 (7.33 s): the mass grows more. By 7.6–8.3 s the gore mass extends from the head down over the chest and onto the ground. It looks like a "pulped head" replacement: the head silhouette no longer reads as a head, only the tan neck/hand stub sticks out, plus red chunks. Unclear whether actual decapitation or head-mesh removal happens; it reads as the head being destroyed and replaced with a gore mesh/particle cluster.
- Blood pool: grows under the head/torso during 7–9 s into a dark glossy puddle that reflects slightly. Its edges are soft.
- Persistence: everything stays until the end of the clip (9.0–11.1 s). Nothing fades. A few tiny white specks (bone fragments? or particles/dust) appear and drift around 9.8–10.4 s (single-pixel white dots near the body, uncertain).
- The body after death is fully static. There is no further movement after the final shot.
- Small detail: the victim's cap stays on through the first shots, and the red of the cap blends visually with the blood, making the mass look bigger.

4. SOUND CUES (inferred) AND PACING
- Gunshot with a sharp crack on frames 52, 77, 94 and 111, plus a wet impact/splat on the same frame or +1 (the mist appears +2 frames after the shot). A meaty "squelch" layer on each hit would match the growing gore. Probably a casing/bolt mechanical sound on recoil.
- Pacing: slow approach (3.3 s), then 4 shots spaced about 1.1–1.7 s with a quiet hold between each, then 2 s of looking at the result. It is cold, deliberate and slow, with little camera motion. Intensity comes from the escalating damage per shot (each shot visibly worsens the wound), not from flashy effects. The low resolution and dark grade make the gore read as a "mess" rather than detailed anatomy.

5. KEY TAKEAWAYS
- Escalating, cumulative gore per hit: each successive hit on the same body part adds more gore volume (mist, then smears, then a full pulped mass), so repeated hits visibly "progress" the wound. Track a damage stage per limb/head (e.g. 0–3) and swap or add gore meshes at each stage.
- Blood mist on the bullet/heavy impact: a soft semi-transparent dark-red smoke puff (size about 1 head) appears 1–2 frames after the hit, expands slightly, and fades over 0.5–1 s. A faint residual haze lingers for 1–2 s.
- Blood colour is a dark, slightly desaturated crimson (roughly RGB 90–130, 10–20, 10–20) with a wet specular sheen on meshes and pools, never bright cartoon red.
- Gore is volumetric: the destroyed head is replaced by a lumpy 3D red mesh/cluster (multiple small shaded parts with highlights) covering the head and upper chest, not just a texture or decal. In R6, replace or hide the Head and spawn a cluster of small, wet-material red parts welded to the torso.
- Blood pools grow under the body over about 1.5–2 s after the kill and stay. Already-downed victims have a pre-existing pool, so the bleeding state is readable before the kill.
- Muzzle flash is exactly 1 frame of a bright star flash plus 1 frame of orange afterglow, with a short warm light pop on the surroundings. There are no tracers, no hit marker, no damage numbers and no screen shake on a single shot.
- Recoil sells the gun: on the shot, the viewmodel kicks up/right and rotates (roughly 15–25°) for 2–3 frames, then returns to ADS over about 0.3–0.4 s. Keep the camera itself steady for precision executions.
- Executions are slow and deliberate: about 0.8 s raise/aim, about 1.1–1.7 s between shots, then a 2 s "look at it" hold. Let the player linger on the result; don't auto-cut away.
- Dead or downed bodies are limp ragdolls lying on their side and fully static after death. Corpses and gore persist (at least 10+ s, likely until cleanup).
- Lighting and grade carry the mood: a low warm sun, long hard shadows, dark asphalt, crushed blacks and a desaturated palette, so the red blood is the most saturated thing on screen.
- No visible UI feedback except a small, discreet red-bordered status panel bottom-left (likely downed/injury status). Keep the HUD minimal for realism.

Uncertain points: the exact nature of the head-destruction mesh (decapitation versus a gore overlay) can't be confirmed at this resolution. Whether the victim twitches on each hit, and what the tiny white specks around 10 s are (possibly bone fragments), are unsure.

Zoom files I made: (local) v8zoom.png and (local) v8zoom2.png