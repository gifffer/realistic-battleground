# Reference video 14

Analysed frame by frame at 15 fps.

VIDEO 14: "Want to create a realistic glass effect in Blender" (48.7 s, no voiceover, source is only 640x338)

I read all 25 contact sheets (v14_sheet00 to v14_sheet24). The source is low resolution, so I re-extracted key frames from v14.mp4, upscaled them with lanczos and cropped the Properties panel to read the values. Crops are in (local) v14/ (cmp1.png and cmp2.png show the material and render panels, vp.png shows the viewport stages). The status bar shows Blender 4.5.x.

The tutorial is basic. The "glass" is a thin box with a Principled BSDF set to Transmission 1, Roughness 0 and IOR about 1.4, lit by one Area light in Cycles. Nothing is procedural: no node tree, no textures, no thickness or dispersion tricks. The realism comes from three things: real thickness, Cycles refraction, and a single hard light in a dark world.

TIMELINE (what is on screen)
- 0.0-0.3 s: empty scene. Render properties: Render Engine = Cycles, Feature Set = Supported, Device = GPU Compute. Viewport: Noise Threshold on, 0.1000; Max Samples 1024; Min Samples 0; Denoise off. Render: Noise Threshold on, 0.0100; Max Samples 4096; Min Samples 0; Time Limit 0 s; Denoise on. Light Paths stay at their defaults; nothing is changed there.
- 0.3-2.4 s: Shift+A > Mesh > Plane.
- 4.4-7.3 s: the plane gets solid shading, then is scaled up (about 3-4x) into a floor.
- 7.4-11.2 s: from the Asset Browser shelf (Blender 4.x Essentials-style assets), the user hovers a teal Table, then drags a green plastic "Chair" into the collection onto the plane. The outliner shows "Chair" and "Chair.001" (collection instances).
- 11.2-13.4 s: a sofa asset is browsed but not used.
- 13.5-15.0 s: Shift+A > Mesh > Cube.
- 15.0-18.5 s: the cube sits on the floor (moved up in Z so its base touches the plane) and is scaled.
- 18.5-19.3 s: header reads "Scale ... along global X". The cube is squashed on X into a thin slab, a glass pane about 2 m tall and wide and a few cm thick. The pane stands upright between the camera and the chair. Its edges keep real thickness; this matters later because the refraction at the edges is what reads as glass.
- 19.3-20.0 s: view from the front. The chair sits behind the pane, and "Chair.002" is made into an instance with a real mesh child.
- 20.1-22.1 s: Shift+A > Light > Area.
- 22.1-27.9 s: the Area light is moved (G Z) about 2-3 m above the scene and sits over the pane and chair, pointing straight down. It is later rotated or tilted a little (at 43 s a tilted area-light gizmo is visible above and to the left). The world stays dark grey; there is no HDRI.
- 28.0-29.8 s: Cube selected > Material tab > New. "Material.005" is created with a Principled BSDF.
- 29.9-37.5 s: Principled BSDF settings, readable in the crops:
    Base Color = white (about 1,1,1)
    Metallic = 0.000
    Roughness = dragged to 0.000
    IOR = changed from 1.500 to 1.400 (it reads "1.400"; physically correct soda-lime glass is 1.45-1.52)
    Alpha = 1.000
    Normal = Default
- 37.0-39.9 s: the Transmission subpanel is opened, Weight goes from 0.000 to 1.000.
- Coat, Sheen, Emission, Thin Film, Subsurface, Specular and Volume panels are left at defaults. No Volume Absorption is used, so the glass has no tint.
- 40.0-43.6 s: camera orbit; the floor plane is scaled bigger again.
- 43.6-48.7 s: viewport set to Rendered (Cycles, the header shows "Sample x/1024"). Result:
    - a soft pool of light under the area light, and a dark surround;
    - the green chair seen through the pane, sharply refracted and slightly shifted;
    - the pane edges read as dark, almost black bands, because thick-edge total internal reflection and refraction pick up the dark world;
    - a faint mirror reflection of the floor and the light on the front face;
    - a soft, grey-transparent caustic shadow under the pane rather than a solid black one;
    - small bright specular pinpoints from the light on the glass face.
  The final orbit shows the pane at a 3/4 angle. The near face is a dark mirror with the chair visible through it, and the edges are bright or dark lines.

REPRODUCE IN bpy (headless, matches the video)
```
import bpy
s = bpy.context.scene
s.render.engine = 'CYCLES'; s.cycles.device = 'CPU'   # the video uses GPU; we render on CPU
s.cycles.use_adaptive_sampling = True; s.cycles.adaptive_threshold = 0.01
s.cycles.samples = 512; s.cycles.use_denoising = True  # the video used 4096, 512 + denoise is enough here
# Keep enough transmission and glossy bounces for thick glass:
s.cycles.max_bounces = 12; s.cycles.transmission_bounces = 12; s.cycles.glossy_bounces = 4
# Floor
bpy.ops.mesh.primitive_plane_add(size=8)
# Glass pane: a cube with real thickness
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
pane = bpy.context.object; pane.scale = (0.02, 1, 1)   # about 4 cm thick
bpy.ops.object.transform_apply(scale=True)
bev = pane.modifiers.new("Bevel", 'BEVEL'); bev.width = 0.003; bev.segments = 2  # catches edge highlights
m = bpy.data.materials.new("Glass"); m.use_nodes = True
b = m.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (1, 1, 1, 1)
b.inputs["Metallic"].default_value = 0.0
b.inputs["Roughness"].default_value = 0.0
b.inputs["IOR"].default_value = 1.45            # video: 1.40
b.inputs["Transmission Weight"].default_value = 1.0
pane.data.materials.append(m)
# Subject behind the glass (the video uses an asset chair)
# Light: one Area light about 3 m above, aimed down, slightly tilted
bpy.ops.object.light_add(type='AREA', location=(0.5, 0.5, 3), rotation=(0.2, -0.15, 0))
L = bpy.context.object.data; L.energy = 300; L.size = 1.0
# World: dark grey, about 0.02-0.05 strength (no HDRI in the video)
```
Extras that are not in the video but improve realism and are worth adding:
- a faint green-cyan Volume Absorption (density about 0.5-2) for real-glass edge tint;
- Roughness 0.02-0.05 for slightly used glass;
- a grime or fingerprint texture into Roughness;
- for shards, cell-fracture the pane: Cell Fracture addon, or bmesh Voronoi cuts. Shards keep thickness on both sides.

HOW TO TRANSFER THIS TO OUR GAME (Roblox, no custom shaders)
Roblox cannot refract. Material.Glass gives a fake screen-space distortion and reflection on some quality levels, and only on Parts, not on MeshParts with SurfaceAppearance. The lessons from the video that do carry over are these:
- thickness: dark or bright edges sell glass;
- mostly see-through faces with a specular glint;
- light-coloured "shadow" pools instead of black ones;
- a dark surround so the highlights pop.

1) Glass shards (bottles, flasks, Dr. Rift vials, windows)
- Offline in Blender: fracture a thin-walled bottle or flask mesh (with real wall thickness, like the cube pane) into 8-20 shards, using Cell Fracture or bmesh Voronoi. Keep pieces under about 1k tris each. Export as one FBX per set (for example assets/glass/), in the same pipeline as tools/wounds/. As CLAUDE.md requires, zip the folder for the player.
- In Roblox, each shard is a MeshPart and there are two looks:
  a) Cheap and robust: Material = Glass, Transparency 0.6-0.75, Reflectance 0.15-0.3, Color light grey-green (about 200,220,215), with CastShadow = false so there are no black shadows. The engine's Glass material adds the distortion and reflection on higher graphics settings. Note that Glass only looks transparent when Transparency is above 0 and quality is high enough.
  b) Higher fidelity: a SurfaceAppearance with a baked ColorMap whose alpha carries transparency (AlphaMode = Transparency). The ColorMap is pale, with dark edge bands baked in, which fakes the black refracted edges seen at 44-48 s. Add a RoughnessMap near 0 with grime streaks, a MetalnessMap at 0, and a NormalMap with micro-ripple and chip bevels so the light gives pinpoint glints. Bake these in Blender: render the Cycles glass material into the UVs (Emit or Combined bake from a front-facing camera, or bake "Glossy + Transmission" against a dark environment), and use an edge mask (Bevel node or AO inverted) to darken the rims.
- Rule of thumb from the video: rims dark, face clear, one hot specular dot. Bake the hot dot as a small near-white spot in the ColorMap only for shards; on whole objects let the engine specular do it.

2) Breaking glass VFX (bottle smash, vial bursting)
- About 1 frame: a white-blue flash (PointLight, Brightness 3-5, Range 6, lasting 0.05 s), in line with our hitstop and flash-frame rules in docs/references/README.md.
- Shards: 8-15 MeshParts with radial velocity, spin and gravity. They stay on the ground (persistence, like blood) and fade only after a long time. Use CanCollide with low friction and density, or client-side debris with raycast landing.
- Glitter: a ParticleEmitter of tiny glass flecks (a 64-128 px texture with a bright core and dark rim, baked from a Blender render of a small shard against black, LightEmission 0.3-0.5). Lifetime 0.3-0.8 s, Drag 2-4, Acceleration -Y. Pair it with a Beam or ParticleEmitter liquid splash if the flask has contents.
- Ground: a Decal or flat plane with a baked shard-scatter alpha texture, and a pale caustic "pool" (not black) for a pane or window resting on the ground.

3) Glass as a weapon or gore element (broken-bottle stab, shard embedded in a wound)
- Reuse the shard meshes and add a dark wet blood layer on one end: a second SurfaceAppearance variant whose ColorMap has blood near the tip, or a small blood Decal or mesh overlay from the wound kit. Blood on glass reads best as thin, glossy, dark red with low roughness, so it stays readable against the clear body.
- An embedded shard in a wound: a MeshPart welded to the limb, Transparency about 0.5, CastShadow off, with our existing blood decals around it.

4) Environment glass (windows, display cases) in the arena
- Parts with Material = Glass, Transparency 0.5-0.7 and Reflectance 0.1-0.2 give correct engine behaviour. Make them thick (0.1-0.2 studs) so the edges catch light, exactly as the video's thin cube. A breakable version swaps to pre-fractured shard MeshParts on hit (from Blender), plus the flash, the glitter particles and persistent floor debris.

5) Lighting cue for our cinematics
- One strong overhead or side key light (SpotLight or SurfaceLight) in a dark area, as the video uses a single Area light in a dark world, makes glass read. In flat ambient light glass disappears. For finisher cameras that feature glass, briefly add a SurfaceLight or SpotLight close to the glass.

Limits to remember: Roblox has no refraction, real caustics or IOR; Glass material distortion depends on quality level; SurfaceAppearance alpha transparency sorts poorly against other transparent objects, so keep shard counts small; and Glass material is ignored on MeshParts that use SurfaceAppearance. So choose per asset: either (a) engine Glass or (b) baked SurfaceAppearance, not both.