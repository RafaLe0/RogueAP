#!/usr/bin/env bash

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "[ERROR] This tool must be run as root."
        exit 1
    fi
}

prepare_env() {
    if ! mkdir -p "$LOG_DIR"; then
        die "Failed to create log directory"
    fi
    log "Environment prepared"
}

handle_interrupt() {
    log "Interrupt received (Ctrl+C)"
    cleanup
    exit 0
}

detect_inet_interface() {
    IFACE_INET=$(ip route show default \
        | sort -k5,5n \
        | head -n1 \
        | awk '{print $5}')

    [[ -n "$IFACE_INET" ]] || die "Unable to detect internet interface"

    log "Detected internet interface: $IFACE_INET"
}

cleanup() {
    log "Stopping services"

    [[ -n "${AIREPLAY_PID:-}" ]] && kill "$AIREPLAY_PID"
    [[ -n "${TCPDUMP_PID:-}" ]] && kill "$TCPDUMP_PID"
    [[ -n "${HOSTAPD_PID:-}" ]] && kill "$HOSTAPD_PID"
    [[ -n "${DNSMASQ_PID:-}" ]] && kill "$DNSMASQ_PID"

    wait 2>/dev/null
    log "PID  stopped"
    iptables -t nat -F
    iptables -F

    sysctl -w net.ipv4.ip_forward=0 >/dev/null

    log "Network config stopped."
}

