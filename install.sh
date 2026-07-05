#!/bin/sh
# install.sh — installs the fss CLI to ~/.fss and links it into your PATH.
#
# Usage:  curl -fsSL https://fss.coody.app/install.sh | sh
#
# What it does (and nothing else):
#   1. Downloads the latest main branch of github.com/coodyapp/fss
#   2. Copies apps/cli into ~/.fss
#   3. Symlinks ~/.local/bin/fss -> ~/.fss/bin/fss
#
# POSIX sh; works on macOS and Debian-based Linux. Re-run to update.
set -eu

REPO_TARBALL="https://codeload.github.com/coodyapp/fss/tar.gz/refs/heads/main"
FSS_DIR="${FSS_DIR:-$HOME/.fss}"
BIN_DIR="${FSS_BIN_DIR:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

command -v tar >/dev/null 2>&1 || die "tar is required"

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "curl or wget is required"
  fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fss-install.XXXXXX")" || die "cannot create temp dir"
trap 'rm -rf "$WORK"' EXIT INT TERM

say "Downloading fss (main) ..."
fetch "$REPO_TARBALL" | tar -xzf - -C "$WORK" || die "download failed"

SRC="$(find "$WORK" -maxdepth 1 -type d -name 'fss-*' | head -n 1)"
if [ -z "$SRC" ] || [ ! -d "$SRC/apps/cli" ]; then
  die "unexpected archive layout"
fi

say "Installing to $FSS_DIR ..."
rm -rf "$FSS_DIR"
mkdir -p "$FSS_DIR"
cp -R "$SRC/apps/cli/bin" "$SRC/apps/cli/lib" "$FSS_DIR/"
chmod +x "$FSS_DIR/bin/fss"

mkdir -p "$BIN_DIR"
ln -sf "$FSS_DIR/bin/fss" "$BIN_DIR/fss"

say "Installed: $("$FSS_DIR/bin/fss" --version | head -n 1)"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    say "Done. Run: fss scan ."
    ;;
  *)
    say "Done — but $BIN_DIR is not in your PATH."
    say "Add this line to your shell rc, then restart your shell:"
    say "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac
