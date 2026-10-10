For h-dashboard PRs: user says 'pr' → create PR from current branch to upstream/beta (asgarimehdi/h-dashboard). All changes commit+push to current branch.
§
Every new session: cwd /home/runner/h-dashboard; `codegraph sync` first, then codegraph_explore for code Q&A; load superpowers process skills.
§
Boost MCP occasionally dies on first stdio call ("lost its stdio subprocess") — call it again. CLI fallback always works: php scripts/boost_tool.php <tool> '<json>'.
§
h-dashboard branch nahal tracks origin/beta (branch.nahal.merge=refs/heads/beta), so `git status` shows 'nahal...origin/beta'; always use explicit refspecs HEAD:refs/heads/nahal.
§
MaryUI x-select defaults to optionValue='id'/optionLabel='name'. Options keyed 'value'/'label' need explicit option-value="value" option-label="label" or every <option> renders empty (blank control). Pass :options="$this->myOptions()" from a component method — a bare $myOptions is undefined in the Blade view.
§
scripts/e2e-test.sh: not concurrency-safe, no trap — never run two instances; .env.dev.bak may hold ALREADY-SWAPPED content so .env stays on e2e config (always verify `grep DB_DATABASE .env` == h_dashboard after a run). Lost bak: cp .env.e2e .env, set APP_URL=http://127.0.0.1:8000 + DB_DATABASE=h_dashboard; kill orphan via `kill $(pgrep -f 'artisan serve --port=800[1]')` — never pkill -f 'artisan serve' (kills shared :8000).
§
.env is gitignored; rebuild from `.env-example-github` + secrets in `.env.e2e`, override APP_URL=http://127.0.0.1:8000 and DB_DATABASE=h_dashboard, drop `secrets.` lines, verify `php artisan about --only=environment`. parse_ini_file('.env') fails (unquoted parens) — regex scan or config() instead.
§
Issue-review cron 391997173a5b: gate = ~/.hermes/scripts/h-dashboard-issue-gate.sh — copy from the issue-watch skill's templates/issue-gate.sh; rebuild it when a tick reports 'Script not found'.