#!/bin/sh
# Telegraf Exec JSON Disk Collection Script
# Collect disk usage from multiple VMs over SSH and emit JSON per line.

set -eu
set -o pipefail 2>/dev/null || true

[ "${DEBUG:-}" = "1" ] && echo "# DEBUG: Script start" >&2

# Ensure bundled SSH client path is available even if PATH is minimal.
if [ -x /usr/local/bin/ssh-tools/ssh ]; then
    PATH="/usr/local/bin/ssh-tools:$PATH"
    export PATH
fi

SSH_INSTALLED=0
if ! command -v ssh >/dev/null 2>&1; then
    echo "# SSH client not found - attempting install" >&2
    if command -v apk >/dev/null 2>&1; then
        if apk add --no-cache openssh-client >/dev/null 2>&1; then
            SSH_INSTALLED=1
            echo "# Installed openssh-client" >&2
        else
            echo "# Failed to install openssh-client" >&2
        fi
    fi
fi

emit_status_array() {
    # Helper to emit a minimal status-only JSON array when we cannot proceed.
    reason="$1"  # e.g. vm_list_missing, ssh_missing, key_missing
    TS_MS=$(( $(date +%s) * 1000 ))
    echo '[{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"start","installed":'$SSH_INSTALLED',"success":0},'
    echo ' {"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"missing","error_reason":"'"$reason"'","installed":'$SSH_INSTALLED',"success":0}]'
}

if ! command -v ssh >/dev/null 2>&1; then
    emit_status_array ssh_missing
    exit 0
fi

SSH_USER="telegraf"
SSH_KEY="${SSH_KEY:-/ssh/id_rsa}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-5}"
SSH_OPTS="-n -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=${SSH_CONNECT_TIMEOUT}"

if [ ! -f "$SSH_KEY" ]; then
    echo "# Missing SSH key $SSH_KEY" >&2
    emit_status_array key_missing
    exit 0
fi
if [ ! -r "$SSH_KEY" ]; then
    echo "# SSH key is not readable: $SSH_KEY" >&2
    emit_status_array key_unreadable
    exit 0
fi

# VM list must be provided via file (e.g., ConfigMap or Secret) referenced by VM_LIST_FILE.
VM_LIST_REASON=""
if [ -n "${VM_LIST_FILE:-}" ] && [ -f "${VM_LIST_FILE}" ]; then
    VMS="$(grep -Ev '^[[:space:]]*($|#)' "$VM_LIST_FILE" || true)"
    if [ -z "$VMS" ]; then
        VM_LIST_REASON="vm_list_empty"
    fi
else
    echo "# VM list file missing or not set (VM_LIST_FILE='$VM_LIST_FILE')" >&2
    VM_LIST_REASON="vm_list_missing"
    VMS=""  # Ensure empty so loop does nothing
fi

append_metric() {
    # $1 = raw JSON object (no surrounding commas or array brackets)
    if [ -z "${METRICS:-}" ]; then
        METRICS="$1"
    else
        METRICS="$METRICS,$1"
    fi
}

collect_one() {
    vm_name="$1"; vm_ip="$2"
    # Return if either field is empty
    if [ -z "$vm_name" ] || [ -z "$vm_ip" ]; then
        return 1
    fi
    [ "${DEBUG:-}" = "1" ] && echo "# DEBUG: Collecting $vm_name ($vm_ip)" >&2
    remote_cmd='hostname; (df -B1 --output=source,fstype,size,used,avail,pcent,target 2>/dev/null | grep -E "^/dev/" | head -1 || df -kP 2>/dev/null | awk "NR>1 && /^\\/dev\\// {printf \"%s unknown %d %d %d %s %s\\n\", $1, $2*1024, $3*1024, $4*1024, $5, $6; exit}")'
    # Use -n (already in SSH_OPTS) so ssh does not consume the while-loop's stdin (the VM list)
    vm_data=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$vm_ip" "$remote_cmd" 2>/dev/null || true)
    if [ -z "$vm_data" ]; then
        fallback='hostname; df -B1 / 2>/dev/null | awk "NR==2 {printf \"%s %s %s %s %s %s %s\\n\", $1, \"unknown\", $2, $3, $4, $5, $6}"'
        vm_data=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$vm_ip" "$fallback" 2>/dev/null || true)
    fi
    [ -z "$vm_data" ] && return 2
    host=$(echo "$vm_data" | head -1)
    line=$(echo "$vm_data" | tail -1)
    set -- $line
    dev=$1 fstype=${2:-unknown} total=$3 used=$4 avail=$5 pct=$6 mnt=${7:-/}
    case "$total$used" in (''|*[!0-9]*) return 3;; esac
    pct=${pct%\%}; [ -z "$pct" ] && pct=0
    sanitize() { echo "$1" | tr ' ,=' '_' | tr -d '"'; }
    dev=$(sanitize "$dev"); fstype=$(sanitize "$fstype"); mnt=$(sanitize "$mnt"); host=$(sanitize "$host"); vm_name=$(sanitize "$vm_name"); vm_ip=$(sanitize "$vm_ip")
    TS_MS=$(( $(date +%s) * 1000 ))
    append_metric '{"measurement":"vm_disk_usage","timestamp":'"$TS_MS"',"vm_hostname":"'$host'","vm_name":"'$vm_name'","vm_ip":"'$vm_ip'","device":"'$dev'","fstype":"'$fstype'","mountpoint":"'$mnt'","total_bytes":'$total',"used_bytes":'$used',"free_bytes":'$avail',"used_percentage":'$pct'}'
    append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"vm","vm_name":"'$vm_name'","vm_ip":"'$vm_ip'","installed":'$SSH_INSTALLED',"success":1}'
    return 0
}

main() {
    METRICS=""
    TS_MS=$(( $(date +%s) * 1000 ))
    append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"start","installed":'"$SSH_INSTALLED"',"success":0}'
    success_count=0
    # Write VM list to a temp file to avoid any shell word-splitting surprises
    tmpfile="$(mktemp 2>/dev/null || echo /tmp/vm_list.$$)"
    printf '%s\n' "$VMS" > "$tmpfile"
    [ "${DEBUG:-}" = "1" ] && {
        echo "# DEBUG: VM list written to $tmpfile" >&2
        nl -ba "$tmpfile" >&2
    }
    while IFS=: read -r vm_name vm_ip; do
        # Skip blank / comment
        [ -z "${vm_name}" ] && continue
        case "$vm_name" in '#'* ) continue;; esac
        vm_name=${vm_name%$'\r'}
        vm_ip=${vm_ip%$'\r'}
        if collect_one "$vm_name" "$vm_ip"; then
            success_count=$((success_count+1))
        else
            rc=$?
            TS_MS=$(( $(date +%s) * 1000 ))
            case "$rc" in
              1) err="invalid_params";;
              2) err="empty_output";;
              3) err="parse_error";;
              *) err="unknown_$rc";;
            esac
            append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"vm","vm_name":"'$vm_name'","vm_ip":"'$vm_ip'","error_reason":"'$err'","installed":'$SSH_INSTALLED',"success":0}'
            echo "# Warning: Failed $vm_name ($vm_ip)" >&2
        fi
    done < "$tmpfile"
    rm -f "$tmpfile"
    TS_MS=$(( $(date +%s) * 1000 ))
    append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"end","installed":'"$SSH_INSTALLED"',"success":'"$success_count"'}'
    if [ "$success_count" -eq 0 ]; then
        TS_MS=$(( $(date +%s) * 1000 ))
        if [ -n "$VM_LIST_REASON" ]; then
            append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"missing","error_reason":"'$VM_LIST_REASON'","installed":'$SSH_INSTALLED',"success":0}'
        else
            append_metric '{"measurement":"vm_collection_status","timestamp":'"$TS_MS"',"stage":"none_succeeded","installed":'$SSH_INSTALLED',"success":0}'
        fi
    fi
    # Output single valid JSON value (array of objects)
    printf '[%s]\n' "$METRICS"
}

main "$@"
