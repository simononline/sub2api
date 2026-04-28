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
PLATFORM="${PLATFORM:-linux/amd64}"

COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/deploy/docker-compose.my-sub2api.yml}"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/deploy/.env}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
INCLUDE_ENV="${INCLUDE_ENV:-auto}"
BUILD_BACKEND="${BUILD_BACKEND:-1}"
BUILD_FRONTEND="${BUILD_FRONTEND:-1}"

REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_HOST="${REMOTE_HOST:-43.160.239.168}"
REMOTE_PORT="${REMOTE_PORT:-22}"
REMOTE_DIR="${REMOTE_DIR:-/root/my-sub2api}"
REMOTE_UPLOAD_DIR="${REMOTE_UPLOAD_DIR:-/tmp}"
REMOTE_ENV_POLICY="${REMOTE_ENV_POLICY:-keep}"
REMOTE="${REMOTE_USER}@${REMOTE_HOST}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new}"

SAFE_TAG="$(printf '%s' "$TAG" | tr '/:' '__')"
PACKAGE_NAME="${PACKAGE_NAME:-${PROJECT_NAME}-${SAFE_TAG}-${COMMIT}.tar.gz}"
PACKAGE_PATH="${PACKAGE_PATH:-$DIST_DIR/$PACKAGE_NAME}"
PACKAGE_WORK_DIR="${PACKAGE_WORK_DIR:-$DIST_DIR/.release-${PROJECT_NAME}-${SAFE_TAG}-${COMMIT}}"

ACTION="${1:-package}"

log() {
    printf '[release-images] %s\n' "$*"
}

die() {
    printf '[release-images] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage:
  ./deploy/release-images.sh build
  ./deploy/release-images.sh package
  ./deploy/release-images.sh deploy

Actions:
  build     只在本地构建 Docker 镜像
  package   本地构建镜像，并生成可上传的 tar.gz 产物（默认动作）
  deploy    本地打包，上传到远端，并在远端 docker load 后只重建 backend/frontend

Common variables:
  TAG=local
  PLATFORM=$PLATFORM
  DIST_DIR=$ROOT_DIR/dist
  PACKAGE_PATH=$PACKAGE_PATH
  INCLUDE_ENV=auto|1|0              默认 auto：存在 deploy/.env 时打进包里
  BUILD_BACKEND=1|0                 默认 1；只改前端/nginx 时可设为 0 跳过后端构建
  BUILD_FRONTEND=1|0                默认 1；只改后端时可设为 0 跳过前端构建

Remote variables:
  REMOTE_USER=$REMOTE_USER
  REMOTE_HOST=$REMOTE_HOST
  REMOTE_PORT=$REMOTE_PORT
  REMOTE_DIR=$REMOTE_DIR
  REMOTE_UPLOAD_DIR=$REMOTE_UPLOAD_DIR
  REMOTE_ENV_POLICY=keep|replace|skip
                                    keep：远端已有 .env 时不覆盖
  REMOTE_PASSWORD=...               使用密码登录时需要本机安装 sshpass

Examples:
  ./deploy/release-images.sh package
  REMOTE_PASSWORD='your-password' ./deploy/release-images.sh deploy
  TAG=0.1.119-local REMOTE_PASSWORD='your-password' ./deploy/release-images.sh deploy

EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "找不到命令: $1"
}

image_exists() {
    docker image inspect "$1" >/dev/null 2>&1
}

image_platform() {
    docker image inspect --format '{{.Os}}/{{.Architecture}}{{if .Variant}}/{{.Variant}}{{end}}' "$1" 2>/dev/null
}

image_matches_platform() {
    actual_platform="$(image_platform "$1" || true)"
    case "$actual_platform" in
        "$PLATFORM"|"$PLATFORM/"*)
            return 0
            ;;
    esac
    return 1
}

is_enabled() {
    case "$1" in
        1|true|yes|on)
            return 0
            ;;
        0|false|no|off)
            return 1
            ;;
        *)
            die "$2 只能是 1|0"
            ;;
    esac
}

ensure_base_image_once() {
    target_image="$1"
    source_image="$2"
    label="$3"

    log "检查 ${label} 镜像: ${target_image}"
    if image_exists "$target_image"; then
        if image_matches_platform "$target_image"; then
            log "${label} 镜像已存在且平台匹配，跳过创建"
            return
        fi

        log "${label} 镜像平台不匹配，删除后重建: ${target_image} ($(image_platform "$target_image"))"
        docker rmi -f "$target_image"
    fi

    log "${label} 镜像不存在，拉取 ${source_image} (${PLATFORM}) 并创建本地别名"
    docker pull --platform "$PLATFORM" "$source_image"
    docker tag "$source_image" "$target_image"
}

rebuild_image() {
    image="$1"
    dockerfile="$2"
    label="$3"
    shift 3

    log "检查 ${label} 镜像: ${image}"
    if image_exists "$image"; then
        log "${label} 镜像已存在，将复用 Docker 构建缓存并覆盖标签: ${image}"
    fi

    log "重新构建 ${label} 镜像: ${image}"
    DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build \
        --platform "$PLATFORM" \
        -f "$dockerfile" \
        -t "$image" \
        "$@" \
        "$ROOT_DIR"
}

build_images() {
    require_cmd docker

    log "项目目录: ${ROOT_DIR}"
    log "镜像命名前缀: ${PROJECT_NAME}"
    log "业务镜像 tag: ${TAG}"
    log "目标镜像平台: ${PLATFORM}"

    ensure_base_image_once "$SQL_IMAGE" "$POSTGRES_SOURCE_IMAGE" "PostgreSQL"
    ensure_base_image_once "$REDIS_IMAGE" "$REDIS_SOURCE_IMAGE" "Redis"

    if is_enabled "$BUILD_BACKEND" "BUILD_BACKEND"; then
        rebuild_image "$BACKEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.backend" "backend" \
            --build-arg "VERSION=${VERSION}" \
            --build-arg "COMMIT=${COMMIT}" \
            --build-arg "DATE=${DATE}" \
            --build-arg "GOPROXY=${GOPROXY}" \
            --build-arg "GOSUMDB=${GOSUMDB}"
    else
        image_exists "$BACKEND_IMAGE" || die "BUILD_BACKEND=0，但本地不存在 backend 镜像: ${BACKEND_IMAGE}"
        log "跳过 backend 镜像构建，复用本地镜像: ${BACKEND_IMAGE}"
    fi

    if is_enabled "$BUILD_FRONTEND" "BUILD_FRONTEND"; then
        rebuild_image "$FRONTEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.frontend" "frontend"
    else
        image_exists "$FRONTEND_IMAGE" || die "BUILD_FRONTEND=0，但本地不存在 frontend 镜像: ${FRONTEND_IMAGE}"
        log "跳过 frontend 镜像构建，复用本地镜像: ${FRONTEND_IMAGE}"
    fi

    log "镜像创建完成:"
    log "  SQL      ${SQL_IMAGE}"
    log "  Redis    ${REDIS_IMAGE}"
    log "  Backend  ${BACKEND_IMAGE}"
    log "  Frontend ${FRONTEND_IMAGE}"
}

copy_env_if_needed() {
    case "$INCLUDE_ENV" in
        auto)
            if [ -f "$ENV_FILE" ]; then
                cp "$ENV_FILE" "$PACKAGE_WORK_DIR/deploy.env"
                log "已将 deploy/.env 打入发布包；远端默认仅在 .env 不存在时使用"
            fi
            ;;
        1|true|yes)
            [ -f "$ENV_FILE" ] || die "INCLUDE_ENV=$INCLUDE_ENV，但找不到 $ENV_FILE"
            cp "$ENV_FILE" "$PACKAGE_WORK_DIR/deploy.env"
            log "已将 deploy/.env 打入发布包；远端默认仅在 .env 不存在时使用"
            ;;
        0|false|no)
            log "跳过打包 deploy/.env"
            ;;
        *)
            die "INCLUDE_ENV 只能是 auto|1|0"
            ;;
    esac
}

write_manifest() {
    {
        printf 'PROJECT_NAME=%s\n' "$PROJECT_NAME"
        printf 'TAG=%s\n' "$TAG"
        printf 'SQL_IMAGE=%s\n' "$SQL_IMAGE"
        printf 'REDIS_IMAGE=%s\n' "$REDIS_IMAGE"
        printf 'BACKEND_IMAGE=%s\n' "$BACKEND_IMAGE"
        printf 'FRONTEND_IMAGE=%s\n' "$FRONTEND_IMAGE"
        printf 'PLATFORM=%s\n' "$PLATFORM"
        printf 'COMMIT=%s\n' "$COMMIT"
        printf 'BUILD_DATE=%s\n' "$DATE"
    } > "$PACKAGE_WORK_DIR/manifest.env"
}

package_release() {
    require_cmd docker
    require_cmd tar
    [ -f "$COMPOSE_FILE" ] || die "找不到 compose 文件: $COMPOSE_FILE"

    build_images

    rm -rf "$PACKAGE_WORK_DIR"
    mkdir -p "$PACKAGE_WORK_DIR" "$DIST_DIR"

    log "导出 Docker 镜像到 tar: $PACKAGE_WORK_DIR/images.tar"
    docker save \
        -o "$PACKAGE_WORK_DIR/images.tar" \
        "$SQL_IMAGE" \
        "$REDIS_IMAGE" \
        "$BACKEND_IMAGE" \
        "$FRONTEND_IMAGE"

    cp "$COMPOSE_FILE" "$PACKAGE_WORK_DIR/docker-compose.yml"
    write_manifest
    copy_env_if_needed

    log "生成发布包: $PACKAGE_PATH"
    rm -f "$PACKAGE_PATH"
    (
        cd "$PACKAGE_WORK_DIR"
        COPYFILE_DISABLE=1 tar -czf "$PACKAGE_PATH" .
    )

    log "发布包创建完成: $PACKAGE_PATH"
}

ssh_password_value() {
    if [ -n "${REMOTE_PASSWORD:-}" ]; then
        printf '%s' "$REMOTE_PASSWORD"
    elif [ -n "${SSHPASS:-}" ]; then
        printf '%s' "$SSHPASS"
    else
        printf ''
    fi
}

ssh_remote() {
    password="$(ssh_password_value)"
    if [ -n "$password" ]; then
        require_cmd sshpass
        SSHPASS="$password" sshpass -e ssh -p "$REMOTE_PORT" $SSH_OPTS "$REMOTE" "$@"
    else
        ssh -p "$REMOTE_PORT" $SSH_OPTS "$REMOTE" "$@"
    fi
}

scp_upload() {
    src="$1"
    dest="$2"
    password="$(ssh_password_value)"
    if [ -n "$password" ]; then
        require_cmd sshpass
        SSHPASS="$password" sshpass -e scp -P "$REMOTE_PORT" $SSH_OPTS "$src" "$REMOTE:$dest"
    else
        scp -P "$REMOTE_PORT" $SSH_OPTS "$src" "$REMOTE:$dest"
    fi
}

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

root_remote_dir() {
    case "$REMOTE_DIR" in
        "~")
            printf '/root\n'
            ;;
        "~/"*)
            printf '/root/%s\n' "${REMOTE_DIR#~/}"
            ;;
        *)
            printf '%s\n' "$REMOTE_DIR"
            ;;
    esac
}

run_remote_install() {
    remote_dir_abs="$1"
    remote_package_path="$2"
    package_name="$3"
    env_policy="$4"

    remote_dir_q="$(shell_quote "$remote_dir_abs")"
    remote_package_path_q="$(shell_quote "$remote_package_path")"
    package_q="$(shell_quote "$package_name")"
    env_policy_q="$(shell_quote "$env_policy")"

    ssh_remote "sudo -n -i sh -s -- $remote_dir_q $remote_package_path_q $package_q $env_policy_q" <<'REMOTE_SCRIPT'
set -eu

REMOTE_DIR="$1"
REMOTE_PACKAGE_PATH="$2"
PACKAGE_NAME="$3"
ENV_POLICY="$4"

log() {
    printf '[remote-install] %s\n' "$*"
}

die() {
    printf '[remote-install] ERROR: %s\n' "$*" >&2
    exit 1
}

find_docker() {
    if docker info >/dev/null 2>&1; then
        printf 'docker\n'
        return
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
        printf 'sudo docker\n'
        return
    fi

    die "远端当前用户无法执行 docker。请把用户加入 docker 组，或配置免密 sudo。"
}

find_compose() {
    docker_cmd="$1"

    if $docker_cmd compose version >/dev/null 2>&1; then
        printf '%s compose\n' "$docker_cmd"
        return
    fi

    if command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
        printf 'docker-compose\n'
        return
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n docker-compose version >/dev/null 2>&1; then
        printf 'sudo docker-compose\n'
        return
    fi

    die "远端找不到 docker compose 或 docker-compose。"
}

wait_service_healthy() {
    service="$1"
    timeout="$2"
    start_ts="$(date +%s)"

    while :; do
        cid="$($COMPOSE -f docker-compose.yml ps -q "$service" 2>/dev/null || true)"
        if [ -n "$cid" ]; then
            status="$($DOCKER inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || printf unknown)"
            case "$status" in
                healthy|running)
                    log "${service} 状态: ${status}"
                    return 0
                    ;;
            esac
        fi

        now_ts="$(date +%s)"
        if [ $((now_ts - start_ts)) -ge "$timeout" ]; then
            log "${service} 等待超时，最近日志如下:"
            if [ -n "${cid:-}" ]; then
                $DOCKER logs --tail 80 "$cid" || true
            fi
            return 1
        fi

        sleep 3
    done
}

remove_application_containers() {
    $COMPOSE -f docker-compose.yml stop frontend backend >/dev/null 2>&1 || true
    $COMPOSE -f docker-compose.yml rm -f frontend backend >/dev/null 2>&1 || true
    $DOCKER rm -f "${PROJECT_NAME}-frontend" "${PROJECT_NAME}-backend" >/dev/null 2>&1 || true
}

DOCKER="$(find_docker)"
COMPOSE="$(find_compose "$DOCKER")"

mkdir -p "$REMOTE_DIR"

if [ -f "$REMOTE_PACKAGE_PATH" ]; then
    mv "$REMOTE_PACKAGE_PATH" "$REMOTE_DIR/$PACKAGE_NAME"
fi

cd "$REMOTE_DIR"

[ -f "$PACKAGE_NAME" ] || die "找不到远端发布包: $REMOTE_DIR/$PACKAGE_NAME"

log "解压发布包到 $REMOTE_DIR"
tar -xzf "$PACKAGE_NAME" -C "$REMOTE_DIR"

case "$ENV_POLICY" in
    keep)
        if [ ! -f .env ] && [ -f deploy.env ]; then
            cp deploy.env .env
            log "远端 .env 不存在，已使用发布包里的 deploy.env 初始化"
        elif [ -f .env ]; then
            log "保留远端已有 .env"
        fi
        ;;
    replace)
        [ -f deploy.env ] || die "REMOTE_ENV_POLICY=replace，但发布包里没有 deploy.env"
        cp deploy.env .env
        log "已用发布包里的 deploy.env 覆盖远端 .env"
        ;;
    skip)
        log "跳过远端 .env 处理"
        ;;
    *)
        die "REMOTE_ENV_POLICY 只能是 keep|replace|skip"
        ;;
esac

[ -f .env ] || die "远端缺少 .env。请先提供 deploy/.env，或使用 INCLUDE_ENV=1 打包。"
[ -f docker-compose.yml ] || die "发布包缺少 docker-compose.yml"
[ -f images.tar ] || die "发布包缺少 images.tar"
[ -f manifest.env ] || die "发布包缺少 manifest.env"

mkdir -p data postgres_data redis_data

log "导入 Docker 镜像"
$DOCKER load -i images.tar

. ./manifest.env
export PROJECT_NAME TAG SQL_IMAGE REDIS_IMAGE BACKEND_IMAGE FRONTEND_IMAGE PLATFORM

postgres_id="$($COMPOSE -f docker-compose.yml ps -q postgres 2>/dev/null || true)"
redis_id="$($COMPOSE -f docker-compose.yml ps -q redis 2>/dev/null || true)"

if [ -n "$postgres_id" ] && [ -n "$redis_id" ]; then
    log "检测到已有 PostgreSQL/Redis 容器，仅删除并重建 backend/frontend"
    $DOCKER start "$postgres_id" "$redis_id" >/dev/null 2>&1 || true
    remove_application_containers
    $COMPOSE -f docker-compose.yml up -d --no-deps --force-recreate backend
    wait_service_healthy backend 180
    $COMPOSE -f docker-compose.yml up -d --no-deps --force-recreate frontend
else
    log "未检测到完整 PostgreSQL/Redis 容器，执行首次完整启动"
    remove_application_containers
    $COMPOSE -f docker-compose.yml up -d
fi

log "远端服务状态:"
$COMPOSE -f docker-compose.yml ps
REMOTE_SCRIPT
}

deploy_release() {
    require_cmd ssh
    require_cmd scp
    require_cmd sed

    package_release

    remote_dir_abs="$(root_remote_dir)"
    remote_package_path="${REMOTE_UPLOAD_DIR%/}/$(basename "$PACKAGE_PATH")"

    log "远端目录: ${REMOTE}:${remote_dir_abs}"
    log "远端临时上传路径: ${REMOTE}:${remote_package_path}"

    remote_upload_dir_q="$(shell_quote "$REMOTE_UPLOAD_DIR")"
    ssh_remote "mkdir -p $remote_upload_dir_q"

    log "上传发布包到远端"
    scp_upload "$PACKAGE_PATH" "$remote_package_path"

    log "开始远端安装并重建 backend/frontend"
    run_remote_install "$remote_dir_abs" "$remote_package_path" "$(basename "$PACKAGE_PATH")" "$REMOTE_ENV_POLICY"
}

case "$ACTION" in
    build)
        build_images
        ;;
    package)
        package_release
        ;;
    deploy)
        deploy_release
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        die "未知动作: $ACTION"
        ;;
esac
