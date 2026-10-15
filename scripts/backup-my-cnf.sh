#!/usr/bin/env bash
# Configuration backup only; not a database/data backup.
set -euo pipefail
umask 077
if (( EUID != 0 )); then
    echo '[ERROR] Run with sudo/root to read system configuration.' >&2
    exit 1
fi
BACKUP_DIR=/root/mysql-cnf-backups
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
PATHS=()
for path in etc/my.cnf etc/my.cnf.d etc/mysql; do
    [[ ! -e /$path ]] || PATHS+=("$path")
done
if (( ${#PATHS[@]} == 0 )); then
    echo '[ERROR] No standard configuration paths found.' >&2
    exit 1
fi
TARGET=$(mktemp "$BACKUP_DIR/mysql_config_$(date +%Y%m%d_%H%M%S)_XXXXXX.tar.gz")
trap 'rm -f -- "$TARGET"' EXIT
# Preserve symlinks; external include files and symlink targets require separate backup.
tar -czf "$TARGET" -C / "${PATHS[@]}"
tar -tzf "$TARGET" >/dev/null
trap - EXIT
printf '[SUCCESS] Configuration archive: %s\n' "$TARGET"
echo 'Also back up external include files/symlink targets. This is not a database backup.'
