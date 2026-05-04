#!/bin/bash
set -euo pipefail

WAN_WAIT_RETRIES=45
WAN_WAIT_SLEEP=1
STATE_FILE="/run/awg-resume-active.list"
PENDING_FILE="/run/awg-resume-pending"

log() {
    logger -t awg-resume-restart "$*"
    echo "$*"
}

saved_awg_units() {
    [[ -f "$STATE_FILE" ]] || return 0
    sed '/^$/d' "$STATE_FILE"
}

get_wan_gateway() {
    ip route show default 0.0.0.0/0 | grep -m1 via | awk '{print $3}'
}

get_wan_interface() {
    ip route show default 0.0.0.0/0 | grep -m1 via | awk '{print $5}'
}

wait_for_wan() {
    local attempt=1
    local wan_gw
    local wan_if

    while [[ "$attempt" -le "$WAN_WAIT_RETRIES" ]]; do
        wan_gw="$(get_wan_gateway || true)"
        wan_if="$(get_wan_interface || true)"

        if [[ -n "$wan_gw" && -n "$wan_if" ]]; then
            log "WAN ready on attempt $attempt/$WAN_WAIT_RETRIES: $wan_if via $wan_gw"
            return 0
        fi

        log "Waiting for WAN route after resume: attempt $attempt/$WAN_WAIT_RETRIES"
        sleep "$WAN_WAIT_SLEEP"
        attempt=$((attempt + 1))
    done

    return 1
}

main() {
    local units
    local unit

    log "resume service started"

    if [[ ! -f "$PENDING_FILE" ]]; then
        log "No pending resume restore marker, nothing to restart"
        exit 0
    fi

    wait_for_wan || {
        log "WAN route not ready after $WAN_WAIT_RETRIES attempts"
        exit 1
    }

    units="$(saved_awg_units || true)"

    if [[ -z "$units" ]]; then
        log "No saved AWG units from suspend, nothing to restart"
        exit 0
    fi

    log "Restarting saved AWG units after WAN recovery: $(printf '%s' "$units" | tr '\n' ' ')"

    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        systemctl reset-failed "$unit" || true
        systemctl start "$unit"
        log "Started $unit"
    done < <(printf '%s\n' "$units")

    rm -f "$STATE_FILE"
    rm -f "$PENDING_FILE"
    log "Restored saved AWG units successfully"
}

main "$@"
