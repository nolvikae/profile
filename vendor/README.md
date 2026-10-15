# Vendor — images Node.js Pterodactyl

Fichiers sources pour construire des images Wings (utilisateur `container`, `/home/container`, entrypoint ash).

## Contenu

- `entrypoint.sh` — script d’entrée (copie aussi dans chaque dossier de version)
- `nodejs-12` … `nodejs-25` — un `Dockerfile` + `entrypoint.sh` par version

Chaque image part de `node:XX-alpine` et installe `ca-certificates curl ffmpeg git openssl sqlite tar tzdata`.

## Build

Le contexte Docker **doit** être le dossier de version (pas le parent), sinon `COPY ./entrypoint.sh` échoue.

```bash
docker build -t ghcr.io/nolvikae/profile:nodejs_20 ./nodejs-20
```

## Panel

L’egg importe les images publiques `ghcr.io/nolvikae/profile:nodejs_XX`.
Ces Dockerfiles servent si tu veux publier tes propres tags, depuis le dépôt
`nolvikae/profile` (seules GitHub et nodejs.org).
