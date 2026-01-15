#!/usr/bin/env bash
source .env 2>/dev/null || true

# VOLUME DETECTION (matches backup.sh/copy.sh)
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
SQL_DB=${MARIADB_DATABASE:-wordpress}_${DOMAIN//./_}
SQL_USER=${MARIADB_USER:-wordpress}
SQL_PASS=${MARIADB_PASSWORD:-wordpress}
ROOT_PASS=${MARIADB_ROOT_PASSWORD}

check_db_access() {
    ${DOCKER_CMD} exec mysql mysql -uroot -p"${ROOT_PASS}" -e "status" >/dev/null 2>&1
}

db_setup() {
    echo "📥 Creating database '${SQL_DB}' for ${DOMAIN}..."
    ${DOCKER_CMD} exec -i mysql mysql -uroot -p"${ROOT_PASS}" -e "
        CREATE DATABASE IF NOT EXISTS \`${SQL_DB}\`;
        GRANT ALL PRIVILEGES ON \`${SQL_DB}\`.* TO '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASS}';
        FLUSH PRIVILEGES;
    "
}

# MAIN
if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

if ! check_db_access; then
    echo "❌ Cannot access MariaDB (check MARIADB_ROOT_PASSWORD)"
    exit 1
fi

db_setup
echo "✅ Database '${SQL_DB}' ready for ${DOMAIN}"
echo "   wp-config.php → DB_NAME='${SQL_DB}'"
echo "   DB_USER='${SQL_USER}'"
echo "   DB_PASSWORD='${SQL_PASS}'"
