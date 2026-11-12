#!/usr/bin/env bash
# pendra-claudemd — zet de productie-waarschuwing in CLAUDE.md van een live-repo (via de GitHub-API, [skip ci]).
# Gebruik: pendra-claudemd <repo-naam zonder PendraStudio/>
set -uo pipefail
ORG="PendraStudio"; R="$1"
case "$R" in live-*) ;; *) echo "  (alleen voor live- repo's, $R overgeslagen)"; exit 0;; esac
MARK="<!-- pendra-hq -->"
BLOCK="$MARK
## Pendra: productie
- Dit is een \`live-\` klantsite. Push of merge naar de standaard-branch gaat **direct live** bij de klant: eerst de preview laten zien en toestemming vragen.
- Deploy loopt via GitHub Actions naar Vercel \`pendra-hq\` (zie skill \`pendra-hq\`). Nooit Git koppelen in Vercel."
DEF=$(gh repo view "$ORG/$R" --json defaultBranchRef -q .defaultBranchRef.name)
CUR=$(gh api "repos/$ORG/$R/contents/CLAUDE.md?ref=$DEF" 2>/dev/null) || CUR=""
if [ -n "$CUR" ]; then
  SHA=$(printf '%s' "$CUR" | python3 -c "import json,sys;print(json.load(sys.stdin)['sha'])")
  OLD=$(printf '%s' "$CUR" | python3 -c "import json,sys,base64;print(base64.b64decode(json.load(sys.stdin)['content']).decode(),end='')")
  case "$OLD" in *"$MARK"*) echo "  ✓ $R: CLAUDE.md heeft de regel al"; exit 0;; esac
  NEWC="$OLD

$BLOCK
"
  printf '%s' "$NEWC" | base64 | gh api -X PUT "repos/$ORG/$R/contents/CLAUDE.md" -f message="CLAUDE.md: productie-waarschuwing (live-site) [skip ci]" -F content=@- -f sha="$SHA" -f branch="$DEF" >/dev/null && echo "  ✓ $R: regel toegevoegd aan bestaande CLAUDE.md"
else
  printf '%s\n' "$BLOCK" | base64 | gh api -X PUT "repos/$ORG/$R/contents/CLAUDE.md" -f message="CLAUDE.md: productie-waarschuwing (live-site) [skip ci]" -F content=@- -f branch="$DEF" >/dev/null && echo "  ✓ $R: CLAUDE.md aangemaakt"
fi
