#!/usr/bin/env bash
# pendra-project — zet een projectmap in één keer goed in PendraStudio (GitHub) + PendraHQ (Vercel).
#
# Gebruik (in de projectmap):   pendra-project [naam] [--preview]
#   naam       repo- en Vercel-naam (standaard: huidige naam van het Vercel-project of de mapnaam)
#   --preview  maak daarna meteen een preview-deploy en toon de link
#
# Doet, en slaat over wat al klopt:
#   1. Git-repo  -> PendraStudio/<naam> (privé), huidige commits gepusht
#   2. Vercel    -> project <naam> in team pendra-hq, gelinkt, GEEN Git-koppeling
#   3. GitHub    -> variabele VERCEL_PROJECT_ID + secrets VERCEL_TOKEN/VERCEL_ORG_ID
#   4. Workflow  -> .github/workflows/deploy.yml (commit met [skip ci], raakt je andere wijzigingen niet)
#
# Eenmalig nodig: de PendraHQ Vercel-token in je Mac-sleutelhanger:
#   security add-generic-password -a pendrahq -s pendrahq-vercel-token -w
#   (plak de token als erom gevraagd wordt; hij wordt nergens anders opgeslagen)
set -euo pipefail

ORG="PendraStudio"
TEAM_SLUG="pendra-hq"
TEAM_ID="team_hpzeMXxEof0JVAjm1VgEasR5"
KEYCHAIN_SERVICE="pendrahq-vercel-token"
TEMPLATE="$(cd "$(dirname "$(readlink "$0" || echo "$0")")/.." && pwd)/template/.github/workflows/deploy.yml"

PREVIEW=0; NAME=""
for a in "$@"; do case "$a" in --preview) PREVIEW=1;; -h|--help) sed -n '2,16p' "$0"; exit 0;; *) NAME="$a";; esac; done

say()  { printf '\033[1m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }

# ---------- controles ----------
command -v gh >/dev/null || fail "gh ontbreekt"
command -v vercel >/dev/null || fail "vercel CLI ontbreekt"
gh auth status >/dev/null 2>&1 || fail "gh is niet ingelogd (gh auth login)"
WHO=$(vercel whoami 2>/dev/null | tail -1)
[ "$WHO" = "pendrahq" ] || fail "vercel is ingelogd als '$WHO', moet 'pendrahq' zijn (vercel login)"
[ -f package.json ] || [ -f index.html ] || fail "dit lijkt geen projectmap (geen package.json/index.html)"

# naam bepalen
if [ -z "$NAME" ] && [ -f .vercel/project.json ]; then
  NAME=$(python3 -c "import json;d=json.load(open('.vercel/project.json'));print(d.get('projectName','') if d.get('orgId')=='$TEAM_ID' else '')")
fi
[ -z "$NAME" ] && NAME=$(basename "$PWD" | tr '[:upper:]_ ' '[:lower:]--')
say "Project: $NAME"

# ---------- 1. GitHub ----------
say "GitHub"
if [ ! -d .git ]; then
  git init -q -b main
  git add -A && git commit -qm "Eerste versie" && ok "git-repo aangemaakt met eerste commit"
fi
if ! git rev-parse HEAD >/dev/null 2>&1; then git add -A && git commit -qm "Eerste versie"; fi
if gh repo view "$ORG/$NAME" >/dev/null 2>&1; then
  ok "repo $ORG/$NAME bestaat al"
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$ORG/$NAME.git"
else
  git remote remove origin 2>/dev/null || true
  gh repo create "$ORG/$NAME" --private --source . --remote origin --push >/dev/null && ok "repo $ORG/$NAME aangemaakt (privé) en gepusht"
fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ---------- 2. Vercel ----------
say "Vercel (team $TEAM_SLUG)"
LINKED_ORG=$(python3 -c "import json;print(json.load(open('.vercel/project.json')).get('orgId',''))" 2>/dev/null || true)
if [ "$LINKED_ORG" != "$TEAM_ID" ]; then
  rm -rf .vercel
  if ! vercel project inspect "$NAME" --scope "$TEAM_SLUG" >/dev/null 2>&1; then
    vercel project add "$NAME" --scope "$TEAM_SLUG" >/dev/null 2>&1 && ok "Vercel-project $NAME aangemaakt"
  fi
  vercel link --yes --project "$NAME" --scope "$TEAM_SLUG" >/dev/null 2>&1 || fail "vercel link mislukt"
fi
PID=$(python3 -c "import json;print(json.load(open('.vercel/project.json'))['projectId'])")
ok "gelinkt aan $NAME ($PID)"
vercel git disconnect --yes >/dev/null 2>&1 || true
ok "geen Git-koppeling in Vercel (deploy loopt via GitHub Actions)"
grep -qxF '.vercel' .gitignore 2>/dev/null || { echo '.vercel' >> .gitignore; }

# ---------- 3. variabele + secrets ----------
say "GitHub-instellingen"
gh variable set VERCEL_PROJECT_ID -R "$ORG/$NAME" -b "$PID" >/dev/null && ok "VERCEL_PROJECT_ID"
TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)
if [ -z "$TOKEN" ]; then
  printf '  ! token niet in sleutelhanger. Eenmalig doen:\n    security add-generic-password -a pendrahq -s %s -w\n  en dan dit commando opnieuw draaien.\n' "$KEYCHAIN_SERVICE"
  exit 1
fi
printf '%s' "$TOKEN" | gh secret set VERCEL_TOKEN -R "$ORG/$NAME" >/dev/null
printf '%s' "$TEAM_ID" | gh secret set VERCEL_ORG_ID -R "$ORG/$NAME" >/dev/null
unset TOKEN
ok "VERCEL_TOKEN + VERCEL_ORG_ID"

# ---------- 4. workflow ----------
say "Deploy-workflow"
if [ -f .github/workflows/deploy.yml ]; then
  ok "staat er al"
else
  mkdir -p .github/workflows && cp "$TEMPLATE" .github/workflows/deploy.yml
  # alleen dit bestand (en .gitignore) committen, andere wijzigingen blijven staan
  git add .github/workflows/deploy.yml .gitignore
  git commit -q -m "Deploy via GitHub Actions (PendraHQ) [skip ci]" -- .github/workflows/deploy.yml .gitignore
  git push -q origin "$BRANCH" && ok "toegevoegd en gepusht (zonder deploy)"
fi

# ---------- preview ----------
if [ "$PREVIEW" = 1 ]; then
  say "Preview-deploy"
  URL=$(vercel deploy --yes --scope "$TEAM_SLUG" 2>/dev/null | tail -1)
  ok "$URL"
fi

say "Klaar. Vanaf nu: push naar een branch/PR = preview, merge naar main = live."
