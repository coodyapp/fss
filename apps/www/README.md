# fss.coody.app

A Vite + React + Tailwind + [shadcn/ui](https://ui.shadcn.com) site, served
by Cloudflare Pages, project **`coody-fss-www-prd-01`**.

The version badge on the page is read at build time from `FSS_VERSION` in
`apps/cli/lib/common.sh` — the CLI is the single source of truth.

The build also copies the repo-root `install.sh` into `dist/` as a fallback;
in production `https://fss.coody.app/install.sh` is answered by the
`coody-fss-prd-01` Worker (see `apps/worker/`), whose zone Route takes
precedence over the Pages custom domain for that one path.

## Develop

```sh
pnpm install
pnpm --filter www dev        # local dev server
pnpm --filter www lint
pnpm --filter www typecheck
pnpm --filter www build      # tsc -b && vite build → dist/
```

## Deploy

Automatic via `.github/workflows/cd-www.yaml` on `v*.*.*` tags (or manual
`workflow_dispatch`), or manually from the repo root:

```sh
pnpm build:www && pnpm deploy:www
```

The Pages project owns the `fss.coody.app` custom domain; DNS and TLS are
managed by Cloudflare Pages.
