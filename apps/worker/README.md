# Serving install.sh from fss.coody.app

This deploys a small Cloudflare Worker, **`coody-fss-prd-01`**, that
intercepts only `fss.coody.app/install.sh` and proxies it from this repo's
`main` branch on GitHub. It is independent of the `coody-fss-www-prd-01`
Pages project (which serves the https://fss.coody.app site) and only ever
attaches a Route on the single path above — the rest of the hostname is
untouched.

Because it is a zone **Route**, it takes precedence over the Pages custom
domain for that path, so the installer URL is always answered by this
Worker.

## Deploy

```bash
cd apps/worker
pnpm dlx wrangler@4 deploy   # creates/updates coody-fss-prd-01 and attaches the Route from wrangler.toml
```

Or from the repo root: `pnpm deploy:worker`.

`wrangler.toml` pins `account_id` to the `coody` Cloudflare account, so
`wrangler deploy` won't prompt you to pick an account.

## Verify

1. Cloudflare dashboard → Workers & Pages → `coody-fss-prd-01` → Triggers →
   confirm `fss.coody.app/install.sh` is listed under Routes.
2. `curl -sI https://fss.coody.app/install.sh` → expect `HTTP/2 200` and
   `content-type: text/x-shellscript`.
3. `curl -fsSL https://fss.coody.app/install.sh | sh` on macOS or a
   Debian-based machine.

## Updating install.sh

Because the Worker fetches `raw.githubusercontent.com/.../main/install.sh` on
every request (edge-cached 300s), pushing to `main` updates the live script
automatically. Re-run `wrangler deploy` only when `worker.js` or
`wrangler.toml` itself changes — CI does this via
`.github/workflows/cd-worker.yaml`.
