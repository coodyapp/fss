# shellcheck shell=sh disable=SC3043
# banner.sh — welcome banner for bare `fss` (no subcommand): a big logo +
# usage, revealed line by line for a quick animated feel in real terminals.
# POSIX sh port of sak's lib/banner.sh (no arrays, no <<<, no substrings).

# Animate only on a real terminal, and let NO_COLOR / CI / FSS_NO_ANIMATION
# opt out.
fss_animate() {
  [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ] && [ -z "${FSS_NO_ANIMATION:-}" ]
}

# Print $1 line by line in color $2; sleep between lines when $3 = 1.
_reveal() {
  local text="$1" color="$2" animate="$3" l
  printf '%s\n' "$text" | while IFS= read -r l; do
    printf '%s%s%s\n' "$color" "$l" "$RST"
    [ "$animate" -eq 1 ] && sleep 0.012
  done
  return 0
}

# Repeat character $1 $2 times (pure sh: tr can't be trusted with multibyte
# box-drawing chars on BSD).
_repeat() {
  local char="$1" count="$2" out="" i=0
  while [ "$i" -lt "$count" ]; do
    out="$out$char"
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# Pad $1 with trailing spaces to $2 columns (content is ASCII-only).
_pad() {
  printf '%s%s' "$1" "$(_repeat ' ' $(($2 - ${#1})))"
}

# Two-column welcome box: check-group count on the left, a quick tip on the
# right.
_welcome_box() {
  local version="$1" left=32 right=36 title fill
  title=" fss $version "
  fill=$((left - ${#title}))

  printf '┌%s%s┬%s┐\n' "$title" "$(_repeat '─' "$fill")" "$(_repeat '─' "$right")"
  printf '│%s│%s│\n' "$(_pad '  Security check groups: 7' "$left")" "$(_pad '  New here? Run: fss scan .' "$right")"
  printf '└%s┴%s┘\n' "$(_repeat '─' "$left")" "$(_repeat '─' "$right")"
}

render_banner() {
  local animate=0 logo
  fss_animate && animate=1

  logo=' ███████████  █████████   █████████
░░███░░░░░░  ███░░░░░███ ███░░░░░███
 ░███ █ ░   ░███    ░░░ ░███    ░░░
 ░███████   ░░█████████ ░░█████████
 ░███░░░█    ░░░░░░░░███ ░░░░░░░░███
 ░███ ░      ███    ░███ ███    ░███
 █████      ░░█████████ ░░█████████
░░░░░        ░░░░░░░░░   ░░░░░░░░░  '

  _reveal "$logo" "$BLD" "$animate"
  echo
  _reveal '  A Fast Security Scan for developers — powered by coody.app' "$DIM" "$animate"
  echo
  _reveal "$(_welcome_box "$FSS_VERSION")" "$DIM" "$animate"
  echo
  _reveal "$(usage)" '' "$animate"
  return 0
}
