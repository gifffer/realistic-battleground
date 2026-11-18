--!strict
-- Vfx: the combat VFX library (client only). Every fight effect you SEE —
-- the contact flash, sparks, air rings, dust, trails, hit-stop, the camera
-- push-in — is built here from a few shared pieces, so every move speaks
-- the same visual language (docs/references/README.md: realistic light,
-- moisture, air and dust; pop, don't grow; the last hit looks different).
-- Sounds are NOT here (SoundController). Blood is NOT here (Combat/Blood*).
--
-- ── Files ──────────────────────────────────────────────────────────────
--   Types     the shared types (+ an example spec at the top)
--   Palette   colours and textures            Tiers    how hard each hit looks
--   Quality   graphics level, culling, caps   Pool     pooled emitters / lights / beams + the frame scheduler
--   Floor     what's under a point            Layers   the primitives (flash, sparks, ring, dust...)
--   Limb      trails, smears, afterimages, speed lines
--   Camera    shake, kick, FOV punch, dim, impact frames (the ONE owner of camera offsets)
--   Impact    whole stacks: hit, groundSlam, knockoutOverlay, awakening, landing
--   HitFx     the dispatcher: combat events / actions → specs → layers
--   Moves/*   one spec file per kit: what each move looks like (data)
--
-- ── API (all functions never yield; they do nothing when culled) ───────
-- Layers (Vfx.Layers):
--   contactFlash(point, size, { color?, frames?, spikes?, dir? }?)
--   light(point, brightness, range, { color?, holdFrames?, fade? }?)
--   sparkBurst(point, dir, { count, speed?, spread?, palette? "Body"|"Warm"|"Glass"|"Rift", life?, heavy? })
--   streaks(point, dir, count, length, { width?, frames?, backAlong? }?)
--   pressureLines(point, dir, radius)
--   shockRing(point, facing, { from, to, life, delayFrames?, alpha?, color? })
--   specks(point, dir, count, { color?, delayFrames? }?)
--   puff(point, dir, size, count, { color?, delayFrames?, life? }?)
--   dustRing(floorPoint, { puffs, speed, size?, color?, groundRing?, dir? })
--   chips(point, count, color)
--   debris(floorPoint, count, { size?, up?, out?, stay? }?)
--   crack(point, normal, size, stay?)
--   breath(model, { size?, count? }?)
-- Limb (Vfx.Limb):
--   part(model, limb) → BasePart?          tip(model, limb) → Vector3?
--   trailOn(model, limb, { life?, arc?, width? }?)   trailOff(model, limb)
--   trailWindow(model, limb, fromNow, toNow, opts?)
--   smear(model, limb, { ghosts?, frames? }?)   (needs track(model, true) first)
--   afterimage(model, { count?, fade?, spacing? }?)
--   speedLines(model, seconds, { dir?, rate? }?)   scrape(model, seconds)
--   glint(model, limb)                     track(model, on)
-- Camera (Vfx.Camera):
--   trauma(amount, at?, radius?)   kick(worldDir, degrees)   fovPunch(degrees)
--   setBaseFov(fov, tweenTime)     dim(amount, { edge?, recover?, preFrames? }?)
--   impactFrame("KO" | "White")    desaturate(amount, hold, recover)
--   drain(amount, recover)         involves(...models) → 1 / 0.4 / 0
-- Impact (Vfx.Impact):
--   hit(ImpactArgs)   groundSlam(point, tier, { attacker?, victim?, debris?, crack?, camera?, scale? }?)
--   knockoutOverlay(ImpactArgs)    awakening(model, "Street"|"Boxer"|"Bouncer", beat?)
--   landing(victim, strength)      contactPoint(victim, attacker, limb?, zone?) → (point, dir)
--   hitstop(attacker?, victim?, seconds, dir?, jitter?)
-- HitFx (wired by CombatEffectsController / CharacterAnimationController):
--   onAction(model, clip)   onPredictedHit(victim, attacker, combo, zone, side)
--   onCombatEvent(kind, victim, attacker, zone, side, moveId?, alreadyShown, blood)
--   stop(model)   watch(model)   bloodDelay(predictedAt?)   tierFor(kind, attacker, moveId?)
-- Pool: afterFrames(n, fn)  after(seconds, fn)  step(fn(dt) → keep?)  token(model)  bump(model)
--
-- ── How to give a move its VFX (beginner guide) ────────────────────────
-- 1. Open the spec file of its kit, e.g. Vfx/Moves/Boxer.luau.
-- 2. The SWING (while the animation plays): add a clip spec named like the
--    animation clip (CombatClips). Each beat = one blow: its contact time
--    in the clip (`at`, = the Kits hit's `at`) and the striking limb. The
--    limb's air trail runs from `at - swing` to `at + after`.
--        Boxer_Uppercut = { beats = { { at = 0.25, limb = "RightArm", arc = true,
--                                       smear = true, preDim = true } } },
-- 3. The CONTACT (when the server says it landed): add a move spec named
--    like the server's moveId (Shared/Kits ids). Pick a tier (Vfx/Tiers);
--    one per hit for multi-hit moves.
--        Uppercut = { tier = "Heavy", limb = "RightArm", ringFacing = "Up" },
--        JabRush  = { tiers = { "Light", "Light", "Light", "Clean" }, limb = "LeftArm" },
-- 4. Something special on top? `onHit = function(ctx) ... end` gets the
--    HitContext (point, dir, victim, attacker, index...): call Layers /
--    Limb / Impact from there. `run = function(ctx) ... end` on a clip spec
--    does the same for the swing (use ctx.later(seconds, fn): it skips the
--    rest if the move was cut short).
-- 5. Keep it coherent: one tier per hit, nothing extra on misses or
--    blocked hits beyond the swing trail and the Blocked spark.
--
-- Rules: never require Vfx (this file) or Vfx/HitFx from a spec file (they
-- require the specs: a loop). Never `task.wait` for frame timing: use
-- Pool.afterFrames / Pool.after / ctx.later.

local Camera = require(script.Camera)
local Floor = require(script.Floor)
local HitFx = require(script.HitFx)
local Impact = require(script.Impact)
local Layers = require(script.Layers)
local Limb = require(script.Limb)
local Palette = require(script.Palette)
local Pool = require(script.Pool)
local Quality = require(script.Quality)
local Tiers = require(script.Tiers)

local Vfx = {
	Camera = Camera,
	Floor = Floor,
	HitFx = HitFx,
	Impact = Impact,
	Layers = Layers,
	Limb = Limb,
	Palette = Palette,
	Pool = Pool,
	Quality = Quality,
	Tiers = Tiers,
}

local started = false

-- Builds the pools, the camera layer, and starts the frame scheduler.
-- (CombatEffectsController.start calls it once.)
function Vfx.start()
	if started then
		return
	end
	started = true
	Quality.start()
	Pool.start()
	Camera.start()
end

return Vfx
