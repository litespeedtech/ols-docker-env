#!/usr/bin/env bash
DOMAIN=''
INSTALL=''
REMOVE=''
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
    echo "${EPACE}${EPACE}Will create certificate for example.test and www.example.test"
    echow '-I, --install'
    echo "${EPACE}${EPACE}Install mkcert on Windows (requires Chocolatey)"
    echow '-R, --remove'
    echo "${EPACE}${EPACE}Remove certificate for a specific domain"
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit"
    exit 0
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
    fi
}

domain_filter(){
    if [ -z "${1}" ]; then
        echo "[X] Domain name is required!"
        exit 1
    fi
    DOMAIN="${1}"
    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN%%/*}"
}

www_domain(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        DOMAIN=$(echo ${1} | cut -c 5-)
    else
        DOMAIN=${1}    
    fi
    WWW_DOMAIN="www.${DOMAIN}"
}

check_mkcert(){
    echo '[Start] Checking mkcert installation'
    
    # Try .exe first (for WSL/Windows)
    if command -v mkcert.exe >/dev/null 2>&1; then
        MKCERT_CMD="mkcert.exe"
        echo -e "[O] mkcert is installed (using: mkcert.exe)"
    elif command -v mkcert >/dev/null 2>&1; then
        MKCERT_CMD="mkcert"
        echo -e "[O] mkcert is installed (using: mkcert)"
    else
        echo "[X] mkcert is not installed!"
        echo "[!] Please run: ./bin/mkcert.sh --install"
        echo "[!] Or install manually: choco install mkcert"
        exit 1
    fi
    
    echo '[End] Checking mkcert'
}

install_mkcert(){
    echo '[Start] Installing mkcert'
    
    # Try Windows executable first (for WSL/Git Bash)
    choco.exe --version > /dev/null 2>&1
    CHOCO_CHECK=$?
    
    # If .exe doesn't work, try without extension
    if [ ${CHOCO_CHECK} != 0 ]; then
        choco --version > /dev/null 2>&1
        CHOCO_CHECK=$?
    fi
    
    if [ ${CHOCO_CHECK} != 0 ]; then
        echo "[X] Chocolatey is not installed or not in PATH!"
        echo "[!] Please install Chocolatey first: https://chocolatey.org/install"
        echo "[!] After installation, restart your terminal"
        exit 1
    fi
    
    echo "[O] Chocolatey is installed"
    
    # Check if mkcert already installed (try .exe first for WSL)
    mkcert.exe -version > /dev/null 2>&1
    MKCERT_CHECK=$?
    
    if [ ${MKCERT_CHECK} != 0 ]; then
        mkcert -version > /dev/null 2>&1
        MKCERT_CHECK=$?
    fi
    
    if [ ${MKCERT_CHECK} = 0 ]; then
        echo "[!] mkcert is already installed"
        MKCERT_VERSION=$(mkcert.exe -version 2>&1 || mkcert -version 2>&1 | head -n 1)
        echo "[!] Version: ${MKCERT_VERSION}"
        echo "[!] Running mkcert -install to ensure local CA is configured..."
        mkcert.exe -install || mkcert -install
        echo '[End] Installing mkcert'
        return 0
    fi
    
    echo "[!] Installing mkcert via Chocolatey..."
    choco.exe install mkcert -y || choco install mkcert -y
    
    if [ ${?} = 0 ]; then
        echo -e "[O] mkcert installed successfully"
        echo "[!] Running mkcert -install to create local CA..."
        mkcert.exe -install || mkcert -install
        echo '[End] Installing mkcert'
    else
        echo "[X] Failed to install mkcert"
        exit 1
    fi
}

create_cert_dir(){
    if [ ! -d "${CERT_DIR}" ]; then
        echo "[!] Creating certificate directory: ${CERT_DIR}"
        mkdir -p "${CERT_DIR}"
    fi
}

generate_cert(){
    echo '[Start] Generating SSL certificate'
    domain_filter "${DOMAIN}"
    www_domain "${DOMAIN}"
    
    create_cert_dir
    
    cd "${CERT_DIR}"
    
    echo -e "[!] Generating certificate for: \033[32m${DOMAIN}\033[0m and \033[32m${WWW_DOMAIN}\033[0m"
    
    # Use the detected mkcert command
    ${MKCERT_CMD} "${DOMAIN}" "${WWW_DOMAIN}"
    
    if [ ${?} = 0 ]; then
        echo -e "[O] Certificate generated successfully"
        
        # Rename files to standard format
        CERT_FILE="${DOMAIN}+1.pem"
        KEY_FILE="${DOMAIN}+1-key.pem"
        
        if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
            echo "[!] Certificate files:"
            echo "${EPACE}Cert: ${CERT_DIR}/${CERT_FILE}"
            echo "${EPACE}Key:  ${CERT_DIR}/${KEY_FILE}"
        fi
    else
        echo "[X] Failed to generate certificate"
        exit 1
    fi
    
    cd - > /dev/null
    echo '[End] Generating SSL certificate'
}

configure_litespeed(){
    echo '[Start] Configuring OpenLiteSpeed'
    
    CERT_FILE="${DOMAIN}+1.pem"
    KEY_FILE="${DOMAIN}+1-key.pem"
    
    # Check if certificate files exist
    if [ ! -f "${CERT_DIR}/${CERT_FILE}" ] || [ ! -f "${CERT_DIR}/${KEY_FILE}" ]; then
        echo "[X] Certificate files not found!"
        exit 1
    fi
    
    echo "[!] Configuring SSL for domain: ${DOMAIN}"
    
    LSWS_CONF_DIR="/usr/local/lsws/conf"
    HTTPD_CONF="${LSWS_CONF_DIR}/httpd_config.conf"
    
    # Copy certificates to container
    docker compose cp "${CERT_DIR}/${CERT_FILE}" ${CONT_NAME}:${LSWS_CONF_DIR}/cert/
    docker compose cp "${CERT_DIR}/${KEY_FILE}" ${CONT_NAME}:${LSWS_CONF_DIR}/cert/
    
    echo "[O] Certificates copied to container"
    
    # Backup config
    docker compose exec -T ${CONT_NAME} bash -c "cp ${HTTPD_CONF} ${HTTPD_CONF}.backup.\$(date +%Y%m%d_%H%M%S)"
    echo "[O] Config backed up"
    
    # Kiểm tra xem đã có SSL Listener chưa
    HAS_SSL=$(docker compose exec -T ${CONT_NAME} bash -c "grep -c 'listener Default HTTPS' ${HTTPD_CONF}" | tr -d '\r')
    
    if [ "${HAS_SSL}" = "0" ]; then
        echo '[!] Creating new SSL Listener...'
        
        # Tạo SSL listener mới
        docker compose exec -T ${CONT_NAME} bash -c "cat >> ${HTTPD_CONF} <<'LISTENER_EOF'

listener Default HTTPS {
  address                 *:443
  secure                  1
  keyFile                 ${LSWS_CONF_DIR}/cert/${KEY_FILE}
  certFile                ${LSWS_CONF_DIR}/cert/${CERT_FILE}
  certChain               1
  sslProtocol             24
  enableSpdy              15
  map                     ${DOMAIN} ${DOMAIN}
}
LISTENER_EOF
"
        echo '[O] SSL Listener created'
    else
        echo '[!] SSL Listener exists, updating...'
        
        # Cập nhật cert paths
        docker compose exec -T ${CONT_NAME} bash -c "
            sed -i '/listener Default HTTPS/,/^}/s|keyFile.*|  keyFile                 ${LSWS_CONF_DIR}/cert/${KEY_FILE}|' ${HTTPD_CONF}
            sed -i '/listener Default HTTPS/,/^}/s|certFile.*|  certFile                ${LSWS_CONF_DIR}/cert/${CERT_FILE}|' ${HTTPD_CONF}
        "
        echo '[O] Certificate paths updated'
        
        # Kiểm tra xem domain đã được map chưa
        HAS_MAPPING=$(docker compose exec -T ${CONT_NAME} bash -c "grep -A 15 'listener Default HTTPS' ${HTTPD_CONF} | grep -c 'map.*${DOMAIN}'" | tr -d '\r')
        
        if [ "${HAS_MAPPING}" = "0" ]; then
            # Thêm mapping
            docker compose exec -T ${CONT_NAME} bash -c "
                sed -i '/listener Default HTTPS/,/^}/ {
                    /^}/i\  map                     ${DOMAIN} ${DOMAIN}
                }' ${HTTPD_CONF}
            "
            echo '[O] Domain mapping added to SSL Listener'
        else
            echo '[!] Domain mapping already exists'
        fi
    fi
    
    echo ""
    echo "[!] Current SSL Listener configuration:"
    docker compose exec -T ${CONT_NAME} bash -c "grep -A 15 'listener Default HTTPS' ${HTTPD_CONF}"
    echo ""
    
    if [ ${?} = 0 ]; then
        echo -e "[O] SSL configured for: \033[32m${DOMAIN}\033[0m"
        echo "[!] Restarting OpenLiteSpeed..."
        lsws_restart
    else
        echo "[X] Failed to configure SSL"
        exit 1
    fi
    
    echo '[End] Configuring OpenLiteSpeed'
}

lsws_restart(){
    docker compose exec ${CONT_NAME} su -c '/usr/local/lsws/bin/lswsctrl restart >/dev/null'
    if [ ${?} = 0 ]; then
        echo -e "[O] OpenLiteSpeed restarted successfully"
    else
        echo "[X] Failed to restart OpenLiteSpeed"
    fi
}

remove_cert(){
    echo '[Start] Removing SSL certificate'
    domain_filter "${DOMAIN}"
    
    CERT_FILE="${DOMAIN}+1.pem"
    KEY_FILE="${DOMAIN}+1-key.pem"
    
    if [ -f "${CERT_DIR}/${CERT_FILE}" ]; then
        rm "${CERT_DIR}/${CERT_FILE}"
        echo -e "[O] Removed: ${CERT_DIR}/${CERT_FILE}"
    fi
    
    if [ -f "${CERT_DIR}/${KEY_FILE}" ]; then
        rm "${CERT_DIR}/${KEY_FILE}"
        echo -e "[O] Removed: ${CERT_DIR}/${KEY_FILE}"
    fi
    
    # Remove SSL listener config
    SSL_LISTENER="/usr/local/lsws/conf/cert/${DOMAIN}.xml"
    docker compose exec ${CONT_NAME} bash -c "[ -f ${SSL_LISTENER} ] && rm ${SSL_LISTENER}"
    
    echo '[End] Removing SSL certificate'
    lsws_restart
}

main(){
    if [ "${INSTALL}" = 'true' ]; then
        install_mkcert
        exit 0
    fi
    
    if [ "${REMOVE}" = 'true' ]; then
        remove_cert
        exit 0
    fi
    
    check_mkcert
    generate_cert
    configure_litespeed
    
    echo ""
    echo -e "\033[1m[SUCCESS] SSL certificate setup completed!\033[0m"
    echo ""
    echo "Next steps:"
    echo "1. Add '${DOMAIN}' to your Windows hosts file (C:\Windows\System32\drivers\etc\hosts)"
    echo "   Example: 127.0.0.1 ${DOMAIN} ${WWW_DOMAIN}"
    echo "2. Configure your virtual host to use SSL-${DOMAIN} listener"
    echo "3. Access https://${DOMAIN} in your browser"
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[dD] | -domain | --domain) 
            shift
            check_input "${1}"
            DOMAIN="${1}"
            ;;
        -[iI] | --install) 
            INSTALL=true
            ;;
        -[rR] | --remove)
            REMOVE=true
            ;;
        *) 
            help_message
            ;;              
    esac
    shift
done

main