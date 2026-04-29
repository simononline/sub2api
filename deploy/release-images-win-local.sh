#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

export LOCAL_OS="${LOCAL_OS:-win}"
export PLATFORM="${PLATFORM:-linux/amd64}"
export BIND_HOST="${BIND_HOST:-127.0.0.1}"
export SCRIPT_NAME="${SCRIPT_NAME:-release-images-win-local.sh}"

if [ "${1:-}" = "deploy" ]; then
    shift
    exec "$SCRIPT_DIR/release-images-mac-local.sh" up "$@"
fi

exec "$SCRIPT_DIR/release-images-mac-local.sh" "$@"
