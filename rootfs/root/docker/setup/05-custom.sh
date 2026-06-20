#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202606010000-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Fri May 29 10:20:10 PM EDT 2026
# @@File             :  05-custom.sh
# @@Description      :  Install Go latest and Go tooling
# @@Changelog        :  Use pre-built binaries where available; go install for the rest
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
exitCode=0

# Installation root for the Go distribution (not GOPATH)
GOINSTALL_DIR="/usr/local/go"
# GOPATH: module cache, pkg index, user-installed binaries (declared VOLUME)
GOPATH_DIR="/usr/local/share/go"
# Baked-in tool binaries land here so they are on the default PATH
GOBIN_DIR="/usr/local/bin"
# Throwaway build cache used only during this image build layer
GOCACHE_BUILD="/tmp/go-build-cache"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Helpers

# Return the latest release tag from GitHub; exits 1 if the version cannot be resolved
_gh_latest() {
  local repo="$1"
  local filter="${2:-.tag_name}"
  local auth_header=""
  [ -n "${GITHUB_TOKEN:-}" ] && auth_header="-H Authorization: token ${GITHUB_TOKEN}"
  # shellcheck disable=SC2206
  local ver
  ver="$(curl -fsSL ${auth_header:+$auth_header} "https://api.github.com/repos/${repo}/releases/latest" | jq -r "${filter}")"
  if [ -z "$ver" ] || [ "$ver" = "null" ]; then
    echo "ERROR: could not resolve latest version for ${repo}" >&2
    exit 1
  fi
  echo "$ver"
}

# Download a tar.gz asset, find a named binary anywhere inside, install to GOBIN_DIR
_install_tar() {
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
  install -m 0755 "$found" "${GOBIN_DIR}/${bin}"
  rm -rf "$tmp"
}

# Download a single binary asset directly to GOBIN_DIR
_install_bin() {
  local url="$1"
  local name="$2"
  echo "  → ${name} from ${url##*/}"
  curl -fsSL "$url" -o "${GOBIN_DIR}/${name}"
  chmod 0755 "${GOBIN_DIR}/${name}"
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

rm -rf "${GOINSTALL_DIR}"
curl -fsSL "https://dl.google.com/go/${_GO_VERSION}.linux-${_GOARCH}.tar.gz" | tar -C /usr/local -xz

ln -sf "${GOINSTALL_DIR}/bin/go" "${GOBIN_DIR}/go"
ln -sf "${GOINSTALL_DIR}/bin/gofmt" "${GOBIN_DIR}/gofmt"

export GOPATH="${GOPATH_DIR}"
export GOBIN="${GOBIN_DIR}"
export PATH="${GOINSTALL_DIR}/bin:${PATH}"
export GOCACHE="${GOCACHE_BUILD}"
export CGO_ENABLED="0"
export GOTOOLCHAIN="auto"

mkdir -p "${GOPATH_DIR}/pkg/mod" "${GOPATH_DIR}/cache" "${GOPATH_DIR}/bin"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Pre-built binary installs (fast — no compilation)

echo "Installing pre-built tools"

# goreleaser — release automation (Linux/x86_64 or Linux/arm64)
_GR_VER="$(_gh_latest goreleaser/goreleaser)"
_install_tar \
  "https://github.com/goreleaser/goreleaser/releases/download/${_GR_VER}/goreleaser_Linux_${_ARCH_GLIBC}.tar.gz" \
  "goreleaser"

# golangci-lint — meta-linter (official installer handles its own version resolution)
curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
  | sh -s -- -b "${GOBIN_DIR}" latest

# staticcheck — standalone advanced static analyser (linux_amd64 / linux_arm64)
_SC_VER="$(_gh_latest dominikh/go-tools)"
_install_tar \
  "https://github.com/dominikh/go-tools/releases/download/${_SC_VER}/staticcheck_linux_${_GOARCH}.tar.gz" \
  "staticcheck"

# gofumpt — stricter formatter; asset name includes version: gofumpt_v0.x.y_linux_amd64
_GF_VER="$(_gh_latest mvdan/gofumpt)"
_install_bin \
  "https://github.com/mvdan/gofumpt/releases/download/${_GF_VER}/gofumpt_${_GF_VER}_linux_${_GOARCH}" \
  "gofumpt"

# gotestsum — structured test runner; asset uses amd64/arm64 (not x86_64)
_GTS_VER="$(_gh_latest gotestyourself/gotestsum)"
_GTS_TAG="${_GTS_VER#v}"
_install_tar \
  "https://github.com/gotestyourself/gotestsum/releases/download/${_GTS_VER}/gotestsum_${_GTS_TAG}_linux_${_GOARCH}.tar.gz" \
  "gotestsum"

# ko — build Go container images without a Dockerfile (Linux/x86_64 or Linux/arm64)
_KO_VER="$(_gh_latest google/ko)"
_KO_TAG="${_KO_VER#v}"
_install_tar \
  "https://github.com/google/ko/releases/download/${_KO_VER}/ko_${_KO_TAG}_Linux_${_ARCH_GLIBC}.tar.gz" \
  "ko"

# air — live-reload dev server; asset: air_1.x.y_linux_amd64 (version without v prefix)
_AIR_VER="$(_gh_latest air-verse/air)"
_AIR_TAG="${_AIR_VER#v}"
_install_bin \
  "https://github.com/air-verse/air/releases/download/${_AIR_VER}/air_${_AIR_TAG}_linux_${_GOARCH}" \
  "air"

# buf — modern protobuf toolchain; uses x86_64/aarch64 (uname -m convention)
_BUF_VER="$(_gh_latest bufbuild/buf)"
_install_bin \
  "https://github.com/bufbuild/buf/releases/download/${_BUF_VER}/buf-Linux-${_UNAME_M}" \
  "buf"

# goose — DB migration runner (linux_x86_64 or linux_arm64)
_GOOSE_VER="$(_gh_latest pressly/goose)"
_install_bin \
  "https://github.com/pressly/goose/releases/download/${_GOOSE_VER}/goose_linux_${_ARCH_GLIBC}" \
  "goose"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# go install for tools without standalone release binaries

echo "Installing Go tooling via go install"

# Import organiser — superset of gofmt that also manages import groups
go install golang.org/x/tools/cmd/goimports@latest

# Generate String() methods for iota-based types
go install golang.org/x/tools/cmd/stringer@latest

# Official Go language server (no binary releases; must compile)
go install golang.org/x/tools/gopls@latest

# Vulnerability scanner against the Go vulnerability database
go install golang.org/x/vuln/cmd/govulncheck@latest

# Source-level debugger
go install github.com/go-delve/delve/cmd/dlv@latest

# Live process diagnostics: list Go processes, dump stacks, force GC
go install github.com/google/gops@latest

# Benchmark comparison — statistically sound diff of pprof benchmark runs
go install golang.org/x/perf/cmd/benchstat@latest

# Compile-time dependency injection code generator
go install github.com/google/wire/cmd/wire@latest

# Mock generator for interfaces (Uber fork of golang/mock)
go install go.uber.org/mock/mockgen@latest

# protobuf Go code generator
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

# gRPC Go code generator
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

echo "Go tooling installed"

# Strip the module download cache and ephemeral build cache from this layer
go clean -modcache
go clean -cache
rm -rf "${GOCACHE_BUILD}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
