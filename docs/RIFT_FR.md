# Dr. Rift : importer son équipement (RiftGear)

> **Bras** : le bras mécanique n'utilise plus ce fichier. C'est maintenant un bras R6 en métal fait de pièces (même taille que le vrai bras, sans doigts), toujours bien placé. `RiftGear.fbx` ne sert plus qu'aux **pistolets** et à la **fiole**.

Le bras mécanique du Dr. Rift, le pistolet à rayon, le pistolet à portails et la fiole des potions sont de **vrais modèles 3D** (plaques boulonnées, servos, vérins chromés, tuyaux, cellule d'énergie verte, doigts articulés...). Ils sont dans **`assets/rift/RiftGear.fbx`**.

Sans ce fichier, le jeu marche quand même : il dessine une version plus simple avec des pièces Roblox (et l'Output affiche une fois `[RiftAssets] RiftGear has no pieces`).

## Importer dans Studio (une seule fois, et à chaque mise à jour du fichier)

1. Télécharge **`assets/rift/RiftGear.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`Rift`**.
   Si un ancien **`RiftGear`** est déjà dedans, **supprime-le** d'abord.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `RiftGear.fbx`, puis clique **Import** sans rien changer.
4. Glisse le modèle **`RiftGear`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > Rift`.
5. Ne supprime **rien** dedans, ne renomme rien : surtout pas **Kit_Origin**, **Kit_Up**, **Kit_Out** et les petits cubes `..._Pivot`, `..._Tip`, `Arm_PalmPoint`, `Arm_Cell` : le jeu s'en sert pour se repérer.
   Conseillé : sélectionne toutes les MeshParts du modèle et mets **CollisionFidelity** sur **Box** (ça ne se change pas en jeu, et l'équipement ne touche jamais rien : inutile de charger des formes de collision détaillées).
6. **File → Publish to Roblox**.

## Vérifier

Équipe le kit **DR. RIFT** :
- ton **bras gauche** est remplacé par le bras robot (le vrai bras est caché sur ton écran comme sur celui des autres) : l'épaulière est **posée sur l'épaule** (en haut du bras, au ras du torse), le bras a la **même largeur** qu'un bras Roblox et le gant arrive **au niveau de la main**. Il a la forme d'un vrai bras : une épaulière, le haut du bras, le coude (un servo), l'avant-bras qui s'affine jusqu'au poignet, puis une **main** qui pend comme une vraie main (quatre doigts serrés un peu pliés, le pouce devant) ; la **paume**, tournée vers ta jambe, brille en vert. Il reste collé au bras quand tu bouges, en ragdoll, sur les clones et en première personne ;
- il n'y a **plus d'implant à l'œil** (retiré) ;
- touche **2** : le pistolet à rayon (lueur orange) ; touche **4** : le pistolet à portails (bulbe en verre vert). Le tir part du bout du canon.

## Si tu avais déjà importé l'ancien fichier

Le bras se **cale tout seul** sur ton vrai bras gauche : le jeu mesure le modèle importé et le remet à la bonne taille et à la bonne place (même si l'import l'a agrandi, rapetissé ou décalé). Mais pour avoir la **nouvelle forme** (forme de vrai bras : épaulière, coude, avant-bras, main avec ses doigts et son pouce) et ne plus charger l'œil, refais l'import ci-dessus avec le nouveau `RiftGear.fbx` (supprime l'ancien `RiftGear` d'abord). L'ancien fichier marche encore en attendant (l'œil qu'il contient n'est simplement plus utilisé).

## Refaire le fichier

```bash
venv/bin/python -I tools/rift/build_rift_gear.py assets/rift --preview /tmp/rift_preview
```

`--preview` rend des images (le bras, la main, le bras posé sur un personnage R6 vu de face, de côté, de dos, les pistolets, la fiole). Voir `assets/rift/README.md` pour le détail des pièces.
