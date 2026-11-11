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

## Étape 1 bis — Mouvements (`feature/crouch-slide-climb`)

Prépare un terrain de test dans le Workspace (pas dans un dossier Rojo) : des blocs **ancrés**
(*Anchored*) de **3**, **5** et **8** studs de haut, et un muret fin (0,5 stud d'épaisseur, 3 de haut).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | **C** | La caméra descend, le perso marche lentement. Re-**C** → debout. |
| 2 | Accroupi puis **Espace** | Le perso se relève (ne saute pas). |
| 3 | Accroupi puis **Shift** | Le perso se relève et court. |
| 4 | Courir puis **C** | Glissade rapide dans la direction de la course, qui ralentit, finit **accroupi**. STAMINA -15. |
| 5 | Glissade puis **Espace** | La glissade s'arrête, le perso saute. |
| 6 | Glissade contre un mur | Elle s'arrête net, pas de tremblement. |
| 7 | Deux glissades d'affilée très vite | La 2ᵉ ne part pas tant que le cooldown (1,2 s) n'est pas fini (C → accroupi à la place). |
| 8 | Face au bloc de **3** studs, **Espace** | Le perso se hisse dessus (~0,5 s). STAMINA -10. |
| 9 | Face au bloc de **5** studs, **Espace** | Pareil. |
| 10 | Face au bloc de **8** studs : sauter, puis **Espace** en l'air près du haut | Le perso attrape le rebord et monte. Depuis le sol : rien (trop haut). |
| 11 | Le muret fin | On l'escalade et on retombe de l'autre côté. |
| 12 | Un bloc avec un plafond juste au-dessus | Pas d'escalade (pas la place). |
| 13 | STAMINA presque vide (< 10) | Pas d'escalade ni de glissade. |
| 14 | En 1ʳᵉ personne (Settings) | Accroupi, glissade, escalade marchent aussi. |
| 15 | Accroupi immobile | Garde basse : pied gauche devant, buste penché, poings levés, respiration lente. |
| 16 | Accroupi en marchant | Pas chassés (le pied avant avance, l'arrière suit), aucun pied dans le sol. |
| 17 | Glissade | Buste en arrière, jambes devant au ras du sol, une main traîne derrière. |
| 18 | Escalade | Bras tendus vers le rebord → genou levé → appui sur les mains → debout. |
| 19 | Course | Le buste se penche un peu en avant ; à l'arrêt il se redresse en douceur. |
| 20 | Passer d'une animation à l'autre | Toujours un fondu, jamais de « saut » de pose. |

Test à 2 joueurs : le joueur 2 voit les **animations** du joueur 1 (accroupi, glissade, escalade,
course penchée), avec un petit décalage normal (réseau).
Dans l'Output, **aucune ligne rouge**. S'il y en a : copie-les-moi avec le numéro du test.
