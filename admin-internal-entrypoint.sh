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

exec basalt-admin-internal "$@"
