#!/usr/bin/env bash
# Script pour restaurer l'ancienne configuration Wi-Fi (inverse de setup_ap.sh)

# Active le mode "exit on error"
set -e

# ========== FONCTION D'AIDE ==========
show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Restaure l'ancienne adresse MAC et désactive le mode monitor.

Options:
  -l, --list       Liste tous les backups disponibles
  -f, --file FILE  Restaure depuis un fichier de backup spécifique
  -h, --help       Affiche cette aide

Par défaut, restaure depuis le backup le plus récent.

Exemples:
  $0                                   # Restaure le backup le plus récent
  $0 --list                            # Liste tous les backups
  $0 --file mac_backup_v2.txt          # Restaure un backup spécifique

EOF
  exit 1
}


# ========== VARIABLES ==========
BACKUP_DIR="$HOME/.rogueap_backups"
BACKUP_FILE=""
LIST_MODE=false


# ========== PARSE DES ARGUMENTS ==========
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--list)
      LIST_MODE=true
      shift
      ;;
    -f|--file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Option inconnue: $1"
      show_help
      ;;
  esac
done


# ========== MODE LISTE ==========
if [[ "$LIST_MODE" == true ]]; then
  if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
    echo "Aucun backup trouvé"
    exit 1
  fi

  echo "Backups disponibles dans $BACKUP_DIR :"

  for file in "$BACKUP_DIR"/mac_backup*.txt; do
    if [[ -f "$file" ]]; then
	  echo "------------------------------"
      echo "$(basename "$file")"
      echo "$(cat "$file")"
    fi
  done
  echo "------------------------------"
  exit 0
fi


# ========== VÉRIFICATION DU DOSSIER DE BACKUP ==========
if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Aucun dossier de backup trouvé ($BACKUP_DIR)"
  echo "Aucune configuration précédente à restaurer"
  exit 1
fi


# ========== SÉLECTION DU FICHIER DE BACKUP ==========
if [[ -z "$BACKUP_FILE" ]]; then
  # Trouve le fichier le plus récent
  BACKUP_FILE=$(ls -t "$BACKUP_DIR"/mac_backup*.txt 2>/dev/null | head -n 1)
  
  if [[ -z "$BACKUP_FILE" ]]; then
    echo "Aucun fichier de backup trouvé"
    exit 1
  fi
  
  echo "Utilisation du backup le plus récent : $(basename "$BACKUP_FILE")"
else
  # Utilise le fichier spécifié
  if [[ ! "$BACKUP_FILE" =~ ^/ ]]; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
  fi
  
  if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Fichier de backup introuvable : $BACKUP_FILE"
    exit 1
  fi
  
  echo "Utilisation du backup : $(basename "$BACKUP_FILE")"
fi


# ========== EXTRACTION DES DONNÉES DU BACKUP ==========
BACKUP_CONTENT=$(cat "$BACKUP_FILE")
echo "Contenu du backup : $BACKUP_CONTENT"
echo

# Extrait l'interface et l'ancienne MAC du backup
RESTORED_IFACE=$(echo "$BACKUP_CONTENT" | grep -oP 'Interface: \K\S+')
OLD_MAC=$(echo "$BACKUP_CONTENT" | grep -oP 'Ancienne MAC: \K[0-9a-fA-F:]+')

if [[ -z "$RESTORED_IFACE" ]] || [[ -z "$OLD_MAC" ]]; then
  echo "Impossible d'extraire les informations du backup"
  exit 1
fi

echo "Interface à restaurer : $RESTORED_IFACE"
echo "MAC à restaurer       : $OLD_MAC"
echo

# ========== VÉRIFICATION DE L'INTERFACE ==========
if ! ip link show "$RESTORED_IFACE" &>/dev/null; then
  echo "L'interface $RESTORED_IFACE n'existe pas actuellement"
  echo "Sortie de la restauration."
  exit 1
fi

# ========== RESTAURATION DE L'ADRESSE MAC ==========
echo "Restauration de l'adresse MAC..."

# Désactive l'interface
ip link set "$RESTORED_IFACE" down

# Restaure l'ancienne MAC
macchanger -m "$OLD_MAC" "$RESTORED_IFACE" >/dev/null 2>&1 || {
  # Si macchanger n'est pas disponible, utilise ip link
  ip link set dev "$RESTORED_IFACE" address "$OLD_MAC"
}

# Réactive l'interface
ip link set "$RESTORED_IFACE" up

echo "Adresse MAC restaurée : $OLD_MAC"

# ========== DÉSACTIVATION DU MODE MONITOR ==========
if [[ "$RESTORED_IFACE" =~ mon$ ]]; then
  echo "Désactivation du mode monitor..."
  
  # Arrête le mode monitor
  airmon-ng stop "$RESTORED_IFACE" >/dev/null 2>&1 || {
    echo "Impossible de désactiver le mode monitor avec airmon-ng"
    echo "Sortie de la restauration."
    exit 1
	}
  
  echo "Mode monitor désactivé"
else
  echo "L'interface n'est pas en mode monitor, aucune désactivation nécessaire"
fi

# ========== ARCHIVAGE DU BACKUP UTILISÉ ==========
ARCHIVE_DIR="$BACKUP_DIR/used"
mkdir -p "$ARCHIVE_DIR"
mv "$BACKUP_FILE" "$ARCHIVE_DIR/" 2>/dev/null || true
echo "Backup archivé dans $ARCHIVE_DIR/"

# ========== RÉSULTATS ==========
echo
echo "═══════════════════════════════════════"
echo "Restauration terminée avec succès!"
echo "═══════════════════════════════════════"
echo "MAC restaurée    : $OLD_MAC"
echo "Interface        : $RESTORED_IFACE"
echo "═══════════════════════════════════════"
