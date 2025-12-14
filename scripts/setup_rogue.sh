#!/bin/bash

interface="wlan0"

echo "[1] Starting monitor mode..."

sudo ip link set $interface down || {
    echo "[ERROR] Impossible de mettre l’interface $interface down."
    exit 1
}

sudo iw $interface set monitor control || {
    echo "[ERROR] Impossible de passer $interface en mode monitor. Carte incompatible ?"
    exit 1
}

sudo ip link set $interface up || {
    echo "[ERROR] Impossible de remonter l’interface $interface up."
    exit 1
}

echo "[2] Monitor mode enabled successfully."

