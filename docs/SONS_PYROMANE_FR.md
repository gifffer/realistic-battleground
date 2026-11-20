# Sons du Pyromane

Chaque son du kit **Pyromane** (un *cue*) est fait de **une à cinq couches** jouées ensemble, chacune avec son propre son dans `src/shared/Sounds.luau` (section *Pyromaniac*, à la fin du fichier) et son moment de départ dans `src/shared/SoundCues.luau` (colonne *À*) :

| Couche | Rôle |
|---|---|
| `_Transient` | l'attaque : le tout premier instant, sec et court |
| `_Mechanism` | ce qui bouge : charnière, molette, liquide, verre |
| `_Body` | le cœur du son, ce qu'on reconnaît |
| `_Sub` | le grave, le poids (on le sent plus qu'on ne l'entend) |
| `_Tail` | la fin qui s'éteint |

Une couche dont les `ids` sont vides (`{}`) est **muette** (aucune erreur).

## Les sons en place (boutique Roblox, mesurés)

Chaque son du Pyromane utilise des **effets sonores gratuits et publics** du *Creator Store* de Roblox, tous de **Pro Sound Effects** (`ProSoundEffects`, créateur vérifié : la bibliothèque sous licence que Roblox offre à toutes les expériences). Il n'y a **rien à faire** : Rojo synchronise, *Play*.

**Comment ils ont été choisis.** Chaque candidat a été téléchargé et **mesuré** (`tools/sounds/ears.py`) : sonie (LUFS), crête, blanc au début, montée, brillance, part de 2-5 kHz (ce qui « pique »), part de grave sous 150 Hz (inaudible sur téléphone), et pour les boucles la stabilité du niveau et la soudure fin → début. On garde ceux qui partent net, ne saturent pas et ne piquent pas, puis :

- **le blanc au début est coupé** pour chaque fichier (`start`), et pour les sons calés sur un coup, le début est réglé pour que **le pic tombe sur l'image du coup** (« pic à +0,03 s ») ;
- **chaque fichier est ramené au même niveau** que ses variantes (`gain`) : plus de variante 12 dB plus forte qu'une autre ;
- **chaque son a son niveau cible** (colonne *Cible*) : le briquet discret, le lancer moyen, le Molotov et l'embrasement les plus forts, les boucles en dessous ;
- **2 à 4 variantes** pour les sons fréquents, jamais la même deux fois de suite, avec une petite variation de hauteur (± 3-8 %) et de volume (± 1,5 dB) ;
- **les boucles** sont longues (36-56 s), stables, et passent d'un tour au suivant **en fondu enchaîné** (pas de clic) ; elles démarrent à un endroit au hasard et **entrent en fondu** pendant que l'explosion qui les lance s'éteint ;
- tous les sons du Pyromane passent dans un **groupe de mix** (compresseur doux + aigus un peu baissés) : quand le verre, l'explosion, la flaque et les cris tombent ensemble, ça reste lisible et ça ne sature pas.

Colonnes : *Durée* du fichier ; *I* sonie moyenne (LUFS) ; *Max* sonie maximale sur 0,4 s du morceau joué ; *Crête* (dBFS) ; *Blanc* coupé au début (s) ; *Montée* jusqu'au pic (s) ; *Brillance* (Hz) ; *2-5k* et *<150* les parts d'énergie ; *Gain* le volume propre au fichier ; *Niveau* final (Max + volume + gain). Pour une boucle, *Max* est remplacé par la stabilité (écart-type du niveau, dB) et la soudure (saut de niveau fin → début, dB).

| Son | Couche | À | ID | Nom sur la boutique | Pourquoi | Durée | I | Max | Crête | Blanc | Montée | Brillance | 2-5k | <150 | Gain | Niveau | Cible | Réglage |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`ZippoOpen`](#zippoopen) | `_Body` | 0,00 s | `9121005566` | Zippo Lighter 1 (SFX) | le « clink » du couvercle, net, sans blanc | 0,45 s | −28,5 | −28,5 | −4,8 | 0,03 | 0,03 | 5920 | 0,43 | 0,01 | 1,00 | −26,0 | −26 Max | `volume` 1,33 |
| [`ZippoStrike`](#zippostrike) | `_Body` | 0,00 s | `9121005779` | Zippo Lighter 3 (SFX) | la molette puis le « fff » de la mèche | 0,69 s | −32,5 | −30,9 | −11,7 | 0,02 | 0,14 | 314 | 0,01 | 0,32 | 1,00 | −24,0 | −24 Max | `volume` 2,21 |
|  | `_Tail` | 0,12 s | `9114446183` | Fire Whoosh 2 (SFX) | petit souffle doux : la mèche qui prend | 0,72 s | −33,7 | −32,9 | −15,8 | 0,15 | 0,26 | 241 | 0,00 | 0,54 | 1,26 | −32,9 | −33 Max | `volume` 0,79 |
|  |  |  | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 0,79 | −33,0 |  |  |
| [`ZippoClose`](#zippoclose) | `_Body` | 0,00 s | `9121005783` | Zippo Lighter 5 (SFX) | un « clac » sec : le couvercle refermé | 0,71 s | −24,6 | −24,5 | −2,1 | 0,07 | 0,01 | 8398 | 0,29 | 0,00 | 1,00 | −27,0 | −27 Max | `volume` 0,75 |
| [`MolotovThrow`](#molotovthrow) | `_Body` | 0,00 s | `9114463219` | Flame Licks 8 (SFX) | torche qui passe : la flamme du chiffon qui file | 1,69 s | −20,4 | −17,7 | −5,9 | 0,19 | 0,37 | 206 | 0,00 | 0,56 | 1,00 | −20,9 | −21 Max | `volume` 0,69, coupé à 1,40 s, fondu 0,30 s |
|  |  |  | `9114463410` | Flame Licks 10 (SFX) | variante | 1,93 s | −20,5 | −17,4 | −5,6 | 0,19 | 0,61 | 222 | 0,00 | 0,48 | 0,96 | −21,0 |  |  |
|  |  |  | `9114463208` | Flame Licks 7 (SFX) | variante | 1,73 s | −20,2 | −17,6 | −7,3 | 0,20 | 0,15 | 169 | 0,00 | 0,66 | 0,99 | −20,9 |  |  |
|  |  |  | `9114463016` | Flame Licks 4 (SFX) | variante, plus grave | 1,89 s | −21,2 | −18,2 | −7,2 | 0,19 | 0,44 | 145 | 0,00 | 0,70 | 1,06 | −20,9 |  |  |
| [`FuelIgnite`](#fuelignite) | `_Body` | 0,00 s | `9114429507` | Fire Burst 1 (SFX) | boule de feu qui part d'un coup (pas une montée lente) | 8,67 s | −16,8 | −9,9 | −2,2 | 0,05 | 0,08 | 353 | 0,02 | 0,73 | 1,03 | −13,0 | −13 Max | `volume` 0,68, coupé à 2,20 s, fondu 1,00 s |
|  |  |  | `9114429835` | Fire Burst 8 (SFX) | variante, plus grave | 8,81 s | −14,3 | −9,4 | −1,6 | 0,15 | 0,07 | 147 | 0,00 | 0,75 | 0,97 | −13,0 |  |  |
|  |  |  | `9114429958` | Fire Burst 12 (SFX) | variante, plus claire | 8,94 s | −16,3 | −9,8 | −1,8 | 0,24 | 0,08 | 604 | 0,06 | 0,67 | 1,02 | −13,0 |  |  |
|  |  |  | `9114429740` | Fire Burst 5 (SFX) | variante | 8,77 s | −16,1 | −9,4 | −2,1 | 0,25 | 0,08 | 161 | 0,01 | 0,79 | 0,97 | −13,0 |  |  |
|  | `_Sub` | 0,00 s | `9114554567` | Gas Fire Explosion 3 (SFX) | le « whoump » grave de l'essence | 4,03 s | −10,8 | −8,6 | −3,5 | 0,00 | 0,17 | 290 | 0,02 | 0,72 | 1,00 | −21,0 | −21 Max | `volume` 0,24, `pitch` 0,80, coupé à 1,50 s, fondu 0,50 s |
| [`PoolFire`](#poolfire) | `_Body` | 0,00 s | `9112780561` | Fire Whoosh 1 (SFX) | kérosène qui brûle au sol, 49 s, niveau stable, sans crépitement fort | 49,01 s | −31,3 | σ 2,0 / soudure 0,9 | −13,9 | 0,00 | 11,13 | 258 | 0,00 | 0,45 | 1,00 | −25,0 | −25 I | `volume` 2,07 |
|  | `_Mechanism` | 0,00 s | `9112780462` | Fireplace Constant Burning Flame 4 (SFX) | crépitement de feu de bois, 43 s : le grain sous la flaque | 42,75 s | −42,3 | σ 2,4 / soudure 1,1 | −5,1 | 0,00 | 5,33 | 2772 | 0,03 | 0,55 | 1,00 | −31,0 | −31 I | `volume` 3,67 |
| [`FireBreath`](#firebreath) | `_Transient` | 0,00 s | `9114446277` | Fire Whoosh 6 (SFX) | jet de kérosène à travers une torche (« lance-flammes ») | 1,50 s | −20,0 | −19,7 | −5,8 | 0,23 | 0,08 | 1432 | 0,05 | 0,05 | 1,14 | −19,0 | −19 Max | `volume` 0,95, pic à +0,08 s |
|  |  |  | `9114441555` | Fire Whoosh 8 (SFX) | variante, plus courte | 1,86 s | −16,3 | −17,4 | −2,7 | 0,72 | 0,06 | 1562 | 0,01 | 0,37 | 0,88 | −19,0 |  |  |
|  | `_Body` | 0,05 s | `9117984812` | Pyro Fire Ball Burst 1 (SFX) | long jet de feu (pyrotechnie de cinéma) | 3,00 s | −17,4 | −13,2 | −1,0 | 0,22 | 0,32 | 483 | 0,02 | 0,44 | 0,59 | −15,0 | −15 Max | `volume` 1,37, coupé à 0,75 s, fondu 0,30 s |
|  |  |  | `9117985848` | Pyro Fire Ball Burst 6 (SFX) | variante | 2,56 s | −23,4 | −19,8 | −4,8 | 0,25 | 0,11 | 254 | 0,01 | 0,54 | 1,27 | −15,0 |  |  |
|  |  |  | `9117985933` | Pyro Fire Ball Burst 7 (SFX) | variante, plus sèche | 1,93 s | −23,1 | −20,2 | −3,2 | 0,22 | 0,09 | 186 | 0,01 | 0,71 | 1,33 | −15,0 |  |  |
|  | `_Tail` | 0,60 s | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 1,00 | −29,0 | −29 Max | `volume` 0,99, coupé à 1,00 s, fondu 0,30 s |
| [`FuelSplash`](#fuelsplash) | `_Body` | 0,00 s | `9125702439` | Mud Puddle Splash Shallow Water Impacts Hits (SFX) | l'essence qui gicle au sol | 0,88 s | −32,6 | −30,5 | −10,6 | 0,00 | 0,27 | 1560 | 0,19 | 0,07 | 0,91 | −20,0 | −20 Max | `volume` 3,69 |
|  |  |  | `9125702803` | Mud Puddle Splash Shallow Water Impacts Hits (SFX) | variante | 0,78 s | −35,4 | −32,2 | −10,3 | 0,00 | 0,05 | 1089 | 0,10 | 0,37 | 1,10 | −20,0 |  |  |
|  | `_Mechanism` | 0,00 s | `9126173160` | Water Burst Movement Out Of Liquid Splashing (SFX) | le liquide qui part d'un coup | 6,56 s | −28,6 | −20,9 | −11,7 | 0,14 | 0,42 | 1638 | 0,16 | 0,21 | 1,00 | −22,0 | −22 Max | `volume` 0,88, coupé à 1,00 s, fondu 0,30 s |
| [`BodyBurn`](#bodyburn) | `_Body` | 0,00 s | `9112780438` | Fireplace Constant Burning Flame 2 (SFX) | feu qui brûle, régulier, 36 s (une boucle choisie par corps) | 36,01 s | −40,6 | σ 1,8 / soudure 3,8 | −2,6 | 0,00 | 34,30 | 997 | 0,01 | 0,74 | 0,87 | −29,0 | −29 I | `volume` 4,35 |
|  |  |  | `9112780212` | Fireplace Constant Burning Flame 3 (SFX) | variante, plus de crépitements | 36,01 s | −42,5 | σ 2,0 / soudure 2,1 | −4,9 | 0,00 | 30,96 | 1804 | 0,02 | 0,65 | 1,09 | −29,0 |  |  |
|  |  |  | `9112780193` | Fireplace Constant Burning Flame 1 (SFX) | variante, plus sourde | 36,01 s | −42,2 | σ 2,1 / soudure −0,5 | −3,3 | 0,00 | 11,12 | 729 | 0,00 | 0,71 | 1,05 | −29,0 |  |  |
| [`SelfIgnite`](#selfignite) | `_Mechanism` | 0,00 s | `9114446277` | Fire Whoosh 6 (SFX) | jet de kérosène à travers une torche (« lance-flammes ») | 1,50 s | −20,0 | −19,6 | −5,8 | 0,21 | 0,10 | 1432 | 0,05 | 0,05 | 1,20 | −20,0 | −20 Max | `volume` 0,80, pic à +0,10 s |
|  |  |  | `9114441555` | Fire Whoosh 8 (SFX) | variante, plus courte | 1,86 s | −16,3 | −16,5 | −2,7 | 0,70 | 0,10 | 1562 | 0,01 | 0,37 | 0,84 | −20,0 |  |  |
|  | `_Body` | 0,00 s | `9117983605` | Pyro Fire Ball Burst 9 (SFX) | boule de feu courte et grave | 1,48 s | −18,6 | −16,8 | −0,2 | 0,22 | 0,12 | 111 | 0,01 | 0,93 | 0,98 | −16,0 | −16 Max | `volume` 1,12, pic à +0,20 s |
|  |  |  | `9117983322` | Pyro Fire Ball Burst 6 (SFX) | variante | 1,44 s | −20,2 | −18,5 | −0,4 | 0,21 | 0,11 | 176 | 0,01 | 0,86 | 1,19 | −16,0 |  |  |
|  |  |  | `9117986652` | Pyro Fire Ball Burst 7 (SFX) | variante | 1,50 s | −17,5 | −15,7 | −0,2 | 0,37 | 0,20 | 107 | 0,00 | 0,98 | 0,86 | −16,0 |  |  |
| [`BodyIgnite`](#bodyignite) | `_Body` | 0,00 s | `9114429835` | Fire Burst 8 (SFX) | variante, plus grave | 8,81 s | −14,3 | −9,1 | −1,6 | 0,19 | 0,05 | 147 | 0,00 | 0,75 | 0,97 | −12,0 | −12 Max | `volume` 0,74, coupé à 3,00 s, fondu 1,20 s, pic à +0,04 s |
|  |  |  | `9114429507` | Fire Burst 1 (SFX) | boule de feu qui part d'un coup (pas une montée lente) | 8,67 s | −16,8 | −9,7 | −2,2 | 0,10 | 0,04 | 353 | 0,02 | 0,73 | 1,04 | −12,0 |  |  |
|  | `_Sub` | 0,00 s | `9114554567` | Gas Fire Explosion 3 (SFX) | le « whoump » grave de l'essence | 4,03 s | −10,8 | −8,6 | −3,5 | 0,00 | 0,17 | 290 | 0,02 | 0,72 | 1,00 | −20,0 | −20 Max | `volume` 0,27, `pitch` 0,80, coupé à 1,50 s, fondu 0,50 s |
|  | `_Tail` | 0,15 s | `9119165650` | Sizzle Short And Explosive Sear 4 (SFX) | saisie qui grésille : la chair qui brûle | 1,36 s | −23,3 | −20,3 | −3,1 | 0,18 | 0,02 | 12789 | 0,12 | 0,02 | 1,41 | −22,0 | −22 Max | `volume` 0,58 |
|  |  |  | `9119166424` | Sizzle Short And Explosive Sear 11 (SFX) | grésillement court | 1,81 s | −17,8 | −14,3 | −1,5 | 0,16 | 0,07 | 12232 | 0,09 | 0,01 | 0,71 | −22,0 |  |  |
| [`BurnScream`](#burnscream) | `_Body` | 0,00 s | `9116454870` | Male Screams In Pain Injury Yells Agony 1 (SFX) | homme qui hurle de douleur | 2,37 s | −27,2 | −23,6 | −11,8 | 0,11 | 0,26 | 1170 | 0,03 | 0,00 | 2,01 | −15,0 | −15 Max | `volume` 1,34, coupé à 1,40 s, fondu 0,15 s |
|  |  |  | `9125652466` | Male Scream Short Yelling Bursts Death Cries (SFX) | cri d'agonie bref | 1,42 s | −18,3 | −16,4 | −1,0 | 0,06 | 0,15 | 631 | 0,02 | 0,01 | 0,88 | −15,0 |  |  |
|  |  |  | `9125652432` | Male Scream Short Yelling Bursts Death Cries (SFX) | variante | 1,11 s | −14,6 | −12,6 | −1,3 | 0,07 | 0,10 | 947 | 0,01 | 0,00 | 0,57 | −14,9 |  |  |
| [`InfernoBreath`](#infernobreath) | `_Transient` | 0,00 s | `9114446277` | Fire Whoosh 6 (SFX) | jet de kérosène à travers une torche (« lance-flammes ») | 1,50 s | −20,0 | −19,7 | −5,8 | 0,23 | 0,08 | 1432 | 0,05 | 0,05 | 1,14 | −18,0 | −18 Max | `volume` 1,07, pic à +0,08 s |
|  |  |  | `9114441555` | Fire Whoosh 8 (SFX) | variante, plus courte | 1,86 s | −16,3 | −17,4 | −2,7 | 0,72 | 0,06 | 1562 | 0,01 | 0,37 | 0,88 | −17,9 |  |  |
|  | `_Body` | 0,05 s | `9117984812` | Pyro Fire Ball Burst 1 (SFX) | long jet de feu (pyrotechnie de cinéma) | 3,00 s | −17,4 | −13,2 | −1,0 | 0,22 | 0,32 | 483 | 0,02 | 0,44 | 0,59 | −14,0 | −14 Max | `volume` 1,54, coupé à 0,95 s, fondu 0,35 s |
|  |  |  | `9117985848` | Pyro Fire Ball Burst 6 (SFX) | variante | 2,56 s | −23,4 | −19,8 | −4,8 | 0,25 | 0,11 | 254 | 0,01 | 0,54 | 1,27 | −14,0 |  |  |
|  |  |  | `9117985933` | Pyro Fire Ball Burst 7 (SFX) | variante, plus sèche | 1,93 s | −23,1 | −20,2 | −3,2 | 0,22 | 0,09 | 186 | 0,01 | 0,71 | 1,33 | −14,0 |  |  |
|  | `_Tail` | 0,80 s | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 1,00 | −28,0 | −28 Max | `volume` 1,11, coupé à 1,00 s, fondu 0,30 s |
| [`FireSwing`](#fireswing) | `_Body` | 0,00 s | `9114462915` | Flame Licks 1 (SFX) | torche agitée qui passe | 1,92 s | −22,6 | −19,7 | −9,5 | 0,45 | 0,12 | 183 | 0,00 | 0,55 | 1,05 | −20,0 | −20 Max | `volume` 0,92, coupé à 1,00 s, fondu 0,30 s, pic à +0,12 s |
|  |  |  | `9114462930` | Flame Licks 3 (SFX) | variante | 1,80 s | −22,2 | −19,3 | −6,5 | 0,40 | 0,12 | 159 | 0,00 | 0,67 | 1,01 | −19,9 |  |  |
|  |  |  | `9114463010` | Flame Licks 5 (SFX) | variante | 1,66 s | −22,4 | −19,5 | −9,4 | 0,25 | 0,12 | 221 | 0,00 | 0,50 | 1,03 | −20,0 |  |  |
|  |  |  | `9114463022` | Flame Licks 6 (SFX) | variante | 1,77 s | −21,2 | −18,5 | −9,1 | 0,49 | 0,12 | 170 | 0,00 | 0,63 | 0,92 | −19,9 |  |  |
| [`FireImpact`](#fireimpact) | `_Body` | 0,00 s | `9114443884` | Fire Whoosh 1 (SFX) | variante, plus grave | 0,72 s | −24,2 | −23,8 | −6,6 | 0,27 | 0,02 | 197 | 0,00 | 0,57 | 0,93 | −18,0 | −18 Max | `volume` 2,10, coupé à 0,80 s, fondu 0,20 s, pic à +0,02 s |
|  |  |  | `9114444052` | Fire Whoosh 5 (SFX) | variante, plus ronde | 1,29 s | −25,9 | −25,1 | −7,4 | 0,25 | 0,02 | 345 | 0,00 | 0,49 | 1,08 | −18,0 |  |  |
|  | `_Tail` | 0,02 s | `9119166424` | Sizzle Short And Explosive Sear 11 (SFX) | grésillement court | 1,81 s | −17,8 | −14,3 | −1,5 | 0,16 | 0,07 | 12232 | 0,09 | 0,01 | 0,88 | −22,0 | −22 Max | `volume` 0,47, coupé à 1,20 s, fondu 0,30 s |
|  |  |  | `9119166217` | Sizzle Short And Explosive Sear 9 (SFX) | variante | 2,13 s | −18,3 | −15,1 | −1,2 | 0,10 | 0,04 | 8545 | 0,12 | 0,04 | 0,97 | −21,9 |  |  |
|  |  |  | `9119165644` | Sizzle Short And Explosive Sear 2 (SFX) | variante | 2,69 s | −20,2 | −15,1 | −1,7 | 0,07 | 0,02 | 7587 | 0,05 | 0,03 | 0,97 | −21,9 |  |  |
|  |  |  | `9119166425` | Sizzle Short And Explosive Sear 13 (SFX) | variante | 1,43 s | −21,1 | −17,1 | −3,8 | 0,07 | 0,03 | 13783 | 0,07 | 0,03 | 1,22 | −21,9 |  |  |
| [`CatchFire`](#catchfire) | `_Body` | 0,00 s | `9114446183` | Fire Whoosh 2 (SFX) | petit souffle doux : la mèche qui prend | 0,72 s | −33,7 | −32,9 | −15,8 | 0,15 | 0,26 | 241 | 0,00 | 0,54 | 1,81 | −22,0 | −22 Max | `volume` 1,93 |
|  |  |  | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 1,14 | −22,1 |  |  |
|  |  |  | `9114462912` | Flame Licks 2 (SFX) | petite flamme qui passe, jouée plus aiguë | 1,59 s | −24,3 | −21,4 | −10,2 | 0,18 | 0,24 | 210 | 0,00 | 0,51 | 0,48 | −22,1 |  |  |
|  | `_Tail` | 0,10 s | `9119165912` | Sizzle Short And Explosive Sear 5 (SFX) | grésillement doux qui monte | 1,85 s | −18,5 | −16,7 | −5,9 | 0,06 | 0,63 | 16232 | 0,02 | 0,00 | 0,96 | −29,8 | −30 Max | `volume` 0,23 |
|  |  |  | `9119165930` | Sizzle Short And Explosive Sear 7 (SFX) | variante | 1,51 s | −19,2 | −17,4 | −8,3 | 0,03 | 0,57 | 15748 | 0,03 | 0,00 | 1,04 | −29,8 |  |  |
| [`Extinguish`](#extinguish) | `_Body` | 0,00 s | `9119166199` | Sizzle Short And Explosive Sear 8 (SFX) | grésillement qui retombe | 1,91 s | −19,4 | −16,2 | −2,0 | 0,08 | 0,06 | 12449 | 0,07 | 0,03 | 0,88 | −30,1 | −30 Max | `volume` 0,23, `pitch` 0,90, coupé à 1,20 s, fondu 0,40 s |
|  |  |  | `9119165933` | Sizzle Short And Explosive Sear 6 (SFX) | variante | 2,25 s | −20,5 | −18,4 | −6,9 | 0,11 | 0,07 | 16220 | 0,03 | 0,01 | 1,14 | −30,0 |  |  |
| [`PyreRoar`](#pyreroar) | `_Body` | 0,00 s | `9112780691` | Fire Whoosh 2 (SFX) | grondement de feu de kérosène, 56 s | 56,50 s | −33,2 | σ 4,3 / soudure −3,3 | −8,9 | 0,00 | 46,86 | 241 | 0,00 | 0,50 | 1,00 | −28,0 | −28 I | `volume` 1,82 |
| [`GunDraw`](#gundraw) | `_Body` | 0,00 s | `9114190682` | Drum Slosh Liquid Movement Small Splashes 1 (SFX) | liquide qui ballotte dans un fût | 3,85 s | −39,5 | −41,0 | −17,3 | 0,07 | 0,22 | 818 | 0,04 | 0,18 | 1,00 | −30,0 | −30 Max | `volume` 3,55, coupé à 0,40 s, fondu 0,15 s |
| [`PilotLight`](#pilotlight) | `_Body` | 0,00 s | `9121005783` | Zippo Lighter 5 (SFX) | un « clac » sec : le couvercle refermé | 0,71 s | −24,6 | −24,5 | −2,1 | 0,07 | 0,01 | 8398 | 0,29 | 0,00 | 1,00 | −32,0 | −32 Max | `volume` 0,42, `pitch` 1,30 |
|  | `_Tail` | 0,05 s | `9114446183` | Fire Whoosh 2 (SFX) | petit souffle doux : la mèche qui prend | 0,72 s | −33,7 | −32,9 | −15,8 | 0,15 | 0,26 | 241 | 0,00 | 0,54 | 1,00 | −34,0 | −34 Max | `volume` 0,88 |
| [`PilotOut`](#pilotout) | `_Body` | 0,00 s | `9119166199` | Sizzle Short And Explosive Sear 8 (SFX) | grésillement qui retombe | 1,91 s | −19,4 | −16,2 | −2,0 | 0,08 | 0,06 | 12449 | 0,07 | 0,03 | 1,00 | −32,1 | −32 Max | `volume` 0,16, `pitch` 1,20, coupé à 0,40 s, fondu 0,15 s |
| [`TriggerClick`](#triggerclick) | `_Body` | 0,00 s | `9121005566` | Zippo Lighter 1 (SFX) | le « clink » du couvercle, net, sans blanc | 0,45 s | −28,5 | −28,5 | −4,8 | 0,03 | 0,03 | 5920 | 0,43 | 0,01 | 1,00 | −30,0 | −30 Max | `volume` 0,84, `pitch` 0,80 |
| [`BurstPop`](#burstpop) | `_Body` | 0,00 s | `9114442751` | Fire Whoosh 2 (SFX) | « pouf » de kérosène très court et franc | 1,15 s | −12,3 | −11,2 | −2,1 | 0,25 | 0,03 | 985 | 0,00 | 0,48 | 0,38 | −15,0 | −15 Max | `volume` 1,70, coupé à 1,00 s, fondu 0,30 s, pic à +0,03 s |
|  |  |  | `9114444052` | Fire Whoosh 5 (SFX) | variante, plus ronde | 1,29 s | −25,9 | −25,1 | −7,4 | 0,24 | 0,03 | 345 | 0,00 | 0,49 | 1,88 | −15,0 |  |  |
|  |  |  | `9114443884` | Fire Whoosh 1 (SFX) | variante, plus grave | 0,72 s | −24,2 | −23,8 | −6,6 | 0,26 | 0,03 | 197 | 0,00 | 0,57 | 1,62 | −15,0 |  |  |
|  |  |  | `9114444008` | Fire Whoosh 3 (SFX) | variante, plus sèche | 1,38 s | −19,2 | −18,3 | −3,6 | 0,62 | 0,03 | 299 | 0,00 | 0,54 | 0,86 | −15,0 |  |  |
|  | `_Tail` | 0,05 s | `9119166424` | Sizzle Short And Explosive Sear 11 (SFX) | grésillement court | 1,81 s | −17,8 | −14,3 | −1,5 | 0,16 | 0,07 | 12232 | 0,09 | 0,01 | 0,88 | −22,9 | −23 Max | `volume` 0,42, coupé à 1,20 s, fondu 0,30 s |
|  |  |  | `9119166217` | Sizzle Short And Explosive Sear 9 (SFX) | variante | 2,13 s | −18,3 | −15,1 | −1,2 | 0,10 | 0,04 | 8545 | 0,12 | 0,04 | 0,97 | −22,9 |  |  |
|  |  |  | `9119165644` | Sizzle Short And Explosive Sear 2 (SFX) | variante | 2,69 s | −20,2 | −15,1 | −1,7 | 0,07 | 0,02 | 7587 | 0,05 | 0,03 | 0,97 | −22,9 |  |  |
|  |  |  | `9119166425` | Sizzle Short And Explosive Sear 13 (SFX) | variante | 1,43 s | −21,1 | −17,1 | −3,8 | 0,07 | 0,03 | 13783 | 0,07 | 0,03 | 1,22 | −22,9 |  |  |
| [`GlobLaunch`](#globlaunch) | `_Transient` | 0,00 s | `9114446277` | Fire Whoosh 6 (SFX) | jet de kérosène à travers une torche (« lance-flammes ») | 1,50 s | −20,0 | −20,1 | −5,8 | 0,26 | 0,05 | 1432 | 0,05 | 0,05 | 1,14 | −20,0 | −20 Max | `volume` 0,89, coupé à 0,40 s, fondu 0,15 s, pic à +0,05 s |
|  |  |  | `9114441555` | Fire Whoosh 8 (SFX) | variante, plus courte | 1,86 s | −16,3 | −17,8 | −2,7 | 0,75 | 0,05 | 1562 | 0,01 | 0,37 | 0,88 | −19,9 |  |  |
|  | `_Body` | 0,00 s | `9114429507` | Fire Burst 1 (SFX) | boule de feu qui part d'un coup (pas une montée lente) | 8,67 s | −16,8 | −9,9 | −2,2 | 0,05 | 0,08 | 353 | 0,02 | 0,73 | 1,03 | −17,0 | −17 Max | `volume` 0,43, coupé à 0,50 s, fondu 0,20 s |
|  |  |  | `9114429835` | Fire Burst 8 (SFX) | variante, plus grave | 8,81 s | −14,3 | −9,4 | −1,6 | 0,15 | 0,07 | 147 | 0,00 | 0,75 | 0,97 | −17,0 |  |  |
| [`GlobSplat`](#globsplat) | `_Body` | 0,00 s | `9125702439` | Mud Puddle Splash Shallow Water Impacts Hits (SFX) | l'essence qui gicle au sol | 0,88 s | −32,6 | −30,5 | −10,6 | 0,00 | 0,27 | 1560 | 0,19 | 0,07 | 0,91 | −18,0 | −18 Max | `volume` 4,65 |
|  |  |  | `9125702803` | Mud Puddle Splash Shallow Water Impacts Hits (SFX) | variante | 0,78 s | −35,4 | −32,2 | −10,3 | 0,00 | 0,05 | 1089 | 0,10 | 0,37 | 1,10 | −18,0 |  |  |
| [`StreamEnd`](#streamend) | `_Tail` | 0,00 s | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 1,00 | −28,0 | −28 Max | `volume` 1,11, coupé à 1,00 s, fondu 0,40 s |
| [`PressureHiss`](#pressurehiss) | `_Body` | 0,00 s | `9126173160` | Water Burst Movement Out Of Liquid Splashing (SFX) | le liquide qui part d'un coup | 6,56 s | −28,6 | −20,9 | −11,7 | 0,14 | 0,42 | 1638 | 0,16 | 0,21 | 1,00 | −30,0 | −30 Max | `volume` 0,35, `pitch` 1,40, coupé à 0,80 s, fondu 0,30 s |
| [`ValveCrank`](#valvecrank) | `_Body` | 0,00 s | `9121005783` | Zippo Lighter 5 (SFX) | un « clac » sec : le couvercle refermé | 0,71 s | −24,6 | −24,5 | −2,1 | 0,07 | 0,01 | 8398 | 0,29 | 0,00 | 1,00 | −27,0 | −27 Max | `volume` 0,75, `pitch` 0,60 |
| [`TorchLance`](#torchlance) | `_Body` | 0,00 s | `9114446277` | Fire Whoosh 6 (SFX) | jet de kérosène à travers une torche (« lance-flammes ») | 1,50 s | −20,0 | −20,1 | −5,8 | 0,26 | 0,05 | 1432 | 0,05 | 0,05 | 1,14 | −18,0 | −18 Max | `volume` 1,12, `pitch` 1,25, coupé à 0,25 s, fondu 0,10 s, pic à +0,05 s |
|  |  |  | `9114441555` | Fire Whoosh 8 (SFX) | variante, plus courte | 1,86 s | −16,3 | −17,8 | −2,7 | 0,75 | 0,05 | 1562 | 0,01 | 0,37 | 0,88 | −17,9 |  |  |
| [`Vent`](#vent) | `_Body` | 0,00 s | `9119166199` | Sizzle Short And Explosive Sear 8 (SFX) | grésillement qui retombe | 1,91 s | −19,4 | −16,2 | −2,0 | 0,08 | 0,06 | 12449 | 0,07 | 0,03 | 0,88 | −25,9 | −26 Max | `volume` 0,37, `pitch` 0,80, coupé à 1,50 s, fondu 0,50 s |
|  |  |  | `9119165933` | Sizzle Short And Explosive Sear 6 (SFX) | variante | 2,25 s | −20,5 | −18,4 | −6,9 | 0,11 | 0,07 | 16220 | 0,03 | 0,01 | 1,14 | −25,9 |  |  |
|  | `_Tail` | 0,10 s | `9114445526` | Fire Whoosh 12 (SFX) | souffle doux et long : la flamme qui flotte, qui retombe | 1,38 s | −31,3 | −28,9 | −11,5 | 0,05 | 0,35 | 558 | 0,02 | 0,38 | 1,00 | −30,0 | −30 Max | `volume` 0,88, coupé à 1,50 s, fondu 0,50 s |

**Écartés après mesure** : *Zippo Lighter 2/4/6* (presque muets : un clic de 20 ms puis rien), *Fire Burst 2* et *11* (une montée lente : le pic arrive 1,3 s après la boule de feu), *Gas Fire Explosion 4* (un grondement plat et saturé, sans attaque), *Fire Whoosh 13* (9114442370 : trop de 2-5 kHz, il pique), *Fry Or Sizzle 1* (trop sifflant pour une boucle), les briquets à pipe (*Lighter Flicking…* : un briquet jetable puis quelqu'un qui aspire), et les boucles de la communauté utilisées avant (impossibles à télécharger sans compte, donc impossibles à vérifier).

**Le lance-flammes** (depuis qu'il a remplacé le Zippo, les Molotov, le jerrican et la flasque dans les attaques) n'a demandé **aucun nouveau téléchargement** : ses sons sont faits des mêmes fichiers mesurés, coupés, montés ou descendus en hauteur (`pitch`) : *Fire Whoosh 6* (un vrai jet de lance-flammes) pour le jet et la lance du chalumeau, le levier du Zippo grave pour la gâchette et les vannes, le liquide qui part d'un coup monté d'une quinte pour le sifflement du détendeur, le grésillement qui retombe pour la veilleuse coupée et la soupape du finisher. Retirés du générateur car plus utilisés : *FlameFlare* (devenu *BurstPop*), *MolotovLight*, *MolotovShatter* (plus de verre : *GlobSplat*), *FuelSwig*, *FuelPour*, *CanThrow*, *ZippoDrop*, *CanSlosh* (devenu *GunDraw*).

## Changer un son

1. Mets son ID dans `STOCK` (`tools/sounds/pyro_sounds.py`) avec un niveau *cible*.
2. `python3 tools/sounds/pyro_sounds.py --measure --cache <dossier>` : télécharge et mesure (numpy + ffmpeg ; seuls les sons publics se téléchargent sans compte).
3. `python3 tools/sounds/pyro_sounds.py --verify` : vérifie chaque ID sur la boutique.
4. `python3 tools/sounds/pyro_sounds.py --write` puis `stylua src` : réécrit `Sounds.luau`, `SoundCues.luau` et ce document.

## Plus tard (optionnel) : générer ses propres sons

Pas nécessaire. Mais pour un son encore plus précis, chaque fiche plus bas donne un design en cinq couches et un **prompt** prêt à coller dans un générateur audio. Coupe le silence au début du fichier, fais boucler sans clic les sons marqués **BOUCLE**, importe-les (*Creator Hub → Creations → Audio → Upload*) et mets leurs IDs dans `STOCK`.

## La liste

| Son | Ce que c'est | Quand |
|---|---|---|
| [`ZippoOpen`](#zippoopen) | Le couvercle du Zippo qui s'ouvre d'un coup de pouce (le « clink »). | IMMOLATION (1,85 s), quand il sort le briquet pour rallumer la veilleuse. |
| [`ZippoStrike`](#zippostrike) | La molette frottée sur la pierre, les étincelles, la mèche qui prend feu. | IMMOLATION (2,15 s), juste après ZippoOpen. |
| [`ZippoClose`](#zippoclose) | Le couvercle refermé d'un coup sec : la flamme étouffée. | IMMOLATION (2,62 s) : le briquet refermé et rangé. |
| [`MolotovThrow`](#molotovthrow) | Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air. | NAPALM LOB et NAPALM MORTAR : la boule de napalm en vol (la flamme qui passe). |
| [`FuelIgnite`](#fuelignite) | L'essence répandue qui s'embrase : la boule de feu. | Juste après GlobSplat (la flaque prend feu). |
| [`PoolFire`](#poolfire) | La flaque d'essence qui brûle (BOUCLE, tant que le feu dure). **BOUCLE** | Pendant tout le feu au sol (napalm, INFERNO), en 3D sur la flaque, baisse quand le feu meurt. |
| [`FireBreath`](#firebreath) | Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit. | FLAME STREAM (0,45 s → 1 s), TORCH CHARGE (le jet devant lui) et le pilier de l'Awakening (0,45 s). |
| [`FuelSplash`](#fuelsplash) | L'essence projetée hors du jerrican sur quelqu'un (DOUSE). | FUEL SPRAY (0,4 s) : le carburant cru pulvérisé ; IMMOLATION (0,4 s) : le carburant versé. |
| [`BodyBurn`](#bodyburn) | Un corps et ses vêtements en feu (BOUCLE). Aussi, plus bas, ses poings en feu pendant l'Awakening. **BOUCLE** | Sur la victime du finisher pendant qu'elle brûle, et (en plus faible) sur les avant-bras du Pyromane en Awakening. |
| [`SelfIgnite`](#selfignite) | Il allume ses propres avant-bras imbibés d'essence (BURNING MAN). | L'activation de l'Awakening (0,55 s) : le retour de flamme sur ses avant-bras. |
| [`BodyIgnite`](#bodyignite) | Le corps imbibé qui s'embrase d'un coup (« whump »). | IMMOLATION, à 3,05 s (le jet à bout portant). |
| [`BurnScream`](#burnscream) | Les cris de la victime qui brûle (coupés à la mort). | IMMOLATION, de 3,2 s à 4,6 s (coupé net au « Still »). |
| [`InfernoBreath`](#infernobreath) | Le jet de l'INFERNO : le même que FireBreath, plus long. | INFERNO (0,45 s → 1,25 s) et le plein jet du finisher (3,05 s). |
| [`FireSwing`](#fireswing) | Le poing ou le bras en feu qui fend l'air : une torche qui passe. | BLOWTORCH (0,16 s) : le canon chaud lancé vers eux. |
| [`FireImpact`](#fireimpact) | Le poing en feu qui touche : un « pouf » de flamme et la peau qui grésille. | BLOWTORCH / TORCH CHARGE, au coup confirmé par le serveur. |
| [`CatchFire`](#catchfire) | Quelqu'un qui prend feu : un souffle de flamme qui l'enveloppe, un grésillement. | Le premier instant où un corps brûle (napalm, jet, flaque, finisher). |
| [`Extinguish`](#extinguish) | Le feu qui s'éteint sur un corps : un grésillement qui retombe. | Quand les dernières flammes d'un corps s'éteignent, et à la fin de l'Awakening. |
| [`PyreRoar`](#pyreroar) | Le grondement du corps qui brûle en entier (BOUCLE). **BOUCLE** | IMMOLATION, de l'embrasement (3,05 s) à la fin du feu (12 s), par-dessus le crépitement du corps. |
| [`GunDraw`](#gundraw) | Le lance-flammes ramené du dos à la hanche : l'essence qui ballotte dans la bouteille. | Chaque attaque, quand la main prend la poignée (0,15 s ; 0,08 s en Awakening). |
| [`PilotLight`](#pilotlight) | La veilleuse qui s'allume : un clic de levier et un petit « fwip » bleu. | Après le dégainage de chaque attaque, FUEL SPRAY (0,66 s : rallumée), IMMOLATION (2,3 s). |
| [`PilotOut`](#pilotout) | La veilleuse coupée : un petit grésillement aigu. | FUEL SPRAY (0,27 s), IMMOLATION (avant de verser le carburant). |
| [`TriggerClick`](#triggerclick) | La gâchette pressée : un clic métallique sourd. | FLASH BURST (0,38 s), NAPALM LOB (0,6 s), FLAME STREAM (0,42 s), NAPALM MORTAR, INFERNO, TORCH CHARGE. |
| [`BurstPop`](#burstpop) | La boule de feu sous pression qui éclate : un « pouf » franc, des gouttes qui crépitent. | FLASH BURST, sur le coup (0,42 s). |
| [`GlobLaunch`](#globlaunch) | La boule de napalm crachée par le canon : une courte bouffée de feu. | NAPALM LOB (0,62 s), NAPALM MORTAR (0,45 s). |
| [`GlobSplat`](#globsplat) | La boule de napalm qui s'écrase au sol : un « splash » mouillé (pas de verre). | À l'impact de la boule (sol, mur ou sur quelqu'un), juste avant FuelIgnite. |
| [`StreamEnd`](#streamend) | Le jet relâché : la queue de la flamme qui s'éloigne. | Fin de FLAME STREAM, d'INFERNO et du plein jet du finisher (4,25 s). |
| [`PressureHiss`](#pressurehiss) | Le sifflement du détendeur sous pression qui monte. | Sous les jets : FLASH BURST, NAPALM LOB (la pression qui monte), FLAME STREAM, l'Awakening, NAPALM MORTAR, INFERNO, IMMOLATION. |
| [`ValveCrank`](#valvecrank) | La vanne claquée ou le volant de la bouteille tourné : un « clac » métallique. | NAPALM LOB (0,33 s étranglée, 0,58 s rouverte), l'Awakening (0,14 s), INFERNO (0,2 s), IMMOLATION. |
| [`TorchLance`](#torchlance) | La lance du chalumeau qui s'allume : un jet court et dur. | BLOWTORCH (0,22 s, juste avant le coup). |
| [`Vent`](#vent) | La soupape de sécurité du lance-flammes surchauffé : un long sifflement brûlant. | IMMOLATION (4,8 s), après la mort. |

## ZippoOpen

Le couvercle du Zippo qui s'ouvre d'un coup de pouce (le « clink »). **Quand :** IMMOLATION (1,85 s), quand il sort le briquet pour rallumer la veilleuse.

> *Brief :* Design a layered sound effect for a brass Zippo-style lighter lid being flicked open with the thumb. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bord du couvercle en laiton qui claque contre le boîtier | 2-9 kHz | clic métallique sec, très court | 0 ms | 25 ms |
| Mécanique | La came à ressort de la charnière qui bascule | 1-5 kHz | « clink » aigu qui sonne une fraction de seconde | 10 ms | 120 ms |
| Corps | La résonance du boîtier creux en laiton | 600 Hz-3 kHz | petit tintement creux, boisé par la main | 15 ms | 200 ms |
| Grave (sub) | Le pouce qui pousse le couvercle | 80-250 Hz | petit « tok » sourd de chair sur métal | 0 ms | 60 ms |
| Queue (la fin) | Le tintement qui s'éteint dans une petite pièce | 1-6 kHz | réverbération très courte, métallique | 50 ms | 350 ms |

### Les prompts (à coller)

**`ZippoOpen_Transient`**
```
Single sharp metallic click of a brass lighter lid snapping open, close-miked, extremely short, dry, no reverb, no other sounds, isolated one-shot, 0.1 seconds.
```
**`ZippoOpen_Mechanism`**
```
The distinctive spring-loaded hinge clink of a Zippo lighter opening, bright metallic ping with a tiny spring twang, close-miked, dry, isolated, 0.3 seconds.
```
**`ZippoOpen_Body`**
```
Short hollow resonance of a small brass box held in a hand, soft metallic ring, muted by fingers, no click at the start, isolated, 0.3 seconds.
```
**`ZippoOpen_Sub`**
```
Very soft low thump of a thumb pushing against a small metal object, muffled, subtle, no ring, isolated, 0.1 seconds.
```
**`ZippoOpen_Tail`**
```
Tiny metallic ring decaying in a small room, very short natural reverb tail only, no initial click, isolated, 0.5 seconds.
```

## ZippoStrike

La molette frottée sur la pierre, les étincelles, la mèche qui prend feu. **Quand :** IMMOLATION (2,15 s), juste après ZippoOpen.

> *Brief :* Design a layered sound effect for a Zippo lighter's flint wheel being struck and the wick catching fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | La molette d'acier qui accroche la pierre | 2-10 kHz | « tchk » granuleux, très bref | 0 ms | 30 ms |
| Mécanique | La molette crantée qui tourne et râpe la pierre, les étincelles | 3-12 kHz | râpe rapide et grésillement d'étincelles | 10 ms | 120 ms |
| Corps | La mèche imbibée d'essence qui s'allume | 200 Hz-2 kHz | « fff » doux et aéré | 60 ms | 300 ms |
| Grave (sub) | La flamme qui gonfle | 50-150 Hz | souffle grave très léger | 70 ms | 250 ms |
| Queue (la fin) | La petite flamme qui flotte | 300 Hz-3 kHz | flottement doux et régulier, léger crépitement | 150 ms | 800 ms |

### Les prompts (à coller)

**`ZippoStrike_Transient`**
```
Sharp gritty click of a steel flint wheel being struck by a thumb on a lighter, close-miked, dry, extremely short, isolated one-shot, 0.1 seconds.
```
**`ZippoStrike_Mechanism`**
```
Fast rasp of a knurled steel wheel scraping a ferrocerium flint, with a tiny crackle of sparks, close-miked, dry, isolated, 0.15 seconds.
```
**`ZippoStrike_Body`**
```
Soft airy whoof of a lighter wick catching fire, gentle puff of a small naphtha flame igniting, close-miked, no click, isolated, 0.4 seconds.
```
**`ZippoStrike_Sub`**
```
Very subtle low airy bloom of a small flame igniting, soft low-frequency puff, no high frequencies, isolated, 0.3 seconds.
```
**`ZippoStrike_Tail`**
```
Small steady lighter flame fluttering gently in still air, soft breathy flicker with faint crackle, close-miked, isolated, 1 second.
```

## ZippoClose

Le couvercle refermé d'un coup sec : la flamme étouffée. **Quand :** IMMOLATION (2,62 s) : le briquet refermé et rangé.

> *Brief :* Design a layered sound effect for a Zippo lighter lid snapping shut and smothering the flame. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le couvercle qui claque sur le boîtier | 1-8 kHz | « clac » métallique plein | 0 ms | 30 ms |
| Mécanique | La came de la charnière qui se rabat | 1-5 kHz | petit cliquetis à ressort | 5 ms | 90 ms |
| Corps | Le boîtier serré dans la main | 300 Hz-2 kHz | « toc » creux et étouffé | 5 ms | 120 ms |
| Grave (sub) | La paume qui serre | 60-200 Hz | petit coup sourd | 0 ms | 80 ms |
| Queue (la fin) | La flamme étouffée | 500 Hz-4 kHz | petit « pff » d'air coupé, puis rien | 30 ms | 250 ms |

### Les prompts (à coller)

**`ZippoClose_Transient`**
```
Solid metallic snap of a brass lighter lid closing hard, close-miked, dry, very short, isolated one-shot, 0.1 seconds.
```
**`ZippoClose_Mechanism`**
```
Small spring hinge clack of a Zippo lid closing, tight mechanical click, dry, isolated, 0.2 seconds.
```
**`ZippoClose_Body`**
```
Muffled hollow knock of a small metal case closing inside a fist, dull, short, isolated, 0.2 seconds.
```
**`ZippoClose_Sub`**
```
Very soft low thud of a hand closing around a small object, subtle, isolated, 0.1 seconds.
```
**`ZippoClose_Tail`**
```
Tiny puff of a small flame being smothered under a metal lid, short soft hiss cut off, isolated, 0.3 seconds.
```

## MolotovThrow

Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air. **Quand :** NAPALM LOB et NAPALM MORTAR : la boule de napalm en vol (la flamme qui passe).

> *Brief :* Design a layered sound effect for a lit Molotov cocktail bottle being thrown overhand and flying past. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bras et la veste qui fendent l'air | 300 Hz-4 kHz | « fff » de mouvement rapide, tissu | 0 ms | 150 ms |
| Mécanique | L'essence qui ballotte dans la bouteille de verre | 200 Hz-2 kHz | glouglou de liquide dans du verre | 0 ms | 300 ms |
| Corps | La flamme du chiffon qui file | 150 Hz-3 kHz | flamme qui ronfle en passant (effet Doppler) | 80 ms | 700 ms |
| Grave (sub) | L'air poussé | 40-120 Hz | souffle grave léger | 80 ms | 300 ms |
| Queue (la fin) | La flamme qui s'éloigne | 300 Hz-3 kHz | flottement qui s'éteint au loin | 500 ms | 900 ms |

### Les prompts (à coller)

**`MolotovThrow_Transient`**
```
Quick swish of an arm and jacket sleeve swinging hard overhand, cloth whoosh, short, isolated, 0.2 seconds.
```
**`MolotovThrow_Mechanism`**
```
Liquid sloshing inside a glass wine bottle as it is swung, short glug and slosh, close-miked, isolated, 0.3 seconds.
```
**`MolotovThrow_Body`**
```
A small burning rag flame flying through the air and passing by, fluttering fire whoosh with a doppler pitch drop, isolated, 0.8 seconds.
```
**`MolotovThrow_Sub`**
```
Subtle low air push of an object thrown hard, soft low whump, isolated, 0.3 seconds.
```
**`MolotovThrow_Tail`**
```
Fluttering flame receding into the distance, fading fire flutter, isolated, 1 second.
```

## FuelIgnite

L'essence répandue qui s'embrase : la boule de feu. **Quand :** Juste après GlobSplat (la flaque prend feu).

> *Brief :* Design a layered sound effect for spilled petrol on the ground igniting into a fireball. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Les vapeurs d'essence qui s'enflamment | 300 Hz-6 kHz | « fwump » sec, claquant | 0 ms | 80 ms |
| Mécanique | Le front de flamme qui court sur la flaque | 500 Hz-6 kHz | balayage de feu qui file sur le liquide | 30 ms | 400 ms |
| Corps | La boule de feu | 100 Hz-3 kHz | rugissement de flamme large et chaud | 50 ms | 1200 ms |
| Grave (sub) | La pression d'air | 25-90 Hz | « whoomp » profond | 40 ms | 500 ms |
| Queue (la fin) | Le feu qui retombe en crépitant | 300 Hz-5 kHz | rugissement qui baisse vers un crépitement | 700 ms | 1500 ms |

### Les prompts (à coller)

**`FuelIgnite_Transient`**
```
Sharp dry pop of petrol vapour igniting, a quick fwump crack, not an explosion, close, isolated one-shot, 0.15 seconds.
```
**`FuelIgnite_Mechanism`**
```
Flame front rushing across a spreading pool of petrol, fast sweeping hiss of fire, isolated, 0.5 seconds.
```
**`FuelIgnite_Body`**
```
Large roaring fireball rising from burning petrol, deep warm rolling roar that swells then settles, no explosion debris, isolated, 1.3 seconds.
```
**`FuelIgnite_Sub`**
```
Deep low-frequency whoomp of a fireball pushing air, sub-bass pressure swell, no high frequencies, isolated, 0.5 seconds.
```
**`FuelIgnite_Tail`**
```
A large fire roar settling down into a steady crackling burn, fading, isolated, 1.5 seconds.
```

## PoolFire

La flaque d'essence qui brûle (BOUCLE, tant que le feu dure). **Quand :** Pendant tout le feu au sol (napalm, INFERNO), en 3D sur la flaque, baisse quand le feu meurt. C'est une **BOUCLE**.

> *Brief :* Design a layered sound effect for a pool of burning petrol on a street floor (seamless loop). Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Les petits claquements de la flamme (bulles qui éclatent) | 1-8 kHz | « pops » irréguliers | 0 ms | boucle |
| Mécanique | L'essence qui bout et grésille à la surface | 1-7 kHz | grésillement continu, mouillé | 0 ms | boucle |
| Corps | Les flammes | 150 Hz-3 kHz | ronflement continu de feu, moyen | 0 ms | boucle |
| Grave (sub) | Le grondement | 30-100 Hz | grondement grave stable | 0 ms | boucle |
| Queue (la fin) | L'air aspiré par le feu | 200 Hz-2 kHz | souffle d'air qui flotte, comme du vent | 0 ms | boucle |

### Les prompts (à coller)

**`PoolFire_Transient`**
```
Seamless loop of irregular small pops and snaps from a fire burning on a liquid, sparse crackle only, no roar, isolated, 6 seconds, loopable.
```
**`PoolFire_Mechanism`**
```
Seamless loop of fuel bubbling and sizzling on a hot surface, wet continuous sizzle, isolated, 6 seconds, loopable.
```
**`PoolFire_Body`**
```
Seamless loop of a medium pool fire burning steadily outdoors, continuous warm roar with flutter, no wind, isolated, 8 seconds, loopable.
```
**`PoolFire_Sub`**
```
Seamless loop of a low steady rumble of a fire, sub-bass only, smooth, isolated, 6 seconds, loopable.
```
**`PoolFire_Tail`**
```
Seamless loop of air being drawn into a fire, soft breathy flutter like gentle wind, isolated, 6 seconds, loopable.
```

## FireBreath

Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit. **Quand :** FLAME STREAM (0,45 s → 1 s), TORCH CHARGE (le jet devant lui) et le pilier de l'Awakening (0,45 s).

> *Brief :* Design a layered sound effect for a fire breather spitting atomised fuel through a lighter flame into a roaring jet of fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Les lèvres qui crachent le liquide en brouillard | 1-8 kHz | « pfff » éclaté, mouillé | 0 ms | 120 ms |
| Mécanique | Le brouillard d'essence qui siffle | 2-10 kHz | sifflement de pulvérisation fin | 20 ms | 500 ms |
| Corps | Le jet de flamme | 100 Hz-4 kHz | rugissement de chalumeau large qui gonfle | 60 ms | 700 ms |
| Grave (sub) | La poussée d'air chaud | 30-110 Hz | « whoomp » grave | 60 ms | 500 ms |
| Queue (la fin) | La flamme qui s'enroule et retombe | 300 Hz-5 kHz | flamme qui roule et crépite en s'éteignant | 600 ms | 900 ms |

### Les prompts (à coller)

**`FireBreath_Transient`**
```
Explosive wet spit of a mouthful of liquid sprayed through pursed lips into a mist, sharp pff, close, isolated, 0.15 seconds.
```
**`FireBreath_Mechanism`**
```
Fine hiss of atomised liquid spraying through the air, continuous misty spray, isolated, 0.6 seconds.
```
**`FireBreath_Body`**
```
Big roaring jet of flame from a fire breather, a fast rising whoosh that holds as a roaring tongue of fire, warm and wide, isolated, 0.8 seconds.
```
**`FireBreath_Sub`**
```
Deep low whoomp of a large flame blooming in the air, sub-bass swell, isolated, 0.5 seconds.
```
**`FireBreath_Tail`**
```
A jet of flame curling up and dying out in the air, rolling flutter with crackle, fading, isolated, 1 second.
```

## FuelSplash

L'essence projetée hors du jerrican sur quelqu'un (DOUSE). **Quand :** FUEL SPRAY (0,4 s) : le carburant cru pulvérisé ; IMMOLATION (0,4 s) : le carburant versé.

> *Brief :* Design a layered sound effect for petrol flung from a metal jerrycan onto a person. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le liquide qui sort d'un coup du bec | 500 Hz-6 kHz | claque de liquide lancée | 0 ms | 80 ms |
| Mécanique | Le jerrican en tôle qui se tord et la poignée qui grince | 200 Hz-3 kHz | « bonk » de tôle creuse, grincement | 0 ms | 250 ms |
| Corps | L'arc d'essence qui s'écrase sur le corps et le sol | 150 Hz-5 kHz | grande éclaboussure étalée, mouillée | 50 ms | 500 ms |
| Grave (sub) | Le poids du liquide | 40-140 Hz | « floc » grave | 40 ms | 200 ms |
| Queue (la fin) | Les gouttes qui tombent | 1-8 kHz | gouttes et filets qui ruissellent | 400 ms | 1300 ms |

### Les prompts (à coller)

**`FuelSplash_Transient`**
```
Sudden slap of liquid thrown out of a can spout, sharp wet burst, close, isolated, 0.1 seconds.
```
**`FuelSplash_Mechanism`**
```
Hollow metal jerrycan flexing with a dull bonk as it is swung, handle creak, isolated, 0.3 seconds.
```
**`FuelSplash_Body`**
```
Wide arc of liquid splashing over a person and onto concrete, heavy wet splatter, isolated, 0.6 seconds.
```
**`FuelSplash_Sub`**
```
Low heavy thud of a large mass of liquid landing, soft low splat, isolated, 0.2 seconds.
```
**`FuelSplash_Tail`**
```
Liquid dripping from clothes onto concrete, scattered drips and a small trickle, quiet, isolated, 1.3 seconds.
```

## BodyBurn

Un corps et ses vêtements en feu (BOUCLE). Aussi, plus bas, ses poings en feu pendant l'Awakening. **Quand :** Sur la victime du finisher pendant qu'elle brûle, et (en plus faible) sur les avant-bras du Pyromane en Awakening. C'est une **BOUCLE**.

> *Brief :* Design a layered sound effect for a human body and its clothes burning (seamless loop). Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Les petits éclatements (graisse, tissu) | 1-8 kHz | « pops » et claquements irréguliers | 0 ms | boucle |
| Mécanique | Le tissu qui brûle | 1-7 kHz | crépitement de vêtements qui se consument | 0 ms | boucle |
| Corps | Les flammes autour du corps | 150 Hz-3 kHz | ronflement de feu moyen, irrégulier | 0 ms | boucle |
| Grave (sub) | Le grondement | 30-100 Hz | grave doux et stable | 0 ms | boucle |
| Queue (la fin) | Le grésillement de la peau (vapeur) | 2-9 kHz | sifflement humide continu | 0 ms | boucle |

### Les prompts (à coller)

**`BodyBurn_Transient`**
```
Seamless loop of irregular sharp pops and snaps of a fire burning cloth and fat, sparse crackles only, isolated, 6 seconds, loopable.
```
**`BodyBurn_Mechanism`**
```
Seamless loop of clothing burning, dense dry crackle of cotton and fabric being consumed, isolated, 6 seconds, loopable.
```
**`BodyBurn_Body`**
```
Seamless loop of a person-sized fire burning, irregular warm roar with flutter, close, isolated, 8 seconds, loopable.
```
**`BodyBurn_Sub`**
```
Seamless loop of a soft low rumble under a fire, sub-bass only, isolated, 6 seconds, loopable.
```
**`BodyBurn_Tail`**
```
Seamless loop of a wet sizzle, like meat on a hot grill, continuous steam hiss, isolated, 6 seconds, loopable.
```

## SelfIgnite

Il allume ses propres avant-bras imbibés d'essence (BURNING MAN). **Quand :** L'activation de l'Awakening (0,55 s) : le retour de flamme sur ses avant-bras.

> *Brief :* Design a layered sound effect for petrol-soaked forearm wraps being lit with a lighter and flaring up along both arms. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | La flamme du briquet qui touche le tissu | 1-6 kHz | petit « pff » sec | 0 ms | 60 ms |
| Mécanique | Le tissu imbibé qui prend | 2-10 kHz | crépitement qui court le long du bras | 20 ms | 400 ms |
| Corps | Les deux bras qui s'embrasent | 150 Hz-3 kHz | double « whoosh » de flamme qui monte | 60 ms | 700 ms |
| Grave (sub) | La flamme qui gonfle | 30-110 Hz | « whoomp » grave | 60 ms | 400 ms |
| Queue (la fin) | Les poings qui brûlent | 300 Hz-4 kHz | flamme qui flotte et crépite | 500 ms | 1200 ms |

### Les prompts (à coller)

**`SelfIgnite_Transient`**
```
Tiny dry puff as a lighter flame touches fuel-soaked cloth wraps, short pop, isolated, 0.1 seconds.
```
**`SelfIgnite_Mechanism`**
```
Crackle of fire racing along fuel-soaked fabric wrapped on an arm, quick running crackle, isolated, 0.5 seconds.
```
**`SelfIgnite_Body`**
```
Two quick whooshes of flame flaring up along both arms, rising warm fire roar, isolated, 0.8 seconds.
```
**`SelfIgnite_Sub`**
```
Deep soft whoomp of flames blooming, low-frequency swell, isolated, 0.4 seconds.
```
**`SelfIgnite_Tail`**
```
Fire burning on fists and forearms, fluttering roar with crackle settling to steady, isolated, 1.2 seconds.
```

## BodyIgnite

Le corps imbibé qui s'embrase d'un coup (« whump »). **Quand :** IMMOLATION, à 3,05 s (le jet à bout portant).

> *Brief :* Design a layered sound effect for a petrol-soaked person on the ground going up in flames. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Les vapeurs d'essence qui s'enflamment | 300 Hz-6 kHz | « fwump » sec | 0 ms | 80 ms |
| Mécanique | Le feu qui court sur les vêtements | 500 Hz-7 kHz | balayage de flamme qui file sur le tissu | 20 ms | 500 ms |
| Corps | Le corps qui s'embrase | 100 Hz-3 kHz | rugissement de feu qui enveloppe | 40 ms | 1100 ms |
| Grave (sub) | La pression d'air | 25-90 Hz | « whoomp » profond | 30 ms | 450 ms |
| Queue (la fin) | Le feu qui s'installe | 300 Hz-5 kHz | rugissement qui devient un crépitement | 800 ms | 1300 ms |

### Les prompts (à coller)

**`BodyIgnite_Transient`**
```
Sharp dry fwump of petrol vapour igniting around a body, quick pop, not an explosion, isolated, 0.1 seconds.
```
**`BodyIgnite_Mechanism`**
```
Fire racing over fuel-soaked clothes from chest to legs, fast sweeping crackling hiss, isolated, 0.5 seconds.
```
**`BodyIgnite_Body`**
```
A person-sized fire engulfing a body in one roaring whoosh, warm deep roar swelling then holding, isolated, 1.2 seconds.
```
**`BodyIgnite_Sub`**
```
Deep low whoomp of flames bursting up, sub-bass pressure swell, isolated, 0.5 seconds.
```
**`BodyIgnite_Tail`**
```
A fire roar settling into a steady crackling burn of clothes, fading, isolated, 1.3 seconds.
```

## BurnScream

Les cris de la victime qui brûle (coupés à la mort). **Quand :** IMMOLATION, de 3,2 s à 4,6 s (coupé net au « Still »).

> *Brief :* Design a layered sound effect for a man screaming in agony while burning, his voice breaking and cut short. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches (design)

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | L'inspiration brutale avant le cri | 300 Hz-4 kHz | halètement aigu, choc | 0 ms | 250 ms |
| Mécanique | La gorge qui râpe, la toux dans la fumée | 200 Hz-3 kHz | râle et toux étouffée | 250 ms | 1200 ms |
| Corps | Le cri d'agonie | 150 Hz-3 kHz | cri brut, déchiré, homme adulte | 200 ms | 1300 ms |
| Grave (sub) | La poitrine | 70-200 Hz | grognement grave de fond | 200 ms | 1200 ms |
| Queue (la fin) | La voix qui se brise | 150 Hz-2.5 kHz | voix qui casse en sifflement rauque | 1100 ms | 400 ms |

### Les prompts (à coller)

**`BurnScream_Transient`**
```
Sharp panicked gasp of an adult man in sudden pain, a short ragged intake of breath, close, isolated, 0.3 seconds.
```
**`BurnScream_Mechanism`**
```
Raspy throat strain and choking coughs of a man in smoke, rough, close, isolated, 1.2 seconds.
```
**`BurnScream_Body`**
```
Raw agonised scream of an adult man in pain, ragged and breaking, realistic, not theatrical, no music, close, isolated, 1.4 seconds.
```
**`BurnScream_Sub`**
```
Low guttural chest groan under a scream, subtle, isolated, 1.2 seconds.
```
**`BurnScream_Tail`**
```
A scream breaking into a rasping wheeze and stopping, voice giving out, isolated, 0.4 seconds.
```

## InfernoBreath

Le jet de l'INFERNO : le même que FireBreath, plus long. **Quand :** INFERNO (0,45 s → 1,25 s) et le plein jet du finisher (3,05 s).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## FireSwing

Le poing ou le bras en feu qui fend l'air : une torche qui passe. **Quand :** BLOWTORCH (0,16 s) : le canon chaud lancé vers eux.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## FireImpact

Le poing en feu qui touche : un « pouf » de flamme et la peau qui grésille. **Quand :** BLOWTORCH / TORCH CHARGE, au coup confirmé par le serveur.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## CatchFire

Quelqu'un qui prend feu : un souffle de flamme qui l'enveloppe, un grésillement. **Quand :** Le premier instant où un corps brûle (napalm, jet, flaque, finisher).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## Extinguish

Le feu qui s'éteint sur un corps : un grésillement qui retombe. **Quand :** Quand les dernières flammes d'un corps s'éteignent, et à la fin de l'Awakening.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## PyreRoar

Le grondement du corps qui brûle en entier (BOUCLE). **Quand :** IMMOLATION, de l'embrasement (3,05 s) à la fin du feu (12 s), par-dessus le crépitement du corps. C'est une **BOUCLE**.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## GunDraw

Le lance-flammes ramené du dos à la hanche : l'essence qui ballotte dans la bouteille. **Quand :** Chaque attaque, quand la main prend la poignée (0,15 s ; 0,08 s en Awakening).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## PilotLight

La veilleuse qui s'allume : un clic de levier et un petit « fwip » bleu. **Quand :** Après le dégainage de chaque attaque, FUEL SPRAY (0,66 s : rallumée), IMMOLATION (2,3 s).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## PilotOut

La veilleuse coupée : un petit grésillement aigu. **Quand :** FUEL SPRAY (0,27 s), IMMOLATION (avant de verser le carburant).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## TriggerClick

La gâchette pressée : un clic métallique sourd. **Quand :** FLASH BURST (0,38 s), NAPALM LOB (0,6 s), FLAME STREAM (0,42 s), NAPALM MORTAR, INFERNO, TORCH CHARGE.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## BurstPop

La boule de feu sous pression qui éclate : un « pouf » franc, des gouttes qui crépitent. **Quand :** FLASH BURST, sur le coup (0,42 s).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## GlobLaunch

La boule de napalm crachée par le canon : une courte bouffée de feu. **Quand :** NAPALM LOB (0,62 s), NAPALM MORTAR (0,45 s).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## GlobSplat

La boule de napalm qui s'écrase au sol : un « splash » mouillé (pas de verre). **Quand :** À l'impact de la boule (sol, mur ou sur quelqu'un), juste avant FuelIgnite.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## StreamEnd

Le jet relâché : la queue de la flamme qui s'éloigne. **Quand :** Fin de FLAME STREAM, d'INFERNO et du plein jet du finisher (4,25 s).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## PressureHiss

Le sifflement du détendeur sous pression qui monte. **Quand :** Sous les jets : FLASH BURST, NAPALM LOB (la pression qui monte), FLAME STREAM, l'Awakening, NAPALM MORTAR, INFERNO, IMMOLATION.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## ValveCrank

La vanne claquée ou le volant de la bouteille tourné : un « clac » métallique. **Quand :** NAPALM LOB (0,33 s étranglée, 0,58 s rouverte), l'Awakening (0,14 s), INFERNO (0,2 s), IMMOLATION.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## TorchLance

La lance du chalumeau qui s'allume : un jet court et dur. **Quand :** BLOWTORCH (0,22 s, juste avant le coup).

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

## Vent

La soupape de sécurité du lance-flammes surchauffé : un long sifflement brûlant. **Quand :** IMMOLATION (4,8 s), après la mort.

Pas de design en cinq couches : les couches en place sont dans le tableau plus haut.

