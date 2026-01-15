#!/usr/bin/env bash
source .env 2>/dev/null || true

# VOLUME DETECTION (matches backup.sh)
if [ -d "./data/db" ]; then
    COMPOSE_CMD="docker-compose"
    DOCKER_CMD="docker"
    echo "✅ Legacy volume → docker-compose/docker mode" >&2
else
    COMPOSE_CMD="docker compose"
    DOCKER_CMD="docker"
    echo "🚀 Fresh install → docker compose/docker mode" >&2
fi

SOURCE_DOMAIN=$1
NEW_DOMAIN=$2

if [[ -z "$SOURCE_DOMAIN" || -z "$NEW_DOMAIN" ]]; then
  echo "Usage: $0 <source-domain> <new-domain>"
  echo "Example: $0 example.local copy1.local"
  exit 1
fi

# Validate source exists
if [[ ! -d "./sites/${SOURCE_DOMAIN}" ]]; then
  echo "❌ Source domain ${SOURCE_DOMAIN} not found"
  exit 1
fi

echo "🔄 Copying ${SOURCE_DOMAIN} → ${NEW_DOMAIN}..."

# 🔥 SAFETY: Pre-copy backup of source (protected by backup.sh pruning)
echo "💾 Creating safety backup of ${SOURCE_DOMAIN}..."
bash "$(dirname "$0")/backup.sh" "${SOURCE_DOMAIN}" "Pre-Copy-AutoSave"

# 1. Create new database (quoted, safe)
NEW_DB="${MARIADB_DATABASE}_${NEW_DOMAIN//./_}"
echo "📥 Creating database ${NEW_DB}..."
${DOCKER_CMD} exec -i mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${NEW_DB}\`"

# 2. Copy database (mysqldump → mysql pipe, quoted)
SOURCE_DB=$(grep "DB_NAME" "./sites/${SOURCE_DOMAIN}/wp-config.php" 2>/dev/null | cut -d\' -f4 || echo "${MARIADB_DATABASE}")
echo "📋 Copying database ${SOURCE_DB} → ${NEW_DB}..."
${DOCKER_CMD} exec mariadb mysqldump --single-transaction --quick "${SOURCE_DB}" | \
${DOCKER_CMD} exec -i mariadb mysql "${NEW_DB}"

# 3. Copy files (atomic move if target exists)
if [[ -d "./sites/${NEW_DOMAIN}" ]]; then
  echo "📂 Target exists, preserving as _pre_copy..."
  rm -rf ./sites/${NEW_DOMAIN}_pre_copy 2>/dev/null || true
  mv ./sites/${NEW_DOMAIN} ./sites/${NEW_DOMAIN}_pre_copy
fi

cp -r ./sites/${SOURCE_DOMAIN} ./sites/${NEW_DOMAIN}
chown -R 1000:1000 ./sites/${NEW_DOMAIN}
chmod -R 755 ./sites/${NEW_DOMAIN}

# 4. WP-CLI search-replace (docker-compose network, proper path)
echo "🔗 Replacing URLs: http://${SOURCE_DOMAIN} → http://${NEW_DOMAIN}"
${COMPOSE_CMD} run --rm litespeed wp search-replace "http://${SOURCE_DOMAIN}" "http://${NEW_DOMAIN}" \
  /var/www/vhosts/${NEW_DOMAIN} --allow-root

# 5. Update wp-config.php DB_NAME (precise regex)
sed -i "s|DB_NAME', '.*'|DB_NAME', '${NEW_DB}'|" ./sites/${NEW_DOMAIN}/wp-config.php

# 6. Database URL cleanup (safety net)
echo "🔄 Final DB URL cleanup..."
${DOCKER_CMD} exec -i mariadb mysql "${NEW_DB}" -e "
  UPDATE wp_options SET option_value = REPLACE(option_value, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}') 
  WHERE option_name = 'home' OR option_name = 'siteurl';
  UPDATE wp_posts SET guid = REPLACE(guid, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
  UPDATE wp_posts SET post_content = REPLACE(post_content, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
  UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
"

# 7. Optimize tables
echo "⚡ Optimizing database..."
${DOCKER_CMD} exec -i mariadb mysql "${NEW_DB}" -e "
  OPTIMIZE TABLE wp_posts;
  OPTIMIZE TABLE wp_postmeta; 
  OPTIMIZE TABLE wp_options;
"

echo "✅ Copy complete: http://${NEW_DOMAIN}"
echo "   💾 Safety backup: ./backups/${SOURCE_DOMAIN}/*_Pre-Copy-AutoSave/"
echo "   🔧 Next steps:"
echo "      MARIADB_DATABASE=${NEW_DB} bash bin/database.sh ${NEW_DOMAIN}"
echo "      bash bin/domain.sh --add ${NEW_DOMAIN}"
echo "      echo '127.0.0.1 ${NEW_DOMAIN}' | sudo tee -a /etc/hosts"
