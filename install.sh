#!/bin/bash
# NodeJS App Installation Script (Nolvikae)
# Server Files: /mnt/server
set -euo pipefail

say() { printf '\033[38;5;%sm[NOLVIKAE INSTALL]\033[0m %s\n' "$(( ( $(date +%s) % 200 ) + 16 ))" "$*"; }
fail() { say "ERREUR: $*"; exit 1; }

apt-get update -y
apt-get install -y --no-install-recommends git curl jq file unzip make gcc g++ python3 python3-dev python3-pip libtool ca-certificates
rm -rf /var/lib/apt/lists/*

say "Mise à jour de npm..."
npm install npm@latest --location=global || say "Mise à jour npm ignorée."

mkdir -p /mnt/server
cd /mnt/server

command -v git >/dev/null 2>&1 || fail "git est absent du conteneur d'installation."
command -v npm >/dev/null 2>&1 || fail "npm est absent du conteneur d'installation."

SKIP_GIT=0
if [ "${USER_UPLOAD:-0}" = "true" ] || [ "${USER_UPLOAD:-0}" = "1" ]; then
  say "USER_UPLOAD activé : clonage ignoré."
  SKIP_GIT=1
fi

if [ "$SKIP_GIT" -eq 0 ] && [ -n "${GIT_ADDRESS:-}" ]; then
  REPO_URL="${GIT_ADDRESS}"
  case "$REPO_URL" in
    *.git) ;;
    *) REPO_URL="${REPO_URL%/}.git" ;;
  esac

  if [ -n "${USERNAME:-}" ] || [ -n "${ACCESS_TOKEN:-}" ]; then
    HOST_PATH="$(echo "$REPO_URL" | cut -d/ -f3-)"
    if [ -n "${USERNAME:-}" ]; then
      REPO_URL="https://${USERNAME}:${ACCESS_TOKEN}@${HOST_PATH}"
    else
      REPO_URL="https://x-access-token:${ACCESS_TOKEN}@${HOST_PATH}"
    fi
  else
    say "Clonage Git anonyme."
  fi

  if [ "$(ls -A /mnt/server 2>/dev/null | grep -v '^\.nolvikae$' || true)" ]; then
    say "/mnt/server n'est pas vide."
    if [ -d .git ]; then
      if [ -f .git/config ]; then
        ORIGIN="$(git config --get remote.origin.url || true)"
        git remote set-url origin "$REPO_URL" 2>/dev/null || true
        if [ "${CLEAN_INSTALL:-0}" = "1" ]; then
          say "CLEAN_INSTALL : git reset --hard"
          git reset --hard
        fi
        if [ -n "${BRANCH:-}" ]; then
          git fetch --all --prune
          git checkout -B "$BRANCH" "origin/$BRANCH" 2>/dev/null || git checkout "$BRANCH"
          git pull --ff-only origin "$BRANCH" || fail "Impossible de mettre à jour la branche $BRANCH."
        else
          git pull --ff-only || git pull || fail "Impossible de mettre à jour le dépôt."
        fi
      else
        fail "Fichiers trouvés sans config Git. Rien n'a été modifié."
      fi
    else
      if [ "${CLEAN_INSTALL:-0}" = "1" ]; then
        say "CLEAN_INSTALL sans .git : clonage dans un dossier temporaire."
      else
        fail "Le dossier contient déjà des fichiers sans dépôt Git. Active CLEAN_INSTALL après sauvegarde."
      fi
      if [ -n "${BRANCH:-}" ]; then
        git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO_URL" /tmp/nolvikae-repo || fail "Clonage GitHub impossible."
      else
        git clone --depth 1 "$REPO_URL" /tmp/nolvikae-repo || fail "Clonage GitHub impossible."
      fi
      cp -a /tmp/nolvikae-repo/. /mnt/server/
      rm -rf /tmp/nolvikae-repo
    fi
  else
    say "Clonage du dépôt dans /mnt/server..."
    if [ -z "${BRANCH:-}" ]; then
      git clone "$REPO_URL" . || fail "Clonage GitHub impossible."
    else
      git clone --single-branch --branch "$BRANCH" "$REPO_URL" . || fail "Clonage GitHub impossible."
    fi
  fi
elif [ "$SKIP_GIT" -eq 0 ]; then
  say "GIT_ADDRESS vide : aucun clonage (upload manuel ou fichiers déjà présents)."
fi

mkdir -p /mnt/server/.nolvikae
SCRIPTS_BASE="https://raw.githubusercontent.com/nolvikae/profile/${BRANCH:-main}/scripts"
say "Récupération de logger.cjs et start.sh..."
if curl -fsSL "${SCRIPTS_BASE}/logger.cjs" -o /mnt/server/.nolvikae/logger.cjs; then
  say "logger.cjs téléchargé depuis GitHub."
else
  say "logger.cjs GitHub indisponible : copie locale embarquée."
  cat > /mnt/server/.nolvikae/logger.cjs << 'LOGGER'
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const main = String(process.env.MAIN_FILE || 'index.js').trim();
const rawArgs = String(process.env.NODE_ARGS || '');
const args = rawArgs.match(/(?:[^\s"]+|"[^"]*")+/g) || [];
const cleanArgs = args.map(function (v) {
  return v.replace(/^"|"$/g, '');
});
const colorFlag = String(process.env.COLOR_LOGS || '1').toLowerCase();
const useColors = ['0', 'false', 'off', 'no'].indexOf(colorFlag) === -1;

const palette = [];
for (let i = 0; i < 50; i++) {
  const h = (i * 137.508) % 360;
  const s = 78;
  const l = 62;
  const c = (1 - Math.abs((2 * l) / 100 - 1)) * (s / 100);
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l / 100 - c / 2;
  let r = 0;
  let g = 0;
  let b = 0;
  if (h < 60) {
    r = c; g = x; b = 0;
  } else if (h < 120) {
    r = x; g = c; b = 0;
  } else if (h < 180) {
    r = 0; g = c; b = x;
  } else if (h < 240) {
    r = 0; g = x; b = c;
  } else if (h < 300) {
    r = x; g = 0; b = c;
  } else {
    r = c; g = 0; b = x;
  }
  palette.push(
    '\x1b[38;2;' +
      Math.round((r + m) * 255) +
      ';' +
      Math.round((g + m) * 255) +
      ';' +
      Math.round((b + m) * 255) +
      'm'
  );
}

let lineNumber = 0;

function pipeLines(stream, target) {
  let pending = '';
  stream.setEncoding('utf8');
  stream.on('data', function (chunk) {
    pending += chunk;
    const lines = pending.split(/\r?\n/);
    pending = lines.pop();
    for (let i = 0; i < lines.length; i++) {
      emit(lines[i], target);
    }
  });
  stream.on('end', function () {
    if (pending.length) emit(pending, target);
  });
}

function emit(line, target) {
  const color = palette[lineNumber++ % palette.length];
  target.write((useColors ? color : '') + line + (useColors ? '\x1b[0m' : '') + '\n');
}

const entry = path.resolve(process.cwd(), main);
if (!fs.existsSync(entry)) {
  console.error('[NOLVIKAE] Fichier de démarrage introuvable : ' + main);
  process.exit(1);
}

const isJs = /\.(js|cjs|mjs)$/i.test(main);
const bin = isJs ? process.execPath || 'node' : 'ts-node';
const spawnArgs = isJs ? [entry].concat(cleanArgs) : ['--esm', entry].concat(cleanArgs);

console.log(
  '[NOLVIKAE] Démarrage de ' +
    main +
    ' — palette de 50 couleurs ' +
    (useColors ? 'activée' : 'désactivée') +
    '.'
);

const child = spawn(bin, spawnArgs, {
  cwd: process.cwd(),
  env: process.env,
  stdio: ['inherit', 'pipe', 'pipe'],
});

pipeLines(child.stdout, process.stdout);
pipeLines(child.stderr, process.stderr);

child.on('error', function (err) {
  console.error('[NOLVIKAE] Impossible de lancer Node.js:', err.message);
  process.exitCode = 1;
});

child.on('exit', function (code, signal) {
  if (signal) console.log('[NOLVIKAE] Processus arrêté par ' + signal + '.');
  process.exitCode = code === null ? 1 : code;
});

['SIGINT', 'SIGTERM'].forEach(function (sig) {
  process.on(sig, function () {
    child.kill(sig);
  });
});
LOGGER
fi

if curl -fsSL "${SCRIPTS_BASE}/start.sh" -o /mnt/server/.nolvikae/start.sh; then
  say "start.sh téléchargé depuis GitHub."
else
  say "start.sh GitHub indisponible : copie locale embarquée."
  cat > /mnt/server/.nolvikae/start.sh << 'START'
#!/bin/sh
set -eu
cd /home/container

if [ "${AUTO_UPDATE:-0}" = "1" ] && [ -d .git ]; then
  echo "[NOLVIKAE] Mise à jour Git activée."
  git pull --ff-only || {
    echo "[NOLVIKAE] Échec de git pull."
    exit 1
  }
fi

if [ "${INSTALL_ON_START:-0}" = "1" ] && [ -f package.json ]; then
  echo "[NOLVIKAE] Installation/vérification des dépendances npm..."
  if [ -f package-lock.json ]; then
    /usr/local/bin/npm ci --omit=dev || /usr/local/bin/npm install --omit=dev || /usr/local/bin/npm install --production
  else
    /usr/local/bin/npm install --omit=dev || /usr/local/bin/npm install --production
  fi
fi

if [ -n "${NODE_PACKAGES:-}" ]; then
  /usr/local/bin/npm install ${NODE_PACKAGES}
fi

if [ -n "${UNNODE_PACKAGES:-}" ]; then
  /usr/local/bin/npm uninstall ${UNNODE_PACKAGES}
fi

exec /usr/local/bin/node /home/container/.nolvikae/logger.cjs
START
fi
chmod +x /mnt/server/.nolvikae/start.sh

say "Installation des paquets Node.js..."
if [ -n "${NODE_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  /usr/local/bin/npm install ${NODE_PACKAGES} || fail "Installation des paquets supplémentaires impossible."
fi

if [ -n "${UNNODE_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  /usr/local/bin/npm uninstall ${UNNODE_PACKAGES} || say "Désinstallation des paquets impossible (optionnel)."
fi

if [ -f /mnt/server/package.json ]; then
  say "package.json trouvé."
  if [ "${INSTALL_DEV_DEPENDENCIES:-0}" = "1" ]; then
    /usr/local/bin/npm install || fail "npm install a échoué."
  else
    /usr/local/bin/npm install --omit=dev || /usr/local/bin/npm install --production || fail "Installation des dépendances npm impossible."
  fi
else
  say "Aucun package.json : pas de dépendances npm à installer."
fi

say "Installation terminée."
exit 0
