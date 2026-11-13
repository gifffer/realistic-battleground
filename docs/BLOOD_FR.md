# Les images du sang (une seule fois)

Le sang est beaucoup plus réaliste avec ses images : vraies formes de taches (bords festonnés, épines, queues, gouttelettes satellites), flaques avec un bord fin, coulures, traînées, empreintes de pas et de mains, tissus imbibés, gouttes qui volent.
**Sans elles, le jeu marche quand même** : il dessine le sang avec des formes simples (ovales, disques). Tu peux les importer dans n'importe quel ordre, une catégorie à la fois.

![Aperçu : les images teintées comme dans le jeu, sur asphalte, béton, brique, peau et coton](../assets/blood/preview.png)

## Comment elles marchent

- Les images sont **en gris** : blanc = film de sang très fin, gris foncé = sang épais. Le jeu les **teinte** avec les couleurs de `Config.Blood.PALETTE` (rouge vif quand c'est frais, puis rouge sombre, puis brun-noir quand ça sèche). C'est pour ça qu'elles paraissent grises dans le Gestionnaire de contenus : c'est normal.
- Les taches « directionnelles » (ovales, queues, traînées, satellites, arcs) **vont vers la droite** de l'image (+X). Le jeu les tourne dans le sens du mouvement de la goutte.
- Les empreintes (pieds, mains) ont les **orteils / doigts vers le haut** de l'image.
- Elles sont fabriquées par `tools/blood/make_blood_textures.py` (Python, numpy + scipy + Pillow). Pour les refaire : `python3 tools/blood/make_blood_textures.py` puis `python3 tools/blood/preview.py` (depuis la racine du repo). Si tu les refais, il faut les ré-importer et recoller les ID.

## Les fichiers (`assets/blood/`, 53 images, ~2,7 Mo)

| Fichiers | Taille | Ce que c'est | Clé dans `IMAGES` |
|---|---|---|---|
| `spatter_round_1..3` | 512 | Goutte tombée presque à la verticale : tache ronde, épines, gouttelettes autour | `spatterRound` |
| `spatter_oval_1..3` | 512 | Goutte arrivée en biais (40-70°) : ovale, épines vers l'avant | `spatterOval` |
| `spatter_tail_1..3` | 512 | Goutte très en biais (15-40°) : « point d'exclamation » avec queue | `spatterTail` |
| `spatter_streak_1..2` | 512 | Goutte rasante (< 15°) : longue traînée perlée | `spatterStreak` |
| `satellites_1..3` | 512 | Nuage de fines gouttelettes (40, 90, 150 gouttes) | `satellites` |
| `drip_1..2` | 256 | Goutte tombée d'une plaie (environ 1 m) | `drip` |
| `drip_pool_1..2` | 512 | Gouttes tombées sur du sang mouillé (quelqu'un saigne sans bouger) | `dripPool` |
| `pool_1..3` | 1024 | Flaque : bord fin plus clair, centre épais | `pool` |
| `pool_rim_1..3` | 1024 | Même contour que `pool_<n>` : auréole qui sèche, sérum, caillots | `poolRim` |
| `pool_lobe_1..3` | 512 | Langue de sang qui s'ajoute quand la flaque coule vers la pente | `poolLobe` |
| `run_1..2` | 256×1024 | Coulure sur un mur / la peau (du haut vers le bas) | `run` |
| `smear_1..2` | 1024×512 | Traînée quand on traîne un corps (vers la droite) | `smear` |
| `handprint_L_1`, `handprint_R_1` | 256 | Empreinte de main gauche / droite | `handL`, `handR` |
| `foot_L_1..3`, `foot_R_1..3` | 256 | Semelle gauche / droite : 1 = pleine, 2 = partielle, 3 = trace | `footL`, `footR` |
| `soak_1..3` | 512 | Sang imbibé dans un t-shirt / pantalon | `soak` |
| `skin_smear_1..2` | 512 | Film fin essuyé sur la peau | `skinSmear` |
| `knuckles_1..2` | 256 | Sang sur les jointures du poing | `knuckles` |
| `arterial_arc_1..2` | 1024×256 | Jet d'artère sur un mur : vague de taches + coulures | `arterialArc` |
| `p_drop` | 128 | Une goutte en vol (particule) | `pDrop` |
| `p_drops_4x4` | 1024 | Goutte qui oscille en tombant (16 images) | `pDrops4x4` |
| `p_gobs_4x4` | 1024 | 16 paquets / filaments de sang (gros jets) | `pGobs4x4` |
| `p_mist_8x8` | 1024 | Fine bruine qui s'étale (64 images) | `pMist8x8` |
| `beam_stream` | 1024×256 | La « corde » de sang du jet d'artère (se répète vers la droite) | `beamStream` |

`preview.png` n'est **pas** à importer : c'est juste l'aperçu.

## Importer dans Studio

1. Ouvre le jeu dans Roblox Studio.
2. **Fenêtre → Gestionnaire de contenus** (*Window → Asset Manager*).
3. Clique **Importation en bloc** (*Bulk Import*), puis choisis toutes les images de `assets/blood/` **sauf `preview.png`** (Ctrl+A puis Ctrl+clic sur `preview.png` pour la retirer). Attends que la modération les accepte (elles apparaissent dans le dossier *Images*).
4. Pour chaque image : **clic droit → Copier l'ID de la ressource** (*Copy Asset ID*). Attention : il faut l'ID de l'**image**, pas celui d'un décalque.
5. Colle l'ID dans `src/shared/Config.luau`, dans `Blood.IMAGES`, à la bonne place. Chaque liste suit l'ordre des numéros des fichiers :

```lua
IMAGES = table.freeze({
	spatterRound = table.freeze({ 0, 0, 0 }), -- spatter_round_1, _2, _3
	...
	footL = table.freeze({ 0, 0, 0 }), -- foot_L_1 (pleine), _2 (partielle), _3 (trace)
	pool = table.freeze({ 0, 0, 0 }), -- pool_1..3
	poolRim = table.freeze({ 0, 0, 0 }), -- pool_rim_1..3 (même ordre que pool !)
	...
}),
```

   Par exemple, si `spatter_round_2.png` a l'ID `123456789` : `spatterRound = table.freeze({ 0, 123456789, 0 })`.
   **0 = pas encore importée** : le jeu prend une autre image de la même liste, ou les formes simples si toute la liste est à 0.
6. `pool_<n>` et `pool_rim_<n>` vont **par paires** (même contour) : remplis toujours les deux au même numéro.
7. Lance une partie test (F5) et frappe un mannequin pour voir le sang. Puis **File → Publish to Roblox**.

## Si ça ne rend pas bien

- **Le sang paraît rose** : ce n'est pas les images. Baisse d'abord la brillance (`gloss` dans `Config.Blood.PROFILES`), pas les couleurs.
- **Une image reste invisible** : vérifie que tu as collé l'ID de l'**image** (pas du décalque) et qu'elle a passé la modération.
- **Le jet d'artère est de travers** (corde verticale au lieu de suivre le jet) : préviens le développeur, `beam_stream` est dessinée pour que la corde suive la longueur du Beam (axe X de l'image).

⚠️ Gore réaliste : remplis le **questionnaire de maturité** du jeu en conséquence. `Config.Blood.ENABLED = false` coupe tout le sang.
