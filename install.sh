#!/bin/bash
set -Eeuo pipefail

say() { printf '\033[38;5;%sm[NOLVIKAE INSTALL]\033[0m %s\n' "$(( ( $(date +%s) % 200 ) + 16 ))" "$*"; }
fail() { say "ERREUR: $*"; exit 1; }

apt-get update -y
apt-get install -y --no-install-recommends git curl ca-certificates xz-utils
rm -rf /var/lib/apt/lists/*

mkdir -p /mnt/server
mkdir -p /mnt/server/.nolvikae/vendor
cd /mnt/server

say "Préparation de l'installation Node.js..."
command -v git >/dev/null 2>&1 || fail "git est absent du conteneur d'installation."
command -v curl >/dev/null 2>&1 || fail "curl est absent du conteneur d'installation."

# Téléchargement des fichiers vendor depuis GitHub nolvikae/profile
VENDOR_REPO="${GIT_ADDRESS:-https://github.com/nolvikae/profile/}"
VENDOR_URL="${VENDOR_REPO}raw/${BRANCH:-main}/vendor/"

say "Téléchargement des fichiers vendor depuis ${VENDOR_URL}..."
curl -fsSL "${VENDOR_URL}entrypoint.sh" -o /mnt/server/.nolvikae/vendor/entrypoint.sh || say "entrypoint.sh non disponible (optionnel)."

# Téléchargement du Dockerfile selon la version Node.js
NODE_MAJOR="${NODE_VERSION%%.*}"
VENDOR_DOCKERFILE="${VENDOR_URL}nodejs-${NODE_MAJOR}/Dockerfile"
curl -fsSL "${VENDOR_DOCKERFILE}" -o /mnt/server/.nolvikae/vendor/Dockerfile || say "Dockerfile pour Node.js ${NODE_MAJOR} non disponible (optionnel)."
say "Fichiers vendor téléchargés."

# Téléchargement de Node.js depuis nodejs.org
NODE_VERSION="${NODE_VERSION:-20.11.1}"
NODE_ARCH="${NODE_ARCH:-x64}"
NODE_DIR="node-v${NODE_VERSION}-linux-${NODE_ARCH}"
NODE_TAR="${NODE_DIR}.tar.xz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"

say "Téléchargement de Node.js v${NODE_VERSION} depuis nodejs.org..."
curl -fsSL "${NODE_URL}" -o "/tmp/${NODE_TAR}" || fail "Impossible de télécharger Node.js depuis nodejs.org."

say "Extraction de Node.js..."
tar -xJf "/tmp/${NODE_TAR}" -C /tmp || fail "Impossible d'extraire Node.js."
rm -f "/tmp/${NODE_TAR}"

say "Installation de Node.js dans .nolvikae/vendor/..."
mv "/tmp/${NODE_DIR}" "/mnt/server/.nolvikae/vendor/nodejs"
rm -rf /tmp/${NODE_DIR}

# Export PATH pour Node.js local
export PATH="/mnt/server/.nolvikae/vendor/nodejs/bin:$PATH"
export NODE_PATH="/mnt/server/.nolvikae/vendor/nodejs/lib/node_modules"

say "Vérification de Node.js..."
/mnt/server/.nolvikae/vendor/nodejs/bin/node --version || fail "Node.js installation failed."
/mnt/server/.nolvikae/vendor/nodejs/bin/npm --version || fail "npm installation failed."

if [[ "${USER_UPLOAD:-0}" == "1" || "${USER_UPLOAD:-false}" == "true" ]]; then
  say "USER_UPLOAD activé : clonage ignoré."
else
  [[ -n "${GIT_ADDRESS:-}" ]] || fail "Renseigne GIT_ADDRESS avec l'URL du dépôt GitHub."

  REPO_URL="${GIT_ADDRESS}"
  [[ "$REPO_URL" == *.git ]] || REPO_URL="${REPO_URL%.git}.git"

  # Authentification facultative pour les dépôts privés. Ne jamais afficher le token.
  if [[ -n "${ACCESS_TOKEN:-}" ]]; then
    if [[ "$REPO_URL" =~ ^https://github\.com/ ]]; then
      REPO_PATH="${REPO_URL#https://github.com/}"
      REPO_URL="https://x-access-token:${ACCESS_TOKEN}@github.com/${REPO_PATH}"
    elif [[ -n "${USERNAME:-}" ]]; then
      HOST_PATH="${REPO_URL#https://}"
      REPO_URL="https://${USERNAME}:${ACCESS_TOKEN}@${HOST_PATH}"
    fi
  fi

  if [[ -d .git ]]; then
    say "Dépôt Git existant détecté."
    git remote set-url origin "$REPO_URL" 2>/dev/null || true
    if [[ "${CLEAN_INSTALL:-0}" == "1" ]]; then
      say "Nettoyage des fichiers suivis avant mise à jour..."
      git reset --hard
    fi
    git fetch --all --prune
    if [[ -n "${BRANCH:-}" ]]; then
      git checkout -B "$BRANCH" "origin/$BRANCH" 2>/dev/null || git checkout "$BRANCH"
      git pull --ff-only origin "$BRANCH" || fail "Impossible de mettre à jour la branche $BRANCH."
    else
      git pull --ff-only || fail "Impossible de mettre à jour le dépôt."
    fi
  else
    # Refuse d'écraser des fichiers préexistants hors .git.
    if find . -mindepth 1 -maxdepth 1 ! -name '.nolvikae' -print -quit | grep -q .; then
      fail "Le dossier contient déjà des fichiers sans dépôt Git. Vide-le ou active CLEAN_INSTALL après avoir sauvegardé tes données."
    fi
    if [[ -n "${BRANCH:-}" ]]; then
      git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO_URL" /tmp/nolvikae-repo || fail "Clonage GitHub impossible (URL, branche, droits ou réseau)."
    else
      git clone --depth 1 "$REPO_URL" /tmp/nolvikae-repo || fail "Clonage GitHub impossible (URL, droits ou réseau)."
    fi
    cp -a /tmp/nolvikae-repo/. /mnt/server/
    rm -rf /tmp/nolvikae-repo
  fi
fi

# Création du logger avec 50 couleurs
cat > /mnt/server/.nolvikae/logger.cjs <<'LOGGER'
'use strict';
const { spawn } = require('node:child_process');
const path = require('node:path');

const main = (process.env.MAIN_FILE || 'index.js').trim();
const args = (process.env.NODE_ARGS || '').match(/(?:[^\s"]+|"[^"]*")+/g) || [];
const cleanArgs = args.map(v => v.replace(/^"|"$/g, ''));
const useColors = !['0', 'false', 'off', 'no'].includes(String(process.env.COLOR_LOGS || '1').toLowerCase());

// 50 couleurs RGB distinctes. La couleur change à chaque ligne complète affichée.
const palette = Array.from({ length: 50 }, (_, i) => {
  const h = (i * 137.508) % 360;
  const s = 78, l = 62;
  const c = (1 - Math.abs(2 * l / 100 - 1)) * s / 100;
  const x = c * (1 - Math.abs((h / 60) % 2 - 1));
  const m = l / 100 - c / 2;
  let r = 0, g = 0, b = 0;
  if (h < 60) [r,g,b] = [c,x,0];
  else if (h < 120) [r,g,b] = [x,c,0];
  else if (h < 180) [r,g,b] = [0,c,x];
  else if (h < 240) [r,g,b] = [0,x,c];
  else if (h < 300) [r,g,b] = [x,0,c];
  else [r,g,b] = [c,0,x];
  return `\x1b[38;2;${Math.round((r+m)*255)};${Math.round((g+m)*255)};${Math.round((b+m)*255)}m`;
});
let lineNumber = 0;
function pipeLines(stream, target) {
  let pending = '';
  stream.setEncoding('utf8');
  stream.on('data', chunk => {
    pending += chunk;
    const lines = pending.split(/\r?\n/);
    pending = lines.pop();
    for (const line of lines) emit(line, target);
  });
  stream.on('end', () => { if (pending.length) emit(pending, target); });
}
function emit(line, target) {
  const color = palette[lineNumber++ % palette.length];
  target.write((useColors ? color : '') + line + (useColors ? '\x1b[0m' : '') + '\n');
}
const entry = path.resolve(process.cwd(), main);
if (!require('node:fs').existsSync(entry)) {
  console.error(`[NOLVIKAE] Fichier de démarrage introuvable : ${main}`);
  process.exit(1);
}
console.log(`[NOLVIKAE] Démarrage de ${main} — palette de 50 couleurs ${useColors ? 'activée' : 'désactivée'}.`);
const child = spawn('/mnt/server/.nolvikae/vendor/nodejs/bin/node', [entry, ...cleanArgs], {
  cwd: process.cwd(),
  env: { ...process.env, PATH: '/mnt/server/.nolvikae/vendor/nodejs/bin:' + process.env.PATH },
  stdio: ['inherit', 'pipe', 'pipe']
});
pipeLines(child.stdout, process.stdout);
pipeLines(child.stderr, process.stderr);
child.on('error', err => { console.error('[NOLVIKAE] Impossible de lancer Node.js:', err.message); process.exitCode = 1; });
child.on('exit', (code, signal) => {
  if (signal) console.log(`[NOLVIKAE] Processus arrêté par ${signal}.`);
  process.exitCode = code === null ? 1 : code;
});
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => child.kill(sig));
LOGGER

# Création du script de démarrage
cat > /mnt/server/.nolvikae/start.sh <<'START'
#!/bin/bash
set -Eeuo pipefail
cd /home/container

# Ajout de Node.js local au PATH
export PATH="/home/container/.nolvikae/vendor/nodejs/bin:$PATH"
export NODE_PATH="/home/container/.nolvikae/vendor/nodejs/lib/node_modules"

if [[ "${AUTO_UPDATE:-0}" == "1" && -d .git ]]; then
  echo "[NOLVIKAE] Mise à jour Git activée."
  git pull --ff-only || { echo "[NOLVIKAE] Échec de git pull."; exit 1; }
fi

if [[ "${INSTALL_ON_START:-0}" == "1" && -f package.json ]]; then
  echo "[NOLVIKAE] Installation/vérification des dépendances npm..."
  if [[ -f package-lock.json ]]; then /home/container/.nolvikae/vendor/nodejs/bin/npm ci --omit=dev || /home/container/.nolvikae/vendor/nodejs/bin/npm install --omit=dev
  else /home/container/.nolvikae/vendor/nodejs/bin/npm install --omit=dev
  fi
fi

if [[ -n "${NODE_PACKAGES:-}" ]]; then
  read -r -a packages <<< "$NODE_PACKAGES"
  if (( ${#packages[@]} )); then /home/container/.nolvikae/vendor/nodejs/bin/npm install --no-save "${packages[@]}"; fi
fi

exec /home/container/.nolvikae/vendor/nodejs/bin/node /home/container/.nolvikae/logger.cjs
START
chmod +x /mnt/server/.nolvikae/start.sh

# Installation des dépendances npm avec Node.js local
if [[ -f package.json ]]; then
  say "package.json trouvé."
  if [[ "${INSTALL_DEV_DEPENDENCIES:-0}" == "1" ]]; then
    /mnt/server/.nolvikae/vendor/nodejs/bin/npm install || fail "npm install a échoué."
  elif [[ -f package-lock.json ]]; then
    /mnt/server/.nolvikae/vendor/nodejs/bin/npm ci --omit=dev || /mnt/server/.nolvikae/vendor/nodejs/bin/npm install --omit=dev || fail "Installation des dépendances npm impossible."
  else
    /mnt/server/.nolvikae/vendor/nodejs/bin/npm install --omit=dev || fail "Installation des dépendances npm impossible."
  fi
else
  say "Aucun package.json détecté : dépôt cloné, aucune dépendance npm à installer."
fi

if [[ -n "${NODE_PACKAGES:-}" ]]; then
  read -r -a packages <<< "$NODE_PACKAGES"
  if (( ${#packages[@]} )); then /mnt/server/.nolvikae/vendor/nodejs/bin/npm install --no-save "${packages[@]}" || fail "Installation des paquets supplémentaires impossible."; fi
fi

say "Installation terminée."
