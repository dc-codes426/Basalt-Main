#!/bin/bash
set -e

# Phala Cloud pre-launch script: derives secrets from dstack TEE
# and writes /dstack/.env for docker-compose usage.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Function: notify host
notify_host_info() {
    echo "[notify-host] boot.progress: $1"
    dstack-util notify-host -e "boot.progress" -d "$1"
}

notify_host_error() {
    echo "[notify-host] boot.error: $1"
    dstack-util notify-host -e "boot.error" -d "$1"
}

# Function: Perform Docker cleanup
perform_cleanup() {
    echo "Pruning unused images"
    docker image prune -af
    echo "Pruning unused volumes"
    docker volume prune -f
    notify_host_info "docker cleanup completed"
}

# Function: GHCR login
ghcr_login() {
    echo "Logging in to ghcr"
    if [[ -z "$GHCR_USERNAME" || -z "$GHCR_PASSWORD" ]]; then
        echo "No GHCR credentials found, skipping registry login."
        return 0
    fi

    local docker_config_path="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
    if [[ -f "$docker_config_path" ]] && grep -q "ghcr.io" "$docker_config_path"; then
        echo "Already logged in to ghcr.io"
        return 0
    fi

    echo "Logging in to ghcr.io..."
    echo "$GHCR_PASSWORD" | docker login -u "$GHCR_USERNAME" --password-stdin ghcr.io
    if [ $? -eq 0 ]; then
        echo "GHCR login successful."
    else
        echo "ERROR: GHCR login failed."
        notify_host_error "GHCR login failed"
        exit 1
    fi
}

# Function: Derive a key from dstack
derive_key() {
    local path="$1"
    local response
    response=$(curl -sf --unix-socket /var/run/dstack.sock \
        -X POST "http://localhost/GetKey" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${path}\"}")
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo "ERROR: dstack key derivation failed for path '$path'"
        notify_host_error "key derivation with dstack failed"
        exit 1
    fi
    echo "$response" | jq -r '.key // empty'
}

# Function: Derive secrets and write .env file
derive_secrets() {
    echo "Deriving secrets from dstack..."

    if [[ -z "$REDIS_DERIVE_PATH" || -z "$MINIO_DERIVE_PATH" || -z "$MINIO_KMS_DERIVE_PATH" || -z "$MINIO_VULTISERVER_DERIVE_PATH" ]]; then
        echo "ERROR: Derivation path env vars not set."
        notify_host_error "missing derivation path env vars"
        exit 1
    fi

    local redis_password=$(derive_key "$REDIS_DERIVE_PATH")
    local minio_root_password=$(derive_key "$MINIO_DERIVE_PATH")
    local minio_kms_key=$(derive_key "$MINIO_KMS_DERIVE_PATH")
    local minio_vultiserver_password=$(derive_key "$MINIO_VULTISERVER_DERIVE_PATH")

    cat > "$ENV_FILE" <<EOF
REDIS_PASSWORD=${redis_password}
MINIO_ROOT_PASSWORD=${minio_root_password}
MINIO_KMS_SECRET_KEY=basalt-vault-key:${minio_kms_key}
MINIO_VULTISERVER_PASSWORD=${minio_vultiserver_password}
EOF

    echo "Wrote $ENV_FILE"
}

# Main logic starts here
echo "----------------------------------------------"
echo "Running Phala Cloud Pre-Launch Script v0.0.15"
echo "----------------------------------------------"
perform_cleanup
ghcr_login
derive_secrets
notify_host_info "pre-launch completed"
echo "----------------------------------------------"
echo "Script execution completed"
echo "----------------------------------------------"

