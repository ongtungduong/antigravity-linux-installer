#!/usr/bin/env bash
# Print "<product> <platform> <version>" for every product and platform listed on
# Google's download page. Fails if any version cannot be read, so a page layout
# change shows up as a failed run instead of a silently stale file.
#   tools/google-versions.sh              # reads the live page
#   tools/google-versions.sh page.html    # reads a saved page (tests)
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../antigravity-linux
source "$here/antigravity-linux"

page="${1:-}"
if [ -z "$page" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/google-versions.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  page=$(fetch_download_page "$tmp")
fi

for product in desktop ide; do
  for AG_PLATFORM in linux-x64 linux-arm; do
    read -r version _ < <(resolve_download "$page" "$product") \
      || err "No $product build for $AG_PLATFORM on the download page."
    [ "$version" != "unknown" ] || err "Could not read the $product version for $AG_PLATFORM from its URL."
    printf '%s %s %s\n' "$product" "$AG_PLATFORM" "$version"
  done
done
