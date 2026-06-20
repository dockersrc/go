#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202506192219-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  00-go.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 29, 2026 22:22 EDT
# @@File             :  00-go.sh
# @@Description      :  Go toolchain — placeholder init (no daemon)
# - - - - - - - - - - - - - - - - - - - - - - - - -
# This file must exist. __start_init_scripts spawns an infinite keep-alive loop
# when init_count == 0 (no scripts in init.d/). Go is not a daemon — we just
# need one script so init_count >= 1. SERVICE_USES_PID is set in the env file
# (go.sh) which the parent shell reads; exports here are subshell-isolated and
# would not propagate back to the entrypoint anyway.
