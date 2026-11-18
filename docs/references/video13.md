# Reference video 13

Analysed frame by frame at 15 fps.

VIDEO 13 - "How to Create a Realistic Rain Ripple Effect in Blender" (125 s, source 640x338, about 30 fps)

I read all 63 contact sheets (0-125 s). The subtitles were burnt in, so I read them from a 1 fps subtitle strip. I read the property values from crops of the Properties panel, upscaled 3x from the video stream. Where a value could not be read I say so.

=== TECHNIQUE SUMMARY (in the video's order, with every value I could read) ===

The idea: two planes. The upper plane emits small falling particles (the rain). The lower plane is a Dynamic Paint Canvas with surface type Waves, and the particles are its Brush, so each drop that reaches the water starts a ring wave that spreads out. The ripple is a real vertex displacement, so the plane needs dense geometry. No shader or nodes are used. The video stays in the Solid viewport and never shows a final render, material or lighting.

1. 0-15 s: Delete the default cube. Add a Plane. This first plane, "Plane", becomes the water.
2. 16-29 s: Duplicate the plane and move the copy straight up along Z, by roughly 2-3 plane widths judging by the viewport. The copy, "Plane.001", is the rain emitter. "Plane" stays at the origin as the water surface.
3. 30-43 s: Select the upper plane and add a new Particle System (Emitter type).
   - Number = 1000. The voice says "increase the number of particles". The panel shows 1000, which is also the default.
   - Seed = 0. Frame Start = 1.000. End = 200.000.
   - Lifetime = 50.000, kept long enough "so the rain continues throughout the animation". Lifetime Randomness = 0.000.
   - Velocity was not changed, so drops fall under scene gravity only (Normal velocity is left at the default).
4. 44-60 s: Add an Icosphere and scale it down. This is the raindrop instance. It is moved aside along Z ("control G and z").
5. 61-73 s: In the particle Render panel:
   - Render As = Object, Instance Object = Icosphere.
   - Scale = 0.050.
   - Scale Randomness = 0.8 (subtitle: "random value 0.8"; the field is being typed at 72-74 s).
   - Show Emitter = on.
6. 74-90 s: With the upper plane still selected, open Physics and add Dynamic Paint, Type = Brush.
   - Paint Color = blue, Alpha = 1.00, Wetness = 1.00, Absolute Alpha = on, Erase Paint = off.
   - Source: Paint = "Particle System" (the subtitle calls it "change the type mesh volume to particle system"). Particle Systems = ParticleSystem.
   - Effect Solid Radius = 0.200, Use Particle's Radius = off, Smooth Radius = 0.200.
   - Velocity / Waves sub-panels: left at defaults (Wave Type Drop, Factor 1.0).
7. 91-96 s: Select the lower plane. In Edit Mode, Subdivide "to give it enough geometry for the displacement".
   - Number of Cuts is dragged to near the slider's maximum. The digits are cut off in the crop; it is probably about 50-100.
   - Smoothness = 0.000, Create N-Gons = on, Quad Corner = Straight Cut, Fractal = 0, Along Normal = 0, Seed = 0.
8. 97-110 s: On the lower plane, add Physics, Dynamic Paint, Type = Canvas, then Add Canvas. On the surface:
   - Format = Vertex, Anti-Aliasing = off.
   - Frame Start = 1, End = 250, Sub-Steps = 0.
   - Surface Type changed from Paint to Waves (the dropdown also lists Displace and Weight).
   - Waves settings: Open Borders = off, Timescale = 1.00, Speed = 1.00, Damping = 0.04, Spring = 0.20. Smoothness is just below, at the default 1.00.
   - Brush Collection: all. Output: the canvas deforms the mesh directly.
9. 111-116 s: Scrub or play the timeline. The water plane fills with interfering ripple dimples. Then Object > Shade Smooth (the "Keep Sharp Edges" redo option shows). The faceted look becomes a smooth, liquid surface.
10. 116-125 s: Play the animation. Icosphere drops fall from the emitter and every impact starts a ring that spreads and fades (damping 0.04). The canvas cache is re-baked once Shade Smooth and the brush settings are in place.

Reproducing it in bpy (headless):
- Water and emitter planes:
  - `bpy.ops.mesh.primitive_plane_add(size=2)` for the water, then subdivide by `bmesh.ops.subdivide_edges(cuts=100, use_grid_fill=True)`, or add a Subdivision modifier (simple, level 6) placed BEFORE Dynamic Paint in the stack.
  - Copy it for the emitter at z=+3.
- Particles:
  - `ps = emitter.modifiers.new("Rain", 'PARTICLE_SYSTEM').particle_system.settings`
  - `ps.count=1000; ps.frame_start=1; ps.frame_end=200; ps.lifetime=50; ps.normal_factor=0`
  - `ps.render_type='OBJECT'; ps.instance_object=ico; ps.particle_size=0.05; ps.size_random=0.8`
- Brush (on the emitter):
  - `m = emitter.modifiers.new("DP", 'DYNAMIC_PAINT'); m.ui_type='BRUSH'; bpy.ops.dpaint.type_toggle(type='BRUSH')` (needs a context override in headless, or set `m.brush_settings` after toggling).
  - `b = m.brush_settings; b.paint_source='PARTICLE_SYSTEM'; b.particle_system=emitter.particle_systems[0]; b.solid_radius=0.2; b.smooth_radius=0.2; b.wave_type='DROP'; b.wave_factor=1.0`
- Canvas (on the water):
  - `bpy.ops.dpaint.type_toggle(type='CANVAS')`
  - `s = water.modifiers["DP"].canvas_settings.canvas_surfaces[0]; s.surface_format='VERTEX'; s.surface_type='WAVE'; s.frame_start=1; s.frame_end=250; s.wave_timescale=1.0; s.wave_speed=1.0; s.wave_damping=0.04; s.wave_spring=0.20; s.wave_smoothness=1.0; s.use_wave_open_borders=False`
- Finish:
  - `bpy.ops.object.shade_smooth()`
  - Bake by stepping `scene.frame_set(f)` from 1 to 250 in order. Dynamic Paint only evaluates frame by frame.

Note: Dynamic Paint waves need about 150x150 vertices or more to give clean rings. For crisper rings, raise the cuts or the substeps.

=== HOW TO TRANSFER THIS TO OUR GAME ===

Roblox cannot run Dynamic Paint, deform a mesh per vertex in real time cheaply, or use custom shaders. We keep the simulation offline in Blender and ship the result as textures plus particle and decal timing. The look must stay realistic: dark, wet, nearly black-red blood with a thin specular rim, not a cartoon water ring.

A. Ripple-ring flipbook (main deliverable): `tools/wounds/` gets a ripple-build script, for example `build_ripple_flipbook.py`.
   - Scene: one 2x2 m canvas, subdivided to 200x200 or more, Waves surface (damping about 0.06-0.10 for blood: it is thicker than water, so rings should die faster; Spring 0.2, Speed 0.8).
   - Drop ONE brush (a single particle or an animated empty-sphere brush, Solid Radius 0.05-0.1) at the centre on frame 1. Simulate 24-32 frames.
   - Render top-down with an orthographic camera, Cycles. Blood material: base colour about (0.08, 0.005, 0.005), roughness 0.08, a little clearcoat. Light it with one soft-box plus an HDRI so the ring crests catch highlights.
   - Better: render two passes per frame, and use the pass that fits the use below.
     (1) Lit colour with alpha. Alpha comes from the slope (normal z), so flat areas are transparent and only the crests show.
     (2) A greyscale height or normal map.
   - Pack 16 or 25 frames into a 4x4 or 5x5 atlas, 1024 px, as PNG.
   - Roblox use: a ParticleEmitter with FlipbookLayout=Grid4x4 (or 8x8), FlipbookMode=OneShot, Orientation=VelocityPerpendicular (or a flat emitter Attachment pointing up), Speed=0, Rate=0, `:Emit(1)` per drop. Size curve 0.3 to 1.2 studs. Transparency curve 0.2 to 1. LightEmission 0, LightInfluence 1, so it takes the map's lighting.

B. Where it plays in our game:
   - Blood pools (finishers, arterial spray, decapitation):
     - When a blood droplet particle or drip lands on an existing pool, Emit one ripple ring at the hit point.
     - The client raycasts each simulated droplet; on a hit inside the pool's bounds, Emit, otherwise spawn a splat decal.
     - This matches our persistence rule: the pool stays and the rings are short-lived on top of it.
   - Dripping wounds and severed stumps held above the ground: a steady drip makes a ring every 0.4-0.8 s.
   - Rain or wet maps, if we ever add them: the same atlas, emitted randomly over puddle parts.

C. Pool surface "breathing" or settling:
   - Render an offline Waves sim with many random drops into a seamless loop (open borders off, same seed). Turn it into a normal or height flipbook.
   - Show it on a SurfaceAppearance pool mesh by swapping the NormalMap texture every 0.1 s, or with an animated Decal/Texture (`OffsetStudsU`/`V` on a pre-packed strip).
   - Use this sparingly: texture swaps are client-side only.

D. Optional: real geometric ripples on the pool for finisher cinematics only.
   - Bake the Dynamic Paint wave as a shape-key or bone animation.
   - Simplest: export the canvas as an EditableMesh-free FBX with about 20 bone rings, and drive the bones from the baked vertex heights.
   - Import it as a MeshPart and play it on the close-up camera shot. It costs too much for general gameplay, but it is fine for a two-second hero shot.

E. Timing, from the video's look:
   - The ring appears on the impact frame, with no delay.
   - The first crest is sharp. It spreads to its full radius in about 0.5 s, and a second, weaker ring follows behind it.
   - It fades out by about 0.8-1.0 s with damping like the video's (0.04). For blood, use about 0.06 so it dies sooner.
   - Add a tiny crown splash (2-4 droplet particles, upward speed 3-6 studs/s, gravity) on the same frame for heavy drops.

Files used:
- (local frames, not in the repo) v13_sheet00.png .. v13_sheet62.png
- (local) v13/subs_0.png
- (local) v13/subs_1.png
- (local) v13/panels_0.png
- (local) v13/panels_1.png
- (local) v13/q/all.png