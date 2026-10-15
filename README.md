# MySQL & MariaDB Tuning Kit

Configuration starting points and read-only Bash diagnostics for Linux database servers.
These templates are not universal production settings. Review your workload, existing
configuration, exact server version, storage and effective memory limits before applying.
No live database startup or workload benchmarks have been performed for this repository.

## Profiles

| File in `configs/` | Intended host | Buffer pool | Connection limit |
| --- | --- | --- | --- |
| `4GB-ram-web-server.cnf` | 4 GiB shared web + DB | 1.5 GiB | 100 |
| `8GB-ram-dedicated-db.cnf` | 8 GiB dedicated DB | 5.5 GiB | 200 |
| `16GB-ram-high-traffic.cnf` | 16 GiB dedicated DB | 11 GiB | 350 |
| `32GB-ram-enterprise.cnf` | 32 GiB dedicated DB | 22 GiB | 600 |

Names describe intended scenarios, not guaranteed throughput. Connection limits are
starting points, not concurrency targets. For containers use the cgroup/service memory
limit, not host RAM. Leave room for the OS, other services and peak query allocations.

## Compatibility and defaults

Intended review targets: MySQL 8.0.16+/8.4 and MariaDB 10.11/11.4 on Linux.
This is a review scope, not a tested compatibility certification or a recommendation to
use an unsupported release. Other versions require separate validation.

- Common templates omit `innodb_buffer_pool_instances` (removed in MariaDB 10.6).
- Redo sizing uses existing/server defaults. MySQL 8.0.30+ uses
  `innodb_redo_log_capacity`; older MySQL and MariaDB have different redo controls.
  Size redo separately for the exact engine/version; never delete redo files as a tuning step.
- `innodb_flush_log_at_trx_commit=1` retains commit-time flushing. Binary-log durability
  also depends on existing `sync_binlog` settings and storage behavior; review separately.
- SQL mode, name resolution, thread stack and storage I/O tuning retain existing/default
  values. RAM capacity alone does not determine storage IOPS or CPU thread settings.
- Per-query buffers start small, and temporary table limits are 32 MiB. These are not
  total memory caps. MySQL TempTable has engine/version-specific aggregate limits.
- Slow logging is enabled without forcing an absolute log path. Check the effective
  path, permissions, free disk space and log rotation first.
- cPanel/WHM, Plesk and distribution-managed hosts may use different configuration
  locations and restart procedures. Follow the installed platform's supported workflow.

## Diagnostics

```bash
git clone https://github.com/netopsiyon/mysql-mariadb-tuning-kit.git
cd mysql-mariadb-tuning-kit
chmod +x scripts/*.sh
./scripts/db-memory-calculator.sh
./scripts/quick-health-check.sh
```

Requires Bash, awk, a `mariadb` or `mysql` client, and Linux `/proc/meminfo` for the
memory estimate. Both diagnostics source `scripts/db-common.sh`; keep the scripts together.
Use socket authentication or a protected client option file. Do not put passwords on the
command line or commit credentials. Client options are forwarded, for example:

```bash
./scripts/quick-health-check.sh --defaults-extra-file=/secure/client.cnf
```

Protect the client file with mode 600. The account must be able to connect and read
`SHOW GLOBAL VARIABLES` / `SHOW GLOBAL STATUS`; follow your server's privilege policy.
Errors stop the report instead of silently substituting missing values with zero.

The memory report adds selected global buffers and one set of selected per-connection
buffers multiplied by `max_connections`. It is a partial planning estimate, **not a
worst-case bound, measured RSS, or proof that a host is safe**. Temporary tables, packet
buffers, multiple buffers per query, replication, Performance Schema and other allocations
are excluded. Measure peak RSS and concurrency on the actual workload.
Run the memory script on the database host against its local database. With a remote
connection it compares remote settings with local RAM, so the percentage is not meaningful.

The health report shows connections, running threads, slow queries, buffer hit ratio,
reported disk temporary tables, thread reuse, open files and InnoDB row-lock waits.
Counters are cumulative; compare interval samples under representative load. No activity
produces `N/A`, not an artificial 100% success rate. MySQL's disk temporary table counter
omits TempTable mmap overflow. Thread pooling also changes thread-cache interpretation.
A high temporary-table ratio warrants query-plan and memory investigation, not an
automatic increase of `tmp_table_size`. Open_files is not the process's total FD count.

## Apply and roll back

1. Identify the exact server version, service name, configuration root and include order.
   `mysqld --verbose --help` or `mariadbd --verbose --help` can show default paths;
   also inspect service command-line options and included files. Later settings can
   override earlier ones. Do not replace the main configuration with a profile.
2. Back up configuration and ensure a separate recoverable database backup exists:

   ```bash
   sudo ./scripts/backup-my-cnf.sh
   ```

   The archive covers `/etc/my.cnf`, `/etc/my.cnf.d` and `/etc/mysql` when present.
   External includes and symlink targets need separate backups. Archives can contain
   credentials; keep them private. This script does not back up database data.
3. Review and merge one profile into a **new, previously absent** included file.
   Example only, after confirming this directory is read by your installation:

   ```bash
   # This command refuses to overwrite an existing tuning file.
   sudo bash -c 'set -C; cat configs/8GB-ram-dedicated-db.cnf > /etc/mysql/conf.d/tuning.cnf'
   ```

   Record that exact destination for rollback. Check existing log paths and permissions.
4. Validate the complete effective configuration before restarting. For MySQL 8.0.16+,
   use the installed server binary with the same configuration selection as the service:

   ```bash
   sudo mysqld --validate-config
   # If the service uses an explicit defaults file, it must be the first option:
   # sudo mysqld --defaults-file=/actual/root/my.cnf --validate-config
   ```

   For MariaDB 10.11/11.4, inspect `mariadbd --verbose --help` output and diagnostics
   with the same defaults-file selection. This is a limited option-parsing check, not
   a full startup validation. Verify startup on a staging instance with the exact version.
   Never start a second server against the production data directory. Parser checks do
   not prove permissions, service limits, plugins or workload safety.
5. During a maintenance window, restart the confirmed service (`mariadb` or `mysql`),
   check `systemctl status`, its journal/error log, application connectivity and actual
   values using `SHOW GLOBAL VARIABLES`. Observe memory and workload over 24-48 hours.
6. If startup or application checks fail, move the newly added tuning file outside the
   included directory, restore any separately edited settings from your backup, validate
   again, then restart and check logs. Restore only reviewed configuration files; do not
   blindly extract an entire archive over `/etc`. Configuration rollback cannot recover
   lost database data.

## Local checks

```bash
for f in scripts/*.sh tests/*.sh; do bash -n "$f" || exit 1; done
bash tests/diagnostics-smoke.sh
```

The smoke test uses an isolated fake client for normal counters, zero activity,
missing counters and connection errors. It does not prove live database compatibility.

## Contributing

Report exact engine/version, RAM/service limits, workload and reproducible measurements.
Remove passwords, host identities and customer data before sharing reports.

Maintained by [Netopsiyon](https://www.netopsiyon.com).

---

## Türkçe kullanım

Bu depo, Linux için başlangıç yapılandırmaları ve salt okunur tanılama betikleri içerir.
Profiller her sunucuya doğrudan uygulanabilir ayarlar değildir. Canlı sürüm uyumluluğu
ve performans testi henüz yapılmamıştır.

1. Sunucu sürümünü, gerçek bellek sınırını, okunan yapılandırma dosyalarını ve servis
   adını belirleyin. Paylaşımlı sunucuda web/PHP süreçlerine de bellek ayırın.
2. Tanılama betiklerini çalıştırın. Bellek betiğini doğrudan veritabanı sunucusunda,
   yerel veritabanına bağlanarak kullanın. Uzak bağlantıda yerel RAM ile uzak sunucunun
   ayarları karşılaştırılır ve yüzde anlamını kaybeder. Sonuç yalnızca kısmi tahmindir;
   güvenli üst sınır veya gerçek tüketim değildir. Konteyner limitini ayrıca kontrol edin.
3. `sudo ./scripts/backup-my-cnf.sh` ile ayarları yedekleyin. Bu işlem veritabanı
   verilerini yedeklemez. Harici include dosyalarını ve sembolik bağ hedeflerini ayrıca koruyun.
4. Uygun profili inceleyip gerçekten okunan dizinde yeni bir dosyaya ekleyin; mevcut
   ana dosyanın üzerine yazmayın. Yukarıdaki uygulama bölümündeki doğrulama ve geri alma
   adımlarını izleyin. cPanel/WHM veya Plesk için platformun desteklediği yöntemi uygulayın.
5. `innodb_flush_log_at_trx_commit=1` ayarını koruyun. `2`, işletim sistemi çökmesi
   veya elektrik kesintisinde son onaylanan işlemlerin kaybolmasına yol açabilir.
6. Bakım aralığında yeniden başlatın; günlükleri, uygulama bağlantılarını ve etkin
   değişkenleri kontrol edin. Sorunda yeni dosyayı include dizini dışına taşıyıp önceki
   ayarları geri yükleyin. Üretim veri diziniyle ikinci bir sunucu başlatmayın.

Disk geçici tablo oranını düşürmek için bellek limitlerini körlemesine artırmayın;
önce sorgu planlarını inceleyin. Sayaçlar başlangıçtan veya sıfırlamadan beri birikir.
24-48 saatlik temsili yük ve aralıklı ölçümlerle değerlendirin. Etkinlik yoksa oranlar
`N/A` olarak gösterilir; eksik sayaçlar hata verir.
