#!/usr/bin/env bash
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

APP_NAME='wordpress'
CONT_NAME='litespeed'
DOC_FD=''
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    case ${1} in
        "1")    
            echow "Script will get 'DOMAIN' and 'database' info from .env file, then auto setup virtual host and WordPress site."
            exit 0
        ;;
        "2")
            echow '✅ Service finished! Enjoy your accelerated LiteSpeed server!'
            ;;
    esac       
}

domain_filter(){
    if [[ -z "${1}" ]]; then
        echow "❌ DOMAIN parameter required!"
        exit 1
    fi
    DOMAIN="${1#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN%%/*}"
    [[ -z "$DOMAIN" ]] && { echow "❌ Invalid DOMAIN format!"; exit 1; }
}

gen_root_fd(){
    local domain=${1}
    DOC_FD="./sites/${domain}/"
    if [[ -d "$DOC_FD" ]]; then
        echow "[O] Root folder ${DOC_FD} exists."
    else
        echow "📁 Creating document root..."
        bash bin/domain.sh -add "${domain}" || { echow "❌ Failed to create domain dir"; exit 1; }
        echow "✅ Document root ready."
    fi
}

create_db(){
    local domain=${1}
    if [[ -z "${MARIADB_DATABASE}" || -z "${MARIADB_USER}" || -z "${MARIADB_PASSWORD}" ]]; then
        echow "❌ Missing MariaDB credentials in .env!"
        exit 1
    fi    
    bash bin/database.sh -D "${domain}" -U "${MARIADB_USER}" -P "${MARIADB_PASSWORD}" -DB "${MARIADB_DATABASE}" || {
        echow "❌ Database creation failed!"
        exit 1
    }
}

store_credential(){
    if [[ -f "${DOC_FD}/.db_pass" ]]; then
        echow "[O] Database credentials exist."
    else
        echow "💾 Storing database credentials..."
        cat > "${DOC_FD}/.db_pass" << EOT
{
  "Database": "${MARIADB_DATABASE}",
  "Username": "${MARIADB_USER}",
  "Password": "${MARIADB_PASSWORD}"
}
EOT
        chmod 600 "${DOC_FD}/.db_pass"
    fi
}

app_download(){
    local app=${1} domain=${2}
    echow "⬇️  Installing ${app} for ${domain}..."
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" su -c "appinstallctl.sh --app ${app} --domain ${domain}" || {
        echow "❌ App installation failed!"
        exit 1
    }
}

lsws_restart(){
    echow "🔄 Restarting LiteSpeed..."
    bash bin/webadmin.sh -r || { echow "❌ LiteSpeed restart failed!"; exit 1; }
}

main(){
    domain_filter "${DOMAIN}"
    gen_root_fd "${DOMAIN}"
    create_db "${DOMAIN}"
    store_credential "${DOMAIN}"
    app_download "${APP_NAME}" "${DOMAIN}"
    lsws_restart
    help_message 2
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        -[hH]*|--help|help)
            help_message 1
            ;;
        *)
            DOMAIN="${1}"
            shift
            break
            ;;
    esac
done

[[ -z "$DOMAIN" ]] && help_message 1
main
