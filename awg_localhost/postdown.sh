#!/bin/bash
set -euo pipefail

IPSET_NAME="ru_nets"

active_awg_links() {
    ip -o link show type amneziawg 2>/dev/null | wc -l
}

remove_mangle_rules() {
    iptables -t mangle -D OUTPUT -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200 2>/dev/null || true
    iptables -t mangle -D PREROUTING -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200 2>/dev/null || true
    iptables -t mangle -D PREROUTING -j CONNMARK --restore-mark 2>/dev/null || true
    iptables -t mangle -D POSTROUTING -j CONNMARK --save-mark 2>/dev/null || true
}

main() {
    if [[ "$(active_awg_links)" -gt 0 ]]; then
        echo "Another AWG interface is still active, keeping shared novpn/ru_nets state."
        exit 0
    fi

    ip rule del fwmark 200 table novpn 2>/dev/null || true
    ip route flush table novpn 2>/dev/null || true
    ipset destroy "$IPSET_NAME" 2>/dev/null || true
    remove_mangle_rules
}

main "$@"
