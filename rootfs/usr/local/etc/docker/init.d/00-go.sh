#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605292219-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  00-go.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 29, 2026 22:22 EDT
# @@File             :  00-go.sh
# @@Description      :  Go toolchain — configuration-only init (no daemon)
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Tell the init framework this is a configuration service, not a daemon.
# This prevents __start_init_scripts from waiting for a PID or keep-alive loop.
export CONTAINER_INIT="yes"
export SERVICE_USES_PID="no"
