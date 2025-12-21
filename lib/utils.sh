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

cleanup() {
    log "Cleaning environment"
    log "Stopping services"

    [[ -n "${HOSTAPD_PID:-}" ]] && kill "$HOSTAPD_PID" 2>/dev/null
    [[ -n "${DNSMASQ_PID:-}" ]] && kill "$DNSMASQ_PID" 2>/dev/null

    log "Services stopped"
}
