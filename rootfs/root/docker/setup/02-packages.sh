#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202604221922-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Wed Apr 22 07:22:56 PM EDT 2026
# @@File             :  02-packages.sh
# @@Description      :  script to run packages
# @@Changelog        :  newScript
# @@TODO             :  Refactor code
# @@Other            :  N/A
# @@Resource         :  N/A
# @@Terminal App     :  yes
# @@sudo/root        :  yes
# @@Template         :  templates/dockerfiles/init_scripts/02-packages.sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
set -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set env variables
exitCode=0

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Predefined actions

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script

# Install the latest upstream Go toolchain straight from go.dev.
# We don't use apk's `go` package because Alpine often lags upstream by
# a release. Tarballs from go.dev are HTTPS-served and we additionally
# verify the SHA256 published in the same JSON catalog.
#
# Wrapped in a subshell with `set -e` so any single step (curl, jq,
# sha256sum, tar) that fails aborts the whole installer and the
# parent script returns non-zero - the Dockerfile then fails the build
# rather than silently producing a broken image.
(
  set -euo pipefail

  case "$(uname -m)" in
    x86_64)        GO_ARCH="amd64" ;;
    aarch64)       GO_ARCH="arm64" ;;
    armv7l|armv6l) GO_ARCH="armv6l" ;;
    i386|i686)     GO_ARCH="386" ;;
    ppc64le)       GO_ARCH="ppc64le" ;;
    s390x)         GO_ARCH="s390x" ;;
    riscv64)       GO_ARCH="riscv64" ;;
    *)
      echo "Unsupported architecture for upstream Go install: $(uname -m)" >&2
      exit 1
      ;;
  esac

  GO_DL_INDEX="https://go.dev/dl/?mode=json"
  GO_INDEX_JSON="$(curl -fsSL "$GO_DL_INDEX")"
  # `// empty` makes jq emit nothing (instead of the literal string
  # "null") when the path is missing, so the [ -z ... ] check below
  # actually catches resolution failures.
  GO_VERSION="$(printf '%s' "$GO_INDEX_JSON" \
    | jq -r '[.[] | select(.stable == true)][0].version // empty')"
  if [ -z "$GO_VERSION" ]; then
    echo "Failed to resolve latest Go version from $GO_DL_INDEX" >&2
    exit 1
  fi
  GO_FILE="${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  GO_SHA256="$(printf '%s' "$GO_INDEX_JSON" \
    | jq -r --arg f "$GO_FILE" '[.[] | select(.stable == true)][0].files[] | select(.filename == $f) | .sha256 // empty')"
  if [ -z "$GO_SHA256" ]; then
    echo "Failed to resolve sha256 for $GO_FILE from $GO_DL_INDEX" >&2
    exit 1
  fi

  echo "Installing upstream ${GO_VERSION} for linux/${GO_ARCH}"
  curl -fsSL "https://go.dev/dl/${GO_FILE}" -o "/tmp/${GO_FILE}"
  echo "${GO_SHA256}  /tmp/${GO_FILE}" | sha256sum -c -

  rm -rf /usr/local/go
  tar -C /usr/local -xzf "/tmp/${GO_FILE}"
  rm -f "/tmp/${GO_FILE}"

  # Expose go + gofmt on PATH (the rest of the Go-shipped tools are
  # invoked through `go tool ...` and don't need symlinks).
  ln -sf /usr/local/go/bin/go    /usr/local/bin/go
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

  # Sanity-check the install before subsequent setup steps depend on it.
  /usr/local/bin/go version

  # Trim ~70MB of test data and API definitions that aren't useful at
  # build/run time. Stdlib sources stay (needed for `go build`).
  rm -rf /usr/local/go/test /usr/local/go/api /usr/local/go/doc
)
__go_install_rc=$?
# Note: this is intentionally a separate statement, not `(...) || exit`.
# Bash silently disables `set -e` inside an explicit subshell when the
# subshell appears on the left of && or ||, so the form below is the
# only reliable way to propagate set -e failures from the subshell.
if [ "$__go_install_rc" -ne 0 ]; then
  exit "$__go_install_rc"
fi
unset __go_install_rc

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
#exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
