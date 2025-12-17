#!/usr/bin/env bash

# Active le mode "exit on error"
set -e

# ========== FONCTION D'AIDE ==========
show_help() {
  cat << EOF
Usage: $0 <MAC>

Configure un point d'accès Wi-Fi avec des paramètres personnalisés.

Arguments:
  MAC      Adresse MAC personnalisée (format: XX:XX:XX:XX:XX:XX)

Exemples:
  $0 02:00:00:11:22:33
  $0 AA:BB:CC:DD:EE:FF

EOF
  exit 1
}


# ========== VALIDATION DES ARGUMENTS ==========
# Vérifie qu'il y a exactement 1 argument
if [[ $# -ne 1 ]]; then
  echo "Erreur: 1 argument requis"
  echo
  show_help
fi

# Récupération des arguments
NEW_MAC="$1"

# Validation du format MAC (XX:XX:XX:XX:XX:XX)
if ! [[ "$NEW_MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
  echo "Erreur: Format MAC invalide"
  echo "Format attendu: XX:XX:XX:XX:XX:XX (ex: 02:00:00:11:22:33)"
  exit 1
fi


# ========== CONFIGURATION ==========
DURATION=10
TMP_DIR=$(mktemp -d)

# Fonction de nettoyage
cleanup() {
  # Désactive le mode monitor si activé
  if [[ -n "$MON_IFACE" ]]; then
    airmon-ng stop "${MON_IFACE}" >/dev/null 2>&1 || true
  fi
  # Supprime le répertoire temporaire
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT


# ========== DÉTECTION DE L'INTERFACE WI-FI ==========
echo "Détection de l'interface Wi-Fi..."
IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

if [[ -z "$IFACE" ]]; then
  echo "Aucune interface Wi-Fi détectée"
  exit 1
fi

echo "Interface détectée : $IFACE"


# ========== ACTIVATION DU MODE MONITOR ==========
echo "Activation du mode monitor..."
MON_IFACE=$(airmon-ng start "$IFACE" 2>/dev/null | awk '/monitor mode vif enabled/ {print $NF}' | tr -d ')')

# Fallback si déjà en mode monitor
# MON_IFACE=${MON_IFACE:-"${IFACE}mon"}

echo "Mode monitor activé : $MON_IFACE"


# ========== CONFIGURATION DE L'ADRESSE MAC ==========
echo "Configuration de l'adresse MAC..."

# Récupère l'adresse MAC actuelle
OLD_MAC=$(ip link show "$MON_IFACE" | awk '/link\/ether/ {print $2}')

# Sauvegarde l'ancienne MAC dans un fichier avec versioning
BACKUP_DIR="$HOME/.rogueap_backups"
mkdir -p "$BACKUP_DIR"

# Trouve un nom de fichier disponible
BACKUP_FILE="$BACKUP_DIR/mac_backup.txt"
if [[ -f "$BACKUP_FILE" ]]; then
  VERSION=1
  while [[ -f "$BACKUP_DIR/mac_backup_v${VERSION}.txt" ]]; do
    ((VERSION++))
  done
  BACKUP_FILE="$BACKUP_DIR/mac_backup_v${VERSION}.txt"
fi

# Sauvegarde l'ancienne MAC avec timestamp
echo "$(date '+%Y-%m-%d %H:%M:%S') - Interface: $MON_IFACE - Ancienne MAC: $OLD_MAC - Nouvelle MAC: $NEW_MAC" > "$BACKUP_FILE"
echo "Ancienne MAC sauvegardée dans : $BACKUP_FILE"

# Désactive l'interface avant de changer la MAC
ip link set "$MON_IFACE" down
# Change l'adresse MAC
macchanger -m "$NEW_MAC" "$MON_IFACE" >/dev/null 2>&1 || {
  # Si macchanger n'est pas disponible, utilise ip link
  ip link set dev "$MON_IFACE" address "$NEW_MAC"
}
# Réactive l'interface
ip link set "$MON_IFACE" up

echo "Adresse MAC configurée : $NEW_MAC (ancienne: $OLD_MAC)"


# ========== RÉSULTATS ==========
echo "MAC          : $NEW_MAC (ancienne: $OLD_MAC)"
echo "Interface    : $MON_IFACE"
echo "Configuration terminée avec succès!"
