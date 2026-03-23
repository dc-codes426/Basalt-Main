#!/bin/sh
set -e

# shellcheck source=dstack-derive.sh
. /dstack-derive.sh

# --- Derive Redis password from TEE ---
DERIVED_PASSWORD=$(derive_key "basalt/redis-password") || true
if [ -n "$DERIVED_PASSWORD" ]; then
    echo "Redis password derived from dstack TEE."
    REDIS_PASSWORD="$DERIVED_PASSWORD"
elif [ -n "$REDIS_PASSWORD" ]; then
    echo "Using Redis password from environment."
else
    echo "WARNING: No Redis password set. Starting Redis without authentication."
    exec redis-server "$@"
fi

exec redis-server --requirepass "$REDIS_PASSWORD" "$@"
