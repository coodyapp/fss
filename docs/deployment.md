# Deployment & CI/CD

## Overview

| | |
|---|---|
| Host (site) | Cloudflare Pages, project `coody-fss-www-prd-01` |
| Host (installer) | Cloudflare Worker `coody-fss-prd-01` (`apps/worker`) |
| Account | Coody (`51a60f4777316c6bfd6b773b58a494e8`) |
| Production URL | https://fss.coody.app |
| Deployed directory | `apps/www/dist` (Vite build) |

The site is a Pages project with `fss.coody.app` as its custom domain.

The installer Worker, **`coody-fss-prd-01`**, serves only
`https://fss.coody.app/install.sh`: it proxies
`raw.githubusercontent.com/coodyapp/fss/main/install.sh` (edge-cached 300s)
via a zone Route (`fss.coody.app/install.sh` on zone `coody.app`). Worker
Routes take precedence over the Pages custom domain, so this single path is
answered by the Worker and everything else by Pages. Same pattern as sak's
`coody-sak-prd-01` (`coody.app/install.sh`). See `apps/worker/README.md`.

## CI/CD workflows

### `.github/workflows/ci-cli.yaml`

Runs on pushes to `main`, pull requests, and manual dispatch:

1. `dash -n` + `bash -n` syntax check on all shell files, including the
   repo-root `install.sh` (dash is Debian's `/bin/sh`; bash covers macOS)
2. `shellcheck -s sh` on the CLI and `install.sh`
3. Test suite under **dash** and under **bash**
4. Self-scan: `fss scan .` against the repo with a hermetic `HOME`
   (the build fails if the repo itself ever trips the scanner)

### `.github/workflows/ci-www.yaml`

Runs on pushes to `main` and non-draft pull requests: `pnpm install
--frozen-lockfile`, then lint, typecheck, and build of `apps/www`.

### `.github/workflows/cd-www.yaml`

Runs on `v*.*.*` tags and manual `workflow_dispatch`. Builds the site with
`pnpm --filter www build`, then deploys `apps/www/dist` to the Pages project
via `pnpm deploy:www` (plain `pnpm dlx wrangler@4 pages deploy`, same
command as local deploys — `cloudflare/wrangler-action` cannot install
wrangler in this pnpm workspace: its npm path corrupts `node_modules` and
its pnpm path trips `ERR_PNPM_IGNORED_BUILDS`). Targets the `prd`
environment (https://fss.coody.app).

### `.github/workflows/ci-worker.yaml`

Runs on pushes to `main`, non-draft pull requests, and manual dispatch when
`apps/worker/**` changes: `pnpm install --frozen-lockfile`, then
`wrangler deploy --dry-run` to validate the bundle and config.

### `.github/workflows/cd-worker.yaml`

Runs on pushes to `main` touching `apps/worker/**` (plus manual
`workflow_dispatch`). Deploys `coody-fss-prd-01` with
`pnpm dlx wrangler@4 deploy` in `apps/worker`. Serializes in the
`cd-worker` concurrency group, targets the `prd` environment. Note that
`install.sh` content changes do **not** need this workflow — the Worker
fetches the script from GitHub `main` at request time.

### `.github/workflows/release.yml`

Runs on `v*.*.*` tags: verifies the tag matches `FSS_VERSION` in
`apps/cli/lib/common.sh`, then creates a GitHub release with generated
notes.

## Required settings

Already provisioned as **organization-level** secrets on `coodyapp`
(available to all repos):

| Secret | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API token with **Workers Scripts: Edit** (deploy + custom domain) |
| `CLOUDFLARE_ACCOUNT_ID` | `51a60f4777316c6bfd6b773b58a494e8` |

## Manual deploy

```sh
pnpm install
pnpm build:www      # pnpm --filter www build
pnpm deploy:www     # wrangler pages deploy apps/www/dist → coody-fss-www-prd-01
pnpm deploy:worker  # pnpm dlx wrangler@4 deploy --cwd apps/worker (installer proxy)
```

## Rollback

Pages keeps prior deployments: dashboard → Workers & Pages →
coody-fss-www-prd-01 → Deployments → rollback, or redeploy any earlier
commit. The installer Worker keeps prior versions too (`wrangler rollback`
in `apps/worker`).
