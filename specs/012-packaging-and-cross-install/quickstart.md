# Quickstart: validate feature 012

1. Install from the README alone, on a clean machine: load, retag, `cp .env.example .env`,
   `docker buildx use default`, `docker compose build`, `docker compose up -d`.
2. Run `sh scripts/smoke.sh`. Expected: `smoke: PASS in <n>s: Case case_… is <state>` within
   15 minutes of starting the install.
3. Open `http://localhost:52773/signalnoir/`. Expected: the console lists the Case. Node is not
   needed on the host.
4. Run `docker compose restart`, then `stop` and `start`. Expected: the same Cases and Timeline.
   Then `down` and `up`. Expected: zero Cases.
5. Search for the key:
   - `docker history --no-trunc signalnoir/app:local | grep -c "$KEY"` → 0;
   - the same for `docker compose logs`, the Case detail and `git grep`.
6. Run `sh scripts/secret-scan.sh`. Expected: `secret-scan: clean`.
7. Run CI on a push. Expected: the secret-scan, console, core-tests, contracts and quality jobs
   pass, and no job builds or pushes an image.
