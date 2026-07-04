# shellcheck shell=sh disable=SC3043
# clean.sh — find and safely remove node_modules directories.
#
# Safety rules, in order:
#   - only directories literally named node_modules are ever deleted
#   - symlinks are listed but never followed or deleted
#   - nested node_modules are pruned (deleting the parent removes them)
#   - interactive confirmation unless --yes; --dry-run never deletes

cmd_clean() {
  local root dry_run=0 assume_yes=0 arg dir kb total_kb=0 count=0 answer

  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --yes|-y)  assume_yes=1 ;;
      -*)        die "unknown option for clean: $arg" ;;
      *)         root="$arg" ;;
    esac
  done
  root="$(resolve_dir "${root:-.}")" || return 3

  case "$root" in
    /|"$HOME") die "refusing to run clean on $root — pick a project or workspace directory" ;;
  esac

  TMP="$(mktemp -d "${TMPDIR:-/tmp}/fss.XXXXXX")" || die "cannot create temp dir"
  trap 'rm -rf "$TMP"' EXIT INT TERM

  printf '%sfss clean%s — %s\n\n' "$BLD" "$RST" "$root"

  # -prune keeps nested node_modules out of the list; deleting the top-level
  # directory removes them anyway.
  find "$root" -type d -name node_modules -not -path '*/.git/*' -prune -print 2>/dev/null \
    | sort > "$TMP/dirs"

  if [ ! -s "$TMP/dirs" ]; then
    ok "no node_modules directories found"
    return 0
  fi

  while IFS= read -r dir; do
    if [ -L "$dir" ]; then
      info "skipping symlink: $dir"
      continue
    fi
    kb="$(du -sk "$dir" 2>/dev/null | cut -f1)"
    kb="${kb:-0}"
    total_kb=$((total_kb + kb))
    count=$((count + 1))
    printf '  %8s  %s\n' "$(human_kb "$kb")" "$dir"
    printf '%s\n' "$dir" >> "$TMP/targets"
  done < "$TMP/dirs"

  [ -s "$TMP/targets" ] || { ok "nothing to delete"; return 0; }

  printf '\n  %s%d director%s, %s total%s\n' \
    "$BLD" "$count" "$([ "$count" -eq 1 ] && echo y || echo ies)" "$(human_kb "$total_kb")" "$RST"

  if [ "$dry_run" -eq 1 ]; then
    info "dry run — nothing deleted"
    return 0
  fi

  if [ "$assume_yes" -ne 1 ]; then
    printf '\n  Delete these directories? [y/N] '
    read -r answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) info "aborted — nothing deleted"; return 0 ;;
    esac
  fi

  while IFS= read -r dir; do
    # Re-verify before each delete: still a real dir, still named node_modules.
    if [ ! -d "$dir" ] || [ -L "$dir" ]; then continue; fi
    case "$dir" in
      */node_modules) rm -rf -- "$dir" ;;
      *) warn "unexpected path skipped: $dir" ;;
    esac
  done < "$TMP/targets"

  ok "reclaimed $(human_kb "$total_kb")"
  return 0
}
