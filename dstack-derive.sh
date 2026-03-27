#!/bin/sh
# Shared helper for deriving secrets from the dstack TEE key derivation API.
# Source this file, then call: derive_key <path>
#
# Returns a 64-char hex string (256-bit key) derived deterministically from
# the TEE hardware identity + the given path. Same code + same path = same key
# across restarts.
#
# Falls back gracefully: if dstack socket is unavailable, returns empty string
# so callers can fall back to env vars.

DSTACK_SOCKET="${DSTACK_SOCKET:-/var/run/dstack.sock}"

derive_key() {
    _path="$1"
    if [ -z "$_path" ]; then
        echo "derive_key: path argument required" >&2
        return 1
    fi

    if [ ! -S "$DSTACK_SOCKET" ]; then
        return 0
    fi

    _response=$(curl -sf --unix-socket "$DSTACK_SOCKET" \
        -X POST "http://localhost/prpc/Getkey" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${_path}\"}")

    if [ $? -ne 0 ] || [ -z "$_response" ]; then
        echo "derive_key: dstack request failed for path '$_path'" >&2
        return 1
    fi

    # Extract hex key from JSON response. Adjust field name if dstack API differs.
    _key=$(echo "$_response" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([0-9a-fA-F]*\)".*/\1/p')

    if [ -z "$_key" ]; then
	    echo "derive_key: failed to parse key from dstack response for path '$_path' (unexpected response)" >&2
        return 1
    fi
    
    echo "derive_key successful for path '$_path'"
    printf '%s' "$_key"
}
