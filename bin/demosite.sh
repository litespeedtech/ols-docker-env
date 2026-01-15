#!/usr/bin/env bash
source .env 2>/dev/null || true

# STACK DETECTION (matches all scripts)
if [ -d "./data/db" ]; then
    COMPOSE_CMD="docker-compose"
    DOCKER_CMD="docker"
else
    COMPOSE_CMD="docker compose"
    DOCKER_CMD="docker"
fi

APP_NAME='wordpress'
DOMAIN=$1

echow() {
    echo -e "\033[1m        ${1}\033[0m${@:2}"
}

domain_filter() {
    DOMAIN="${1#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%%/*}"
    [[ -z "$DOMAIN" ]] && { echow "❌ Invalid DOMAIN"; exit 1; }
}

# 1. CREATE DOMAIN DIR
gen_root_fd() {
    local domain=${1}
    DOC_FD="./sites/${domain}"
    if [[ ! -d "$DOC_FD" ]]; then
        echow "📁 Creating ${DOC_FD}..."
        mkdir -p "$DOC_FD"
        chown 1000:1000 "$DOC_FD"
    fi
}

# 2. SETUP DATABASE (matches your database.sh)
create_db() {
    local domain=${1}
    DB_NAME="${MARIADB_DATABASE:-wordpress}_${domain//./_}"
    echow "📥 Creating database ${DB_NAME}..."
    ${DOCKER_CMD} exec -i mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "
        CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
        GRANT ALL ON \`${DB_NAME}\`.* TO '${MARIADB_USER:-wordpress}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD:-wordpress}';
        FLUSH PRIVILEGES;
    "
}

# 3. APPINSTALL VIA CONTAINER
app_download() {
    local domain=${1}
    echow "⬇️  Installing WordPress for ${domain}..."
    ${COMPOSE_CMD} exec litespeed appinstallctl.sh --app wordpress --domain "${domain}"
}

# 4. RESTART LSWS
lsws_restart() {
    echow "🔄 Restarting LiteSpeed..."
    ${COMPOSE_CMD} restart litespeed
}

# MAIN
[[ -z "$1" ]] && { echow "Usage: $0 example.com"; exit 1; }
domain_filter "$1"

gen_root_fd "$DOMAIN"
create_db "$DOMAIN"
app_download "$DOMAIN"
lsws_restart

echow "✅ COMPLETE: http://${DOMAIN}"
echow "   wp-config.php → DB_NAME='${MARIADB_DATABASE:-wordpress}_${DOMAIN//./_}'"
