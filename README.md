# go

A Docker image that ships the **latest stable Go toolchain** (fetched from
`go.dev` at build time) together with a complete set of tools for building,
testing, linting, debugging, and releasing Go projects. The image is based on
Alpine and produces fully static binaries by default (`CGO_ENABLED=0`); the
CGO build-deps (`gcc`, `musl-dev`, `openssl-dev`, etc.) are still present so
you can opt in per build.

---

## 📦 Pull

```shell
docker pull casjaysdevdocker/go:latest
```

---

## 🐳 Docker

### Quick one-shot commands

```shell
# build a project (mount source at /app)
docker run --rm -it \
  -v "$PWD:/app" -w /app \
  casjaysdevdocker/go:latest \
  go build ./...

# run tests
docker run --rm -it \
  -v "$PWD:/app" -w /app \
  casjaysdevdocker/go:latest \
  gotestsum ./...

# lint
docker run --rm -it \
  -v "$PWD:/app" -w /app \
  casjaysdevdocker/go:latest \
  golangci-lint run

# interactive shell
docker run --rm -it \
  -v "$PWD:/app" -w /app \
  casjaysdevdocker/go:latest \
  bash -l
```

### Long-running container

```shell
docker run -d \
  --restart always \
  --name casjaysdevdocker-go \
  --hostname go \
  -e TZ=${TIMEZONE:-America/New_York} \
  -v go-state:/usr/local/share/go \
  -v "$PWD:/app" -w /app \
  casjaysdevdocker/go:latest

# exec into it
docker exec -it casjaysdevdocker-go bash -l
docker exec casjaysdevdocker-go go test ./...
docker exec casjaysdevdocker-go golangci-lint run
docker exec casjaysdevdocker-go goreleaser release --snapshot --clean
```

### docker-compose

```yaml
services:
  go:
    image: casjaysdevdocker/go:latest
    container_name: casjaysdevdocker-go
    hostname: go
    environment:
      - TZ=America/New_York
    volumes:
      - go-state:/usr/local/share/go
      - .:/app
    working_dir: /app
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
| `GOCACHE` | `/usr/local/share/go/cache` | Build cache (persisted in volume) |
| `GOMODCACHE` | *(defaults to `$GOPATH/pkg/mod`)* | Module cache |
| `CGO_ENABLED` | `0` | Static builds by default — override per build |
| `GOTOOLCHAIN` | `auto` | Auto-fetch the Go version declared in `go.mod` |
| `TZ` | `America/New_York` | Override at run time with `-e TZ=...` |

Opt into CGO per build without changing the image:

```shell
docker run --rm -v "$PWD:/app" -w /app \
  -e CGO_ENABLED=1 \
  casjaysdevdocker/go:latest \
  go build ./...
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

Convenience symlinks also resolve to the canonical path:

| Symlink | Notes |
|---------|-------|
| `/go` | Legacy Docker convention — matches the official `golang` image |
| `/root/go` | Go's default `~/go` GOPATH |
| `/root/.go` | Hidden variant |
| `/root/.local/share/go` | XDG base-dir variant |
| `/data/go` | Created at container start |

---

## 🌐 Cross-compile

With `CGO_ENABLED=0` (the default) the Go toolchain cross-compiles pure-Go
binaries with no extra setup:

```shell
GOOS=linux   GOARCH=arm64  go build -o app-linux-arm64   ./...
GOOS=darwin  GOARCH=arm64  go build -o app-darwin-arm64  ./...
GOOS=windows GOARCH=amd64  go build -o app-windows.exe   ./...
GOOS=freebsd GOARCH=amd64  go build -o app-freebsd-amd64 ./...
```

Run `go tool dist list` for the full ~50-target matrix. `goreleaser` is
pre-installed to orchestrate multi-platform release builds.

---

## 🛠️ Development

### Prerequisites

- Docker (with buildx)
- `make`, `bash`

### Build the image locally

```shell
git clone https://github.com/casjaysdevdocker/go "$HOME/Projects/github/casjaysdevdocker/go"
cd "$HOME/Projects/github/casjaysdevdocker/go"
docker build --tag casjaysdevdocker/go:test .
```

### Get source files

```shell
git clone "https://github.com/casjaysdevdocker/go" \
  "$HOME/Projects/github/casjaysdevdocker/go"
```

---

## 📄 License

MIT — see [LICENSE.md](LICENSE.md)

---

🤖 [casjay](https://github.com/casjay) ·
⛵ [casjaysdevdocker](https://github.com/casjaysdevdocker) ·
🐳 [Docker Hub](https://hub.docker.com/u/casjaysdevdocker)
