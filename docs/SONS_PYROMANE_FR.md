# Sons du Pyromane

Chaque son du kit **Pyromane** est fait de **cinq couches** jouées ensemble, chacune avec son propre son dans `src/shared/Sounds.luau` (section *Pyromaniac*, à la fin du fichier) :

| Couche | Rôle |
|---|---|
| `_Transient` | l'attaque : le tout premier instant, sec et court |
| `_Mechanism` | ce qui bouge : charnière, molette, liquide, verre |
| `_Body` | le cœur du son, ce qu'on reconnaît |
| `_Sub` | le grave, le poids (on le sent plus qu'on ne l'entend) |
| `_Tail` | la fin qui s'éteint |

Une couche dont les `ids` sont vides (`{}`) est **muette** (aucune erreur). Le jeu joue toutes les couches **au bon moment** (colonne *Début* plus bas).

## Sons de la boutique Roblox (en place)

Tu ne veux pas générer ni importer les sons toi-même : chaque son du Pyromane utilise donc des **effets sonores gratuits et publics** du *Creator Store* de Roblox (*Toolbox → Audio*), déjà mis dans `src/shared/Sounds.luau`. Il n'y a **rien à faire** : Rojo synchronise, *Play*.

- Presque tous viennent de **Pro Sound Effects** (`ProSoundEffects`, créateur vérifié) : la bibliothèque sous licence que Roblox offre à toutes les expériences. Ce sont des enregistrements réalistes, pas des bruitages de dessin animé.
- Seules les **boucles** de feu (`PoolFire`, `BodyBurn`) viennent de membres de la communauté : Pro Sound Effects n'a pas de feu qui dure sur la boutique. Si l'une d'elles clique au bouclage ou disparaît (modération), remplace son ID dans `STOCK` (`tools/sounds/pyro_sounds.py`).
- En général, un seul son par effet, dans la couche `_Body` ; une deuxième couche seulement quand un second son aide vraiment (le verre **et** l'essence qui gicle pour le Molotov, le grésillement de la chair sous le « whoump » du corps). Les autres couches restent vides (muettes). Plusieurs IDs dans une couche = une variante au hasard à chaque fois.
- `volume` est réglé d'après le niveau de chaque fichier ; *Début coupé* saute le blanc au début du fichier (`start`), *Coupé à* arrête un son trop long avec un fondu rapide (`length`).

| Son | Couche | ID | Nom sur la boutique | Créateur | Durée | Pourquoi | Réglage |
|---|---|---|---|---|---|---|---|
| [`ZippoOpen`](#zippoopen) | `_Body` | `9121005566` | Zippo Lighter 1 (SFX) | ProSoundEffects (vérifié) | 0,45 s | le « clink » du couvercle qui s'ouvre, avec son petit tintement | `volume` 1,2 |
| [`ZippoStrike`](#zippostrike) | `_Body` | `9121005779` | Zippo Lighter 3 (SFX) | ProSoundEffects (vérifié) | 0,7 s | la molette puis le « fff » de la mèche qui prend | `volume` 1,5 |
| [`ZippoClose`](#zippoclose) | `_Body` | `9121005783` | Zippo Lighter 5 (SFX) | ProSoundEffects (vérifié) | 0,7 s | un « clac » sec, sans tintement : le couvercle refermé | `volume` 0,7 |
| [`FlameFlare`](#flameflare) | `_Body` | `9125616655` | Kerosene Explosion Whooshing Poofs Crackling | ProSoundEffects (vérifié) | 1,1 s | un « pouf » de kérosène qui s'embrase : la boule de feu courte | `volume` 2,2 |
|  |  | `9125615451` | Kerosene Explosion Whooshing Poofs Crackling | ProSoundEffects (vérifié) | 1,05 s | variante |  |
|  |  | `9125616715` | Kerosene Explosion Whooshing Poofs Crackling | ProSoundEffects (vérifié) | 1,2 s | variante, un peu plus longue |  |
| [`MolotovLight`](#molotovlight) | `_Body` | `9114442370` | Fire Whoosh 13 (SFX) | ProSoundEffects (vérifié) | 0,8 s | petit souffle de feu (torche à kérosène) : le chiffon qui prend, joué un peu plus grave | `volume` 1,4, `pitch` 0,9, début coupé 0,05 s |
|  |  | `9114446852` | Fire Whoosh 15 (SFX) | ProSoundEffects (vérifié) | 0,8 s | variante |  |
| [`MolotovThrow`](#molotovthrow) | `_Body` | `9114463219` | Flame Licks 8 (SFX) | ProSoundEffects (vérifié) | 1,7 s | une torche agitée qui passe : la flamme du chiffon qui file | `volume` 1,25, début coupé 0,15 s |
|  |  | `9114463410` | Flame Licks 10 (SFX) | ProSoundEffects (vérifié) | 1,9 s | variante |  |
|  |  | `9114463016` | Flame Licks 4 (SFX) | ProSoundEffects (vérifié) | 1,9 s | variante |  |
| [`MolotovShatter`](#molotovshatter) | `_Transient` | `9113553645` | Bottle Breaks 1 (SFX) | ProSoundEffects (vérifié) | 4,5 s | une grande bouteille en verre (1,2 l) jetée sur du béton (coupée à 2,2 s) | `volume` 1,6, début coupé 0,2 s, coupé à 2,2 s |
|  |  | `9113552246` | Bottle Breaks 3 (SFX) | ProSoundEffects (vérifié) | 3,2 s | variante |  |
|  | `_Mechanism` | `9125702439` | Mud Puddle Splash Shallow Water Impacts | ProSoundEffects (vérifié) | 0,9 s | liquide qui gicle sur le sol | `volume` 1,5, `pitch` 0,9 |
|  |  | `9125702803` | Mud Puddle Splash Shallow Water Impacts | ProSoundEffects (vérifié) | 0,8 s | variante |  |
| [`FuelIgnite`](#fuelignite) | `_Body` | `9114430091` | Fire Burst 2 (SFX) | ProSoundEffects (vérifié) | 5,8 s | une vague de flammes qui gronde (coupée à 3 s, la flaque prend le relais) | `volume` 0,9, début coupé 0,15 s, coupé à 3 s |
|  |  | `9114432358` | Fire Burst 11 (SFX) | ProSoundEffects (vérifié) | 5,9 s | variante, plus sourde |  |
|  | `_Sub` | `9114554567` | Gas Fire Explosion 3 (SFX) | ProSoundEffects (vérifié) | 4 s | le « whoump » grave de l'essence, joué plus bas et court | `volume` 0,35, `pitch` 0,8, coupé à 1,5 s |
| [`PoolFire`](#poolfire) | `_Body` | `82555625627924` | Fire burning SFX 1 | Obamacaremathlab | 5 s | feu qui brûle, publié « Loopable » (BOUCLE) | `volume` 0,8 |
|  | `_Mechanism` | `516449725` | Fire Crackling | KittyNebulaPlays | 8 s | crépitement de feu, très bas : du grain sous la flaque (BOUCLE) | `volume` 0,3 |
| [`FuelSwig`](#fuelswig) | `_Body` | `9114171960` | Drinking Cu Gulping 5 (SFX) | ProSoundEffects (vérifié) | 0,9 s | une gorgée bue de près | `volume` 2,5, début coupé 0,05 s |
|  |  | `9114172109` | Drinking Cu Gulping 6 (SFX) | ProSoundEffects (vérifié) | 1,2 s | variante |  |
| [`FireBreath`](#firebreath) | `_Body` | `9114446277` | Fire Whoosh 6 (SFX) | ProSoundEffects (vérifié) | 1,5 s | jet de kérosène à travers une torche (« usage : lance-flammes ») : c'est ce que fait un cracheur de feu | `volume` 1,6, début coupé 0,15 s |
|  |  | `9117987278` | Pyro Fire Ball Burst 12 (SFX) | ProSoundEffects (vérifié) | 1,2 s | jet de feu court (effets pyrotechniques de cinéma) |  |
| [`FuelSplash`](#fuelsplash) | `_Body` | `9125702439` | Mud Puddle Splash Shallow Water Impacts | ProSoundEffects (vérifié) | 0,9 s | liquide qui gicle sur le sol | `volume` 2,2 |
|  |  | `9125702803` | Mud Puddle Splash Shallow Water Impacts | ProSoundEffects (vérifié) | 0,8 s | variante |  |
|  | `_Mechanism` | `9126173160` | Water Burst Movement Out Of Liquid Splashing | ProSoundEffects (vérifié) | 6,6 s | le liquide qui part d'un coup (coupé à 1 s) | `volume` 1,2, coupé à 1 s |
| [`BodyBurn`](#bodyburn) | `_Body` | `140718666763137` | fire_burning1 | Loyalist6283 | 5 s | feu qui brûle de près (BOUCLE) | `volume` 0,8 |
|  | `_Mechanism` | `9079463756` | Fire Crackling | Vults_x | 8 s | crépitement enregistré dans une cheminée : les vêtements qui crépitent (BOUCLE) | `volume` 0,3 |
| [`SelfIgnite`](#selfignite) | `_Body` | `9117987278` | Pyro Fire Ball Burst 12 (SFX) | ProSoundEffects (vérifié) | 1,2 s | jet de feu court (effets pyrotechniques de cinéma) | `volume` 1,6, début coupé 0,2 s |
|  |  | `9117983605` | Pyro Fire Ball Burst 9 (SFX) | ProSoundEffects (vérifié) | 1,5 s | variante, plus forte |  |
| [`FuelPour`](#fuelpour) | `_Body` | `9120575856` | Water Pour 1 (SFX) | ProSoundEffects (vérifié) | 3,6 s | un liquide versé qui éclabousse du béton (coupé à 1,2 s) | `volume` 2,5, début coupé 0,05 s, coupé à 1,2 s |
| [`CanThrow`](#canthrow) | `_Body` | `9116536883` | Metal Can Large Sized Hit Drop 1 (SFX) | ProSoundEffects (vérifié) | 3,1 s | un grand bidon de métal vide qui tombe et sonne creux (coupé à 2 s) | `volume` 0,6, coupé à 2 s |
| [`ZippoDrop`](#zippodrop) | `_Body` | `9114462912` | Flame Licks 2 (SFX) | ProSoundEffects (vérifié) | 1,6 s | une petite flamme qui passe : le Zippo allumé qui tombe, joué plus aigu | `volume` 0,9, `pitch` 1,15, début coupé 0,15 s |
| [`BodyIgnite`](#bodyignite) | `_Body` | `9114554766` | Gas Fire Explosion 4 (SFX) | ProSoundEffects (vérifié) | 4,2 s | l'essence qui s'embrase d'un coup, rugissante (coupée à 2,5 s) | `volume` 0,75, coupé à 2,5 s |
|  | `_Tail` | `9119165650` | Sizzle Short And Explosive Sear 4 (SFX) | ProSoundEffects (vérifié) | 1,4 s | une saisie qui grésille : la chair et le tissu qui brûlent | `volume` 1, début coupé 0,15 s |
| [`BurnScream`](#burnscream) | `_Body` | `9116454870` | Male Screams In Pain Injury Yells Agony 1 (SFX) | ProSoundEffects (vérifié) | 2,4 s | un homme qui hurle de douleur (coupé à 1,4 s) | `volume` 1,3, début coupé 0,05 s, coupé à 1,4 s |
|  |  | `9125652466` | Male Scream Short Yelling Bursts Death Cries | ProSoundEffects (vérifié) | 1,4 s | cri d'agonie bref |  |
|  |  | `9125652432` | Male Scream Short Yelling Bursts Death Cries | ProSoundEffects (vérifié) | 1,1 s | variante |  |

> Les sons de la communauté ont été choisis sur leur nom et leur description (on ne peut pas les télécharger sans compte) ; ceux de Pro Sound Effects ont été vérifiés sur leur forme d'onde (durée, attaque, blanc au début, niveau). Si un son ne te plaît pas en jeu, dis-le : on en prend un autre.

## Plus tard (optionnel) : générer ses propres sons

Pas nécessaire : les sons de la boutique ci-dessus suffisent. Mais pour un son encore plus précis, chaque fiche plus bas donne un design en cinq couches et un **prompt** prêt à coller dans un générateur audio.

1. Pour chaque son, copie le **prompt** de chaque couche (en anglais) dans ton générateur audio. Un fichier par couche.
2. Coupe le silence au début du fichier (sinon la couche arrive en retard).
3. Les sons marqués **BOUCLE** doivent boucler sans clic : coupe-les sur un passage à zéro et fais un fondu enchaîné début / fin.
4. Importe-les (*Creator Hub → Creations → Audio → Upload*), copie chaque ID et mets-le dans `STOCK` (`tools/sounds/pyro_sounds.py`) à la place de celui de la boutique, puis lance `python3 tools/sounds/pyro_sounds.py --write`.
5. Rojo synchronise, *Play*. Si une couche est trop forte ou faible, change seulement son `volume`.

> Le texte de départ de chaque fiche est exactement ta demande (le *brief*) ; la suite en est la réponse. Ces fichiers (`Sounds.luau` section Pyromane, `SoundCues.luau`, ce document) sont générés par `tools/sounds/pyro_sounds.py` : pour changer un design ou un ID, change-le là puis lance `python3 tools/sounds/pyro_sounds.py --write`.

## La liste

| Son | Ce que c'est | Quand |
|---|---|---|
| [`ZippoOpen`](#zippoopen) | Le couvercle du Zippo qui s'ouvre d'un coup de pouce (le « clink »). | ZIPPO FLARE, MOLOTOV, FIRE BREATH, l'Awakening et le finisher, quand il ouvre le briquet. |
| [`ZippoStrike`](#zippostrike) | La molette frottée sur la pierre, les étincelles, la mèche qui prend feu. | Juste après ZippoOpen (ZIPPO FLARE, MOLOTOV, FIRE BREATH, Awakening, finisher). |
| [`ZippoClose`](#zippoclose) | Le couvercle refermé d'un coup sec : la flamme étouffée. | À la fin de ZIPPO FLARE et de FIRE BREATH. |
| [`FlameFlare`](#flameflare) | Le jet de liquide à briquet à travers la flamme : une boule de feu courte dans le visage. | ZIPPO FLARE, au moment du coup (0,42 s). |
| [`MolotovLight`](#molotovlight) | Le chiffon imbibé d'essence au goulot qui prend feu. | MOLOTOV, quand le briquet touche le chiffon (0,3 s). |
| [`MolotovThrow`](#molotovthrow) | Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air. | MOLOTOV et FIREBOMB, au lâcher de la bouteille. |
| [`MolotovShatter`](#molotovshatter) | La bouteille qui éclate au sol : le verre, les éclats, l'essence qui gicle. | Quand le Molotov se brise (sol, mur ou sur quelqu'un). |
| [`FuelIgnite`](#fuelignite) | L'essence répandue qui s'embrase : la boule de feu. | Juste après MolotovShatter (la flaque prend feu). |
| [`PoolFire`](#poolfire) | La flaque d'essence qui brûle (BOUCLE, tant que le feu dure). **BOUCLE** | Pendant tout le feu au sol du Molotov, en 3D sur la flaque, baisse quand le feu meurt. |
| [`FuelSwig`](#fuelswig) | Il boit une gorgée d'essence (pour la cracher) : le bouchon, le liquide, la bouche pleine. | FIRE BREATH / INFERNO BREATH, au début. |
| [`FireBreath`](#firebreath) | Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit. | FIRE BREATH (0,55 s → 1 s) et INFERNO BREATH (plus long). |
| [`FuelSplash`](#fuelsplash) | L'essence projetée hors du jerrican sur quelqu'un (DOUSE). | DOUSE, au balancement du jerrican (0,42 s). |
| [`BodyBurn`](#bodyburn) | Un corps et ses vêtements en feu (BOUCLE). Aussi, plus bas, ses poings en feu pendant l'Awakening. **BOUCLE** | Sur la victime du finisher pendant qu'elle brûle, et (en plus faible) sur les avant-bras du Pyromane en Awakening. |
| [`SelfIgnite`](#selfignite) | Il allume ses propres avant-bras imbibés d'essence (BURNING MAN). | L'activation de l'Awakening (0,55 s). |
| [`FuelPour`](#fuelpour) | L'essence versée du jerrican sur le corps (finisher). | IMMOLATION, de 0,4 s à 1,45 s. |
| [`CanThrow`](#canthrow) | Le jerrican vide jeté par terre (finisher). | IMMOLATION, à 1,6 s. |
| [`ZippoDrop`](#zippodrop) | Le Zippo allumé lâché sur le corps (finisher). | IMMOLATION, à 2,8 s (il tombe, touche la poitrine à 3,05 s). |
| [`BodyIgnite`](#bodyignite) | Le corps imbibé qui s'embrase d'un coup (« whump »). | IMMOLATION, à 3,05 s. |
| [`BurnScream`](#burnscream) | Les cris de la victime qui brûle (coupés à la mort). | IMMOLATION, de 3,2 s à 4,6 s (coupé net au « Still »). |

## ZippoOpen

Le couvercle du Zippo qui s'ouvre d'un coup de pouce (le « clink »). **Quand :** ZIPPO FLARE, MOLOTOV, FIRE BREATH, l'Awakening et le finisher, quand il ouvre le briquet.

> *Brief :* Design a layered sound effect for a brass Zippo-style lighter lid being flicked open with the thumb. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `ZippoOpen_Transient` | -4 dB | 0.63 (vide : muette) |
| `ZippoOpen_Mechanism` | -7 dB | 0.45 (vide : muette) |
| `ZippoOpen_Body` | -12 dB | 1.2 (boutique) |
| `ZippoOpen_Sub` | -20 dB | 0.1 (vide : muette) |
| `ZippoOpen_Tail` | -18 dB | 0.13 (vide : muette) |

Le son entier est à -4 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## ZippoStrike

La molette frottée sur la pierre, les étincelles, la mèche qui prend feu. **Quand :** Juste après ZippoOpen (ZIPPO FLARE, MOLOTOV, FIRE BREATH, Awakening, finisher).

> *Brief :* Design a layered sound effect for a Zippo lighter's flint wheel being struck and the wick catching fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `ZippoStrike_Transient` | -4 dB | 0.63 (vide : muette) |
| `ZippoStrike_Mechanism` | -8 dB | 0.4 (vide : muette) |
| `ZippoStrike_Body` | -6 dB | 1.5 (boutique) |
| `ZippoStrike_Sub` | -18 dB | 0.13 (vide : muette) |
| `ZippoStrike_Tail` | -16 dB | 0.16 (vide : muette) |

Le son entier est à -4 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## ZippoClose

Le couvercle refermé d'un coup sec : la flamme étouffée. **Quand :** À la fin de ZIPPO FLARE et de FIRE BREATH.

> *Brief :* Design a layered sound effect for a Zippo lighter lid snapping shut and smothering the flame. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `ZippoClose_Transient` | -5 dB | 0.56 (vide : muette) |
| `ZippoClose_Mechanism` | -10 dB | 0.32 (vide : muette) |
| `ZippoClose_Body` | -14 dB | 0.7 (boutique) |
| `ZippoClose_Sub` | -23 dB | 0.07 (vide : muette) |
| `ZippoClose_Tail` | -17 dB | 0.14 (vide : muette) |

Le son entier est à -5 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FlameFlare

Le jet de liquide à briquet à travers la flamme : une boule de feu courte dans le visage. **Quand :** ZIPPO FLARE, au moment du coup (0,42 s).

> *Brief :* Design a layered sound effect for lighter fluid squirted through a lighter flame into someone's face, flaring into a burst of fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bidon de liquide pressé, le jet qui part | 2-8 kHz | « tsst » sous pression | 0 ms | 80 ms |
| Mécanique | Le jet de liquide qui crépite en traversant la flamme | 1-9 kHz | sifflement mouillé et crépitant | 20 ms | 250 ms |
| Corps | Le liquide qui s'embrase d'un coup | 150 Hz-3 kHz | « fwoosh » de flamme, rond et chaud | 50 ms | 500 ms |
| Grave (sub) | La bouffée d'air chaud | 40-120 Hz | « whump » grave et mou | 50 ms | 300 ms |
| Queue (la fin) | Les gouttes qui brûlent encore | 1-6 kHz | petits crépitements et grésillements qui s'éteignent | 250 ms | 900 ms |

### Les prompts (à coller)

**`FlameFlare_Transient`**
```
Short pressurized squirt of liquid from a small squeezed metal can, sharp tss sound, close-miked, dry, isolated, 0.15 seconds.
```
**`FlameFlare_Mechanism`**
```
Hiss and spatter of a thin stream of lighter fluid spraying through a flame, wet sizzling crackle, isolated, 0.3 seconds.
```
**`FlameFlare_Body`**
```
Sudden fwoosh of a burst of flame flaring up from sprayed fuel, warm roaring whoosh, medium size, no explosion, isolated, 0.6 seconds.
```
**`FlameFlare_Sub`**
```
Soft deep whump of air pushed by a flame flaring up, low-frequency pressure puff, no crack, isolated, 0.3 seconds.
```
**`FlameFlare_Tail`**
```
Small burning droplets crackling and sizzling as they die out, sparse pops fading away, isolated, 1 second.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FlameFlare_Transient` | -5 dB | 0.56 (vide : muette) |
| `FlameFlare_Mechanism` | -7 dB | 0.45 (vide : muette) |
| `FlameFlare_Body` | -1 dB | 2.2 (boutique) |
| `FlameFlare_Sub` | -11 dB | 0.28 (vide : muette) |
| `FlameFlare_Tail` | -13 dB | 0.22 (vide : muette) |

Le son entier est à -1 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## MolotovLight

Le chiffon imbibé d'essence au goulot qui prend feu. **Quand :** MOLOTOV, quand le briquet touche le chiffon (0,3 s).

> *Brief :* Design a layered sound effect for a petrol-soaked rag stuffed in a bottle neck being lit and catching fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | La flamme du briquet qui touche le tissu imbibé | 1-6 kHz | petit « pff » sec | 0 ms | 60 ms |
| Mécanique | Les fibres du coton qui s'enflamment | 2-10 kHz | crépitement fin et sec | 20 ms | 400 ms |
| Corps | Le chiffon imbibé d'essence qui s'embrase | 150 Hz-2.5 kHz | « whouf » chaud qui gonfle | 60 ms | 500 ms |
| Grave (sub) | La flamme qui monte | 40-120 Hz | souffle grave doux | 60 ms | 300 ms |
| Queue (la fin) | Le chiffon qui brûle en flottant | 300 Hz-4 kHz | flamme de tissu qui flotte et crépite | 300 ms | 1200 ms |

### Les prompts (à coller)

**`MolotovLight_Transient`**
```
Tiny dry puff as a lighter flame touches a fuel-soaked cloth, short soft pop, isolated, 0.1 seconds.
```
**`MolotovLight_Mechanism`**
```
Fine crisp crackle of cotton fibres catching fire, dry tight crackling, close-miked, isolated, 0.5 seconds.
```
**`MolotovLight_Body`**
```
Petrol-soaked rag bursting into flame, warm rising whoof of fire catching on fabric, medium-small, no explosion, isolated, 0.6 seconds.
```
**`MolotovLight_Sub`**
```
Soft low bloom of a flame rising, subtle low-frequency airy push, isolated, 0.3 seconds.
```
**`MolotovLight_Tail`**
```
Small rag flame burning and fluttering on a bottle neck, soft roar with light crackle, steady, isolated, 1.2 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `MolotovLight_Transient` | -9 dB | 0.35 (vide : muette) |
| `MolotovLight_Mechanism` | -9 dB | 0.35 (vide : muette) |
| `MolotovLight_Body` | -3 dB | 1.4 (boutique) |
| `MolotovLight_Sub` | -17 dB | 0.14 (vide : muette) |
| `MolotovLight_Tail` | -12 dB | 0.25 (vide : muette) |

Le son entier est à -3 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## MolotovThrow

Le lancer : le bras, le liquide qui ballotte, la flamme du chiffon qui file dans l'air. **Quand :** MOLOTOV et FIREBOMB, au lâcher de la bouteille.

> *Brief :* Design a layered sound effect for a lit Molotov cocktail bottle being thrown overhand and flying past. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `MolotovThrow_Transient` | -7 dB | 0.45 (vide : muette) |
| `MolotovThrow_Mechanism` | -12 dB | 0.25 (vide : muette) |
| `MolotovThrow_Body` | -3 dB | 1.25 (boutique) |
| `MolotovThrow_Sub` | -19 dB | 0.11 (vide : muette) |
| `MolotovThrow_Tail` | -15 dB | 0.18 (vide : muette) |

Le son entier est à -3 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## MolotovShatter

La bouteille qui éclate au sol : le verre, les éclats, l'essence qui gicle. **Quand :** Quand le Molotov se brise (sol, mur ou sur quelqu'un).

> *Brief :* Design a layered sound effect for a glass Molotov bottle smashing on concrete and splashing petrol. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le verre épais qui casse à l'impact | 1-12 kHz | « crack » de verre net et violent | 0 ms | 60 ms |
| Mécanique | Les éclats qui se dispersent et tintent | 3-14 kHz | pluie d'éclats de verre qui tintent et roulent | 20 ms | 600 ms |
| Corps | L'essence qui gicle et claque au sol | 200 Hz-4 kHz | éclaboussure de liquide mouillée | 15 ms | 350 ms |
| Grave (sub) | Le choc sur le béton | 40-150 Hz | « toum » sourd | 0 ms | 150 ms |
| Queue (la fin) | Les derniers éclats qui se posent, l'essence qui coule | 2-10 kHz | petits tintements épars et gouttes | 300 ms | 1200 ms |

### Les prompts (à coller)

**`MolotovShatter_Transient`**
```
Sharp loud crack of a thick glass bottle smashing on concrete, the first impact only, bright, close, dry, isolated one-shot, 0.1 seconds.
```
**`MolotovShatter_Mechanism`**
```
Shards of a broken glass bottle scattering and tinkling across a concrete floor, bright granular glass debris, isolated, 0.7 seconds.
```
**`MolotovShatter_Body`**
```
Wet splash of about a litre of liquid slapping onto concrete and spreading, splattering, isolated, 0.4 seconds.
```
**`MolotovShatter_Sub`**
```
Low dull thud of a heavy bottle hitting concrete, weight only, no glass, isolated, 0.2 seconds.
```
**`MolotovShatter_Tail`**
```
Last few glass fragments settling with sparse tinkles, a little liquid trickling, quiet, isolated, 1.2 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `MolotovShatter_Transient` | +0 dB | 1.6 (boutique) |
| `MolotovShatter_Mechanism` | -5 dB | 1.5 (boutique) |
| `MolotovShatter_Body` | -3 dB | 0.71 (vide : muette) |
| `MolotovShatter_Sub` | -10 dB | 0.32 (vide : muette) |
| `MolotovShatter_Tail` | -14 dB | 0.2 (vide : muette) |

Le son entier est à +0 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FuelIgnite

L'essence répandue qui s'embrase : la boule de feu. **Quand :** Juste après MolotovShatter (la flaque prend feu).

> *Brief :* Design a layered sound effect for spilled petrol on the ground igniting into a fireball. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FuelIgnite_Transient` | -2 dB | 0.79 (vide : muette) |
| `FuelIgnite_Mechanism` | -6 dB | 0.5 (vide : muette) |
| `FuelIgnite_Body` | +0 dB | 0.9 (boutique) |
| `FuelIgnite_Sub` | -4 dB | 0.35 (boutique) |
| `FuelIgnite_Tail` | -8 dB | 0.4 (vide : muette) |

Le son entier est à +0 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## PoolFire

La flaque d'essence qui brûle (BOUCLE, tant que le feu dure). **Quand :** Pendant tout le feu au sol du Molotov, en 3D sur la flaque, baisse quand le feu meurt. C'est une **BOUCLE** : toutes les couches bouclent ensemble (le *Début* est 0).

> *Brief :* Design a layered sound effect for a pool of burning petrol on a street floor (seamless loop). Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `PoolFire_Transient` | -11 dB | 0.28 (vide : muette) |
| `PoolFire_Mechanism` | -13 dB | 0.3 (boutique) |
| `PoolFire_Body` | -3 dB | 0.8 (boutique) |
| `PoolFire_Sub` | -13 dB | 0.22 (vide : muette) |
| `PoolFire_Tail` | -17 dB | 0.14 (vide : muette) |

Le son entier est à -3 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FuelSwig

Il boit une gorgée d'essence (pour la cracher) : le bouchon, le liquide, la bouche pleine. **Quand :** FIRE BREATH / INFERNO BREATH, au début.

> *Brief :* Design a layered sound effect for a man taking a mouthful of fuel from a metal hip flask. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bouchon métallique dévissé | 1-8 kHz | petit clic de métal | 0 ms | 60 ms |
| Mécanique | Le liquide qui coule dans le flacon de métal | 300 Hz-3 kHz | glouglou métallique | 80 ms | 350 ms |
| Corps | La bouche qui se remplit | 150 Hz-2 kHz | gorgée humide, bouche fermée | 150 ms | 400 ms |
| Grave (sub) | La gorge | 60-200 Hz | résonance grave de la poitrine | 150 ms | 300 ms |
| Queue (la fin) | Le souffle par le nez | 500 Hz-5 kHz | expiration courte et tendue | 500 ms | 400 ms |

### Les prompts (à coller)

**`FuelSwig_Transient`**
```
Small metallic click of a hip flask screw cap being opened, close, dry, isolated, 0.1 seconds.
```
**`FuelSwig_Mechanism`**
```
Liquid glugging out of a small metal flask, hollow metallic glug, close, isolated, 0.4 seconds.
```
**`FuelSwig_Body`**
```
A man filling his mouth with liquid and holding it, wet gulp with closed lips, no swallowing, close-miked, isolated, 0.4 seconds.
```
**`FuelSwig_Sub`**
```
Very subtle low throat and chest resonance of someone holding a mouthful, soft, isolated, 0.3 seconds.
```
**`FuelSwig_Tail`**
```
Short tense exhale through the nose, breathy, close-miked, isolated, 0.4 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FuelSwig_Transient` | -10 dB | 0.32 (vide : muette) |
| `FuelSwig_Mechanism` | -12 dB | 0.25 (vide : muette) |
| `FuelSwig_Body` | -6 dB | 2.5 (boutique) |
| `FuelSwig_Sub` | -22 dB | 0.08 (vide : muette) |
| `FuelSwig_Tail` | -18 dB | 0.13 (vide : muette) |

Le son entier est à -6 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FireBreath

Le cracheur de feu : l'essence pulvérisée à travers la flamme, un jet de feu qui rugit. **Quand :** FIRE BREATH (0,55 s → 1 s) et INFERNO BREATH (plus long).

> *Brief :* Design a layered sound effect for a fire breather spitting atomised fuel through a lighter flame into a roaring jet of fire. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FireBreath_Transient` | -4 dB | 0.63 (vide : muette) |
| `FireBreath_Mechanism` | -8 dB | 0.4 (vide : muette) |
| `FireBreath_Body` | +0 dB | 1.6 (boutique) |
| `FireBreath_Sub` | -6 dB | 0.5 (vide : muette) |
| `FireBreath_Tail` | -10 dB | 0.32 (vide : muette) |

Le son entier est à +0 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FuelSplash

L'essence projetée hors du jerrican sur quelqu'un (DOUSE). **Quand :** DOUSE, au balancement du jerrican (0,42 s).

> *Brief :* Design a layered sound effect for petrol flung from a metal jerrycan onto a person. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FuelSplash_Transient` | -5 dB | 0.56 (vide : muette) |
| `FuelSplash_Mechanism` | -10 dB | 1.2 (boutique) |
| `FuelSplash_Body` | -2 dB | 2.2 (boutique) |
| `FuelSplash_Sub` | -14 dB | 0.2 (vide : muette) |
| `FuelSplash_Tail` | -16 dB | 0.16 (vide : muette) |

Le son entier est à -2 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## BodyBurn

Un corps et ses vêtements en feu (BOUCLE). Aussi, plus bas, ses poings en feu pendant l'Awakening. **Quand :** Sur la victime du finisher pendant qu'elle brûle, et (en plus faible) sur les avant-bras du Pyromane en Awakening. C'est une **BOUCLE** : toutes les couches bouclent ensemble (le *Début* est 0).

> *Brief :* Design a layered sound effect for a human body and its clothes burning (seamless loop). Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `BodyBurn_Transient` | -13 dB | 0.22 (vide : muette) |
| `BodyBurn_Mechanism` | -11 dB | 0.3 (boutique) |
| `BodyBurn_Body` | -3 dB | 0.8 (boutique) |
| `BodyBurn_Sub` | -15 dB | 0.18 (vide : muette) |
| `BodyBurn_Tail` | -17 dB | 0.14 (vide : muette) |

Le son entier est à -3 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## SelfIgnite

Il allume ses propres avant-bras imbibés d'essence (BURNING MAN). **Quand :** L'activation de l'Awakening (0,55 s).

> *Brief :* Design a layered sound effect for petrol-soaked forearm wraps being lit with a lighter and flaring up along both arms. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `SelfIgnite_Transient` | -6 dB | 0.5 (vide : muette) |
| `SelfIgnite_Mechanism` | -6 dB | 0.5 (vide : muette) |
| `SelfIgnite_Body` | +0 dB | 1.6 (boutique) |
| `SelfIgnite_Sub` | -8 dB | 0.4 (vide : muette) |
| `SelfIgnite_Tail` | -10 dB | 0.32 (vide : muette) |

Le son entier est à +0 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## FuelPour

L'essence versée du jerrican sur le corps (finisher). **Quand :** IMMOLATION, de 0,4 s à 1,45 s.

> *Brief :* Design a layered sound effect for petrol being poured from a jerrycan over a body lying on the ground. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bouchon du jerrican qui saute | 500 Hz-6 kHz | « clonk » métallique et « pop » d'air | 0 ms | 120 ms |
| Mécanique | Les gloussements d'air dans le jerrican | 150 Hz-1.5 kHz | glouglous creux, rythmés | 250 ms | 1000 ms |
| Corps | Le filet d'essence sur les vêtements et le corps | 200 Hz-6 kHz | coulée continue, qui éclabousse | 250 ms | 1050 ms |
| Grave (sub) | La résonance du bidon | 50-150 Hz | « bloub » grave | 250 ms | 1000 ms |
| Queue (la fin) | Les dernières gouttes | 1-8 kHz | gouttes qui tombent, filet qui s'arrête | 1150 ms | 700 ms |

### Les prompts (à coller)

**`FuelPour_Transient`**
```
Metal jerrycan cap being unclipped with a clonk and a little air pop, close, isolated, 0.2 seconds.
```
**`FuelPour_Mechanism`**
```
Rhythmic hollow glugging of air bubbles entering a metal jerrycan while it is poured, isolated, 1 second.
```
**`FuelPour_Body`**
```
Steady stream of liquid pouring onto clothes and a body lying on concrete, wet splashing pour, isolated, 1.1 seconds.
```
**`FuelPour_Sub`**
```
Low hollow resonance of a large metal can being emptied, soft bloub, sub only, isolated, 1 second.
```
**`FuelPour_Tail`**
```
Last drips of liquid from a can spout landing on fabric and concrete, the stream stopping, isolated, 0.7 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `FuelPour_Transient` | -6 dB | 0.5 (vide : muette) |
| `FuelPour_Mechanism` | -8 dB | 0.4 (vide : muette) |
| `FuelPour_Body` | -2 dB | 2.5 (boutique) |
| `FuelPour_Sub` | -16 dB | 0.16 (vide : muette) |
| `FuelPour_Tail` | -14 dB | 0.2 (vide : muette) |

Le son entier est à -2 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## CanThrow

Le jerrican vide jeté par terre (finisher). **Quand :** IMMOLATION, à 1,6 s.

> *Brief :* Design a layered sound effect for an almost empty metal jerrycan tossed aside onto a concrete floor. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le bidon qui frappe le béton | 300 Hz-6 kHz | « klang » de tôle creuse | 300 ms | 80 ms |
| Mécanique | La poignée et le bouchon qui cliquettent au rebond | 1-8 kHz | cliquetis métalliques | 330 ms | 300 ms |
| Corps | La résonance du bidon vide | 200 Hz-2 kHz | « bwong » creux qui sonne | 310 ms | 600 ms |
| Grave (sub) | Le choc | 40-120 Hz | « toum » sourd | 300 ms | 120 ms |
| Queue (la fin) | Le bidon qui glisse, le reste d'essence qui ballotte | 300 Hz-5 kHz | frottement sur le sol, clapotis | 500 ms | 700 ms |

### Les prompts (à coller)

**`CanThrow_Transient`**
```
Hollow metal jerrycan hitting a concrete floor, loud klang of thin sheet metal, the impact only, isolated, 0.1 seconds.
```
**`CanThrow_Mechanism`**
```
Rattle of a metal handle and a dangling cap as a can bounces, small metallic clatter, isolated, 0.3 seconds.
```
**`CanThrow_Body`**
```
Hollow ringing bwong of an empty metal jerrycan resonating after a hit, isolated, 0.6 seconds.
```
**`CanThrow_Sub`**
```
Low dull thud of a light metal container landing, weight only, isolated, 0.1 seconds.
```
**`CanThrow_Tail`**
```
Metal can skidding to a stop on concrete with a little liquid sloshing inside, isolated, 0.7 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `CanThrow_Transient` | -4 dB | 0.63 (vide : muette) |
| `CanThrow_Mechanism` | -10 dB | 0.32 (vide : muette) |
| `CanThrow_Body` | -8 dB | 0.6 (boutique) |
| `CanThrow_Sub` | -16 dB | 0.16 (vide : muette) |
| `CanThrow_Tail` | -16 dB | 0.16 (vide : muette) |

Le son entier est à -4 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## ZippoDrop

Le Zippo allumé lâché sur le corps (finisher). **Quand :** IMMOLATION, à 2,8 s (il tombe, touche la poitrine à 3,05 s).

> *Brief :* Design a layered sound effect for a lit Zippo lighter dropped onto a petrol-soaked body. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

| Couche | Source | Hauteur (Hz) | Texture | Début | Durée |
|---|---|---|---|---|---|
| Transitoire (l'attaque) | Le briquet qui touche la poitrine | 500 Hz-6 kHz | petit choc de métal sur tissu mouillé | 250 ms | 50 ms |
| Mécanique | Le couvercle qui cliquette | 2-8 kHz | petit cliquetis | 255 ms | 100 ms |
| Corps | La flamme qui tombe | 300 Hz-3 kHz | flamme qui flotte en chute | 0 ms | 300 ms |
| Grave (sub) | Le poids | 60-200 Hz | « tup » mou | 250 ms | 80 ms |
| Queue (la fin) | La flamme qui lèche le tissu | 500 Hz-4 kHz | petit sifflement avant l'embrasement | 280 ms | 200 ms |

### Les prompts (à coller)

**`ZippoDrop_Transient`**
```
Small metal lighter landing on a wet jacket on a body, soft dull tap, isolated, 0.1 seconds.
```
**`ZippoDrop_Mechanism`**
```
Tiny rattle of a lighter lid as it lands, light metallic tick, isolated, 0.1 seconds.
```
**`ZippoDrop_Body`**
```
Small lighter flame fluttering as it falls through the air, brief soft whoosh, isolated, 0.3 seconds.
```
**`ZippoDrop_Sub`**
```
Very soft low thud of a small object on a body, subtle, isolated, 0.1 seconds.
```
**`ZippoDrop_Tail`**
```
Tiny flame licking at a fuel-soaked fabric, a short rising hiss right before ignition, isolated, 0.2 seconds.
```

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `ZippoDrop_Transient` | -6 dB | 0.5 (vide : muette) |
| `ZippoDrop_Mechanism` | -12 dB | 0.25 (vide : muette) |
| `ZippoDrop_Body` | -12 dB | 0.9 (boutique) |
| `ZippoDrop_Sub` | -20 dB | 0.1 (vide : muette) |
| `ZippoDrop_Tail` | -16 dB | 0.16 (vide : muette) |

Le son entier est à -6 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## BodyIgnite

Le corps imbibé qui s'embrase d'un coup (« whump »). **Quand :** IMMOLATION, à 3,05 s.

> *Brief :* Design a layered sound effect for a petrol-soaked person on the ground going up in flames. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `BodyIgnite_Transient` | -2 dB | 0.79 (vide : muette) |
| `BodyIgnite_Mechanism` | -5 dB | 0.56 (vide : muette) |
| `BodyIgnite_Body` | +0 dB | 0.75 (boutique) |
| `BodyIgnite_Sub` | -4 dB | 0.63 (vide : muette) |
| `BodyIgnite_Tail` | -8 dB | 1.0 (boutique) |

Le son entier est à +0 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

## BurnScream

Les cris de la victime qui brûle (coupés à la mort). **Quand :** IMMOLATION, de 3,2 s à 4,6 s (coupé net au « Still »).

> *Brief :* Design a layered sound effect for a man screaming in agony while burning, his voice breaking and cut short. Break it into transient, mechanism, body, sub, and tail layers, and for each give the source, pitch range, texture, and timing. Then write one ready-to-paste audio generation prompt per layer, plus suggested mix levels.

### Les couches

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

### Le mix

| Couche | Niveau | `volume` |
|---|---|---|
| `BurnScream_Transient` | -5 dB | 0.56 (vide : muette) |
| `BurnScream_Mechanism` | -9 dB | 0.35 (vide : muette) |
| `BurnScream_Body` | -1 dB | 1.3 (boutique) |
| `BurnScream_Sub` | -15 dB | 0.18 (vide : muette) |
| `BurnScream_Tail` | -9 dB | 0.35 (vide : muette) |

Le son entier est à -1 dB ; chaque couche est réglée par rapport à la plus forte du son (0 dB). Le *Sub* reste bas : il doit donner du poids, pas du bruit.

