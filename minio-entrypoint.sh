#!/bin/sh
set -e

DSTACK_SOCKET="/var/run/dstack.sock"
KEY_PATH="${MINIO_SSE_KEY_PATH:-basalt/vault-encryption}"

if [ -S "$DSTACK_SOCKET" ]; then
    echo "Deriving MinIO master key from dstack TEE..."
    RESPONSE=$(curl -sf --unix-socket "$DSTACK_SOCKET" \
        -X POST "http://localhost/prpc/Getkey" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${KEY_PATH}\"}")
    # Extract hex key from JSON response. Adjust field name if dstack API differs.
    HEX_KEY=$(echo "$RESPONSE" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([0-9a-fA-F]*\)".*/\1/p')
    if [ -z "$HEX_KEY" ]; then
        echo "ERROR: Failed to derive key from dstack. Response: $RESPONSE" >&2
        exit 1
    fi
    echo "Successfully derived master key from dstack TEE."
elif [ -n "$MINIO_SSE_MASTER_KEY" ]; then
    echo "Using static master key from environment."
    HEX_KEY="$MINIO_SSE_MASTER_KEY"
else
    echo "WARNING: No SSE master key available. Starting MinIO without encryption at rest."
    exec minio server /data "$@"
fi

export MINIO_KMS_SECRET_KEY="basalt-vault-key:${HEX_KEY}"
echo "MinIO SSE-S3 encryption enabled."
exec minio server /data "$@"
