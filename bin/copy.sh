#!/bin/bash
# Usage: bash bin/copy.sh source.local newname.local

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

# 🔥 SAFETY: Pre-copy backup of source
echo "💾 Creating safety backup of ${SOURCE_DOMAIN}..."
bash "$(dirname "$0")/backup.sh" "${SOURCE_DOMAIN}" "Pre-Copy-AutoSave"

# 1. Create new database
NEW_DB="${MYSQL_DATABASE}_${NEW_DOMAIN//./_}"
echo "📥 Creating database ${NEW_DB}..."
docker exec -i mariadb mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS \`${NEW_DB}\`;"

# 2. Copy database (source DB → new DB)
SOURCE_DB=$(grep DB_NAME ./sites/${SOURCE_DOMAIN}/wp-config.php 2>/dev/null | cut -d\' -f4 || echo $MYSQL_DATABASE)
echo "📋 Copying database ${SOURCE_DB} → ${NEW_DB}..."
docker exec mariadb mysqldump "$SOURCE_DB" | docker exec -i mariadb mysql "$NEW_DB"

# 3. Copy files with safety backup of target (if exists)
if [[ -d "./sites/${NEW_DOMAIN}" ]]; then
  echo "📂 Target exists, moving to _pre_copy..."
  rm -rf ./sites/${NEW_DOMAIN}_pre_copy 2>/dev/null || true
  mv ./sites/${NEW_DOMAIN} ./sites/${NEW_DOMAIN}_pre_copy
fi

cp -r ./sites/${SOURCE_DOMAIN} ./sites/${NEW_DOMAIN}
chown -R 1000:1000 ./sites/${NEW_DOMAIN}
chmod -R 755 ./sites/${NEW_DOMAIN}

# 4. WP-CLI URL replace (handles serialized data)
echo "🔗 Replacing URLs: http://${SOURCE_DOMAIN} → http://${NEW_DOMAIN}"
docker run --rm \
  -v $(pwd)/sites/${NEW_DOMAIN}:/app \
  -w /app \
  --network host \
  wordpress:cli search-replace "http://${SOURCE_DOMAIN}" "http://${NEW_DOMAIN}" . --allow-root

# 5. Update wp-config.php DB name
sed -i "s|DB_NAME.*=.*'|DB_NAME = '${NEW_DB}';|" ./sites/${NEW_DOMAIN}/wp-config.php

# 6. Update site URLs in database (double safety)
echo "🔄 Updating database URLs..."
docker exec -i mariadb mysql "$NEW_DB" -e "
  UPDATE wp_options SET option_value = REPLACE(option_value, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}') WHERE option_name = 'home' OR option_name = 'siteurl';
  UPDATE wp_posts SET guid = REPLACE(guid, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
  UPDATE wp_posts SET post_content = REPLACE(post_content, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
  UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, '${SOURCE_DOMAIN}', '${NEW_DOMAIN}');
"

# 7. Post-copy optimization
echo "⚡ Optimizing new database..."
docker exec -i mariadb mysql "$NEW_DB" -e "
  OPTIMIZE TABLE wp_posts;
  OPTIMIZE TABLE wp_postmeta;
  OPTIMIZE TABLE wp_options;
"

echo "✅ Copy complete: http://${NEW_DOMAIN}"
echo "   💾 Safety backup: ./backups/${SOURCE_DOMAIN}/[timestamp]_Pre-Copy-AutoSave/"
echo "ℹ️  Next steps:"
echo "   MYSQL_DATABASE=${NEW_DB} bash bin/database.sh ${NEW_DOMAIN}"
echo "   bash bin/domain.sh --add ${NEW_DOMAIN}"
echo "   echo '127.0.0.1 ${NEW_DOMAIN}' | sudo tee -a /etc/hosts"
