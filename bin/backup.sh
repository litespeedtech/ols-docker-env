#!/usr/bin/env bash
source .env

DOMAIN=$1
NOTE=${2:-""}

# Auto-detect cron job (no TTY + CRON_BACKUP env var)
IS_CRON=false
if [[ ! -t 0 && -n "$CRON_BACKUP" ]]; then
  NOTE="cron"
  IS_CRON=true
fi

# BACKUP_ROOT comes from .env, fallback to ./backups if not set
BACKUP_ROOT="${BACKUP_ROOT:-./backups}"

DATE_TIME=$(date +%Y-%m-%d_%H-%M-%S)
SUFFIX=${IS_CRON:+"_cron"}

if [[ -n "$NOTE" ]]; then
  FOLDER_NAME="${DATE_TIME}_${NOTE}${SUFFIX}"
else
  FOLDER_NAME="${DATE_TIME}${SUFFIX}"
fi

BACKUP_DIR="${BACKUP_ROOT}/${DOMAIN}/${FOLDER_NAME}"
mkdir -p "$BACKUP_DIR"

echo "🔄 Backing up ${DOMAIN} → ${BACKUP_DIR}"

# Get target database name from wp-config or env (same as demosite.sh pattern)
TARGET_DB=$(grep DB_NAME ./sites/${DOMAIN}/wp-config.php 2>/dev/null | cut -d\' -f4 || echo ${MARIADB_DATABASE}

if [[ -z "$TARGET_DB" ]]; then
  echo "❌ Could not determine database for ${DOMAIN}"
  exit 1
fi

# 1. Database backup (with progress)
echo "📥 Dumping database ${TARGET_DB}..."
docker exec mariadb mariadb-dump "$TARGET_DB" | gzip > "${BACKUP_DIR}/${DOMAIN}_db.sql.gz"

# 2. Site files backup (with progress)
echo "📁 Archiving site files..."
tar -czf "${BACKUP_DIR}/${DOMAIN}_site.tar.gz" -C ./sites "${DOMAIN}"

# 3. Fix permissions
chmod 644 "${BACKUP_DIR}/${DOMAIN}_db.sql.gz"
chmod 644 "${BACKUP_DIR}/${DOMAIN}_site.tar.gz"
chown -R 1000:1000 "$BACKUP_DIR"

# 4. Create restore manifest
cat > "${BACKUP_DIR}/restore-info.json" << EOF
{
  "domain": "${DOMAIN}",
  "timestamp": "${DATE_TIME}",
  "database": "${TARGET_DB}",
  "note": "${NOTE}",
  "backup_path": "${BACKUP_DIR}",
  "files": [
    "${DOMAIN}_db.sql.gz",
    "${DOMAIN}_site.tar.gz"
  ],
  "restore_command": "./bin/restore.sh ${DOMAIN} ${FOLDER_NAME##*/}"
}
EOF

# 5. Backup stats
echo "📊 Backup stats:"
du -sh "$BACKUP_DIR"/*
echo "Total: $(du -sh "$BACKUP_DIR" | cut -f1)"

# 6. SMART PRUNING - Manual=unlimited, Cron=30 rolling
echo "🧹 Pruning backups..."
if [[ "$IS_CRON" == true ]]; then
  echo "   📅 Cron mode: Keeping last 30 backups"
  # Cron: Keep newest 30 cron backups only (excludes safety)
  find "${BACKUP_ROOT}/${DOMAIN}" -maxdepth 1 -type d \
    \( -name "*_cron*" ! -name "*Pre-Restore-AutoSave*" ! -name "*Pre-Copy-AutoSave*" \) | \
    sort -r | tail -n +31 | xargs rm -rf 2>/dev/null || true
else
  echo "   🙌 Manual mode: No pruning (unlimited)"
fi

# ALWAYS protect ALL safety backups (both modes)
find "${BACKUP_ROOT}/${DOMAIN}" -maxdepth 1 -type d \
  \( -name "*Pre-Restore-AutoSave*" -o -name "*Pre-Copy-AutoSave*" \) | \
  sort -r | tail -n +999 | xargs rm -rf 2>/dev/null || true

echo "✅ Backup complete: ${BACKUP_DIR}"
echo "   📋 Restore with: ./bin/restore.sh ${DOMAIN} ${FOLDER_NAME##*/}"

