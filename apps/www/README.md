# fss.coody.app

A Vite + React + Tailwind + [shadcn/ui](https://ui.shadcn.com) site, served as
static assets by its own Cloudflare Worker, **`coody-fss-www-prd-01`**, via
[Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/).

The version badge on the page is read at build time from `FSS_VERSION` in
`apps/cli/lib/common.sh` — the CLI is the single source of truth.

The build also copies the repo-root `install.sh` into `dist/`, so
`curl -fsSL https://fss.coody.app/install.sh | sh` serves the installer from
the same Worker.

## Develop

```sh
pnpm install
pnpm --filter www dev        # local dev server
pnpm --filter www lint
pnpm --filter www typecheck
pnpm --filter www build      # tsc -b && vite build → dist/
```

## Deploy

Automatic via `.github/workflows/cd-www.yaml` on pushes to `main`, or
manually from the repo root:

```sh
pnpm build:www && pnpm deploy:www
```

`wrangler.toml` declares the custom domain (`fss.coody.app`,
`custom_domain = true`), so Cloudflare provisions DNS and the certificate on
deploy — no manual DNS records.
