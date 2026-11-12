---
name: pendra-hq
description: Pendra-workflow voor GitHub (PendraStudio) en Vercel (team pendra-hq). Gebruik bij alles rond pushen, deployen, preview- of live-links, een project online zetten, een nieuw project starten, projecten verhuizen naar PendraHQ, Vercel-instellingen, domeinen/DNS, secrets/tokens, of fouten in GitHub Actions-deploys.
---

# Pendra-workflow: PendraStudio + PendraHQ

## Model
- Code: GitHub-org `PendraStudio`. Iedereen commit/pusht met zijn **eigen** GitHub-account (identiteit + geschiedenis).
- Sites: Vercel-team `pendra-hq` (slug), id `team_hpzeMXxEof0JVAjm1VgEasR5`. **Eén betaalde seat**; gedeelde login `info@pendra.studio` (CLI-user `pendrahq`).
- Deploy: elke repo heeft `.github/workflows/deploy.yml` → reusable workflow `PendraStudio/deploy-workflows` → `vercel build/deploy --prebuilt` met secret `VERCEL_TOKEN` (PendraHQ-token), `VERCEL_ORG_ID`, repo-variabele `VERCEL_PROJECT_ID`.
  - pull request openen/updaten = **preview** (link komt als reactie in de PR + als 'Preview'-environment); push/merge naar `main` (of de ingestelde production-branch) = **productie**. Een losse branch-push zonder PR bouwt niets (spaart minuten); snel een link zonder PR: `vercel deploy`.
- Vercel ziet alleen de token → geen extra seats, ongeacht wie pusht.

## Commando's (staan in ~/.local/bin, bron: ~/pendra-tools of de deploy-workflows-clone)
| Taak | Commando | Ingelogd als (vercel) |
|---|---|---|
| Project online zetten / nieuw project | `pendra-project <naam> --preview` | `pendrahq` |
| Eigen bestaand project verhuizen | `pendra-verhuis <oude-naam> <nieuwe-naam>` → print `pendra-accepteer …` | eigen account |
| Overdracht accepteren in pendra-hq | `pendra-accepteer <code> <nieuwe-naam> <project-id>` | `pendrahq` |
| Secrets opnieuw zetten | `scripts/set-secrets.sh <repo>` | — |

Gebruik altijd deze scripts; niet zelf repo's, Vercel-projecten, secrets of workflows met de hand opzetten. Ze slaan over wat al klopt.

## Eigenaar en main (altijd)
- Elke repo heeft een **eigenaar**: staat in `.github/CODEOWNERS` en in het Pendra-blok van `CLAUDE.md`. Lees die eerst. Twee soorten:
  - **persoonlijk** (`* @gebruiker`): wie het project startte beslist wat naar de hoofdbranch gaat;
  - **gedeeld** (`* @Quentin-Pendra @arthur-pendra @CCPendra`, met een aanspreekpunt): van het hele team, zoals de Rust-repo's (aanspreekpunt @arthur-pendra). Review door een teamgenoot.
- De hoofdbranch is niet altijd `main` (Rust-repo's: `pendra`). Kijk naar de standaard-branch van de repo.
- **Nooit direct naar `main`/`master` pushen.** Altijd: branch → `gh pr create --fill` → is de gebruiker niet de eigenaar, dan `--reviewer <eigenaar>` toevoegen.
- **Voor elke merge/push naar main expliciet vragen**, met de eigenaar erbij: *"Wil je dit naar main zetten? Dat gaat live. Eigenaar: @x."* Alleen na een duidelijk ja.
- De lokale Pendra git-check blokkeert pushes naar main van PendraStudio-repo's als er geen terminal is om te bevestigen (zoals in Claude Code). Na het akkoord van de gebruiker: `PENDRA_MAIN_OK=1 git push`. Nooit zonder akkoord omzeilen.
- Nieuwe repo of verhuisde repo: `pendra-project`/`pendra-verhuis` zetten de eigenaar automatisch (de gebruiker die het script draait). Handmatig: `pendra-eigenaar <repo> [gebruiker]` of gedeeld: `pendra-eigenaar <repo> team:<aanspreekpunt>`.

## Aan een bestaand project werken
`gh repo clone PendraStudio/<repo>` → `npm install && npm run dev` → `git checkout -b <branch>` → commit/push → `gh pr create --fill` (preview-link verschijnt als PR-reactie) → merge naar main = live. Env vars lokaal: `vercel link --yes --project <repo> --scope pendra-hq && vercel env pull .env.local` (vercel als pendrahq). Geen Vercel-lidmaatschap nodig.

## Naamgeving
`live-` klantsite met domein (main = productie bij de klant) · `pendra-` eigen product/tool · `lab-` experiment/mirror/oude versie. Repo-naam == Vercel-projectnaam. Twijfel → één keer vragen, anders `lab-`.

## Regels
- **Preview mag altijd.** Alles wat naar main/productie gaat (push/merge naar main, `vercel deploy --prod`, Shopify-thema publiceren) **eerst aan de gebruiker vragen**, met de eigenaar erbij genoemd.
- Nooit Git koppelen in Vercel ("Connect Git Repository", `vercel git connect`) en nooit leden of join requests accepteren in pendra-hq: elke Owner/Member/Developer kost $20/maand, ook tijdelijk. Viewer is gratis. Na `vercel link` altijd `vercel git disconnect --yes` (doen de scripts al).
- Tokens nooit in chat, bestanden of commits. Token komt uit de macOS-sleutelhanger (`security find-generic-password -s pendrahq-vercel-token -w`); ontbreekt hij, laat de gebruiker zelf draaien: `security add-generic-password -a pendrahq -s pendrahq-vercel-token -w`.
- Workflow-bestanden toevoegen aan een bestaande repo: commit met `[skip ci]` zodat er niets onbedoeld live gaat.
- Uncommitted werk gaat niet mee in de scripts; vraag of het eerst gecommit moet worden.
- Houd shell-commando's simpel (één ding per commando), dan vraagt Claude Code minder om toestemming.

## Valkuilen
- 404 op vercel.com/pendra-hq → browser ingelogd met verkeerd account; inloggen als info@pendra.studio.
- Actions: "token … is not valid" → secret fout (vaak dubbel geplakt); opnieuw via sleutelhanger + `set-secrets.sh`.
- Vercel-deploy BLOCKED / "commit author is not a member" → er hangt toch een Git-koppeling; `vercel git disconnect`.
- Preview vraagt login → Deployment Protection; gebruik de Share-link.
- "No Production Deployment" / "Connect Git Repository" in het dashboard → normaal bij deze opzet.
- Domein met DNS bij Vercel verhuizen: `vercel domains move <domein> pendra-hq --scope <oud-team>` (records gaan mee). DNS bij Hostinger/GoDaddy: niets doen.
- Shopify-thema gekoppeld aan GitHub: na repo-verhuizing opnieuw koppelen ("Could not load branches" = opnieuw inloggen bij GitHub in het Connect-paneel; één branch per thema) en daarna pas publiceren.
- macOS `/bin/bash` is 3.2: geen `declare -A` in scripts.
