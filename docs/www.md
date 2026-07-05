# apps/www — fss.coody.app

Landing page for FSS. Headline: **"A Fast Security Scan for
developers."**

## Stack

Vite + React + TypeScript + Tailwind CSS 4 +
[shadcn/ui](https://ui.shadcn.com), following the Coody house style. The
build output (`dist/`) is served as static assets by a dedicated
Cloudflare **Worker**, `coody-fss-www-prd-01`, via
[Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)
— there is no server-side code, only assets.

Two build-time integrations keep the CLI as the single source of truth:

- **Version badge** — `vite.config.ts` reads `FSS_VERSION` from
  `apps/cli/lib/common.sh` and injects it as
  `import.meta.env.VITE_FSS_VERSION`.
- **Installer** — the repo-root `install.sh` is copied into `dist/` at
  build time, so `curl -fsSL https://fss.coody.app/install.sh | sh`
  serves the installer from the same Worker.

## Files

```
apps/www/
├── wrangler.toml        # Worker name, custom domain, [assets] dist/
├── vite.config.ts       # version injection + install.sh copy plugin
├── index.html           # meta tags, title
└── src/
    ├── App.tsx          # hero, install command, usage terminals
    ├── components/      # terminal, site-footer, theme-provider, ui/
    ├── index.css        # Tailwind theme (CRT/terminal look)
    └── main.tsx
```

## Develop

```sh
pnpm install
pnpm --filter www dev        # local dev server
pnpm --filter www lint
pnpm --filter www typecheck
pnpm --filter www build      # tsc -b && vite build → dist/
```

## Deploy

Automatic on push to `main` touching `apps/www/**`, `install.sh`, or the
CLI version (see [deployment.md](deployment.md)), or manually from the
repo root:

```sh
pnpm build:www && pnpm deploy:www
```
