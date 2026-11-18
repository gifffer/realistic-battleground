# Le feu (corps qui brûlent, Pyromane)

Toutes les flammes du jeu passent par un seul module, `src/client/Combat/FireLook.luau` : les corps en feu (`Burns`, toutes les sources), et tout le Pyromane (`PyroFx` : Zippo, Molotov, flaques, souffle, bras en feu, Immolation).

## Ce qui a changé

Avant, une flamme = une tache orange floue de Roblox (`fire_main`) qui monte. Maintenant chaque feu est fait de **couches**, comme dans les jeux pros :

| Couche | Ce que c'est |
|---|---|
| **Corps** (`flame_loop.png`) | quelques **gros paquets de flammes** animés en boucle (3 à 5 langues qui se rejoignent) : la masse du feu |
| **Langues** (`flame_tongue.png`) | des langues qui **lèchent vers le haut**, s'étirent, se détachent et se déchirent |
| **Cœur** (`glow.png`) | la lueur très chaude collée au membre / au combustible |
| **Fumée** (`smoke.png`) | 4 bouffées différentes, **chaude en bas** (éclairée par le feu), noire de suie, puis grise |
| **Braises** (`ember.png`) | point, traînée, flocon qui brûle, double étincelle |
| **Boule de feu** (`fireball.png`) | pleine taille **dès la 1re image**, roule vers le haut, devient de la suie |
| **Feu au sol** (`ground_fire.png`) | un film d'essence en feu **à plat sur le sol**, bords irréguliers (jamais un rond) |
| **Ruban** (`flame_strip.png`) | le jet continu du souffle (Beam) et la traînée du Molotov (Trail) |
| **Brûlé** (`scorch.png`) | la marque noire au sol : bord cassé, doigts d'éclaboussure, gouttes |

- **Corps en feu** : par membre, corps + langues + cœur + braises ; **une seule** colonne de fumée et **une seule** lumière par corps, placées au milieu de ce qui brûle et qui bougent un peu (les ombres « rampent »). Le feu **respire** (flammes et lumière ensemble), a des **flambées** de temps en temps, **prend** en une fraction de seconde (une gerbe de langues, la lumière saute) et **s'éteint en ~1 s** (dernière bouffée de fumée), plus jamais d'un coup.
- **Flaques** : chaque cellule a son film au sol + ses flammes debout (hauteurs différentes) ; une cellule **prend** avec une gerbe, **baisse** sur sa dernière seconde. Une lumière par flaque, au-dessus des flammes qui restent ; **ombres** seulement pour la flaque la plus proche. La marque noire **se forme pendant que ça brûle** : une grande marque irrégulière + quelques taches plus petites (plus de disques par cellule).
- **Pyromane** : la mèche du Zippo **prend** (étincelles de la molette, la flamme grandit en 0,08 s), **s'étouffe** avec un filet de fumée ; le chiffon du Molotov s'allume avec des étincelles, laisse **une traînée de feu** en vol ; à l'impact, **gouttes d'essence en feu** ; le souffle a une **bouffée** au départ, un **jet continu**, la lumière **dans** le jet, et il **se détache des lèvres** à la fin ; l'Awakening suit le clip (voir les tests) ; les coups en feu ont un **impact** (flamme, étincelles, flash) ; l'Immolation a les **éclaboussures** sur la tête, une **tache d'essence** qui s'étale sous le corps, puis le **sol qui prend feu** autour de lui.
- **Performances** : moins de particules mais plus grandes (~17 flammes par membre en feu au lieu de ~40 petites, une fumée par corps au lieu de six). La **qualité graphique Roblox** compte : 1-3 = moitié moins de particules et pas de cœur ; 4-6 et automatique = trois quarts ; téléphone = trois quarts au plus.

## Importer les images (une seule fois)

**Tout marche sans elles** : en attendant, les anciennes images des brûlures (`flame.png`, `smoke.png`, `ember.png` de `assets/burns`) ou les particules de Roblox les remplacent, le ruban du souffle / du Molotov n'apparaît pas, et la marque au sol est faite de quelques ellipses sombres.

Les 9 images de `assets/fire/` :

| Fichier | Où coller l'ID dans `Config.Injuries.FIRE` |
|---|---|
| `flame_loop.png` | `flameLoop` |
| `flame_tongue.png` | `flameTongue` |
| `fireball.png` | `fireball` |
| `ground_fire.png` | `groundFire` |
| `smoke.png` | `smoke` |
| `ember.png` | `ember` |
| `glow.png` | `glow` |
| `flame_strip.png` | `flameStrip` |
| `scorch.png` | `scorch` |

1. Dans Studio : **Asset Manager** (*View* → *Asset Manager*) → **Bulk Import** → choisir les 9 images (pas les aperçus de `docs/fire`).
2. Pour chacune : clic droit → **Copy Asset ID** (l'ID de l'**image**, pas du décalque — même méthode que `docs/BURNS_FR.md`).
3. Les coller dans `src/shared/Config.luau`, section `Injuries.FIRE` :

```lua
FIRE = table.freeze({
	flameLoop = 111,
	flameTongue = 111,
	fireball = 111,
	groundFire = 111,
	smoke = 111,
	ember = 111,
	glow = 111,
	flameStrip = 111,
	scorch = 111,
}),
```

Les grandes feuilles d'animation font 1024 × 1024 (la taille max de Roblox) : ne pas les redimensionner. Si Roblox réduit la qualité à l'import, réimporter sans compression.

## Refaire les images

Tout est généré (aucune photo) :

- `venv/bin/python -I tools/pyro/make_fire.py assets/fire` (toutes) ou `... assets/fire flame_loop fireball` (seulement celles-là) ;
- `venv/bin/python -I tools/pyro/preview_fire.py assets/fire <dossier>` écrit `sheets.png` (chaque feuille sur nuit / ciel), `frames.png` (des images en grand) et `scene.png` (une petite simulation des couches : un corps R6 en feu, une flaque, nuit et jour).

![Les feuilles](fire/sheets.jpg)
![Images en grand : flamme en boucle, langue, boule de feu, feu au sol](fire/frames.jpg)
![Simulation : corps en feu, flaque de feu, nuit et jour](fire/scene.jpg)
