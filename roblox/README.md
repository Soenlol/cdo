# Piste Poussière — version Roblox

Jeu de rallye contre la montre pour Roblox. Tracés, voitures et noms originaux.

## Ouvrir le jeu

1. Télécharger `build/PistePoussiere.rbxlx`.
2. Roblox Studio → **Fichier → Ouvrir depuis un fichier** → choisir le `.rbxlx`.
3. **Jouer** (F5). Au premier lancement, le serveur construit les 7 étapes en arrière-plan (barre « construction » en haut de l'écran). Le parc d'assistance est utilisable tout de suite.
4. Pour publier : **Fichier → Publier sur Roblox**. On peut aussi enregistrer en `.rbxl` avec **Fichier → Enregistrer sous**.

Pour tester la sauvegarde (crédits, records, classement mondial) dans Studio : **Paramètres du jeu → Sécurité → Enable Studio Access to API Services**.

Pour les passes de jeu, remplir les IDs dans `ReplicatedStorage/Rallye/Config` : `VIP_GAMEPASS_ID` (EXP et crédits doublés) et `COMETE_GAMEPASS_ID` (voiture Comète Bi). Avec 0, le pass est désactivé et la Comète s'achète en crédits.

## Contenu

- **Modes** : Conduire, Conduite partagée (monter comme copilote à côté d'un autre joueur et lui annoncer les virages avec les touches 1 à 4), Déplacement libre dans le parc, Défi tête-à-tête entre joueurs (invitation Accepter / Refuser).
- **7 étapes** : Lande aux Pins, Col des Marmottes, Route des Érables, Gorges Rouges, Corniche Azur, Lac Miroir, et l'événement Raid des Dunes (jetons de raid → gants). On y trouve des gués, des crêtes à sauter, des ponts (dont un couvert), un tunnel, une arche, des congères, un lac gelé, une plage, des villages et un phare.
- **Surfaces** lues sous chaque roue : asphalte, pavés, gravier, terre rouge, boue, neige tassée, glace, sable, bois, herbe, neige profonde.
- **12 voitures** en classes D à S (traction, propulsion, 4x4, turbo à retard, biturbo, hybride avec boost, électrique, trophy truck, buggy). Chacune a des barres de stats et une maîtrise M1 à M10.
- **Physique** : suspension par rayons, pneus qui saturent, cercle d'adhérence, transfert de charge et frein à main. Boîte auto avec rétrogradage au freinage, ou boîte manuelle. Marche arrière automatique en maintenant S. Les réglages de départ ont été calés sur les mesures de la fiche de référence.
- **Course** :
  - compte à rebours avec feux ; le chrono démarre à l'arche ;
  - points de passage avec écart sur ton record ;
  - pénalités de coupe de virage (+1,5 s / +2,5 s) ;
  - R = dernier point de passage (+3 s), maintenir Retour arrière = recommencer ;
  - pièces à ramasser ;
  - fissures du pare-brise après les chocs, boue sur le pare-brise ;
  - fantôme de ton meilleur passage ;
  - replay avec caméras de bord de route.
- **Copilote** : flèche (rouge = serré), « Droite 4 », « Épingle gauche », « À fond », étiquettes LÉGER / DIFFICILE / DANGER, conseils en bas à gauche. Les chevrons et panneaux jaunes sont posés sur le terrain. En solo, l'avatar d'un ami est assis à la place du copilote.
- **Caméras** : poursuite, capot, cockpit avec tableau de bord (vitesse, rapport, chrono, températures, carburant, cap) et gants. Clic droit pour regarder autour.
- **Progression** : crédits, EXP et niveaux, médailles Bronze / Argent / Or / Platine, records et classement mondial par étape, contrats du jour, caisses (performance, peinture, gants), peintures, gants.

## Développer

Le code source est dans `src/`, au format Rojo (`default.project.json`). Il est aussi possible de modifier les scripts directement dans Studio.

Après une modification de `src/`, régénérer le fichier de place :

```bash
python3 build_place.py
```

| Dossier | Contenu |
|---|---|
| `src/shared` | Config (données), Physics (modèle de conduite), Track (tracés, copilote, temps de référence), Cars (modèles) |
| `src/server` | Main (courses, récompenses, défis, passagers), RallyeServer/Builder (terrain et décor), RallyeServer/Data (sauvegarde) |
| `src/client` | Drive (pilotage, caméra, chrono), Hud, Menus, Replay, Ui |
| `src/player` | Client (script principal du joueur) |
