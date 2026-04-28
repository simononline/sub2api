#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0")}"
LOCAL_OS="${LOCAL_OS:-mac}"

PROJECT_NAME="${PROJECT_NAME:-my-sub2api}"
TAG="${TAG:-local}"

REDIS_SOURCE_IMAGE="${REDIS_SOURCE_IMAGE:-redis:8-alpine}"
REDIS_IMAGE="${REDIS_IMAGE:-${PROJECT_NAME}-redis:8-alpine}"
BACKEND_IMAGE="${BACKEND_IMAGE:-${PROJECT_NAME}-backend:${TAG}}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-${PROJECT_NAME}-frontend:${TAG}}"

VERSION="${VERSION:-}"
COMMIT="${COMMIT:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf docker)}"
DATE="${DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"
GOSUMDB="${GOSUMDB:-sum.golang.google.cn}"

detect_platform() {
    machine="$(uname -m 2>/dev/null || printf unknown)"
    case "$machine" in
        arm64|aarch64)
            printf 'linux/arm64\n'
            ;;
        *)
            printf 'linux/amd64\n'
            ;;
    esac
}

PLATFORM="${PLATFORM:-$(detect_platform)}"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/deploy/.env}"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT_DIR/dist/local-docker/$LOCAL_OS}"
RUNTIME_ENV_FILE="$RUNTIME_DIR/local.env"
RUNTIME_COMPOSE_FILE="$RUNTIME_DIR/docker-compose.yml"

BUILD_BACKEND="${BUILD_BACKEND:-1}"
BUILD_FRONTEND="${BUILD_FRONTEND:-1}"
START_TUNNEL="${START_TUNNEL:-1}"

REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_HOST="${REMOTE_HOST:-43.160.239.168}"
REMOTE_PORT="${REMOTE_PORT:-22}"
REMOTE_DATABASE_HOST="${REMOTE_DATABASE_HOST:-127.0.0.1}"
REMOTE_DATABASE_PORT="${REMOTE_DATABASE_PORT:-5432}"
REMOTE_DATABASE_CONTAINER="${REMOTE_DATABASE_CONTAINER:-${PROJECT_NAME}-postgres}"
REMOTE_DATABASE_DISCOVERY="${REMOTE_DATABASE_DISCOVERY:-auto}"
LOCAL_DATABASE_BIND_HOST="${LOCAL_DATABASE_BIND_HOST:-127.0.0.1}"
LOCAL_DATABASE_PORT="${LOCAL_DATABASE_PORT:-15432}"
APP_DATABASE_HOST="${APP_DATABASE_HOST:-host.docker.internal}"
APP_DATABASE_PORT="${APP_DATABASE_PORT:-$LOCAL_DATABASE_PORT}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes}"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${PROJECT_NAME}-${LOCAL_OS}-local}"
BIND_HOST="${BIND_HOST:-127.0.0.1}"
SERVER_PORT="${SERVER_PORT:-8080}"
SERVER_MODE="${SERVER_MODE:-debug}"
RUN_MODE="${RUN_MODE:-standard}"
TZ="${TZ:-Asia/Shanghai}"

ACTION="${1:-up}"

log() {
    printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage:
  ./deploy/$SCRIPT_NAME up       Build images, open the SSH DB tunnel, and start local Docker services
  ./deploy/$SCRIPT_NAME build    Build backend/frontend and prepare the local Redis image
  ./deploy/$SCRIPT_NAME tunnel   Open only the SSH tunnel to the remote PostgreSQL service
  ./deploy/$SCRIPT_NAME down     Stop local Docker services
  ./deploy/$SCRIPT_NAME restart  Recreate backend/frontend/redis
  ./deploy/$SCRIPT_NAME ps       Show local Docker services
  ./deploy/$SCRIPT_NAME logs     Follow local Docker logs
  ./deploy/$SCRIPT_NAME config   Render the generated compose config

Default services:
  frontend  http://$BIND_HOST:$SERVER_PORT
  backend   ${BACKEND_IMAGE}
  redis     ${REDIS_IMAGE}
  database  host container -> $APP_DATABASE_HOST:$APP_DATABASE_PORT -> ssh tunnel -> $REMOTE_HOST:$REMOTE_DATABASE_PORT

Common variables:
  TAG=$TAG
  PLATFORM=$PLATFORM
  ENV_FILE=$ENV_FILE
  LOCAL_DATABASE_PORT=$LOCAL_DATABASE_PORT
  REMOTE_USER=$REMOTE_USER
  REMOTE_HOST=$REMOTE_HOST
  REMOTE_PORT=$REMOTE_PORT
  REMOTE_DATABASE_HOST=$REMOTE_DATABASE_HOST
  REMOTE_DATABASE_PORT=$REMOTE_DATABASE_PORT
  REMOTE_DATABASE_CONTAINER=$REMOTE_DATABASE_CONTAINER
  REMOTE_DATABASE_DISCOVERY=$REMOTE_DATABASE_DISCOVERY
  REMOTE_PASSWORD=...       Optional; requires sshpass. Without it, ssh prompts interactively.
  START_TUNNEL=1|0          Set 0 when DATABASE_HOST is directly reachable from Docker.
  DATABASE_USER=...         Optional override; default falls back to POSTGRES_USER from ENV_FILE.
  DATABASE_PASSWORD=...     Optional override; default falls back to POSTGRES_PASSWORD from ENV_FILE.
  DATABASE_DBNAME=...       Optional override; default falls back to POSTGRES_DB from ENV_FILE.

Examples:
  ./deploy/$SCRIPT_NAME up
  REMOTE_PASSWORD='<ssh-password>' ./deploy/$SCRIPT_NAME up
  LOCAL_DATABASE_PORT=15433 ./deploy/$SCRIPT_NAME up
  START_TUNNEL=0 APP_DATABASE_HOST=43.160.239.168 APP_DATABASE_PORT=5432 ./deploy/$SCRIPT_NAME up

EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
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
            die "$2 must be 1|0"
            ;;
    esac
}

find_compose() {
    if docker compose version >/dev/null 2>&1; then
        printf 'docker compose\n'
        return
    fi

    if command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
        printf 'docker-compose\n'
        return
    fi

    die "missing docker compose or docker-compose"
}

ensure_base_image_once() {
    target_image="$1"
    source_image="$2"
    label="$3"

    log "checking $label image: $target_image"
    if image_exists "$target_image"; then
        if image_matches_platform "$target_image"; then
            log "$label image already exists for $PLATFORM"
            return
        fi

        log "$label image platform mismatch, recreating: $target_image ($(image_platform "$target_image"))"
        docker rmi -f "$target_image"
    fi

    log "pulling $source_image ($PLATFORM) and tagging $target_image"
    docker pull --platform "$PLATFORM" "$source_image"
    docker tag "$source_image" "$target_image"
}

rebuild_image() {
    image="$1"
    dockerfile="$2"
    label="$3"
    shift 3

    log "building $label image: $image"
    DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build \
        --platform "$PLATFORM" \
        -f "$dockerfile" \
        -t "$image" \
        "$@" \
        "$ROOT_DIR"
}

build_images() {
    require_cmd docker

    log "project dir: $ROOT_DIR"
    log "image prefix: $PROJECT_NAME"
    log "business tag: $TAG"
    log "target platform: $PLATFORM"

    ensure_base_image_once "$REDIS_IMAGE" "$REDIS_SOURCE_IMAGE" "Redis"

    if is_enabled "$BUILD_BACKEND" "BUILD_BACKEND"; then
        rebuild_image "$BACKEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.backend" "backend" \
            --build-arg "VERSION=${VERSION}" \
            --build-arg "COMMIT=${COMMIT}" \
            --build-arg "DATE=${DATE}" \
            --build-arg "GOPROXY=${GOPROXY}" \
            --build-arg "GOSUMDB=${GOSUMDB}"
    else
        image_exists "$BACKEND_IMAGE" || die "BUILD_BACKEND=0 but backend image is missing: $BACKEND_IMAGE"
        log "skipping backend build and reusing $BACKEND_IMAGE"
    fi

    if is_enabled "$BUILD_FRONTEND" "BUILD_FRONTEND"; then
        rebuild_image "$FRONTEND_IMAGE" "$ROOT_DIR/deploy/Dockerfile.frontend" "frontend"
    else
        image_exists "$FRONTEND_IMAGE" || die "BUILD_FRONTEND=0 but frontend image is missing: $FRONTEND_IMAGE"
        log "skipping frontend build and reusing $FRONTEND_IMAGE"
    fi

    log "images ready:"
    log "  Redis    $REDIS_IMAGE"
    log "  Backend  $BACKEND_IMAGE"
    log "  Frontend $FRONTEND_IMAGE"
}

env_value() {
    key="$1"
    file="$2"

    [ -f "$file" ] || return 0
    awk -v key="$key" '
        index($0, key "=") == 1 {
            sub(/^[^=]*=/, "")
            sub(/\r$/, "")
            print
            exit
        }
    ' "$file"
}

first_value() {
    for candidate in "$@"; do
        if [ -n "$candidate" ]; then
            printf '%s\n' "$candidate"
            return
        fi
    done
}

host_path() {
    path="$1"
    case "$LOCAL_OS" in
        win)
            if command -v cygpath >/dev/null 2>&1; then
                cygpath -w "$path" | sed 's#\\#/#g'
            else
                printf '%s\n' "$path"
            fi
            ;;
        *)
            printf '%s\n' "$path"
            ;;
    esac
}

write_env_line() {
    key="$1"
    value="$2"
    printf '%s=%s\n' "$key" "$value" >> "$RUNTIME_ENV_FILE"
}

write_runtime_env() {
    mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/data" "$RUNTIME_DIR/redis_data"
    rm -f "$RUNTIME_ENV_FILE"

    env_database_user="$(first_value "${DATABASE_USER:-}" "$(env_value DATABASE_USER "$ENV_FILE")" "$(env_value POSTGRES_USER "$ENV_FILE")" "sub2api")"
    env_database_password="$(first_value "${DATABASE_PASSWORD:-}" "$(env_value DATABASE_PASSWORD "$ENV_FILE")" "$(env_value POSTGRES_PASSWORD "$ENV_FILE")")"
    env_database_dbname="$(first_value "${DATABASE_DBNAME:-}" "$(env_value DATABASE_DBNAME "$ENV_FILE")" "$(env_value POSTGRES_DB "$ENV_FILE")" "sub2api")"
    env_database_sslmode="$(first_value "${DATABASE_SSLMODE:-}" "$(env_value DATABASE_SSLMODE "$ENV_FILE")" "disable")"
    env_redis_password="$(first_value "${REDIS_PASSWORD:-}" "$(env_value REDIS_PASSWORD "$ENV_FILE")")"
    env_redis_db="$(first_value "${REDIS_DB:-}" "$(env_value REDIS_DB "$ENV_FILE")" "0")"
    env_admin_email="$(first_value "${ADMIN_EMAIL:-}" "$(env_value ADMIN_EMAIL "$ENV_FILE")" "admin@sub2api.local")"
    env_admin_password="$(first_value "${ADMIN_PASSWORD:-}" "$(env_value ADMIN_PASSWORD "$ENV_FILE")")"
    env_jwt_secret="$(first_value "${JWT_SECRET:-}" "$(env_value JWT_SECRET "$ENV_FILE")")"
    env_totp_key="$(first_value "${TOTP_ENCRYPTION_KEY:-}" "$(env_value TOTP_ENCRYPTION_KEY "$ENV_FILE")")"

    [ -n "$env_database_password" ] || die "database password is empty. Set DATABASE_PASSWORD or POSTGRES_PASSWORD in $ENV_FILE"

    write_env_line "COMPOSE_PROJECT_NAME" "$COMPOSE_PROJECT_NAME"
    write_env_line "PROJECT_NAME" "$PROJECT_NAME"
    write_env_line "LOCAL_OS" "$LOCAL_OS"
    write_env_line "BACKEND_IMAGE" "$BACKEND_IMAGE"
    write_env_line "FRONTEND_IMAGE" "$FRONTEND_IMAGE"
    write_env_line "REDIS_IMAGE" "$REDIS_IMAGE"
    write_env_line "BIND_HOST" "$BIND_HOST"
    write_env_line "SERVER_PORT" "$SERVER_PORT"
    write_env_line "SERVER_MODE" "$SERVER_MODE"
    write_env_line "RUN_MODE" "$RUN_MODE"
    write_env_line "TZ" "$TZ"
    write_env_line "DATA_DIR_HOST" "$(host_path "$RUNTIME_DIR/data")"
    write_env_line "REDIS_DATA_DIR_HOST" "$(host_path "$RUNTIME_DIR/redis_data")"

    write_env_line "AUTO_SETUP" "true"
    write_env_line "DATABASE_HOST" "$APP_DATABASE_HOST"
    write_env_line "DATABASE_PORT" "$APP_DATABASE_PORT"
    write_env_line "DATABASE_USER" "$env_database_user"
    write_env_line "DATABASE_PASSWORD" "$env_database_password"
    write_env_line "DATABASE_DBNAME" "$env_database_dbname"
    write_env_line "DATABASE_SSLMODE" "$env_database_sslmode"
    write_env_line "DATABASE_MAX_OPEN_CONNS" "$(first_value "${DATABASE_MAX_OPEN_CONNS:-}" "$(env_value DATABASE_MAX_OPEN_CONNS "$ENV_FILE")" "50")"
    write_env_line "DATABASE_MAX_IDLE_CONNS" "$(first_value "${DATABASE_MAX_IDLE_CONNS:-}" "$(env_value DATABASE_MAX_IDLE_CONNS "$ENV_FILE")" "10")"
    write_env_line "DATABASE_CONN_MAX_LIFETIME_MINUTES" "$(first_value "${DATABASE_CONN_MAX_LIFETIME_MINUTES:-}" "$(env_value DATABASE_CONN_MAX_LIFETIME_MINUTES "$ENV_FILE")" "30")"
    write_env_line "DATABASE_CONN_MAX_IDLE_TIME_MINUTES" "$(first_value "${DATABASE_CONN_MAX_IDLE_TIME_MINUTES:-}" "$(env_value DATABASE_CONN_MAX_IDLE_TIME_MINUTES "$ENV_FILE")" "5")"
    write_env_line "DATABASE_MIGRATION_TIMEOUT_SECONDS" "$(first_value "${DATABASE_MIGRATION_TIMEOUT_SECONDS:-}" "$(env_value DATABASE_MIGRATION_TIMEOUT_SECONDS "$ENV_FILE")" "600")"

    write_env_line "REDIS_HOST" "redis"
    write_env_line "REDIS_PORT" "6379"
    write_env_line "REDIS_PASSWORD" "$env_redis_password"
    write_env_line "REDISCLI_AUTH" "$env_redis_password"
    write_env_line "REDIS_DB" "$env_redis_db"
    write_env_line "REDIS_POOL_SIZE" "$(first_value "${REDIS_POOL_SIZE:-}" "$(env_value REDIS_POOL_SIZE "$ENV_FILE")" "1024")"
    write_env_line "REDIS_MIN_IDLE_CONNS" "$(first_value "${REDIS_MIN_IDLE_CONNS:-}" "$(env_value REDIS_MIN_IDLE_CONNS "$ENV_FILE")" "10")"
    write_env_line "REDIS_ENABLE_TLS" "$(first_value "${REDIS_ENABLE_TLS:-}" "$(env_value REDIS_ENABLE_TLS "$ENV_FILE")" "false")"

    write_env_line "ADMIN_EMAIL" "$env_admin_email"
    write_env_line "ADMIN_PASSWORD" "$env_admin_password"
    write_env_line "JWT_SECRET" "$env_jwt_secret"
    write_env_line "JWT_EXPIRE_HOUR" "$(first_value "${JWT_EXPIRE_HOUR:-}" "$(env_value JWT_EXPIRE_HOUR "$ENV_FILE")" "24")"
    write_env_line "TOTP_ENCRYPTION_KEY" "$env_totp_key"

    write_env_line "GEMINI_OAUTH_CLIENT_ID" "$(first_value "${GEMINI_OAUTH_CLIENT_ID:-}" "$(env_value GEMINI_OAUTH_CLIENT_ID "$ENV_FILE")")"
    write_env_line "GEMINI_OAUTH_CLIENT_SECRET" "$(first_value "${GEMINI_OAUTH_CLIENT_SECRET:-}" "$(env_value GEMINI_OAUTH_CLIENT_SECRET "$ENV_FILE")")"
    write_env_line "GEMINI_OAUTH_SCOPES" "$(first_value "${GEMINI_OAUTH_SCOPES:-}" "$(env_value GEMINI_OAUTH_SCOPES "$ENV_FILE")")"
    write_env_line "GEMINI_QUOTA_POLICY" "$(first_value "${GEMINI_QUOTA_POLICY:-}" "$(env_value GEMINI_QUOTA_POLICY "$ENV_FILE")")"
    write_env_line "GEMINI_CLI_OAUTH_CLIENT_SECRET" "$(first_value "${GEMINI_CLI_OAUTH_CLIENT_SECRET:-}" "$(env_value GEMINI_CLI_OAUTH_CLIENT_SECRET "$ENV_FILE")")"
    write_env_line "ANTIGRAVITY_OAUTH_CLIENT_SECRET" "$(first_value "${ANTIGRAVITY_OAUTH_CLIENT_SECRET:-}" "$(env_value ANTIGRAVITY_OAUTH_CLIENT_SECRET "$ENV_FILE")")"
}

write_runtime_compose() {
    mkdir -p "$RUNTIME_DIR"
    cat > "$RUNTIME_COMPOSE_FILE" <<'EOF'
services:
  frontend:
    image: ${FRONTEND_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-frontend
    restart: unless-stopped
    ports:
      - "${BIND_HOST}:${SERVER_PORT}:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "3", "-O", "/dev/null", "http://127.0.0.1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  backend:
    image: ${BACKEND_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-backend
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    env_file:
      - ./local.env
    environment:
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=8080
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - type: bind
        source: ${DATA_DIR_HOST}
        target: /app/data
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 15s
      timeout: 10s
      retries: 20
      start_period: 10m

  redis:
    image: ${REDIS_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-redis
    restart: unless-stopped
    env_file:
      - ./local.env
    volumes:
      - type: bind
        source: ${REDIS_DATA_DIR_HOST}
        target: /data
    command: >
      sh -c '
        redis-server
        --save 60 1
        --appendonly yes
        --appendfsync everysec
        $${REDIS_PASSWORD:+--requirepass "$$REDIS_PASSWORD"}'
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

networks:
  local-network:
    driver: bridge
EOF
}

write_runtime_files() {
    write_runtime_env
    write_runtime_compose
    log "runtime compose: $RUNTIME_COMPOSE_FILE"
    log "runtime env: $RUNTIME_ENV_FILE"
}

port_open() {
    host="$1"
    port="$2"

    if command -v nc >/dev/null 2>&1; then
        nc -z "$host" "$port" >/dev/null 2>&1
        return $?
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command "\$client = New-Object Net.Sockets.TcpClient; try { \$client.Connect('$host', $port); exit 0 } catch { exit 1 } finally { \$client.Close() }" >/dev/null 2>&1
        return $?
    fi

    return 1
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
    remote="${REMOTE_USER}@${REMOTE_HOST}"
    password="$(ssh_password_value)"

    if [ -n "$password" ]; then
        require_cmd sshpass
        SSHPASS="$password" sshpass -e ssh -p "$REMOTE_PORT" $SSH_OPTS "$remote" "$@"
    else
        ssh -p "$REMOTE_PORT" $SSH_OPTS "$remote" "$@"
    fi
}

remote_database_container_ip() {
    ssh_remote "container='$REMOTE_DATABASE_CONTAINER'; if command -v docker >/dev/null 2>&1; then docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{\"\\n\"}}{{end}}' \"\$container\" 2>/dev/null || sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{\"\\n\"}}{{end}}' \"\$container\"; fi" \
        | awk 'NF { print; exit }'
}

remote_host_listens_on_database_port() {
    ssh_remote "port='$REMOTE_DATABASE_PORT'; ss -ltn 2>/dev/null | awk -v port=\":${REMOTE_DATABASE_PORT}\" 'NR > 1 && index(\$4, port) { found=1 } END { exit(found ? 0 : 1) }'"
}

resolve_remote_database_host() {
    case "$REMOTE_DATABASE_DISCOVERY" in
        direct)
            printf '%s\n' "$REMOTE_DATABASE_HOST"
            return
            ;;
        container)
            resolved_host="$(remote_database_container_ip)"
            [ -n "$resolved_host" ] || die "failed to resolve container IP for $REMOTE_DATABASE_CONTAINER on $REMOTE_HOST"
            printf '%s\n' "$resolved_host"
            return
            ;;
        auto)
            ;;
        *)
            die "REMOTE_DATABASE_DISCOVERY must be auto|direct|container"
            ;;
    esac

    case "$REMOTE_DATABASE_HOST" in
        127.0.0.1|localhost|::1)
            if remote_host_listens_on_database_port; then
                printf '%s\n' "$REMOTE_DATABASE_HOST"
                return
            fi

            resolved_host="$(remote_database_container_ip)"
            [ -n "$resolved_host" ] || die "remote host does not listen on $REMOTE_DATABASE_HOST:$REMOTE_DATABASE_PORT and container $REMOTE_DATABASE_CONTAINER could not be resolved"
            printf '%s\n' "$resolved_host"
            ;;
        *)
            printf '%s\n' "$REMOTE_DATABASE_HOST"
            ;;
    esac
}

tunnel_listener_pid() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$LOCAL_DATABASE_PORT" -sTCP:LISTEN -t 2>/dev/null | head -n 1
    fi
}

process_command() {
    ps -p "$1" -o command= 2>/dev/null
}

start_tunnel() {
    if ! is_enabled "$START_TUNNEL" "START_TUNNEL"; then
        log "START_TUNNEL=0, skipping SSH tunnel"
        return
    fi

    require_cmd ssh

    remote="${REMOTE_USER}@${REMOTE_HOST}"
    resolved_remote_database_host="$(resolve_remote_database_host)"
    forward="${LOCAL_DATABASE_BIND_HOST}:${LOCAL_DATABASE_PORT}:${resolved_remote_database_host}:${REMOTE_DATABASE_PORT}"

    if port_open "$LOCAL_DATABASE_BIND_HOST" "$LOCAL_DATABASE_PORT"; then
        pid="$(tunnel_listener_pid || true)"
        if [ -n "${pid:-}" ]; then
            cmd="$(process_command "$pid" || true)"
            expected_fragment="${LOCAL_DATABASE_BIND_HOST}:${LOCAL_DATABASE_PORT}:${resolved_remote_database_host}:${REMOTE_DATABASE_PORT}"
            case "$cmd" in
                *ssh*"$expected_fragment"*"$remote"*)
                    log "reusing local SSH tunnel on $LOCAL_DATABASE_BIND_HOST:$LOCAL_DATABASE_PORT"
                    return
                    ;;
                *ssh*)
                    log "found stale SSH tunnel on $LOCAL_DATABASE_BIND_HOST:$LOCAL_DATABASE_PORT, recreating it"
                    kill "$pid"
                    sleep 1
                    ;;
                *)
                    die "local port $LOCAL_DATABASE_BIND_HOST:$LOCAL_DATABASE_PORT is already in use by another process: $cmd"
                    ;;
            esac
        else
            die "local port $LOCAL_DATABASE_BIND_HOST:$LOCAL_DATABASE_PORT is already in use"
        fi
    fi

    log "opening SSH tunnel: $forward via $remote"

    password="$(ssh_password_value)"
    if [ -n "$password" ]; then
        require_cmd sshpass
        SSHPASS="$password" sshpass -e ssh -f -N -p "$REMOTE_PORT" $SSH_OPTS -L "$forward" "$remote"
    else
        ssh -f -N -p "$REMOTE_PORT" $SSH_OPTS -L "$forward" "$remote"
    fi

    sleep 2
    if ! port_open "$LOCAL_DATABASE_BIND_HOST" "$LOCAL_DATABASE_PORT"; then
        die "SSH tunnel did not become ready on $LOCAL_DATABASE_BIND_HOST:$LOCAL_DATABASE_PORT"
    fi
}

compose_run() {
    COMPOSE="$(find_compose)"
    if [ "$LOCAL_OS" = "win" ]; then
        COMPOSE_CONVERT_WINDOWS_PATHS="${COMPOSE_CONVERT_WINDOWS_PATHS:-1}" \
            $COMPOSE --env-file "$RUNTIME_ENV_FILE" -f "$RUNTIME_COMPOSE_FILE" "$@"
    else
        $COMPOSE --env-file "$RUNTIME_ENV_FILE" -f "$RUNTIME_COMPOSE_FILE" "$@"
    fi
}

open_url_hint() {
    url="http://$BIND_HOST:$SERVER_PORT"
    log "local URL: $url"
}

case "$ACTION" in
    up)
        start_tunnel
        build_images
        write_runtime_files
        compose_run up -d --remove-orphans
        compose_run ps
        open_url_hint
        ;;
    build)
        build_images
        ;;
    tunnel)
        start_tunnel
        ;;
    restart)
        start_tunnel
        build_images
        write_runtime_files
        compose_run up -d --force-recreate --remove-orphans
        compose_run ps
        open_url_hint
        ;;
    down)
        write_runtime_files
        compose_run down
        ;;
    ps)
        write_runtime_files
        compose_run ps
        ;;
    logs)
        write_runtime_files
        shift || true
        compose_run logs -f "$@"
        ;;
    config)
        write_runtime_files
        compose_run config
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        die "unknown action: $ACTION"
        ;;
esac
