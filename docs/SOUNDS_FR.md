# Ajouter les sons

Tous les sons sont listés dans **`src/shared/Sounds.luau`**. Chaque son a une **liste** d'IDs
(`ids`) : le jeu en tire un au hasard à chaque fois (jamais deux fois le même de suite), pour qu'un
combat ne sonne pas comme une boucle. Tant qu'une liste est vide (`{}`), le jeu ne joue rien pour ce
son (ou son son de secours `fallback`) : tu peux les remplir dans l'ordre que tu veux.

Déjà remplis : `Swing` (3 sons) et `Hit` (3 sons). `HeavySwing` et `HeavyHit` (le finisher)
réutilisent ces sons en plus **grave** et plus **fort** tant qu'ils n'ont pas les leurs.

## 1. Trouver un son
- **Creator Store** (dans Studio : *Toolbox* → onglet *Audio*, ou sur create.roblox.com) :
  cherche par exemple `punch`, `whoosh`, `block`, `slide`.
- Ou **importe ton propre fichier** (.mp3 / .ogg) : *Creator Hub → Creations → Audio → Upload*.
  Roblox vérifie le fichier (quelques minutes).

> Le son doit être **public** (Creator Store) ou t'appartenir, sinon il ne se joue pas en jeu.

## 2. Récupérer son ID
Clic droit sur le son → *Copy Asset ID*. Tu obtiens un nombre (ex. `1234567890`).

## 3. Le mettre dans le jeu
Dans VS Code, ouvre `src/shared/Sounds.luau` et ajoute le nombre dans la liste `ids`
(un seul, ou plusieurs séparés par des virgules pour avoir des variantes) :

```lua
Block = { ids = { 1234567890, 2345678901 }, volume = 0.6, pitch = 1, pitchVariation = 0.1 },
```

- `volume` : de 0 à 1.
- `pitch` : 1 = normal ; 0.8 = plus grave et plus lourd ; 1.2 = plus aigu.
- `pitchVariation` : chaque fois, le son est un peu plus aigu ou grave au hasard (0.1 = ±10 %),
  pour qu'un même coup ne sonne jamais exactement pareil.
- Facultatif : `volumeVariation` (± dB au hasard à chaque fois), `start` (secondes sautées au
  début du fichier), `length` (secondes jouées) et `fadeOut` (le fondu à ce moment-là), et
  `trims = { [id] = { start = 0.2, gain = 0.8 } }` : le début et le volume **propres à un ID**,
  pour que des variantes enregistrées à des niveaux différents sonnent pareil.

Rojo synchronise, *Play*.

## Sons en couches (Pyromane)
Les sons du kit **Pyromane** sont faits de **1 à 5 couches** chacun (`_Transient`, `_Mechanism`,
`_Body`, `_Sub`, `_Tail`), chaque couche étant une entrée à part dans `Sounds.luau` (section
*Pyromaniac*, à la fin du fichier) jouée ensemble au bon moment (`src/shared/SoundCues.luau`).
Ce sont des sons gratuits de Pro Sound Effects, choisis et réglés par mesure ; la liste, les
mesures et les réglages sont dans **[`SONS_PYROMANE_FR.md`](SONS_PYROMANE_FR.md)**. Tant
qu'une couche n'a pas d'ID, elle est muette.

## Les sons et quand ils jouent
| Nom | Quand |
|---|---|
| `Swing` | Coups M1 1 à 3 (souffle du poing) |
| `HeavySwing` | Coup M1 4 (le finisher) |
| `Hit` | Un coup touche |
| `HeavyHit` | Le finisher touche |
| `Block` | Un coup tape dans la garde |
| `Parry` | Parade réussie |
| `GuardBreak` | Garde brisée |
| `Dash` | Esquive (Q) |
| `Dodge` | Un coup esquivé pendant le dash |
| `Slide` | Début d'une glissade |
| `Vault` | Passage par-dessus un obstacle bas |
| `Mantle` | Attraper un rebord |
| `FootConcrete` | Un pas sur béton, bitume, brique, pierre, plastique (le son par défaut) |
| `FootDirt` | Un pas sur terre, sable, boue, gravier, neige (et tapis, plus bas) |
| `FootWood` | Un pas sur du bois ou des planches |
| `FootMetal` | Un pas sur du métal (plaques, grilles, métal rouillé) |
| `FootGrass` | Un pas sur l'herbe |
| `BloodDrip` | Une goutte de sang qui tombe d'un blessé (doux, discret) |
| `BloodSplat` | Une giclée de sang sur un coup lourd qui saigne |
| `ArterialSpurt` | Chaque jet d'une artère coupée (finishers) |
| `BloodGurgle` | Le sang dans la gorge ouverte (finisher de la batte) |

Les sons sont joués **en 3D** sur le personnage : on les entend plus fort de près, et du bon côté.
Ils sont tous téléchargés au lancement du jeu, pour que le premier coup ne soit pas muet.

> Si un son ne joue pas : ouvre l'Output dans Studio. Un message `Failed to load sound` veut dire
> que le son est privé ou supprimé — il faut qu'il soit public ou qu'il appartienne à ton compte.

## Les bruits de pas

Chaque fois qu'un pied touche le sol (le moment exact vient de l'animation de marche),
le jeu regarde la matière du sol sous ce pied et joue un son `Foot...` au hasard dans sa
liste, depuis la jambe, en 3D. Plus fort en courant, plus doux en marchant. On l'entend
jusqu'à 45 studs. Le bruit de pas de Roblox (le son « Running ») est coupé, sinon on
entendrait les deux. Quelle matière donne quel son : `STEP_SOUND` en haut de
`src/client/Combat/Footsteps.luau`. Accroupi ou en boitant, pas de bruit de pas.
