#!/usr/bin/env bash
# pendra-accepteer — accepteert een overdracht-aanvraag (van pendra-verhuis) in team pendra-hq en rondt af.
# Gebruik (vercel ingelogd als pendrahq):   pendra-accepteer <code> <nieuwe-naam> <project-id>
set -uo pipefail
HQ_ID="team_hpzeMXxEof0JVAjm1VgEasR5"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; echo '{}' > "$TMP/empty.json"
ok() { printf '  ✓ %s\n' "$*"; }; fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
api() { vercel api "$@" 2>/dev/null; }
[ $# -ge 3 ] || { sed -n '2,3p' "$0"; exit 1; }
CODE="$1"; NEW="$2"; PID="$3"
[ "$(vercel whoami 2>/dev/null | tail -1)" = "pendrahq" ] || fail "log in als pendrahq (vercel login)"

api "/projects/transfer-request/$CODE?teamId=$HQ_ID" --method PUT --input "$TMP/empty.json" >/dev/null
for i in $(seq 1 20); do
  A=$(api "/v9/projects/$PID?teamId=$HQ_ID" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('accountId',''))
except Exception: print('')"); [ "$A" = "$HQ_ID" ] && break; sleep 3; done
[ "$A" = "$HQ_ID" ] || fail "overdracht niet gelukt (code verlopen of al gebruikt?)"
ok "overdracht geaccepteerd ($PID)"
echo "{\"name\":\"$NEW\"}" > "$TMP/n.json"
api "/v9/projects/$PID?teamId=$HQ_ID" --method PATCH --input "$TMP/n.json" >/dev/null && ok "hernoemd naar $NEW"
mkdir -p "$TMP/l/.vercel" && echo "{\"projectId\":\"$PID\",\"orgId\":\"$HQ_ID\"}" > "$TMP/l/.vercel/project.json"
(cd "$TMP/l" && vercel git disconnect --yes >/dev/null 2>&1) || true
ok "geen Git-koppeling in Vercel"
api "/v9/projects/$PID/domains?teamId=$HQ_ID" | python3 -c "import json,sys
for x in json.load(sys.stdin).get('domains',[]): print('  · domein', x['name'], 'geverifieerd' if x.get('verified') else 'NIET geverifieerd')"
