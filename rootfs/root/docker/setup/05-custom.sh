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

# Return the latest tag from a GitHub release API
_gh_latest() {
  local repo="$1"
  local filter="${2:-.tag_name}"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r "${filter}"
}

# Download a tar.gz release asset, extract a single binary, install to GOBIN_DIR
# Usage: _install_tar <url> <binary-name-in-archive> [<subdir-prefix>]
_install_tar() {
  local url="$1"
  local bin="$2"
  local prefix="${3:-}"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -C "$tmp" -xz
  if [ -n "$prefix" ]; then
    install -m 0755 "${tmp}/${prefix}/${bin}" "${GOBIN_DIR}/${bin}"
  else
    # Binary may be in a subdirectory; find it
    local found
    found="$(find "$tmp" -name "$bin" -type f | head -1)"
    install -m 0755 "$found" "${GOBIN_DIR}/${bin}"
  fi
  rm -rf "$tmp"
}

# Download a single binary release asset directly to GOBIN_DIR
# Usage: _install_bin <url> <installed-name>
_install_bin() {
  local url="$1"
  local name="$2"
  curl -fsSL "$url" -o "${GOBIN_DIR}/${name}"
  chmod 0755 "${GOBIN_DIR}/${name}"
}

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Architecture detection

# Go convention (used by gopls, govulncheck tarballs)
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

# uname -m verbatim (used by buf, goreleaser aarch64 vs arm64 assets)
_UNAME_M="$(uname -m)"

# goreleaser / ko / gotestsum / goose use x86_64 / arm64 (not aarch64)
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

# goreleaser — release automation
_GR_VER="$(_gh_latest goreleaser/goreleaser)"
_GR_TAG="${_GR_VER#v}"
_install_tar \
  "https://github.com/goreleaser/goreleaser/releases/download/${_GR_VER}/goreleaser_Linux_${_ARCH_GLIBC}.tar.gz" \
  "goreleaser"

# golangci-lint — meta-linter (official installer writes to /usr/local/bin)
curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
  | sh -s -- -b "${GOBIN_DIR}" latest

# staticcheck — standalone advanced static analyser
_SC_VER="$(_gh_latest dominikh/go-tools .tag_name)"
_install_tar \
  "https://github.com/dominikh/go-tools/releases/download/${_SC_VER}/staticcheck_linux_${_GOARCH}.tar.gz" \
  "staticcheck"

# gofumpt — stricter formatter
_GF_VER="$(_gh_latest mvdan/gofumpt)"
_install_bin \
  "https://github.com/mvdan/gofumpt/releases/download/${_GF_VER}/gofumpt_linux_${_GOARCH}" \
  "gofumpt"

# gotestsum — structured test runner
_GTS_VER="$(_gh_latest gotestyourself/gotestsum)"
_GTS_TAG="${_GTS_VER#v}"
_install_tar \
  "https://github.com/gotestyourself/gotestsum/releases/download/${_GTS_VER}/gotestsum_${_GTS_TAG}_linux_${_ARCH_GLIBC}.tar.gz" \
  "gotestsum"

# ko — build Go container images without a Dockerfile
_KO_VER="$(_gh_latest google/ko)"
_KO_TAG="${_KO_VER#v}"
_install_tar \
  "https://github.com/google/ko/releases/download/${_KO_VER}/ko_${_KO_TAG}_Linux_${_ARCH_GLIBC}.tar.gz" \
  "ko"

# air — live-reload dev server
_AIR_VER="$(_gh_latest air-verse/air)"
_install_bin \
  "https://github.com/air-verse/air/releases/download/${_AIR_VER}/air_linux_${_GOARCH}" \
  "air"

# buf — modern protobuf toolchain
# buf uses x86_64 / aarch64 (uname -m style)
_BUF_VER="$(_gh_latest bufbuild/buf)"
_install_bin \
  "https://github.com/bufbuild/buf/releases/download/${_BUF_VER}/buf-Linux-${_UNAME_M}" \
  "buf"

# goose — DB migration runner
_GOOSE_VER="$(_gh_latest pressly/goose)"
_GOOSE_TAG="${_GOOSE_VER#v}"
_install_bin \
  "https://github.com/pressly/goose/releases/download/${_GOOSE_VER}/goose_linux_${_ARCH_GLIBC}" \
  "goose"

# gopls — Go language server
_GOPLS_VER="$(curl -fsSL 'https://api.github.com/repos/golang/tools/tags?per_page=50' \
  | jq -r '[.[] | select(.name | startswith("gopls/v"))] | .[0].name | ltrimstr("gopls/")')"
_install_tar \
  "https://github.com/golang/tools/releases/download/gopls%2F${_GOPLS_VER}/gopls_${_GOPLS_VER}_linux_${_GOARCH}.tar.gz" \
  "gopls"

# govulncheck — vulnerability scanner
_VULN_VER="$(curl -fsSL 'https://api.github.com/repos/golang/vuln/releases/latest' | jq -r '.tag_name')"
_install_tar \
  "https://github.com/golang/vuln/releases/download/${_VULN_VER}/govulncheck_${_VULN_VER}_linux_${_GOARCH}.tar.gz" \
  "govulncheck"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# go install for tools without standalone release binaries

echo "Installing Go tooling via go install"

# Import organiser — superset of gofmt that also manages import groups
go install golang.org/x/tools/cmd/goimports@latest

# Generate String() methods for iota-based types
go install golang.org/x/tools/cmd/stringer@latest

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
