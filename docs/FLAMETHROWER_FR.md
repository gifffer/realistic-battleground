# Le lance-flammes du Pyromane

Le lance-flammes validé (`tools/pyro/flamethrower.py`, rendus dans `assets/pyro/flamethrower_sheet.png`) est maintenant dans le jeu, sur tout personnage dont le kit est « Pyromaniac » (clones et corps compris). Il est visible chez tous les joueurs.

## Ce que tu vois

- **Porté dans le dos** en permanence : en diagonale, la poignée rouge juste derrière la hanche droite, la bouche qui dépasse derrière l'épaule gauche, la bouteille vers l'extérieur.
- **En main** pendant ses attaques : soudé au bras droit dans la prise validée (main droite sur la poignée-pistolet, main gauche sur la poignée en bois, crosse contre la hanche). Il passe du dos aux mains (et retour) en 0,12 s, sans « saut ».
- **Veilleuse bleue** au bout du brûleur quand il est sorti ; plus grosse, avec une pointe orange, en Éveil.
- **Chaleur** : en Éveil, les trous percés du manchon rougeoient en orange et fument ; pour le finisher, tout le manchon et la bouche deviennent rouge cerise, puis la soupape de décharge souffle un jet blanc et la chaleur retombe.
- **Pièces mobiles** : la gâchette, le levier de la vanne (tiré par le câble de frein), le volant de la bouteille et l'aiguille du manomètre.
- S'il est **étourdi, au sol ou mort**, il lâche la gâchette, la veilleuse s'éteint et l'arme repart dans le dos en 0,15 s.

## Deux versions

1. **Sans import** (par défaut) : l'arme est reconstruite en pièces Roblox (cylindres, blocs, coins, sphères), 192 pièces, mêmes proportions et couleurs que le modèle validé. Fichier généré : `src/client/Combat/FlamethrowerShape.luau`.
2. **Avec le FBX importé** : le vrai modèle (41 pièces nommées) est utilisé à sa place, automatiquement.

## Importer le FBX dans Studio (facultatif)

1. Dans Studio : **Fichier › Importer 3D** (3D Importer), choisis `assets/pyro/Flamethrower.fbx`.
2. Réglages : **Unité de fichier = Mètre** (Meter), garde les pièces séparées (ne coche pas « fusionner »), ancre le modèle.
3. Renomme le modèle importé **`Flamethrower`** et range-le dans **ReplicatedStorage › Assets** (crée le dossier `Assets` s'il n'existe pas).
4. Ne renomme pas les pièces (`Muzzle`, `Tank`, `StockConduit`, `ValveLever`, `TriggerLever`, `ValveWheel`...) : le jeu les reconnaît par leur nom.
5. Inutile de les colorier : le FBX n'a pas de textures, le jeu donne à chaque pièce sa couleur et sa matière (acier sombre, bouteille olive, poignée rouge, laiton, cuivre, bois, crosse galvanisée, caoutchouc...). Le tableau est dans `FlamethrowerShape.luau` (`MESH_PAINT`).

Le jeu retrouve tout seul l'orientation et l'échelle de l'import (grâce aux centres de quatre pièces). Si le modèle est incomplet, retourné en miroir ou modifié, un avertissement apparaît dans la sortie et la version en pièces Roblox est utilisée.

## Pour les développeurs

- Module : `src/client/Combat/Flamethrower.luau` (API en tête de fichier : `draw`, `holster`, `fumble`, `point`/`muzzle`, `setPilot`, `trigger`, `setValve`, `crankValve`, `setGauge`, `setHeat`, `vent`).
- Points d'attache : `Muzzle` (sa direction = celle du jet), `PilotLight`, `GripR`, `GripL`, `Stock`, `BackMount`, `ShroudGlow`, `GaugeFace`, `Regulator`.
- Régénérer les pièces et les aperçus : `venv/bin/python -I tools/pyro/flamethrower_parts.py --write --render <dossier>` puis `stylua src`.

## Dans les attaques

Le lance-flammes est maintenant **l'arme des 8 attaques** du Pyromane (et du finisher). Chaque clip (`tools/anim/pyro_clips.py`) le dégaine du dos (la main droite va chercher la poignée, `draw`), tire, puis le remet dans le dos (`holster`). Les poses de tir sont **calculées** avec l'arme dans les mains : le bras droit est résolu pour que le **canon vise là où part le feu**, le bras gauche pour que la main se pose sur la **poignée en bois** (ou le volant de la bouteille, la vanne, la veilleuse). `python3 tools/anim/pyro_clips.py --check` le vérifie image par image (60 i/s) ; `--render <dossier>` dessine les planches avec l'arme et la ligne de tir.

- **Prise « debout »** (`Flamethrower.port`) : seulement dans le finisher, pour que la main gauche puisse approcher le Zippo de la veilleuse (les bras R6 sont rigides). Elle est calculée par `pyro_clips.py --write`, qui réécrit la ligne `local PORT = ...` de `Flamethrower.luau`.
- **Le jet** part toujours du point `Muzzle` de l'arme ; si l'arme n'est pas encore construite, il part devant la poitrine.
- **Coupé** (étourdi, mis au sol, mort, autre action) : le jet se détache tout de suite, la gâchette se relâche et l'arme retourne dans le dos en 0,15 s.

Le modèle et le FBX n'ont **pas changé** : rien à réimporter.
