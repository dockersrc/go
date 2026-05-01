#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202604221922-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Wed Apr 22 07:22:57 PM EDT 2026
# @@File             :  03-files.sh
# @@Description      :  script to run files
# @@Changelog        :  newScript
# @@TODO             :  Refactor code
# @@Other            :  N/A
# @@Resource         :  N/A
# @@Terminal App     :  yes
# @@sudo/root        :  yes
# @@Template         :  templates/dockerfiles/init_scripts/03-files.sh
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
if [ -d "/tmp/bin" ]; then
  mkdir -p "/usr/local/bin"
  for bin in "/tmp/bin"/*; do
    name="$(basename -- "$bin")"
    echo "Installing $name to /usr/local/bin/$name"
    copy "$bin" "/usr/local/bin/$name"
    chmod -f +x "/usr/local/bin/$name"
  done
fi
unset bin
if [ -d "/tmp/var" ]; then
  for var in "/tmp/var"/*; do
    name="$(basename -- "$var")"
    echo "Installing $var to /var/$name"
    if [ -d "$var" ]; then
      mkdir -p "/var/$name"
      copy "$var/." "/var/$name/"
    else
      copy "$var" "/var/$name"
    fi
  done
fi
unset var
if [ -d "/tmp/etc" ]; then
  for config in "/tmp/etc"/*; do
    name="$(basename -- "$config")"
    echo "Installing $config to /etc/$name"
    if [ -d "$config" ]; then
      mkdir -p "/etc/$name"
      copy "$config/." "/etc/$name/"
      mkdir -p "/usr/local/share/template-files/config/$name"
      copy "$config/." "/usr/local/share/template-files/config/$name/"
    else
      copy "$config" "/etc/$name"
      copy "$config" "/usr/local/share/template-files/config/$name"
    fi
  done
fi
unset config
if [ -d "/tmp/data" ]; then
  for data in "/tmp/data"/*; do
    name="$(basename -- "$data")"
    echo "Installing $data to /usr/local/share/template-files/data"
    if [ -d "$data" ]; then
      mkdir -p "/usr/local/share/template-files/data/$name"
      copy "$data/." "/usr/local/share/template-files/data/$name/"
    else
      copy "$data" "/usr/local/share/template-files/data/$name"
    fi
  done
fi
unset data
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script

# Create conventional Go project dirs. Users can mount their code into
# any of these; WORKDIR defaults to /app.
for dir in /app /work /root/app /root/project; do
  mkdir -p "$dir"
  chmod 0755 "$dir"
done

# Canonical Go state dir (FHS-style: arch-independent shared data);
# declared as a Docker VOLUME for cross-rebuild persistence. The paths
# /go, /root/go, /root/.go, /root/.local/share/go are symlinks to this
# location so any of the conventional GOPATH paths resolve here. /data/go
# is symlinked at runtime by the init script (since /data is a volume).
GO_STATE_DIR="/usr/local/share/go"
mkdir -p "${GO_STATE_DIR}/bin" "${GO_STATE_DIR}/cache" "${GO_STATE_DIR}/pkg/mod"
chmod -R 0755 "${GO_STATE_DIR}"
mkdir -p /root/.local/share
for link in /go /root/go /root/.go /root/.local/share/go; do
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    rm -rf "$link"
  fi
  ln -sfn "${GO_STATE_DIR}" "$link"
done
unset GO_STATE_DIR link

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
#exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
