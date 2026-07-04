# shellcheck shell=sh disable=SC3043
# outdated.sh — report installed vs latest versions for declared dependencies.
#
# Sources, in order of preference:
#   installed : node_modules/<pkg>/package.json
#   latest    : npm registry (curl/wget); skipped when FSS_OFFLINE=1
#
# Exit codes: 0 all current | 1 outdated found | 3 error.

cmd_outdated() {
  local root pkg name spec installed latest status outdated=0 checked=0
  root="$(resolve_dir "${1:-.}")" || return 3
  pkg="$root/package.json"
  [ -f "$pkg" ] || die "no package.json in $root"

  TMP="$(mktemp -d "${TMPDIR:-/tmp}/fss.XXXXXX")" || die "cannot create temp dir"
  trap 'rm -rf "$TMP"' EXIT INT TERM

  if [ "${FSS_OFFLINE:-0}" != "1" ] && ! has curl && ! has wget; then
    die "need curl or wget for registry lookups (or set FSS_OFFLINE=1)"
  fi

  json_deps "$pkg" > "$TMP/deps"
  [ -s "$TMP/deps" ] || { ok "no dependencies declared"; return 0; }

  printf '%sfss outdated%s — %s\n\n' "$BLD" "$RST" "$root"
  printf '  %-32s %-14s %-14s %-14s %s\n' PACKAGE SPEC INSTALLED LATEST STATUS

  while IFS=' ' read -r name spec; do
    [ -n "$name" ] || continue
    checked=$((checked + 1))

    installed='-'
    if [ -f "$root/node_modules/$name/package.json" ]; then
      installed="$(json_version "$root/node_modules/$name/package.json")"
      installed="${installed:--}"
    fi

    latest='?'
    if [ "${FSS_OFFLINE:-0}" != "1" ]; then
      if http_get "https://registry.npmjs.org/$name/latest" > "$TMP/reg" && [ -s "$TMP/reg" ]; then
        latest="$(json_version "$TMP/reg")"
        latest="${latest:-?}"
      fi
    fi

    status=current
    if [ "$installed" = "-" ]; then
      status="not installed"
    elif [ "$latest" = "?" ]; then
      status=unknown
    elif [ "$installed" != "$latest" ]; then
      if [ "${installed%%.*}" != "${latest%%.*}" ]; then
        status="${RED}MAJOR${RST}"
      else
        status="${YEL}outdated${RST}"
      fi
      outdated=$((outdated + 1))
    fi

    printf '  %-32s %-14s %-14s %-14s %b\n' "$name" "$spec" "$installed" "$latest" "$status"
  done < "$TMP/deps"

  printf '\n'
  if [ "$outdated" -gt 0 ]; then
    warn "$outdated of $checked dependencies outdated"
    return 1
  fi
  ok "all $checked dependencies current (or unknown)"
  return 0
}
