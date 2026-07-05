# Task: coody-fss-prd-01 Worker (installer proxy, like coody-sak-prd-01)

Serve `https://fss.coody.app/install.sh` from a dedicated Worker that proxies
GitHub raw `coodyapp/fss/main/install.sh` — same pattern as sak's
`coody-sak-prd-01` (`coody.app/install.sh`). A zone Route takes precedence
over the Pages project currently squatting `fss.coody.app`, so the installer
goes live immediately, before the Pages delete unblocks the www Worker.

## Plan

- [x] Inspect sak worker (`sak/apps/worker`) + its CI/CD workflows
- [x] Inspect fss current state (www worker ships install.sh as static asset; live fss.coody.app is old Pages, /install.sh 404)
- [x] Create `apps/worker/` — wrangler.toml (route `fss.coody.app/install.sh`, zone `coody.app`), worker.js, package.json, README.md
- [x] Add `.github/workflows/ci-worker.yaml` (dry-run validate) + `cd-worker.yaml` (deploy on main push touching apps/worker)
- [x] Root package.json: `deploy:worker` script
- [x] Docs: deployment.md + README monorepo layout
- [x] `wrangler deploy` → verify `curl -sI https://fss.coody.app/install.sh` → 200 text/x-shellscript
- [x] Installer smoke test via new route

## Review

- Worker `coody-fss-prd-01` deployed (version 09490d00), route
  `fss.coody.app/install.sh` live: HTTP 200, `text/x-shellscript`,
  content byte-identical to repo `install.sh`. Site root (Pages) untouched.
- Smoke test exposed two latent CLI bugs (pre-existing, not Worker-related);
  both fixed locally, lint + 21/21 tests pass:
  1. `install.sh`: mktemp workdir `fss-install.XXXXXX` matched the
     `find -name 'fss-*'` glob used to locate the extracted tarball → SRC
     resolved to the workdir itself → "unexpected archive layout" on every
     `curl | sh` run. Renamed template to `fss_install.XXXXXX`.
  2. `apps/cli/bin/fss`: FSS_HOME derived from `dirname $0` without resolving
     the `~/.local/bin/fss` symlink → `lib/common.sh: No such file`. Added
     POSIX symlink-resolution loop; verified via absolute + relative symlinks.
- Live `curl | sh` still serves the pre-fix script until these changes are
  pushed to `main` (Worker proxies GitHub raw main).

## Lessons

- Local `Bash` tool pipes binary data through rtk; use `rtk proxy sh -c '...'`
  for tarball/binary pipelines.

---

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

## Phase 2 — rebuild on SAK examples (tmp/www, tmp/workflows, tmp/worker)

User provided sibling-project (SAK) examples in `tmp/`; rebuilt to match
the Coody house style.

- [x] apps/www rebuilt: Vite + React + TS + Tailwind 4 + shadcn/ui from
  tmp/www template; headline unchanged; FSS ASCII logo; install command +
  usage terminals; version badge read at build time from
  `FSS_VERSION` in apps/cli/lib/common.sh (vite define)
- [x] Cloudflare architecture: Pages → **Worker Static Assets**
  (`wrangler.toml`: name coody-fss-www-prd-01, `[[routes]]`
  fss.coody.app `custom_domain = true`, `[assets] dist/`) — Worker
  provisions DNS/cert itself, removing the Zone DNS:Edit blocker
- [x] `install.sh` (repo root): POSIX installer → ~/.fss + ~/.local/bin
  symlink; shipped into dist/ by a vite plugin, served at
  fss.coody.app/install.sh
- [x] pnpm workspace (pnpm-workspace.yaml + committed pnpm-lock.yaml)
- [x] Workflows split per app: ci-cli.yaml, ci-www.yaml, cd-www.yaml
  (wrangler-action@v3), release.yml (tag ↔ FSS_VERSION check); old
  ci.yml + deploy-www.yml deleted
- [x] Verify: lint OK, typecheck OK, shellcheck OK (incl. install.sh),
  21/21 tests, www build OK (dist/ contains install.sh)
- [x] Worker deployed (assets uploaded)
- [ ] **BLOCKED (needs user):** fss.coody.app custom-domain claim fails —
  CF API 409, error 100117: hostname already has DNS records, created by
  the old v1 Pages deployment (old static site is live there). Fix:
  delete Pages project `coody-fss-www-prd-01`
  (`npx wrangler@4 pages project delete coody-fss-www-prd-01`) then
  re-run deploy. Deleting a live production project was denied to the
  agent in auto mode — user must run/approve it.
- [x] Docs updated: docs/www.md, docs/deployment.md, README.md
- [x] Commit + push; monitor ci-cli / ci-www / cd-www

## Lessons

- POSIX sh: `while` in a pipeline = subshell = lost state. Design loops
  around `done < file` redirection from the start.
- `die`-style helpers are inert inside command substitution; check the
  substitution's exit status at every call site.
- Generate malicious-looking test fixtures at runtime instead of committing
  them — keeps the repo clean for GitHub scanning and other people's
  security tooling (including our own self-scan in CI).
- `devEngines.packageManager: pnpm` makes bare `npx` fail with
  EBADDEVENGINES — use `pnpm dlx` in scripts instead.
- Workers custom domains refuse hostnames with pre-existing DNS records
  (API error 100117) — migrating Pages → Worker on the same hostname
  requires deleting the Pages custom domain/records first.
