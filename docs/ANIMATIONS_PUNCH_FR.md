# Les 4 coups de base (M1) : Motifect → R6

Les 4 coups du combo M1 (`Brawler_M1_1` à `Brawler_M1_4` dans
`src/client/Animation/CombatClips.luau`, communs à tous les kits) sont générés par
`tools/anim/motifect_retarget.py`. Le **jab** et le **crochet** (main gauche) viennent du
**Motifect Combat Motion Pack** (40 animations FBX faites pour Unreal), adaptées au R6. Le **direct**
et le **coup final** (main droite) sont maintenant **posés à la main**, image clé par image clé
(voir « Direct et coup final : un vrai coup de poing, pas une claque » à la fin).

## Les animations choisies

| Coup | Animation Motifect | Images | Pourquoi |
|---|---|---|---|
| M1_1 jab gauche | `jab_right` **en miroir** (la garde du pack est inversée) | 5 → 23,5, impact 11,2 | Le jab le plus droit et le plus rapide du pack, il part presque dans l'axe. Testé contre `jab_left` : même rendu, mais plus lent à l'impact. |
| M1_2 direct droit | aucune : posé à la main (voir la fin) | — | Les versions Motifect puis « bras lancé en arrière » ne marchaient pas (claque). |
| M1_3 crochet gauche | `hook_left` (haut du corps seulement) | 14 → 29,7, impact 28,6 | Le crochet le plus rapide : le poing sort puis balaie à hauteur de tête. On coupe le suivi qui s'enroule derrière la tête et on revient en garde. |
| M1_4 finisher | aucune : posé à la main (voir la fin) | — | `cross_right` est un swing bras tendu (lu comme une claque en R6). |

L'ordre des mains reste gauche-droite-gauche-droite : les réactions (`HitJab`, `HitCross`,
`HitHook`, `HitHeavy`) et le côté où la tête part n'ont pas changé.

## Comment c'est adapté au R6
Le R6 n'a ni coude ni genou, et le jeu impose le moment de l'impact (**0,15 s** pour le jab et le
crochet, **0,28 s** et **0,38 s** pour le direct et le coup final, qui sont chargés). Le script :
- vise le **poing** (pas l'os du bras) : le trajet du poing Motifect est recalé pour partir du poing
  de la Garde et arriver au même point d'impact que les anciens coups (dans la hitbox) ;
- reprend la rotation du torse (mise à l'échelle : jab −35°, direct +40°, crochet −49°, finisher +50°),
  une petite fente vers l'avant, la tête qui reste sur la cible, l'autre poing au menton ;
  après l'impact le torse continue de tourner de quelques degrés (2–5°, 14° sur le finisher : le poids
  passe à travers la cible) ;
- garde le crochet à hauteur de tête : son arc s'élargit sur les côtés, mais pas vers le bas ;
- plante les pieds au sol (genou simulé), sans glisser ;
- ajoute une vraie **prise d'élan** avant chaque coup (voir plus bas), puis fait partir le coup en chaîne,
  du bas vers le poing, de plus en plus vite jusqu'au contact ;
- arrête le poing net sur la cible (le hit-stop fige une pose propre), puis le ramène en douceur ;
- commence et finit **exactement** en pose de Garde (le combo s'enchaîne 0,38 s après le jab et le
  crochet, 0,48 s après le direct ; voir plus bas la rotation du torse gardée jusqu'au clic suivant).

## Préparation et transfert de poids
Les boxeurs du pack Motifect ne « télégraphient » presque pas (7° de contre-rotation au plus, le poing
ne recule jamais) : en 0,15 s le bras partait directement. Le script ajoute donc, **par-dessus** la mocap
(réglages `windup` de chaque coup dans `SPECS`) une petite prise d'élan réaliste. C'est ce que font le
**jab et le crochet**. Le direct et le coup final sont posés à la main (voir la dernière partie).

1. **Préparation (0 → 0,067 s, 4 images)** : le torse tourne à l'envers du coup, le poids descend et
   recule vers la jambe qui charge (les genoux plient), l'épaule recule, le poing revient vers le menton
   (sur un bras R6 rigide, un poing plus près de l'épaule = un coude replié), le menton rentre, l'autre
   poing reste en garde. La pose chargée est presque tenue une image (le poing bouge de 1 à 4 studs/s).
2. **Frappe (0,08 → 0,15 s)** : chaque partie lâche sa charge l'une après l'autre : jambes et poids
   d'abord, puis la rotation du torse, l'épaule, et le bras en dernier. Un bras R6 est un seul bloc : le
   poing ne peut pas « rester derrière » pendant que l'épaule avance (le bras glisserait dans l'épaule).
   Le bras, encore plié, est donc d'abord **porté par le corps qui tourne**, puis il se déplie : pour le
   jab, le poing est calculé depuis l'épaule (le bras pivote vers la cible et
   s'allonge, de plus en plus vite). La vitesse du poing = celle du corps + celle du bras : elle
   **augmente à chaque image** jusqu'à l'impact, et l'épaule ne glisse pas plus d'environ 0,3 stud par image.
   Le crochet garde son trajet « dehors, puis en travers ».
3. **Après l'impact** : le poing reste sur la cible pendant que le torse continue de tourner de quelques
   degrés et que le poids s'enfonce un peu (rien ne se fige pendant le hit-stop).
4. **Récupération** : le bras revient d'abord, le torse ensuite. Pour M1_1 à M1_3, la rotation du torse
   s'arrête à 7° de la Garde, du côté où le coup est parti, jusqu'à 0,38 s : dans le combo, la prise
   d'élan du coup suivant continue dans ce sens (la fin du jab = l'armé du direct, la fin du direct =
   l'armé du crochet…), donc le torse ne fait plus d'aller-retour au moment du clic. La pose est
   exactement la Garde à la fin du clip.

| Coup | Préparation (pose chargée à 0,05–0,067 s) | Vitesse du poing, 5 dernières images (studs/s) |
|---|---|---|
| Jab (M1_1) | torse 13° à l'envers, épaule avant qui plonge, poing 0,38 stud en arrière, le poids recule vers la jambe arrière | 5 → 12 → 23 → 25 → 29 |
| Direct (M1_2) | posé à la main (voir la fin) | — |
| Crochet (M1_3) | torse enroulé 15° à droite sur la jambe avant, coude et poing écartés et bas | 4 → 8 → 21 → 24 → 39 |
| Finisher (M1_4) | posé à la main (voir la fin) | — |

Tout reste réaliste (amplitudes 1,5 à 2× les vraies, bien en dessous d'un style cartoon). Ce qui ne
change pas pour le jab et le crochet : impact à 0,15 s, durées, ordre des mains, poing au même point
d'impact, pieds au sol.

## Régénérer
```
python3 -m venv venv && venv/bin/pip install bpy numpy scipy
venv/bin/python -I tools/anim/motifect_dump.py <dossier dump> <fichiers .fbx du pack>
venv/bin/python -I tools/anim/motifect_retarget.py <dossier dump> --write
stylua src
```
Les réglages de chaque coup (images, vitesse, point d'impact, rotation…) sont dans `SPECS`, en haut
de `tools/anim/motifect_retarget.py`. Ne modifie pas les images clés à la main : relance le script.

## Ce qui n'a PAS changé
Les coups des kits (Street Brawler, Boxer, Bouncer, Sentinel, Rift), la Garde, le blocage, les
réactions, les VFX, les sons, les dégâts, les hitbox et les timings de `Config`
(à l'époque `HIT_DELAY` 0,15 s, `M1_INTERVAL` 0,38 s). Seuls les 4 blocs `Brawler_M1_N` ont été remplacés.

## Coups chargés (direct du droit et coup final)
Les deux coups du bras droit (le **direct**, coup 2, et le **coup final**, coup 4) prennent de
l'élan (le corps se charge avant de frapper), donc ils **touchent plus tard** : 0,28 s et 0,38 s après le clic au lieu
de 0,15 s. C'est voulu : l'élan doit avoir le temps de se voir. Le jab et le crochet (coups 1 et 3)
touchent toujours à 0,15 s. Les dégâts et la hitbox arrivent au moment de l'impact, c'est toujours le
serveur qui décide. Les timings sont maintenant **par coup** dans `Config.Combat` :

| Coup | Impact (`M1_HIT_DELAY`) | Coup suivant possible (`M1_INTERVAL` / `FINISHER_RECOVERY`) |
|---|---|---|
| 1 jab (gauche) | 0,15 s | 0,38 s |
| 2 direct (droit, chargé) | 0,28 s | 0,48 s |
| 3 crochet (gauche) | 0,15 s | 0,38 s |
| 4 coup final (droit, chargé) | 0,38 s | 1,23 s (toujours 0,85 s après l'impact) |

- Le « whoosh » : tout de suite au clic pour le jab et le crochet ; pour les coups chargés, rien
  pendant l'élan, puis il part 0,1 s avant l'impact (`M1_SWING_LEAD`), quand le bras frappe
  (0,18 s pour le direct, 0,28 s pour le coup final).
- Le combo reste inévitable : quand tu lances le coup suivant, la victime du coup d'avant reste
  sonnée jusqu'à l'impact + 0,1 s (`COMBO_HOLD_MARGIN`). Si ce coup ne la touche **pas** (raté,
  annulé parce que l'attaquant s'est fait frapper, ou dash), ce temps de sonné en plus lui est
  **rendu** tout de suite : on ne peut pas s'en servir pour bloquer quelqu'un sans le toucher.
- **Dash pendant l'élan = coup annulé** : avant, un coup lancé puis suivi d'un dash touchait quand
  même depuis l'endroit d'arrivée du dash (jusqu'à 18 studs plus loin). Maintenant le dash annule le
  coup qui n'a pas encore touché (sur le serveur et à l'écran), et on peut de nouveau bloquer. Ça
  permet aussi de feinter un coup chargé avec un dash. Si tu préfères « pas de dash tant que le poing
  n'a pas touché », c'est un petit changement dans `tryDash` (serveur et client).
- Hors combo, un coup chargé se voit venir : l'adversaire peut le couper avec un jab, l'esquiver
  (dash) ou le bloquer / parer (surtout le coup final).

## Direct et coup final : un vrai coup de poing, pas une claque
Tu trouvais que le bras partait beaucoup trop loin en arrière et que ça ressemblait à une **claque**.
Les deux coups du bras droit ont été refaits entièrement (le jab et le crochet n'ont pas bougé : leurs
blocs sont identiques à l'octet près).

### Pourquoi ça faisait une claque
Un bras R6 est un seul bloc rigide, sans coude. L'ancienne version lançait le bras tendu loin derrière
le dos (poing à ~2,5 studs derrière le corps, ou derrière la tête), puis le ramenait en le faisant
**tourner autour de l'épaule**. Le poing décrivait alors un grand **arc** (balayage de côté de 2,7 à
3 studs) et il se déplaçait **perpendiculairement au bras** (70 à 120° entre le bras et la direction du
poing) : c'est exactement la signature d'une claque ou d'un revers. Un vrai coup de poing fait
l'inverse : le poing va **en ligne droite** vers la cible et le bras **s'aligne** sur cette ligne (il
s'allonge dans son propre axe). En plus, tout partait en même temps (le corps et le bras sur la même
image) et les 2 dernières images bougeaient de 73° (un « saut » de pose).

### Les principes utilisés
- **Anticipation** : l'élan est dans le **corps**, pas dans le bras. Le torse tourne à l'envers du coup
  (13° de plus que la Garde pour le direct, 20° pour le coup final : assez pour se lire, pas assez pour
  « télégraphier »), le poids s'assoit sur la jambe arrière, le menton rentre, et le poing vient
  seulement **contre la joue**. Le poing ne passe **jamais** derrière le corps.
- **Faux coude** : comme le R6 n'a pas de coude, le bras **glisse dans son propre axe** (décalage de
  l'épaule) : rentré pendant l'armé (coude plié), poussé vers l'avant à l'impact (bras tendu). Le
  glissement est limité à ~0,4 stud au contact (0,3 pendant le suivi) et il se défait **en premier**
  au retour, pour que le bras ne semble jamais sortir de la poitrine vu de profil.
- **Timing** : armé → charge qui bouge encore un peu (le torse continue de s'enrouler et de
  s'asseoir : jamais de pose figée) → les **hanches et le torse partent d'abord**, le poing attend
  2 images (coude encore plié) → le poing part en **ligne droite**, de plus en plus vite, **le plus
  rapide au contact** (on ne ralentit jamais avant de toucher).
- **Arcs** : le corps tourne sur un arc naturel, mais le poing, lui, suit une ligne droite (rectitude
  0,99) : c'est ça qui fait un coup de poing.
- **Pas de toupie** : le torse s'arrête presque **face à la cible** au contact (20° de l'autre côté
  de la Garde, 24° au maximum du suivi pour le direct ; 22 et 30° pour le coup final), au lieu de
  tourner 40° plus loin. Une grosse rotation se lisait, depuis la caméra de jeu, comme « le perso
  tourne et balance un bras ». L'allonge vient d'un **pas vers l'avant** (le poids passe sur la jambe
  avant) plutôt que de la rotation.
- **La main avant reste au menton** : elle est accrochée à la **tête** (que le cou garde tournée vers
  la cible), pas au torse. Elle ne part plus sur le côté quand le torse tourne (balayage 0,6 / 0,9
  stud au lieu de 1,8 / 2,1) : depuis la caméra de jeu, c'est bien le poing qui frappe qu'on voit
  bouger, pas l'autre bras.
- **Follow-through / chevauchement** : après l'impact, le poing pousse encore un peu dans la même
  ligne et s'arrête en ~0,04 s (il ne reste pas figé bras tendu : le jeu ajoute déjà son hit-stop), le
  torse continue de tourner en ralentissant, la tête se pose **2 à 3 images après** le corps, et la
  main avant arrive au menton après le torse. Rien ne s'arrête sur la même image.
- **Hauteur de frappe** : le haut de la poitrine, juste sous le menton de l'adversaire, un peu à
  droite de la tête de l'attaquant (le bras reste visible depuis la caméra de jeu). Sur un R6,
  l'épaule pivote à hauteur de poitrine : viser la tête obligerait le bras à pointer vers le haut
  (un uppercut), et un poing qui descend pendant que le bras monte redevient un geste de balayage.
- **Coup final différent du direct** : charge plus profonde et plus longue, assis plus bas, plus
  grand pas en avant, le poing part de l'accroupi sur une ligne droite **légèrement montante**, le
  corps continue de tourner et de s'enfoncer plus longtemps après l'impact, récupération plus lourde.

### Les chiffres (ancien → nouveau)
| | Direct ancien | **Direct nouveau** | Final ancien | **Final nouveau** |
|---|---|---|---|---|
| Angle bras / direction du poing avant l'impact (punch ≈ 0–30°, claque ≈ 70–90°) | 70–122° | **22–30°** | 59–117° | **18–29°** |
| Trajet du poing (1 = ligne droite) | 0,76 | **0,99** | 0,57 | **0,99** |
| Balayage de côté du poing | 2,5 studs | **0,54** | 3,2 studs | **0,74** |
| Balayage de côté de la main avant | — | **0,64** | — | **0,91** |
| Rotation du torse (armé → contact → fin du suivi) | — | **+25° → −20° → −24°** | — | **+33° → −22° → −30°** |
| Poing derrière le dos | jusqu'à 2 studs | **jamais** (≥ 1,4 devant) | jusqu'à 2,3 | **jamais** (≥ 1,3 devant) |
| Bloc du bras derrière le dos (Garde : 0,19) | 2,3 studs | **0,51** | 2,5 studs | **0,77** |
| Glissement du bras (faux coude) au contact | — | **0,40 stud** | — | **0,31 stud** |
| Vitesse du poing, dernières images (studs/s) | jusqu'à 170 (flou) | 12 → 21 → 30 → **39** | jusqu'à 150 | 9 → 22 → 37 → **50** |
| Plus grand saut entre 2 images | 73° | **9°** | 73° | **13°** |
| Retour en Garde | ~0,45 s | **0,46 s** (le crochet part à 0,48 s) | ~0,9 s | **0,81 s** |
| Durée du clip | 0,6 s | **0,55 s** | 1,08 s | **0,95 s** |

Impacts inchangés : 0,28 s et 0,38 s (`Config.Combat.M1_HIT_DELAY`). Les hitbox, dégâts, VFX, sons et
timings ne changent pas. Dans le combo complet (clics à 0 / 0,38 / 0,86 / 1,24 s), le plus grand saut
est maintenant celui du crochet, inchangé (20,5° par image), contre 73° avant.

### Réglages
Dans `tools/anim/motifect_retarget.py` : `CROSS_KEYS` (direct) et `FINISHER_KEYS` (coup final). Chaque
pose clé du corps est commentée (anticipation, armé, charge, hanches d'abord, contact, suivi,
récupération), avec le plan du poing (`fist` : armé, départ, point d'impact, accélération, poussée
après l'impact), la main avant (`lead`, accrochée à la tête) et les retards (`lag` pour le buste,
`head_lag` pour la tête). Relance le script avec `--write`, puis `stylua src`.
À vérifier dans Studio, caméra libre : le glissement du bras dans l'épaule (faux coude, ~0,4 stud au
plus au contact) doit rester caché par le torse.
