#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

PROJECT_NAME="${PROJECT_NAME:-my-sub2api}"
TAG="${TAG:-local}"

POSTGRES_SOURCE_IMAGE="${POSTGRES_SOURCE_IMAGE:-postgres:18-alpine}"
REDIS_SOURCE_IMAGE="${REDIS_SOURCE_IMAGE:-redis:8-alpine}"

SQL_IMAGE="${SQL_IMAGE:-${PROJECT_NAME}-postgres:18-alpine}"
REDIS_IMAGE="${REDIS_IMAGE:-${PROJECT_NAME}-redis:8-alpine}"
BACKEND_IMAGE="${BACKEND_IMAGE:-${PROJECT_NAME}-backend:${TAG}}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-${PROJECT_NAME}-frontend:${TAG}}"

VERSION="${VERSION:-}"
COMMIT="${COMMIT:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf docker)}"
DATE="${DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"
GOSUMDB="${GOSUMDB:-sum.golang.google.cn}"

log() {
    printf '[release-images] %s\n' "$*"
}

image_exists() {
    docker image inspect "$1" >/dev/null 2>&1
}

ensure_base_image_once() {
    target_image="$1"
    source_image="$2"
    label="$3"

    log "检查 ${label} 镜像: ${target_image}"
    if image_exists "$target_image"; then
        log "${label} 镜像已存在，跳过创建"
        return
    fi

    log "${label} 镜像不存在，拉取 ${source_image} 并创建本地别名"
    docker pull "$source_image"
    docker tag "$source_image" "$target_image"
}

rebuild_image() {
    image="$1"
    dockerfile="$2"
    label="$3"
    shift 3

    log "检查 ${label} 镜像: ${image}"
    if image_exists "$image"; then
        log "删除已存在的 ${label} 镜像: ${image}"
        docker rmi "$image"
    fi

    log "重新构建 ${label} 镜像: ${image}"
    docker build \
        -f "$dockerfile" \
        -t "$image" \
        "$@" \
        "$ROOT_DIR"
}

log "项目目录: ${ROOT_DIR}"
log "镜像命名前缀: ${PROJECT_NAME}"
log "业务镜像 tag: ${TAG}"

ensure_base_image_once "$SQL_IMAGE" "$POSTGRES_SOURCE_IMAGE" "PostgreSQL"
ensure_base_image_once "$REDIS_IMAGE" "$REDIS_SOURCE_IMAGE" "Redis"

rebuild_image "$BACKEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.backend" "backend" \
    --build-arg "VERSION=${VERSION}" \
    --build-arg "COMMIT=${COMMIT}" \
    --build-arg "DATE=${DATE}" \
    --build-arg "GOPROXY=${GOPROXY}" \
    --build-arg "GOSUMDB=${GOSUMDB}"

rebuild_image "$FRONTEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.frontend" "frontend"

log "镜像创建完成:"
log "  SQL      ${SQL_IMAGE}"
log "  Redis    ${REDIS_IMAGE}"
log "  Backend  ${BACKEND_IMAGE}"
log "  Frontend ${FRONTEND_IMAGE}"
