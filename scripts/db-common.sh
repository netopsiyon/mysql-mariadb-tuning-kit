#!/usr/bin/env bash
# Shared read-only client helpers. Sourced by diagnostic scripts.
set -euo pipefail
export LC_ALL=C
if command -v mariadb >/dev/null 2>&1; then
    DB_CLIENT=mariadb
elif command -v mysql >/dev/null 2>&1; then
    DB_CLIENT=mysql
else
    echo "[ERROR] Install the mariadb or mysql command-line client." >&2
    exit 1
fi
# Pass client options through, e.g. --defaults-extra-file=/secure/client.cnf.
DB_ARGS=("$@")
if ! DB_VARIABLES=$("$DB_CLIENT" "${DB_ARGS[@]}" --batch --skip-column-names -e 'SHOW GLOBAL VARIABLES;'); then
    echo "[ERROR] Cannot read server variables. Check credentials and permissions." >&2
    exit 1
fi
number() {
    local value
    value=$(awk -v key="$2" '$1 == key {print $2; exit}' <<< "$1")
    if [[ ! $value =~ ^[0-9]+$ ]]; then
        echo "[ERROR] Missing or non-numeric server value: $2" >&2
        return 1
    fi
    printf '%s\n' "$value"
}
variable() { number "$DB_VARIABLES" "$1"; }
ratio() {
    awk -v n="$1" -v d="$2" -v complement="${3:-0}" 'BEGIN {
        if (d == 0) {print "N/A"; exit}
        printf "%.2f%%", (complement ? 1-n/d : n/d)*100
    }'
}
