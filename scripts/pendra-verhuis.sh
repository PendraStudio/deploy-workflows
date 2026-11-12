#!/usr/bin/env bash
# pendra-verhuis — verhuist één eigen Vercel-project + de GitHub-repo erachter naar PendraHQ / PendraStudio.
# Je hoeft GEEN lid van het Vercel-team pendra-hq te zijn (geen extra seat).
#
# Gebruik (vercel ingelogd met JE EIGEN account):
#   pendra-verhuis <huidige-vercel-projectnaam> <nieuwe-naam>
#
# Doet:
#   1. Git-koppeling in Vercel weg + overdracht-aanvraag naar pendra-hq (geeft een code)
#   2. GitHub-repo -> PendraStudio/<nieuwe-naam> (privé)
#   3. VERCEL_PROJECT_ID, VERCEL_TOKEN, VERCEL_ORG_ID + deploy-bestand in de repo ([skip ci], niets gaat live)
# Daarna accepteert iemand met de PendraHQ-login:  pendra-accepteer <code> <nieuwe-naam> <project-id>
set -uo pipefail

HQ_ID="team_hpzeMXxEof0JVAjm1VgEasR5"; ORG="PendraStudio"; KEYCHAIN_SERVICE="pendrahq-vercel-token"
TEMPLATE="$(cd "$(dirname "$(readlink "$0" || echo "$0")")/.." && pwd)/template/.github/workflows/deploy.yml"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; echo '{}' > "$TMP/empty.json"
say()  { printf '\033[1m▸ %s\033[0m\n' "$*"; }; ok() { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }; fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
api()  { vercel api "$@" 2>/dev/null; }
js()   { python3 -c "import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
$1"; }

[ $# -ge 2 ] || { sed -n '2,12p' "$0"; exit 1; }
OLD="$1"; NEW="$2"
case "$NEW" in live-*|pendra-*|lab-*) ;; *) fail "nieuwe naam moet beginnen met live-, pendra- of lab-";; esac
gh auth status >/dev/null 2>&1 || fail "gh is niet ingelogd"
WHO=$(vercel whoami 2>/dev/null | tail -1); [ -n "$WHO" ] || fail "vercel is niet ingelogd"
[ "$WHO" != "pendrahq" ] || fail "log in met je EIGEN Vercel-account (het project staat daar)"
TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)
[ -n "$TOKEN" ] || fail "token niet in sleutelhanger: security add-generic-password -a pendrahq -s $KEYCHAIN_SERVICE -w"

# ---------- 1. Vercel ----------
say "Vercel-project '$OLD' zoeken"
SRC=""; PID=""
for T in $(api "/v2/teams?limit=100" | js "print(' '.join(t['id'] for t in d.get('teams',[]) if t['id']!='$HQ_ID'))"); do
  P=$(api "/v9/projects/$OLD?teamId=$T" | js "print(d.get('id',''))"); [ -n "$P" ] && { SRC="$T"; PID="$P"; break; }
done
[ -n "$PID" ] || fail "project '$OLD' niet gevonden in je teams (vercel project ls)"
INFO=$(api "/v9/projects/$PID?teamId=$SRC")
REPO=$(echo "$INFO" | js "l=d.get('link') or {}; print((l.get('org','')+'/'+l.get('repo','')) if l.get('repo') else '')")
DOMAINS=$(api "/v9/projects/$PID/domains?teamId=$SRC" | js "print(' '.join(x['name'] for x in d.get('domains',[]) if not x['name'].endswith('.vercel.app')))")
ok "gevonden ($PID)${REPO:+, repo $REPO}"

mkdir -p "$TMP/l/.vercel" && echo "{\"projectId\":\"$PID\",\"orgId\":\"$SRC\"}" > "$TMP/l/.vercel/project.json"
(cd "$TMP/l" && vercel git disconnect --yes >/dev/null 2>&1) && ok "Git-koppeling in Vercel weg"
CODE=$(api "/projects/$PID/transfer-request?teamId=$SRC" --method POST --input "$TMP/empty.json" | js "print(d.get('code',''))")
[ -n "$CODE" ] || fail "overdracht-aanvraag mislukt"
ok "overdracht-aanvraag gemaakt"

# ---------- 2. GitHub ----------
if [ -n "$REPO" ]; then
  say "Repo $REPO → $ORG/$NEW"
  if gh repo view "$ORG/$NEW" >/dev/null 2>&1; then ok "staat al in $ORG"; else
    gh api "repos/$REPO/transfer" -f new_owner="$ORG" -f new_name="$NEW" >/dev/null 2>&1 || fail "repo-verhuizing mislukt (ben je eigenaar van $REPO?)"
    for i in $(seq 1 20); do gh repo view "$ORG/$NEW" >/dev/null 2>&1 && break; sleep 3; done; ok "verhuisd"
  fi
  # ---------- 3. instellingen ----------
  gh variable set VERCEL_PROJECT_ID -R "$ORG/$NEW" -b "$PID" >/dev/null
  printf '%s' "$TOKEN" | gh secret set VERCEL_TOKEN -R "$ORG/$NEW" >/dev/null
  printf '%s' "$HQ_ID" | gh secret set VERCEL_ORG_ID -R "$ORG/$NEW" >/dev/null
  ok "VERCEL_PROJECT_ID + secrets"
  DEF=$(gh repo view "$ORG/$NEW" --json defaultBranchRef -q .defaultBranchRef.name)
  if ! gh api "repos/$ORG/$NEW/contents/.github/workflows/deploy.yml" >/dev/null 2>&1; then
    if [ "$DEF" = "main" ]; then CONTENT=$(base64 < "$TEMPLATE"); else
      CONTENT=$(sed -e "s/branches: \[main\]/branches: [$DEF]/" -e "s/project-id: \${{ vars.VERCEL_PROJECT_ID }}/project-id: \${{ vars.VERCEL_PROJECT_ID }}\\
      production-branch: $DEF/" "$TEMPLATE" | base64); fi
    for i in $(seq 1 10); do
      gh api -X PUT "repos/$ORG/$NEW/contents/.github/workflows/deploy.yml" -f message="Deploy via GitHub Actions (PendraHQ) [skip ci]" \
        -f content="$CONTENT" -f branch="$DEF" >/dev/null 2>&1 && break; sleep 6; done
  fi
  ok "deploy-bestand op $DEF (niets live gezet)"
else
  warn "geen GitHub-repo gekoppeld; later toevoegen met: pendra-project $NEW"
fi
unset TOKEN

# ---------- domeinen met Vercel-DNS ----------
VDNS=""
for D in $DOMAINS; do APEX=$(echo "$D" | awk -F. '{print $(NF-1)"."$NF}')
  vercel domains inspect "$APEX" --scope "$SRC" >/dev/null 2>&1 && case " $VDNS " in *" $APEX "*) ;; *) VDNS="$VDNS $APEX";; esac
done

say "Bijna klaar. Stuur dit naar wie de PendraHQ-login heeft:"
echo
echo "    pendra-accepteer $CODE $NEW $PID"
echo
[ -n "$VDNS" ] && echo "  Domeinen met DNS bij Vercel (pas NA het accepteren verhuizen):$VDNS
    vercel domains move <domein> pendra-hq --scope $SRC"
[ -n "$REPO" ] && echo "  Lokale map:  git remote set-url origin https://github.com/$ORG/$NEW.git"
