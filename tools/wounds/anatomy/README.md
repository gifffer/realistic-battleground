# Anatomy of the head (burst head of the bat finisher)

`head.npz` holds decimated meshes taken from **Z-Anatomy** (https://www.z-anatomy.com),
licensed **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/): the skull's
bones, the brain, the lower jaw, the teeth, the eyes, the atlas and axis vertebrae.
They were reduced and moved into the classic Roblox head's space by
`tools/wounds/extract_anatomy.py`. Under the same licence, the derived pieces
(`Gore_*` in `assets/wounds/WoundKit.fbx`) are shared alike, with this credit.

`arm.npz` holds the right **humerus**, the outer part of the right **scapula**, the outer end of
the right **clavicle** and the muscles round the right shoulder and upper arm, also from **Z-Anatomy** (CC BY-SA 4.0), taken from the Z-Anatomy repository's
`SkeletalSystem100.fbx` and `MuscularSystem100.fbx` (https://github.com/LluisV/z-anatomy) by `tools/wounds/extract_arm.py`, for the
Bouncer's finisher (the torn arm) and the bone you can throw (`Gore_Humerus*`, `Gore_ArmEnd_Bone`,
`Gore_Shoulder_Bone` in `WoundKit.fbx`, shared alike under the same licence).

`torso.npz` holds parts of the chest and the belly, also from **Z-Anatomy** (CC BY-SA 4.0),
taken from Z-Anatomy's `Startup.blend` by `tools/wounds/extract_anatomy.py --torso`, cropped
to where the wounds are, decimated and moved into the R6 torso's space:

- for the Sentinel's finisher (the bore over the heart: the `Bore*` inserts of `WoundKit.fbx`):
  the **right and left ventricles** and the **papillary muscles** of the heart, the **body of
  the sternum**, the left **third to sixth ribs** and their **costal cartilage**, the left
  **pectoralis major** (sternocostal and abdominal parts), the left **internal intercostal
  muscles**, the **superior and inferior lobes of the left lung**. The insert's wall and bottom
  show which of them is where (read along the beam), each given a real thickness;
- for the Bull's finisher (the body torn in two: `Gore_Waist_*`, `Gore_Hips_*`, `Gore_Gut*`):
  the **L3, L4 and L5 vertebrae** and the **L3-L4 and L4-L5 discs**, the **jejunum** (a curve
  object in Z-Anatomy: its evaluated mesh), the **ascending, descending, sigmoid and
  transverse colon**, the **rectus abdominis**, **external and internal oblique** and
  **transversus abdominis** muscles, the **psoas major**, **quadratus lumborum**,
  **iliocostalis lumborum**, **longissimus thoracis** and **multifidus lumborum** muscles,
  the **hip bones** and the **sacrum**.

The derived pieces are shared alike under the same licence, with this credit.

`waist.npz` holds a slab of the hips round the cut of Dr. Rift's finisher (PortalCut, the body cut
in two at the hip joints), also from **Z-Anatomy** (CC BY-SA 4.0), taken from the Z-Anatomy
repository's `SkeletalSystem100.fbx`, `MuscularSystem100.fbx`, `VisceralSystem100.fbx` and
`CardioVascular41.fbx` by `tools/wounds/extract_waist.py`: both **hip bones**, the **sacrum**, the
**coccyx**, the tops of both **femurs**; the muscles round the hips (glutei, iliacus, psoas major,
obturators, piriformis, gemelli, tensor fasciae latae, sartorius, rectus femoris, pectineus,
adductors, quadratus femoris, vastus lateralis, pelvic floor, the lowest abdominal wall); the
**urinary bladder**, the **sigmoid** and **descending colon**, the lowest loops of the
**small intestine** and the whole small intestine (jejunum); the femoral, external iliac, gluteal,
pudendal, obturator and circumflex vessels. They make `Gore_RiftWaist_*`, `Gore_RiftHipR_*`, `Gore_RiftHipL_*`,
`Gore_RiftGut1_*`..`Gore_RiftGut3_*` and `Gore_RiftColon_*` in `WoundKit.fbx`, shared alike under the same licence.
