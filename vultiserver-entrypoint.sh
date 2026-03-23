#!/bin/sh
set -e

# shellcheck source=dstack-derive.sh
. /dstack-derive.sh

# --- Derive Redis password from TEE ---
DERIVED_REDIS=$(derive_key "basalt/redis-password") || true
if [ -n "$DERIVED_REDIS" ]; then
    echo "Redis password derived from dstack TEE."
    export REDIS_PASSWORD="$DERIVED_REDIS"
elif [ -z "$REDIS_PASSWORD" ]; then
    echo "WARNING: No Redis password available."
fi

# --- Derive MinIO credentials from TEE ---
DERIVED_MINIO=$(derive_key "basalt/minio-password") || true
if [ -n "$DERIVED_MINIO" ]; then
    echo "MinIO credentials derived from dstack TEE."
    export BLOCK_STORAGE_SECRET="$DERIVED_MINIO"
elif [ -z "$BLOCK_STORAGE_SECRET" ]; then
    echo "WARNING: No MinIO password available."
fi

# Run the original entrypoint (starts worker + HTTP server)
exec /root/entrypoint.sh "$@"
