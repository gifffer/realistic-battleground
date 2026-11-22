# Firearms: research digest

What shipped games, engine docs, Roblox developers and real-world data say about gun handling, and what we keep for Realistic Battleground (R6, Rojo, Luau `--!strict`, server-authoritative, realistic and gore-heavy). This is the input of `docs/firearms/ARCHITECTURE.md`.

How to read the tags:
- **[S]** a fetched source says it (URL next to it or in the section's source list);
- **[E]** an engineering estimate or real-world knowledge with no source found; treat [E] numbers as starting values to tune;
- **[k]** general Unreal Engine / Roblox knowledge not confirmed by a page fetched for this study; check exact names before relying on them.

Sources we could not reach: the BI wiki (Cloudflare 403), the Unreal Insurgency spotlight (403), hub.sp-tarkov.com (blocked), the Battlefield V weapon-animation forum post (500), GDC Vault videos (paywall). No public Infinity Ward GDC talk on MW2019/MWII weapon animation exists; only blogs and interviews. No primary write-ups exist for the internals of Phantom Forces, Bad Business, Frontlines or Weaponry: every claim about them is a community guess.

Units used in this file: metres (m) and studs. **1 stud = 0.28 m** (the R6 avatar scale the repo already uses for the flamethrower). Roblox's default gravity (196.2 studs/s²) assumes 20 studs per metre: at our scale it is 55 m/s², 5.6 times real gravity (see §11).

---

## 1. Shipped architectures: the layer order

Every shipped system builds gun handling from the same stack of layers, applied in order:

1. Locomotion (full body).
2. A per-weapon base stance pose for the upper body (low ready / high ready / shouldered / aiming down sights).
3. Procedural additive springs: look lag, move sway, breathing, footstep bob, landing bump.
4. Action clips: reload, chamber, draw, holster.
5. Recoil (additive).
6. Hand / aim correction LAST, so the hands stay on the gun's grip points.

Evidence:
- **Crysis 3:** idle pose with a weapon target bone → semi-procedural weapon animation → STAP → weapon offset pose modifier → action additives → hand IK retarget last. Crysis 2 used up to 10 layers (base, base modifier, additive sway/idle/run/sprint, bump/jump, action additives for reload/recoil/melee). Per-weapon, per-zoom-mode offsets (`fp_offset` / `fp_rot_offset`) are stored, and the shoulder ↔ zoom 6-DOF offsets are interpolated with a Hermite cubic, not linearly. [S] https://cryengine.com/docs/static/engines/cryengine-3/categories/1114113/pages/1605638
- **Overwatch (GDC 2017) as rebuilt by sreitich:** every procedural effect is an additive pose whose input comes from a damped spring per axis, never a lerp. Lerps snap on sharp direction changes; springs overshoot and settle. [S] https://sreitich.github.io/fpp-animation ; https://www.gdcvault.com/play/1024319/
- **Anew: The Distant Light:** one owner per transform at a time; the gun is unparented from the hand while the aim solver owns it. Standing aim needs a full-body aim set, because masked upper-body poses make standing legs look stiff. When turning while aiming, turn the way that unwinds the torso. The free hand has its own small state machine (weapon grip / relaxed / sprint). [S] https://gamedeveloper.com/design/creating-fluid-gunplay-for-anew-the-distant-light
- **Unreal (ALS / Lyra, Part §12):** locomotion, then an upper-body overlay with per-body-part weights, montage slots for actions, aim offset, then hand IK.

Pitfalls the sources name:
- Apply recoil BEFORE the hand IK step, or the support hand lags the recoiling gun. [S] https://forums.unrealengine.com/t/left-hand-ik-not-keeping-up-with-procedural-recoil-of-weapon/2052237
- Additive layers must not carry left-hand deviation, or the hand slides off the handguard. [S] https://forums.unrealengine.com/t/misalignment-with-additive-animations/236415
- Hands "swim" unless IK targets are masked out of additive layers. [S] https://dev.epicgames.com/documentation/unreal-engine/virtual-bones-in-unreal-engine
- Reading the grip socket one step too early gives a one-frame trail. Compute the hand target after the gun's pose is final. [S] https://forums.unrealengine.com/t/stumped-left-hand-ik-not-updating-when-i-move-the-socket/2209450
- The outgoing clip must keep moving for the whole blend; a frozen last frame reads as a speed break. Don't let a crossfade eat the anticipation of the incoming clip. [S] https://www.gamedeveloper.com/programming/common-mistakes-in-game-animation
- Transitions cost double evaluation, and target-curve transitions avoid overshoot (Gears of War 4). [S] https://history.siggraph.org/wp-content/uploads/2022/09/2017-Talks-Bollo_High-Performance-Animation-in-Gears-of-War-4.pdf

## 2. Weight drives everything

- **MW2019:** animation data is built from calibre and class weight; LMG reloads are "stiffer" than AR reloads. Active idle replaced slow sinusoidal "ship-deck" sway with small, quick, muscle-driven corrections. The head leads and the gun trails when turning. The gun reacts to stairs and steps instead of being glued to the camera. Reloads vary by magazine (extended mags and drums shown physically); each reload is one seamless clip; ADS reloads keep the gun on target; reviewed with SEAL advisors. [S] https://blog.activision.com/call-of-duty/2019-07/Modern-Warfare-Initial-Intel-Detailing-Advancements-in-Animation-and-Authenticity
- **Ground Branch:** ready and transition variants per weapon length and weight; an MG is raised to ADS slower than a carbine. [S] https://www.groundbranch.com/2021/08/31/
- **Arma 3 weapon inertia:** heavy or long guns misalign more and realign slower; SMGs and carbines fastest; bullpups have a small advantage (centre of mass closer); suppressors and high-power scopes make it worse. [S] https://dev.arma3.com/post/oprep-weapon-inertia
- **Tarkov:** ergonomics + weight set ADS speed, sway ("aiming volume") and arm-stamina drain while aiming; out of arm stamina, the aim shakes. Body inertia (patch 0.12.12) affects accelerating, stopping, sharp turns, landing and side-steps, and depends on gear weight. Players hated long stopping: keep body inertia to a few frames and put the weight in the weapon. [S] https://escapefromtarkov.fandom.com/wiki/Performance_modifiers ; https://www.gamepressure.com/newsroom/escape-from-tarkov-patch-01212-adds-new-map-and-voip/z03dd5 ; https://www.sportskeeda.com/esports/feels-like-dogs-t-summit1g-voices-opinion-adding-inertia-escape-tarkov

Real masses to feed the tuning [E]:

| Our weapon (style target) | Mass |
|---|---|
| Compact polymer 9mm (Glock-19-like) | ~0.85 kg loaded |
| 12 ga semi-auto (Mossberg-940-like) | ~3.5 kg + shells |
| 7.62×39 AK-type rifle | 3.1 kg empty, ~3.9 kg loaded |
| .338 bolt-action sniper (AWM/L96-like) + scope + bipod | ~7–8 kg |
| 5.56 belt-fed LMG (M249-para-like) | ~7.1 kg + ~3 kg for a 200-round pouch |

## 3. Sway, inertia, breathing

**Separate forces (Arma 3 rework)** [S] https://dev.arma3.com/post/oprep-weapon-sway-fatigue
- Breathing moves the aim vertically; its size and speed scale with fatigue.
- Grip is a separate force; injuries hurt grip more than breathing.
- Holding breath cancels breathing until oxygen runs out; on release, a penalty spike proportional to the oxygen used.
- Prone is steadier than crouch, crouch steadier than standing. Standing is steady when still but distorts more while turning.
- Running with the weapon raised tires more than with it lowered.

**Insurgency: Sandstorm** [S] https://news.xbox.com/en-us/2021/09/13/creating-immersion-and-intensity-in-insurgency-sandstorm/ ; https://insurgency.fandom.com/wiki/Game_Mechanics
- Low stamina → more sway. Suppression → more sway and vision blur. Crouch → less recoil; prone → much steadier. Breath-hold removes almost all sway.

**Spring parameters from the sreitich rebuild** [S]
- Critical damping factor 0.5 (default), stiffness 25 (×35 internally), mass 10, interp speed 1; a NEGATIVE interp speed turns lag into lead.
- Movement sway: 2 springs on local velocity ÷ max speed. Aim sway: 2 springs on look angular speed, normalised to 720°/s (yaw) and 360°/s (pitch). Zero the aim speed on the first frame (no spike). Falling offset = vertical velocity ÷ jump velocity. Skip spring updates when dt > 0.1 s.
- Opsive uses Perlin turbulence for idle and scoped breathing. [S] https://opsive.com/support/documentation/ultimate-character-controller/animation/springs/

**Starting numbers, third person, gun relative to the torso [E]**

| Effect | Pistol | Rifle / shotgun | Sniper / LMG |
|---|---|---|---|
| Look-lag spring frequency | 6–8 Hz | 4–6 Hz | 2.5–3.5 Hz |
| Look-lag damping ratio ζ | 0.55–0.7 | 0.55–0.7 | 0.55–0.7 |
| Look-lag max offset | 4–8° | 4–8° | 4–8° |
| Move sway | 2–4° roll | 1–2 cm back | as rifle, slower |
| Walk bob per footstep | 0.5–1° | 0.5–1° | 2× rifle |
| Landing bump | 3–8° pitch dip, ~250 ms recovery, scaled by landing speed (Crysis "bump" [S]) | same | same |

- Damping guide: ζ = 0.7 → ~4.6 % overshoot; ζ = 0.5 → ~16 %. Settling time ≈ 4 / (ζ·ω).
- Breathing [E]: at rest 12–16 breaths/min (0.2–0.27 Hz), 0.2–0.5° vertical. After a sprint 30–40 breaths/min, 1.5–3°, decaying over 5–10 s. Add 2–3 octaves of Perlin noise at ≤ 0.3° for the "muscle" part.

## 4. Recoil

**Structure.**
- CryEngine treats recoil like car suspension: a spring pulls back to neutral, a damper filters fast moves. Crysis 3 per-fire-mode values [S]: third person (Crysis 2) `duration` 0.4, `strength` 0.06, `kickIn` 0.3; first person `dampStrength` 7.5, `fireRecoilTime` 0.05 s (one ~50 ms impulse), `fireRecoilStrengthFirst` 3.0 (the first shot of a burst is 6× the later ones), `fireRecoilStrength` 0.5, `angleRecoilStrength` 0.4, `randomness` 0.1.
- Kinemation PRAS (a commercial procedural kit) [S] https://kinemation.gitbook.io/pras-documentation/basics/recoil-settings.md :
  - controller (aim) recoil: a random pitch/yaw step, smoothing, damping back to zero, a "compensation %" that honours the player's pull-down;
  - visual kick: separate pitch/yaw/roll and back/right/up ranges, for hip and for aim;
  - auto-fire smoothing per axis; roll alternates sign each shot;
  - a noise layer on the YZ plane, smaller when aiming;
  - pushback added from the 2nd shot of a burst;
  - "recoil sway" (the body absorbing it), with its own damping, scaled when aiming;
  - the pivot is the shoulder or the cheek, not the gun's centre, and differs hip vs ADS;
  - the timeline is locked to the fire rate (600 RPM = 0.1 s per shot).
- Feel numbers [k]: the impulse lasts 1–2 frames; recovery half-life ~60–120 ms; slight overshoot (ζ 0.5–0.7) reads as weight; heavier guns get lower stiffness and more mass.
- Overwatch sells kick with the arm extending, then pulling back up (McCree). [S] https://www.invenglobal.com/articles/1187/how-overwatchs-first-person-animation-breathed-life-into-heroes

**Camera vs weapon.**
- Keep the gameplay recoil path (where bullets go) separate from cosmetic camera shake; layer the shake on top so it never fights the player's aim input. [S] https://devforum.roblox.com/t/need-help-adding-visual-recoil-camera-shake-how/3904950
- Apex-style recovery: a small settle after each shot (not a full return), then the camera goes back to its pre-spray rotation when the spray ends. [S] https://discussions.unity.com/t/where-to-look-to-try-and-implement-fps-weapon-recoil-recovery/1702238
- Tarkov splits weapon recoil (moves the aim) from camera recoil (moves the view); "convergence" is the return speed. Camera recoil was cut 20 % in 0.13.0.2 because it was too much. [S] https://www.ggrecon.com/guides/escape-from-tarkov-0-13-0-2-patch-notes/
- Players judge VISUAL recoil. MWII was criticised for visual recoil that hid targets; MW4 aims for "more understandable" recoil and muzzle smoke that never hides the target. [S] https://www.techradar.com/gaming/consoles-pc/modern-warfare-4-developer-breaks-down-the-most-advanced-weapon-simulation-in-call-of-duty-history-we-want-them-to-feel-like-real-weapons-but-they-shouldnt-feel-frustrating
- Roblox: apply the rotational spring as a DELTA to the camera each frame, after the camera module runs; an absolute CFrame freezes or drifts the camera. Step springs with dt (frame-rate-dependent recoil is a common Roblox bug). [S] https://devforum.roblox.com/t/how-to-add-recoil-to-a-gun-while-maintaining-a-3rd-person-view-camera-lock/2221701 ; https://devforum.roblox.com/t/recoil-depends-on-the-fps/2519376 ; https://devforum.roblox.com/t/spring-based-camera-recoil-not-going-back-to-original-position/3388055
- Roblox Weapons Kit defaults [S]: RecoilMin 0.05, RecoilMax 0.5, RecoilDecay 0.825, RecoilDelayTime 0.07, TotalRecoilMax 2. https://create.roblox.com/docs/resources/weapons-kit

**Third-person recoil: the body absorbs it [E].** The kick goes into the shoulders and arms (pitch up + push back), the upper torso (a small rearward rock) and the head (small, one frame late). Onset 1–2 frames (a deliberate snap), peak at ~30–50 ms.

| Weapon | Kick | Recovery | Notes |
|---|---|---|---|
| Pistol | 6–12° muzzle flip | 120–180 ms | wrists break, elbows absorb, ~5 % overshoot |
| AK | 3–5° pitch + 1–2 cm back per shot | 150–220 ms | cumulative climb on auto; real AKs climb up and right |
| 12 ga | 8–14° + 4–6 cm shoulder push + torso rock | 350–500 ms | |
| Sniper | 6–10° + strong push | 500–700 ms | the brake lowers felt recoil; then the bolt cycle |
| LMG | 1.5–3° per shot | — | bipod cuts it ~70 %; heavy mass, high-frequency jitter |

Free-recoil energy for relative scaling [E]: 9mm ~4–6 J; 7.62×39 ~7–9 J; 5.56 ~4–5 J; 12 ga 3" ~35–50 J; .338 Lapua ~40–55 J (minus ~30–50 % with a brake).

## 5. Third-person aim and hit registration

**TLOU2 (GDC 2024, Derek Mattson, "A Second Shot")** [S] https://media.gdcvault.com/gdc2024/Slides/GDC+slide+presentations/Mattson_Derek_ASecondShot_Notes.pdf
- The root problem: the camera is decoupled from the character. "Reticle is King."
- Probes: a camera spherecast through the reticle that ignores the environment; a hidden camera raycast that hits the environment; a muzzle probe back-calculated from the camera probe's predicted impact, colliding only with enemies, passing through a near blocker for ~1 frame. Mattson warns this player-favouring setup is wrong for multiplayer (getting shot from behind a corner): a server-authoritative game must check muzzle-to-target line of sight (see Forrest Smith, "Adventures with Guns in a Third Person Shooter").
- "Weapon feel is almost entirely hit reactions": a leg shot gives a stun (and opens follow-ups); a neck shot a unique death; torso collision = several horizontal capsules on the spine joints; the thigh split in two capsules so knee shots count as leg shots. Start with good animation and hit detection before FX, sound and haptics.
- Render latency (up to 3 frames at 30 fps) is covered by buffering the reticle overlap of the last few frames and granting near-misses through a "hit chance curve" (91.84 % → 100 %). "Almost missing feels worse than missing by a mile."
- Projectiles: shoot straight through the reticle, no gravity for the first frames then blend it in; spherecasts slightly fatter than the projectile.
- TLOU2 reload craft (Troy Slough): intricate reloads easy to miss mid-combat. [S] https://gamesradar.com/the-last-of-us-2-animator-shows-off-intricate-reload-animations-you-may-have-missed . Known in play [E]: partial shotgun reloads count shells; the weapon lowers near walls and allies.

**Aim offsets.**
- A 3×3 aim pose grid (L/C/R × up/centre/down), waist up, blended by aim vector; test the extremes for shoulder deformation. Upper/lower split at spine_01/02. Blend weights need not be 0/1 (sprint: 0.3 locomotion / 0.7 weapon). Soft/hard aim transitions 0.15–0.25 s: under 0.15 feels janky, over 0.3 sluggish. A third-person character typically needs 80–150 clips per weapon type in AAA. [S] https://mocaponline.com/blogs/mocap-news/third-person-shooter-animation-guide
- UE Aim Offset = a blend space of MESH-SPACE additive poses on a yaw/pitch grid over a base aim pose: a pitch-up additive rotates spine and arms around world axes, so the gun rises whatever the stride does. [S] https://dev.epicgames.com/documentation/en-us/unreal-engine/aim-offset-in-unreal-engine
- Third-person aim-to-crosshair: trace from the camera, then rotate the muzzle toward the hit point (a small corrective angle). [S] https://forums.unrealengine.com/t/third-person-rifle-to-view-alignment/145841
- R6 has no waist joint: pitch comes from the shoulders, the neck and possibly a small RootJoint lean (which tilts the legs too). [S] https://devforum.roblox.com/t/how-to-tilt-the-torso-on-an-r6-rigtype-so-it-faces-the-camera-direction/1933818
- EgoMoose's split [S] https://devforum.roblox.com/t/the-first-person-element-of-a-first-person-shooter/160434 : θ·0.5 on the neck, θ·0.5 on the waist (RootJoint on R6), the arms get the full θ. Send the angle ~every 0.1 s and interpolate on the receiving side; never fire a remote every frame. Arms solved from "Left"/"Right" grip parts on the weapon.

## 6. Weapon positions, ready stances, walls

Ground Branch taxonomy (the best public spec) [S] https://www.groundbranch.com/2012/10/weapon-positions/ ; https://www.groundbranch.com/2021/08/31/

| Position | What it is |
|---|---|
| Engaged | full extension, sights up |
| Ready | full extension, sights not engaged |
| Close Ready | pistol tight at the chest; long gun stock under the shoulder above the hip |
| Low Ready | muzzle down; default off-target for long guns; slight fire delay |
| High Ready | elbows in, muzzle up; stairs and slopes; free off-hand |
| Sul | gun rotated 90°, held at the chest, muzzle nearly vertical; near allies |
| Obstructed Low / High | automatic, from the weapon's angle and stance; real fire delay (High < Low) |

- Tap aim toggles low/high ready; hold aim switches Engaged ↔ Ready. Smooth transitions; the trigger finger is visibly off/on per stance; longer guns use a more tucked High Ready; auto-lower or auto-raise near a friendly.
- Ready or Not: the gun first pushes toward the screen before dropping to low ready against a wall (a warning before it becomes unusable). [S] https://devtrackers.gg/ready-or-not/p/45652433-ron-pve-update-14-12-2021-patch-16671
- UE5 "tuck" additive: capsule-trace ahead, tuck alpha from penetration depth; the gun stays angled toward the screen centre and bullets go barrel → crosshair. [S] https://80.lv/articles/developer-proposes-an-elegant-solution-for-realistic-third-person-weapon-handling

Recipe [E]: cast from the shoulder along the barrel for the weapon length + 0.15 m. Penetration 0–40 %: slide the gun back up to 15–20 cm. Over 40 %: rotate to High Ready (aim pitch > −10°) or Low Ready (otherwise) through a spring, 0.15–0.25 s. Block or delay firing while obstructed (~0.15 s to come back on target). Hysteresis so it does not flicker.

## 7. Timings: ADS, draw, holster, sprint

| | Pistol | AK-type | 12 ga | Sniper | LMG | Source |
|---|---|---|---|---|---|---|
| Ready → ADS | 150–200 ms [E] | ~250 ms [S] | 280–320 ms [E] | ~400 ms [S] (MWII 516 ms) | ~450 ms [S] | https://hone.gg/blog/ads-in-call-of-duty/ |
| Sprint → fire | 150 ms | 220–280 ms | 280 ms | 400–450 ms | 400–500 ms | [E]; Cold War snipers 400 → 450 ms [S] https://pcgamer.com/call-of-duty-cold-war-sniper-nerf |
| Draw (game) | 0.45–0.6 s | 0.8–1.1 s from a back sling | ~1.0 s | ~1.1 s | 1.1–1.4 s | [E] |

- A whole weapon swap takes 0.8–1.5 s (holster → brief neutral → draw → ready) and is interruptible. [S] mocaponline
- Real pistol draw to first shot: 1.0 s (outside-waistband holster) to 1.5 s (concealed) for good shooters; 0.64 s from hand-on-gun. [S] https://www.rifleconfigurator.com/drills/bill-drill ; https://thetruthaboutguns.com/testing-a-new-standard-for-handgun-testing . Game draw [E]: the four-count draw (grip → clear → rotate / meet the support hand → press out).
- Attachments that improve range or recoil slow ADS. [S] hone.gg
- Crysis known issue: a too-abrupt run → sprint transition; give sprint start / loop / stop. [S] CryEngine doc.
- Sprint carry [E]: rifle canted 30–45°, muzzle down-left across the body, stock at the hip/armpit, support hand on the handguard, elbows in, some bounce lag. Pistol: compressed at the chest or in the strong hand, pumping. LMG: low across the body or by the carry handle, slower. Sniper: muzzle down or port arms.

## 8. Reloads: craft, timing, interruption

**Shipped facts** [S]
- Infinity Ward animators author per weapon: tactical, empty, pull-out, put-away, ADS. https://www.engadget.com/2012/11/08/infinity-ward-animator-talks-first-person-flourishes/
- Halo 2's list: idle, ready, put-away, fire overlay, reload-full, reload-empty. https://learn.microsoft.com/en-us/halo-master-chief-collection/h2/art/animation/animationsfpanims
- Insurgency: an early reload sacrifices the remaining rounds (mags tracked one by one); the empty reload locks the bolt back; a reload can be interrupted mid-way with no mag in.
- Spawn the mag drop from the clip's release EVENT, not a fixed time; keep the hands on the weapon while moving; separate tactical (partial mag) and empty (slide lock) reloads. [S] mocaponline
- Keep reload action off the reticle and out of the central "combat corridor" (Destiny, David Helsby). https://gdcvault.com/play/1022297/ . Overwatch moved Soldier 76's reload to the left hand for readability. [S] Inven.
- First-person animation is mainly feedback: which weapon is equipped and whether it is ready to fire (Ryan Duffin, GDC 2013). https://gdcvault.com/play/1017633/
- DICE BF5: convey "weight and balance, and the intricacies and resistance of the action". https://vgr.com/?p=41276 ; https://www.dice.se/in-the-dice-news-blog/lets-push-innovative-gunplay
- UE montages: notifies at key frames run gameplay (MagOut, MagDrop, MagIn, BoltBack, BoltRelease); use montage notifies for socket swaps; the mag is its own bone or mesh; keep the weapon's own animation (bolt, slide, mag) synced to the character's. [S] https://dev.epicgames.com/documentation/unreal-engine/animation-notifies-in-unreal-engine ; https://forums.unrealengine.com/t/behavior-of-montage-notify-vs-skeleton-notify/245245 ; https://forums.unrealengine.com/t/how-to-synchronize-weapon-and-character-animations/1811585
- During the montage the left-hand IK weight goes to 0 while the hand fetches a mag, back to 1 when it regrips: curve-driven, never a pop. Ammo is committed at MagIn, not at the start; a cancel before keeps the old mag. [k]

**Craft per reload [E]** (to match Blender keys)
- Anticipation: dip and cant the gun 15–35° toward the support hand; pull it 10–20 cm in toward the chest "work space"; the head looks at the mag well; the support hand moves first.
- Overlap: the gun lags the hand's impulse by 2–4 frames; the mag swings slightly as it is pulled.
- Insert: a fast approach, a short hard stop (seat slap, a deliberate snap); the gun bumps 2–4° up and 1–2 cm, then settles over 150–250 ms with one small overshoot.
- Chamber / release: a sharp pull with a whole-gun counter-motion (the gun moves 1–3 cm toward the pulling hand), then the slam forward with a small recoil-like jolt.
- Follow-through: back to ready through a spring (not a linear blend), ~200–300 ms for a rifle, ~350 ms for the LMG; the head comes back on target last.
- Interrupt: sprint or fire cancels before the commit point (mag seated); before it, the round count does not change. Shell loops cancel after each shell.
- Tactical vs empty: tactical strips the old mag (kept in a pouch +0.3–0.5 s, or dropped); empty drops it (pistol / AR) or strips and drops it (AK), then the slide / bolt action (+0.4–0.7 s).

**Timing targets [E]** (game-plausible, near real skilled times)

| Weapon | Tactical | Empty | Notes |
|---|---|---|---|
| Pistol | 1.5–1.8 s | 1.9–2.2 s | slide release or overhand rack ~0.3 s. Real: ~2 s good shooters, 3 s+ most [S] https://gundigest.com/how-to/reloading-in-competitive-pistol-shooting |
| AK-type | 2.4–2.8 s | 3.0–3.5 s | no bolt hold-open on standard mags |
| 12 ga semi | per shell 0.45–0.55 s | + port load | |
| Bolt sniper (detachable mag) | 3.0–3.6 s | 3.6–4.2 s | + bolt cycle 0.8–1.1 s |
| Belt LMG | 6–8 s | — | +1 s if the pouch is replaced |

## 9. Manipulation per weapon (real procedure → beats)

**Pistol (striker 9mm).** The mag drops free under gravity when the thumb button is pressed. Empty: slide locked back; slide release or overhand rack after insertion. Casings eject right and rear; some generations throw them up and back toward the face (ejector geometry). [S] https://palmettostatearmory.com/forum/t/brass-hitting-me-in-head-when-ejecting/18627?page=2

**AK-type [E].** Tactical: thumb or the new mag's spine presses the paddle release behind the mag; the old mag rocks forward-out (pivot on the front lug, ~20–30°); the new mag rocks in (front lug hooks first, rotate back, click). Empty: the same, then the right hand (or the left reaching under/over) racks the right-side charging handle fully back and lets it slam.

**12 ga semi-auto (940-like: no pump; reciprocating charging handle; bolt release button; tube under the barrel; loading port underneath) [E].**
- Tube top-off loop: start 0.35–0.45 s (roll the gun 60–90° belly-up / outboard, support hand to the port, strong hand stays on the grip); per shell 0.45–0.55 s (take from the carrier, thumb it in, follow-through push, small gun bump); end 0.3–0.4 s (roll back, remount). Cancellable after every shell.
- Empty: bolt locked open → one shell dropped through the ejection port ("port load"), hit the bolt release (the bolt slams) → then the tube loop.
- Real: 10 shells, remount and an aimed shot under 10 s (8 s with practice); competition quad-loads do 8 in ~3 s (special gear, not our style). Single-shell loading is recommended under stress. [S] https://pewpewtactical.com/reloading-shotguns/ ; https://www.recoilweb.com/preview-speedload-your-shotgun-like-the-pros-36537.html

**Bolt-action sniper (AWM/L96-like, 5-round detachable mag).**
- Cycle [E]: lift (handle rotates 60–90°) 0.12 s; pull 0.18 s (the case ejects at the end of the pull, gently); push 0.18 s; lock 0.1 s; settle 0.2–0.3 s.
- Keep the cheek weld: the head stays on the stock, only the right arm moves; the gun rolls 3–5° and dips on the pull; the support hand holds.
- Record shooters cycle in ~1.56 s per aimed shot; lifting the head off the stock is a known time cost. [S] https://bulletin.accurateshooter.com/2019/10/scandinavian-bolt-action-speed-shooting-stangskyting
- Ejection force depends on how hard the bolt is worked; a slow bolt barely tosses the case. [S] https://www.africahunting.com/threads/win-m70-ejector-adjustment-crf-models.90590/post-1401932
- Hunt: Showdown's developers call lever and bolt actions "particularly challenging when combining physics and animation". [S] https://steamcommunity.com/app/594650/discussions/8/3040480429141848198/

**Belt-fed LMG (M249/Minimi-para-like).** Real procedure (US Army FM 23-14, USMC TBS) [S] https://www.globalsecurity.org/military/library/policy/army/fm/23-14/fm231_4.htm ; https://www.trngcmd.marines.mil/Portals/207/Docs/TBS/B3M4138%20M249%20Light%20Machine%20Gun.pdf
1. Pull the bolt to the rear first (open-bolt gun).
2. Squeeze the latches at the rear of the feed cover, flip it open; raise the feed tray if checking.
3. Remove old links and rounds; glance at the chamber.
4. Lay the belt, open side of the links down, first round against the cartridge stop. Cant the weapon right when loading.
5. Hold the belt, count ~5–6 rounds down, close the cover with a hand in front of the rear sight.
- Game beats [E]: unclip the empty 200-round soft pouch (left side under the receiver) and drop it (~0.6–0.8 kg empty); clip on the new one (~3 kg); pull the belt end up and lay it in; slap the cover shut (deliberate snap); charge if needed. 6–8 s total. Body crouches into the gun; heavy, slow arcs; strong anticipation before the cover slap.
- Spent cases fall DOWN, links go out to the RIGHT: spawn both [E]. Visible belt: N link + round segments from the tray to the pouch, hidden one by one as the count drops [E].

## 10. Casing ejection: real data → simulation

**AK (Type 56, steel case), forensic study, 60+ shots, shooters and a fixed mount** [S] https://kar.kent.ac.uk/id/document/3221503 (Nishshanka & Shepherd)
- 94 % of cases landed right and FORWARD of the shooter, 6 % right-rear.
- Resting distance: fixed mount average 5.1 m (min 2.2, max 6.8, SD 1.3 m); human shooters average 5.5–6.0 m (min 1.9, max 7.7 m). Two other rifles: 8.7 m and 8.0 m averages, max 9 m. Measured on grass (little roll). Dispersion is rifle-specific (long piston stroke, gas leaks, the case hitting the receiver cover).
- Sim launch [E]: ~5–7 m/s, toward 1–2 o'clock (right, ~30–50° forward of perpendicular), +10–20° up. Fall from ~1.4 m ≈ 0.53 s, then bounce and roll.

**Pistols**
- Glock 17 vs P226: both group right-rear; the Glock more angled to the line of fire, the Sig more parallel. [S] https://www.ojp.gov/ncjrs/virtual-library/abstracts/cartridge-casing-ejection-patterns-two-types-9-mm-self-loading
- Over 25 % of cases from 8 police pistols land somewhere other than right-rear (grip, cant, movement). [S] https://www.ojp.gov/ncjrs/virtual-library/abstracts/fired-cartridge-case-ejection-patterns-semi-automatic-firearms
- Carpet test: 0 to 5.4 m; canting the gun 90° left flips the pattern left-rear. [S] https://www.forensicmag.com/3425-Featured-Article-List/622131-Evidence-Retrieval-Getting-the-Most-from-Semi-Automatic-Pistol-Casings/
- Sim [E]: ~2.5–4 m/s, 3:30–4:30 o'clock (right, slightly back), +30–45° up; ~10 % chance of a steep up-and-back toss.

**Others**
- AR-15 baseline: 3:00–4:30 o'clock is healthy; 12–2 o'clock means over-gassed. [S] https://www.at3tactical.com/blogs/news/ar-15-brass-ejectio-patterns-diagnosing-your-rifles-performance
- Bolt sniper [E]: 1–2.5 m/s from the pull stroke, right and slightly up, lands 0.5–1.5 m away; the big .338 case is heavy and tumbles slowly.
- Shotgun hull [E]: plastic hull, brass head, ejected right at 1.5–3 m/s; large and light (drag matters), dull plastic thud, little bounce, rolls.
- LMG [E]: cases straight down under the gun at 1–2 m/s, links to the right; piles form under the gunner.

**Spin, bounce, lifetime, implementation**
- Spin [E]: 15–40 rev/s around a random axis near the case's short axis, ±30 %. Randomise launch ±10–15° and ±15 % speed per shot.
- Bounce [S] (hobby implementations): vertical restitution ~0.25–0.5, ~25 % horizontal speed lost per bounce (a Godot example halves it). https://huggingface.co/spaces/victor/orcs-in-the-forest/blob/main/src/casings.js ; https://forum.godotengine.org/t/realistic-cartridge-case-ejection/125513
- Brass on concrete [E]: 3–5 audible micro-bounces over 0.3–0.8 s, then a short roll.
- Use an impulse, never a force; build the direction from the WEAPON's own axes so it follows cant; continuous collision (small fast parts tunnel through thin floors). [S] Godot thread.
- Inherit the shooter's velocity, or casings fly "behind the player when walking", a classic Roblox bug. [S] https://devforum.roblox.com/t/shells-ejecting-behind-the-player-when-walking/1158420 ; https://devforum.roblox.com/t/issues-with-shell-ejection-while-moving/2769851
- Roblox [S]: spawn casings on clients only (the shooter's own instantly, the server relays to the OTHER clients; server-made casings are late and duplicated). Unanchored parts hanging in the air are an ownership/timing issue; ApplyImpulse after parenting (possibly one frame later) works. Mass `Destroy()` calls degrade performance: pool. A collision group so casings never hit the gun or the shooter; CanTouch / CanQuery / AudioCanCollide off. An assembly sleeps below 0.33 studs/s. https://devforum.roblox.com/t/how-to-replicate-client-side-shell-ejection-and-keep-server-and-client-shell-ejection-seperate/1289477 ; https://devforum.roblox.com/t/bullet-casing-ignores-physics/3384404 ; https://devforum.roblox.com/t/performance-degradation-after-mass-basepartdestroy-calls-with-getpartboundsinradius-%E2%80%94-best-practices-for-high-throughput-part-removal/4730759 ; https://create.roblox.com/docs/workspace/collisions ; https://create.roblox.com/docs/physics/sleep-system
- Pooling: PartCache (keep parts parented, CFrame them away; ~3× faster than create/destroy), ObjectCache (BulkMoveTo, FireCFrameChanged off). [S] https://devforum.roblox.com/t/partcache-for-all-your-quick-part-creation-needs/246641 ; https://github.com/Pyseph/ObjectCache
- Lifetime: hobby kits remove casings at 2.5–3 s. For a gritty game [E]: keep 30–60 s with a per-client cap (~100–150, oldest recycled), freeze each at rest, fade by sinking. Players complain when casings vanish at once. [S] https://feedback.bistudio.com/T165330
- Sound [S/E]: libraries record per surface (e.g. 12 shell types × 7 surfaces, 3600 takes, https://www.asoundeffect.com/?p=68448). Concrete/tile: bright metallic tink with ring; wood: duller, shorter; metal: louder, ringing; dirt/grass/mud: near-silent. Steel-case 7.62×39 is duller than brass; a plastic hull is a hollow tap; the big .338 case is lower. Per impact: velocity-scaled volume, pitch ±8 %, 40–60 ms minimum between impacts of one casing; the first contact only when it actually lands (~0.5 s), never instantly. In auto fire, the overlapping tinkles behind the shots are what sells realism.

## 11. Magazine drop

- Roblox pattern (DevForum consensus) [S]: the real mag is a Motor6D'd part animated with the clip; at the release event hide it and spawn an unanchored clone at the same CFrame with the hand's velocity; at the grab event show a fresh mag on the hand. Drop on the client (smooth); in a server-authoritative game send an event and let each client spawn its own cosmetic copy. Server-side drops hitch when network ownership changes mid-fall. Give the clone a simple invisible collision box, a collision group, ~30 s cleanup, ~8 per player cap. https://devforum.roblox.com/t/how-do-you-animate-a-gun-where-the-gun-mag-is-part-of-the-animation/172438 ; https://devforum.roblox.com/t/how-do-you-correctly-animate-a-gun-magazine/1041225 ; https://devforum.roblox.com/t/how-to-make-a-gun-reload-animation-where-the-old-magazine-is-dropped/3038822 ; https://devforum.roblox.com/t/why-does-physics-lag/1997027
- Physics [E]: inherit hand and gun velocity. Pistol mags fall nearly straight with a slight forward spin. AK mags are rocked out: forward angular velocity ~3–6 rad/s, they tumble. Masses: pistol mag ~0.07–0.1 kg empty (~0.25 kg loaded); steel AK mag ~0.33 kg empty (~0.8 kg loaded); empty belt pouch ~0.6–0.8 kg (cloth, floppy, no bounce). Restitution: polymer 0.2–0.3 with a hollow clack; steel 0.15 with a heavy clank and little roll; cloth ~0, a thud.
- Lifetime [E]: 60–120 s, cap ~20 per client. A retained tactical mag never drops (it goes to the vest).
- Tarkov: a separate "check mag" action; malfunctions mostly from mags (drums especially), heat and condition. [S] https://escapefromtarkov.fandom.com/wiki/Weapon_malfunctions (a possible later feature: jam clearing).
- **Gravity at our scale [E]:** Roblox's 196.2 studs/s² is 55 m/s² at 0.28 m/stud. Casings and mags under it fall 2.4× too fast (5 studs = 1.4 m in 0.23 s instead of 0.53 s). Cosmetic debris needs ~35 studs/s² (9.81 / 0.28).

## 12. Unreal Engine conventions (for the player's 71-bone reference)

**UE4 mannequin (SK_Mannequin, 68 bones) [k]** — the reference is probably this plus a few extras (weapon or virtual bones). UE5 Manny has more (spine_04/05, neck_02, metacarpals).
- root > pelvis > spine_01 > spine_02 > spine_03 > neck_01 > head.
- spine_03 > clavicle_l/r > upperarm_l/r > lowerarm_l/r > hand_l/r; 5 fingers × 3 bones per hand; twist bones upperarm_twist_01, lowerarm_twist_01.
- pelvis > thigh_l/r > calf_l/r > foot_l/r > ball_l/r; thigh_twist_01, calf_twist_01.
- Under root, not the pelvis: ik_foot_root > ik_foot_l/r; ik_hand_root > ik_hand_gun > ik_hand_l, ik_hand_r.
- Count: 7 + 2×21 + 2×6 + 7 = 68.

**ik_hand_gun** [S] https://forums.unrealengine.com/t/explanation-of-the-mannequin-ik-bones/45166 ; https://forums.unrealengine.com/t/mannequin-hand-ik-confusion/56882 ; https://forums.unrealengine.com/t/how-can-i-retarget-ik-bones-in-ue4-skeleton-to-ue5-skeleton/2498817 ; https://forums.unrealengine.com/t/whats-the-purpose-of-right-hand-ik-in-lyra/2743139
- IK bones do not deform; they are targets. ik_hand_gun is keyed to follow hand_r: it is where the weapon sits. ik_hand_l / ik_hand_r store where each hand belongs relative to the gun. After additives move the arms, the IK pass puts hand_l back on ik_hand_l.
- Animations must key ik_hand_root, ik_hand_gun and ik_hand_l/r explicitly; retargeting snaps ik_hand_gun onto hand_r; many projects attach weapons to ik_hand_gun; Lyra uses right-hand IK mostly for retargeting.
- ALS-Refactored virtual bones "VB hand_l_to_ik_hand_gun" / "VB hand_r_to_ik_hand_gun" express each hand relative to the gun bone. [S] https://raw.githubusercontent.com/Sixze/ALS-Refactored/main/Source/ALS/Public/Utility/AlsConstants.h
- Left-hand IK: read the weapon's "LeftHandGrip" socket each frame in hand_r space, feed a Two Bone IK on hand_l with a pole vector keeping the elbow down and out; IK alpha driven by curves (ALS v4 Enable_HandIK_L/R [k]; ALS-Refactored HandLeftIk / HandRightIk [S]). https://docs.unrealengine.com/4.26/en-US/AnimatingObjects/SkeletalMeshAnimation/NodeReference/SkeletalControls/TwoBoneIK ; https://forums.unrealengine.com/t/weapons-and-hand-placement/12801

**ALS overlays and layering** [S] https://miica37.github.io/docs/unreal-guides/als/ ; https://raw.githubusercontent.com/Sixze/ALS-Refactored/main/Source/ALS/Public/State/AlsLayeringState.h ; https://unreal-devop.gitbook.io/gasp-dynamicadditiveoverlay/basics/gasp-dao-1.44/editor-1/editor-4/primary-data-asset-creation/pda_overlaylayering
- An upper-body overlay pose (rifle, pistol 1H/2H, bow, torch, box...) over base locomotion, plus aim offset, hand IK, foot IK and look-at. Rifles need weapon alignment plus left-hand IK.
- Per-part blend weights 0..1: Head (blend/additive/slot), ArmLeft/ArmRight (blend/additive/slot/local-space/mesh-space), HandLeft/HandRight, Spine (blend/additive/slot), Pelvis, Legs.
- Additive = (overlay − overlay base pose) added onto live locomotion, so the arms keep some walk swing and the gun bobs with the body. Override = blend to the overlay. Per arm: mesh space (keeps its pose relative to the root, so the gun stays aimed while the spine sways) or local space (inherits the spine). "Slot" lets montages override per part. A rifle overlay: spine ~0.5–0.75 additive, arms mesh space weight 1, head stiffened.

**Lyra** [S] https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-in-lyra-sample-game-in-unreal-engine ; https://www.unrealengine.com/tech-blog/adapting-lyra-animation-to-your-ue5-game ; https://dev.epicgames.com/documentation/en-us/unreal-engine/pose-warping-in-unreal-engine
- Per-weapon anim-layer sets linked on equip (animations loaded only while the weapon is equipped); upper/lower split with Layered Blend Per Bone; fire and reload montages on the upper body; montages use blend profiles and inertialization.
- Turn in place: the actor follows controller yaw, "Rotate Root Bone" counters it; Root Yaw Offset modes Accumulate (idle) / Hold (starts) / Blend Out (jog); turn clips triggered by angle and wait time.
- Distance matching (play rate so feet match distance), stride warping, orientation warping (twist the lower body to cover 360° from 4 cardinal strafes).
- GASP (Game Animation Sample, motion matching) has no weapon overlays; the community adds them (GASP-ALS). [S] https://dev.epicgames.com/documentation/en-us/unreal-engine/game-animation-sample-project-in-unreal-engine ; https://github.com/gokhocse/GASP-ALS

## 13. Roblox: what the best gun systems do

**Kits** [S]
- ACS 2.0.1: first-person only; viewmodel arms written to Motor6Ds in RenderStepped (hard to re-animate); no third person. https://devforum.roblox.com/t/acs-advanced-combat-system-robloxs-1-fps-combat-system/1285741
- Carbon Engine: first person; "sound isolation" (distant shots sound distant); viewmodel speed depended on frame rate (a lerp not scaled by dt). Reportedly discontinued; do not link its docs domain. https://devforum.roblox.com/t/ce-carbon-engine-revolutionary-fps-combat-technology/872472
- FE Gun Kit: viewmodel and real-character variants; widely forked (one reply says Criminality runs a modified one); dated and buggy. https://devforum.roblox.com/t/how-to-use-the-fe-gun-kit-edited-and-what-it-is/1763847
- Roblox Weapons Kit (official): projectiles + ShoulderCamera (weaker on R6). Config names worth reusing: BulletSpeed (20000 ≈ hitscan), GravityFactor, MaxDistance, MinSpread/MaxSpread, NumProjectiles; recoil (above); CasingEjectPoint attachment whose orientation is the eject direction, CasingEjectSpeedMin 15 / Max 18, CasingHitSound; Beam tracers, HitMark aligned to the normal; SlowZoomWalkEnabled. https://create.roblox.com/docs/resources/weapons-kit
- Laser Tag sample (official hit-validation reference): the client raycasts; the server checks types, the ray angle against the recomputed direction (tolerance in degrees), shooter near the origin and target near the destination (studs tolerance, raised for fast walkers), then re-raycasts for walls. Fire state machine (Ready / Blasting / Disabled) on both sides, server owns the cooldown. Fire on button DOWN. https://create.roblox.com/docs/tutorials/curriculums/gameplay-scripting/detect-hits ; https://create.roblox.com/docs/tutorials/curriculums/gameplay-scripting/implement-blasters
- Kaeto (R6): a Bolt/Slide part cycling on fire, AimPart and Muzzle markers; the muzzle is for effects and the obstruction check only, the bullet starts from the aim ray; head and arm rotation replicated. https://devforum.roblox.com/t/kaeto-ranged-weapons-system-for-r6-rigs/2586186
- Open-source OTS system: shoulder switch Q/E, safety stance, per-material hit sounds/particles, visuals on the client. https://devforum.roblox.com/t/open-source-ots-gun-system-no-longer-updated/1576415
- Phantom Forces / BHRM5 / Frontlines (guesses only): procedural CFrame work, IK-solved limbs, each client generating others' animation from compact replicated state, update rate scaled down with distance; Frontlines-style "feels like true hitscan" = client hit registration with server sanity checks. https://devforum.roblox.com/t/how-are-prodcedural-animations-created-in-games-like-phantom-forces/194145 ; https://devforum.roblox.com/t/gun-system-hitscan-help-how-do-other-games-overcome-client-server-time-delays/4194566

**Engine facts** [S]
- The Animator writes Motor6D.Transform every frame after PreAnimation and before PreSimulation; Transform changes apply in a batch after PreSimulation. Procedural layers multiply into Transform in PreSimulation (this repo already does it: R6Pose / CharacterAnimationController). Skip work when Animator.EvaluationThrottled. https://create.roblox.com/docs/reference/engine/classes/Motor6D ; https://create.roblox.com/docs/reference/engine/classes/Animator
- Script-written Transforms are NOT replicated: the server sees every R6 body in its rest pose (the repo's HitPrediction.luau is built on this).
- Avatar Joint Upgrade (R15): AnimationConstraint replaces Motor6D (C0/C1 read-only aliases, IsA("Motor6D") false, Transform identical). R6 is not named; keep joint lookups tolerant. Replicate procedural poses through attributes or UnreliableRemoteEvent, never C0 on the server.
- Server Authority mode (AuthorityMode = Server, beta) needs NextGenerationReplication, the Input Action System, deferred signals, fixed simulation, StreamingEnabled; one bug report says writing Transform in PreSimulation broke under it; no built-in hitscan rewind. Not for this feature. https://create.roblox.com/docs/projects/server-authority ; https://devforum.roblox.com/t/critical-bug-animation-overriding-motor6dtransform/3630180
- IKControl is meant for third-person aiming, but R6 has no elbows: of little use for arms. https://create.roblox.com/docs/reference/engine/classes/IKControl
- RemoteEvent and UnreliableRemoteEvent: ~500 requests/s per client, shared per type. An LMG at 750–850 RPM is ~14 shots/s: fine. Batch shotgun pellets into one event. Unreliable (unordered, may drop) suits cosmetic shot relays and a 10–20 Hz aim stream; damage requests go reliable. https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent
- Workspace:GetServerTimeNow() is a smoothed, monotonic server clock on the client (within 0.6 % of local rate); Player:GetNetworkPing() is the isolated round trip. A forum claim that it is a precise synced clock is unverified. https://create.roblox.com/docs/reference/engine/classes/Workspace ; https://create.roblox.com/docs/reference/engine/classes/Player
- Security: "What happens if this feature is used 1,000+ times per second?" Exploiters fire remotes at any rate with any arguments and own their character's physics. https://create.roblox.com/docs/scripting/security/security-tactics

**Shot validation consensus ("shooter-first")** [S] https://devforum.roblox.com/t/making-secure-client-sided-raycasts/1044812 ; https://devforum.roblox.com/t/raycasting-sanity-server-checks-for-ranged-weapons/820131 ; https://devforum.roblox.com/t/gun-system-methods-of-server-checking-raycasts-for-damage/1455695 ; https://devforum.roblox.com/t/serverclient-raycast-lag-compensation/3404150 ; https://devforum.roblox.com/t/lag-compensation-with-hitscan-revisited/763848 ; https://devforum.roblox.com/t/on-the-matter-of-lag-compensation-raycasting/538725
- The client raycasts and shows everything at once, then sends one remote. The server checks: weapon equipped, server ammo > 0, fire-rate cooldown (a token bucket tolerates jitter), origin within N studs of the server head/root, direction within an angle tolerance of the recomputed spread (shared seed), a re-raycast for walls, the target near where the server saw it (a few studs; 3 is common). Then damage, then a cosmetic broadcast to the others.
- Rewinding: keep a ring buffer of root CFrames per player (~1 s; Valve keeps 1 s), validate at the shot time, cap the rewind, drop stale shots. In one test 6 of 50 jump shots missed by more than 1 stud while 50/50 horizontal ones matched: give vertical motion more tolerance.
- Hitscan vs projectile: FastCast-style per-frame segments only when drop and travel time matter. https://devforum.roblox.com/t/making-a-combat-game-with-ranged-weapons-fastcast-may-be-the-module-for-you/133474

**Effects** [S] https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter ; https://devforum.roblox.com/t/particles%E2%80%99-flipbook-release/2029388 ; https://create.roblox.com/docs/reference/engine/classes/Beam ; https://create.roblox.com/docs/reference/engine/classes/Sound ; https://create.roblox.com/docs/reference/engine/classes/AudioEmitter
- Muzzle flash: a ParticleEmitter (Enabled false, `:Emit(n)`), flipbook (Enum.ParticleFlipbookLayout Grid2x2/4x4/8x8, OneShot; square power-of-two 8–1024 px texture), LockedToPart, LightEmission ~1, LightInfluence 0; a PointLight (range ~8–14, warm) on for ONE rendered frame.
- Tracers: client-only; a Beam between attachments or a thin moving part; they vanish past ~50 studs if too thin: scale width with distance. https://devforum.roblox.com/t/bullet-tracers-lack-visibility/2995887
- Sound: near / mid / far layers played together (RollOffMax ~50–100, ~500, 1000+ studs), the far one darkened by EQ; delay distant reports by distance ÷ speed of sound; ±3–5 % pitch per shot; an Echo effect stops with its Sound, so let tails finish. New Audio API: AudioPlayer → AudioEmitter (custom distance curve) → AudioListener. https://devforum.roblox.com/t/how-to-make-a-good-distant-gun-shot-sound-effect/1639337

**Camera, ADS, input** [S]
- Over-the-shoulder: Humanoid.CameraOffset or a step bound at RenderPriority.Camera + 1; raycast the camera against walls yourself. https://devforum.roblox.com/t/3rd-person-over-the-shoulder-camera/3222599
- FieldOfView 1–120 (default 70); ~55–60 for irons/red dot, ~8–20 for a scope with an overlay; scale mouse sensitivity with tan(fov/2) (UserInputService.MouseDeltaSensitivity); slow the walk while aiming. https://create.roblox.com/docs/reference/engine/classes/Camera

**Roblox rules** [S] https://create.roblox.com/docs/production/promotion/content-maturity ; https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Rules-of-Conduct
- Realistic modern firearms are allowed as in-experience items (not UGC accessories). Real-world weapon-making instructions or schematics are prohibited: our models are visual only, no internal mechanisms beyond what moves on screen.
- Graphic realistic violence with dismemberment and organs is "Restricted" (18+ ID-verified); "extreme gore", torture and war crimes are prohibited even then; uploaded assets are moderated separately. Guns in a shooter need no "sensitive issue" disclosure.
- No manufacturer logos or trademark names on models; generic serial-style stamps only.

## 14. Minimum clip set and events [E]

Per weapon: idle / active idle in low ready, high ready, shouldered; shouldered ↔ ADS; sprint carry + sprint in / out; draw, holster; tactical reload, empty reload, the chamber / bolt / pump beat (own clip or event); fire additive (hip and ADS); obstructed high / low; inspect (optional).
Weapon-specific: shotgun shell start / loop / end + port load; sniper bolt cycle (hip and scoped), bipod deploy / fold; LMG belt reload, bipod deploy / fold, braced idle.
Events: `mag_release`, `mag_drop`, `mag_grab`, `mag_insert` (snap), `bolt_back`, `case_eject`, `bolt_forward` (snap), `round_count_commit`, a `cancel_ok` window, sound cues.

---

## Principles we keep

1. **Six layers, fixed order, every armed character:** (1) ALS locomotion (legs, root bob), (2) the weapon's stance pose for the upper body, (3) action clips (reload, draw...), (4) aim offset (pitch spread over Root / gun / Neck), (5) additive springs and recoil, (6) arm solve to the gun's grip markers, then a per-joint rate limit. Recoil is applied before the arm solve.
2. **One owner per transform.** The gun's pose has exactly one owner at a time (Torso-space gun pose, or a hand during draw / holster / hand-carry); the arms are DERIVED from it by solving to `GripR` / `GripL`. Owner switches are inertialized, never popped.
3. **Rate limit:** no joint and no gun pose may rotate more than **20° per frame at 60 fps (1200°/s)**, except flagged snaps: the shot's recoil impulse frame, a mag seat slap, a bolt / slide / charging-handle slam, a feed-cover slap. Every clip and the runtime layer are checked for it (Python `--check`, Lune sim).
4. **Springs, not lerps, for everything procedural;** stance changes of known duration are timed Hermite blends that start from the current pose AND speed (inertialized). Starting spring values: look lag 7 Hz pistol / 5 Hz rifle-shotgun / 3 Hz sniper-LMG, ζ 0.6, max 6°; recoil ζ 0.5–0.7; skip springs when dt > 0.1 s; zero the look speed on the first frame.
5. **Mass and length drive the numbers.** Spring frequency ∝ 1/√(mass), ADS time, sprint-to-fire, reload stiffness and sway scale with weight: pistol 0.85 kg, shotgun 3.5 kg, rifle 3.9 kg, sniper 7.5 kg, LMG 10 kg loaded. ADS 0.18 / 0.30 / 0.25 / 0.40 / 0.45 s; sprint-to-fire 0.15 / 0.28 / 0.25 / 0.42 / 0.45 s.
6. **R6 arms are rigid (1.505 studs from the shoulder pivot to the hand point).** Two-handed holds are SOLVED offline (gun placement + torso blade + shoulders) per weapon, stance and aim pitch, and checked: right-hand residual ≤ 0.05 stud, left ≤ 0.10 stud, stock butt ≤ 0.15 stud from the shoulder pocket, no gun through the torso or head. Never hand-tuned by eye alone.
7. **Recoil = gameplay path + body absorption + cosmetic camera, three separate things.** Gameplay climb moves the aim and recovers 60–80 % after the burst; the body takes the visual kick (gun pitch/push, torso rock, head one frame late); the camera only gets a small decaying shake (≤ 1.5° FOV punch, ≤ 0.08 stud jitter, 0.15 s). First shot of a burst 1.5–3× the later ones; roll alternates sign. Smoke and flash never hide the target.
8. **Weapon positions from Ground Branch:** low ready (default off-target), high ready, ready (shouldered), ADS, sprint carry, obstructed high/low (automatic). Firing from low ready costs a raise (0.15–0.25 s); obstructed blocks fire until 0.15 s after clearing.
9. **Wall collision:** cast from the shoulder pocket along the barrel for its length + 0.15 m; 0–40 % penetration slides the gun back (≤ 0.17 m / 0.6 stud); over 45 % (back under 35 %) it goes to obstructed high (aim pitch > −10°) or low in 0.2 s.
10. **Reloads are state machines with events from the clip, never fixed timers:** ammo commits at `mag_insert` (or each shell's push), cancels before it change nothing, shell loops cancel after each shell. Timings: pistol 1.6 / 2.0 s, AK 2.6 / 3.2 s, shotgun 0.5 s per shell (+0.4 start, 0.35 end, +0.9 port load), sniper 3.3 / 3.9 s + bolt 1.0 s, LMG 7.0 s.
11. **Reload craft:** anticipation (gun dips and cants 15–35°, pulls in 10–20 cm, head looks at the well, support hand first), overlap (gun lags the hand by 2–4 frames), a snap on seating (gun bumps 2–4° / 1–2 cm, settles in 150–250 ms with one overshoot), counter-motion on chambering (1–3 cm toward the pulling hand), spring follow-through (200–350 ms), head back on target last. The left-hand IK weight is a curve, 0 while fetching, 1 when gripping.
12. **Casings are real-data driven, client-only, pooled, kinematic:** launched in the gun's own axes with the shooter's velocity added, AK 5–7 m/s right-forward (1–2 o'clock, +10–20°), pistol 2.5–4 m/s right-rear (+30–45°, 10 % up-back), shotgun hull 1.5–3 m/s, sniper 1–2.5 m/s on the bolt pull, LMG cases down 1–2 m/s + links right; ±12° and ±15 % per shot; 15–40 rev/s tumble; restitution 0.25–0.5 with 25 % horizontal loss per bounce; at our scale gravity 35 studs/s²; they stay 45 s, max 150 per client (oldest recycled), sink to fade; tinks per surface on real contacts only.
13. **Magazines drop as real objects:** the mag part is hidden on `mag_drop` and a pooled copy falls from its exact pose with the hand's velocity (AK +3–6 rad/s forward tumble), correct gravity, per-material restitution (polymer 0.25, steel 0.15, cloth 0), stays 90 s, max 20 per client. Pouches thud and do not bounce.
14. **Server-authoritative, shooter-first netcode:** the client predicts the shot and its effects; the server validates weapon, ammo, rate (token bucket at the def's RPM, 20 % jitter slack), origin near the server head (and line of sight head → muzzle), direction within tolerance of the seed-recomputed spread, wall re-raycast, target against the rewound body (existing Combat/Rewind, capped 0.35 s); damage goes through the existing Combat hit path. Others get an unreliable cosmetic relay; aim streams at 15 Hz and is interpolated.
15. **Hit zones match what the server can see:** rest-pose R6 boxes (the HitPrediction approach), zones Head / Torso / Arms / Legs; the shooter's client uses the same shared box maths so it predicts the same zone.
16. **Hitscan for all five guns at city ranges;** a 900 m/s bullet drops 0.15 stud over 300 studs, so projectiles buy nothing until maps exceed ~600 studs (keep the projectile path as an option for the sniper only).
17. **Effects grammar from docs/references:** flash pops in 0–1 frame with a 1-frame light, blood ~2 frames after impact, impacts leave marks that stay, no hit markers or damage numbers; smoke builds over long bursts but never covers the sight line.
18. **Sound in layers:** mechanism, near body, mid, far (low-passed, delayed by distance ÷ 1225 studs/s), environment tail, supersonic crack near the bullet path; every reload event has its own mechanical sound; casing tinks behind the shots.
19. **No viewmodel.** One world model per character, animated identically on every client from replicated state; first-person mode puts the camera at the eye / optic.
20. **Few weapons, each complete:** every gun ships with its full clip set (§14), its moving parts, casings, mag/pouch drop, sounds and checks, before the next one starts.
21. **Original models:** credible real-world proportions in metres, no brand logos, trademark names or copied markings; generic serial-style stamps only; nothing that works as a build schematic.
