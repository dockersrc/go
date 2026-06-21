# go

A Docker image that ships the **latest stable Go toolchain** (fetched from
`go.dev` at build time) together with a complete set of tools for building,
testing, linting, debugging, and releasing Go projects. The image is based on
Alpine and produces fully static binaries by default (`CGO_ENABLED=0`); the
CGO build-deps (`gcc`, `musl-dev`, `openssl-dev`, etc.) are still present so
you can opt in per build.

---

## 📦 Install

```shell
docker pull casjaysdev/go:latest
```

---

## 🐳 Docker

### Default workflow — no args needed

Mount your project at `/app` and run with no arguments. The container
automatically runs the full Go workflow:

```
go mod tidy  →  gofmt -w .  →  go vet ./...  →  go test ./...  →  go build ./...
```

```shell
docker run --rm -v "$PWD:/app" casjaysdev/go:latest
```

### Production mode

Set `GO_PROD=1` to strip binaries for release: `-trimpath` removes all local
file system paths; `-ldflags=-s -w` strips the symbol table and DWARF debug
info. Applied to `go build` only — `go test` is unaffected so stack traces
stay readable.

```shell
docker run --rm -v "$PWD:/app" -e GO_PROD=1 casjaysdev/go:latest
```

### One-shot commands

Pass any command and it runs directly instead of the default workflow:

```shell
# run tests only
docker run --rm -v "$PWD:/app" casjaysdev/go:latest go test -v ./...

# lint (add --timeout for cold caches)
docker run --rm -v "$PWD:/app" casjaysdev/go:latest golangci-lint run --timeout=5m ./...

# cross-compile for arm64
docker run --rm -v "$PWD:/app" \
  -e GOOS=linux -e GOARCH=arm64 \
  casjaysdev/go:latest go build -o app-arm64 ./...

# interactive shell
docker run --rm -it -v "$PWD:/app" casjaysdev/go:latest bash

# sh -c for compound commands
docker run --rm -v "$PWD:/app" casjaysdev/go:latest sh -c 'go vet ./... && staticcheck ./...'
```

### Long-running container

```shell
docker run -d \
  --restart always \
  --name casjaysdev-go \
  --hostname go \
  -e TZ=${TIMEZONE:-America/New_York} \
  -v go-state:/usr/local/share/go \
  -v "$PWD:/app" \
  casjaysdev/go:latest \
  tail null

# exec into it
docker exec -it casjaysdev-go bash
docker exec casjaysdev-go go test ./...
docker exec casjaysdev-go golangci-lint run --timeout=5m
docker exec casjaysdev-go goreleaser release --snapshot --clean
```

### docker-compose

```yaml
services:
  go:
    image: casjaysdev/go:latest
    container_name: casjaysdev-go
    hostname: go
    command: tail null
    environment:
      - TZ=America/New_York
    volumes:
      - go-state:/usr/local/share/go
      - .:/app
    restart: always

volumes:
  go-state:
```

---

## 🔧 Included tools

### Go distribution

| Binary | Purpose |
|--------|---------|
| `go` | Go compiler and toolchain |
| `gofmt` | Standard formatter (bundled with Go) |

### Linting & static analysis

| Tool | Purpose |
|------|---------|
| `golangci-lint` | Meta-linter — runs 50+ analysers in one pass |
| `staticcheck` | Advanced static analyser (SA, QF, ST, S1 checks) |
| `govulncheck` | Vulnerability scanner against the Go vuln DB |

### Formatting & imports

| Tool | Purpose |
|------|---------|
| `goimports` | `gofmt` + automatic import grouping |
| `gofumpt` | Stricter formatter used by many golangci-lint configs |

### Testing & benchmarking

| Tool | Purpose |
|------|---------|
| `gotestsum` | Structured test runner — JUnit/JSON export, better output |
| `benchstat` | Statistically sound comparison of `go test -bench` runs |

### Debugging & diagnostics

| Tool | Purpose |
|------|---------|
| `dlv` | Delve — full Go source-level debugger |
| `gops` | Live process diagnostics — stacks, GC, process list |

### Code generation

| Tool | Purpose |
|------|---------|
| `stringer` | Generates `String()` for iota-based types |
| `wire` | Compile-time dependency injection code generator |
| `mockgen` | Interface mock generator (Uber fork of `golang/mock`) |

### Protobuf & gRPC

| Tool | Purpose |
|------|---------|
| `protoc` | Protocol Buffers compiler (system package) |
| `protoc-gen-go` | Protobuf Go code generator |
| `protoc-gen-go-grpc` | gRPC Go code generator |
| `buf` | Modern protobuf toolchain — lint, format, breaking-change detection |

### DB migrations

| Tool | Purpose |
|------|---------|
| `goose` | Go-native migration runner — supports Go and SQL migrations |

### Release & dev loop

| Tool | Purpose |
|------|---------|
| `goreleaser` | Cross-compile, sign, publish, and push container images |
| `ko` | Build Go container images without a Dockerfile |
| `air` | Live-reload dev server for iterative development |

### Language server

| Tool | Purpose |
|------|---------|
| `gopls` | Official Go language server — editor integration |

---

## ⚙️ Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GOPATH` | `/usr/local/share/go` | Workspace; declared as `VOLUME` |
| `GOBIN` | `/usr/local/bin` | Destination for `go install` binaries |
| `GOCACHE` | `/usr/local/share/go/cache` | Build cache (persisted in volume) |
| `CGO_ENABLED` | `0` | Static builds by default — override per build |
| `GOTOOLCHAIN` | `auto` | Auto-fetch the Go version declared in `go.mod` |
| `GOFLAGS` | `-buildvcs=false` | Suppress VCS stamp errors on mounted projects |
| `GOPROXY` | `https://proxy.golang.org,direct` | Module proxy — override for private registries |
| `GOTELEMETRY` | `off` | Disable Go 1.23+ telemetry |
| `GO_PROD` | *(unset)* | Set to `1` to enable `-trimpath -ldflags=-s -w` on `go build` |
| `TZ` | `America/New_York` | Override at run time with `-e TZ=...` |

Opt into CGO per build without changing the image:

```shell
docker run --rm -v "$PWD:/app" \
  -e CGO_ENABLED=1 \
  casjaysdev/go:latest \
  go build ./...
```

Override the module proxy for a private registry:

```shell
docker run --rm -v "$PWD:/app" \
  -e GOPROXY=https://goproxy.corp.internal,direct \
  casjaysdev/go:latest
```

---

## 🗂️ PATH order

```
/usr/local/go/bin  →  /usr/local/bin  →  $GOPATH/bin  →  ...
```

Baked tools (`/usr/local/bin`) always take precedence over anything installed
at runtime into `$GOPATH/bin`, so a volume-mounted Go workspace can never
shadow the image tools.

---

## 💾 Persistence

Go state lives at **`/usr/local/share/go`** (declared `VOLUME`). Mount a named
volume to persist the module cache, build cache, and any `go install`-ed tools
across container rebuilds:

```shell
# named volume (recommended)
docker run -v go-state:/usr/local/share/go ...

# share with the host's own Go workspace
docker run -v ~/go:/usr/local/share/go ...
```

---

## 🌐 Cross-compile

With `CGO_ENABLED=0` (the default) the Go toolchain cross-compiles pure-Go
binaries with no extra setup:

```shell
docker run --rm -v "$PWD:/app" -e GOOS=linux   -e GOARCH=arm64  casjaysdev/go:latest go build -o app-linux-arm64   ./...
docker run --rm -v "$PWD:/app" -e GOOS=darwin  -e GOARCH=arm64  casjaysdev/go:latest go build -o app-darwin-arm64  ./...
docker run --rm -v "$PWD:/app" -e GOOS=windows -e GOARCH=amd64  casjaysdev/go:latest go build -o app-windows.exe   ./...
docker run --rm -v "$PWD:/app" -e GOOS=freebsd -e GOARCH=amd64  casjaysdev/go:latest go build -o app-freebsd-amd64 ./...
```

Run `docker run --rm casjaysdev/go:latest go tool dist list` for the full
~50-target matrix. `goreleaser` is pre-installed to orchestrate multi-platform
release builds.

---

## 🛠️ Development

### Prerequisites

- Docker (with buildx)
- `make`, `bash`

### Build the image locally

```shell
git clone https://github.com/dockersrc/go "$HOME/Projects/github/dockersrc/go"
cd "$HOME/Projects/github/dockersrc/go"
docker build --tag casjaysdev/go:test .
```

---

## 📄 License

MIT

---

🤖 [casjay](https://github.com/casjay)  
⛵ [casjaysdev](https://github.com/casjaysdev)  
🐳 [Docker Hub](https://hub.docker.com/u/casjaysdev)
