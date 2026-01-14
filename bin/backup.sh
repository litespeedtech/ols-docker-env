#!/usr/bin/env bash
source .env 2>/dev/null || true

# NEW VOLUME DETECTION (V2) - Same as previous scripts
if [ -d "./data/db" ]; then
    COMPOSE_CMD="docker-compose"
    DOCKER_CMD="docker"
    echo "✅ Legacy volume → docker-compose/docker mode" >&2
else
    COMPOSE_CMD="docker compose"
    DOCKER_CMD="docker"
    echo "🚀 Fresh install → docker compose/docker mode" >&2
fi

DOMAIN=$1
NOTE=${2:-""}

# Auto-detect cron job (no TTY + CRON_BACKUP env var)
IS_CRON=false
if [[ ! -t 0 && -n "$CRON_BACKUP" ]]; then
    NOTE="cron"
    IS_CRON=true
fi

# BACKUP_ROOT from .env, fallback to ./backups
BACKUP_ROOT="${BACKUP_ROOT:-./backups}"
DATE_TIME=$(date +%Y-%m-%d_%H-%M-%S)
SUFFIX=${IS_CRON:+"_cron"}

FOLDER_NAME="${DATE_TIME}_${NOTE}${SUFFIX}"
BACKUP_DIR="${BACKUP_ROOT}/${DOMAIN}/${FOLDER_NAME}"
mkdir -p "$BACKUP_DIR" || { echo "❌ Failed to create $BACKUP_DIR"; exit 1; }

echo "🔄 Backing up ${DOMAIN} → ${BACKUP_DIR}"

# Get target database name from wp-config.php or env (FIXED syntax)
TARGET_DB=$(grep "DB_NAME" "./sites/${DOMAIN}/wp-config.php" 2>/dev/null | cut -d\' -f4 || echo "${MARIADB_DATABASE}")

if [[ -z "$TARGET_DB" ]]; then
    echo "❌ Could not determine database for ${DOMAIN}"
    exit 1
fi

# 1. Database backup (with progress via pv if available, mariadb-dump → mysqldump)
echo "📥 Dumping database ${TARGET_DB}..."
if command -v pv >/dev/null 2>&1; then
    ${DOCKER_CMD} exec mariadb mysqldump --single-transaction --quick --lock-tables=false "$TARGET_DB" | pv | gzip > "${BACKUP_DIR}/${DOMAIN}_db.sql.gz"
else
    ${DOCKER_CMD} exec mariadb mysqldump --single-transaction --quick --lock-tables=false "$TARGET_DB" | gzip > "${BACKUP_DIR}/${DOMAIN}_db.sql.gz"
fi

# 2. Site files backup (with progress)
echo "📁 Archiving site files..."
if command -v pv >/dev/null 2>&1; then
    tar -czf - -C ./sites "${DOMAIN}" | pv > "${BACKUP_DIR}/${DOMAIN}_site.tar.gz"
else
    tar -czf "${BACKUP_DIR}/${DOMAIN}_site.tar.gz" -C ./sites "${DOMAIN}"
fi

# 3. Fix permissions (more robust)
chmod 644 "${BACKUP_DIR}/${DOMAIN}_db.sql.gz" "${BACKUP_DIR}/${DOMAIN}_site.tar.gz"
chown -R 1000:1000 "$BACKUP_DIR" 2>/dev/null || true

# 4. Create restore manifest (enhanced)
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
  "restore_command": "${COMPOSE_CMD} run --rm mariadb mariadb-dump ${DOMAIN} ${FOLDER_NAME##*/}",
  "docker_cmd": "${DOCKER_CMD}"
}
EOF

# 5. Backup stats
echo "📊 Backup stats:"
du -sh "$BACKUP_DIR"/*
echo "Total: $(du -sh "$BACKUP_DIR" | cut -f1)"

# 6. SMART PRUNING (enhanced safety)
echo "🧹 Pruning backups..."
if [[ "$IS_CRON" == true ]]; then
    echo "   📅 Cron mode: Keeping last 30 backups"
    find "${BACKUP_ROOT}/${DOMAIN}" -maxdepth 1 -type d \
        \( -name "*_cron*" ! -name "*Pre-Restore-AutoSave*" ! -name "*Pre-Copy-AutoSave*" \) | \
        sort -r | tail -n +31 | xargs -r rm -rf
else
    echo "   🙌 Manual mode: No pruning (unlimited)"
fi

# ALWAYS protect safety backups (keep last 5 only)
find "${BACKUP_ROOT}/${DOMAIN}" -maxdepth 1 -type d \
    \( -name "*Pre-Restore-AutoSave*" -o -name "*Pre-Copy-AutoSave*" \) | \
    sort -r | tail -n +6 | xargs -r rm -rf

echo "✅ Backup complete: ${BACKUP_DIR}"
echo "   📋 Restore with: ./bin/restore.sh ${DOMAIN} ${FOLDER_NAME##*/}"
