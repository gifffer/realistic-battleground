# Animations (faites en code)

Toutes les animations du jeu sont **écrites en code** : rien à faire dans l'Animation Editor,
rien à publier. Le code tourne directement les 6 articulations du personnage R6
(tête, torse, 2 bras, 2 jambes).

## Où elles sont
| Fichier | Contenu |
|---|---|
| `src/client/Animation/MovementClips.luau` | Accroupi (immobile / marche), glissade, vault, mantle, inclinaison en course |
| `src/client/Animation/CombatClips.luau` | 4 coups M1, blocage, coup bloqué, parade, guard break, sonné, réactions aux coups, 4 dashs |
| `src/client/Animation/R6Pose.luau` | Les maths (conversion des angles, interpolation entre les poses) |
| `src/client/Controllers/CharacterAnimationController.luau` | Qui joue quoi, sur quel personnage, avec les fondus |

Chaque client anime **tous** les combattants (joueurs et mannequins), à partir de ce que le serveur
partage (état de mouvement, blocage, étourdissement, coups). Tout le monde voit donc les animations
de tout le monde.

## Modifier une pose
Une animation = une liste d'images clés (`keyframes`). Chaque image donne, pour certaines
articulations, une rotation en degrés (`rot`) et parfois un décalage en studs (`pos`) :

- `rot.X > 0` : un bras / une jambe part **vers l'avant** ; le torse / la tête **penche en arrière**.
- `rot.Y` : tourne à gauche / à droite. `rot.Z` : penche sur le côté.
- `pos` sur `Root` : déplace tout le corps (ex. `Y = -0.9` → 0,9 stud plus bas).
- `pos` sur une jambe : la remonte dans le torse (c'est comme ça qu'on simule un genou plié en R6).

Change les nombres dans VS Code, Rojo synchronise, *Play*. Si tu veux une pose différente,
le plus simple est de m'envoyer une **image de référence** et une capture de ce qui ne va pas.

> ⚠️ Le moment de l'impact des coups M1 est à **0,15 s** dans `CombatClips.luau` : il doit rester
> égal à `Config.Combat.HIT_DELAY` (le moment où le serveur vérifie la hitbox).
