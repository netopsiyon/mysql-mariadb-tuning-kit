#!/usr/bin/env bash
# Read-only cumulative counters; these queries also add a little activity.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/db-common.sh"
DB_STATUS=$("$DB_CLIENT" "${DB_ARGS[@]}" --batch --skip-column-names -e 'SHOW GLOBAL STATUS;')
status() { number "$DB_STATUS" "$1"; }
# Validate every required value before formatting (printf can mask substitution errors).
for key in Uptime Questions Threads_connected Threads_running Max_used_connections Slow_queries Innodb_buffer_pool_reads Innodb_buffer_pool_read_requests Created_tmp_disk_tables Created_tmp_tables Threads_created Connections Open_files Innodb_row_lock_waits Innodb_row_lock_time; do
    status "$key" >/dev/null
done
for key in max_connections open_files_limit; do
    variable "$key" >/dev/null
done
UPTIME=$(status Uptime)
QUESTIONS=$(status Questions)
printf 'MySQL / MariaDB counter snapshot\n'
printf 'Uptime: %s seconds\n' "$UPTIME"
printf 'Average Questions/sec since startup: %s\n' "$(awk -v q="$QUESTIONS" -v t="$UPTIME" 'BEGIN {if(t==0) print "N/A"; else printf "%.2f",q/t}')"
printf 'Connected / Running / Peak / Connection limit: %s / %s / %s / %s\n' "$(status Threads_connected)" "$(status Threads_running)" "$(status Max_used_connections)" "$(variable max_connections)"
printf 'Slow queries: %s\n' "$(status Slow_queries)"
printf 'InnoDB buffer hit ratio: %s\n' "$(ratio "$(status Innodb_buffer_pool_reads)" "$(status Innodb_buffer_pool_read_requests)" 1)"
printf 'Reported disk temporary table ratio: %s\n' "$(ratio "$(status Created_tmp_disk_tables)" "$(status Created_tmp_tables)")"
printf 'Thread cache reuse estimate: %s\n' "$(ratio "$(status Threads_created)" "$(status Connections)" 1)"
printf 'Open files / configured limit: %s / %s (%s)\n' "$(status Open_files)" "$(variable open_files_limit)" "$(ratio "$(status Open_files)" "$(variable open_files_limit)")"
printf 'InnoDB row lock waits: %s; cumulative wait time: %s ms\n' "$(status Innodb_row_lock_waits)" "$(status Innodb_row_lock_time)"
cat <<'NOTE'
Ratios are cumulative counter estimates, not pass/fail health checks.
N/A means no denominator activity. Counter resets affect interpretation.
Threads_running includes this diagnostic query. Thread pooling affects cache metrics.
MySQL TempTable mmap overflow is not counted in Created_tmp_disk_tables.
Investigate query plans, storage latency, concurrency and memory before changing limits.
Open_files does not represent every file descriptor used by the server process.
NOTE
if (( UPTIME < 86400 )); then
    echo '[NOTE] Under 24h uptime; collect representative workload samples over 24-48h.'
fi
