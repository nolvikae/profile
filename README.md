# Nolvikae Node.js Egg — GitHub + 50 Colors



## Sources distantes (2 seules)

Cet egg ne récupère son contenu que de **deux** sources distantes :

1. **GitHub nolvikae** — `github.com/nolvikae/profile` (par SSH ou par `raw.githubusercontent.com/nolvikae/profile`)
   - `install.sh` clone le dépôt de l'application et récupère `logger.cjs` + `start.sh`.
   - Aucun autre dépôt GitHub n'est contacté.
2. **nodejs.org** — `nodejs.org/dist/`
   - Si le binaire Node n'est pas présent dans l'image selectée, `start.sh` le télécharge et l'installe depuis nodejs.org (variable `NODEJS_MAJOR`, par défaut `22`).

Tout le reste (npm, dépendances, démarrage) s'effectue avec les binaires déjà présents dans l'image Docker choisie (version Node = l'image, d'où `ghcr.io/nolvikae/profile:nodejs_XX`).
Egg Pterodactyl Node.js complet, calqué sur l’egg générique (`egg-node-js-generic.json`) : tu **choisis l’image Docker** (donc la version Node) dans le panel, tu clones un dépôt GitHub, npm s’installe, et les logs passent en 50 couleurs.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `egg-nolvikae-custom.json` | Egg PTDL_v2 à importer dans Pterodactyl |
| `install.sh` | Script d’installation (embarqué dans l’egg) |
| `scripts/logger.cjs` | Wrapper de logs (50 couleurs RGB) |
| `scripts/start.sh` | Démarrage POSIX (`sh`, compatible Alpine) |
| `vendor/entrypoint.sh` | Entrypoint Pterodactyl (images custom) |
| `vendor/nodejs-XX/` | Dockerfile + entrypoint pour Node 12 → 25 |
| `.github/workflows/docker.yml` | Build/push optionnel vers GHCR |

## Images Docker (sélecteur panel)

Mêmes images que l’egg générique :

- `ghcr.io/ptero-eggs/yolks:nodejs_12` … `nodejs_25` (egg générique, hors Nolvikae)
- Node 15 existe en Dockerfile local, mais n’est pas dans le sélecteur panel (l’egg générique ne l’expose pas non plus).

La version de Node = l’image choisie ; si le binaire est manquant, `start.sh`
le récupère depuis nodejs.org.

## Installation panel

1. Uploade ce dépôt sur GitHub (`nolvikae/profile`).
2. Dans Pterodactyl : **Admin → Nests → Import Egg** → `egg-nolvikae-custom.json`.
3. Crée un serveur avec cet egg.
4. Dans **Startup** :
   - **Docker Image** : Nodejs 20 (ou celle que tu veux)
   - `GIT_ADDRESS` : URL du **dépôt de l’application** (pas forcément ce repo d’egg)
   - `BRANCH` : `main` par défaut
   - `MAIN_FILE` : `index.js` (ou un `.ts`)
5. Réinstalle le serveur, puis démarre-le.

Le démarrage Wings exécute `sh /home/container/.nolvikae/start.sh`. La console doit afficher `[NOLVIKAE] Démarrage de`.

## Variables principales

Identiques à l’egg générique, plus :

- `INSTALL_ON_START` — npm à chaque start
- `INSTALL_DEV_DEPENDENCIES` — inclure les devDependencies
- `COLOR_LOGS` — palette 50 couleurs
- `CLEAN_INSTALL` — `git reset --hard` / reclonage si le dossier n’est pas vide

`GIT_ADDRESS` peut rester vide si tu uploades les fichiers à la main (`USER_UPLOAD=1`).

## Images custom (optionnel)

Les Dockerfiles `vendor/nodejs-XX` permettent de publier tes propres images :

```text
ghcr.io/nolvikae/profile:nodejs_20
```

Le workflow `.github/workflows/docker.yml` les build après push. L’egg importé utilise les **yolks officielles** pour que le sélecteur marche tout de suite, sans attendre GHCR.

Build local :

```bash
docker build -t ghcr.io/nolvikae/profile:nodejs_20 vendor/nodejs-20
```
