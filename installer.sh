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
api="$(curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${REPO}/releases?per_page=30")" \
  || die "Could not reach the GitHub releases API."

# First match = newest (the list is newest-first). NOT `head -1`: the match list
# outgrew grep's 4K stdio buffer, so grep kept writing after head exited, took
# SIGPIPE, and under `set -euo pipefail` the script died HERE with no output
# (the "prints Resolving… then nothing" failure). sed reads all its input, so
# the pipe never closes early; `|| true` lets a no-match (grep exit 1) fall
# through to the die below instead of silently killing the script the same way.
url="$(printf '%s' "$api" \
  | grep -oE "https://[^\"]*/aurapanel_[0-9][^\"]*_${ARCH}\.deb" \
  | sed -n '1p')" || true
[ -n "$url" ] || die "No aurapanel_*_${ARCH}.deb asset in the latest release yet (build may still be running)."

ver="$(printf '%s' "$url" | sed -E 's#.*/aurapanel_([^_]+)_'"${ARCH}"'\.deb#\1#')"
say "Latest release: v${ver:-?}  (${ARCH})"

tmp="$(mktemp /tmp/aurapanel.XXXXXX.deb)"
trap 'rm -f "$tmp"' EXIT
say "Downloading $(basename "$url")…"
curl -fL --connect-timeout 15 --retry 3 -o "$tmp" "$url" || die "Download failed."

# Verify the package against the release's SIGNED SHA256SUMS *before* installing
# it as root. The Ed25519 public key is embedded here because the .deb that ships
# it (/opt/aurapanel/share/release-ed25519.pub, used by update.sh) is not on disk
# yet on a first-touch bootstrap. Fail closed: a valid signature over SHA256SUMS
# AND a matching checksum are BOTH required. Mirrors update.sh's verify_artifact —
# KEEP THE EMBEDDED KEY IN SYNC with installer/release-ed25519.pub.
base="${url%/*}"            # https://…/releases/download/<tag>
name="$(basename "$url")"   # aurapanel_<ver>_<arch>.deb
pub="$(mktemp /tmp/aurapanel.XXXXXX.pub)"
sums="$(mktemp /tmp/aurapanel.XXXXXX.sums)"
sig="$(mktemp /tmp/aurapanel.XXXXXX.sig)"
trap 'rm -f "$tmp" "$pub" "$sums" "$sig"' EXIT
cat > "$pub" <<'PUBKEY'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEARTexoH8qDE3/xksfU/KKOWWlUhYihjsdC4LVHyircDA=
-----END PUBLIC KEY-----
PUBKEY
command -v openssl   >/dev/null 2>&1 || die "openssl is required to verify the release signature."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required to verify the package."
say "Verifying release signature + checksum…"
curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 -o "$sums" "$base/SHA256SUMS"     || die "Release publishes no SHA256SUMS — refusing to install unverified."
curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 -o "$sig"  "$base/SHA256SUMS.sig" || die "Release publishes no SHA256SUMS.sig — refusing to install unverified."
openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$sums" -sigfile "$sig" >/dev/null 2>&1 \
  || die "Release signature verification FAILED — refusing to install (tampering or wrong key)."
want="$(awk -v f="$name" '$2 == f || $2 == "*"f {print $1; exit}' "$sums")"
[ -n "$want" ] || die "No checksum for ${name} in SHA256SUMS — refusing to install."
got="$(sha256sum "$tmp" | awk '{print $1}')"
[ "$want" = "$got" ] || die "Checksum mismatch for ${name} — refusing to install."
say "Signature + checksum verified (Ed25519)."

say "Installing the package…"
$SUDO dpkg -i "$tmp"

say "Provisioning the data plane (aurapanel-install)…"
# aurapanel-install reads /dev/tty for the interactive wizard, so piping this
# script through `| bash` does not interfere. Forwarded flags ("$@") win.
$SUDO aurapanel-install "$@"
