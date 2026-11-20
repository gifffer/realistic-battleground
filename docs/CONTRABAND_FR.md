# Contrebande : prototype (`feature/contraband-prototype`)

Première version jouable de la nouvelle direction : un labo privé dans un immeuble de la ville, une culture de clone qui pousse dans une cuve, l'extraction du bio-core en 6 gestes, la mallette BX-7 qu'on porte à la main gauche et l'acheteur qui paie en coins. Pas de police, pas de PNJ en plus (sauf l'acheteur), pas de trams. Le gore et le train ne changent pas.

Tout est décidé par le serveur : les clients ne font que demander (3 remotes + des ProximityPrompts), et chaque demande est vérifiée (cadence, distance, état, propriétaire).

## Ce qui a été ajouté

### La boucle
1. **Entrer** : 3 portes en bois de la ville ouvrent **ton** labo (chacun le sien, privé) : **Calloway Tenements** (avenue, ouest), **Doyle Alley 7**, **Lot 9 Rear**. Maintenir **E** « Enter lab ». Une petite réglette de lumière froide au-dessus de chaque porte aide à les trouver. Refusé si on vient d'être frappé **ou de frapper** (« Not while fighting. », 8 s après un coup reçu, 5 s après un coup donné), si on n'est pas au repos (en train d'attaquer, de bloquer…), en duel ou en train de vendre. Tout est revérifié juste avant la téléportation. On ressort par la porte « Leave lab » du labo, devant la porte par où on est entré.
2. **Planter** : « Plant culture » sur la cuve. Le clone pousse **8 min**, seulement tant que tu es sur le serveur (dans le labo ou dehors) ; hors ligne, ça attend :
   - **MATRIX** (0–25 %) : liquide ambre, lobes de gel sur une tige ;
   - **FRAME** (25–75 %) : armature adulte blanche qui se remplit de gel laiteux depuis les pieds ;
   - **SHELL** (75–100 %) : corps synthétique gris nacré sans visage, « SYN-04 NO ID » ;
   - **READY** : LED fixe, écran « READY · EXTRACT », la cuve propose « Extract ». Message « Culture ready. Back to your lab. » où que tu sois.
   - Le HUD (en bas à droite) affiche toujours « CULTURE 47 % · 4:15 », puis « CULTURE READY ».
3. **Extraire** (~20–30 s, sans mallette en main) : caméra sur l'établi, 6 étapes : déverrouiller 2 pinces, ouvrir la trappe, écarter la membrane, couper les 4 fibres qui brillent fixe (pas les 2 qui clignotent, un peu plus chaudes ; seule la partie extérieure de chaque fibre se coupe ; une mauvaise fibre devient grise avec une bouffée et « Wrong fibre: grade down »), soulever le bio-core, le sceller dans une capsule. La carte de résultat reste 2,5 s et dit pourquoi on a perdu des points et combien vaut le core (« 1 wrong fibre · lifted too fast · worth ~60 coins »). Liquides laiteux, jamais de rouge. La coque part dans la goulotte. Grade **A / B / C** selon la précision (±20 % du prix au maximum). Le core va sur l'étagère (stash, 8 places, sauvegardé) ou directement dans une mallette posée dans le labo.
4. **Mallette** : « Take case » sur le râtelier, puis « Load cores » (**E**) sur l'établi pour y mettre les cores du stash ; « Unload cores » (**T**) pour les remettre. Chaque prompt n'apparaît que s'il peut servir. Mallette « Courier » = 2 berceaux (le 3e est bouché par la mousse). Au plus 2 mallettes posées dans ton labo ; prendre une nouvelle mallette reprend tes mallettes **vides** laissées en ville.
5. **Porter** : la mallette est dans la main **gauche** (le buste penche un peu de l'autre côté, l'épaule chargée descend). Les M1 de la main gauche (coups 1 et 3) sont donnés avec la main droite, au même timing. Vitesse ×0,88 (le sprint marche), endurance du sprint ×1,3, pas d'escalade haute (mantle), l'enjambement bas marche. M1, blocage et dash marchent ; pas de coups de kit (1–4), pas d'Awakening, pas de finisher. **G** = poser la mallette debout devant soi ; **E** sur une mallette au sol = la ramasser.
6. **KO** par un **joueur** (pas par un mannequin ou un PNJ) : la mallette tombe à plat, couvercle entrouvert à 12° avec une fine lueur froide (seule la réglette LED, la même pleine ou vide). Si elle roule trop loin, tombe d'une corniche ou finit sur la voie du train, elle revient au point de chute. **N'importe qui** peut la ramasser ; le contenu n'est connu qu'en la prenant.
7. **Vendre** : l'acheteur « Marlow » à l'arrière de la camionnette du Yard (petite ampoule rouge, « NIGHT INTAKE »). « Sell cores » (« Night Intake ») n'apparaît que si on porte une mallette. La mallette s'ouvre **1,6 s** : un coup, un KO ou bouger de plus de 4 studs annule (« Interrupted », rien de perdu). Prix par core = 60 × (A 1,2 / B 1,0 / C 0,8), ×0,5 sur un serveur privé. La mallette reste en main, vide.

### Autres règles
- **Déconnexion en portant** : en ville, la mallette reste au sol où tu étais ; dans ton labo, ses cores retournent dans ton stash. « Dans le labo » se décide par la **position** (la boîte du labo), jamais par l'attribut seul.
- **Quitter le serveur** : ton labo disparaît ; les mallettes posées dedans reversent leurs cores dans ton stash.
- **Sauvegarde** : le stash sauvegardé contient aussi les cores des mallettes posées dans ton labo (et de celle que tu tiens dans ton labo), réécrit à chaque changement : un crash ou un arrêt du serveur ne les perd pas. Une mallette **portée en ville** est perdue avec ses cores si le serveur s'arrête (voulu).
- **Mallette abandonnée** : vide et personne à moins de 60 studs pendant 2 min, elle disparaît ; pleine et personne à moins de 60 studs pendant **15 min**, chaque core retourne sur l'étagère de celui qui l'a extrait (s'il est en ligne et a de la place), puis la mallette vide disparaît.
- **Limite du serveur** : au moins `MaxPlayers × 2 + 8` mallettes ; quand c'est plein, la plus vieille mallette **vide** en ville est reprise d'abord.
- **Train** : toujours mortel ; une mallette qui tombe sur la voie est posée sur la passerelle.
- **Anti-téléport** : un trajet trop rapide ou un saut énorme avant la vente → « Try again. » (rien de perdu, ligne d'avertissement dans l'Output).
- **Chaleur** : des compteurs silencieux (extractions, ventes, ramassages, coups pris en portant…) sont seulement enregistrés, sans effet pour l'instant (pour la police plus tard). Dans Studio ils s'affichent dans l'Output quand un joueur part.

### Autres changements visibles
- **Smog Night** : la nuit de la ville a un nouveau réglage (brouillard brun chaud, noirs plus profonds). Toujours la nuit en ville, la pluie et l'orage marchent comme avant, le parc reste ensoleillé.
- **Look « Lab »** dans le labo (air clair et froid), en fondu de 0,6 s à l'entrée et à la sortie. Pas de pluie, d'éclair ni d'annonce météo dans le labo.
- La pluie et l'orage ne descendent plus la lumière ambiante de nuit sous un seuil de lisibilité (seule une coupure de courant va plus sombre).

## Comment tester dans Studio
1. Synchroniser avec Rojo, puis **Test → Clients and Servers → 2 Players** (le détail des tests est dans `docs/TEST_FR.md`, section « Contrebande »).
2. Dans Studio, la culture pousse en **45 s** au lieu de 8 min (attribut `CultureFast` du Workspace, mis à `true` par le serveur au démarrage). Pour tester le vrai temps : dans la fenêtre Properties du Workspace (côté serveur), décocher `CultureFast`.
3. La sauvegarde de Studio utilise le vrai DataStore : il faut **Game Settings → Security → Enable Studio Access to API Services** pour tester « quitter puis revenir ».
4. Vérifications dans la barre de commande (côté **serveur**), elles doivent toutes renvoyer `true` :
   - `require(game.ServerScriptService.Server.Systems.Contraband.Ledger).selfTest(1, 5000)`
   - `require(game.ReplicatedStorage.Shared.Contraband.Grades).selfTest()`
   - `require(game.ServerScriptService.Server.Systems.Contraband.Ledger).verify()` (après chaque scénario)

## Réglages (`src/shared/Config.luau`)
| Section | Clé | Valeur | Rôle |
|---|---|---|---|
| `Lab` | `CULTURE_TIME` | 480 | secondes de pousse (en ligne) |
| `Lab` | `CULTURE_FAST_IN_STUDIO` / `CULTURE_FAST_TIME` | true / 45 | pousse rapide dans Studio |
| `Lab` | `PLANT_COST` | 0 | prix en coins pour planter |
| `Lab` | `STASH_MAX` | 8 | places sur l'étagère |
| `Lab` | `NO_ENTRY_AFTER_HIT` | 8 | pas d'entrée au labo juste après un coup |
| `Extraction` | `MIN_TIME`, `PENALTY`, `GRADE_A` / `GRADE_B` | — | durée minimale de chaque étape, pénalités, seuils 85 / 60 |
| `Case` | `SPEED_MULT` / `STAMINA_DRAIN_MULT` | 0,88 / 1,3 | vitesse et endurance en portant |
| `Case` | `CRADLES` | Courier 2, MkII 3 | berceaux par mallette |
| `Case` | `EMPTY_DESPAWN_TIME` / `DESPAWN_CLEAR_RADIUS` | 120 / 60 | ménage des mallettes vides |
| `Case` | `ABANDON_TIME` | 900 | mallette pleine abandonnée : ses cores retournent à leur auteur |
| `Case` | `MAX_WORLD` / `MAX_ISSUED_LIVE` | 40 / 2 | mallettes du serveur (au moins MaxPlayers × 2 + 8) / mallettes posées dans ton labo |
| `Case` | `SETTLE_MAX_FALL` / `SETTLE_MAX_ROLL` | 6 / 8 | mallette tombée : trop bas ou trop loin = remise au point de chute |
| `Market` | `BASE_PRICE`, `GRADE_MULT`, `PRIVATE_SERVER_MULT` | 60, A1,2/B1/C0,8, 0,5 | prix |
| `Market` | `OPEN_TIME` / `CANCEL_MOVE` | 1,6 / 4 | ouverture vulnérable de la vente |
| `Contraband` | `DEBUG_LOG` | true | lignes de debug dans l'Output (Studio seulement) |
| `Controls` | `CASE_SET_DOWN` | G | poser la mallette |

## Fichiers
- Serveur : `src/server/Systems/Contraband/` (Ledger, Guard, Heat, TripLog, Case, LabBuilder, Apartments, Lab, Extraction, Market ; seul `init.luau` est chargé par le bootstrap).
- Partagé : `src/shared/Contraband/` (CaseModel, Grades, Sites).
- Client : `src/client/Contraband/` (modèles du clone, du core, de la cuve, de l'établi, interface d'extraction), contrôleurs `LabController`, `ExtractionController`, `CaseController`, `ContrabandHudController`, `ZoneLookController`, et `Animation/CarryClips.luau`.
- Retouchés : Knockout (signal `onKnockedOut`, liste d'intercepteurs), Duels, CityDoors (`Locked`, `pulse`), Combat (verrous en portant / en extraction), Movement (endurance, escalade), CityNpcs (`spawnExtra`), Ambience (Smog Night), PlayerData (champ `contraband`), Config, Remotes, Types.

## À vérifier dans Studio (le code n'a pas encore tourné en jeu)
- Le sens d'ouverture des 3 portes, l'endroit où l'on ressort, la porte et le texte « NIGHT INTAKE » de la camionnette.
- La mallette posée (debout) et tombée (à plat) : bien au sol, pas dans le sol.
- La main gauche sur la poignée (en marchant et pendant la vente).
- Le look Smog Night et le look Lab ; la lisibilité du clone, du core et de la mallette.
- Pas de sons pour l'instant : les noms existent dans `src/shared/Sounds.luau` (section « Contraband » : `CaseLatch`, `CaseLidOpen`, `CaseLidClose`, `CasePickup`, `CaseSetDown`, `CaseDrop`, `VatReadyChime`, `ClampClunk`, `HatchHiss`, `MembraneStretch`, `FibreSnap`, `CoreRelease`, `CapsuleSeal`, `ChuteSlide` ; `CaseHum` et `VatHum` pas encore branchés) avec `ids = {}` : il suffit d'y coller des ids.
- La mallette paraît-elle en aluminium brossé sous les lampes sodium ? Sinon monter `ALU` vers 190 dans `CaseModel.luau`.
- Les coins du labo assez éclairés (lumière d'appoint ajoutée), le clone SHELL lisible dans la cuve (verre plus froid, lumière du couvercle).
- Pendant la vente, la mallette est tenue à plat d'une main (pas encore posée sur le hayon).
- Le grade vient en partie de chiffres envoyés par le client (précision des gestes) : un tricheur peut avoir A à chaque fois, mais cela ne change le prix que de ±20 %.
- Échap pendant l'extraction ouvre aussi le menu Roblox (on peut aussi utiliser le bouton STOP ou Retour arrière).
