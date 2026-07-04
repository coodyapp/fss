# fss CLI reference

`fss` is a POSIX shell CLI. It runs on macOS (`/bin/sh`, bash) and
Debian-based Linux (`dash`). No dependencies beyond standard Unix tools:
`sh`, `grep`, `find`, `du`, and `curl` or `wget` for registry lookups.
`node` is used opportunistically for robust JSON parsing when present, with
an `awk` fallback otherwise.

```
Usage: fss <command> [dir] [options]

Commands:
  scan [dir]                Scan for security issues and supply-chain IOCs
  clean [dir] [--dry-run] [--yes]
                            Find and safely delete node_modules directories
  outdated [dir]            Check dependency versions against the npm registry

Options:
  -h, --help                Show help
  -v, --version             Show version

Environment:
  NO_COLOR=1                Disable colored output
  FSS_OFFLINE=1             Skip registry lookups in 'outdated'
```

## fss scan

Scans a directory (default: `.`) in seven check groups. Patterns are derived
from public IOC lists of real npm supply-chain incidents: the Shai-Hulud worm
(Sept 2025), Scavenger / CVE-2025-54313 (July 2025), the September 2025
wallet-hijack compromise of foundational packages, and the TanStack attack /
CVE-2026-45321 (May 2026).

| # | Check | Severity | What it looks for |
|---|---|---|---|
| 1 | Lifecycle scripts | critical | `preinstall`/`install`/`postinstall`/`prepare` scripts that pipe curl/wget to a shell, run `node -e`/`python -c`, decode base64, call `npm token`/`npm publish`, or write to shell rc / `.npmrc` |
| 2 | Known malicious files | critical | File names dropped by known payloads: `bun_environment.js`, `setup_bun.js`, Scavenger DLL/SO names, etc. |
| 3 | Code signatures | critical / warning | Obfuscated eval (`eval(atob(...))`, base64 `Function` constructors), wallet-hijack markers (`stealthProxyControl`, `checkethereumw`), phishing/C2 domains. Warning-level heuristics (env serialization, XHR prototype hooking, IMDS endpoints) apply to first-party code only — `node_modules` is excluded from heuristics to avoid false positives from cloud SDKs |
| 4 | Credential exposure | critical / warning | `_authToken`/`_password` in a project `.npmrc`; `.env` files tracked in git |
| 5 | Registry + lockfile | critical / warning | Non-default registry in `.npmrc`; typosquat/shortener/C2 domains inside lockfiles; `node_modules` present without any lockfile |
| 6 | Binaries in node_modules | critical | `.dll` / `.exe` files (Scavenger dropped fake `node-gyp.dll` and friends) |
| 7 | Host persistence | critical | Dead-man's-switch artefacts (`gh-token-monitor`), suspicious launchd plists, crontab entries, shell-rc references |

**Exit codes:** `0` clean · `1` warnings only · `2` critical findings · `3` usage/tool error.

CI usage:

```yaml
- name: Supply-chain scan
  run: HOME="$(mktemp -d)" apps/cli/bin/fss scan .
```

(Hermetic `HOME` keeps runner dotfiles out of the results.)

### Extending indicators

All indicator sets live at the top of `apps/cli/lib/scan.sh` as plain
`grep -E` patterns (`IOC_FILE_NAMES`, `SIG_CRITICAL`, `SIG_LIFECYCLE`,
`SIG_BAD_DOMAINS`, `SIG_PERSIST`). Add new IOCs there — one source of truth,
no external database to fetch or verify.

## fss clean

Finds every `node_modules` directory under `dir` (default: `.`), prints each
with its size and the total, then asks for confirmation before deleting.

```console
$ fss clean ~/projects
  120.4 MB  /Users/me/projects/api/node_modules
  310.9 MB  /Users/me/projects/web/node_modules

  2 directories, 431.3 MB total

  Delete these directories? [y/N]
```

Safety rules:

- only directories **literally named** `node_modules` are deleted — verified
  again immediately before each `rm`
- symlinks are listed but never followed or deleted
- nested `node_modules` are pruned from the list (the parent delete covers them)
- refuses to run on `/` or `$HOME` directly
- `--dry-run` never deletes; `--yes` skips the prompt (for scripts)

## fss outdated

Reads `dependencies` + `devDependencies` from `package.json`, resolves the
installed version from `node_modules/<pkg>/package.json`, and queries
`registry.npmjs.org/<pkg>/latest` for the latest release.

```console
$ fss outdated .
  PACKAGE       SPEC     INSTALLED   LATEST   STATUS
  left-pad      ^1.0.0   1.0.0       1.3.0    outdated
  @babel/core   ^7.0.0   7.26.0      8.0.1    MAJOR
```

- `MAJOR` (red): major version drift — likely breaking upgrade, but also the
  place where security fixes stop landing
- `outdated` (yellow): newer minor/patch available
- `not installed`: declared but absent from `node_modules`
- `unknown`: registry unreachable (or `FSS_OFFLINE=1`)

**Exit codes:** `0` all current · `1` outdated found · `3` error.

## Tests

```sh
sh apps/cli/test/run-tests.sh
```

Fixtures (including malicious-looking bait for the scanner) are generated in
a temp directory at runtime and never committed, so the repository itself
stays clean for other security tooling. Tests run with a hermetic `HOME`.
