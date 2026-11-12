#!/usr/bin/env python3
"""Voegt veilige dev-commando's toe aan ~/.claude/settings.json (permissions.allow) en werkt
de auto-mode-omgeving bij voor PendraStudio/PendraHQ. Bestaande instellingen blijven staan."""
import json, os

p = os.path.expanduser("~/.claude/settings.json")
d = json.load(open(p))

allow = [
    "Bash(npm run build:*)", "Bash(npm run dev:*)", "Bash(npm run start:*)", "Bash(npm run lint:*)",
    "Bash(npm install:*)", "Bash(npm ci:*)", "Bash(npx serve:*)", "Bash(npx --yes serve:*)",
    "Bash(pnpm build:*)", "Bash(pnpm dev:*)",
    "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)", "Bash(git add:*)", "Bash(git commit:*)",
    "Bash(curl -s:*)", "Bash(vercel deploy:*)", "Bash(pendra-project:*)",
]
perm = d.setdefault("permissions", {})
cur = perm.setdefault("allow", [])
added = [a for a in allow if a not in cur]
cur.extend(added)

env = d.setdefault("autoMode", {}).setdefault("environment", [])
repl = {
    "**Organization**": "**Organization**: Pendra studio (Quentin, Arthur, Chris). GitHub org PendraStudio (all company repos, private); Vercel team pendra-hq (all sites)",
    "**Cloud provider(s)**": "**Cloud provider(s)**: Vercel (team pendra-hq), Shopify (Candela store)",
    "**Repository visibility**": "**Repository visibility**: PendraStudio repos are private; PendraStudio/deploy-workflows is public on purpose",
    "**CI/CD deploy targets**": "**CI/CD deploy targets**: GitHub Actions -> Vercel pendra-hq (main = production of that site, other branches/PRs = preview, routine); PendraStudio/live-candela-store master -> Shopify live theme. Production of a live-* client site: confirm with the user first",
}
for i, e in enumerate(env):
    for k, v in repl.items():
        if e.startswith(k):
            env[i] = v

json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
print(f"Klaar: {len(added)} commando's toegevoegd, auto-mode bijgewerkt. Start Claude Code opnieuw.")
