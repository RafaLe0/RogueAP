#!/usr/bin/env bash

detect_hw_spec() {
    log "Detecting Wi-Fi PHY capabilities"

    WIFI_STD="802.11b/g"

    if tshark -r "$PCAP_FILE" \
        -Y "wlan.fc.type_subtype == 0x08 && wlan.bssid == $TARGET_BSSID && wlan.he.capabilities" \
        -c 1 >/dev/null 2>&1; then
        WIFI_STD="802.11ax"
        log "Detected: $WIFI_STD"
        return
    fi

    if tshark -r "$PCAP_FILE" \
        -Y "wlan.fc.type_subtype == 0x08 && wlan.bssid == $TARGET_BSSID && wlan.vht.capabilities" \
        -c 1 >/dev/null 2>&1; then
        WIFI_STD="802.11ac"
        log "Detected: $WIFI_STD"
        return
    fi

    if tshark -r "$PCAP_FILE" \
        -Y "wlan.fc.type_subtype == 0x08 && wlan.bssid == $TARGET_BSSID && wlan.ht.capabilities" \
        -c 1 >/dev/null 2>&1; then
        WIFI_STD="802.11n"
        log "Detected: $WIFI_STD"
        return
    fi

    log "Detected: $WIFI_STD"
}

