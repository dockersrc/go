# TODO.AI.md

## script-lint findings in rootfs/usr/local/bin/entrypoint.sh (pre-existing, not fixed yet)

Found while lint-checking the START_SERVICES gate fix (commit that changed
`if [ "$START_SERVICES" = "yes" ] || [ -z "$1" ]; then` to `if [ -z "$1" ]; then`).
These predate that change and are out of scope for it — this file is regenerated
wholesale from the upstream template in AI.md Step 2, so the same issues likely
exist in the template itself and in every other dockersrc/casjaysdevdocker repo
built from it.

- [ ] line 553 (`cron` case handler): bare `exit` with no code — use `exit 0`,
  `exit 1`, or `exit "$?"` to be explicit
- [ ] line 652 (`start` case handler): bare `exit` with no code — same fix
- [ ] script header `##@Version 202607082023-git` has no matching `VERSION=`
  assignment in the script body — add `VERSION="202607082023-git"` after the
  header block to satisfy the version-stamp rule
