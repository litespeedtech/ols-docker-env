#!/usr/bin/env bash
source .env 2>/dev/null || true

# VOLUME DETECTION (matches all scripts)
if [ -d "./data/db" ]; then
    COMPOSE_CMD="docker-compose"
    DOCKER_CMD="docker"
else
    COMPOSE_CMD="docker compose"
    DOCKER_CMD="docker"
fi

CONT_NAME='litespeed'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

check_input(){
    if [[ -z "${1}" ]]; then
        echow "❌ Domain name required!"
        exit 1
    fi
    [[ ! "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]] && {
        echow "❌ Invalid domain format: $1"
        exit 1
    }
}

add_domain(){
    local domain=${1}
    check_input "${domain}"
    
    echow "➕ Adding domain ${domain}..."
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -s /bin/bash lsadm -c \
        "cd /usr/local/lsws/conf && domainctl.sh --add ${domain}" || {
        echow "❌ Failed to add domain ${domain}"
        exit 1
    }
    
    if [[ ! -d "./sites/${domain}" ]]; then 
        echow "📁 Creating site directory..."
        mkdir -p "./sites/${domain}/{html,logs,certs}"
        chown -R 1000:1000 "./sites/${domain}"
    else
        echow "[O] Site directory already exists."
    fi
    
    # FIXED: Direct container restart
    ${COMPOSE_CMD} restart "${CONT_NAME}"
    echow "✅ Domain ${domain} added successfully!"
}

del_domain(){
    local domain=${1}
    check_input "${domain}"
    
    echow "➖ Removing domain ${domain}..."
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -s /bin/bash lsadm -c \
        "cd /usr/local/lsws/conf && domainctl.sh --del ${domain}" || {
        echow "❌ Failed to remove domain ${domain}"
        exit 1
    }
    
    # FIXED: Direct container restart
    ${COMPOSE_CMD} restart "${CONT_NAME}"
    echow "✅ Domain ${domain} removed successfully!"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow "-A, --add [domain_name]"
    echo "${EPACE}${EPACE}Example: domain.sh -A example.com"
    echow "-D, --del [domain_name]" 
    echo "${EPACE}${EPACE}Example: domain.sh -D example.com"
    echow '-H, --help'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        -[hH]*|--help|help) help_message ;;
        -[aA]*|--add)
            shift
            add_domain "${1}"
            exit 0
            ;;
        -[dD]*|--del|--delete)
            shift
            del_domain "${1}"
            exit 0
            ;;
        *) echow "❌ Unknown option: ${1}"; help_message ;;
    esac
    shift
done

echow "❌ No action specified!"
help_message
