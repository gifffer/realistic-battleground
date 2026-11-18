# Reference video 3

Analysed frame by frame at 15 fps. Contact sheets (3 s each, 9 frames per row, time on each tile): `docs/references/video3_*.jpg`.

VIDEO 3: what is in it
This is a first-person shotgun gore showcase (ghost-ring rear sight, black receiver, blocky skin-tone arms) on a test-dummy R6 rig. The dummy's parts are coloured blocks labelled FRONT/F/R/D/U/B. There is no melee in the clip: it is guns, then a katana is equipped, then a third-person outro of the player's avatar (purple fedora, katana, shotgun on the back, glowing red eyes). The source is low resolution (240x427), so fine texture detail is approximate. The useful parts are the timing of the gore, the blood mist, the open-wound meshes and how bodies persist. Below, those findings are translated to a melee fighting game where relevant.

Timeline (15 fps, 1 frame = 67 ms)
- 0.00-2.33 s: An editor overlay reads "GORE WARNING" (white bold text, red outline). It pops in at 0.47 s, then smears out with a vertical motion blur at 2.20-2.40 s. This is video editing, not game UI. The player walks toward the dummy and goes into ADS at about 2.0 s.
- 2.47 s: One frame of red vertical streaks over the gun. It is probably an edit glitch, not game VFX (unsure).
- 2.87 s, shot 1 (headshot): A muzzle flash shows as a yellow-white bloom at the sight with a warm orange tint over the lower half of the screen. It lasts 1 frame.
- 2.93-3.07 s: Hard recoil. The camera and gun kick up sharply in 1 frame (the sight jumps up and gets bigger), then settle back over about 4-5 frames (to about 3.27 s). There is no other screen shake, no FOV punch and no slow motion.
- 3.13 s (about 2 frames after the shot): A dark maroon, almost brown-black blood mist appears where the head was. It is soft and semi-transparent, like smoke, not bright red.
- 3.27-3.53 s: The mist grows into a large flat cloud. It is wider than the body, about 2-3x the torso width, and drifts up and outward. The head is gone. Only a small dark-red glossy meat lump (the neck stump mesh) sits on top of the torso.
- 3.33-3.53 s: The body stays standing and stiff for about 6-8 frames after the kill. This "dead but not yet falling" beat sells the shot.
- 3.60-3.93 s: The body ragdolls backward and sideways and folds at the joints. The R6 parts tumble as separate rigid blocks and come to rest in about 0.4 s. It lands flat with a slight bounce and no sliding.
- 3.6-4.2 s: The mist thins and fades out over about 1 s while it rises and spreads. It is fully gone by about 4.3 s.
- 4.6-6.4 s: The player walks up and looks down at the corpse. The neck stump is a lumpy, glossy, dark red-brown meat mesh with wet highlights, sitting above the torso where the head was. It is persistent.
- 7.53 s, shot 2 (point-blank into the torso on the ground): An orange-yellow muzzle flash with a hot core.
- 7.60 s: A tall, narrow column of dark red-black mist shoots straight up from the impact point. It reads like smoke from a chimney: about 1 body-length high, thick at the bottom and wispy at the top.
- 7.67 s: Big recoil frame. The camera kicks far up, the gun fills the screen, and the view goes dark.
- 7.73-7.87 s: The body is covered in blood decals: thin dark-red streaks and drips running across the "FRONT" torso, plus a fine spray of dots. Small dark droplets scatter on the floor around the body, inside a radius of about 1 m. The decals stay.
- 8.0-8.93 s: The camera circles the body. Seen from the side, the neck stump shows layers: a coiled, intestine-like glossy red-brown mass with a darker rim.
- 9.53 s, shot 3 (to the torso): Muzzle flash, then a black-red mist plume rises at 9.53-9.67 s.
- 9.80-10.00 s: The torso blows open. A purple-red tinted burst (blood mist plus a reddish glow) covers the body for about 3 frames. Limb blocks are thrown apart a little and flip, which shows other coloured faces.
- 10.00-10.13 s: The torso is swapped for an open-cavity gore mesh. It has an outer rim of dark, almost black, glossy torn skin and flesh, with pink organs inside (lumpy, veined lobes that look like lungs or brain tissue) and chunky, shredded, bright-red meat. A large soft pink-red stain spreads under and in front of the body, about 1.5-2 m across, with streaky edges.
- 10.2-10.73 s: The floor stain fades out over about 0.5 s, so it was mostly ground-level mist. A faint residue stays. The cavity mesh stays.
- 10.8-15.9 s: Long close-up inspection of the open torso. It holds detail up close: glistening pink organs with visible veins, crumbly red meat chunks, and a black-maroon glossy wet border. The organ mesh is far more detailed and photoreal than the blocky body, and that contrast is the selling point. Everything persists for the whole clip; there is no despawn or fade over 20+ s.
- 16.47-16.67 s (unsure what triggers it, probably a melee hit or a shot at the corpse): A large dark ink-like blood splat bursts from the body. It has a dark core and many round black-red droplets of different sizes flying outward in a radial pattern. Some of them land near the camera and read almost like screen-space splatter.
- 16.73-17.0 s: The floor around the body is now stained with smeared, uneven maroon-purple decals, thicker near the body.
- 16.87 s onward: A katana blade (thin, steel, specular) is held vertically in view. From 18.0 to 21 s the player shoves and kicks the corpse parts with arm and body contact. The ragdoll parts tumble realistically, and the gore meshes (stump and cavity) stay attached to their parts while they move.
- 21.9-22.8 s: The corpse rests: stump, cavity and blood stains still visible.
- 22.87-23.00 s: Edit transition. A red and white crossed-blade emblem flashes in a 2-3 frame cross-dissolve into an extreme close-up of the player's head.
- 23.0-26.8 s: Third-person outro. The camera pulls back from behind the head to the front over about 1 s. The character idles with a katana held upright, arms crossed, a shotgun on the back, red glowing eyes and a grin.

1. Attacks / animations
- Because the clip is gunplay, there are no punches, grabs or finishers to copy. What transfers is the rhythm. Each hit is: a 1-frame bright flash, then a 1-frame violent camera kick, then 4-5 frames of recovery, then the gore appears about 2 frames (about 130 ms) after the hit.
- There is no hitstop or freeze-frame on the camera, but the victim does a "dead-stand": it stays upright and rigid for about 0.4-0.5 s after a lethal hit, then collapses into ragdoll in about 0.4 s. In a fighting game, add a short freeze on the victim before the ragdoll after a lethal blow.
- Ragdoll: the body is a heavy, low-bounce R6 block ragdoll. Limbs splay, parts tumble independently, and it settles fast without long sliding. Corpses react physically to later shots, kicks and shoves.
- Camera: first person, no cinematic cuts in-game. The cuts at 22.87 s are editing.

2. Hit VFX
- Muzzle flash: a warm yellow-orange bloom with an orange tint on the lower screen, 1 frame.
- Shot impact: there are no white flashes, sparks or shockwave rings on the body. The impact VFX is entirely blood mist. There is no screen shake beyond the weapon recoil, no FOV punch and no slow motion.
- Blood mist is the main effect. It is dark maroon to brown-black, semi-transparent and volumetric (soft particles). It has two shapes:
  - a wide flat cloud for the headshot (spreads sideways and up, about 1 s life);
  - a narrow rising column for close shots (shoots up, then turns wispy).
- Colour grading: neutral and bright (overcast sky, white concrete). The dark blood stands out strongly against it.
- UI: none at all. No damage numbers, no hitmarkers, no health bars on screen. The only overlays are edit text and the emblem.

3. Gore
- Blood colour: dark and desaturated (maroon, brown-red, almost black at the core). It is never bright cartoon red, except for the pink-red ground stain and the inside meat.
- Viscosity: decals on the body are thin streaks and drips plus fine dot spray, which reads like a wet, liquid spray. The big splat at 16.5 s throws round heavy droplets of mixed sizes in a radial burst.
- Floor: droplets and splatter stay as permanent decals. A large soft stain appears under an exploded torso and partly fades in about 0.5 s, leaving residue. Smeared maroon-purple stains build up around the corpse as more damage is done.
- Dismemberment: the head disappears completely (it reads as vaporised in the mist, with no flying head seen) and is replaced by a glossy, coiled, layered meat stump. The torso is replaced by an open-cavity mesh: a black-maroon wet torn skin rim, pink veined organs (lung-like lobes) and shredded red muscle chunks. No bone is clearly visible (unsure, the resolution is low).
- Persistence: all gore and decals persist for the whole clip (20+ s). The gore meshes stay attached to the ragdoll parts while those parts are pushed around.
- Overkill: hitting a dead body keeps escalating the damage (more decals, then cavity, then splat). Damage on corpses is a feature.

4. Inferred sound and pacing
- The sound is probably a loud shotgun boom on the flash frame, a wet thick splat about 2 frames later (when the mist appears), and a body-thud at about 3.6-3.9 s when the ragdoll lands. The torso explosion at 9.8 s probably has a squelch with a meaty crunch.
- Pacing: short spikes of violence (each shot is about 0.3 s of action), then long quiet inspection holds (2-5 s) to show off the gore detail. The gore is meant to be looked at up close.

5. Key takeaways (actionable)
- Gore appears about 2 frames (130 ms) after the hit frame, not on the same frame. The hit flash and camera kick come first, then the blood.
- Lethal hits: freeze the victim upright for about 0.4-0.5 s (6-8 frames at 15 fps), then switch to ragdoll and let it collapse and settle within about 0.4 s with little bounce.
- Blood mist colour: dark maroon to brown-black (roughly RGB 70-110, 10-25, 10-25), soft and semi-transparent, about 1 s life. Make it a wide flat burst for head or heavy blows and a narrow upward column for close-range body blows.
- The impact VFX is the blood, not sparks or rings. Keep the flash to 1 frame, and use a sharp camera kick (1 frame up, recover in 4-5 frames) rather than a long shake or slow motion.
- Swap in a high-detail wound mesh when a body part is destroyed: a dark glossy torn rim, a layered red interior, pink veined organs for the torso, and a coiled meat stump for the neck. The contrast with the low-poly R6 body is the look.
- Wound meshes must stay welded to their ragdoll part and keep simulating when the body is kicked or shoved.
- Blood decals: thin streak and drip decals on the body near the impact, fine dot spray, and small droplets on the floor within about 1 m. They are permanent.
- Massive hit, or a finisher that blows something open: a large pink-red ground stain (about 1.5-2 m) that fades over about 0.5 s and leaves a faint residue.
- Splat burst: a dark core plus a radial spray of round droplets of mixed sizes, some reaching the camera (screen-space splatter for very close kills).
- Corpses stay and keep reacting: hitting a dead body adds more blood and escalates the gore. Do not despawn quickly; 20+ s was fine here.
- No damage numbers or hitmarkers. The feedback is the body, the blood and the camera kick only.
- Pacing: make each hit a fast violent spike, then leave room (camera freedom, no despawn) for the player to inspect the result up close, so the gore textures need to hold up at close range.

Not observed (do not attribute to this reference): punches, grabs, finisher choreography, hit flashes on the body, impact rings, slow motion, damage UI, visible bone.

Reference files: the contact sheets are (local frames, not in the repo) v3_sheet00.png to (local frames, not in the repo) v3_sheet08.png, and the frames are in (local frames, not in the repo) f3/. A zoom sheet of the key moments (frames 0044, 0050, 0052, 0053, 0115, 0118, 0150, 0152, 0249, 0251) is at (local) v3zoom.png