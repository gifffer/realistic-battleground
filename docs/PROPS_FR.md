# Ruelles : importer les objets 3D (CityProps)

Les objets des ruelles (pour l'instant le **cône de chantier**, d'autres vont suivre) sont de **vrais modèles 3D** : formes réelles, bords arrondis, salissures, traces de pneu, bosses... Ils sont dans **`assets/cityprops/CityProps.fbx`**.

Sans ce fichier, le jeu marche quand même : les ruelles gardent les anciens objets faits de pièces Roblox (et l'Output affiche une fois `[PropKit] ... props wait for the city prop kit`).

## Importer dans Studio (une seule fois, et à chaque mise à jour du fichier)

1. Télécharge **`assets/cityprops/CityProps.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`City`**.
   Si un ancien **`CityProps`** est déjà dedans, **supprime-le** d'abord.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `CityProps.fbx`, puis clique **Import** sans rien changer (laisse **Ignore Vertex Colors** décoché : les salissures sont dans les couleurs des sommets).
4. Glisse le modèle **`CityProps`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > City`.
5. Ne supprime **rien** dedans, ne renomme rien : surtout pas **Kit_Origin**, **Kit_Up**, **Kit_Out** et les petits cubes `..._Pivot` (et `..._Light`, `..._Fx` s'il y en a) : le jeu s'en sert pour se repérer.
   Conseillé : sélectionne toutes les MeshParts du modèle et mets **CollisionFidelity** sur **Box** (ça ne se change pas en jeu, et les objets ne servent qu'à l'affichage : les collisions restent celles d'avant).
6. **File → Publish to Roblox**.

## Ce qui change une fois importé

- Chaque objet marqué dans les données (une pièce invisible `MeshProp`) reçoit son modèle 3D au même endroit, à la même taille, tourné pareil.
- Les anciennes pièces de l'objet :
  - celles qui ont des **collisions** (ou que les coups/rayons touchent) deviennent **invisibles mais restent** : on se cogne, on saute et on frappe exactement comme avant ;
  - celles qui portent une **lumière**, des **particules** (feu, vapeur), un **tag** ou un panneau restent aussi (invisibles) : rien ne s'éteint ;
  - les autres (pure décoration) sont **supprimées**.
- Plus de clignotement (« z-fighting ») sur ces objets : chaque modèle est une seule forme propre, sans pièces l'une dans l'autre.

## Vérifier

Va dans les ruelles (à l'est du ring, le long du viaduc) ; dès que les données des ruelles utilisent le kit, le **cône** doit être un vrai cône lisse orange (pas des cylindres empilés), avec deux bandes réfléchissantes blanches, une base carrée noire en caoutchouc, de la crasse en bas et des traces de pneu. Le cône renversé est le même modèle, couché.

## Refaire le fichier

```bash
venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops --preview /tmp/props_preview
```

`--preview` rend des images de chaque objet (4 angles + un gros plan, à côté d'une silhouette humaine de 1,80 m). Voir `assets/cityprops/README.md` pour la liste des objets.
