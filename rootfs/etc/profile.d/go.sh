# Go environment - sourced by /etc/profile for interactive login shells.
#
# All Go state lives under /usr/local/share/go (declared as a Docker
# VOLUME). The paths /go, /root/go, /root/.go, /root/.local/share/go and
# /data/go are symlinks to that location, so any of them can be used
# interchangeably and the data persists across container rebuilds when
# the volume is named.

export GOPATH="${GOPATH:-/usr/local/share/go}"
export GOCACHE="${GOCACHE:-${GOPATH}/cache}"
export CGO_ENABLED="${CGO_ENABLED:-0}"
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

case ":${PATH}:" in
  *":${GOPATH}/bin:"*) ;;
  *) export PATH="${GOPATH}/bin:${PATH}" ;;
esac
