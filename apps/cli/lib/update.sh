# shellcheck shell=sh disable=SC3043
# update.sh — update an installed fss to the latest GitHub release.
#
# Mirrors sak's self-update: stage the new version in a fresh directory and
# swap it in with mv. Overwriting $FSS_HOME in place would corrupt the
# currently executing bin/fss; mv only replaces directory entries, so the
# already-open fd keeps reading the original content safely to the end.

cmd_update() {
  local tag latest work src stage old

  # Running from the repo (apps/cli inside a checkout), not an installed copy.
  if fss_is_checkout; then
    die "running from a checkout — update with git pull instead"
  fi

  [ "${FSS_OFFLINE:-0}" != "1" ] || die "cannot update with FSS_OFFLINE=1"
  command -v tar >/dev/null 2>&1 || die "tar is required"

  tag="$(http_get "$FSS_LATEST_RELEASE_API" | json_tag_name)"
  [ -n "$tag" ] || die "could not determine the latest release"
  latest="${tag#v}"

  if [ "$latest" = "$FSS_VERSION" ]; then
    ok "already up to date ($FSS_VERSION)"
    return 0
  fi

  printf 'Updating fss %s -> %s ...\n' "$FSS_VERSION" "$latest"

  work="$(mktemp -d "${TMPDIR:-/tmp}/fss_update.XXXXXX")" || die "cannot create temp dir"
  stage="$(mktemp -d "${TMPDIR:-/tmp}/fss_stage.XXXXXX")" || die "cannot create temp dir"
  # Bake the paths into the trap: it fires at EXIT, after this function's
  # locals are gone (set -u would report them unbound).
  # shellcheck disable=SC2064  # early expansion intentional
  trap "rm -rf '$work' '$stage'" EXIT INT TERM

  http_get "https://codeload.github.com/coodyapp/fss/tar.gz/refs/tags/$tag" \
    | tar -xzf - -C "$work" || die "download failed"

  src="$(find "$work" -maxdepth 1 -type d -name 'fss-*' | head -n 1)"
  if [ -z "$src" ] || [ ! -d "$src/apps/cli" ]; then
    die "unexpected archive layout"
  fi

  cp -R "$src/apps/cli/bin" "$src/apps/cli/lib" "$stage/"
  chmod +x "$stage/bin/fss"

  old="$FSS_HOME.old.$$"
  if ! { mv "$FSS_HOME" "$old" && mv "$stage" "$FSS_HOME"; }; then
    mv "$old" "$FSS_HOME" 2>/dev/null
    die "could not replace $FSS_HOME"
  fi
  rm -rf "$old"
  printf '%s\n' "$latest" > "$FSS_HOME/.update-check" 2>/dev/null

  ok "updated: fss $("$FSS_HOME/bin/fss" --version)"
  return 0
}
