#!/usr/bin/env bash
source .env 2>/dev/null || true

# LEGACY FALLBACK: MYSQL_* vars OR COMPOSE_V1=true
if [ -n "${MYSQL_DATABASE:-}" ] || [ "${COMPOSE_V1:-false}" = "true" ]; then
    LEGACY_MODE=true
    ROOT_PASS=${MYSQL_ROOT_PASSWORD}
    DB_NAME=${MYSQL_DATABASE}
    CLIENT_CMD="mysql"
    echo "🔄 Legacy mode: MYSQL_* vars detected"
else
    LEGACY_MODE=false
    ROOT_PASS=${MARIADB_ROOT_PASSWORD}
    DB_NAME=${MARIADB_DATABASE}
    CLIENT_CMD="mariadb"
fi

# Universal Compose detection
COMPOSE_CMD=$(command -v docker-compose >/dev/null 2>&1 && echo "docker-compose" || echo "docker compose")

DOMAIN='' SQL_DB='' SQL_USER='' SQL_PASS='' ANY="'%'" SET_OK=0 EPACE='        ' METHOD=0

check_db_access(){
    ${COMPOSE_CMD} exec -T mariadb su -c "${CLIENT_CMD} -uroot --password=${ROOT_PASS} -e 'status'" >/dev/null 2>&1
}

check_db_exist(){
    ${COMPOSE_CMD} exec -T mariadb su -c "test -e /var/lib/mysql/${1}"
}

check_db_not_exist(){
    ${COMPOSE_CMD} exec -T mariadb su -c "test -e /var/lib/mysql/${1}"
}

db_setup(){  
    ${COMPOSE_CMD} exec -T mariadb su -c "${CLIENT_CMD} -uroot --password=${ROOT_PASS} \
    -e \"CREATE DATABASE '${SQL_DB}';\" \
    -e \"GRANT ALL PRIVILEGES ON '${SQL_DB}'.* TO '${SQL_USER}'@'${ANY}' IDENTIFIED BY '${SQL_PASS}';\" \
    -e \"FLUSH PRIVILEGES;\""
    SET_OK=${?}
}
# [Rest unchanged...]
