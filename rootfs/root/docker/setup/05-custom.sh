#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202604221922-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@Copyright        :  Copyright 2026 CasjaysDev
# @@Created          :  Wed Apr 22 07:22:57 PM EDT 2026
# @@File             :  05-custom.sh
# @@Description      :  script to run custom
# @@Changelog        :  newScript
# @@TODO             :  Refactor code
# @@Other            :  N/A
# @@Resource         :  N/A
# @@Terminal App     :  yes
# @@sudo/root        :  yes
# @@Template         :  templates/dockerfiles/init_scripts/05-custom.sh
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

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script

# Install Go developer tools into /usr/local/bin so they are on PATH
# without pulling GOPATH/bin into the runtime image. CGO disabled so the
# tools themselves are fully static (matches the image default).
export GOPATH="${GOPATH:-/usr/local/share/go}"
export GOBIN="/usr/local/bin"
export PATH="${GOBIN}:${PATH}"
export CGO_ENABLED=0
export GOTOOLCHAIN=auto
export GOMAXPROCS="${GOMAXPROCS:-2}"
export GOMEMLIMIT="${GOMEMLIMIT:-1GiB}"
export GOFLAGS="${GOFLAGS:+${GOFLAGS} }-p=1"
mkdir -p "$GOPATH" "$GOPATH/bin" "$GOPATH/cache" "$GOPATH/pkg/mod"

if command -v go >/dev/null 2>&1; then
  echo "Installing Go developer tools with $(go version)"
  tool_install_count=0

  install_go_tool() {
    local tool="$1"

    echo "go install $tool"
    # Best-effort: don't fail the build if a single upstream tool has
    # stale deps incompatible with the current Go release. The rest of
    # the kitchen-sink installs cleanly and the user can manually
    # `go install` whichever tools they need at runtime against their
    # own version pin.
    go install "$tool" || echo "  WARN: skipping $tool (install failed)" >&2

    tool_install_count=$((tool_install_count + 1))
    if [ "$tool_install_count" -ge 5 ]; then
      go clean -cache -testcache 2>/dev/null || true
      tool_install_count=0
    fi
  }

  for tool in \
    "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest" \
    "golang.org/x/tools/gopls@latest" \
    "golang.org/x/tools/cmd/goimports@latest" \
    "golang.org/x/tools/cmd/stringer@latest" \
    "golang.org/x/tools/cmd/godoc@latest" \
    "golang.org/x/tools/cmd/deadcode@latest" \
    "golang.org/x/tools/cmd/callgraph@latest" \
    "golang.org/x/tools/cmd/guru@latest" \
    "golang.org/x/tools/cmd/gorename@latest" \
    "golang.org/x/lint/golint@latest" \
    "golang.org/x/perf/cmd/benchstat@latest" \
    "github.com/go-delve/delve/cmd/dlv@latest" \
    "mvdan.cc/gofumpt@latest" \
    "honnef.co/go/tools/cmd/staticcheck@latest" \
    "golang.org/x/vuln/cmd/govulncheck@latest" \
    "github.com/air-verse/air@latest" \
    "go.uber.org/mock/mockgen@latest" \
    "github.com/swaggo/swag/cmd/swag@latest" \
    "google.golang.org/protobuf/cmd/protoc-gen-go@latest" \
    "google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest" \
    "github.com/kisielk/errcheck@latest" \
    "github.com/gordonklaus/ineffassign@latest" \
    "github.com/fzipp/gocyclo/cmd/gocyclo@latest" \
    "github.com/securego/gosec/v2/cmd/gosec@latest" \
    "github.com/cweill/gotests/gotests@latest" \
    "github.com/josharian/impl@latest" \
    "github.com/fatih/gomodifytags@latest" \
    "gotest.tools/gotestsum@latest" \
    "github.com/kyoh86/richgo@latest" \
    "github.com/goreleaser/goreleaser/v2@latest" \
    "github.com/vektra/mockery/v2@latest" \
    "github.com/google/wire/cmd/wire@latest" \
    "github.com/sqlc-dev/sqlc/cmd/sqlc@latest" \
    "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest" \
    "github.com/bufbuild/buf/cmd/buf@latest" \
    "github.com/go-task/task/v3/cmd/task@latest" \
    "github.com/google/ko@latest" \
    "github.com/magefile/mage@latest" \
    "github.com/pressly/goose/v3/cmd/goose@latest" \
    "github.com/mgechev/revive@latest" \
    "github.com/daixiang0/gci@latest" \
    "github.com/segmentio/golines@latest" \
    "go.uber.org/nilaway/cmd/nilaway@latest" \
    "github.com/jstemmer/go-junit-report/v2@latest" \
    "github.com/boumenot/gocover-cobertura@latest" \
    "github.com/jandelgado/gcov2lcov@latest" \
    "github.com/google/gops@latest" \
    "github.com/dmarkham/enumer@latest" \
    "github.com/mailru/easyjson/easyjson@latest" \
    "github.com/envoyproxy/protoc-gen-validate@latest" \
    "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest" \
    "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@latest" \
    ; do
    install_go_tool "$tool"
  done

  # migrate: needs build tags for DB driver compilation. Limited to
  # the common pure-Go drivers (postgres, pgx, mysql, sqlite) - the
  # full driver set (cockroachdb, spanner, clickhouse, mongodb,
  # redshift) pulls in ~2GB of transitive deps and has been observed
  # to crash bash mid-compile inside resource-constrained build
  # environments. Users who need those drivers can rebuild migrate at
  # runtime with whatever tags they need.
  echo "go install golang-migrate/migrate (pure-Go drivers)"
  go install -tags 'postgres,pgx,mysql,sqlite' \
    github.com/golang-migrate/migrate/v4/cmd/migrate@latest \
    || echo "  WARN: skipping migrate (install failed)" >&2

  # Drop the module cache; it's not needed in the final image.
  go clean -testcache 2>/dev/null || true
  go clean -modcache 2>/dev/null || true
  go clean -cache 2>/dev/null || true
  rm -rf "$GOPATH/pkg" "$GOPATH/src" 2>/dev/null || true
else
  echo "go binary not found; skipping Go dev tools" >&2
fi

# Always succeed: tool installation is best-effort, the build environment
# is functional even if some optional dev tools didn't make it. The Go
# toolchain itself was already verified by 02-packages.sh.
exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
