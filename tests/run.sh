#!/usr/bin/env bash
# Offline test suite for install.sh and antigravity-linux.
# No network, no root, nothing installed: curl/sudo/apt-get/... are stubbed on PATH
# and every install path is redirected into a scratch directory.
#   bash tests/run.sh
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT/antigravity-linux"
INSTALLER="$ROOT/install.sh"
FIX="$ROOT/tests/fixtures"
ORIG_PATH=$PATH
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# --- helpers -----------------------------------------------------------------

setup() {
  T=$(mktemp -d "$SCRATCH/t.XXXXXX")
  STUBS="$T/stubs"; LOG="$T/calls.log"
  mkdir -p "$STUBS"; : > "$LOG"
  PATH="$STUBS:$ORIG_PATH"
  export PATH LOG T
}
stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
fail() { echo "    $*" >&2; return 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'${3:+ ($3)}"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "expected '$2' in: $1" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "did not expect '$2' in: $1" ;; esac; }
assert_file() { [ -e "$1" ] || fail "missing: $1"; }
assert_no_file() { [ ! -e "$1" ] && [ ! -L "$1" ] || fail "should not exist: $1"; }
# Tests that touch system paths refuse to run until the code lets them be redirected.
require_seam() { local v; for v in "$@"; do [ -n "${!v+x}" ] || fail "seam missing: $v (refusing to touch the real system)"; done; }

# Redirect every system path into $T and stub the privileged commands.
sandbox_system() {
  require_seam OPT_DIR BIN_DIR SHARE_DIR
  OPT_DIR="$T/opt"; BIN_DIR="$T/bin"; SHARE_DIR="$T/share"; HELPER_PATH="$BIN_DIR/antigravity-linux"
  mkdir -p "$BIN_DIR"
  stub id 'echo 0'
  stub chown 'exit 0'
  stub curl '
echo "curl $*" >> "$LOG"
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out=$2; shift ;; https://*) url=$1 ;; esac
  shift
done
case "$url" in
  */download) cp "$FIX/download.html" "$out" ;;
  *"Antigravity%20IDE.tar.gz") cp "$T/ide.tar.gz" "$out" ;;
  *Antigravity.tar.gz) cp "$T/desktop.tar.gz" "$out" ;;
  *) echo "unexpected url $url" >&2; exit 22 ;;
esac'
  export FIX
}

make_desktop_tarball() {
  local top
  case "$(uname -m)" in x86_64|amd64) top=Antigravity-x64 ;; aarch64|arm64) top=Antigravity-arm64 ;; *) echo "unsupported test arch" >&2; return 1 ;; esac
  mkdir -p "$T/pkg-d/$top"
  printf '#!/bin/sh\n' > "$T/pkg-d/$top/antigravity"; chmod +x "$T/pkg-d/$top/antigravity"
  : > "$T/pkg-d/$top/chrome-sandbox"
  tar -C "$T/pkg-d" -czf "$T/desktop.tar.gz" "$top"
  DESKTOP_TOP_FOR_TEST=$top
}
make_ide_tarball() {
  mkdir -p "$T/pkg-i/Antigravity IDE/resources/app/resources/linux"
  printf '#!/bin/sh\n' > "$T/pkg-i/Antigravity IDE/antigravity-ide"; chmod +x "$T/pkg-i/Antigravity IDE/antigravity-ide"
  : > "$T/pkg-i/Antigravity IDE/chrome-sandbox"
  : > "$T/pkg-i/Antigravity IDE/resources/app/resources/linux/code.png"
  tar -C "$T/pkg-i" -czf "$T/ide.tar.gz" "Antigravity IDE"
}

# --- resolving downloads (characterization + version fidelity) ---------------

t_resolve_desktop_x64() {
  source "$HELPER"; AG_PLATFORM=linux-x64
  read -r v u < <(resolve_download "$FIX/download.html" desktop)
  assert_eq "$v" "2.33.0-123" "version keeps its build number"
  assert_contains "$u" "/linux-x64/Antigravity.tar.gz"
}
t_resolve_desktop_arm() {
  source "$HELPER"; AG_PLATFORM=linux-arm
  read -r _ u < <(resolve_download "$FIX/download.html" desktop)
  assert_contains "$u" "/linux-arm/Antigravity.tar.gz"
}
t_resolve_ide() {
  source "$HELPER"; AG_PLATFORM=linux-x64
  read -r v u < <(resolve_download "$FIX/download.html" ide)
  assert_eq "$v" "1.2.3-45"
  assert_contains "$u" "Antigravity%20IDE.tar.gz"
}
t_resolve_rejects_untrusted_hosts() {
  source "$HELPER"; AG_PLATFORM=linux-x64
  ! resolve_download "$FIX/download-untrusted.html" desktop 2>/dev/null
}
t_resolve_unknown_layout_reports_unknown() {
  source "$HELPER"; AG_PLATFORM=linux-x64
  read -r v _ < <(resolve_download "$FIX/download-unknown-layout.html" desktop)
  assert_eq "$v" "unknown"
}

# --- up-to-date decision ------------------------------------------------------

t_is_up_to_date() {
  source "$HELPER"
  mkdir -p "$T/app"; printf '#!/bin/sh\n' > "$T/app/bin"; chmod +x "$T/app/bin"
  printf '1.0-1\n' > "$T/ver"
  FORCE=0; is_up_to_date "$T/app/bin" 1.0-1 "$T/ver"
  ! is_up_to_date "$T/app/bin" 1.0-2 "$T/ver"
  FORCE=1; ! is_up_to_date "$T/app/bin" 1.0-1 "$T/ver"
}
t_unknown_version_never_counts_as_up_to_date() {
  source "$HELPER"; FORCE=0
  mkdir -p "$T/app"; printf '#!/bin/sh\n' > "$T/app/bin"; chmod +x "$T/app/bin"
  printf '1.0-1\n' > "$T/ver"
  is_up_to_date "$T/app/bin" 1.0-1 "$T/ver"            # precondition: the function exists and says yes
  printf 'unknown\n' > "$T/ver"
  ! is_up_to_date "$T/app/bin" unknown "$T/ver"
}

# --- environment hardening ----------------------------------------------------

t_init_environment_sets_umask_022() {
  source "$HELPER"
  umask 077
  init_environment
  assert_eq "$(umask)" "0022"
}
t_extract_does_not_keep_archive_owner() {
  source "$HELPER"
  stub tar 'echo "tar $*" >> "$LOG"'
  extract_tarball "$T/x.tgz" "$T/out"
  assert_contains "$(cat "$LOG")" "--no-same-owner"
}
t_extract_really_extracts() {
  source "$HELPER"
  mkdir -p "$T/src/top"; echo hi > "$T/src/top/f"; tar -C "$T/src" -czf "$T/a.tgz" top
  mkdir -p "$T/out"; extract_tarball "$T/a.tgz" "$T/out"
  assert_file "$T/out/top/f"
}

# --- apt dependencies ---------------------------------------------------------

apt_stubs() {
  stub dpkg-query 'for last; do :; done; case " ${MISSING_PKGS:-} " in *" $last "*) exit 1 ;; esac; printf "install ok installed"'
  stub apt-get 'echo "apt-get $*" >> "$LOG"; if [ "$1" = update ] && [ -n "${APT_UPDATE_FAIL:-}" ]; then exit 100; fi'
}
t_deps_skip_apt_when_all_installed() {
  source "$HELPER"; apt_stubs; MISSING_PKGS=""
  INSTALL_DEPS=1; INSTALL_IDE=0
  install_deps_debian
  assert_eq "$(cat "$LOG")" "" "apt-get must not run when nothing is missing"
}
t_deps_install_only_missing() {
  source "$HELPER"; apt_stubs; export MISSING_PKGS="xdg-utils"
  INSTALL_DEPS=1; INSTALL_IDE=0
  install_deps_debian
  assert_contains "$(cat "$LOG")" "apt-get install -y xdg-utils"
  assert_not_contains "$(cat "$LOG")" "python3 "
}
t_deps_update_failure_not_fatal() {
  source "$HELPER"; apt_stubs; export MISSING_PKGS="xdg-utils" APT_UPDATE_FAIL=1
  INSTALL_DEPS=1; INSTALL_IDE=0
  install_deps_debian 2>/dev/null
  assert_contains "$(cat "$LOG")" "apt-get install -y xdg-utils"
}
t_deps_respects_no_apt() {
  source "$HELPER"; apt_stubs; export MISSING_PKGS="xdg-utils"
  INSTALL_DEPS=0
  install_deps_debian
  assert_eq "$(cat "$LOG")" ""
}

# --- atomic directory swap ----------------------------------------------------

t_swap_replaces_and_cleans_previous() {
  source "$HELPER"
  mkdir -p "$T/target" "$T/new"; echo old > "$T/target/f"; : > "$T/target/.antigravity-linux-version"
  echo new > "$T/new/f"
  safe_replace_dir "$T/new" "$T/target"
  assert_eq "$(cat "$T/target/f")" "new"
  assert_no_file "$T/target.previous"
}
t_swap_rolls_back_when_move_fails() {
  source "$HELPER"
  mkdir -p "$T/target"; echo old > "$T/target/f"; : > "$T/target/.antigravity-linux-version"
  ( safe_replace_dir "$T/does-not-exist" "$T/target" ) 2>/dev/null && return 1
  assert_eq "$(cat "$T/target/f")" "old" "old install must be restored"
  assert_no_file "$T/target.previous"
}
t_swap_refuses_foreign_directory() {
  source "$HELPER"
  mkdir -p "$T/target" "$T/new"; echo mine > "$T/target/f"   # no helper marker
  ( safe_replace_dir "$T/new" "$T/target" ) 2>/dev/null && return 1
  assert_eq "$(cat "$T/target/f")" "mine" "a directory we did not create must be left alone"
}
t_swap_first_install() {
  source "$HELPER"
  mkdir -p "$T/new"; echo new > "$T/new/f"
  safe_replace_dir "$T/new" "$T/target"
  assert_eq "$(cat "$T/target/f")" "new"
}

# --- helper wrappers, uninstall, CLI, args -----------------------------------

t_wrappers_only_for_selected_products() {
  source "$HELPER"; require_seam BIN_DIR HELPER_PATH
  BIN_DIR="$T/bin"; HELPER_PATH="$BIN_DIR/antigravity-linux"; mkdir -p "$BIN_DIR"
  INSTALL_DESKTOP=0; INSTALL_IDE=1
  install_helper
  [ -x "$BIN_DIR/update-antigravity-ide" ] || fail "IDE wrapper missing"
  assert_no_file "$BIN_DIR/update-antigravity"
  [ -x "$HELPER_PATH" ] || fail "helper not installed"
}
t_uninstall_only_removes_what_we_installed() {
  source "$HELPER"; require_seam OPT_DIR BIN_DIR SHARE_DIR
  OPT_DIR="$T/opt"; BIN_DIR="$T/bin"; SHARE_DIR="$T/share"
  mkdir -p "$OPT_DIR/antigravity" "$OPT_DIR/antigravity-ide" "$BIN_DIR"
  : > "$OPT_DIR/antigravity/.antigravity-linux-version"      # ours
  echo keep > "$OPT_DIR/antigravity-ide/user-file"            # not ours
  uninstall_all 2>/dev/null
  assert_no_file "$OPT_DIR/antigravity"
  assert_file "$OPT_DIR/antigravity-ide/user-file"
}
t_ref_env_selects_helper_url() {
  ANTIGRAVITY_LINUX_REF=v1.2.3 source "$HELPER"
  assert_contains "$(helper_url)" "/v1.2.3/antigravity-linux"
}
t_ref_defaults_to_main() {
  unset ANTIGRAVITY_LINUX_REF
  source "$HELPER"
  assert_contains "$(helper_url)" "/main/antigravity-linux"
}
t_ref_rejects_odd_characters() {
  ANTIGRAVITY_LINUX_REF=v1.0 source "$HELPER"
  helper_url >/dev/null                                  # precondition: a sane ref works
  HELPER_REF='v1 && rm -rf /'; ( helper_url ) >/dev/null 2>&1 && return 1
  HELPER_REF='../x';           ( helper_url ) >/dev/null 2>&1 && return 1
  HELPER_REF='';               ( helper_url ) >/dev/null 2>&1 && return 1
  return 0
}
t_cli_installer_says_when_it_runs_as_root() {
  source "$HELPER"; unset SUDO_USER
  stub curl 'exit 0'
  out=$(install_cli 2>&1)
  assert_contains "$out" "as root"
}
t_sudo_reexec_forwards_proxy_and_no_proxy() {
  stub id 'echo 1000'
  stub sudo 'echo "sudo $*" >> "$LOG"'
  ANTIGRAVITY_LINUX_REF=v7 https_proxy=http://p:1 no_proxy=localhost,.corp bash "$HELPER" --all || true
  assert_contains "$(cat "$LOG")" "ANTIGRAVITY_LINUX_REF=v7"
  assert_contains "$(cat "$LOG")" "https_proxy=http://p:1"
  assert_contains "$(cat "$LOG")" "no_proxy=localhost,.corp"
}
t_status_and_help_need_no_root() {
  stub id 'echo 1000'
  stub sudo 'echo "sudo $*" >> "$LOG"; exit 1'
  bash "$HELPER" --status >/dev/null
  bash "$HELPER" --help >/dev/null
  assert_eq "$(cat "$LOG")" ""
}

# --- install.sh bootstrap -----------------------------------------------------

bootstrap_stub() {
  stub curl '
echo "curl $*" >> "$LOG"
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift ;; esac; shift; done
printf "#!/usr/bin/env bash\necho \"\$@ ref=\${ANTIGRAVITY_LINUX_REF:-}\" >> \"\$LOG\"\n" > "$out"'
}
t_bootstrap_downloads_and_passes_pinned_ref() {
  bootstrap_stub
  TMPDIR="$T" ANTIGRAVITY_LINUX_REF=v9 bash "$INSTALLER" --all
  assert_contains "$(cat "$LOG")" "/v9/antigravity-linux"
  assert_contains "$(cat "$LOG")" "install --all ref=v9"
}
t_bootstrap_default_is_main() {
  bootstrap_stub
  TMPDIR="$T" bash "$INSTALLER" --all
  assert_contains "$(cat "$LOG")" "/main/antigravity-linux"
  assert_contains "$(cat "$LOG")" "install --all ref="
}
t_bootstrap_download_has_timeouts() {
  bootstrap_stub
  TMPDIR="$T" bash "$INSTALLER"
  assert_contains "$(grep '^curl' "$LOG")" "--connect-timeout"
  assert_contains "$(grep '^curl' "$LOG")" "--max-time"
}
t_bootstrap_cleans_temp_file() {
  bootstrap_stub
  mkdir -p "$T/tmp"
  TMPDIR="$T/tmp" bash "$INSTALLER"
  assert_eq "$(ls -A "$T/tmp")" ""
}

# --- end to end (everything redirected into $T) ------------------------------

t_e2e_desktop_install_update_force() {
  source "$HELPER"; sandbox_system; make_desktop_tarball
  umask 077   # a restrictive caller umask must not leak into the install
  TMPDIR="$T" main --desktop --no-apt --no-nautilus >/dev/null
  assert_file "$OPT_DIR/antigravity/$DESKTOP_TOP_FOR_TEST/antigravity"
  [ -L "$BIN_DIR/antigravity" ] || fail "launcher symlink missing"
  assert_file "$SHARE_DIR/applications/antigravity.desktop"
  assert_eq "$(cat "$OPT_DIR/antigravity/.antigravity-linux-version")" "2.33.0-123"
  assert_no_file "$OPT_DIR/antigravity.previous"
  assert_no_file "$OPT_DIR/antigravity.new"
  [ $(( 0$(stat -c %a "$OPT_DIR/antigravity") & 5 )) -eq 5 ] || fail "install dir not world-readable under umask 077"
  [ $(( 0$(stat -c %a "$SHARE_DIR/applications/antigravity.desktop") & 4 )) -eq 4 ] || fail ".desktop not world-readable"
  [ -x "$BIN_DIR/update-antigravity" ] || fail "desktop update wrapper missing"
  assert_no_file "$BIN_DIR/update-antigravity-ide"

  before=$(grep -c 'Antigravity.tar.gz' "$LOG")
  out=$(TMPDIR="$T" main --desktop --no-apt --no-nautilus)
  assert_contains "$out" "already installed"
  assert_eq "$(grep -c 'Antigravity.tar.gz' "$LOG")" "$before" "second run must not re-download"

  TMPDIR="$T" main --desktop --no-apt --no-nautilus --force >/dev/null
  [ "$(grep -c 'Antigravity.tar.gz' "$LOG")" -gt "$before" ] || fail "--force must re-download"
}
t_e2e_ide_install() {
  source "$HELPER"; sandbox_system; make_ide_tarball
  TMPDIR="$T" main --ide --no-apt --no-nautilus >/dev/null
  assert_file "$OPT_DIR/antigravity-ide/Antigravity-IDE/antigravity-ide"
  [ -L "$BIN_DIR/antigravity-ide" ] || fail "IDE launcher missing"
  assert_file "$SHARE_DIR/icons/hicolor/512x512/apps/antigravity-ide.png"
  assert_file "$SHARE_DIR/applications/antigravity-ide.desktop"
  assert_eq "$(cat "$OPT_DIR/antigravity-ide/.antigravity-linux-version")" "1.2.3-45"
}
t_e2e_every_download_has_timeouts() {
  source "$HELPER"; sandbox_system; make_desktop_tarball
  TMPDIR="$T" main --desktop --no-apt --no-nautilus >/dev/null
  while IFS= read -r line; do
    assert_contains "$line" "--connect-timeout"
    assert_contains "$line" "--max-time"
  done < "$LOG"
}
t_e2e_refuses_to_overwrite_foreign_launcher() {
  source "$HELPER"; sandbox_system; make_desktop_tarball
  echo '#!/bin/sh' > "$BIN_DIR/antigravity"   # a regular file we did not create
  ( TMPDIR="$T" main --desktop --no-apt --no-nautilus ) >/dev/null 2>&1 && return 1
  assert_eq "$(cat "$BIN_DIR/antigravity")" "#!/bin/sh"
}

# --- runner -------------------------------------------------------------------

# Each test runs in its own bash process: errexit is ignored inside a subshell
# that sits in an `if` condition, which would let failing assertions pass.
if [ "${1:-}" = "--run" ]; then
  set -euo pipefail
  setup
  "$2"
  exit 0
fi

passed=0; failed=0; failures=()
for name in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  if out=$(bash "${BASH_SOURCE[0]}" --run "$name" 2>&1); then
    passed=$((passed + 1)); printf 'ok   %s\n' "$name"
  else
    failed=$((failed + 1)); failures+=("$name"); printf 'FAIL %s\n%s\n' "$name" "$out"
  fi
done
printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
