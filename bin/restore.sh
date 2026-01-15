#!/bin/bash
set -e  # Exit on error

source .env 2>/dev/null || true

# NEW VOLUME DETECTION (V2) - Required for mixed environments
if [ -d "./data/db" ]; then
    COMPOSE_CMD="docker-compose"
    DOCKER_CMD="docker"
    echo "✅ Legacy volume → docker-compose/docker mode" >&2
else
    COMPOSE_CMD="docker compose"
    DOCKER_CMD="docker"
    echo "🚀 Fresh install → docker compose/docker mode" >&2
fi

# FALLBACKS: Use .env OR defaults
backup_root="${BACKUP_ROOT:-./backups}"
MARIADB_DATABASE="${MARIADB_DATABASE:-wordpress}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Warn if critical vars missing
[[ -z "$MARIADB_ROOT_PASSWORD" ]] && echo "⚠️  No MARIADB_ROOT_PASSWORD - cross-domain restore limited"

DOMAIN="$1"
TIMESTAMP="${2:-latest}"
SOURCE_DOMAIN="${3:-}"

[[ -z "$DOMAIN" ]] && {
    echo "Usage: $0 <target-domain> [latest|autosave|precopy|timestamp] [source-domain]"
    echo "Examples:"
    echo "  $0 example.local                    # Latest non-autosave"
    echo "  $0 example.local autosave           # Last safety backup"  
    echo "  $0 example.local precopy            # Last Pre-Copy-AutoSave"
    echo "  $0 example.local 2026-01-13_12-01-00 # Specific timestamp"
    echo "  $0 new.local latest example.local   # Copy from other domain"
    exit 1
}

BACKUP_DOMAIN="${SOURCE_DOMAIN:-$DOMAIN}"
BACKUP_DIR="${backup_root}/${BACKUP_DOMAIN}"

[[ ! -d "${BACKUP_DIR}" ]] && {
    echo "❌ No backups found for ${BACKUP_DOMAIN} in ${backup_root}"
    exit 1
}

resolve_timestamp() {
    case "$1" in
        "latest") ls -t "${BACKUP_DIR}" | grep -vE "(Pre-Restore-AutoSave|Pre-Copy-AutoSave)" | head -n1 ;;
        "autosave") ls -t "${BACKUP_DIR}" | grep -E "(Pre-Restore-AutoSave|Pre-Copy-AutoSave)" | head -n1 ;;
        "precopy") ls -t "${BACKUP_DIR}" | grep "Pre-Copy-AutoSave" | head -n1 ;;
        *) echo "$1" ;;
    esac
}

TIMESTAMP=$(resolve_timestamp "$TIMESTAMP")

[[ -z "$TIMESTAMP" ]] && {
    echo "❌ No valid backups found for mode: ${2:-latest}"
    exit 1
}

RESTORE_PATH="${BACKUP_DIR}/${TIMESTAMP}"
DB_FILE="${RESTORE_PATH}/${BACKUP_DOMAIN}_db.sql.gz"
SITE_FILE="${RESTORE_PATH}/${BACKUP_DOMAIN}_site.tar.gz"

[[ ! -f "${DB_FILE}" || ! -f "${SITE_FILE}" ]] && {
    echo "❌ Backup files not found: ${RESTORE_PATH}"
    exit 1
}

echo "🔄 Restoring ${DOMAIN} from ${BACKUP_DOMAIN}:${TIMESTAMP}..."

# AUTO PRE-RESTORE BACKUP (uses backup.sh)
echo "💾 Auto-saving current state..."
bash "$(dirname "$0")/backup.sh" "${DOMAIN}" "Pre-Restore-AutoSave"

# FIXED: Hardcode mariadb service + correct mysql client
DB_CONTAINER="mariadb"
TARGET_DB=$(grep "DB_NAME" "./sites/${DOMAIN}/wp-config.php" 2>/dev/null | cut -d\' -f4 || echo "${MARIADB_DATABASE}")

[[ -z "$TARGET_DB" ]] && { echo "❌ Could not determine target database"; exit 1; }

# 1. Restore database (FIXED: mysql client, matches backup.sh)
echo "📥 Restoring database to ${TARGET_DB}..."
gunzip -c "${DB_FILE}" | ${DOCKER_CMD} exec -i "${DB_CONTAINER}" mysql "${TARGET_DB}"

# 2. Preserve existing site (atomic)
echo "📂 Preserving existing site..."
rm -rf "./sites/${DOMAIN}_pre_restore" 2>/dev/null || true
mv "./sites/${DOMAIN}" "./sites/${DOMAIN}_pre_restore" 2>/dev/null || true

# 3. Restore site files
echo "📁 Restoring site files..."
tar -xzf "${SITE_FILE}" -C ./sites

# 4. Fix permissions
echo "🔧 Fixing permissions..."
chown -R 1000:1000 "./sites/${DOMAIN}"
chmod -R 755 "./sites/${DOMAIN}"

# CROSS-DOMAIN: Auto-setup vhost + DB (INLINE, no external deps)
if [[ "$BACKUP_DOMAIN" != "$DOMAIN" && -n "$MARIADB_ROOT_PASSWORD" ]]; then
    echo "🌐 Setting up new domain ${DOMAIN}..."
    
    NEW_DB="${MARIADB_DATABASE}_${DOMAIN//./_}"
    ${DOCKER_CMD} exec -i "${DB_CONTAINER}" mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "
        CREATE DATABASE IF NOT EXISTS \`${NEW_DB}\`;
        GRANT ALL PRIVILEGES ON \`${NEW_DB}\`.* TO '${MARIADB_USER:-wordpress}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD:-wordpress}';
        FLUSH PRIVILEGES;
    "

    # Update wp-config.php
    sed -i "s|DB_NAME', '.*'|DB_NAME', '${NEW_DB}'|" "./sites/${DOMAIN}/wp-config.php"
    
    # URL replacement
    ${DOCKER_CMD} exec -i "${DB_CONTAINER}" mysql "${NEW_DB}" -e "
        UPDATE wp_options SET option_value = REPLACE(option_value, '${BACKUP_DOMAIN}', '${DOMAIN}') 
        WHERE option_name = 'home' OR option_name = 'siteurl';
        UPDATE wp_posts SET guid = REPLACE(guid, '${BACKUP_DOMAIN}', '${DOMAIN}');
        UPDATE wp_posts SET post_content = REPLACE(post_content, '${BACKUP_DOMAIN}', '${DOMAIN}');
        UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, '${BACKUP_DOMAIN}', '${DOMAIN}');
    "
    
    # Domain setup
    mkdir -p "./sites/${DOMAIN}/{html,logs,certs}"
    chown -R 1000:1000 "./sites/${DOMAIN}"
    bash "$(dirname "$0")/domain.sh" -A "${DOMAIN}"
    
elif [[ "$BACKUP_DOMAIN" != "$DOMAIN" ]]; then
    echo "❌ Cross-domain restore requires MARIADB_ROOT_PASSWORD in .env"
    exit 1
fi

# POST-RESTORE OPTIMIZATION
echo "⚡ Running post-restore optimization..."
${DOCKER_CMD} exec -i "${DB_CONTAINER}" mysql "${TARGET_DB}" -e "
    OPTIMIZE TABLE wp_posts;
    OPTIMIZE TABLE wp_postmeta;
    OPTIMIZE TABLE wp_options;
"

# Clear caches
echo "🧹 Clearing caches..."
rm -rf "./sites/${DOMAIN}/wp-content/cache/"* 2>/dev/null || true

echo "✅ Restore complete: http://${DOMAIN}"
echo "   💾 Auto-backup: ${backup_root}/${DOMAIN}/[timestamp]_Pre-Restore-AutoSave/"
echo "   📁 Restored from: ${RESTORE_PATH}"
echo "   📂 Previous site: ./sites/${DOMAIN}_pre_restore/"
