# Tester les fonctionnalités dans Studio

Pour chaque étape : récupère la branche (GitHub Desktop → *Fetch* → choisir la branche),
`rojo serve` doit tourner, Studio connecté, puis **Play**. Garde la fenêtre **Output** ouverte
(*View → Output*) : aucune ligne rouge ne doit apparaître.

## Étape 1 — Base personnage (`feature/character-base`)

Avant : place réglée en **R6** (voir `SETUP_FR.md`, « Avatar R6 »).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Lancer **Play** | Personnage R6 (blocs). En bas : barres **HEALTH 100** et **STAMINA 100**. À gauche : bouton **SETTINGS**. Pas de barre de vie Roblox en haut à droite. |
| 2 | Bouger la souris | La caméra tourne sans clic droit, le curseur reste au centre, le perso regarde où vise la caméra, caméra décalée sur l'épaule droite. |
| 3 | Molette | Zoom entre proche et moyen, jamais en 1ʳᵉ personne. |
| 4 | Maintenir **Shift** en marchant | Le perso court, l'angle de vue s'élargit un peu, STAMINA descend. |
| 5 | Shift **sans bouger** | STAMINA ne descend pas. |
| 6 | Courir jusqu'à 0 | La barre devient brun/orange, on repasse en marche. On ne peut recourir qu'à partir de 25. |
| 7 | Arrêter de courir | Après ~1 s, STAMINA remonte. |
| 8 | **Ctrl** | Le curseur apparaît, la caméra ne tourne plus. Re-**Ctrl** → verrouillé à nouveau. |
| 9 | Ctrl puis clic **SETTINGS** | Une fenêtre s'ouvre, bouton SETTINGS orange. **X** ou re-clic SETTINGS la ferme. |
| 10 | *First-person camera* → **ON** | Passage en 1ʳᵉ personne ; le curseur reste libre tant que la fenêtre est ouverte. Fermer → curseur bloqué. |
| 10b | Repasser **OFF** | Retour en 3ᵉ personne à une distance normale (pas collé au personnage). |
| 11 | Arrêter Play puis relancer | Le choix 1ʳᵉ personne est conservé (seulement si les sauvegardes sont actives dans Studio). |
| 12 | Se faire mal (ex. `game.Players.<TonNom>.Character.Humanoid.Health = 50` dans la barre de commande, côté **Server**) | HEALTH descend à 50 et **ne remonte pas** tout seul (attendre ~15 s pour vérifier). |
| 13 | Mourir et réapparaître | Barres à 100, caméra et menu fonctionnent toujours. |

Test à 2 joueurs (*Test → Clients and Servers → 2 Players → Start*) : chaque joueur a ses propres
barres, la course de l'un n'affecte pas l'autre.

Si un test échoue : copie-moi les lignes rouges de l'Output et dis-moi le numéro du test.

## Étape 1 bis — Mouvements (`main` ou `feature/better-animations`)

**Parcours de test automatique** : dans Studio, un parcours apparaît tout seul près du spawn
(dossier `Workspace > DevTestCourse`, construit par `Server/Systems/DevCourse`). Chaque obstacle a
une étiquette qui dit ce qui doit se passer. Il n'existe **que dans Studio** (jamais dans le jeu
publié) ; pour le désactiver : `Config.Dev.TEST_COURSE = false`.

- **Rangée 1** : murs de 2,5 à 9 studs (verts = vault, bleus = mantle, orange = sauter d'abord).
- **Rangée 2** : muret fin, 4 barrières à enchaîner en courant, bloc « pas de place ».
- **Rangée 3** : piste de glissade, tour à escalader.

| # | Test | Résultat attendu |
|---|---|---|
| 1 | **C** | Le perso met **un genou à terre**, buste bas, poings levés ; la caméra descend. Re-**C** → debout. |
| 2 | Accroupi, avancer | Marche accroupie : les jambes **alternent**, aucun pied dans le sol. |
| 3 | Accroupi puis **Espace** | Le perso se relève (ne saute pas). |
| 4 | Accroupi puis **Shift** | Le perso se relève et court. |
| 5 | Courir sur la piste puis **C** | Glissade : buste en arrière et tourné, une jambe tendue devant, un genou levé, une main au sol derrière. Finit **accroupi**. STAMINA -15. |
| 6 | Glissade puis **Espace** | La glissade s'arrête, le perso saute. |
| 7 | Glissade contre un mur | Elle s'arrête net, pas de tremblement. |
| 8 | Mur **vert** (≤ 3,6 studs), **Espace** | **Vault** rapide (~0,4 s) : une main posée, le corps bascule, les jambes passent sur le côté. STAMINA -10. |
| 9 | Les 4 barrières en sprintant, **Espace** à chacune | On les enchaîne **sans perdre sa vitesse**. |
| 10 | Muret fin | Vault par-dessus, on retombe de l'autre côté. |
| 11 | Mur **bleu** (4 à 5,5 studs), **Espace** | **Mantle** (0,7 à 0,9 s) : attrape le rebord → suspendu, les jambes se balancent → traction → genou sur le rebord → debout. Les mains touchent bien le rebord. |
| 12 | Mur **orange** (7, 9 studs) : sauter, puis **Espace** en l'air | Le perso attrape le rebord en plein saut et monte. Depuis le sol : rien. |
| 13 | Arriver **de biais** sur un mur, **Espace** | Le perso se remet face au mur en grimpant (pas de travers). |
| 14 | La tour | On monte les 4 étages en enchaînant les mantles. |
| 15 | Bloc rouge « NO ROOM » | Pas d'escalade. |
| 16 | STAMINA presque vide (< 10) | Pas d'escalade ni de glissade. |
| 17 | Course | Le buste se penche en avant ; à l'arrêt il se redresse en douceur. |
| 18 | Passer d'une animation à l'autre | Toujours un fondu, jamais de « saut » de pose. |
| 19 | En 1ʳᵉ personne (Settings) | Tout marche aussi. |

Test à 2 joueurs : le joueur 2 voit les **animations** du joueur 1, avec un petit décalage normal (réseau).
Dans l'Output, **aucune ligne rouge**. S'il y en a : copie-les-moi avec le numéro du test.
