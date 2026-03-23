#!/bin/sh
set -e

# shellcheck source=dstack-derive.sh
. /dstack-derive.sh

# --- Derive MinIO credentials from TEE ---
DERIVED_PASSWORD=$(derive_key "basalt/minio-password") || true
if [ -n "$DERIVED_PASSWORD" ]; then
    echo "MinIO credentials derived from dstack TEE."
    MINIO_ROOT_PASSWORD="$DERIVED_PASSWORD"
elif [ -z "$MINIO_ROOT_PASSWORD" ]; then
    echo "ERROR: No MinIO password available." >&2
    exit 1
fi

BUCKET="${BLOCK_STORAGE_BUCKET:-vaults}"
MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"

# Wait for MinIO to be ready and configure the alias
for i in 1 2 3 4 5 6; do
    mc alias set local "http://minio:9000" "$MINIO_USER" "$MINIO_ROOT_PASSWORD" && break
    echo "Waiting for MinIO..." && sleep 5
done

# Create bucket and enable auto-encryption
mc mb --ignore-existing "local/${BUCKET}"
if mc encrypt set sse-s3 "local/${BUCKET}" 2>/dev/null; then
    echo "Bucket auto-encryption enabled (SSE-S3)."
else
    echo "SSE not available — bucket encryption skipped."
fi
