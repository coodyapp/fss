# shellcheck shell=sh disable=SC3043
# scan.sh — security + supply-chain scan for Node.js projects.
#
# Checks are grouped in numbered sections. Findings count as warnings or
# criticals; cmd_scan maps them to exit codes (0 clean / 1 warn / 2 crit).
#
# Pattern sources: public IOC lists from the 2025-2026 npm supply-chain
# attacks (Shai-Hulud worm, Scavenger/CVE-2025-54313, September 2025 wallet
# hijack, TanStack/CVE-2026-45321 dead-man's switch).
#
# Implementation note: hit lists are always written to a temp file and read
# back with `while read ... done < file` in the main shell — piping into
# `while` would run it in a subshell and lose the finding counters.

# ── Indicator sets (single source of truth, greppable EREs) ──────────────────
# File names dropped by known payloads.
IOC_FILE_NAMES='bun_environment.js setup_bun.js opensearch_init.js vite_setup.mjs
node-gyp.dll loader.dll version.dll umpdc.dll profapi.dll
node-gyp.so loader.so version.so libumpdc.so libprofapi.so'

# Code signatures with near-zero false-positive rates (safe inside node_modules).
SIG_CRITICAL='eval[[:space:]]*\(.*atob[[:space:]]*\(|eval[[:space:]]*\(.*Buffer\.from\(.*base64|new Function\(.*atob|window\.stealthProxyControl|checkethereumw|runmask.*newdlocal|logDiskSpace|npmjs\.help|dieorsuffer\.com|smartscreen-api\.com|firebase\.su'

# Heuristics for first-party code only (too noisy for node_modules).
SIG_PROJECT_WARN='JSON\.stringify\(process\.env|XMLHttpRequest\.prototype\.(open|send)[[:space:]]*=|document\.cookie.*fetch\(|169\.254\.169\.254|metadata\.google\.internal|/computeMetadata/v1/'

# Suspicious lifecycle script contents (install-time code execution).
SIG_LIFECYCLE='curl[[:space:]].*\|[[:space:]]*(ba|z)?sh|wget[[:space:]].*\|[[:space:]]*(ba|z)?sh|node[[:space:]]+-e[[:space:]]|python[3]?[[:space:]]+-c[[:space:]]|base64[[:space:]]+(-d|--decode)|powershell|rundll32|regsvr32|npm[[:space:]]+token|npm[[:space:]]+publish|>>?[[:space:]]*~?/?\.((bash|zsh)rc|profile|npmrc)'

# Domains that should never appear in a lockfile (typosquats, shorteners, C2).
SIG_BAD_DOMAINS='npnjs\.com|npmjs\.help|npmjs\.support|npmjs\.security|nprnjs\.|npmj5\.|npm-js\.|firebase\.su|dieorsuffer\.com|smartscreen-api\.com|bit\.ly/|tinyurl\.com/|cutt\.ly/|is\.gd/'

# Dead-man's-switch / persistence artefacts (TanStack attack, May 2026).
SIG_PERSIST='gh-token-monitor|token-monitor\.sh'

# ── Helpers ───────────────────────────────────────────────────────────────────
# List JS-ish files under $1 (skipping .git), one per line.
find_js() {
  find "$1" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' \) \
    -not -path '*/.git/*' 2>/dev/null
}

# Read file paths on stdin, print "path: first-match" for files matching ERE $1.
grep_files() {
  local f match
  while IFS= read -r f; do
    match="$(grep -E -m 1 -o "$1" "$f" 2>/dev/null | head -n 1)"
    [ -n "$match" ] && printf '%s: %s\n' "$f" "$match"
  done
}

# Report every line of $1 (a hit-list file) at severity $2 with prefix $3.
# Runs in the main shell so counters and FOUND survive.
report_hits() {
  local file="$1" sev="$2" prefix="$3" line
  [ -s "$file" ] || return 0
  while IFS= read -r line; do
    "$sev" "$prefix: $line"
  done < "$file"
  FOUND=1
}

# ── Sections ──────────────────────────────────────────────────────────────────
scan_lifecycle_scripts() {
  hdr "1/7  Lifecycle scripts (install-time execution)"
  local root="$1" pkg
  FOUND=0

  find "$root" -name package.json -not -path '*/.git/*' 2>/dev/null > "$TMP/pkgs"
  : > "$TMP/hits"
  while IFS= read -r pkg; do
    if grep -E '"(preinstall|install|postinstall|prepare)"[[:space:]]*:' "$pkg" 2>/dev/null |
       grep -qE "$SIG_LIFECYCLE"; then
      printf '%s\n' "$pkg" >> "$TMP/hits"
    fi
  done < "$TMP/pkgs"

  report_hits "$TMP/hits" crit "suspicious lifecycle script"
  [ "$FOUND" -eq 0 ] && ok "no suspicious lifecycle scripts"
}

scan_ioc_files() {
  hdr "2/7  Known malicious files (IOC name match)"
  local root="$1" name
  FOUND=0

  : > "$TMP/hits"
  for name in $IOC_FILE_NAMES; do
    find "$root" -type f -name "$name" -not -path '*/.git/*' 2>/dev/null >> "$TMP/hits"
  done

  report_hits "$TMP/hits" crit "known payload file name"
  [ "$FOUND" -eq 0 ] && ok "no known payload file names found"
}

scan_code_signatures() {
  hdr "3/7  Malicious code signatures"
  local root="$1"
  FOUND=0

  find_js "$root" > "$TMP/js"
  grep_files "$SIG_CRITICAL" < "$TMP/js" > "$TMP/hits"
  report_hits "$TMP/hits" crit "malware signature"

  # Heuristics apply to first-party code only (node_modules is too noisy).
  grep -v '/node_modules/' "$TMP/js" | grep_files "$SIG_PROJECT_WARN" > "$TMP/hits"
  report_hits "$TMP/hits" warn "suspicious pattern in project code"

  [ "$FOUND" -eq 0 ] && ok "no malicious code signatures"
}

scan_credentials() {
  hdr "4/7  Credential exposure"
  local root="$1" f
  FOUND=0

  find "$root" -name .npmrc -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null > "$TMP/npmrcs"
  : > "$TMP/hits"
  while IFS= read -r f; do
    grep -qE '_authToken|_password' "$f" 2>/dev/null && printf '%s\n' "$f" >> "$TMP/hits"
  done < "$TMP/npmrcs"
  report_hits "$TMP/hits" crit "npm credential committed in project .npmrc"

  if [ -d "$root/.git" ] && has git; then
    git -C "$root" ls-files '.env' '.env.*' '*/.env' '*/.env.*' 2>/dev/null |
      grep -v '\.example$' > "$TMP/hits" || true
    report_hits "$TMP/hits" warn ".env file tracked in git"
  fi

  [ "$FOUND" -eq 0 ] && ok "no exposed credentials"
}

scan_registry_and_lockfile() {
  hdr "5/7  Registry config + lockfile integrity"
  local root="$1" f reg
  FOUND=0

  for f in "$root/.npmrc" "$HOME/.npmrc"; do
    [ -f "$f" ] || continue
    reg="$(grep -E '^registry=' "$f" 2>/dev/null | head -n 1)"
    # Anchored: a lookalike like registry.npmjs.org.evil.example must not pass.
    if [ -n "$reg" ] &&
       ! printf '%s' "$reg" | grep -qE '^registry=https://registry\.npmjs\.org/?[[:space:]]*$'; then
      warn "non-default npm registry in $f: ${reg#registry=}"
      FOUND=1
    fi
  done

  for f in "$root/package-lock.json" "$root/yarn.lock" "$root/pnpm-lock.yaml"; do
    [ -f "$f" ] || continue
    grep -E -o "$SIG_BAD_DOMAINS" "$f" 2>/dev/null | sort -u > "$TMP/hits"
    report_hits "$TMP/hits" crit "suspicious domain in $(basename "$f")"
  done

  if [ -d "$root/node_modules" ] && [ ! -f "$root/package-lock.json" ] &&
     [ ! -f "$root/yarn.lock" ] && [ ! -f "$root/pnpm-lock.yaml" ] && [ ! -f "$root/bun.lockb" ]; then
    warn "node_modules present but no lockfile — dependency versions are not pinned"
    FOUND=1
  fi

  [ "$FOUND" -eq 0 ] && ok "registry config and lockfiles look sane"
}

scan_native_binaries() {
  hdr "6/7  Unexpected binaries in node_modules"
  local root="$1"
  FOUND=0

  [ -d "$root/node_modules" ] || { info "no node_modules directory"; return 0; }

  find "$root/node_modules" -type f \( -name '*.dll' -o -name '*.exe' \) 2>/dev/null > "$TMP/hits"
  report_hits "$TMP/hits" crit "Windows binary in node_modules"

  [ "$FOUND" -eq 0 ] && ok "no unexpected binaries"
}

scan_persistence() {
  hdr "7/7  Host persistence artefacts"
  local f d
  FOUND=0

  for f in "$HOME/.local/bin/gh-token-monitor.sh" "$HOME/.local/bin/gh-token-monitor" \
           "/usr/local/bin/gh-token-monitor.sh" "/usr/local/bin/gh-token-monitor" \
           "$HOME/.config/gh-token-monitor"; do
    if [ -e "$f" ]; then
      crit "dead-man's switch artefact: $f"
      FOUND=1
    fi
  done

  : > "$TMP/hits"
  for d in "$HOME/Library/LaunchAgents" "/Library/LaunchAgents" "/Library/LaunchDaemons"; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 1 -type f -name '*token-monitor*' 2>/dev/null >> "$TMP/hits"
  done
  report_hits "$TMP/hits" crit "suspicious launchd plist"

  if has crontab && crontab -l 2>/dev/null | grep -qE "$SIG_PERSIST"; then
    crit "crontab entry matches token-monitor pattern"
    FOUND=1
  fi

  for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshenv"; do
    if [ -f "$f" ] && grep -qE "$SIG_PERSIST" "$f" 2>/dev/null; then
      crit "shell rc references token-monitor: $f"
      FOUND=1
    fi
  done

  [ "$FOUND" -eq 0 ] && ok "no persistence artefacts"
}

# ── Entry point ───────────────────────────────────────────────────────────────
cmd_scan() {
  local root
  root="$(resolve_dir "${1:-.}")" || return 3

  TMP="$(mktemp -d "${TMPDIR:-/tmp}/fss.XXXXXX")" || die "cannot create temp dir"
  trap 'rm -rf "$TMP"' EXIT INT TERM

  printf '%sfss scan%s — %s\n' "$BLD" "$RST" "$root"

  scan_lifecycle_scripts "$root"
  scan_ioc_files "$root"
  scan_code_signatures "$root"
  scan_credentials "$root"
  scan_registry_and_lockfile "$root"
  scan_native_binaries "$root"
  scan_persistence

  hdr "Summary"
  if [ "$CRIT_COUNT" -gt 0 ]; then
    printf '  %s%d critical%s, %d warning(s) — investigate before installing or running anything.\n' \
      "$RED" "$CRIT_COUNT" "$RST" "$WARN_COUNT"
    return 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    printf '  %s%d warning(s)%s — review recommended.\n' "$YEL" "$WARN_COUNT" "$RST"
    return 1
  fi
  printf '  %sclean%s — no findings.\n' "$GRN" "$RST"
  return 0
}
