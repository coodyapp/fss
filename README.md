# A Fast Security Scan for developers.

**FSS** scans Node.js projects for security issues and supply-chain attack
indicators, cleans `node_modules` safely, and flags outdated dependencies —
with a single POSIX shell script, zero dependencies, on macOS and
Debian-based Linux.

🌐 **[fss.coody.app](https://fss.coody.app)**

```console
$ apps/cli/bin/fss scan .

1/7  Lifecycle scripts (install-time execution)
  ✖  suspicious lifecycle script: node_modules/evil-pkg/package.json
2/7  Known malicious files (IOC name match)
  ✔  no known payload file names found
...
Summary
  1 critical, 0 warning(s) — investigate before installing or running anything.
```

## Why

The npm ecosystem was hit by a series of supply-chain attacks in 2025–2026
(Shai-Hulud worm, Scavenger, the September 2025 wallet hijack, the TanStack
compromise). The common thread: malicious code executes **at install time**,
before any audit tool you `npm install` has a chance to run.

FSS takes the opposite approach — the scanner itself adds nothing to your
supply chain. It's readable shell, using only tools already on your machine:
`sh`, `grep`, `find`, `curl`/`wget`.

## Quick start

```sh
git clone https://github.com/coodyapp/fss.git
cd fss

# scan a project for security issues + supply-chain IOCs
apps/cli/bin/fss scan ~/projects/my-app

# preview node_modules cleanup, then actually delete
apps/cli/bin/fss clean ~/projects --dry-run
apps/cli/bin/fss clean ~/projects --yes

# check dependency freshness against the npm registry
apps/cli/bin/fss outdated ~/projects/my-app
```

Optional: put it on your PATH.

```sh
ln -s "$PWD/apps/cli/bin/fss" /usr/local/bin/fss
```

## Monorepo layout

```
fss/
├── apps/
│   ├── cli/          # the fss shell CLI (POSIX sh)
│   │   ├── bin/fss   # entry point / dispatcher
│   │   ├── lib/      # scan.sh, clean.sh, outdated.sh, common.sh
│   │   └── test/     # self-contained test suite (fixtures generated at runtime)
│   └── www/          # fss.coody.app — static site, zero JS, strict CSP
│       └── public/   # deployed as-is to Cloudflare Pages
├── docs/             # CLI reference, www notes, deployment guide
└── .github/workflows # ci.yml (lint+test), deploy-www.yml (Cloudflare Pages)
```

## Commands

| Command | What it does | Exit codes |
|---|---|---|
| `fss scan [dir]` | 7 check groups: lifecycle scripts, known payload files, malware code signatures, credential exposure, registry/lockfile integrity, rogue binaries, host persistence | 0 clean · 1 warnings · 2 critical · 3 error |
| `fss clean [dir] [--dry-run] [--yes]` | Finds `node_modules` dirs with sizes, deletes after confirmation. Never follows symlinks. | 0 ok · 3 error |
| `fss outdated [dir]` | Installed vs latest registry versions, highlights major drift | 0 current · 1 outdated · 3 error |

Full reference: [docs/cli.md](docs/cli.md)

## Development

```sh
npm test          # or: sh apps/cli/test/run-tests.sh
npm run scan      # dogfood: fss scans this repo
```

CI runs shellcheck, the test suite under both `dash` (Debian `/bin/sh`) and
`bash` (macOS), and a self-scan on every push. Pushes to `main` that touch
`apps/www/` deploy to Cloudflare Pages automatically
([docs/deployment.md](docs/deployment.md)).

## Docs

- [CLI reference](docs/cli.md)
- [Web app](docs/www.md)
- [Deployment & CI/CD](docs/deployment.md)

## License

MIT © [Coody](https://coody.app)
