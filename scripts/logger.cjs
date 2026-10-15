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

const nodeBin =
  process.env.NOLVIKAE_NODE ||
  '/home/container/.nolvikae/vendor/nodejs/bin/node';
const isJs = /\.(js|cjs|mjs)$/i.test(main);
const bin = isJs ? nodeBin : 'ts-node';
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
