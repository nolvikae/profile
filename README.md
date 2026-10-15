# Nolvikae Node.js Egg — Custom GitHub + 50 Colors

## Contenu
- `egg-nolvikae-custom.json` : egg PTDL_v2 importable dans Pterodactyl.
- `install.sh` : script d'installation personnalisé pour GitHub nolvikae/profile.
- `README.md` : instructions.

## Architecture
- **Node.js** : Téléchargé depuis nodejs.org et installé dans `.nolvikae/vendor/nodejs/`
- **Code applicatif** : Cloné depuis ton GitHub (https://github.com/nolvikae/profile/)
- **Logs** : Palette de 50 couleurs RGB, change à chaque ligne
- **Base Docker** : Debian Bookworm Slim (pas de yolks Pterodactyl)

## Installation
1. Dans Pterodactyl : **Admin → Nests → Import Egg**, importe le JSON.
2. Crée un serveur avec cet egg.
3. Dans Startup, configure :
   - `NODE_VERSION` : Version Node.js depuis nodejs.org (ex: 20.11.1)
   - `NODE_ARCH` : Architecture (x64 ou arm64)
   - `GIT_ADDRESS` : URL du dépôt GitHub (par défaut: https://github.com/nolvikae/profile/)
   - `BRANCH` : Branche (par défaut: main)
   - `MAIN_FILE` : Fichier principal (ex: index.js)
4. Lance l'installation/réinstallation du serveur.
5. Démarre le serveur. `.nolvikae/logger.cjs` colore chaque ligne avec 50 couleurs.

## Fichiers générés
- `.nolvikae/vendor/nodejs/` : Installation Node.js locale
- `.nolvikae/logger.cjs` : Wrapper pour colorer les logs
- `.nolvikae/start.sh` : Script de démarrage avec PATH Node.js

## Versions Node.js supportées
Toutes les versions disponibles sur nodejs.org (18.x, 20.x, 22.x, etc.)

## Dépendances
- git
- curl
- xz-utils (pour extraction .tar.xz)
