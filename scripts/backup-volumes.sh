#!/bin/bash
#
# Backup all Docker named volumes to a directory
#
# Usage:
#   ./scripts/backup-volumes.sh [OPTIONS] [BACKUP_DIR]
#
# Options:
#   --tar    Create a .tar.gz archive (easier to transfer off-NAS)
#
# Examples:
#   ./scripts/backup-volumes.sh                           # Backup to /volume1/backups/arr-stack-YYYYMMDD
#   ./scripts/backup-volumes.sh /path/to/backup           # Backup to custom directory
#   ./scripts/backup-volumes.sh --tar                     # Create tarball in current directory
#   ./scripts/backup-volumes.sh --tar /path/to/backup     # Create tarball in custom directory
#
# To pull backup to local machine:
#   scp user@nas:/path/to/arr-stack-backup-YYYYMMDD.tar.gz ./backups/
#

set -e

# Parse arguments
CREATE_TAR=false
BACKUP_DIR=""

for arg in "$@"; do
  case $arg in
    --tar)
      CREATE_TAR=true
      ;;
    *)
      BACKUP_DIR="$arg"
      ;;
  esac
done

# Default backup directory
BACKUP_DIR="${BACKUP_DIR:-/volume1/backups/arr-stack-$(date +%Y%m%d)}"
mkdir -p "$BACKUP_DIR"

# Volumes to backup (essential configs only)
# Excludes: jellyfin-cache (regenerates), duc-index (regenerates)
VOLUMES=(
  # arr-stack.yml
  arr-stack_gluetun-config
  arr-stack_qbittorrent-config
  arr-stack_sonarr-config
  arr-stack_prowlarr-config
  arr-stack_radarr-config
  arr-stack_jellyfin-config
  arr-stack_jellyseerr-config
  arr-stack_bazarr-config
  arr-stack_pihole-etc-pihole
  arr-stack_pihole-etc-dnsmasq
  arr-stack_wireguard-easy-config
  # utilities.yml
  arr-stack_uptime-kuma-data
)

# Optional volumes (uncomment if you want to include them)
# VOLUMES+=(arr-stack_jellyfin-cache)  # ~43MB, regenerates automatically
# VOLUMES+=(arr-stack_duc-index)        # ~20MB, regenerates on restart

echo "Backing up to: $BACKUP_DIR"
echo ""

for vol in "${VOLUMES[@]}"; do
  if docker volume inspect "$vol" &>/dev/null; then
    echo "Backing up $vol..."
    docker run --rm \
      -v "$vol":/source:ro \
      -v "$BACKUP_DIR":/backup \
      alpine cp -a /source/. "/backup/${vol#arr-stack_}/"
  else
    echo "Skipping $vol (not found)"
  fi
done

echo ""
echo "Backup complete: $BACKUP_DIR"

# Create tarball if requested
if [ "$CREATE_TAR" = true ]; then
  TARBALL="${BACKUP_DIR}.tar.gz"
  echo ""
  echo "Creating tarball: $TARBALL"
  tar -czf "$TARBALL" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
  echo "Tarball created: $(ls -lh "$TARBALL" | awk '{print $5}')"
  echo ""
  echo "To pull to local machine:"
  echo "  scp user@nas:$TARBALL ./backups/"
fi

echo ""
echo "To restore a volume:"
echo "  docker run --rm -v /path/to/backup/VOLUME_NAME:/source:ro -v arr-stack_VOLUME_NAME:/dest alpine cp -a /source/. /dest/"
