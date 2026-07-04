# apps/www — fss.coody.app

Static landing page for FSS. Headline: **"A Fast Security Scan for
developers."**

## Design constraints

The site practices what the CLI preaches:

- **Zero JavaScript.** Nothing to execute, nothing to compromise.
- **Zero build step.** `apps/www/public/` is deployed byte-for-byte. No
  bundler, no framework, no npm dependencies — the www workspace's only
  script is the deploy command.
- **No external assets.** System font stack, inline SVG favicon (data URI).
  Every request stays on the origin.
- **Strict security headers** via Cloudflare Pages' `_headers` file:
  `default-src 'none'` CSP (only self-hosted styles and images allowed),
  `nosniff`, `DENY` framing, HSTS, COOP/CORP.

## Files

```
apps/www/
├── package.json      # name + deploy script only
└── public/
    ├── index.html    # single-page: hero, terminal demo, commands, why
    ├── styles.css    # dark terminal theme, responsive grid
    ├── 404.html
    └── _headers      # Cloudflare Pages security headers
```

## Local preview

Any static file server works:

```sh
cd apps/www/public && python3 -m http.server 8080
# or, with headers applied like production:
npx wrangler pages dev apps/www/public
```

## Deploy

Automatic on push to `main` touching `apps/www/**` (see
[deployment.md](deployment.md)), or manually:

```sh
npm run deploy:www
# = npx wrangler pages deploy apps/www/public --project-name coody-fss-www-prd-01
```
