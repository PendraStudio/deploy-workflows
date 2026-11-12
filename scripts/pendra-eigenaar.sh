#!/usr/bin/env bash
# pendra-eigenaar — legt in een PendraStudio-repo vast wie de eigenaar is en hoe er naar main gaat.
#   - .github/CODEOWNERS  (* @eigenaar)  → GitHub toont de eigenaar en vraagt hem automatisch als reviewer
#   - Pendra-blok in CLAUDE.md            → Claude weet: nooit direct naar main, eerst vragen, eigenaar als reviewer
# Alles via de GitHub-API met [skip ci]: er wordt niets gedeployd.
#
# Gebruik: pendra-eigenaar <repo> [github-gebruiker]     (standaard: jijzelf)
set -uo pipefail
ORG="PendraStudio"; R="${1:?repo-naam}"; OWNER="${2:-$(gh api user -q .login)}"
MARK="<!-- pendra-hq -->"
DEF=$(gh repo view "$ORG/$R" --json defaultBranchRef -q .defaultBranchRef.name) || { echo "  ✗ $R bestaat niet"; exit 1; }
HAS_DEPLOY=0; gh api "repos/$ORG/$R/contents/.github/workflows/deploy.yml?ref=$DEF" >/dev/null 2>&1 && HAS_DEPLOY=1

case "$R" in
  live-*) EFFECT="Mergen of pushen naar \`$DEF\` zet de site **direct live bij de klant**." ;;
  *) [ $HAS_DEPLOY = 1 ] && EFFECT="Mergen of pushen naar \`$DEF\` zet de productie-versie op Vercel live." || EFFECT="\`$DEF\` is de hoofdversie van dit project." ;;
esac

BLOCK="$MARK
## Pendra: eigenaar en werkwijze
- **Eigenaar: @$OWNER**, heeft dit project gestart en beslist wat er naar \`$DEF\` gaat.
- **Nooit direct naar \`$DEF\` pushen.** Werk op een branch en open een pull request. Ben je niet de eigenaar, voeg dan de eigenaar toe als reviewer: \`gh pr create --fill --reviewer $OWNER\`.
- $EFFECT Vraag daarom **altijd eerst expliciet**: *\"Wil je dit naar \`$DEF\` zetten? Dat gaat live. Eigenaar: @$OWNER.\"* Pas na een duidelijk ja mergen.
- Een push naar \`$DEF\` wordt lokaal tegengehouden door de Pendra-check; bewust doorzetten kan met \`PENDRA_MAIN_OK=1 git push\`.
- Deploy loopt via GitHub Actions naar Vercel \`pendra-hq\` (skill \`pendra-hq\`). Nooit Git koppelen in Vercel."

put() { # put <path> <content> <message>
  local path="$1" content="$2" msg="$3" cur sha=""
  cur=$(gh api "repos/$ORG/$R/contents/$path?ref=$DEF" 2>/dev/null) && sha=$(printf '%s' "$cur" | python3 -c "import json,sys;print(json.load(sys.stdin)['sha'])")
  if [ -n "$sha" ]; then
    printf '%s' "$content" | base64 | gh api -X PUT "repos/$ORG/$R/contents/$path" -f message="$msg" -F content=@- -f sha="$sha" -f branch="$DEF" >/dev/null
  else
    printf '%s' "$content" | base64 | gh api -X PUT "repos/$ORG/$R/contents/$path" -f message="$msg" -F content=@- -f branch="$DEF" >/dev/null
  fi
}

# CLAUDE.md: bestaand Pendra-blok vervangen of blok toevoegen
OLD=""; CUR=$(gh api "repos/$ORG/$R/contents/CLAUDE.md?ref=$DEF" 2>/dev/null) && OLD=$(printf '%s' "$CUR" | python3 -c "import json,sys,base64;print(base64.b64decode(json.load(sys.stdin)['content']).decode(),end='')")
NEWMD=$(MARK="$MARK" BLOCK="$BLOCK" OLD="$OLD" python3 -c "
import os
old, mark, block = os.environ['OLD'], os.environ['MARK'], os.environ['BLOCK']
base = old.split(mark)[0].rstrip() if mark in old else old.rstrip()
print((base + '\n\n' if base else '') + block)")
if [ "$NEWMD" != "$OLD" ]; then put CLAUDE.md "$NEWMD
" "Pendra: eigenaar @$OWNER en werkwijze naar $DEF [skip ci]" && echo "  ✓ $R: CLAUDE.md (eigenaar @$OWNER)"; fi

# CODEOWNERS
CO="# Eigenaar van dit project (Pendra). Wordt automatisch gevraagd als reviewer.
* @$OWNER
"
put .github/CODEOWNERS "$CO" "Pendra: CODEOWNERS @$OWNER [skip ci]" && echo "  ✓ $R: CODEOWNERS"
