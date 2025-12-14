#!/bin/bash

interface="wlan0"

echo "[1] Disabling monitor mode..."

sudo ip link set $interface down || {
    echo "[ERROR] Impossible de mettre l’interface $interface down."
    exit 1
}

sudo iw $interface set type managed || {
    echo "[ERROR] Impossible de repasser $interface en mode managed."
    exit 1
}

sudo ip link set $interface up || {
    echo "[ERROR] Impossible de remonter l’interface $interface."
    exit 1
}

echo "[2] Monitor mode disabled. Interface back to managed mode."

