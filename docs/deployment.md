# Deployment & CI/CD

## Overview

| | |
|---|---|
| Host | Cloudflare Workers (Static Assets) |
| Account | Coody (`51a60f4777316c6bfd6b773b58a494e8`) |
| Worker | `coody-fss-www-prd-01` |
| Production URL | https://fss.coody.app |
| Deployed directory | `apps/www/dist` (Vite build) |

`apps/www/wrangler.toml` declares the custom domain:

```toml
[[routes]]
pattern = "fss.coody.app"
custom_domain = true

[assets]
directory = "./dist"
```

With `custom_domain = true`, Cloudflare provisions the DNS record and TLS
certificate automatically on `wrangler deploy` — no manual DNS management.
The `coody.app` zone lives in the same account, so the domain validates
immediately.

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

Runs on pushes to `main` touching `apps/www/**`, `install.sh`,
`apps/cli/lib/common.sh` (version source), or the lockfile — plus manual
`workflow_dispatch`. Builds the site with pnpm, then deploys with
[`cloudflare/wrangler-action`](https://github.com/cloudflare/wrangler-action)
(`command: deploy`, `workingDirectory: apps/www`). Deploys serialize in
the `cd-www` concurrency group and target the `prd` environment
(https://fss.coody.app).

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
pnpm deploy:www     # pnpm dlx wrangler@4 deploy --cwd apps/www
```

## History: Pages → Worker

v1 of the site was a zero-build static page on Cloudflare **Pages**
(same project name). It was replaced by this Worker because Pages custom
domains required a separate `Zone DNS: Edit` token permission to create
the CNAME, while a Worker with `custom_domain = true` provisions DNS
itself with only Workers permissions. The old Pages project must be
deleted (its DNS records block the Worker's custom-domain claim —
Cloudflare API error 100117).

## Rollback

Workers keeps prior versions. Roll back from the dashboard
(Workers & Pages → coody-fss-www-prd-01 → Deployments) or with
`wrangler rollback`, or redeploy any earlier commit.
