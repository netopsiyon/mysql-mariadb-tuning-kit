#!/usr/bin/env bash
# Partial configured-buffer estimate, not a memory ceiling or safety verdict.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/db-common.sh"
if [[ ! -r /proc/meminfo ]]; then
    echo "[ERROR] Linux /proc/meminfo is required." >&2
    exit 1
fi
RAM_KB=$(awk '$1 == "MemTotal:" {print $2}' /proc/meminfo)
if [[ ! $RAM_KB =~ ^[0-9]+$ ]] || (( RAM_KB < 1024 )); then
    echo "[ERROR] Cannot determine host RAM." >&2
    exit 1
fi
GLOBAL=0
for key in innodb_buffer_pool_size innodb_log_buffer_size key_buffer_size; do
    value=$(variable "$key")
    GLOBAL=$((GLOBAL + value))
done
PER_CONNECTION=0
for key in sort_buffer_size read_buffer_size read_rnd_buffer_size join_buffer_size thread_stack binlog_cache_size; do
    value=$(variable "$key")
    PER_CONNECTION=$((PER_CONNECTION + value))
done
MAX_CONNECTIONS=$(variable max_connections)
TMP_TABLE=$(variable tmp_table_size)
HEAP_TABLE=$(variable max_heap_table_size)
ESTIMATE=$((GLOBAL + PER_CONNECTION * MAX_CONNECTIONS))
printf 'Local host RAM: %s MiB\n' "$((RAM_KB / 1024))"
printf 'Selected global buffers: %s MiB\n' "$((GLOBAL / 1048576))"
printf 'One set of selected connection buffers: %s KiB\n' "$((PER_CONNECTION / 1024))"
printf 'max_connections: %s\n' "$MAX_CONNECTIONS"
printf 'Partial estimate at max_connections: %s MiB (%s of host RAM)\n' "$((ESTIMATE / 1048576))" "$(ratio "$ESTIMATE" "$((RAM_KB * 1024))")"
printf 'tmp_table_size: %s MiB; max_heap_table_size: %s MiB\n' "$((TMP_TABLE / 1048576))" "$((HEAP_TABLE / 1048576))"
cat <<'NOTE'
This estimate is NOT actual RSS, a worst-case bound, or proof of safety.
Run on the database host against its local database. Remote connections compare
remote settings with local RAM; the resulting percentage is not meaningful.
Buffers are allocated on demand; a query can allocate multiple join/sort buffers.
Excluded: temporary tables, packet buffers, Performance Schema, table caches,
replication, engine overhead, other processes and OS memory. TempTable behavior
and limits differ by engine/version. Host RAM may exceed a container/cgroup limit.
Check peak RSS, effective service/container memory limits and workload concurrency.
Reserve memory for the OS and web services; do not tune from this estimate alone.
NOTE
if (( ESTIMATE * 100 > RAM_KB * 1024 * 85 )); then
    echo '[WARNING] Even this partial estimate exceeds 85% of host RAM.'
fi
