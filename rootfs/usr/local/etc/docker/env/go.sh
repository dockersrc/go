# Go toolchain image — pre-set service-discovery vars to skip __find_* subprocess forks
# The entrypoint sources this before the ${VAR:-$(function)} expansions, so each
# non-empty assignment here silently short-circuits the matching find call.
PHP_INI_DIR="none"
PHP_BIN_DIR="none"
HTTPD_CONFIG_FILE="none"
NGINX_CONFIG_FILE="none"
MYSQL_CONFIG_FILE="none"
PGSQL_CONFIG_FILE="none"
MONGODB_CONFIG_FILE="none"

# This image has no long-running daemon; suppress the startup banner and health loop
ENTRYPOINT_MESSAGE="no"
HEALTH_ENABLED="no"
