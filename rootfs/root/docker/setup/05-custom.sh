#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607271500-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  WTFPL
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Mon Jul 27 03:00:00 PM EDT 2026
# @@File             :  05-custom.sh
# @@Description      :  Install Go latest and Go tooling
# @@Changelog        :  Restored after being wiped to the empty template by an unrelated doc-migration commit
# @@TODO             :  N/A
# @@Other            :  N/A
# @@Resource         :  https://go.dev/dl/
# @@Terminal App     :  yes
# @@sudo/root        :  yes
# @@Template         :  templates/dockerfiles/init_scripts/05-custom.sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
set -eo pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS
# Force IPv4 for all curl calls in this script — the base image IPv6 routing
# intercepts *.github.com and presents a cert for casjay.in, causing SAN mismatch
printf -- '-4\n' > /root/.curlrc
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set env variables
VERSION="202607271500-git"
CUSTOM_EXITCODE=0

# Installation root for the Go distribution (not GOPATH)
CUSTOM_GOINSTALL_DIR="/usr/local/go"
# GOPATH: module cache, pkg index, user-installed binaries (declared VOLUME)
CUSTOM_GOPATH_DIR="/usr/local/share/go"
# Baked-in tool binaries land here so they are on the default PATH
CUSTOM_GOBIN_DIR="/usr/local/bin"
# Throwaway build cache used only during this image build layer
CUSTOM_GOCACHE_BUILD="/tmp/go-build-cache"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Helpers

# Return the latest release tag from GitHub; retries up to 3 times on transient errors
# (rate-limit 403s are common in parallel multi-platform builds without a token).
# Set GITHUB_TOKEN to raise the authenticated rate limit (5000 req/hr vs 60 req/hr).
__gh_latest() {
  local repo="$1"
  local filter="${2:-.tag_name}"
  local auth_header=""
  [ -n "${GITHUB_TOKEN:-}" ] && auth_header="-H Authorization: token ${GITHUB_TOKEN}"
  local ver attempt
  for attempt in 1 2 3; do
    # shellcheck disable=SC2206
    ver="$(curl -fsSL ${auth_header:+$auth_header} "https://api.github.com/repos/${repo}/releases/latest" | jq -r "${filter}")"
    if [ -n "$ver" ] && [ "$ver" != "null" ]; then
      echo "$ver"
      return 0
    fi
    if [ "$attempt" -lt 3 ]; then
      echo "  rate-limited on ${repo} (attempt ${attempt}/3) — retrying in 60s..." >&2
      sleep 60
    fi
  done
  echo "ERROR: could not resolve latest version for ${repo} after 3 attempts" >&2
  exit 1
}

# Download a tar.gz asset, find a named binary anywhere inside, install to CUSTOM_GOBIN_DIR
__install_tar() {
  local url="$1"
  local bin="$2"
  local tmp
  tmp="$(mktemp -d)"
  echo "  → ${bin} from ${url##*/}"
  curl -fsSL "$url" | tar -C "$tmp" -xz
  local found
  found="$(find "$tmp" -name "$bin" -type f | head -1)"
  if [ -z "$found" ]; then
    echo "ERROR: binary '${bin}' not found in archive ${url##*/}" >&2
    rm -rf "$tmp"
    exit 1
  fi
  install -m 0755 "$found" "${CUSTOM_GOBIN_DIR}/${bin}"
  rm -rf "$tmp"
}

# Download a single binary asset directly to CUSTOM_GOBIN_DIR
__install_bin() {
  local url="$1"
  local name="$2"
  echo "  → ${name} from ${url##*/}"
  curl -fsSL "$url" -o "${CUSTOM_GOBIN_DIR}/${name}"
  chmod 0755 "${CUSTOM_GOBIN_DIR}/${name}"
}

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Architecture detection

# Go convention: amd64 / arm64 / armv6l / 386
case "$(uname -m)" in
  x86_64)    _GOARCH="amd64"   ;;
  aarch64)   _GOARCH="arm64"   ;;
  armv7l)    _GOARCH="armv6l"  ;;
  i386|i686) _GOARCH="386"     ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# uname -m verbatim: buf uses x86_64 / aarch64
_UNAME_M="$(uname -m)"

# goreleaser / ko / goose use x86_64 / arm64 (arm64 not aarch64)
if [ "$_UNAME_M" = "aarch64" ]; then
  _ARCH_GLIBC="arm64"
else
  _ARCH_GLIBC="$_UNAME_M"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Install Go distribution

_GO_VERSION="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version')"
echo "Installing ${_GO_VERSION} (linux/${_GOARCH})"

rm -rf "${CUSTOM_GOINSTALL_DIR}"
curl -fsSL "https://dl.google.com/go/${_GO_VERSION}.linux-${_GOARCH}.tar.gz" | tar -C /usr/local -xz

ln -sf "${CUSTOM_GOINSTALL_DIR}/bin/go" "${CUSTOM_GOBIN_DIR}/go"
ln -sf "${CUSTOM_GOINSTALL_DIR}/bin/gofmt" "${CUSTOM_GOBIN_DIR}/gofmt"

export GOPATH="${CUSTOM_GOPATH_DIR}"
export GOBIN="${CUSTOM_GOBIN_DIR}"
export PATH="${CUSTOM_GOINSTALL_DIR}/bin:${PATH}"
export GOCACHE="${CUSTOM_GOCACHE_BUILD}"
export CGO_ENABLED="0"
export GOTOOLCHAIN="auto"

mkdir -p "${CUSTOM_GOPATH_DIR}/pkg/mod" "${CUSTOM_GOPATH_DIR}/cache" "${CUSTOM_GOPATH_DIR}/bin"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Pre-built binary installs (fast — no compilation)

echo "Installing pre-built tools"

# goreleaser — release automation (Linux/x86_64 or Linux/arm64)
_GR_VER="$(__gh_latest goreleaser/goreleaser)"
__install_tar \
  "https://github.com/goreleaser/goreleaser/releases/download/${_GR_VER}/goreleaser_Linux_${_ARCH_GLIBC}.tar.gz" \
  "goreleaser"

# golangci-lint — meta-linter (official installer handles its own version resolution)
curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
  | sh -s -- -b "${CUSTOM_GOBIN_DIR}" latest

# staticcheck — standalone advanced static analyser (linux_amd64 / linux_arm64)
_SC_VER="$(__gh_latest dominikh/go-tools)"
__install_tar \
  "https://github.com/dominikh/go-tools/releases/download/${_SC_VER}/staticcheck_linux_${_GOARCH}.tar.gz" \
  "staticcheck"

# gofumpt — stricter formatter; asset name includes version: gofumpt_v0.x.y_linux_amd64
_GF_VER="$(__gh_latest mvdan/gofumpt)"
__install_bin \
  "https://github.com/mvdan/gofumpt/releases/download/${_GF_VER}/gofumpt_${_GF_VER}_linux_${_GOARCH}" \
  "gofumpt"

# gotestsum — structured test runner; asset uses amd64/arm64 (not x86_64)
_GTS_VER="$(__gh_latest gotestyourself/gotestsum)"
_GTS_TAG="${_GTS_VER#v}"
__install_tar \
  "https://github.com/gotestyourself/gotestsum/releases/download/${_GTS_VER}/gotestsum_${_GTS_TAG}_linux_${_GOARCH}.tar.gz" \
  "gotestsum"

# ko — build Go container images without a Dockerfile (Linux/x86_64 or Linux/arm64)
_KO_VER="$(__gh_latest google/ko)"
_KO_TAG="${_KO_VER#v}"
__install_tar \
  "https://github.com/google/ko/releases/download/${_KO_VER}/ko_${_KO_TAG}_Linux_${_ARCH_GLIBC}.tar.gz" \
  "ko"

# air — live-reload dev server; asset: air_1.x.y_linux_amd64 (version without v prefix)
_AIR_VER="$(__gh_latest air-verse/air)"
_AIR_TAG="${_AIR_VER#v}"
__install_bin \
  "https://github.com/air-verse/air/releases/download/${_AIR_VER}/air_${_AIR_TAG}_linux_${_GOARCH}" \
  "air"

# buf — modern protobuf toolchain; uses x86_64/aarch64 (uname -m convention)
_BUF_VER="$(__gh_latest bufbuild/buf)"
__install_bin \
  "https://github.com/bufbuild/buf/releases/download/${_BUF_VER}/buf-Linux-${_UNAME_M}" \
  "buf"

# goose — DB migration runner (linux_x86_64 or linux_arm64)
_GOOSE_VER="$(__gh_latest pressly/goose)"
__install_bin \
  "https://github.com/pressly/goose/releases/download/${_GOOSE_VER}/goose_linux_${_ARCH_GLIBC}" \
  "goose"

# go install tools (goimports, stringer, gopls, govulncheck, dlv, gops, benchstat,
# wire, mockgen, protoc-gen-go, protoc-gen-go-grpc) are cross-compiled natively on
# the build platform in the Dockerfile go-tools stage and copied to /usr/local/bin
# before this script runs — no QEMU-emulated compilation needed here.

# Strip the module download cache and ephemeral build cache from this layer
go clean -modcache
go clean -cache
rm -rf "${CUSTOM_GOCACHE_BUILD}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
CUSTOM_EXITCODE=$?
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit $CUSTOM_EXITCODE
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
