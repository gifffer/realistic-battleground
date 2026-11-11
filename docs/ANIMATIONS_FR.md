# Faire les animations de combat (guide débutant)

Sur Roblox, une animation ne marche dans un jeu **que si elle appartient au même propriétaire
que le jeu**. Le jeu est sur ton compte perso → publie les animations sur **ton compte perso**.

## 1. Préparer un mannequin (rig)
1. Ouvre ta place dans Studio.
2. Onglet **Avatar** → **Rig Builder** → choisis **R6** → **Block Rig**.
   (Le jeu est en **R6** : seulement 6 parties à animer — tête, torse, 2 bras, 2 jambes.)
   Un mannequin apparaît dans le `Workspace`.
3. Renomme-le (ex. `AnimRig`). Ne le mets pas dans un dossier synchronisé par Rojo.

## 2. Créer une animation
1. Onglet **Avatar** → **Animation Editor**, puis clique sur le mannequin.
2. Donne un nom (voir la liste §5), puis **Create**.
3. Bouge les parties du corps (outil Rotation) et pose des **images clés** (keyframes) sur la
   timeline. Conseils pour un rendu « réaliste » :
   - **Anticipation** : le bras recule légèrement avant de frapper.
   - **Impact rapide** : le coup lui-même dure très peu (2–4 images).
   - **Retour** : revenir à la garde plus lentement.
   - Fais bouger les **hanches et le torse**, pas seulement le bras.
   - Clic droit sur une keyframe → **Easing Style** (`Cubic`, `Out`) pour des mouvements naturels.
4. Durée conseillée : coup M1 ≈ 0,3–0,4 s ; attaque spéciale ≈ 0,6–1,2 s.

## 3. Réglages importants (avant de publier)
1. Menu **⋯** de l'Animation Editor → **Set Animation Priority** → **Action**
   (pour que l'attaque passe par-dessus la marche/la course).
   Exception : `Idle`/`Block` (tenue de garde) → **Idle** ou **Movement** si je te le précise.
2. **Looping** (bouton boucle) : activé seulement pour les animations qui tournent en continu
   (garde, blocage maintenu). Désactivé pour les coups.
3. **Événement « Hit »** (très important) : c'est le moment exact où le coup touche.
   - Place le curseur de la timeline sur l'image de l'impact.
   - Menu **⋯** → **Add Animation Event** (ou clic droit dans la ligne des événements)
     → nom : **`Hit`** (exactement, avec la majuscule).
   - Pour un coup multiple (ex. Jab Rush), ajoute un `Hit` à **chaque** impact.
   Le code utilisera ce marqueur pour synchroniser l'impact (son, hitstop, effet).

## 4. Publier et récupérer l'ID
1. Menu **⋯** → **Publish to Roblox**.
2. **Owner / Creator** : ton compte perso (pas un groupe).
3. Valide, puis copie l'ID (nombre) donné à la fin — tu le retrouves aussi dans
   *Creator Hub → Creations → Development Items → Animations*.
4. Envoie-moi la liste **nom → ID**, ou remplace toi-même le `0` à côté du nom dans
   `src/shared/Animations.luau` (ex. `Block = 1234567890,`). Rojo met Studio à jour tout seul.
5. Pense aussi à **sauvegarder** l'animation dans Studio (menu ⋯ → *Save*) pour pouvoir la
   modifier plus tard. Republier une animation modifiée donne un **nouvel ID** (à me renvoyer).

## 5. Liste des animations à faire (noms exacts)
Tant qu'une animation manque, le code utilisera un ID vide et le combat marchera quand même
(sans animation) : tu peux les faire dans l'ordre que tu veux.

### Communes à tous les kits
| Nom | Boucle | Remarque |
|---|---|---|
| `Block` | oui | Garde haute, bras devant le visage |
| `BlockHit` | non | Réaction quand un coup est bloqué |
| `GuardBreak` | non | Garde brisée, titube (~1,5 s) |
| `Parry` | non | Petit mouvement de déviation |
| `Stunned` | oui | Sonné, tête qui tourne |
| `DashForward` / `DashBack` / `DashLeft` / `DashRight` | non | Esquives (~0,3 s) |
| `HitFront` / `HitBack` | non | Réactions aux coups |
| `Limp` | oui | Marche en boitant (priorité **Movement**) |
| `GetUp` | non | Se relever après un ragdoll |

### Mouvements — ✅ faits en code (rien à faire dans Studio)
Accroupi (immobile / en marchant), glissade, vault, mantle et l'inclinaison en course sont animés
**par le code** : `src/client/Animation/MovementClips.luau` (les poses) et
`src/client/Controllers/CharacterAnimationController.luau` (lecture + fondu).
Pour ajuster une pose : change les angles dans `MovementClips.luau` (explications en haut du
fichier), Rojo synchronise, *Play*.

### Street Brawler
| Nom | `Hit` |
|---|---|
| `Brawler_M1_1` à `Brawler_M1_4` | 1 chacun (M1_4 = coup lourd) |
| `Brawler_BottleSmash` | 1 |
| `Brawler_Headbutt` | 1 |
| `Brawler_Tackle` | 1 (au contact) |
| `Brawler_DirtyKick` | 1 |
| `Brawler_Ultimate` | 1 (activation du mode) |

### Boxer
| Nom | `Hit` |
|---|---|
| `Boxer_Idle` (garde de boxe, boucle, priorité **Idle**) | — |
| `Boxer_M1_1` à `Boxer_M1_4` | 1 chacun |
| `Boxer_JabRush` | un par jab |
| `Boxer_Uppercut` | 1 |
| `Boxer_Slip` / `Boxer_SlipCounter` | 1 sur le contre |
| `Boxer_LiverShot` | 1 |
| `Boxer_Ultimate` (attaquant) + `Boxer_Ultimate_Victim` (victime) | un par coup |

> Pour l'ultime du Boxer (animation à deux), place deux mannequins face à face, à **4 studs**
> l'un de l'autre, et anime-les en même temps. On ajustera la distance ensemble.
