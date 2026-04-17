#!/bin/bash
set -euo pipefail

WAN_WAIT_RETRIES=45
WAN_WAIT_SLEEP=1

log() {
    logger -t awg-resume-restart "$*"
    echo "$*"
}

active_awg_interfaces() {
    ip -o link show type amneziawg 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}'
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
    local interfaces

    log "resume service started"

    wait_for_wan || {
        log "WAN route not ready after $WAN_WAIT_RETRIES attempts"
        exit 1
    }

    interfaces="$(active_awg_interfaces || true)"

    if [[ -z "$interfaces" ]]; then
        log "No active AWG interfaces found in kernel, nothing to recover"
        exit 0
    fi

    log "Active AWG interfaces in kernel: $(printf '%s' "$interfaces" | tr '\n' ' ')"
    log "Recovering novpn/policy routing without awg restart"
    /etc/amnezia/amneziawg/novpn-recover.sh
    log "Recovered novpn/policy routing successfully"
}

main "$@"
