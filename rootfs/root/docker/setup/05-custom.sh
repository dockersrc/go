#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605292220-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Fri May 29 10:20:10 PM EDT 2026
# @@File             :  05-custom.sh
# @@Description      :  Install Go latest and Go tooling
# @@Changelog        :  Add Go install and toolchain setup
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
# Predefined actions

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script

# Map uname -m to the Go download architecture suffix
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

# Fetch the latest stable Go version string from the official download API
_GO_VERSION="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version')"
echo "Installing ${_GO_VERSION} (linux/${_GOARCH})"

# Remove any prior installation and extract the new tarball
rm -rf "${GOINSTALL_DIR}"
curl -fsSL "https://dl.google.com/go/${_GO_VERSION}.linux-${_GOARCH}.tar.gz" | tar -C /usr/local -xz

# Symlink the core binaries so they are found without /usr/local/go/bin in PATH
ln -sf "${GOINSTALL_DIR}/bin/go" "${GOBIN_DIR}/go"
ln -sf "${GOINSTALL_DIR}/bin/gofmt" "${GOBIN_DIR}/gofmt"

# Wire up the environment for the tool installation that follows
export GOPATH="${GOPATH_DIR}"
export GOBIN="${GOBIN_DIR}"
export PATH="${GOINSTALL_DIR}/bin:${PATH}"
export GOCACHE="${GOCACHE_BUILD}"
export CGO_ENABLED="0"
export GOTOOLCHAIN="auto"

# Ensure the GOPATH directory tree exists
mkdir -p "${GOPATH_DIR}/pkg/mod" "${GOPATH_DIR}/cache" "${GOPATH_DIR}/bin"

echo "Installing Go tooling (GOBIN=${GOBIN_DIR})"

# Language server - editor integration (VSCode, Neovim, etc.)
go install golang.org/x/tools/gopls@latest

# Import organiser - superset of gofmt that also manages import groups
go install golang.org/x/tools/cmd/goimports@latest

# Stricter formatter used by many golangci-lint configs
go install mvdan.cc/gofumpt@latest

# Generate String() methods for iota-based types
go install golang.org/x/tools/cmd/stringer@latest

# Meta-linter: runs golint, errcheck, ineffassign, gocyclo, and many more
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Standalone advanced static analyser
go install honnef.co/go/tools/cmd/staticcheck@latest

# Vulnerability scanner against the Go vulnerability database
go install golang.org/x/vuln/cmd/govulncheck@latest

# Structured test runner with better output and JUnit/JSON export
go install gotest.tools/gotestsum@latest

# Source-level debugger
go install github.com/go-delve/delve/cmd/dlv@latest

# Live-reload dev server for iterative development
go install github.com/air-verse/air@latest

# Release automation: cross-compile, sign, publish, container images
go install github.com/goreleaser/goreleaser/v2@latest

# Compile-time dependency injection code generator
go install github.com/google/wire/cmd/wire@latest

# Mock generator for interfaces (uber fork of golang/mock)
go install go.uber.org/mock/mockgen@latest

# Build Go container images without a Dockerfile
go install github.com/google/ko@latest

# protobuf Go code generator
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

# gRPC Go code generator
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

echo "Go tooling installed"

# Strip the module download cache and ephemeral build cache from this layer.
# The installed binaries in GOBIN_DIR are preserved in the image.
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
