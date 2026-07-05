# shellcheck shell=sh disable=SC3043
# common.sh — shared helpers for fss. POSIX sh only (dash, macOS sh, bash).

# shellcheck disable=SC2034  # consumed by bin/fss after sourcing
FSS_VERSION="0.1.0"

# ── Colors (honor NO_COLOR and non-tty output) ────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED="$(printf '\033[31m')"
  GRN="$(printf '\033[32m')"
  YEL="$(printf '\033[33m')"
  CYN="$(printf '\033[36m')"
  BLD="$(printf '\033[1m')"
  RST="$(printf '\033[0m')"
else
  RED=""; GRN=""; YEL=""; CYN=""; BLD=""; RST=""
fi

# ── Finding counters ──────────────────────────────────────────────────────────
WARN_COUNT=0
CRIT_COUNT=0

hdr()  { printf '\n%s%s%s\n' "$BLD" "$*" "$RST"; }
ok()   { printf '  %s✔%s  %s\n' "$GRN" "$RST" "$*"; }
info() { printf '  %sℹ%s  %s\n' "$CYN" "$RST" "$*"; }
warn() { printf '  %s⚠%s  %s\n' "$YEL" "$RST" "$*"; WARN_COUNT=$((WARN_COUNT + 1)); }
crit() { printf '  %s✖%s  %s\n' "$RED" "$RST" "$*"; CRIT_COUNT=$((CRIT_COUNT + 1)); }
die()  { printf '%serror:%s %s\n' "$RED" "$RST" "$*" >&2; exit 3; }

# ── Utilities ─────────────────────────────────────────────────────────────────
has() { command -v "$1" >/dev/null 2>&1; }

# Kilobytes → human-readable size.
human_kb() {
  local kb="$1"
  if [ "$kb" -ge 1048576 ]; then
    printf '%s.%s GB' $((kb / 1048576)) $((kb % 1048576 * 10 / 1048576))
  elif [ "$kb" -ge 1024 ]; then
    printf '%s.%s MB' $((kb / 1024)) $((kb % 1024 * 10 / 1024))
  else
    printf '%s KB' "$kb"
  fi
}

# Resolve a directory argument to an absolute path, or die.
resolve_dir() {
  [ -d "$1" ] || die "not a directory: $1"
  (CDPATH='' cd -- "$1" && pwd)
}

# Fetch a URL to stdout using curl or wget; returns non-zero on failure.
http_get() {
  if has curl; then
    curl -fsSL --max-time 10 "$1" 2>/dev/null
  elif has wget; then
    wget -qO- --timeout=10 "$1" 2>/dev/null
  else
    return 127
  fi
}

# Extract dependency names (one per line) from a package.json.
# Uses node when available (robust), falls back to awk (well-formatted JSON).
json_deps() {
  local pkg="$1"
  if has node; then
    # shellcheck disable=SC2016  # single quotes intentional: JS, not shell expansion
    node -e '
      const p = require(process.argv[1]);
      const deps = { ...(p.dependencies || {}), ...(p.devDependencies || {}) };
      for (const [name, spec] of Object.entries(deps)) console.log(`${name} ${spec}`);
    ' "$pkg" 2>/dev/null
  else
    awk '
      /"(dependencies|devDependencies)"[[:space:]]*:/ { in_deps = 1; next }
      in_deps && /}/ { in_deps = 0 }
      in_deps && /"[^"]+"[[:space:]]*:[[:space:]]*"[^"]*"/ {
        line = $0
        gsub(/^[[:space:]]*"/, "", line); sub(/"[[:space:]]*:[[:space:]]*"/, " ", line)
        sub(/",?[[:space:]]*$/, "", line)
        print line
      }
    ' "$pkg"
  fi
}

# Extract the "version" field from a package.json (or registry JSON blob).
# First occurrence wins: greedy sed would grab the last "version" key on
# minified single-line JSON (e.g. a dependency literally named "version").
json_version() {
  grep -E -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null | head -n 1 |
    sed 's/.*"\([^"]*\)"$/\1/'
}
