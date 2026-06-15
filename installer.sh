#!/usr/bin/env bash
#
# auraPanel bootstrap installer — always fetches the LATEST released package.
#
#   curl -fsSL https://aurapanel.goaura.one/installer.sh | bash
#   # …or pass installer flags through:
#   curl -fsSL …/get.sh | bash -s -- --yes --db=both --node=yes --php=yes
#
# Why this instead of a pinned URL: the Release workflow only publishes a
# GitHub Release (with the .deb assets) when the build SUCCEEDS. A tag whose
# CI build failed never becomes a Release. So "the latest Release" is, by
# construction, the latest *successfully built* package — this script resolves
# it from the GitHub API every run, so you never copy a stale or broken
# version pin. Args after `--` are forwarded verbatim to `aurapanel-install`.
set -euo pipefail

REPO="goaura-one/aurapanel-releases"

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Privilege helper: use sudo when not already root (so `curl … | bash` works
# without the caller prefixing sudo).
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "Run as root, or install sudo."
  SUDO="sudo"
fi

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v dpkg >/dev/null 2>&1 || die "This installer targets Debian/Ubuntu (dpkg not found)."

ARCH="$(dpkg --print-architecture)"   # amd64 | arm64
case "$ARCH" in
  amd64|arm64) ;;
  *) die "Unsupported architecture: ${ARCH} (need amd64 or arm64)." ;;
esac

say "Resolving the latest auraPanel release for ${ARCH}…"
# Pull the releases LIST (newest first) and pick the first .deb for this arch.
# We avoid /releases/latest — GitHub answers it with slow 504s for this repo,
# which broke installs/updates; /releases is fast and reliable. (No jq — grep
# the asset URL; the list is newest-first, so head -1 is the newest build.)
api="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${REPO}/releases?per_page=30")" \
  || die "Could not reach the GitHub releases API."

url="$(printf '%s' "$api" \
  | grep -oE "https://[^\"]*/aurapanel_[0-9][^\"]*_${ARCH}\.deb" \
  | head -1)"
[ -n "$url" ] || die "No aurapanel_*_${ARCH}.deb asset in the latest release yet (build may still be running)."

ver="$(printf '%s' "$url" | sed -E 's#.*/aurapanel_([^_]+)_'"${ARCH}"'\.deb#\1#')"
say "Latest release: v${ver:-?}  (${ARCH})"

tmp="$(mktemp /tmp/aurapanel.XXXXXX.deb)"
trap 'rm -f "$tmp"' EXIT
say "Downloading $(basename "$url")…"
curl -fL --retry 3 -o "$tmp" "$url" || die "Download failed."

say "Installing the package…"
$SUDO dpkg -i "$tmp"

say "Provisioning the data plane (aurapanel-install)…"
# aurapanel-install reads /dev/tty for the interactive wizard, so piping this
# script through `| bash` does not interfere. Forwarded flags ("$@") win.
$SUDO aurapanel-install "$@"
