#!/usr/bin/env bash
# Isolated client fixtures: no database connection or system configuration changes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP=$(mktemp -d)
trap 'rm -rf -- "$TEMP"' EXIT
cat > "$TEMP/mariadb" <<'MOCK'
#!/usr/bin/env bash
if [[ ${FIXTURE:-normal} == failure ]]; then exit 1; fi
if [[ "$*" == *'SHOW GLOBAL VARIABLES;'* ]]; then
    printf 'max_connections\t200\nopen_files_limit\t65535\n'
else
    if [[ ${FIXTURE:-normal} == missing ]]; then exit 0; fi
    for key in Uptime Questions Threads_connected Threads_running Max_used_connections Slow_queries Innodb_buffer_pool_reads Innodb_buffer_pool_read_requests Created_tmp_disk_tables Created_tmp_tables Threads_created Connections Open_files Innodb_row_lock_waits Innodb_row_lock_time; do
        value=0
        if [[ ${FIXTURE:-normal} == normal ]]; then
            value=10
            [[ $key != Uptime ]] || value=86400
            [[ $key != Innodb_buffer_pool_read_requests ]] || value=1000
            [[ $key != Connections ]] || value=100
        fi
        printf '%s\t%s\n' "$key" "$value"
    done
fi
MOCK
chmod +x "$TEMP/mariadb"
export PATH="$TEMP:$PATH"
FIXTURE=normal bash "$ROOT/scripts/quick-health-check.sh" > "$TEMP/report"
grep -q 'InnoDB buffer hit ratio: 99.00%' "$TEMP/report"
grep -q 'Connected / Running / Peak / Connection limit: 10 / 10 / 10 / 200' "$TEMP/report"
FIXTURE=zero bash "$ROOT/scripts/quick-health-check.sh" > "$TEMP/report"
grep -q 'InnoDB buffer hit ratio: N/A' "$TEMP/report"
if FIXTURE=missing bash "$ROOT/scripts/quick-health-check.sh" > "$TEMP/report" 2>&1; then
    echo 'FAIL: missing counter accepted' >&2; exit 1
fi
if FIXTURE=failure bash "$ROOT/scripts/quick-health-check.sh" > "$TEMP/report" 2>&1; then
    echo 'FAIL: failed client accepted' >&2; exit 1
fi
echo 'PASS: normal counters, zero activity, missing counters, client failure'
