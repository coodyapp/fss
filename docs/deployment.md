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
`workflow_dispatch`). Two steps:

1. `npx --yes wrangler@4 pages deploy apps/www/public --project-name coody-fss-www-prd-01`
2. **Ensure custom domain** — idempotently attaches `fss.coody.app` to the
   Pages project and creates the proxied CNAME
   (`fss.coody.app → coody-fss-www-prd-01.pages.dev`) in the `coody.app`
   zone. "Already exists" is success; missing token permissions produce a
   workflow warning instead of a failed deploy.

Deploys are serialized with a `concurrency` group; both workflows run with
`permissions: contents: read` and interpolate no untrusted event data.

## Required settings

Already provisioned as **organization-level** secrets on `coodyapp`
(available to all repos):

| Secret | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API token with **Cloudflare Pages: Edit** (deploy + domain attach) and **Zone DNS: Edit** on `coody.app` (CNAME creation) |
| `CLOUDFLARE_ACCOUNT_ID` | `51a60f4777316c6bfd6b773b58a494e8` |

## Initial provisioning (already done, kept for reference)

```sh
export CLOUDFLARE_ACCOUNT_ID=51a60f4777316c6bfd6b773b58a494e8

# 1. Create the Pages project
npx wrangler pages project create coody-fss-www-prd-01 --production-branch=main

# 2. First deploy
npx wrangler pages deploy apps/www/public --project-name coody-fss-www-prd-01

# 3. Custom domain — handled by the "Ensure custom domain" step in
#    deploy-www.yml on every deploy (idempotent). Equivalent API calls:
#    POST /accounts/{account_id}/pages/projects/coody-fss-www-prd-01/domains
#      { "name": "fss.coody.app" }
#    POST /zones/{zone_id}/dns_records
#      { "type": "CNAME", "name": "fss.coody.app",
#        "content": "coody-fss-www-prd-01.pages.dev", "proxied": true }
```

The `coody.app` zone lives in the same Cloudflare account, so the custom
domain validates automatically once the CNAME record exists.

## Rollback

Cloudflare Pages keeps every deployment. Roll back from the dashboard
(Pages → coody-fss-www-prd-01 → Deployments → Rollback) or redeploy any
earlier commit with `wrangler pages deploy`.
