# Les armes à feu : le plan

Ce document résume le plan des armes à feu. Le détail technique est en anglais dans `docs/firearms/ARCHITECTURE.md` (le plan) et `docs/firearms/RESEARCH.md` (ce qu'on a appris des jeux, d'Unreal, de Roblox et du vrai tir). **Rien n'est encore dans le jeu** : c'est le plan avant de construire.

## Ce que le système fera

- **Peu d'armes, mais très bien faites** : 5 armes, chacune complète avant de passer à la suivante.
- **Le maniement avant tout** : l'arme a un vrai poids. Une arme lourde se lève plus lentement, bouge plus quand on tourne, recule plus fort. Les deux mains restent sur l'arme, même pendant le recul et quand on bouge. Les changements de posture sont fluides (jamais de « saut », jamais de pose figée). La règle des animations reste la même : jamais plus de 20° par image, sauf les coups secs voulus (le tir, le chargeur qu'on claque, la culasse qui revient).
- **Les postures** : arme basse (au repos), arme prête (à l'épaule), visée, arme haute, course (arme en travers du corps), et l'arme qui se replie toute seule quand on est collé à un mur (on ne peut pas tirer à travers un mur avec le canon).
- **Les vraies manipulations** : on change le chargeur, on tire la culasse, on manœuvre le verrou du sniper, on charge les cartouches une par une dans le fusil à pompe, on ouvre le capot de la mitrailleuse et on pose la bande. Les pièces du modèle 3D bougent avec l'animation.
- **Les douilles sautent et restent au sol** : elles partent du bon côté pour chaque arme (vers l'avant-droite pour la kalach, vers l'arrière-droite pour le pistolet, vers le bas pour la mitrailleuse, avec les maillons de la bande à droite), rebondissent, roulent, font « tink » selon le sol (béton, bois, métal ; presque rien sur l'herbe) et restent 45 s.
- **Les chargeurs tombent au sol** quand on les change, et y restent (90 s). La poche de 200 cartouches de la mitrailleuse tombe aussi, molle.
- **Le tir est instantané pour toi**, mais le serveur vérifie tout (munitions, cadence, que ton canon voit bien la cible, que tu ne tires pas à travers un mur). Les autres joueurs voient la même chose que toi.
- **La caméra** : par-dessus l'épaule, elle se rapproche quand tu vises ; vraie lunette pour le sniper (et l'optique ×4 de la mitrailleuse) ; le recul fait monter la visée, puis elle redescend.
- **Le gore** : les balles passent par le même système de dégâts que les coups (KO, sang, blessures). Des blessures de balle dédiées viendront plus tard.
- **Ça ne casse rien** : sans arme, les kits, les coups, les finishers et les duels marchent exactement comme aujourd'hui.

## Les 5 armes (modèles originaux, sans marques ni logos)

1. **Pistolet 9 mm compact** (style polymère moderne) : 15 + 1 balles, tenu à deux mains bras tendus. Rechargement 1,6 s (2 s à vide, avec la culasse à tirer).
2. **Fusil à pompe 12 semi-auto tactique** : 7 + 1 cartouches, viseur point rouge, 8 plombs par tir. Rechargement cartouche par cartouche (0,5 s chacune), qu'on peut arrêter à tout moment.
3. **Fusil d'assaut 7.62 type kalach** (bois, chargeur courbe) : 30 + 1, coup par coup ou rafale. Chargeur qu'on bascule pour l'enlever ; à vide, on tire le levier d'armement. 2,6 s / 3,2 s.
4. **Sniper .338 à verrou** (crosse noire squelette, lunette, bipied) : 5 + 1, manœuvre du verrou après chaque tir (1 s), on peut retenir sa respiration en visant, bipied posable sur un rebord.
5. **Mitrailleuse légère 5.56 à bande** (poche de 200 cartouches, bipied, optique ×4) : 800 coups/min, très lourde, rechargement de 7 s (ouvrir le capot, changer la poche, poser la bande, claquer le capot).

## La feuille de route

1. **Maintenant : les 5 modèles 3D** (Blender, pièces nommées, pièces mobiles, douilles, chargeurs) et **les prises en main calculées** sur le perso R6 (où se placent l'arme et les bras rigides), avec des images de chaque posture pour que tu valides.
2. **Le cœur du maniement avec une seule arme, la kalach** : tir, recul, postures, visée, rechargements, douilles, chargeurs qui tombent, sons provisoires. Tu testes et tu valides la sensation.
3. Le pistolet.
4. Le fusil à pompe.
5. Le sniper (verrou, lunette, bipied).
6. La mitrailleuse (bande, poche, maillons).
7. Les blessures de balle, les exécutions, comment on trouve les armes, l'équilibrage, les sons définitifs.
8. Ton squelette Unreal (71 os) : dès que tu l'envoies, on l'étudie image par image et on adapte ses animations au R6 (les mains restent sur l'arme, c'est l'arme qui se place pour les bras rigides).

## Les questions à trancher

1. **Comment on obtient une arme ?** Proposition : des armes à ramasser dans la ville (rares, peu de munitions, lâchées quand on est KO), le sniper et la mitrailleuse seulement dans des caisses rares annoncées. Pas d'armes en duel. (Autres choix : un kit « armes », ou une arme achetée dans la boutique.)
2. **La puissance** : un coup de poing fait 5 dégâts, une balle de kalach 38. On garde des armes mortelles comme en vrai (et on les rend rares), ou on baisse leurs dégâts ?
3. **Peut-on achever quelqu'un au sol avec une arme ?** Proposition : oui, à bout portant, comme un finisher.
4. **Les touches** : clic droit viser, R recharger (et R reste « boire » quand l'arme est rangée), X sortir / ranger, V mode de tir, T bipied, Alt changer d'épaule. D'accord ?
5. **Rechargement avant d'être vide** : le vieux chargeur tombe avec les balles qui restaient dedans (perdues). On ajoute un appui long pour le garder ?
6. **Traçantes** (les balles lumineuses) : seulement pour la mitrailleuse (réaliste), ou un léger trait pour toutes ?
7. **Compteur de munitions** : un petit chiffre discret, ou rien du tout ?
8. **Se coucher au sol** n'existe pas : on l'ajoute plus tard, ou bipied seulement sur un rebord ?
9. **L'esquive (Q) et le blocage (F)** n'arrêtent pas les balles : d'accord ?
10. **Quand on est KO**, toutes les armes tombent au sol (proposé), ou les armes longues restent dans le dos ?
11. **Taille du pistolet** : la vraie taille paraît petite dans la main carrée du R6. Taille réelle ou un peu plus grand (+15 %) ?
12. **Ton modèle Unreal** : quels sont les 3 os en plus des 68 habituels, et pour quelles armes sont ses animations ?
