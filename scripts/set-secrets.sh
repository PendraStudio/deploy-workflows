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

read -rsp "Plak VERCEL_TOKEN (niet zichtbaar): " TOKEN; echo
read -rp  "VERCEL_ORG_ID (Team ID): " ORGID

for r in "${REPOS[@]}"; do
  printf '%s' "$TOKEN" | gh secret set VERCEL_TOKEN  -R "$ORG/$r" >/dev/null \
    && printf '%s' "$ORGID" | gh secret set VERCEL_ORG_ID -R "$ORG/$r" >/dev/null \
    && echo "✓ $r" || echo "✗ $r (check of de repo bestaat en of je admin bent)"
done
unset TOKEN
