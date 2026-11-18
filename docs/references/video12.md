# Reference video 12

Analysed frame by frame at 15 fps.

VIDEO 12 - "How to Create Realistic Water Droplets in Blender" (harsh x animation), 146 s, 640x338, Blender 4.5.2, Cycles viewport render. No voice-over; burned-in English captions plus the on-screen UI.
Coverage: I read sheets v12_sheet00 to sheet03 (the result montage at 0-8 s). The 480 px frames in f12/ are too small to read node values, so I pulled 1 fps frames from the source mp4 at its full 640 px. I read every second of the video as 2x2 grids, made a caption strip for all 146 s, and zoomed 4x into the node editor and the material and light panels at 49, 64, 67, 83, 90, 92, 96, 128, 129, 131 and 141 s. Values I could not read for sure are marked "unclear". Work files: (local) v12/ (cap0-3.png captions, g00-g36.png grids, c*.png zooms).

=== TECHNIQUE SUMMARY ===
Main idea: the droplets are not modelled on the tube itself. A separate plane object (named "Plane") carries a Geometry Nodes modifier. That modifier reads the tube's mesh through Object Info, scatters small spheres over its surface and outputs only those spheres. The droplets are therefore a separate mesh that hugs the tube, with its own glass material. The tube keeps its own textured material (pink-red label, "Beauty Cream" logo).

0-8 s: final result. A pink cosmetic tube covered in many clear beads of varying size. They look dark-rimmed, with tiny specular dots in the render.

1. Object (8-12 s): new mesh "Cream tube-bottle", a tube shape, already UV-textured.
2. Carrier (13-23 s): split the viewport and open the Geometry Node editor. Add a Plane (any size; it is only a container) and give it a new Geometry Nodes modifier, node group named "water droplets".
3. Source (25-35 s): delete the Group Input node and add Object Info. Set Object = the tube, switch Original to Relative and leave As Instance unchecked. Relative makes the scattered points line up with the tube even though they live on the plane object.
4. Scatter (41-53 s): Object Info Geometry goes into Distribute Points on Faces.Mesh. Settings:
   - mode Poisson Disk
   - Distance Min 0 m
   - Density Max 100 (caption says "density max 100"; the field reads 100.000)
   - Density Factor about 1.0 (dragged during the video; about 1.000 at the end)
   - Seed 0
5. Instancing (55-67 s): Instance on Points, with Points = Distribute.Points.
   - Instance input: UV Sphere (Segments 32, Rings 16, Radius 0.01 m), fed through a Transform Geometry node. Translation is 0 and Rotation is 0. Scale is 1,1,? (the Z value is unclear, maybe flattened).
   - Pick Instance off. Default instance scale 1,1,1.
6. Orientation (69-89 s): add a Vector Math node set to Add. Inputs: Distribute.Rotation plus the vector (1.500, 0.000, 0.000). The result goes into Instance on Points.Rotation. Effect: each sphere follows the surface normal, with an extra roughly 1.5 rad (about 86 degrees, close to pi/2) turn around X. With a flattened Z scale this turns each bead to lie against the surface.
7. Size variation (88-97 s): Random Value node, Float, Min 0.5, Max 1.0, ID empty, Seed 0, plugged into Instance on Points.Scale. Mixing 2x size differences is what keeps the beads from looking cloned.
8. Output chain (100-111 s): Instance on Points, then Realize Instances (Realize All on, Depth 0), then Set Shade Smooth (domain Face, Shade Smooth on), then Set Material (material "water"), then Group Output. The tube is not joined in; the plane outputs only the droplets. Smooth shading on the UV spheres matters: the faceted versions look like grains of rice.
9. Material (120-133 s): a new material, Surface switched from Principled BSDF to Glass BSDF.
   - Distribution: Multiscatter GGX
   - Color: pure white
   - Roughness: caption says "set as zero"; the final value reads about 0.063
   - IOR: 1.500, left at default (physically, water is 1.333)
   - Settings: Displacement "Bump Only", Transparent Shadows on, Bump Map Correction on
10. Lighting and render (131-145 s): Cycles rendered viewport, sample counter "x/1024". Two Area lights ("Area", "Area.001"): Square, Size about 2.84 m, Power about 22.8 W (reads 22.800), Exposure 0, Normalize on, Spread 180 degrees, white. Plain grey background, no HDRI.

Why it looks realistic (from the final close-ups at 137-139 s):
   - The drops are refractive. Each bead shows a flipped, darkened copy of the label behind it and a dark Fresnel rim at its edge, plus a tiny sharp highlight from the area lights.
   - Glass with near-zero roughness gives the dark edge, bright pinpoint and see-through middle that read as water.
   - Poisson Disk spacing stops drops from overlapping while still looking random.
   - Random scale 0.5-1.0 gives large and small drops together.
   - Base radius 0.01 m, so the drops are tiny compared with the object.
   - Drops cover the whole surface, including the silhouette edges, where they break the outline.
   - Large soft area lights give broad, believable highlights instead of one hard point.
Weak points: IOR 1.5 instead of 1.33. The beads are full spheres pushed half into the surface (no flat contact base, no drips or runs, no streaks of dried water). The arrangement does not respond to gravity: no stretched, teardrop or bigger drops lower down.

bpy recipe (condensed):
  plane = add plane; mod = plane.modifiers.new("drops","NODES"); ng = new GeometryNodeTree
  ObjectInfo(transform_space='RELATIVE', Object=tube)
    -> DistributePointsOnFaces(distribute_method='POISSON', Distance Min=0, Density Max=100, Density Factor=1, Seed=0)
  MeshUVSphere(32,16,r=0.01) -> TransformGeometry(scale=(1,1,1 or ~0.5))
    -> InstanceOnPoints.Instance
  VectorMath(ADD, Distribute.Rotation, (1.5,0,0)) -> InstanceOnPoints.Rotation
  RandomValue(FLOAT, 0.5, 1.0) -> InstanceOnPoints.Scale
  -> RealizeInstances -> SetShadeSmooth(domain FACE, True) -> SetMaterial(water) -> GroupOutput
  Material: ShaderNodeBsdfGlass(distribution='MULTI_GGX', Color white, Roughness 0-0.06, IOR 1.5 [use 1.333 for water])
  Lights: 2 x AREA, SQUARE, size 2.84, energy ~22.8 W; Cycles, ~1024 samples (fewer is fine for a preview).
  Then apply the modifier, or use evaluated_get, to bake the drops into a real mesh for export.

=== HOW TO TRANSFER THIS TO OUR GAME ===
Limits in Roblox: one material, colour, reflectance and transparency per MeshPart. There is no refraction and no custom shaders. SurfaceAppearance can give PBR maps (ColorMap, NormalMap, RoughnessMap, MetalnessMap) and an AlphaMode, and it ignores Part.Transparency. Glass material gives a cheap fake refraction, but only on Parts and only at Graphics level 8 and up.

What transfers well:
1. The scatter pipeline as an offline tool, the most useful part. Do the same Object Info (Relative) on a body or limb mesh, then Distribute Points on Faces (Poisson Disk), then Instance on Points with random scale 0.5-1.0. This bakes blood beads and spatter onto wound pieces, severed limbs, the Z-Anatomy stumps in tools/wounds/, and the floor around a body. Realize, apply, export as one MeshPart, so it costs one draw call and not hundreds of parts. Use a fixed Seed per variant and build 3-6 variants per piece so repeats don't show.
   - Add a Selection mask so drops gather near the wound edge: a vertex-group or distance-to-wound-centre falloff into Selection or Density. The tutorial's even coverage would look wrong for blood.
   - Add gravity: stretch drops along world -Z and make them bigger lower down, so they read as runs and drips (teardrop = sphere scaled along the down-tangent). This gives the "blood runs down and stays" persistence our reference README asks for.
2. Shape and shading: the smooth-shaded low-poly sphere matters. For Roblox, use 8-12 segments x 4-6 rings, not 32x16. Flatten Z to about 0.3-0.5 and cut the bottom so drops sit flush (flat contact base). Keep smooth normals, since Roblox imports FBX normals and the round normal gives the convex highlight. For pools: one flattened, smooth-normalled blob mesh with a raised meniscus rim at the edge, never a flat decal disc alone.
3. Material, faked. Blood is not clear glass, so no refraction is needed. The realism comes from a dark, deeply saturated body (base colour around RGB 40-70, 0-5, 0-5, close to black-red where the blood is thick) plus a very glossy surface.
   - Use SurfaceAppearance with RoughnessMap near 0.05-0.15 on wet blood (about 0.5-0.7 where it has dried at the edges) and Metalness 0. The PBR spec then gives the sharp pinpoint highlight the tutorial gets from glass. Without SurfaceAppearance: Material = Glass or SmoothPlastic, Reflectance about 0.1-0.25, dark colour.
   - Bake a NormalMap from the high-poly drop scatter onto a low-poly wound or pool mesh, the way the tutorial gets detail from instances. That gives hundreds of drops' worth of highlights for the cost of one texture: the cheapest way to get wet-looking wounds.
   - A small edge-darkening (Fresnel rim) can be baked into the ColorMap: darker rim, slightly lighter centre on thin films. This copies the tutorial's dark-edged beads without refraction.
4. Glass, for windows and bottles in maps or props: Roblox Glass material plus Transparency about 0.3-0.6 is the in-engine equivalent. Small water or blood beads on glass come from the same scatter, as a separate MeshPart with its own colour.
5. Previews (our Blender render tool): reuse the tutorial setup for look-dev renders of blood. Glass BSDF is wrong for blood; use Principled with Transmission about 0.3-0.5, Subsurface, dark red, Roughness 0.05, IOR about 1.35-1.4, Multiscatter GGX. Light with 2 large square area lights (about 2.8 m, Normalize on) so the wet highlight shows. Check the render before export.

What does not transfer:
- Refraction and IOR, Glass BSDF, transparent shadows, Multiscatter GGX, bump-only displacement: all of these exist only in Cycles. In Roblox they become baked maps or the built-in Glass material.
- Live Geometry Nodes or procedural instancing at runtime: everything must be applied and exported as a static mesh. Runtime spatter needs pre-built mesh variants placed by script, or Decals on a mesh.
- High instance counts: 100 dense drops x 32x16 spheres is about 50k+ triangles. Limit it to roughly 2-5k triangles per gore piece, or move the detail into a baked normal map.
- Pure-white clear water beads: they don't fit our gritty blood look, except for rain or sweat on surfaces.