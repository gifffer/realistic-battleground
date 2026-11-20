# Mini-jeu « autopsie » (vidéo, 18+, Studio seulement)

Un petit mini-jeu fait **uniquement pour tourner une vidéo**. Il est à supprimer ensuite.

- Une salle façon *Dexter* : du plastique transparent sur tous les murs et sur des paravents, une table en acier aux pieds croisés, une lampe dure au-dessus du corps, un chariot d'outils, une arche en briques blanchies avec des cadres.
- Un corps R6 allongé sur la table, emballé dans du film jusqu'au cou, le torse nu.
- Au **scalpel**, tu coupes la peau, puis le gras, puis le muscle. Avec les **mains**, tu écartes la plaie et tu arraches les **organes** (vraie anatomie Z-Anatomy).
- Pendant l'opération, l'écran passe en **pixel art old-school** : gros pixels nets, peu de couleurs, contours sombres.

## Activer

1. Dans `src/shared/Config.luau`, section `Dev`, mets `AUTOPSY_VIDEO = true`.
2. Lance un **Play** dans Studio. Le mini-jeu ne tourne **jamais** dans le jeu publié : il faut Studio **et** ce réglage.
3. Pour avoir les **vrais organes**, ré-importe `assets/wounds/WoundKit.fbx` (il contient les pièces `Gore_Aut*_*`). Sans elles, le jeu met des formes simples à la place et l'écrit dans l'Output.

Si l'écran pixel ne s'affiche pas (message dans l'Output) : *Game Settings > Security*, active **« Allow Mesh / Image APIs »**. Cette option est nécessaire pour les EditableImage.

## Y aller

- Une **dalle rouge** est posée à côté du spawn. Approche-toi et appuie sur **E** (« Enter »). Tu peux aussi appuyer sur **F8**.
- La salle flotte 300 studs au-dessus du spawn. Elle n'existe que chez toi : personne d'autre ne la voit.
- Près de la table, appuie sur **E** (« Operate ») pour commencer l'opération.
- Pour ressortir : la porte en métal (**E**, « Leave »), ou **F8**.
- Si ton perso meurt ou reset dans la salle, tout revient à la normale (caméra, HUD, lumière) et tu réapparais au spawn.

## Commandes pendant l'opération

| Touche | Action |
|---|---|
| **1** | Scalpel (par défaut) : clic gauche maintenu et glisse sur le torse pour couper. Chaque passage va **une couche plus loin** : peau → gras jaune → muscle rouge → cavité. Garde le clic immobile une demi-seconde pour couper plus profond à cet endroit. |
| **2** | Mains : clique **sur la coupure** et tire pour **écarter** la plaie. Clique sur un **organe** visible pour l'attraper : il résiste, s'étire, puis **s'arrache** avec du sang. Relâche pour le lâcher (il tombe, mou et mouillé). |
| **3** | Cisailles : garde le clic **sur le plastron** (sternum et côtes) environ 1 seconde pour le détacher. Ensuite, prends-le avec les mains pour voir les poumons et le cœur. |
| Molette | Zoom. Si tu tiens un organe : la hauteur à laquelle tu le lèves. |
| Clic droit + glisser | Tourner un peu la caméra. |
| **R** | Nouveau corps (le sang déjà versé reste). |
| **P** | Écran pixel on / off, pour comparer. |
| **H** | Cacher la ligne d'aide, pour enregistrer proprement. |
| **F** ou **Retour arrière** | Quitter l'opération. |

Ordre conseillé :
1. Coupe 3 fois le long de la même ligne, du haut du torse au bas du ventre.
2. Écarte avec les mains.
3. Retire la graisse (l'omentum) et les intestins.
4. Coupe le plastron aux cisailles et retire-le.
5. Retire les poumons et le cœur, puis le foie et l'estomac.
6. Les reins sont au fond : ils viennent en dernier.

## Comment c'est fait (pour info)

- **Code** : `src/client/Controllers/AutopsyController.luau`, c'est la porte d'entrée. Tout le reste est dans `src/client/Autopsy/` :
  - `Room` : la salle ;
  - `Patient` : le corps et le film ;
  - `Skin` : les couches qu'on coupe ;
  - `Organs` : les organes ;
  - `Tools` : le scalpel, la main gantée et les cisailles en 3D ;
  - `PixelScreen` et `PixelWorker` : l'écran pixel ;
  - `Sfx` : les sons.
- Tout est **local** : aucun code serveur, rien n'est sauvegardé.
- **Écran pixel** : Roblox n'a pas de post-process. Un petit lanceur de rayons en Luau dessine l'image en 192×108 environ.
  - Il tourne sur 8 Actors, en parallèle.
  - L'image va dans une EditableImage, affichée en plein écran en mode *Pixelated*, donc avec des pixels nets.
  - Le rendu utilise une palette limitée prise sur l'image de référence (bleu nuit, sarcelle, rouges, jaune pâle), un tramage Bayer 4×4 et des contours sombres.
  - Le plastique est dessiné comme une trame.
  - Les rayons ne voient que des pièces : les particules (brume, jet de l'artère) et les Beams sont invisibles en mode pixel. Quand une artère se déchire en mode pixel, le jet est donc aussi dessiné avec des filets de sang (des pièces), sur les mêmes battements.
  - Pour des pixels plus gros, baisse `PIXEL_HEIGHT` dans `PixelScreen.luau` (par exemple 90).
- **Sons** : tous des sons publics du Creator Store, vérifiés. Ils sont dans `Sfx.luau`. En mode pixel, ils sont un peu plus graves et plus étouffés.

## Supprimer plus tard

Supprime :
- `src/client/Controllers/AutopsyController.luau` ;
- le dossier `src/client/Autopsy/` ;
- la ligne `AUTOPSY_VIDEO` (et son commentaire) dans `src/shared/Config.luau` ;
- ce fichier `docs/AUTOPSY_FR.md`.

Les pièces `Gore_Aut*` du `WoundKit` sont optionnelles : on peut les laisser, rien ne les exige.

## TEST

- [ ] `AUTOPSY_VIDEO = false` : Play dans Studio → pas de dalle rouge, rien dans l'Output.
- [ ] `AUTOPSY_VIDEO = true` : Play → Output « [Autopsy] video mini-game on ». La dalle rouge est à côté du spawn.
- [ ] E sur la dalle (ou F8) → tu es dans la salle. Lumière froide bleutée, plastique partout, la table, la lampe, le chariot, l'arche.
- [ ] E sur la table → la caméra glisse au-dessus du corps et l'écran passe en pixels. Le HUD du jeu disparaît.
- [ ] Scalpel : une fente rouge suit la souris, des perles de sang montent, du sang coule sur les côtés et sur le plastique de la table.
- [ ] Coupe 3 fois : jaune (gras), puis rouge (muscle), puis sombre (cavité).
- [ ] Mains sur la coupure : la plaie s'ouvre en marches (peau, gras, muscle) et on voit les organes.
- [ ] Mains sur un organe : il résiste, s'arrache (son, jet de sang, la cavité se remplit de sang), pend, et tombe mou quand on lâche.
- [ ] Mains sur le plastron fermé → message « Cut the chest plate free first ». Cisailles 1 s → craquement. Ensuite on peut le retirer.
- [ ] P : bascule entre l'écran pixel et la vue normale. H : cache l'aide. R : nouveau corps.
- [ ] F : on sort. La caméra, le HUD et la souris reviennent normaux. Clic gauche = coup de poing de nouveau.
- [ ] Porte « Leave » ou F8 : retour à côté du spawn, la lumière normale revient.
- [ ] Reset pendant l'opération : caméra, HUD, souris et lumière normales au respawn, pas d'écran pixel.
