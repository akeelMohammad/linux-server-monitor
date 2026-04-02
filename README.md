# Linux Server Health Monitor

A Bash script to monitor server health metrics including CPU usage, RAM, disk storage, disk I/O latency, and service statuses. Results are logged with WARNING and CRITICAL alerts based on configurable thresholds.

## Features

- **CPU Monitoring**: Tracks usage with sustained high-usage detection.
- **Memory Monitoring**: Checks RAM usage.
- **Disk Storage**: Monitors all mounted filesystems.
- **Disk I/O**: Measures average I/O latency (requires `iostat` from `sysstat`).
- **Service Checks**: Verifies status of specified services (e.g., SSH, Cron).
- **Logging**: Outputs to both terminal and `/var/log/health_monitor.log`.
- **Configurable Thresholds**: Easy to adjust warning and critical levels.

## Requirements

- Linux system (tested on Ubuntu/WSL).
- Bash shell.
- `iostat` command (install with `sudo apt install sysstat` if missing).
- Write access to `/var/log/health_monitor.log` (or run with `sudo`).

## Installation

1. Clone or download the script to your server.
2. Make it executable: `chmod +x monitor.sh`
3. Run manually or set up cron for automation.

## Usage

### Manual Run
```bash
./monitor.sh
```
Output displays in terminal and logs to `/var/log/health_monitor.log`.

### Automated with Cron
Edit crontab: `crontab -e`
Add a line for periodic checks, e.g.:
```
*/5 * * * * /path/to/monitor.sh  # Every 5 minutes
```

### View Logs
- Full log: `cat /var/log/health_monitor.log`
- Latest entries: `tail -n 50 /var/log/health_monitor.log`

## Thresholds

Default values (editable in script):
- **CPU**: Warn 70%, Crit 90%, Sustain 5 min
- **RAM**: Warn 80%, Crit 95%
- **Disk**: Warn 80%, Crit 90%
- **I/O Latency**: Warn 20ms, Crit 50ms

## Services Monitored

- SSH
- Cron

Add more in the `SERVICES` array.

## Output Example

```
[2026-04-02 19:42:29] ------------------------------------------------
[2026-04-02 19:42:29] Health check started on hostname by user
[2026-04-02 19:42:29] Thresholds: CPU warn=70% crit=90% | RAM warn=80% crit=95% | Disk warn=80% crit=90% | IO warn=20ms crit=50ms
[2026-04-02 19:42:29] --- CPU Check ---
[2026-04-02 19:42:29]   Usage: 1%
[2026-04-02 19:42:29]   CPU: OK (1%)
[2026-04-02 19:42:29] --- Memory Check ---
[2026-04-02 19:42:29]   Usage: 5% — 462MB used, 7361MB available of 7824MB total
[2026-04-02 19:42:29]   RAM: OK (5%)
... (disk, I/O, services)
[2026-04-02 19:42:29]   All systems healthy.
[2026-04-02 19:42:29] ------------------------------------------------
[2026-04-02 19:42:29] Health check complete
[2026-04-02 19:42:29] ------------------------------------------------
```

## Customization

- Edit thresholds at the top of `monitor.sh`.
- Modify services in `check_services()`.
- Change log file path if needed.

## License

Free to use and modify.

## Author

Akeel (Version 1.0)</content>
<parameter name="filePath">\\wsl.localhost\Ubuntu\home\akeel\linux-server-monitor\README.md