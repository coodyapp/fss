# Deployment & CI/CD

## Overview

| | |
|---|---|
| Host | Cloudflare Pages |
| Account | Coody (`51a60f4777316c6bfd6b773b58a494e8`) |
| Project | `coody-fss-www-prd-01` |
| Production URL | https://fss.coody.app |
| Pages URL | https://coody-fss-www-prd-01.pages.dev |
| Deployed directory | `apps/www/public` (no build step) |

## CI/CD workflows

### `.github/workflows/ci.yml`

Runs on every push and pull request:

1. `dash -n` + `bash -n` syntax check on all shell files (dash is Debian's
   `/bin/sh`; bash covers macOS)
2. `shellcheck -s sh` on the whole CLI
3. Test suite under **dash** and under **bash**
4. Self-scan: `fss scan .` against the repo with a hermetic `HOME`
   (the build fails if the repo itself ever trips the scanner)

### `.github/workflows/deploy-www.yml`

Runs on pushes to `main` that touch `apps/www/**` (plus manual
`workflow_dispatch`). Single step:

```sh
npx --yes wrangler@4 pages deploy apps/www/public --project-name coody-fss-www-prd-01
```

Deploys are serialized with a `concurrency` group; both workflows run with
`permissions: contents: read` and interpolate no untrusted event data.

## Required repository settings

Configure once in GitHub → repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API token with **Cloudflare Pages: Edit** permission, scoped to the Coody account. Create at dash.cloudflare.com → My Profile → API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | `51a60f4777316c6bfd6b773b58a494e8` |

## Initial provisioning (already done, kept for reference)

```sh
export CLOUDFLARE_ACCOUNT_ID=51a60f4777316c6bfd6b773b58a494e8

# 1. Create the Pages project
npx wrangler pages project create coody-fss-www-prd-01 --production-branch=main

# 2. First deploy
npx wrangler pages deploy apps/www/public --project-name coody-fss-www-prd-01

# 3. Custom domain (Pages project → Custom domains)
#    fss.coody.app → CNAME → coody-fss-www-prd-01.pages.dev
#    Added via dashboard or API:
#    POST /accounts/{account_id}/pages/projects/coody-fss-www-prd-01/domains
#    { "name": "fss.coody.app" }
```

The `coody.app` zone lives in the same Cloudflare account, so the custom
domain validates automatically once the CNAME record exists.

## Rollback

Cloudflare Pages keeps every deployment. Roll back from the dashboard
(Pages → coody-fss-www-prd-01 → Deployments → Rollback) or redeploy any
earlier commit with `wrangler pages deploy`.
