#!/usr/bin/env python3
"""Génère les Dockerfiles vendor et l'egg JSON depuis install.sh."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent
VERSIONS = [12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
PANEL_IMAGES = [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 14, 12]

DOCKERFILE = """\
#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

FROM        --platform=$TARGETOS/$TARGETARCH node:{version}-alpine

LABEL       author="Matthew Penner" maintainer="matthew@pterodactyl.io"

LABEL       org.opencontainers.image.source="https://github.com/nolvikae/profile"
LABEL       org.opencontainers.image.licenses=MIT

RUN         apk add --update --no-cache ca-certificates curl ffmpeg git openssl sqlite tar tzdata \\
	&& adduser -D -h /home/container container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/ash", "/entrypoint.sh" ]
"""


def write_dockerfiles() -> None:
    src_entry = ROOT / "vendor" / "entrypoint.sh"
    for version in VERSIONS:
        folder = ROOT / "vendor" / f"nodejs-{version}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "Dockerfile").write_text(
            DOCKERFILE.format(version=version), encoding="utf-8"
        )
        shutil.copyfile(src_entry, folder / "entrypoint.sh")


def egg_payload(install_script: str) -> dict:
    docker_images = {
        f"Nodejs {version}": f"ghcr.io/ptero-eggs/yolks:nodejs_{version}"
        for version in PANEL_IMAGES
    }
    return {
        "_comment": "Egg Nolvikae Node.js — clone GitHub, images yolks sélectionnables, logs 50 couleurs.",
        "meta": {"version": "PTDL_v2", "update_url": None},
        "exported_at": "2026-10-15T00:00:00+02:00",
        "name": "Nolvikae Node.js — Custom GitHub + 50 Colors",
        "author": "Nolvikae Studio",
        "description": "Egg Node.js basé sur l'egg générique : tu choisis l'image Docker (Node 12 à 25), clones un dépôt GitHub, installes npm, et colores chaque ligne de log avec 50 couleurs RGB.",
        "features": None,
        "docker_images": docker_images,
        "file_denylist": [],
        "startup": "sh /home/container/.nolvikae/start.sh",
        "config": {
            "files": "{}",
            "startup": json.dumps(
                {"done": ["[NOLVIKAE] Démarrage de"]}, ensure_ascii=False
            ),
            "logs": "{}",
            "stop": "^C",
        },
        "scripts": {
            "installation": {
                "script": install_script,
                "container": "node:20-trixie-slim",
                "entrypoint": "bash",
            }
        },
        "variables": [
            {
                "name": "Git Repo Address",
                "description": "Dépôt GitHub de l'application à cloner.\n\nEx: https://github.com/user/mon-bot",
                "env_variable": "GIT_ADDRESS",
                "default_value": "",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string",
                "field_type": "text",
            },
            {
                "name": "Install Branch",
                "description": "The branch to install.",
                "env_variable": "BRANCH",
                "default_value": "main",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string",
                "field_type": "text",
            },
            {
                "name": "User Uploaded Files",
                "description": "Skip git clone if you are letting a user upload files.\n\n0 = false (default)\n1 = true",
                "env_variable": "USER_UPLOAD",
                "default_value": "0",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
            {
                "name": "Auto Update",
                "description": "Pull the latest files on startup when using a GitHub repo.",
                "env_variable": "AUTO_UPDATE",
                "default_value": "0",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
            {
                "name": "Main file",
                "description": "The file that starts the app.\nCan be .js and .ts",
                "env_variable": "MAIN_FILE",
                "default_value": "index.js",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|string|max:255",
                "field_type": "text",
            },
            {
                "name": "Additional Arguments.",
                "description": "Any extra arguments for nodejs or ts-node",
                "env_variable": "NODE_ARGS",
                "default_value": "",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string|max:512",
                "field_type": "text",
            },
            {
                "name": "Additional Node packages",
                "description": "Install additional node packages.\n\nUse spaces to separate.",
                "env_variable": "NODE_PACKAGES",
                "default_value": "",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string|max:512",
                "field_type": "text",
            },
            {
                "name": "Uninstall Node packages",
                "description": "Uninstall node packages.\n\nUse spaces to separate.",
                "env_variable": "UNNODE_PACKAGES",
                "default_value": "",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string|max:512",
                "field_type": "text",
            },
            {
                "name": "Git Username",
                "description": "Username to auth with git.",
                "env_variable": "USERNAME",
                "default_value": "",
                "user_viewable": True,
                "user_editable": True,
                "rules": "nullable|string",
                "field_type": "text",
            },
            {
                "name": "Git Access Token",
                "description": "Password to use with git.\n\nIt's best practice to use a Personal Access Token.\nhttps://github.com/settings/tokens",
                "env_variable": "ACCESS_TOKEN",
                "default_value": "",
                "user_viewable": False,
                "user_editable": True,
                "rules": "nullable|string",
                "field_type": "text",
            },
            {
                "name": "Installer les dépendances au démarrage",
                "description": "1 = réinstalle/vérifie les dépendances à chaque démarrage (démarrage plus lent).",
                "env_variable": "INSTALL_ON_START",
                "default_value": "0",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
            {
                "name": "Inclure les dépendances de développement",
                "description": "1 = installe aussi devDependencies pendant l'installation.",
                "env_variable": "INSTALL_DEV_DEPENDENCIES",
                "default_value": "0",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
            {
                "name": "Couleurs de logs (50 couleurs)",
                "description": "1 = activer la palette de 50 couleurs ; 0 = désactiver les couleurs.",
                "env_variable": "COLOR_LOGS",
                "default_value": "1",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
            {
                "name": "Nettoyer les fichiers suivis Git",
                "description": "1 = git reset --hard lors d'une réinstallation sur un dépôt déjà cloné.",
                "env_variable": "CLEAN_INSTALL",
                "default_value": "0",
                "user_viewable": True,
                "user_editable": True,
                "rules": "required|boolean",
                "field_type": "text",
            },
        ],
    }


def write_eggs() -> None:
    install = (ROOT / "install.sh").read_text(encoding="utf-8")
    if not install.endswith("\n"):
        install += "\n"
    payload = egg_payload(install)
    text = json.dumps(payload, indent=4, ensure_ascii=False) + "\n"
    (ROOT / "egg-nolvikae-custom.json").write_text(text, encoding="utf-8")
    (WORKSPACE / "egg-nolvikae-custom.json").write_text(text, encoding="utf-8")


def main() -> None:
    write_dockerfiles()
    write_eggs()
    print("Dockerfiles:", ", ".join(str(v) for v in VERSIONS))
    print("Egg JSON written to github/ and workspace root.")


if __name__ == "__main__":
    main()
