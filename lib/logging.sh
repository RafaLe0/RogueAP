#!/usr/bin/env bash

log() {
    echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOG_FILE"
}

die() {
    log "[ERROR] $1"
    exit 1
}

