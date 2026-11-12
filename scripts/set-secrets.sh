#!/usr/bin/env bash
# Zet VERCEL_TOKEN en VERCEL_ORG_ID als repo-secret in alle repo's uit repos.txt.
# Draai dit in je eigen Terminal (de token wordt verborgen ingetypt, nergens opgeslagen).
# Gebruik: ./scripts/set-secrets.sh            (alle repo's in scripts/repos.txt)
#          ./scripts/set-secrets.sh repo-a repo-b
set -euo pipefail
ORG="PendraStudio"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -gt 0 ]; then REPOS=("$@"); else
  REPOS=()
  while IFS= read -r line; do REPOS+=("$line"); done < <(grep -vE '^[[:space:]]*(#|$)' "$DIR/repos.txt" 2>/dev/null || true)
fi
if [ -z "${REPOS[*]:-}" ]; then echo "Geen repo's opgegeven (vul scripts/repos.txt)."; exit 1; fi

TOKEN=$(security find-generic-password -s pendrahq-vercel-token -w 2>/dev/null || true)
if [ -n "$TOKEN" ]; then echo "Token gevonden in je sleutelhanger."; else
read -rsp "Plak VERCEL_TOKEN (niet zichtbaar): " TOKEN; echo
TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
echo "Token is ${#TOKEN} tekens lang, begint met '${TOKEN:0:4}' en eindigt op '${TOKEN: -4}'."
echo "Vergelijk met je token: staat het begin er nog een keer middenin, dan is hij dubbel geplakt."
read -rp "Klopt dat? (j/n) " OK; [ "$OK" = "j" ] || { echo "Gestopt."; exit 1; }
fi
ORGID="team_hpzeMXxEof0JVAjm1VgEasR5"

for r in "${REPOS[@]}"; do
  printf '%s' "$TOKEN" | gh secret set VERCEL_TOKEN  -R "$ORG/$r" >/dev/null \
    && printf '%s' "$ORGID" | gh secret set VERCEL_ORG_ID -R "$ORG/$r" >/dev/null \
    && echo "✓ $r" || echo "✗ $r (check of de repo bestaat en of je admin bent)"
done
unset TOKEN
