#!/bin/bash

# ================================================
# SERVER HEALTH MONITOR
# Author: Akeel
# Version: 1.0
# Description: Monitors CPU, RAM, Disk, I/O and
#              services. Logs results with WARNING
#              and CRITICAL tiers. Runs via cron.
# ================================================

# paths

LOG_FILE="/var/log/health_monitor.log"
CPU_COUNTER_FILE="/tmp/cpu_high_count"

# threshholds

CPU_WARN=70
CPU_CRIT=90
CPU_SUSTAIN_MINUTES=5

MEM_WARN=80
MEM_CRIT=95

DISK_WARN=80
DISK_CRIT=90

IO_WARN=20
IO_CRIT=50

# counters

WARNS=0
CRITS=0

# Timestamp

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# functions

log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
    echo "[$TIMESTAMP] $1"
}

log_warn() {
    echo "[$TIMESTAMP] [WARNING]  $1" >> "$LOG_FILE"
    echo "[$TIMESTAMP] [WARNING]  $1"
}

log_crit() {
    echo "[$TIMESTAMP] [CRITICAL] $1" >> "$LOG_FILE"
    echo "[$TIMESTAMP] [CRITICAL] $1"
}

separator() {
    echo "[$TIMESTAMP] ------------------------------------------------" >> "$LOG_FILE"
    echo "[$TIMESTAMP] ------------------------------------------------"
}


check_cpu() {
    log "--- CPU Check ---"

CPU_USAGE=$(top -bn1 2>/dev/null \
        | grep "Cpu(s)" \
        | awk '{print $2}' \
        | cut -d'%' -f1 \
        | cut -d'.' -f1)

if [ -z "$CPU_USAGE" ]; then
        log "  CPU: could not read value"
        return
    fi

    log "  Usage: ${CPU_USAGE}%"

if [ -f "$CPU_COUNTER_FILE" ]; then
        COUNT=$(cat "$CPU_COUNTER_FILE")
    else
        COUNT=0
    fi

if [ "$CPU_USAGE" -ge "$CPU_CRIT" ]; then

	COUNT=$((COUNT + 1))
        echo "$COUNT" > "$CPU_COUNTER_FILE"

        if [ "$COUNT" -ge "$CPU_SUSTAIN_MINUTES" ]; then
            log_crit "CPU at ${CPU_USAGE}% — sustained ${COUNT} min. Scale horizontally or optimise code."
            CRITS=$((CRITS + 1))
        else
            log_warn "CPU at ${CPU_USAGE}% critical level — ${COUNT}/${CPU_SUSTAIN_MINUTES} min sustained so far."
            CRITS=$((CRITS + 1))
        fi

elif [ "$CPU_USAGE" -ge "$CPU_WARN" ]; then

        COUNT=$((COUNT + 1))
        echo "$COUNT" > "$CPU_COUNTER_FILE"

        if [ "$COUNT" -ge "$CPU_SUSTAIN_MINUTES" ]; then
            log_warn "CPU at ${CPU_USAGE}% — sustained ${COUNT} min. Monitor closely."
            WARNS=$((WARNS + 1))
        else
            log_warn "CPU at ${CPU_USAGE}% warning level — ${COUNT}/${CPU_SUSTAIN_MINUTES} min sustained so far."
            WARNS=$((WARNS + 1))
        fi

else
        echo "0" > "$CPU_COUNTER_FILE"
        log "  CPU: OK (${CPU_USAGE}%)"
    fi
}


check_memory() {
    log "--- Memory Check ---"

TOTAL=$(free -m | awk '/^Mem:/{print $2}')
USED=$(free -m  | awk '/^Mem:/{print $3}')
AVAIL=$(free -m | awk '/^Mem:/{print $7}')

MEM_PERCENT=$(( USED * 100 / TOTAL ))

    log "  Usage: ${MEM_PERCENT}% — ${USED}MB used, ${AVAIL}MB available of ${TOTAL}MB total"

    if [ "$MEM_PERCENT" -ge "$MEM_CRIT" ]; then
        log_crit "RAM at ${MEM_PERCENT}%. Check for memory leaks or upgrade RAM."
        CRITS=$((CRITS + 1))
    elif [ "$MEM_PERCENT" -ge "$MEM_WARN" ]; then
        log_warn "RAM at ${MEM_PERCENT}%. Monitor for memory leaks."
        WARNS=$((WARNS + 1))
    else
        log "  RAM: OK (${MEM_PERCENT}%)"
    fi
}


check_disk() {
    log "--- Disk Storage Check ---"

while IFS= read -r LINE; do

        FILESYSTEM=$(echo "$LINE" | awk '{print $1}')
        USAGE=$(echo "$LINE"      | awk '{print $5}' | tr -d '%')
        MOUNTPOINT=$(echo "$LINE" | awk '{print $6}')

if echo "$FILESYSTEM" | grep -qE "^(tmpfs|devtmpfs|udev)"; then
            continue
fi

if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
            continue
        fi

log "  $MOUNTPOINT: ${USAGE}% used"

        if [ "$USAGE" -ge "$DISK_CRIT" ]; then
            log_crit "Disk at $MOUNTPOINT is ${USAGE}% full. Archive data or expand partition."
            CRITS=$((CRITS + 1))
        elif [ "$USAGE" -ge "$DISK_WARN" ]; then
            log_warn "Disk at $MOUNTPOINT is ${USAGE}% full. Consider archiving old data."
            WARNS=$((WARNS + 1))
        fi

    done < <(df -h | tail -n +2)
}

check_disk_io() {
    log "--- Disk I/O Check ---"

if ! command -v iostat &>/dev/null; then
        log "  Disk I/O: iostat not found. Run: sudo apt install sysstat"
        return
    fi

    FOUND_ANY=false
while IFS= read -r LINE; do
        DEVICE=$(echo "$LINE" | awk '{print $1}')
        AWAIT=$(echo "$LINE"  | awk '{print $10}')
if echo "$DEVICE" | grep -qE "^(loop|ram|sr)"; then
            continue
        fi
if [ -z "$AWAIT" ] || [ "$DEVICE" = "Device" ]; then
            continue
        fi

        FOUND_ANY=true
AWAIT_INT=$(echo "$AWAIT" | cut -d'.' -f1)

        log "  /dev/$DEVICE: ${AWAIT}ms avg I/O latency"

        # 2>/dev/null in case AWAIT_INT is somehow not numeric
        if [ "$AWAIT_INT" -ge "$IO_CRIT" ] 2>/dev/null; then
            log_crit "/dev/$DEVICE latency ${AWAIT}ms. Check hardware or reduce I/O load."
            CRITS=$((CRITS + 1))
        elif [ "$AWAIT_INT" -ge "$IO_WARN" ] 2>/dev/null; then
            log_warn "/dev/$DEVICE latency ${AWAIT}ms. Check for heavy background tasks."
            WARNS=$((WARNS + 1))
        fi
done < <(iostat -x 1 2 | grep -A 100 "Device" | tail -n +2)

 if [ "$FOUND_ANY" = false ]; then
        log "  Disk I/O: no physical devices found (normal on WSL virtual disk)"
    fi
}

check_services() {
    log "--- Service Check ---"

SERVICES=("ssh" "cron")
for SERVICE in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$SERVICE")

if [ "$STATUS" = "active" ]; then
            log "  $SERVICE: RUNNING"
        else
log "  $SERVICE: $STATUS"
        fi
    done
}

#!/bin/bash

# ... (Previous check functions should be defined above)

print_summary() {
    if [ "$CRITS" -gt 0 ]; then
        log_crit "ACTION REQUIRED — ${CRITS} critical issue(s) detected."
    elif [ "$WARNS" -gt 0 ]; then
        log_warn "ATTENTION — ${WARNS} warning(s) detected this run."
    else
        log "  All systems healthy."
    fi
}

touch "$LOG_FILE" 2>/dev/null || {
    echo "Cannot write to $LOG_FILE — try: sudo touch $LOG_FILE"
    exit 1
}

separator
log "Health check started on $(hostname) by $(whoami)"
log "Thresholds: CPU warn=${CPU_WARN}% crit=${CPU_CRIT}% | RAM warn=${MEM_WARN}% crit=${MEM_CRIT}% | Disk warn=${DISK_WARN}% crit=${DISK_CRIT}% | IO warn=${IO_WARN}ms crit=${IO_CRIT}ms"
separator

check_cpu
check_memory
check_disk
check_disk_io
check_services
print_summary

separator
log "Health check complete"
separator
