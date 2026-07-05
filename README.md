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

## Install

```sh
curl -fsSL https://fss.coody.app/install.sh | sh
```

Installs to `~/.fss` and symlinks `fss` into `~/.local/bin` — no root, no
dependencies. (Read [install.sh](install.sh) first if you like; it's short.)

Or run straight from a clone:

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

## Monorepo layout

```
fss/
├── apps/
│   ├── cli/          # the fss shell CLI (POSIX sh)
│   │   ├── bin/fss   # entry point / dispatcher
│   │   ├── lib/      # scan.sh, clean.sh, outdated.sh, common.sh
│   │   └── test/     # self-contained test suite (fixtures generated at runtime)
│   └── www/          # fss.coody.app — Vite + React + Tailwind + shadcn/ui,
│                     # served by a Cloudflare Worker (static assets)
├── docs/             # CLI reference, www notes, deployment guide
├── install.sh        # curl | sh installer (served at fss.coody.app/install.sh)
└── .github/workflows # ci-cli, ci-www, cd-www, release
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
pnpm test         # or: sh apps/cli/test/run-tests.sh
pnpm scan         # dogfood: fss scans this repo

pnpm install              # www workspace
pnpm --filter www dev     # local dev server for fss.coody.app
```

CI runs shellcheck, the test suite under both `dash` (Debian `/bin/sh`) and
`bash` (macOS), and a self-scan on every push; the www app is linted,
typechecked, and built on every push. Pushes to `main` that touch
`apps/www/` or `install.sh` deploy the Cloudflare Worker automatically
([docs/deployment.md](docs/deployment.md)).

## Docs

- [CLI reference](docs/cli.md)
- [Web app](docs/www.md)
- [Deployment & CI/CD](docs/deployment.md)

## License

MIT © [Coody](https://coody.app)
