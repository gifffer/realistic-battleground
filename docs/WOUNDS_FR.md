# Coupures réalistes (bouteille en verre)

Une bouteille ne casse pas un crâne et n'ouvre pas une cage thoracique. Le jeu montre donc ce qu'elle fait **vraiment** (sources médico-légales) :

| Coup | Plaie | Ce qu'on voit |
|---|---|---|
| **Bouteille fracassée** (touche 1) | **Lacération** : déchirure irrégulière, souvent en étoile | Bord de peau déchiré, bord rose de la peau coupée, chair rouge, gras jaune (sur le corps), du sang dans la plaie et qui coule |
| **Bouteille cassée** (Broken Bottle) | **Entaille** : longue, bords nets, en fuseau | Pareil, plus long et plus fin. Une entaille profonde (taille L) montre le **muscle** sur le corps, ou tout juste **l'os du crâne** au fond sur la tête (peau fine) |

- Frapper **au même endroit** agrandit la plaie : **S → M → L**. Ailleurs, ça fait une nouvelle plaie (3 au maximum par partie du corps).
- La plaie se trouve **du côté où se tient l'attaquant**, à une hauteur au hasard : front, tempe ou joue pour la tête ; poitrine, ventre ou dos pour le torse.
- Le **visage**, le **t-shirt** et le **pantalon** restent dessinés autour de la plaie.
- Tout disparaît au kill ou à la réapparition.

![Les 12 plaies (en haut : corps, en bas : tête)](wounds_kit.png)
![Rendu de contrôle : la tête en tuiles avec une lacération et une entaille, placées comme dans le jeu](wounds_head.png)

## Importer les plaies dans Studio (une seule fois)

1. Télécharge **`assets/wounds/WoundKit.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`Wounds`**.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `WoundKit.fbx`, puis clique **Import** sans rien changer.
4. Glisse le modèle **`WoundKit`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > Wounds`.
5. Ne supprime **rien** dedans, surtout pas **Kit_Origin**, **Kit_Up** et **Kit_Out** : le jeu s'en sert pour se repérer.
6. **File → Publish to Roblox**.

Tu peux supprimer le dossier `ReplicatedStorage > Assets > Anatomy` : il ne sert plus.

Sans `WoundKit`, le jeu marche quand même. Il y a le sang, mais pas de plaie visible.

## Comment ça marche

- **Serveur** : chaque plaie est un attribut du personnage, `Gash_<Partie>_<n>`. Par exemple, `Gash_Head_1 = "Slash|M|0.31|0.12|-0.52|-30|81234"` veut dire : entaille, taille M, position sur la tête, angle, graine aléatoire. Voir `src/shared/Util/Gash.luau`.
- **Client** (`src/client/Combat/Gashes.luau`) :
  - il cache la vraie partie du corps et la remplace par une **peau en tuiles**, avec la même couleur et les mêmes images (visage, vêtements) ;
  - il enlève les tuiles **en suivant le contour exact** de la plaie ;
  - il pose dedans le **modèle 3D** de la plaie.
- **Modèles** : `tools/wounds/build_wound_kit.py` (Blender en Python) fabrique `WoundKit.fbx` et `src/shared/WoundShapes.luau`, qui contient les contours. Pour les refaire :
  ```bash
  venv/bin/python tools/wounds/build_wound_kit.py assets/wounds --preview
  ```
  Ensuite, ré-importe `WoundKit.fbx` dans Studio.

⚠️ Gore réaliste : remplis le **questionnaire de maturité** du jeu en conséquence. Tu peux aussi tout couper avec `SKIN_TEAR = false` dans `Config.luau`.
