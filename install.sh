#!/usr/bin/env bash
# Bootstrap for antigravity-linux: downloads the helper, which does the install.
#   curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-linux-installer/main/install.sh | bash -s -- [options]
# Set ANTIGRAVITY_LINUX_REF to a tag or commit to install that version of the helper.
set -euo pipefail

REF="${ANTIGRAVITY_LINUX_REF:-main}"
HELPER_URL="https://raw.githubusercontent.com/ongtungduong/antigravity-linux-installer/$REF/antigravity-linux"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required."

# --proxy applies to this download as well.
args=("$@")
for ((i = 0; i < ${#args[@]} - 1; i++)); do
  if [ "${args[i]}" = "--proxy" ]; then
    export http_proxy="${args[i+1]}" https_proxy="${args[i+1]}"
  fi
done

helper=$(mktemp "${TMPDIR:-/tmp}/antigravity-linux.XXXXXX")
trap 'rm -f "$helper"' EXIT
curl -fsSL --retry 3 -o "$helper" "$HELPER_URL" || die "Could not download $HELPER_URL (check network/DNS, or use --proxy)."

bash "$helper" install "$@"
