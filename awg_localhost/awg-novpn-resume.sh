#!/bin/bash
set -euo pipefail

STATE_FILE="/run/awg-resume-active.list"
PENDING_FILE="/run/awg-resume-pending"

active_awg_units() {
    systemctl list-units 'awg-quick@*.service' --state=active --no-legend --plain \
        | awk '{print $1}'
}

save_active_units() {
    local units

    units="$(active_awg_units)"
    if [[ -z "$units" ]]; then
        rm -f "$STATE_FILE"
        rm -f "$PENDING_FILE"
        return 0
    fi

    printf '%s\n' "$units" > "$STATE_FILE"
    rm -f "$PENDING_FILE"
}

stop_saved_units() {
    local unit
    local iface

    [[ -f "$STATE_FILE" ]] || return 0

    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        systemctl stop "$unit"
        iface="${unit#awg-quick@}"
        iface="${iface%.service}"
        cleanup_broken_unit "$unit" "$iface"
    done < "$STATE_FILE"
}

cleanup_awg_rules() {
    local rule
    local mark

    while IFS= read -r rule; do
        [[ -n "$rule" ]] || continue
        mark="$(printf '%s\n' "$rule" | awk '{for (i = 1; i <= NF; i++) if ($i == "fwmark") { print $(i + 1); exit }}')"
        [[ -n "$mark" ]] || continue
        ip rule del not fwmark "$mark" table 51820 2>/dev/null || true
    done < <(ip rule show | grep -F "lookup 51820" | grep -F "fwmark" || true)

    ip route flush table 51820 2>/dev/null || true
}

cleanup_broken_unit() {
    local unit="$1"
    local iface="$2"

    systemctl reset-failed "$unit" 2>/dev/null || true
    cleanup_awg_rules

    if ip link show "$iface" >/dev/null 2>&1; then
        ip link delete dev "$iface" 2>/dev/null || true
    fi
}

case "${1:-}" in
    pre)
        save_active_units
        stop_saved_units
        ;;
    post)
        [[ -f "$STATE_FILE" ]] && : > "$PENDING_FILE"
        ;;
esac
