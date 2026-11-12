<!-- pendra-hq -->
## Pendra: eigenaar en werkwijze
- **Eigenaar: @Quentin-Pendra**, heeft dit project gestart en beslist wat er naar `main` gaat.
- **Nooit direct naar `main` pushen.** Werk op een branch en open een pull request. Ben je niet de eigenaar, voeg dan de eigenaar toe als reviewer: `gh pr create --fill --reviewer Quentin-Pendra`.
- `main` is de hoofdversie van dit project. Vraag daarom **altijd eerst expliciet**: *"Wil je dit naar `main` zetten? Dat gaat live. Eigenaar: @Quentin-Pendra."* Pas na een duidelijk ja mergen.
- Een push naar `main` wordt lokaal tegengehouden door de Pendra-check; bewust doorzetten kan met `PENDRA_MAIN_OK=1 git push`.
- Deploy loopt via GitHub Actions naar Vercel `pendra-hq` (skill `pendra-hq`). Nooit Git koppelen in Vercel.
