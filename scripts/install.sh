#!/usr/bin/env bash
# Installeert de Pendra-commando's (pendra-project, pendra-verhuis) in ~/.local/bin.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/bin"
for c in pendra-project pendra-verhuis pendra-accepteer; do ln -sf "$DIR/$c.sh" "$HOME/.local/bin/$c"; echo "✓ $c"; done
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo "✓ ~/.local/bin aan je PATH toegevoegd (open een nieuw Terminal-venster)";; esac
echo "Klaar. Test met: pendra-project --help"
