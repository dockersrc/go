#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202511291200-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@ReadME           :
# @@Copyright        :  Copyright 2023 CasjaysDev
# @@Created          :  Mon Aug 28 06:48:42 PM EDT 2023
# @@File             :  05-custom.sh
# @@Description      :  script to install Go
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck shell=bash
# shellcheck disable=SC2016
# shellcheck disable=SC2031
# shellcheck disable=SC2120
# shellcheck disable=SC2155
# shellcheck disable=SC2199
# shellcheck disable=SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
set -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set env variables
exitCode=0
LANG_VERSION="${LANG_VERSION:-latest}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Predefined actions
echo "Installing Go version: ${LANG_VERSION}"

# Install Go
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]' | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
if [ "$LANG_VERSION" = "latest" ]; then
  echo "Installing latest Go..."
  curl -fsSL "https://go.dev/dl/go${LANG_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz || exitCode=1
else
  echo "Installing Go ${LANG_VERSION}..."
  curl -fsSL "https://go.dev/dl/go${LANG_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz || exitCode=1
fi

if [ -f /tmp/go.tar.gz ]; then
  tar -C /usr/local -xzf /tmp/go.tar.gz || exitCode=1
  rm /tmp/go.tar.gz
  echo "Go installed successfully"
  /usr/local/go/bin/go version || exitCode=1
else
  echo "Go installation failed" >&2
  exitCode=1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
exit $exitCode
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
