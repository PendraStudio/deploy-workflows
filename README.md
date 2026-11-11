# deploy-workflows

Centrale deploy-workflow voor alle sites in de GitHub-org **PendraStudio** naar het Vercel-team **PendraHQ**.
Collega's pushen met hun eigen GitHub; deze workflow deployt met de PendraHQ-token, dus er zijn geen extra Vercel-members nodig.

## Eenmalig
1. Vercel (ingelogd als PendraHQ) → Account Settings → Tokens → token `github-actions`, scope **PendraHQ**.
2. Deze repo is **public** zodat private repo's hem kunnen gebruiken op het gratis GitHub-plan. Er staan geen geheimen in.

## Secrets (gratis plan = per repo)
Org-secrets werken niet voor private repo's op GitHub Free. Gebruik daarom het script:
1. Zet repo-namen in `scripts/repos.txt` (één per regel).
2. In je eigen Terminal: `./scripts/set-secrets.sh` → token en Team ID één keer invoeren.
   Zet `VERCEL_TOKEN` en `VERCEL_ORG_ID` in elke repo. Nieuwe site: `./scripts/set-secrets.sh <repo>`.

## Per site-repo
1. Vercel-project bestaat in PendraHQ (transfer of `vercel link`).
2. Repo-variabele `VERCEL_PROJECT_ID` = Project ID (Vercel → Project → Settings → General).
3. Kopieer `template/.github/workflows/deploy.yml` naar de repo.
4. In Vercel: zet bij het project de automatische Git-deploys uit (of koppel geen Git-repo), anders deployt het dubbel.

Push naar `main` = productie, andere branches = preview.
