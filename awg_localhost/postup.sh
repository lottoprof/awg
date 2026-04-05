#!/bin/bash
set -euo pipefail

IPSET_NAME="ru_nets"
RU_URL="https://www.ipdeny.com/ipblocks/data/countries/ru.zone"
RU_SRC="/etc/amnezia/amneziawg/ru.zone"
RU_AGGR="/etc/amnezia/amneziawg/ru_aggr.zone"
RU_IPSET="/etc/amnezia/amneziawg/ru.ipset"
TMP_ZONE="/tmp/ru.zone.download"

get_wan_gateway() {
    ip route show default 0.0.0.0/0 | grep -m1 via | awk '{print $3}'
}

get_wan_interface() {
    ip route show default 0.0.0.0/0 | grep -m1 via | awk '{print $5}'
}

ensure_nat_rule() {
    local wan_if="$1"

    iptables -t nat -C POSTROUTING -o "$wan_if" -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -o "$wan_if" -j MASQUERADE
}

update_ru_zone() {
    echo "Downloading ru.zone from ipdeny..."

    if wget -q --timeout=5 --tries=1 "$RU_URL" -O "$TMP_ZONE"; then
        if [[ -s "$TMP_ZONE" ]]; then
            mv "$TMP_ZONE" "$RU_SRC"
            echo "Download succeeded, ru.zone updated."
        else
            echo "Warning: downloaded file is empty, using existing ru.zone."
        fi
    else
        echo "Warning: failed to download ru.zone, using existing file."
    fi
}

aggregate_ru_zone() {
    if [[ ! -f "$RU_AGGR" || "$RU_SRC" -nt "$RU_AGGR" ]]; then
        echo "Aggregating CIDR blocks..."
        command -v aggregate >/dev/null || {
            echo "Missing 'aggregate' utility"
            exit 1
        }

        if [[ -s "$RU_SRC" ]]; then
            aggregate < "$RU_SRC" > "$RU_AGGR"
        else
            echo "Warning: ru.zone is empty or missing, skipping aggregation"
            cp "$RU_SRC" "$RU_AGGR"
        fi
    else
        echo "Aggregation not needed, $RU_AGGR is up-to-date"
    fi
}

rebuild_ipset() {
    echo "Generating $RU_IPSET..."
    {
        echo "create $IPSET_NAME hash:net family inet hashsize 1024 maxelem 20000"
        awk '{ print "add '"$IPSET_NAME"' " $1 }' "$RU_AGGR"
    } > "$RU_IPSET"

    ipset create "$IPSET_NAME" hash:net family inet hashsize 1024 maxelem 20000 2>/dev/null || true
    ipset flush "$IPSET_NAME"
    grep '^add ' "$RU_IPSET" | ipset restore
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

main() {
    local wan_gw
    local wan_if

    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    wan_gw="$(get_wan_gateway)"
    wan_if="$(get_wan_interface)"

    if [[ -z "$wan_gw" || -z "$wan_if" ]]; then
        echo "Error: WAN gateway or interface not found"
        exit 1
    fi

    echo "Using WAN interface: $wan_if, gateway: $wan_gw"

    ensure_nat_rule "$wan_if"
    update_ru_zone
    aggregate_ru_zone
    rebuild_ipset
    ensure_novpn_route "$wan_gw" "$wan_if"
    ensure_novpn_rule
    ensure_mangle_rules

    echo "PostUp completed successfully."
}

main "$@"
