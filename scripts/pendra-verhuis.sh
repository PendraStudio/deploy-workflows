#!/usr/bin/env bash
# pendra-verhuis — verhuist één bestaand Vercel-project (+ de GitHub-repo erachter) naar PendraHQ / PendraStudio.
#
# Gebruik:   pendra-verhuis <huidige-vercel-projectnaam> <nieuwe-naam>
#   bv.      pendra-verhuis mijn-klantsite live-mijnklant
#
# Voorwaarden (zie het workflow-document):
#   - vercel CLI ingelogd met JE EIGEN account (niet pendrahq), en je bent tijdelijk lid van team pendra-hq
#   - gh ingelogd met je eigen GitHub-account, lid van org PendraStudio
#   - PendraHQ Vercel-token in je sleutelhanger (service: pendrahq-vercel-token)
#
# Wat het doet:
#   1. zoekt het project in jouw eigen Vercel-teams
#   2. haalt de Git-koppeling in Vercel weg, zet het project over naar pendra-hq en hernoemt het
#   3. verhuist domeinen waarvan de DNS bij Vercel staat mee (records gaan mee)
#   4. verhuist de GitHub-repo naar PendraStudio/<nieuwe-naam> (privé)
#   5. zet VERCEL_PROJECT_ID, VERCEL_TOKEN, VERCEL_ORG_ID en het deploy-bestand (zonder te deployen)
set -uo pipefail

HQ_SLUG="pendra-hq"; HQ_ID="team_hpzeMXxEof0JVAjm1VgEasR5"; ORG="PendraStudio"
KEYCHAIN_SERVICE="pendrahq-vercel-token"
TEMPLATE="$(cd "$(dirname "$(readlink "$0" || echo "$0")")/.." && pwd)/template/.github/workflows/deploy.yml"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
echo '{}' > "$TMP/empty.json"

say()  { printf '\033[1m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
api()  { vercel api "$@" 2>/dev/null; }
js()   { python3 -c "import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
$1"; }

[ $# -ge 2 ] || { sed -n '2,8p' "$0"; exit 1; }
OLD="$1"; NEW="$2"
case "$NEW" in live-*|pendra-*|lab-*) ;; *) fail "nieuwe naam moet beginnen met live-, pendra- of lab-";; esac

# ---------- controles ----------
command -v gh >/dev/null && command -v vercel >/dev/null || fail "gh en vercel CLI zijn nodig"
gh auth status >/dev/null 2>&1 || fail "gh is niet ingelogd (gh auth login)"
WHO=$(vercel whoami 2>/dev/null | tail -1)
[ -n "$WHO" ] || fail "vercel is niet ingelogd (vercel login)"
[ "$WHO" != "pendrahq" ] || fail "log voor het verhuizen in met JE EIGEN Vercel-account, niet met pendrahq"
api "/v2/teams/$HQ_ID" | js "sys.exit(0 if d.get('id') else 1)" || fail "jouw account ($WHO) is (nog) geen lid van pendra-hq — vraag Quentin om je tijdelijk toe te voegen"
TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)
[ -n "$TOKEN" ] || fail "token niet in sleutelhanger: security add-generic-password -a pendrahq -s $KEYCHAIN_SERVICE -w"

# ---------- 1. project zoeken ----------
say "Project '$OLD' zoeken in jouw Vercel-teams"
SRC=""; PID=""
for T in $(api "/v2/teams?limit=100" | js "print(' '.join(t['id'] for t in d.get('teams',[]) if t['id']!='$HQ_ID'))"); do
  P=$(api "/v9/projects/$OLD?teamId=$T" | js "print(d.get('id',''))")
  [ -n "$P" ] && { SRC="$T"; PID="$P"; break; }
done
if [ -z "$PID" ]; then
  P=$(api "/v9/projects/$NEW?teamId=$HQ_ID" | js "print(d.get('id',''))")
  [ -n "$P" ] && { PID="$P"; ok "staat al in pendra-hq als $NEW ($PID) — ik maak de rest af"; } || fail "project '$OLD' niet gevonden in je teams"
else
  ok "gevonden in team $SRC ($PID)"
fi

# repo + domeinen onthouden vóór het loskoppelen
INFO=$(api "/v9/projects/$PID?teamId=${SRC:-$HQ_ID}")
REPO=$(echo "$INFO" | js "l=d.get('link') or {}; print((l.get('org','')+'/'+l.get('repo','')) if l.get('repo') else '')")
BRANCH=$(echo "$INFO" | js "print((d.get('link') or {}).get('productionBranch','main'))")

if [ -n "$SRC" ]; then
  DOMAINS=$(api "/v9/projects/$PID/domains?teamId=$SRC" | js "print(' '.join(x['name'] for x in d.get('domains',[]) if not x['name'].endswith('.vercel.app')))")
  # ---------- 2. overzetten ----------
  say "Overzetten naar $HQ_SLUG"
  mkdir -p "$TMP/l1/.vercel" && echo "{\"projectId\":\"$PID\",\"orgId\":\"$SRC\"}" > "$TMP/l1/.vercel/project.json"
  (cd "$TMP/l1" && vercel git disconnect --yes >/dev/null 2>&1) && ok "Git-koppeling in Vercel weg"
  CODE=$(api "/projects/$PID/transfer-request?teamId=$SRC" --method POST --input "$TMP/empty.json" | js "print(d.get('code',''))")
  [ -n "$CODE" ] || fail "overdracht-aanvraag mislukt"
  api "/projects/transfer-request/$CODE?teamId=$HQ_ID" --method PUT --input "$TMP/empty.json" >/dev/null
  for i in $(seq 1 20); do
    A=$(api "/v9/projects/$PID?teamId=$HQ_ID" | js "print(d.get('accountId',''))"); [ "$A" = "$HQ_ID" ] && break; sleep 3
  done
  [ "$A" = "$HQ_ID" ] || fail "overdracht niet bevestigd — kijk in Vercel"
  ok "project staat in $HQ_SLUG"
  # domeinen met Vercel-DNS meeverhuizen
  for D in $DOMAINS; do
    APEX=$(echo "$D" | awk -F. '{print $(NF-1)"."$NF}')
    if vercel domains inspect "$APEX" --scope "$SRC" >/dev/null 2>&1; then
      vercel domains move "$APEX" "$HQ_SLUG" --scope "$SRC" --yes >/dev/null 2>&1 && ok "domein $APEX (met DNS-records) verhuisd" || warn "domein $APEX niet verhuisd — doe het in Vercel via Domains → Move"
    fi
  done
fi

# ---------- hernoemen + koppeling in doelteam weg ----------
echo "{\"name\":\"$NEW\"}" > "$TMP/name.json"
for i in $(seq 1 10); do
  R=$(api "/v9/projects/$PID?teamId=$HQ_ID" --method PATCH --input "$TMP/name.json" | js "print(d.get('name',''))")
  [ "$R" = "$NEW" ] && break; sleep 3
done
[ "$R" = "$NEW" ] && ok "hernoemd naar $NEW" || warn "hernoemen niet gelukt, doe het in Vercel → Settings → Project Name"
mkdir -p "$TMP/l2/.vercel" && echo "{\"projectId\":\"$PID\",\"orgId\":\"$HQ_ID\"}" > "$TMP/l2/.vercel/project.json"
(cd "$TMP/l2" && vercel git disconnect --yes >/dev/null 2>&1) || true

# ---------- 4. GitHub ----------
if [ -z "$REPO" ]; then
  warn "dit project had geen GitHub-repo. Wil je er een? Ga naar de projectmap en draai: pendra-project $NEW"
  say "Klaar: $OLD → $NEW (zonder repo)"; exit 0
fi
say "GitHub-repo $REPO → $ORG/$NEW"
if gh repo view "$ORG/$NEW" >/dev/null 2>&1; then
  ok "repo staat al in $ORG"
else
  gh api "repos/$REPO/transfer" -f new_owner="$ORG" -f new_name="$NEW" >/dev/null 2>&1 || fail "repo-verhuizing mislukt (ben je eigenaar van $REPO?)"
  for i in $(seq 1 20); do gh repo view "$ORG/$NEW" >/dev/null 2>&1 && break; sleep 3; done
  ok "repo verhuisd"
fi

# ---------- 5. instellingen + workflow ----------
say "Deploy-instellingen"
gh variable set VERCEL_PROJECT_ID -R "$ORG/$NEW" -b "$PID" >/dev/null && ok "VERCEL_PROJECT_ID"
printf '%s' "$TOKEN" | gh secret set VERCEL_TOKEN -R "$ORG/$NEW" >/dev/null
printf '%s' "$HQ_ID"  | gh secret set VERCEL_ORG_ID -R "$ORG/$NEW" >/dev/null
unset TOKEN; ok "VERCEL_TOKEN + VERCEL_ORG_ID"
DEF=$(gh repo view "$ORG/$NEW" --json defaultBranchRef -q .defaultBranchRef.name)
if gh api "repos/$ORG/$NEW/contents/.github/workflows/deploy.yml" >/dev/null 2>&1; then
  ok "deploy-bestand staat er al"
else
  if [ "$DEF" = "main" ]; then
    CONTENT=$(base64 < "$TEMPLATE")
  else
    CONTENT=$(sed -e "s/branches: \[main\]/branches: [$DEF]/" \
      -e "s/project-id: \${{ vars.VERCEL_PROJECT_ID }}/project-id: \${{ vars.VERCEL_PROJECT_ID }}\\
      production-branch: $DEF/" "$TEMPLATE" | base64)
  fi
  for i in $(seq 1 10); do
    gh api -X PUT "repos/$ORG/$NEW/contents/.github/workflows/deploy.yml" \
      -f message="Deploy via GitHub Actions (PendraHQ) [skip ci]" -f content="$CONTENT" -f branch="$DEF" >/dev/null 2>&1 && break
    sleep 6
  done
  ok "deploy-bestand toegevoegd op $DEF (er is níets opnieuw live gezet)"
fi

say "Klaar: $OLD → $NEW"
echo "  Lokale map bijwerken (eenmalig, in je projectmap):"
echo "    git remote set-url origin https://github.com/$ORG/$NEW.git"
echo "    rm -rf .vercel && vercel link --yes --project $NEW --scope $HQ_SLUG   (als pendrahq ingelogd)"
