#!/bin/sh
set -e

# shellcheck source=dstack-derive.sh
. /dstack-derive.sh

# --- Derive MinIO root password from TEE ---
DERIVED_PASSWORD=$(derive_key "basalt/minio-password") || true
if [ -n "$DERIVED_PASSWORD" ]; then
    echo "MinIO root password derived from dstack TEE."
    export MINIO_ROOT_PASSWORD="$DERIVED_PASSWORD"
elif [ -n "$MINIO_ROOT_PASSWORD" ]; then
    echo "Using MinIO root password from environment."
else
    echo "ERROR: No MinIO root password available." >&2
    exit 1
fi

# --- Derive SSE master key from TEE ---
SSE_KEY_PATH="${MINIO_SSE_KEY_PATH:-basalt/vault-encryption}"
DERIVED_SSE_KEY=$(derive_key "$SSE_KEY_PATH") || true
if [ -n "$DERIVED_SSE_KEY" ]; then
    echo "MinIO SSE master key derived from dstack TEE."
    export MINIO_KMS_SECRET_KEY="basalt-vault-key:${DERIVED_SSE_KEY}"
    echo "MinIO SSE-S3 encryption enabled."
elif [ -n "$MINIO_SSE_MASTER_KEY" ]; then
    echo "Using static SSE master key from environment."
    export MINIO_KMS_SECRET_KEY="basalt-vault-key:${MINIO_SSE_MASTER_KEY}"
    echo "MinIO SSE-S3 encryption enabled."
else
    echo "WARNING: No SSE master key available. Starting MinIO without encryption at rest."
fi

exec minio server /data "$@"
