#!/usr/bin/env bash
# Installeert de Pendra-commando's (pendra-project, pendra-verhuis) in ~/.local/bin.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/bin"
for c in pendra-project pendra-verhuis pendra-accepteer pendra-eigenaar; do ln -sf "$DIR/$c.sh" "$HOME/.local/bin/$c"; echo "✓ $c"; done
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo "✓ ~/.local/bin aan je PATH toegevoegd (open een nieuw Terminal-venster)";; esac
# Git-check: vraagt bevestiging bij een push naar main van een PendraStudio-repo
HOOKS="$(cd "$DIR/.." && pwd)/hooks"
CURH=$(git config --global --get core.hooksPath || true)
if [ -z "$CURH" ] || [ "$CURH" = "$HOOKS" ]; then
  git config --global core.hooksPath "$HOOKS" && echo "✓ git-check voor main-pushes (bestaande repo-hooks blijven werken)"
else
  echo "! je hebt al een globale core.hooksPath ($CURH); kopieer $HOOKS/pre-push daar zelf naartoe"
fi
# Claude Code-skill
mkdir -p "$HOME/.claude/skills"
SKILL="$(cd "$DIR/.." && pwd)/skills/pendra-hq"
if [ -e "$HOME/.claude/skills/pendra-hq" ] && [ ! -L "$HOME/.claude/skills/pendra-hq" ]; then
  mv "$HOME/.claude/skills/pendra-hq" "$HOME/.claude/skills/pendra-hq.bak.$(date +%s)"
fi
ln -sfn "$SKILL" "$HOME/.claude/skills/pendra-hq" && echo "✓ Claude Code-skill pendra-hq"
echo "Klaar. Test met: pendra-project --help  (bijwerken: git -C $(cd "$DIR/.." && pwd) pull)"
