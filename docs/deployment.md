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

## Agent readiness

Most of it ships with the site, from `apps/www/public/` (see
[www.md](www.md#agent-readiness)): `robots.txt` (RFC 9309 groups, explicit AI
crawler entries, `Content-Signal`), `sitemap.xml` (generated at build time),
`llms.txt`, and `_headers` (RFC 8288 `Link` headers on `/`). Those need no
Cloudflare configuration — deploy and they are live.

Two items are zone-level and are **not** in this repo.

### Markdown for Agents (manual, one-off)

Serves a Markdown rendering of the page to clients that send
`Accept: text/markdown`. It is a Cloudflare zone setting on `coody.app`, needs
a **Pro or Business** plan, and an API token with **Zone Settings: Edit** —
the CI token only has Workers/Pages scopes, so this cannot be automated from
here. Dashboard equivalent: zone → **AI Crawl Control** → enable **Markdown
for Agents**.

```sh
export CF_TOKEN=...   # Zone Settings: Edit + Zone: Read on coody.app
ZONE_ID=$(curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=coody.app" \
  | jq -r '.result[0].id')

# Whole zone (coody.app and every subdomain):
curl -X PATCH \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/content_converter" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"value":"on"}'
```

To scope it to `fss.coody.app` only, use a configuration rule instead. Note
that `PUT` on a phase entrypoint **replaces every rule in that phase** — `GET`
it first and merge, or you will silently drop existing configuration rules:

```sh
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/phases/http_config_settings/entrypoint"

curl -X PUT \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/phases/http_config_settings/entrypoint" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"rules":[{
    "expression": "http.host eq \"fss.coody.app\"",
    "action": "set_config",
    "action_parameters": { "content_converter": true },
    "description": "Markdown for Agents — fss.coody.app"
  }]}'
```

Verify:

```sh
curl -sI -H "Accept: text/markdown" https://fss.coody.app/ \
  | grep -iE 'content-type|x-markdown-tokens'
# want: content-type: text/markdown; charset=utf-8
```

### DNS-AID — deliberately not published

[DNS for AI Discovery](https://datatracker.ietf.org/doc/draft-mozleywilliams-dnsop-dnsaid/)
advertises agent endpoints via SVCB records under `_agents` (for example
`_index._agents.fss.coody.app`). FSS is a CLI: it exposes no agent, no MCP
server and no A2A endpoint, so there is nothing for such a record to resolve
to. Publishing one would point agents at a service that does not exist, so we
do not. Agent-readiness scanners will flag this as a miss; that is the
intended answer until FSS actually ships an agent surface, at which point
publish `_mcp._agents.fss.coody.app` SVCB records and sign the zone with
DNSSEC.

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
