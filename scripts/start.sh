#!/bin/sh
set -eu
cd /home/container

NODE_BIN="/home/container/.nolvikae/vendor/nodejs/bin/node"
NPM_BIN="/home/container/.nolvikae/vendor/nodejs/bin/npm"
export PATH="/home/container/.nolvikae/vendor/nodejs/bin:$PATH"
export NODE_PATH="/home/container/.nolvikae/vendor/nodejs/lib/node_modules"

if [ ! -x "$NODE_BIN" ]; then
  echo "[NOLVIKAE] Node.js introuvable. Téléchargement depuis nodejs.org..."
  if [ -z "${NODEJS_MAJOR:-}" ]; then
    NODEJS_MAJOR="22"
  fi
  say "Installation de Node.js ${NODEJS_MAJOR} depuis nodejs.org..."
  NODE_TAR="node-v${NODEJS_MAJOR}.x-linux-x64.tar.xz"
  curl -fsSL "https://nodejs.org/dist/latest-v${NODEJS_MAJOR}.x/node-${NODE_TAR}" -o /tmp/node.tar.xz || fail "Téléchargement nodejs.org impossible."
  mkdir -p /home/container/.nolvikae/vendor/nodejs
  tar -xJf /tmp/node.tar.xz -C /home/container/.nolvikae/vendor/nodejs --strip-components=1 || fail "Extraction nodejs.org impossible."
  rm -f /tmp/node.tar.xz
  NODE_BIN="/home/container/.nolvikae/vendor/nodejs/bin/node"
  NPM_BIN="/home/container/.nolvikae/vendor/nodejs/bin/npm"
  export PATH="/home/container/.nolvikae/vendor/nodejs/bin:$PATH"
  export NODE_PATH="/home/container/.nolvikae/vendor/nodejs/lib/node_modules"
fi

if [ "${AUTO_UPDATE:-0}" = "1" ] && [ -d .git ]; then
  echo "[NOLVIKAE] Mise à jour Git activée (GitHub Nolvikae)."
  git pull --ff-only || {
    echo "[NOLVIKAE] Échec de git pull."
    exit 1
  }
fi

if [ "${INSTALL_ON_START:-0}" = "1" ] && [ -f package.json ]; then
  echo "[NOLVIKAE] Installation/vérification des dépendances npm..."
  if [ -f package-lock.json ]; then
    "$NPM_BIN" ci --omit=dev || "$NPM_BIN" install --omit=dev || "$NPM_BIN" install --production
  else
    "$NPM_BIN" install --omit=dev || "$NPM_BIN" install --production
  fi
fi

if [ -n "${NODE_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  "$NPM_BIN" install ${NODE_PACKAGES}
fi

if [ -n "${UNNODE_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  "$NPM_BIN" uninstall ${UNNODE_PACKAGES}
fi

export NOLVIKAE_NODE="$NODE_BIN"
exec "$NODE_BIN" /home/container/.nolvikae/logger.cjs
