#!/usr/bin/env bash
source .env 2>/dev/null || true

# VOLUME-BASED AUTO-DETECTION (V1 default)
if [ -d "./data/db" ]; then
    # LEGACY VOLUME → V1 mysql/docker-compose mode
    COMPOSE_CMD="docker-compose"
    echo "✅ Legacy volume detected → docker-compose mode"
else
    # FRESH INSTALL → V2 mariadb/docker compose mode
    COMPOSE_CMD="docker compose"
    echo "🚀 Fresh install → docker compose mode"
fi

EMAIL=''
NO_EMAIL=''
DOMAIN=''
INSTALL=''
UNINSTALL=''
TYPE=0
CONT_NAME='litespeed'
ACME_SRC='https://raw.githubusercontent.com/Neilpang/acme.sh/master/acme.sh'
EPACE='        '
RENEW=''
RENEW_ALL=''
FORCE=''
REVOKE=''
REMOVE=''

# [REST OF SCRIPT IDENTICAL - just replace docker compose → ${COMPOSE_CMD}]

cert_hook(){
    echo '[Start] Adding ACME hook'
    ${COMPOSE_CMD} exec ${CONT_NAME} su -s /bin/bash -c "certhookctl.sh"
    echo '[End] Adding ACME hook'
}

# Replace ALL docker compose exec → ${COMPOSE_CMD} exec
install_acme(){
    echo '[Start] Install ACME'
    if [ "${1}" = 'true' ]; then
        ${COMPOSE_CMD} exec litespeed su -c "
            cd &&
            wget ${ACME_SRC} &&
            chmod
