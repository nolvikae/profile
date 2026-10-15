#requires -Version 5.1

# ============================================================
#                 NIGHTCORD GITHUB UPLOADER
# ============================================================
#
# Local :
# C:\Users\Utilisateur\Documents\eggpteronolvikae\github
#
# GitHub :
# git@github.com:nolvikae/profile.git
#
# Authentification :
# Clé SSH utilisateur (id_ed25519)
#
# Branche :
# main
#
# ============================================================

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$LOCAL_FOLDER = "C:\Users\Utilisateur\Documents\eggpteronolvikae\github"

$SSH_KEY = "$env:USERPROFILE\.ssh\id_ed25519"

# Clé publique correspondante (celle à coller dans les réglages GitHub).
$SSH_KEY_PUB = "$env:USERPROFILE\.ssh\id_ed25519.pub"

$GITHUB_REPO = "git@github.com:nolvikae/profile.git"

$BRANCH = "main"

$GIT_USERNAME = "nolvikae"

# ============================================================
# IMPORTANT :
# Remplace cette adresse par ton adresse GitHub.
#
# Exemple :
# $GIT_EMAIL = "nolvikae@gmail.com"
# ============================================================

$GIT_EMAIL = "nolvikae@gmail.com"

# Message conforme aux conventions Git (anglais, format conventionnel).
$COMMIT_MESSAGE = "chore(repo): sync egg files"

# ============================================================
# ENCODAGE UTF-8
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# FONCTIONS
# ============================================================

function Write-Info {
    param([string]$Text)

    Write-Host "[i] $Text" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Text)

    Write-Host "[+] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)

    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Text)

    Write-Host "[X] $Text" -ForegroundColor Red
}

function Set-Progress {
    param(
        [int]$Percent,
        [string]$Status
    )

    Write-Progress `
        -Activity "NIGHTCORD → GitHub" `
        -Status $Status `
        -PercentComplete $Percent
}

function Stop-Script {
    Write-Host ""
    Write-Progress `
        -Activity "NIGHTCORD → GitHub" `
        -Completed

    Write-Host ""
    Write-Host "Appuie sur Entrée pour fermer..." -ForegroundColor Yellow
    Read-Host

    exit 1
}

# ============================================================
# HEADER
# ============================================================

Clear-Host

Write-Host ""
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "                 NIGHTCORD UPLOADER" -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host ""

Write-Host " Local   : $LOCAL_FOLDER"
Write-Host " GitHub  : $GITHUB_REPO"
Write-Host " Branche : $BRANCH"
Write-Host ""

# ============================================================
# VERIFICATION GIT
# ============================================================

Set-Progress 5 "Vérification de Git..."

if (!(Get-Command git -ErrorAction SilentlyContinue)) {

    Write-ErrorMsg "Git n'est pas installé."

    Write-Host ""
    Write-Host "Installe Git puis relance le programme." -ForegroundColor Yellow

    Stop-Script
}

Write-OK "Git détecté."

# ============================================================
# VERIFICATION DOSSIER
# ============================================================

Set-Progress 10 "Vérification du dossier..."

if (!(Test-Path -LiteralPath $LOCAL_FOLDER)) {

    Write-ErrorMsg "Le dossier n'existe pas :"
    Write-Host $LOCAL_FOLDER

    Stop-Script
}

Write-OK "Dossier local trouvé."

# ============================================================
# VERIFICATION CLE SSH
# ============================================================

Set-Progress 15 "Vérification de la clé SSH..."

if (!(Test-Path -LiteralPath $SSH_KEY)) {

    Write-ErrorMsg "Clé SSH introuvable :"
    Write-Host $SSH_KEY

    Write-Host ""
    Write-Host "Crée-la avec :" -ForegroundColor Yellow
    Write-Host ""
    Write-Host 'ssh-keygen -t ed25519 -C "nolvikae@gmail.com" -f "%USERPROFILE%\.ssh\id_ed25519"' -ForegroundColor Cyan

    Stop-Script
}

Write-OK "Clé SSH trouvée."

# La clé privée suffit pour pousser. La clé publique sert uniquement
# à être enregistrée dans les réglages SSH de GitHub : son absence est
# donc signalée mais ne bloque pas la synchronisation.
if (Test-Path -LiteralPath $SSH_KEY_PUB) {

    Write-Info "Clé publique : $SSH_KEY_PUB"

}
else {

    Write-Warn "Clé publique introuvable : $SSH_KEY_PUB"

    Write-Host ""
    Write-Host "Récupère-la avec :" -ForegroundColor Yellow
    Write-Host "ssh-keygen -y -f `"$SSH_KEY`" > `"$SSH_KEY_PUB`"" -ForegroundColor Cyan

}

# ============================================================
# CONFIGURATION SSH
# ============================================================

Set-Progress 20 "Configuration de SSH..."

# BatchMode évite toute invite interactive (le script ne doit jamais
# rester bloqué sur une confirmation) et ConnectTimeout empêche le
# blocage indéfini si le réseau ou le VPN est coupé.
$env:GIT_SSH_COMMAND = "ssh -i `"$SSH_KEY`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=15"

Write-OK "Authentification SSH configurée."

# ============================================================
# ACCES AU DOSSIER
# ============================================================

Set-Location -LiteralPath $LOCAL_FOLDER

# ============================================================
# CONFIGURATION IDENTITE GIT
# ============================================================

Set-Progress 25 "Configuration de l'identité Git..."

if ($GIT_EMAIL -eq "TON_EMAIL_GITHUB") {

    Write-ErrorMsg "Tu n'as pas configuré ton adresse e-mail Git."

    Write-Host ""
    Write-Host 'Modifie cette ligne dans le script :' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '$GIT_EMAIL = "TON_EMAIL_GITHUB"' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Par exemple :' -ForegroundColor Yellow
    Write-Host '$GIT_EMAIL = "123456789+nolvikae@users.noreply.github.com"' -ForegroundColor Cyan

    Stop-Script
}

git config user.name $GIT_USERNAME

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Impossible de configurer le nom Git."
    Stop-Script
}

git config user.email $GIT_EMAIL

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Impossible de configurer l'adresse Git."
    Stop-Script
}

# Gestion des fins de ligne Windows
git config core.autocrlf true

Write-OK "Identité Git configurée."

# ============================================================
# INITIALISATION GIT
# ============================================================

Set-Progress 30 "Vérification du dépôt Git..."

if (!(Test-Path -LiteralPath ".git")) {

    Write-Info "Dépôt Git inexistant."
    Write-Info "Initialisation..."

    git init

    if ($LASTEXITCODE -ne 0) {

        Write-ErrorMsg "git init a échoué."

        Stop-Script
    }

    Write-OK "Dépôt Git initialisé."

}
else {

    Write-OK "Dépôt Git déjà initialisé."
}

# ============================================================
# FORCE LA BRANCHE MAIN
# ============================================================

Set-Progress 35 "Configuration de la branche $BRANCH..."

git branch -M $BRANCH

if ($LASTEXITCODE -ne 0) {

    Write-ErrorMsg "Impossible de définir la branche $BRANCH."

    Stop-Script
}

Write-OK "Branche locale : $BRANCH"

# ============================================================
# CONFIGURATION DU REMOTE
# ============================================================

Set-Progress 40 "Configuration du repository GitHub..."

$remoteUrl = ""

try {

    $remoteUrl = git remote get-url origin 2>$null

}
catch {

    $remoteUrl = ""
}

if ($remoteUrl) {

    Write-Info "Remote actuel : $remoteUrl"

    git remote set-url origin $GITHUB_REPO

    if ($LASTEXITCODE -ne 0) {

        Write-ErrorMsg "Impossible de modifier le remote."

        Stop-Script
    }

    Write-OK "Remote GitHub configuré."

}
else {

    git remote add origin $GITHUB_REPO

    if ($LASTEXITCODE -ne 0) {

        Write-ErrorMsg "Impossible d'ajouter le remote GitHub."

        Stop-Script
    }

    Write-OK "Remote GitHub ajouté."
}

# ============================================================
# TEST SSH
# ============================================================

Set-Progress 45 "Test de connexion à GitHub..."

Write-Host ""

# Le test utilise exactement les mêmes options SSH que le push,
# sinon il peut valider une configuration que le push n'utilisera pas.
$sshTest = & cmd.exe /c "ssh -i `"$SSH_KEY`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=15 -T git@github.com 2>&1" | Out-String

if ($sshTest -match "successfully authenticated") {

    Write-OK "Connexion GitHub réussie."

}
else {

    Write-ErrorMsg "La connexion SSH a échoué."

    Write-Host ""
    Write-Host $sshTest

    Write-Host ""
    Write-Warn "Vérifie ta clé SSH sur GitHub (Settings > SSH and GPG keys)."

    Stop-Script
}

# ============================================================
# ANALYSE DES FICHIERS
# ============================================================

Set-Progress 50 "Analyse des fichiers..."

$files = @(
    Get-ChildItem `
        -LiteralPath $LOCAL_FOLDER `
        -Recurse `
        -File `
        -Force `
        -ErrorAction SilentlyContinue
)

$totalFiles = $files.Count

Write-OK "$totalFiles fichier(s) trouvé(s)."

# ============================================================
# GIT STATUS AVANT ADD
# ============================================================

Set-Progress 55 "Analyse des modifications..."

Write-Info "Préparation des fichiers..."

# ============================================================
# GIT ADD
# ============================================================

Set-Progress 60 "Ajout des fichiers à Git..."

git add -A

if ($LASTEXITCODE -ne 0) {

    Write-ErrorMsg "git add a échoué."

    Stop-Script
}

Write-OK "Fichiers ajoutés."

# ============================================================
# VERIFICATION DES MODIFICATIONS
# ============================================================

Set-Progress 65 "Vérification des modifications..."

$status = git status --porcelain

# ============================================================
# BUG CORRIGÉ : l'ancien script sortait ici avec "exit 0" dès que
# l'arbre de travail était propre, SANS jamais pousser. Sur un dépôt
# GitHub vide, cela affichait "Repository déjà à jour" alors que rien
# n'avait jamais été envoyé.
#
# On ne considère maintenant le dépôt à jour que si la branche
# distante existe ET pointe exactement sur le commit local.
# ============================================================

# $ErrorActionPreference vaut "Stop" dans ce script : sans cette
# isolation, une commande git légitement en échec (branche distante
# absente) lèverait une erreur terminante et tuerait le script.
# On restaure donc la préférence le temps du test.
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"

$localCommit = (git rev-parse HEAD 2>$null | Out-String).Trim()

$remoteRef = (git ls-remote "refs/heads/$BRANCH" origin 2>$null | Out-String).Trim()

$ErrorActionPreference = $previousErrorAction

$isRemoteUpToDate = $false

if ($localCommit -and $remoteRef -match "^([0-9a-f]{40})") {

    $isRemoteUpToDate = ($Matches[1] -eq $localCommit)

}

if ($isRemoteUpToDate) {

    Set-Progress 100 "Repository déjà à jour."

    Write-Host ""
    Write-OK "Aucune modification à envoyer."
    Write-Host ""
    Write-Host "Le repository GitHub est déjà à jour." -ForegroundColor Cyan
    Write-Host ""

    Write-Progress `
        -Activity "NIGHTCORD → GitHub" `
        -Completed

    Write-Host ""
    Write-Host "Appuie sur Entrée pour fermer..." -ForegroundColor Yellow

    Read-Host

    exit 0

}

if ([string]::IsNullOrWhiteSpace($status)) {

    Write-Info "Arbre de travail propre, mais le distant n'est pas à jour."
    Write-Info "Poussée des commits existants en cours..."

}
else {

    Write-Info "Modifications à committer détectées."

}

# ============================================================
# AFFICHAGE DES MODIFICATIONS
# ============================================================

if (-not [string]::IsNullOrWhiteSpace($status)) {

    Write-Host ""
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " MODIFICATIONS DÉTECTÉES" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

    git status --short

    Write-Host ""
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # ============================================================
    # COMMIT
    # ============================================================

    Set-Progress 75 "Création du commit..."

    git commit -m $COMMIT_MESSAGE

    if ($LASTEXITCODE -ne 0) {

        Write-ErrorMsg "Impossible de créer le commit."

        Stop-Script

    }

    Write-OK "Commit créé."

}
else {

    Write-Info "Rien à committer, les commits existants seront poussés."

}

# ============================================================
# VERIFICATION BRANCHE
# ============================================================

Set-Progress 80 "Vérification de la branche..."

git branch -M $BRANCH

if ($LASTEXITCODE -ne 0) {

    Write-ErrorMsg "Impossible de définir la branche $BRANCH."

    Stop-Script
}

Write-OK "Branche prête : $BRANCH"

# ============================================================
# VERIFICATION DU COMMIT
# ============================================================

$currentCommit = git rev-parse --verify HEAD 2>$null

if (!$currentCommit) {

    Write-ErrorMsg "Aucun commit trouvé."

    Stop-Script
}

Write-OK "Commit local : $currentCommit"

# ============================================================
# PUSH
# ============================================================

Set-Progress 88 "Mise à jour de l'historique distant..."

Write-Host ""
Write-Info "Récupération de l'état distant..."

# --force-with-lease compare le commit local à la ref de suivi
# locale (refs/remotes/origin/<branche>). Sans ce fetch, cette ref
# n'existe pas encore car le remote vient de changer d'URL : git
# rejetterait la poussée avec "stale info". Le fetch garantit aussi
# que la comparaison porte bien sur l'état réel du dépôt distant.
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"

git fetch origin

if ($LASTEXITCODE -ne 0) {

    Write-Warn "Fetch impossible, poursuite avec l'état local connu."

}

$ErrorActionPreference = $previousErrorAction

Set-Progress 90 "Upload vers GitHub..."

Write-Host ""
Write-Host "Upload en cours..." -ForegroundColor Yellow
Write-Host ""

# Poussée forcée : l'historique distant (nolvikae/profile) n'a aucun
# ancêtre commun avec l'historique local, une poussée normale serait
# rejetée. --force-with-lease reste protégé : si le dépôt distant a
# changé depuis le fetch ci-dessus, git annule la poussée au lieu
# d'écraser des commits inconnus.
git push --force-with-lease -u origin $BRANCH

if ($LASTEXITCODE -ne 0) {

    Write-Progress `
        -Activity "NIGHTCORD → GitHub" `
        -Completed

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host "                    PUSH ÉCHOUÉ" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "Le commit local existe toujours." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Repository :" -ForegroundColor Cyan
    Write-Host $GITHUB_REPO
    Write-Host ""
    Write-Host "Branche :" -ForegroundColor Cyan
    Write-Host $BRANCH

    Write-Host ""
    Write-Host "Vérifications :" -ForegroundColor Yellow
    Write-Host " - Clé publique id_ed25519.pub ajoutée sur GitHub"
    Write-Host " - Repository nolvikae/profile"
    Write-Host " - Branche main"
    Write-Host " - Connexion SSH"
    Write-Host ""
    Write-Host "Si le message 'stale info' apparaît, le dépôt distant a" -ForegroundColor Yellow
    Write-Host "changé depuis le fetch : relance le script pour revalider."

    Stop-Script
}

# ============================================================
# FIN
# ============================================================

Set-Progress 100 "Upload terminé !"

Start-Sleep -Milliseconds 700

Write-Progress `
    -Activity "NIGHTCORD → GitHub" `
    -Completed

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "                 UPLOAD TERMINÉ !" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Repository :" -ForegroundColor Cyan
Write-Host "https://github.com/nolvikae/profile"

Write-Host ""
Write-Host "Dossier :" -ForegroundColor Cyan
Write-Host $LOCAL_FOLDER

Write-Host ""
Write-Host "Branche :" -ForegroundColor Cyan
Write-Host $BRANCH

Write-Host ""
Write-Host "Fichiers analysés :" -ForegroundColor Cyan
Write-Host $totalFiles

Write-Host ""
Write-Host "Authentification :" -ForegroundColor Cyan
Write-Host "Clé SSH utilisateur (id_ed25519)"

Write-Host ""
Write-OK "Ton profil GitHub est maintenant synchronisé."

Write-Host ""
Write-Host "Appuie sur Entrée pour fermer..." -ForegroundColor Yellow

Read-Host
