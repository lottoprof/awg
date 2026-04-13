#!/bin/bash
set -euo pipefail

IPSET_NAME="ru_nets"
RU_IPSET="/etc/amnezia/amneziawg/ru.ipset"
WAN_WAIT_RETRIES=45
WAN_WAIT_SLEEP=1

active_awg_links() {
    ip -o link show type amneziawg 2>/dev/null | wc -l
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
            printf '%s\n%s\n' "$wan_gw" "$wan_if"
            return 0
        fi

        echo "Waiting for WAN route after resume: attempt $attempt/$WAN_WAIT_RETRIES"
        sleep "$WAN_WAIT_SLEEP"
        attempt=$((attempt + 1))
    done

    return 1
}

ensure_novpn_route() {
    local wan_gw="$1"
    local wan_if="$2"

    ip route replace default via "$wan_gw" dev "$wan_if" table novpn
}

ensure_novpn_rule() {
    ip rule del fwmark 200 table novpn 2>/dev/null || true
    ip rule add fwmark 200 table novpn priority 10
}

restore_ipset() {
    if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        return 0
    fi

    if [[ ! -s "$RU_IPSET" ]]; then
        echo "Warning: $RU_IPSET is missing, skipping ipset restore."
        return 0
    fi

    ipset restore < "$RU_IPSET"
}

ensure_mangle_rules() {
    iptables -t mangle -C OUTPUT -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200 2>/dev/null || \
        iptables -t mangle -I OUTPUT -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200

    iptables -t mangle -C PREROUTING -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200 2>/dev/null || \
        iptables -t mangle -I PREROUTING -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 200

    iptables -t mangle -C PREROUTING -j CONNMARK --restore-mark 2>/dev/null || \
        iptables -t mangle -I PREROUTING -j CONNMARK --restore-mark

    iptables -t mangle -C POSTROUTING -j CONNMARK --save-mark 2>/dev/null || \
        iptables -t mangle -I POSTROUTING -j CONNMARK --save-mark
}

verify_novpn_state() {
    local wan_gw="$1"
    local wan_if="$2"
    local route_out

    ip rule show | grep -Fq "fwmark 0xc8 lookup novpn" || {
        echo "Error: fwmark 200 rule for table novpn is missing"
        return 1
    }

    ip route show table novpn | grep -Fq "default via $wan_gw dev $wan_if" || {
        echo "Error: novpn default route is missing or incorrect"
        ip route show table novpn || true
        return 1
    }

    route_out="$(ip route get 77.88.8.8 mark 0xc8 2>&1)" || {
        echo "Error: failed to resolve marked route via novpn"
        echo "$route_out"
        return 1
    }

    [[ "$route_out" == *"table novpn"* && "$route_out" == *"dev $wan_if"* ]] || {
        echo "Error: marked RU route does not use novpn/WAN"
        echo "$route_out"
        return 1
    }
}

main() {
    local wan_gw
    local wan_if
    local wan_data

    if [[ "$(active_awg_links)" -eq 0 ]]; then
        echo "No active AWG interfaces, nothing to recover."
        exit 0
    fi

    wan_data="$(wait_for_wan)" || {
        echo "Error: WAN gateway or interface not found after $WAN_WAIT_RETRIES attempts"
        exit 1
    }
    wan_gw="$(printf '%s\n' "$wan_data" | sed -n '1p')"
    wan_if="$(printf '%s\n' "$wan_data" | sed -n '2p')"

    if [[ -z "$wan_gw" || -z "$wan_if" ]]; then
        echo "Error: WAN gateway or interface not found"
        exit 1
    fi

    echo "Recovering novpn via $wan_if/$wan_gw"

    restore_ipset
    ensure_novpn_route "$wan_gw" "$wan_if"
    ensure_novpn_rule
    ensure_mangle_rules
    verify_novpn_state "$wan_gw" "$wan_if"

    echo "novpn recovery completed successfully."
}

main "$@"
