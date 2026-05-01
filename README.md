## 👋 Welcome to go 🚀  

A Docker image for building Go projects. Installs the latest stable Go
toolchain straight from `go.dev` at image build time (SHA256-verified)
so the image is never behind upstream. Includes a comprehensive set of
dev tools and the common build deps (git, make, build-base, openssl-dev,
libffi-dev, zlib-dev, linux-headers, protobuf, jq).

The image is a build environment — it idles after init so you can
`docker exec` into it or use `docker compose exec` for one-off `go
build`, `go test`, `golangci-lint run`, etc.

### What's included

- **Linters / QA**: golangci-lint, staticcheck, govulncheck, gosec,
  errcheck, ineffassign, gocyclo, golint, revive, nilaway, deadcode
- **Formatting / imports**: gofmt (bundled), goimports, gofumpt, gci,
  golines
- **LSP / nav**: gopls, guru, gorename, callgraph
- **Debug / diag**: dlv, gops
- **Codegen**: stringer, mockgen, mockery, wire, sqlc, oapi-codegen,
  gotests, impl, gomodifytags, enumer, easyjson
- **Protobuf / gRPC**: buf, protoc-gen-go, protoc-gen-go-grpc,
  protoc-gen-validate, protoc-gen-grpc-gateway, protoc-gen-openapiv2
- **DB migrations**: migrate (postgres/pgx/mysql/sqlite), goose
- **Test / bench / coverage**: gotestsum, richgo, benchstat,
  go-junit-report, gocover-cobertura, gcov2lcov
- **Build / release / runners**: goreleaser, ko, task, mage, air,
  godoc, swag

  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update go
```
  
## Install and run container
  
```shell
dockerHome="/var/lib/srv/$USER/docker/casjaysdevdocker/go/go/latest/rootfs"
mkdir -p "/var/lib/srv/$USER/docker/go/rootfs"
git clone "https://github.com/dockermgr/go" "$HOME/.local/share/CasjaysDev/dockermgr/go"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/go/rootfs/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-go-latest \
--hostname go \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
casjaysdevdocker/go:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/go
    container_name: casjaysdevdocker-go
    environment:
      - TZ=America/New_York
      - HOSTNAME=go
    volumes:
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/go/go/latest/rootfs/data:/data:z"
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/go/go/latest/rootfs/config:/config:z"
    restart: always
```
  
## Usage

The container idles after init. Use `docker exec` (or `docker compose
exec`) to run go commands against a project mounted into the container,
or do a one-shot build with `docker run --rm`:

```shell
# one-off build (mount your project at /app)
docker run --rm -it \
  -v "$PWD:/app" \
  -w /app \
  casjaysdevdocker/go:latest \
  bash -lc 'go build ./...'

# interactive dev shell
docker run --rm -it \
  -v "$PWD:/app" \
  -w /app \
  casjaysdevdocker/go:latest \
  bash -l

# exec into the long-running container
docker exec -it casjaysdevdocker-go-latest bash -l
docker exec casjaysdevdocker-go-latest go test ./...
docker exec casjaysdevdocker-go-latest golangci-lint run
docker exec casjaysdevdocker-go-latest goreleaser release --snapshot --clean
```

`WORKDIR` inside the image is `/app`. Project code can also be mounted
at `/work`, `/root/app`, `/root/project`, or `/data/build` — all are
created on startup.

## Cross-compile

Go's toolchain ships pre-compiled stdlib for every supported `GOOS/GOARCH`
combination. With the image's `CGO_ENABLED=0` default, **no extra
toolchain is needed** for cross-compiling pure-Go binaries:

```shell
GOOS=windows GOARCH=amd64 go build -o app.exe ./...
GOOS=darwin  GOARCH=arm64 go build -o app     ./...
GOOS=linux   GOARCH=arm64 go build -o app     ./...
GOOS=freebsd GOARCH=amd64 go build -o app     ./...
```

Run `go tool dist list` inside the container for the full ~40-target
matrix. `goreleaser` is pre-installed to orchestrate release builds.

## Environment variables

| Var           | Default                                  | Purpose                                  |
|---------------|------------------------------------------|------------------------------------------|
| `GOPATH`      | `/usr/local/share/go`                    | Workspace; `$GOPATH/bin` on PATH         |
| `GOCACHE`     | `/usr/local/share/go/cache`              | Build cache                              |
| `GOMODCACHE`  | *(unset; defaults to `$GOPATH/pkg/mod`)* | Module cache                             |
| `CGO_ENABLED` | `0`                                      | cgo off by default — static binaries     |
| `GOTOOLCHAIN` | `auto`                                   | Auto-fetch matching Go from `go.mod`     |
| `TZ`          | `America/New_York`                       | Override at run time (`-e TZ=...`)       |

`CGO_ENABLED=0` produces fully static binaries (drop-in deployment
anywhere). Build deps for cgo (`gcc`, `musl-dev`, `openssl-dev`, etc.)
are still installed so you can opt in per build:

```shell
CGO_ENABLED=1 go build ./...
```

## Persistence

Go state lives at the canonical FHS path **`/usr/local/share/go`**,
declared as a Docker `VOLUME`. Mount a named volume there to keep the
module cache, build cache, and any `go install`-ed binaries across
container rebuilds:

```shell
# named volume (managed by docker)
docker run -v go-state:/usr/local/share/go ...

# or share with the host's own Go cache
docker run -v ~/go:/usr/local/share/go ...
```

For convenience these all resolve to the canonical dir via symlinks:

- `/go` (legacy Docker convention, same as the official `golang` image)
- `/root/go` (Go's default `~/go` GOPATH)
- `/root/.go`
- `/root/.local/share/go` (XDG)
- `/data/go` (created at container start)

  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/go
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/go" "$HOME/Projects/github/casjaysdevdocker/go"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/go"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
