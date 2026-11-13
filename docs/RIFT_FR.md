# Dr. Rift : importer son équipement (RiftGear)

Le bras mécanique du Dr. Rift, son implant à l'œil, le pistolet à rayon, le pistolet à portails et la fiole des potions sont de **vrais modèles 3D** (plaques boulonnées, servos, vérins chromés, tuyaux, cellule d'énergie verte, doigts articulés...). Ils sont dans **`assets/rift/RiftGear.fbx`**.

Sans ce fichier, le jeu marche quand même : il dessine une version plus simple avec des pièces Roblox (et l'Output affiche une fois `[RiftAssets] RiftGear has no pieces`).

## Importer dans Studio (une seule fois, et à chaque mise à jour du fichier)

1. Télécharge **`assets/rift/RiftGear.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`Rift`**.
   Si un ancien **`RiftGear`** est déjà dedans, **supprime-le** d'abord.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `RiftGear.fbx`, puis clique **Import** sans rien changer.
4. Glisse le modèle **`RiftGear`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > Rift`.
5. Ne supprime **rien** dedans, ne renomme rien : surtout pas **Kit_Origin**, **Kit_Up**, **Kit_Out** et les petits cubes `..._Pivot`, `..._Tip`, `Arm_PalmPoint`, `Arm_Cell`, `Eye_Lens` : le jeu s'en sert pour se repérer.
   Conseillé : sélectionne toutes les MeshParts du modèle et mets **CollisionFidelity** sur **Box** (ça ne se change pas en jeu, et l'équipement ne touche jamais rien : inutile de charger des formes de collision détaillées).
6. **File → Publish to Roblox**.

## Vérifier

Équipe le kit **DR. RIFT** :
- ton **bras gauche** est remplacé par le bras robot (le vrai bras est caché sur ton écran comme sur celui des autres) ; la **paume** du gant brille en vert au bout de la main ;
- l'**implant** est pile sur ton **œil droit** (bague en laiton, lentille verte, plaque vissée dans la peau, petite antenne sur la tempe) ;
- touche **2** : le pistolet à rayon (lueur orange) ; touche **4** : le pistolet à portails (bulbe en verre vert). Le tir part du bout du canon.

## Refaire le fichier

```bash
venv/bin/python -I tools/rift/build_rift_gear.py assets/rift --preview /tmp/rift_preview
```

`--preview` rend des images (le bras, la main, l'œil sur une tête classique, les pistolets, la fiole). Voir `assets/rift/README.md` pour le détail des pièces.
