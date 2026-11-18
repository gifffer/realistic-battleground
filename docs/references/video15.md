# Reference video 15

Analysed frame by frame at 15 fps. Contact sheets: `docs/references/video15_*.jpg`.

VIDEO 15 (TikTok ssstik 1794989827959): WALK CYCLE REFERENCE FOR R6

I read all 17 contact sheets (0 to 49.8 s). For the cycle itself I studied the big frames in four places: 334-357 (in game, "if you move slow"), 400-415 (in game, "FORWARD"), 586-601 (in game, "FORWARD" again) and 612-631 (the Blender rig, front view). My montages are in (local)  (fwd1.png, fwd2.png, slow.png, blfront.png, intro.png, s13.png).

1. WHAT THE VIDEO SHOWS
It is a dev showcase, "I just made a better movement system than 90% of Roblox games". The character is a classic R6 noob (blue shirt, white spiky hair, black blindfold). Almost all walk footage is shot from the FRONT or front three-quarters, with the character walking toward the camera. There is NO clean side view.
- 0.00-1.47 s: a wide-stance cycle seen from a low front three-quarter view. The legs are spread about 30° outward (abduction) and the arms flap across the body. It looks like the sideways/strafe clip or a hype intro, not the plain forward walk.
- 1.5-3.0 s: another game (football) for comparison. 3.0-4.0 s: close-up of the idle. 4.0-5.9 s: Studio Explorer showing a custom "Animate" script and a LocalScript.
- 6.0-8.9 s: other battleground games ("movement seems very linear").
- 9.0-11.3 s: idle close-ups (tiny breathing).
- 11.4-13.0 s: a run/sprint in another game.
- 13.1-14.4 s: the custom cycle in 3/4 view, ending in a stop (stands neutral at 14.1).
- 14.5-16.6 s: displacement formula slides. 16.8-18.8 s: output logs printing displacement per frame.
- 18.9-21.6 s: a test against another character.
- 21.7-24.3 s: "if you move slow your animation plays slow". The same forward cycle at reduced playback rate.
- 24.4-25.2 s: BACKWARD clip. Legs kick back, arms held out at about 45°.
- 25.27-26.7 s: SIDEWAYS clip. Legs kick out sideways a lot, a strong crossover-hop look.
- 26.73-27.6 s and 39.2-40.0 s: FORWARD clip in game. This is the walk to copy.
- 28.9-32.6 s: ragdoll/fling test. 32.8-36.1 s: code (ROOT_TILT, DIR_ANIM, SPEED_DRIVER, Anim:SetRate(clamp(disp/cap, MIN_RATE, MAX_RATE)), Forward/Back/Left/Right/Crawl chooser), then a meme.
- 40.87-42.0 s: the Blender rig (front view, "FRONT" labels) playing the forward clip. The timeline moves 4 Blender frames per video frame, so the scene runs at 60 fps in real time.
- 42.1-43.7 s: the rig from behind playing the sideways clip.
- 43.9-45.3 s: sideways/forward in game again. 45.4-49.8 s: outro, idle.

The system around the walk:
- Separate Forward, Backward and Sideways (left/right) clips, picked from the move direction relative to the root.
- The playback rate scales with real displacement speed, clamped.
- The root tilts toward the move direction, up to a set maximum number of degrees.

2. THE FORWARD WALK CYCLE (measured)
Cycle length: the same arm crosses the chest at frames 402→410, 592→600 and 614→621/622. That is 8 video frames at 15 fps, so **0.53 s per full cycle (two steps)**. The Blender timeline gives 28 frames at 60 fps = 0.47 s. Recommended: **0.53 s at normal WalkSpeed (16)**, playback rate scaled by speed (about 0.5x to 1.2x).

The cycle is quick and bouncy, a "power-march". What matters:
- **Very high leg lift.** At its peak the forward leg is seen end-on (foreshortened to about 55% of its length), so the hip swings about +55° to +60° forward. The thigh is held up, not swung like a pendulum. The support leg stays near vertical, then 15-20° back.
- **The arm extreme happens at the leg's highest point, not at foot contact.** At contact both arms pass near neutral (frames 594/598).
- **Contralateral and crossing.** The forward arm swings about 60-70° forward AND about 30-40° inward, so the hand ends in front of the opposite side of the chest. At 402/403 and 592 the arm block lies diagonally across the shirt. The back arm goes about -35° back and flares out about 20° (it shows as a short block sticking out sideways, as at 404 and 408).
- **The torso twists hard toward the forward arm**, about ±14° yaw (the side of the shirt shows). It also rolls slightly over the stance leg (±4°) and leans forward about 5°.
- **Bob:** two per cycle. Lowest just after contact (about -0.2 stud), highest at the high-knee/passing pose (about +0.1 stud).
- **Head:** counter-yaws about half of the torso twist so the face stays toward the move direction, plus a small nod (about 3°) at the low point.
- **R6 limits:** the original is R6 too, with straight blocks and no knees or elbows. The "knee" look comes only from the large hip pitch plus foreshortening. To fake a bent elbow, combine shoulder X with Z inward and add a little Y twist.

Phases, 8 frames, starting at right-foot contact:
- f0 R contact (arms neutral)
- f1 down/recoil (lowest point)
- f2 passing/high: L knee peak, R arm across chest
- f3 descent
- f4 L contact
- f5-f7 mirror f1-f3

3. STYLE (what makes it look this way)
- Marching high knees.
- Swaggering cross-body arm punches, "pumping" more than a natural swing.
- Big shoulder/torso twist and a clear double bob. Snappy timing: about 1 frame of ease at the extremes, fast through the middle.
- The feet do not drag. The leg comes down almost vertical.
- Liveliness comes from scaling the rate with speed and from the root tilt (lean into acceleration and turns), more than from the clip itself.
- For our realistic, gritty game: keep the timing, twist and contralateral cross. Tone the cartoon down: hip lift about 40-45° instead of 60°, arm cross about 20° inward instead of 35°.

4. KEYFRAME TABLE (one cycle = 0.533 s, loop; t = 0 at right-foot contact)

Sign conventions:
- Hip X+ = thigh swings FORWARD. Shoulder X+ = arm swings FORWARD.
- Shoulder Z+ = arm moves INWARD across the chest; Z- = flares outward.
- Hip Z+ = leg moves outward (abduction).
- Torso X+ = lean forward. Torso Y+ = yaw so the RIGHT shoulder comes forward. Torso Z+ = roll so the right shoulder drops.
- Root posY in studs, relative to rest. Neck X+ = nod down; Neck Y uses the same sign as torso Y.
- Values are relative to the R6 rest pose (convert to the Motor6D axes in code).

| t (s) | Root/Torso rot X,Y,Z | Root posY | Neck X,Y | RShoulder X,Z | LShoulder X,Z | RHip X,Z | LHip X,Z |
|---|---|---|---|---|---|---|---|
| 0.000 (R contact) | 5, 0, 0 | -0.10 | 0, 0 | 5, 0 | -5, 0 | 22, 0 | -15, 0 |
| 0.067 (down) | 6, 6, 2 | -0.20 | 3, -3 | 30, 15 | -20, -10 | 8, 0 | 15, 0 |
| 0.133 (passing/high, L knee peak) | 5, 14, 4 | +0.10 | 0, -7 | 65, 35 | -35, -20 | -12, 0 | 58, 3 |
| 0.200 (descent) | 5, 8, 2 | +0.05 | 0, -4 | 40, 20 | -25, -12 | -18, 0 | 38, 0 |
| 0.267 (L contact) | 5, 0, 0 | -0.10 | 0, 0 | -5, 0 | 5, 0 | -15, 0 | 22, 0 |
| 0.333 (down) | 6, -6, -2 | -0.20 | 3, 3 | -20, -10 | 30, 15 | 15, 0 | 8, 0 |
| 0.400 (passing/high, R knee peak) | 5, -14, -4 | +0.10 | 0, 7 | -35, -20 | 65, 35 | 58, 3 | -12, 0 |
| 0.467 (descent) | 5, -8, -2 | +0.05 | 0, 4 | -25, -12 | 40, 20 | 38, 0 | -18, 0 |
| 0.533 | = t 0 (loop) | | | | | | |

Shoulder Y twist: add about 10° of twist (forward arm's palm turning inward) at the arm peaks to sell the "bent elbow". It is 0 elsewhere.

Easing:
- Cubic in/out into the peaks at 0.133 and 0.400.
- Linear-ish through contact.
- Root posY: sine-like, with its minima at 0.067 and 0.333.

Realistic variant: scale hip peaks by 0.75, shoulder Z by 0.6 and torso yaw by 0.8.

Accuracy: all angles are estimated from front views by foreshortening (forward hip and shoulder about ±10°). Twist, sideways and timing are reliable to about ±1 frame (±0.067 s).