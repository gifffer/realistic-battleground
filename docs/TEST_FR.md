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
| 1 | **C** | Accroupi tactique : buste penché en avant, genoux pliés, pied gauche devant, garde haute ; la caméra descend. Re-**C** → debout. |
| 2 | Accroupi, avancer | Marche accroupie tactique : les jambes **alternent**, le pied qui avance se soulève, aucun pied dans le sol. |
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

## Étape 2 — Combat de base (`feature/combat-integration`)

Deux **mannequins** apparaissent devant le point d'apparition : **Dummy** (gris, passif, se soigne
après 3 s) et **Attacking Dummy** (rouge, te frappe si tu t'approches à moins de 7 studs).
Les **boîtes rouges** qui apparaissent sont les hitbox (visibles seulement dans Studio).
Les **sons** ne jouent que si leurs IDs sont remplis dans `src/shared/Sounds.luau` (`docs/SOUNDS_FR.md`).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Clic gauche près du **Dummy** | Boîte rouge devant toi, le Dummy flashe rouge, sa vie baisse (barre au-dessus de lui). |
| 2 | **Maintenir** clic gauche | 4 coups enchaînés ; le 4ᵉ **repousse** le Dummy ; petite pause avant le combo suivant. |
| 3 | Frapper dans le vide puis attendre 1 s | Le combo recommence au coup 1. |
| 4 | Pendant que tu frappes | Tu avances plus lentement, Shift ne fait pas courir. |
| 5 | S'approcher de l'**Attacking Dummy** sans rien faire | Tu flashes rouge, contour **jaune** (étourdi), ta vie baisse, l'écran tremble un peu, le 4ᵉ coup te repousse. |
| 6 | Maintenir **F** devant lui | Contour **bleu** ; les coups flashent bleu, ta vie baisse très peu, ta STAMINA baisse. |
| 7 | Rester en garde jusqu'à STAMINA 0 | « **GUARD BREAK!** » orange, contour jaune, tu ne peux plus bloquer ni frapper ~1,5 s. |
| 8 | Appuyer sur F **juste avant** un coup | « **PARRY!** » blanc : c'est **lui** qui devient jaune (étourdi 1 s). Frappe-le pendant ce temps. |
| 9 | Spammer F | Les parades ne marchent plus (il faut lâcher F ~0,6 s avant de retenter). |
| 10 | Garde (F) avec l'Attacking Dummy **dans ton dos** | Le blocage ne marche pas de dos : tu prends le coup normalement. |
| 11 | **Q** en marchant / à l'arrêt | Petit dash dans ta direction / en arrière ; STAMINA −25 ; 2 s avant le prochain. |
| 12 | Q pile quand l'Attacking Dummy frappe | « **DODGE** » : le coup ne fait rien. |
| 13 | Tuer le Dummy | Il tombe, et revient 3 s plus tard. |
| 14 | Mourir face à l'Attacking Dummy | Tu réapparais, tout remarche (frapper, bloquer, dash). |
| 15 | Animations des coups | 1 : direct du gauche ; 2 : direct du droit (le buste tourne) ; 3 : crochet du gauche ; 4 : coup plongeant du droit, bras levé avant. Chaque coup a un petit élan avant l'impact. |
| 16 | Animations de défense | F : avant-bras croisés devant le visage (les jambes continuent de marcher). Coup bloqué : recul. Parade : le bras droit écarte le coup. Guard break : bras qui s'ouvrent, puis titube. |
| 17 | Étourdi / touché | Tête basse, bras ballants qui se balancent. Touché de face : tête en arrière ; de dos : projeté en avant. |
| 18 | Dashs (Q) | Avant : penché, bras en arrière. Arrière : buste en arrière, garde levée. Côtés : le corps penche dans la direction. |
| 19 | L'**Attacking Dummy** | Il joue lui aussi ses coups, ses réactions et son état étourdi. |
| 20 | Pendant une glissade / escalade : clic gauche, F, Q | Rien ne se passe. Et en garde (F) ou étourdi : pas de glissade ni d'escalade. |
| 21 | Accroupi + clic gauche ou F | Ça marche : on frappe / bloque accroupi. |

Test à 2 joueurs (*Test → Clients and Servers → 2 Players*) : vous pouvez vous frapper, bloquer et
parer entre vous ; chaque joueur voit les contours bleus/jaunes **et les animations** de l'autre.

Si un test échoue : copie-moi les lignes rouges de l'Output et dis-moi le numéro du test
(une vidéo marche très bien aussi).
