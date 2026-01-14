#!/bin/bash
set -e  # Exit on error

# Source .env FIRST (with fallbacks)
if [ -f .env ]; then
  source .env
fi

# ✅ FALLBACKS: Use .env OR defaults (ALL CAPS .env vars)
backup_root="${BACKUP_ROOT:-./backups}"
MARIADB_DATABASE="${MARIADB_DATABASE:-wordpress}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Warn if critical vars missing (don't crash)
if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
  echo "⚠️  No MARIADB_ROOT_PASSWORD - cross-domain restore limited"
fi

DOMAIN=$1
TIMESTAMP=${2:-latest}
SOURCE_DOMAIN=${3:-}  # Optional cross-domain source

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <target-domain> [latest|autosave|precopy|timestamp] [source-domain]"
  echo "Examples:"
  echo "  $0 example.local                    # Latest non-autosave"
  echo "  $0 example.local autosave           # Last safety backup"  
  echo "  $0 example.local precopy            # Last Pre-Copy-AutoSave"
  echo "  $0 example.local 2026-01-13_12-01-00 # Specific timestamp"
  echo "  $0 new.local latest example.local   # Copy from other domain"
  exit 1
fi

# Use source domain for backups if provided
BACKUP_DOMAIN=${SOURCE_DOMAIN:-$DOMAIN}
BACKUP_DIR="${backup_root}/${BACKUP_DOMAIN}"

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "❌ No backups found for ${BACKUP_DOMAIN} in ${BACKUP_ROOT:-./backups}"
  exit 1
fi

# 🔥 SMART TIMESTAMP RESOLUTION (w/ precopy)
resolve_timestamp() {
  case "$TIMESTAMP" in
    "latest")
      ls -t "${BACKUP_DIR}" | grep -vE "(Pre-Restore-AutoSave|Pre-Copy-AutoSave)" | head -n1
      ;;
    "autosave")
      ls -t "${BACKUP_DIR}" | grep -E "(Pre-Restore-AutoSave|Pre-Copy-AutoSave)" | head -n1
      ;;
    "precopy")
      ls -t "${BACKUP_DIR}" | grep "Pre-Copy-AutoSave" | head -n1
      ;;
    *)
      echo "$TIMESTAMP"
      ;;
  esac
}

TIMESTAMP=$(resolve_timestamp)

if [[ -z "$TIMESTAMP" ]]; then
  echo "❌ No valid backups found for mode: ${2:-latest}"
  exit 1
fi

RESTORE_PATH="${BACKUP_DIR}/${TIMESTAMP}"
DB_FILE="${RESTORE_PATH}/${BACKUP_DOMAIN}_db.sql.gz"
SITE_FILE="${RESTORE_PATH}/${BACKUP_DOMAIN}_site.tar.gz"

if [[ ! -f "${DB_FILE}" || ! -f "${SITE_FILE}" ]]; then
  echo "❌ Backup files not found: ${RESTORE_PATH}"
  exit 1
fi

echo "🔄 Restoring ${DOMAIN} from ${BACKUP_DOMAIN}:${TIMESTAMP}..."

# 🔥 AUTO PRE-RESTORE BACKUP (safety first)
echo "💾 Auto-saving current state..."
bash "$(dirname "$0")/backup.sh" "${DOMAIN}" "Pre-Restore-AutoSave"

# 1. Get target database name + DB container
TARGET_DB=$(grep DB_NAME ./sites/${DOMAIN}/wp-config.php 2>/dev/null | cut -d\' -f4 || echo "${MARIADB_DATABASE}")
DB_CONTAINER=$(docker ps --filter "name=mariadb" --format "{{.Names}}" | head -n1)

if [[ -z "$TARGET_DB" ]]; then
  echo "❌ Could not determine target database"
  exit 1
fi

if [[ -z "$DB_CONTAINER" ]]; then
  echo "❌ MariaDB container not running"
  exit 1
fi

# 2. Restore database ✅ mariadb + --force
echo "📥 Restoring database to ${TARGET_DB}..."
gunzip -c "${DB_FILE}" | docker exec -i "${DB_CONTAINER}" mariadb "${TARGET_DB}" --force

# 3. Safety backup of existing site
echo "📂 Preserving existing site..."
rm -rf ./sites/${DOMAIN}_pre_restore 2>/dev/null || true
mv ./sites/${DOMAIN} ./sites/${DOMAIN}_pre_restore 2>/dev/null || true

# 4. Restore site files
echo "📁 Restoring site files..."
tar -xzf "${SITE_FILE}" -C ./sites

# 5. Fix permissions
echo "🔧 Fixing permissions..."
chown -R 1000:1000 ./sites/${DOMAIN}
chmod -R 755 ./sites/${DOMAIN}

# 🔥 CROSS-DOMAIN: Auto-setup vhost + DB (NEW DOMAINS ONLY)
if [[ "$BACKUP_DOMAIN" != "$DOMAIN" ]]; then
  echo "🌐 Setting up vhost + database for new domain ${DOMAIN}..."
  
  NEW_DB="${MARIADB_DATABASE}_${DOMAIN//./_}"
  if [[ -n "$MARIADB_ROOT_PASSWORD" ]]; then
    docker exec -i "${DB_CONTAINER}" mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${NEW_DB}\`;"
    
    sed -i "s/DB_NAME.*=.*/DB_NAME = '${NEW_DB}';/" ./sites/${DOMAIN}/wp-config.php
    
    docker exec -i "${DB_CONTAINER}" mariadb "${NEW_DB}" -e "
      UPDATE wp_options SET option_value = REPLACE(option_value, '${BACKUP_DOMAIN}', '${DOMAIN}') WHERE option_name = 'home' OR option_name = 'siteurl';
      UPDATE wp_posts SET guid = REPLACE(guid, '${BACKUP_DOMAIN}','${DOMAIN}');
      UPDATE wp_posts SET post_content = REPLACE(post_content, '${BACKUP_DOMAIN}', '${DOMAIN}');
      UPDATE wp_postmeta SET meta_value = REPLACE(meta_value,'${BACKUP_DOMAIN}','${DOMAIN}');
    "
    
    MARIADB_DATABASE=${NEW_DB} bash "$(dirname "$0")/database.sh" "${DOMAIN}"
    bash "$(dirname "$0")/domain.sh" --add "${DOMAIN}"
    echo "✅ Vhost + DB created for ${DOMAIN}"
  else
    echo "❌ Cross-domain restore requires MARIADB_ROOT_PASSWORD in .env"
    exit 1
  fi
fi

# 🔥 POST-RESTORE OPTIMIZATION
echo "⚡ Running post-restore optimization..."
docker exec -i "${DB_CONTAINER}" mariadb "${TARGET_DB}" -e "
  OPTIMIZE TABLE wp_posts;
  OPTIMIZE TABLE wp_postmeta;
  OPTIMIZE TABLE wp_options;
"

# Clear caches
echo "🧹 Clearing caches..."
rm -rf ./sites/${DOMAIN}/wp-content/cache/* 2>/dev/null || true

echo "✅ Restore complete: http://${DOMAIN}"
echo "   💾 Auto-backup: ${BACKUP_ROOT:-./backups}/${DOMAIN}/[timestamp]_Pre-Restore-AutoSave/"
echo "   📁 Restored from: ${RESTORE_PATH}"
echo "   📂 Previous site: ./sites/${DOMAIN}_pre_restore/"
