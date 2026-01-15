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

DOMAIN=''
INSTALL=false
REMOVE=false
CONT_NAME='litespeed'
CERT_DIR='./certs'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mUSAGE\033[0m"
    echo "${EPACE}mkcert.sh [OPTIONS]"
    echo ""
    echo -e "\033[1mOPTIONS\033[0m" 
    echow '-D, --domain [DOMAIN_NAME]'         
    echo "${EPACE}${EPACE}Example: mkcert.sh --domain example.test"
    echow '-I, --install'
    echo "${EPACE}${EPACE}Install mkcert for your OS"
    echow '-R, --remove --domain [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Example: mkcert.sh --remove --domain example.test"
    echow '-H, --help'
    exit 0
}

domain_filter(){
    [[ -z "${1}" ]] && { echow "❌ Domain name required!"; exit 1; }
    DOMAIN="${1#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN%%/*}"
    [[ -z "$DOMAIN" ]] && { echow "❌ Invalid domain!"; exit 1; }
}

www_domain(){
    if [[ ${1} == www.* ]]; then
        DOMAIN="${1#www.}"
    fi
    WWW_DOMAIN="www.${DOMAIN}"
}

check_mkcert() {
    echow "[Start] Checking mkcert..."
    MKCERT_CMD=$(command -v mkcert.exe 2>/dev/null || command -v mkcert 2>/dev/null) || {
        echow "❌ mkcert not found! Run: $0 --install"
        exit 1
    }
    echow "✅ mkcert found: ${MKCERT_CMD}"
}

install_mkcert() {
    echow "🔧 Installing mkcert..."
    case "$(uname -s)" in
        Linux*)   OS="linux" ;;
        Darwin*)  OS="mac" ;;
        MINGW*|MSYS*|CYGWIN*|Windows*) OS="windows" ;;
        *) echow "❌ Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    
    if command -v mkcert >/dev/null 2>&1 || command -v mkcert.exe >/dev/null 2>&1; then
        echow "✅ mkcert already installed, ensuring CA..."
        command -v mkcert.exe >/dev/null 2>&1 && mkcert.exe -install || mkcert -install
        return 0
    fi
    
    case "$OS" in
        windows) choco install mkcert -y ;;
        mac) brew install mkcert ;;
        linux)
            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y mkcert libnss3-tools
            else
                echow "❌ Install mkcert manually: https://github.com/FiloSottile/mkcert"
                exit 1
            fi
            ;;
    esac
    
    command -v mkcert >/dev/null 2>&1 && mkcert -install || {
        echow "❌ Installation failed!"
        exit 1
    }
    echow "✅ mkcert installed and configured!"
}

domain_verify(){
    local domain="${1}"
    local doc_path="/var/www/vhosts/${domain}/html"
    echow "🔍 Verifying domain '${domain}'..."
    
    if ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "[ -d ${doc_path} ]"; then
        echow "✅ Domain ${domain} exists"
        return 0
    fi
    echow "❌ Domain ${domain} not found! Run: bash bin/domain.sh -A ${domain}"
    exit 1
}

generate_cert(){
    echow "📜 Generating SSL certs..."
    www_domain "${DOMAIN}"
    mkdir -p "${CERT_DIR}/${DOMAIN}"
    pushd "${CERT_DIR}/${DOMAIN}" >/dev/null
    
    ${MKCERT_CMD} -key-file key.pem -cert-file cert.pem "${DOMAIN}" "${WWW_DOMAIN}" || {
        echow "❌ Cert generation failed!"
        popd >/dev/null
        rm -rf "${CERT_DIR}/${DOMAIN}"
        exit 1
    }
    
    echow "✅ Certs created:"
    echow "   Cert: ${CERT_DIR}/${DOMAIN}/cert.pem"
    echow "   Key:  ${CERT_DIR}/${DOMAIN}/key.pem"
    popd >/dev/null
}

lsws_restart() {
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -c '/usr/local/lsws/bin/lswsctrl restart' || {
        echow "❌ LiteSpeed restart failed!"
        exit 1
    }
    echow "✅ OpenLiteSpeed restarted"
}

create_local_template(){
    local source_file="/usr/local/lsws/conf/templates/docker.conf"
    local dest_file="/usr/local/lsws/conf/templates/docker-local.conf"
    
    if ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "[ -f ${dest_file} ]"; then
        echow "✅ docker-local.conf exists"
        return 0
    fi
    
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "
        cp ${source_file} ${dest_file}
        sed -i '/^  vhssl  {/,/^  }/d; \$d' \${dest_file}
        cat >> \${dest_file} <<'VHSSL_EOF'
  vhssl  {
    keyFile               /usr/local/lsws/conf/cert/\$VH_NAME/key.pem
    certFile              /usr/local/lsws/conf/cert/\$VH_NAME/cert.pem
    certChain             1
  }
}
VHSSL_EOF
        chown lsadm:lsadm \${dest_file} 2>/dev/null || chown nobody:nogroup \${dest_file}
        chmod 644 \${dest_file}
    " || { echow "❌ Template creation failed!"; exit 1; }
    
    echow "✅ docker-local.conf created"
}

register_local_template() {
    local config_file="/usr/local/lsws/conf/httpd_config.conf"
    if ! ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "grep -q 'vhTemplate dockerLocal' ${config_file}"; then
        ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "
            cat >> ${config_file} <<EOF

vhTemplate dockerLocal {
  templateFile            conf/templates/docker-local.conf
  listeners               HTTP, HTTPS
  note                    dockerLocal
}
EOF
        "
        echow "✅ dockerLocal template registered"
    fi
}

configure_litespeed(){
    local cert_host_path="${CERT_DIR}/${DOMAIN}"
    local cert_container_path="/usr/local/lsws/conf/cert/${DOMAIN}"
    
    create_local_template
    register_local_template
    
    # Find vhost
    local vhost_name=$(${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "
        grep -B 2 'vhDomain.*${DOMAIN}' /usr/local/lsws/conf/httpd_config.conf | 
        grep 'member' | awk '{print \$2}'" | tr -d '\r') || {
        echow "❌ No vhost found for ${DOMAIN}"
        exit 1
    }
    
    echow "🔗 Configuring vhost: ${vhost_name}"
    
    # Copy certs
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "mkdir -p ${cert_container_path}"
    ${COMPOSE_CMD} cp "${cert_host_path}/cert.pem" "${CONT_NAME}:${cert_container_path}/cert.pem"
    ${COMPOSE_CMD} cp "${cert_host_path}/key.pem" "${CONT_NAME}:${cert_container_path}/key.pem"
    
    # Move to dockerLocal template (simplified)
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "
        cp /usr/local/lsws/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.backup.\$(date +%Y%m%d_%H%M%S)
        sed -i '/vhTemplate docker {/,/}/ {/member ${vhost_name} {/,/}/d;}' /usr/local/lsws/conf/httpd_config.conf
        sed -i '/vhTemplate dockerLocal {/,/}/ { /^}/i\  member ${vhost_name} {\n    vhDomain ${DOMAIN},www.${DOMAIN}\n  }' /usr/local/lsws/conf/httpd_config.conf
    "
    
    lsws_restart
    echow "🎉 SSL enabled for ${DOMAIN}!"
}

remove_cert(){
    local cert_host_path="${CERT_DIR}/${DOMAIN}"
    local cert_container_path="/usr/local/lsws/conf/cert/${DOMAIN}"
    
    # Cleanup host certs
    [[ -d "${cert_host_path}" ]] && rm -rf "${cert_host_path}" && echow "🗑️  Host certs removed"
    
    # Cleanup container certs & revert config
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" bash -c "
        [[ -d ${cert_container_path} ]] && rm -rf ${cert_container_path}
        cp /usr/local/lsws/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.backup.\$(date +%Y%m%d_%H%M%S)
        sed -i '/vhTemplate dockerLocal {/,/}/ {/member .*${DOMAIN} {/,/}/d;}' /usr/local/lsws/conf/httpd_config.conf
    "
    
    lsws_restart
    echow "✅ SSL removed for ${DOMAIN}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case ${1} in
        -[hH]*|--help) help_message ;;
        -[dD]*|--domain) shift; DOMAIN="$1" ;;
        -[iI]*|--install) INSTALL=true; break ;;
        -[rR]*|--remove) REMOVE=true; shift; DOMAIN="$1"; break ;;
        *) help_message ;;
    esac
    shift
done

[[ "$INSTALL" == true ]] && { install_mkcert; exit 0; }
[[ "$REMOVE" == true ]] && { domain_filter "$DOMAIN"; remove_cert; exit 0; }

domain_filter "$DOMAIN"
check_mkcert
domain_verify "$DOMAIN"
generate_cert
configure_litespeed
