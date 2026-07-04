# FSS — Fast Security Scan: Monorepo Build Plan

Spec: monorepo with `apps/cli` (POSIX sh security scanner) and `apps/www`
(static landing page → Cloudflare Pages `coody-fss-www-prd-01` → fss.coody.app).
Headline: "A Fast Security Scan for developers."

Note: `tmp/www` referenced in the request does not exist in the repo or in
system `/tmp`. Built `apps/www` from spec instead: static landing page for the
FSS CLI, using the given headline and domain. `tmp/ex1..ex6` used as pattern
sources for the CLI (IOC lists, check structure, exit codes, cleanup UX).

## Plan

- [x] Analyze `tmp/ex1..ex6` for patterns (IOCs, check structure, exit codes)
- [x] Scaffold monorepo: `apps/`, `docs/`, `.github/workflows/`, `.gitignore`
- [x] `apps/cli`: POSIX sh, macOS + Debian compatible
  - [x] `bin/fss` dispatcher (scan | clean | outdated)
  - [x] `lib/common.sh` — output helpers, counters, portability shims
  - [x] `lib/scan.sh` — supply-chain + security checks
  - [x] `lib/clean.sh` — safe node_modules removal
  - [x] `lib/outdated.sh` — dependency freshness check
  - [x] `test/run-tests.sh` + fixtures
- [x] `apps/www`: static site (no build step), headline, security headers
- [x] CI: `ci.yml` (sh -n, shellcheck, CLI tests)
- [x] CD: `deploy-www.yml` (wrangler pages deploy on main)
- [x] Docs: `docs/cli.md`, `docs/www.md`, `docs/deployment.md`, root `README.md`
- [x] Verify: run tests locally, run scan against fixtures
- [x] Deploy: create Pages project in coody account, deploy, custom domain
- [x] Commit + push to github.com/coodyapp/fss

## Key decisions

- Pure POSIX sh (`#!/bin/sh`): works on dash (Debian) and macOS sh. No arrays,
  no `[[ ]]`, no bashisms. Verified with `sh -n` + shellcheck in CI.
- IOC patterns embedded in `lib/scan.sh` (no external file to resolve/lose).
- `fss outdated` prefers `npm outdated --json` when npm exists; falls back to
  registry queries via curl. npm/curl are native tooling, not third-party deps.
- `fss clean` only deletes dirs literally named `node_modules`, never follows
  symlinks, prompts unless `--yes`, `--dry-run` supported.
- www: zero-dependency static HTML/CSS in `apps/www/public`, `_headers` file
  with CSP + security headers. Deploy = upload directory, no build.
- CI/CD uses `npx wrangler` in a plain run step (no third-party actions).
  Secrets needed in repo: `CLOUDFLARE_API_TOKEN`, var `CLOUDFLARE_ACCOUNT_ID`.
- Exit codes (scan): 0 clean, 1 warnings, 2 critical findings, 3 usage error.

## Review

- CLI: 21/21 tests pass under macOS sh and dash (Debian /bin/sh equivalent);
  shellcheck-clean (`-s sh`). Live-verified: `outdated` against the real npm
  registry (detects outdated + scoped packages), `scan` against `tmp/ex2`
  (true positive on its own signature strings) and against generated
  infected/clean fixtures.
- One real bug found and fixed during testing: `die` inside
  `$(resolve_dir ...)` only exited the subshell — callers now
  `|| return 3`. scan.sh also refactored mid-build to the temp-file +
  main-shell-read pattern so finding counters survive (POSIX pipelines run
  `while` in subshells).
- www deployed: https://coody-fss-www-prd-01.pages.dev — HTTP 200, CSP +
  full security-header set verified via curl, headline exact.
- Pages project `coody-fss-www-prd-01` created in Coody account.
- CI/CD live: org-level secrets CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID
  already existed on coodyapp — first CI run green after SC2015 fix, deploy
  workflow green including the idempotent "Ensure custom domain" step.
- Custom domain fss.coody.app: attached to the Pages project by the
  workflow ✔. CNAME creation failed — org token lacks Zone DNS:Edit
  (API error 10000). ONE remaining user step: grant the token
  Zone DNS:Edit on coody.app and re-run deploy (workflow self-heals), or
  add the proxied CNAME fss → coody-fss-www-prd-01.pages.dev in dashboard.

## Lessons

- POSIX sh: `while` in a pipeline = subshell = lost state. Design loops
  around `done < file` redirection from the start.
- `die`-style helpers are inert inside command substitution; check the
  substitution's exit status at every call site.
- Generate malicious-looking test fixtures at runtime instead of committing
  them — keeps the repo clean for GitHub scanning and other people's
  security tooling (including our own self-scan in CI).
