#!/usr/bin/env bash
DOMAIN=''
INSTALL=''
REMOVE=''
TEST=''
CONT_NAME='litespeed'
CERT_DIR='./certs'
EPACE='        '

# Function to print messages with a specific format
echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

# Function to display help message
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

# Function to check input parameters
check_input(){
    if [ -z "${1}" ]; then
        help_message
    fi
}

# Function to filter and extract domain name
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

# Function to get www version of the domain
www_domain(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        DOMAIN=$(echo ${1} | cut -c 5-)
    else
        DOMAIN=${1}    
    fi
    WWW_DOMAIN="www.${DOMAIN}"
}

# Function to check if mkcert is installed
check_mkcert() {
    echo "[Start] Checking mkcert installation..."

    # Detect mkcert command (Windows supported, other OS can be added later)
    if MKCERT_CMD=$(command -v mkcert.exe 2>/dev/null || command -v mkcert 2>/dev/null); then
        echo "[✔] mkcert found at: ${MKCERT_CMD}"
    else
        echo "[✖] mkcert not found!"
        echo "→ Please run 'bash bin/mkcert.sh --install' or install it manually."
        echo "   Windows: choco install mkcert"
        echo "   (Linux/macOS support can be added here later)"
        exit 1
    fi

    echo "[End] mkcert check completed."
}

# Function to install mkcert on Windows using Chocolatey
# ------------------------------------------------------------------------------
# 💡 Notes for contributors:
#   - This script currently supports Windows / WSL / Git Bash only.
#   - To extend for macOS or Linux, add logic below:
#       macOS:  brew install mkcert nss
#       Ubuntu: sudo apt install mkcert libnss3-tools
#       Fedora: sudo dnf install mkcert nss-tools
# ------------------------------------------------------------------------------
install_mkcert() {
    echo "[Start] Installing mkcert..."

    # 1️⃣ Check if mkcert is already installed
    if command -v mkcert.exe >/dev/null 2>&1 || command -v mkcert >/dev/null 2>&1; then
        echo "[O] mkcert is already installed."
        echo "[!] Ensuring local CA is installed..."
        # Ensure local CA is installed
        (mkcert.exe -install || mkcert -install)
        echo "[O] Local CA configured."
        echo "[End] mkcert installation check complete."
        return 0
    fi

    # 2️⃣ Check if Chocolatey is available
    if ! command -v choco.exe >/dev/null 2>&1 && ! command -v choco >/dev/null 2>&1; then
        echo "[X] Chocolatey not found!"
        echo "→ Please install Chocolatey from: https://chocolatey.org/install"
        echo "→ After installation, restart your terminal and re-run this script."
        exit 1
    fi

    # 3️⃣ Install mkcert using Chocolatey
    echo "[*] Installing mkcert via Chocolatey..."
    (choco.exe install mkcert -y || choco install mkcert -y)

    # 4️⃣ Verify installation result
    if command -v mkcert.exe >/dev/null 2>&1 || command -v mkcert >/dev/null 2>&1; then
        echo "[O] mkcert installed successfully."
        echo "[!] Creating local CA..."
        (mkcert.exe -install || mkcert -install)
        echo "[O] Local CA configured."
        echo "[End] mkcert installation complete."
    else
        echo "[X] mkcert installation failed!"
        exit 1
    fi
}

# Function to create certificate directory if it doesn't exist
create_cert_dir(){
    if [ ! -d "${CERT_DIR}" ]; then
        echo "[!] Creating certificate directory: ${CERT_DIR}"
        mkdir -p "${CERT_DIR}"
    fi
}

# Function to generate SSL certificate using mkcert
generate_cert(){
    echo '[Start] Generating SSL certificate'
    domain_filter "${DOMAIN}"
    www_domain "${DOMAIN}"
    
    create_cert_dir
    
    mkdir -p "${CERT_DIR}/${DOMAIN}"

    cd "${CERT_DIR}/${DOMAIN}"
    
    echo -e "[!] Generating certificate for: \033[32m${DOMAIN}\033[0m and \033[32m${WWW_DOMAIN}\033[0m"
    
    # Use the detected mkcert command
    ${MKCERT_CMD} -key-file key.pem -cert-file cert.pem "${DOMAIN}" "${WWW_DOMAIN}" >/dev/null 2>&1
    
    if [ ${?} = 0 ]; then
        echo -e "[O] Certificate generated successfully"
        echo "[!] Certificate files:"
        echo "${EPACE}Cert: ${CERT_DIR}/${DOMAIN}/cert.pem"
        echo "${EPACE}Key:  ${CERT_DIR}/${DOMAIN}/key.pem"
    else
        echo "[X] Failed to generate certificate"
        cd ../..
        rm -rf "${CERT_DIR}/${DOMAIN}"
        exit 1
    fi
    
    cd - > /dev/null
    echo '[End] Generating SSL certificate'
}

configure_litespeed(){
    echo '[Start] Configuring OpenLiteSpeed for domain'
    
    local cert_host_path="${CERT_DIR}/${DOMAIN}"
    
    # Check if certificate files exist
    if [ ! -f "${cert_host_path}/cert.pem" ] || [ ! -f "${cert_host_path}/key.pem" ]; then
        echo "[X] Certificate files not found on host at: ${cert_host_path}"
        exit 1
    fi
    
    echo "[!] Configuring SSL for domain: ${DOMAIN}"
    
    # Define paths inside the container
    local lsws_conf_dir="/usr/local/lsws/conf"
    local httpd_conf="${lsws_conf_dir}/httpd_config.conf"
    local vhosts_dir="${lsws_conf_dir}/vhosts"
    local cert_container_path="${lsws_conf_dir}/cert/${DOMAIN}"

    # Find the Virtual Host name mapped to the domain
    echo "[!] Searching for Virtual Host mapped to '${DOMAIN}'..."
    local vhost_name=$(docker compose exec -T ${CONT_NAME} bash -c "grep -B 2 'vhDomain.*${DOMAIN}' ${httpd_conf} | grep 'member' | awk '{print \$2}'" | tr -d '\r')

    if [ -z "${vhost_name}" ]; then
        echo "[X] No Virtual Host found for domain '${DOMAIN}' in ${httpd_conf}."
        echo "[!] Please add this domain to your environment first (e.g., using the 'domain' script)."
        exit 1
    fi
    echo "[O] Found Virtual Host member name: '${vhost_name}'"

    local vhconf_path="${vhosts_dir}/${vhost_name}/vhconf.conf"

    # Copy certificate files into the container
    echo "[!] Copying certificates to container..."
    docker compose exec -T ${CONT_NAME} bash -c "mkdir -p ${cert_container_path}"
    docker compose cp "${cert_host_path}/cert.pem" "${CONT_NAME}:${cert_container_path}/cert.pem"
    docker compose cp "${cert_host_path}/key.pem" "${CONT_NAME}:${cert_container_path}/key.pem"
    echo "[O] Certificates copied to container at: ${cert_container_path}"

    # Modify the vhost configuration to enable SSL
    echo "[!] Modifying vhost config: ${vhconf_path}"
    docker compose exec -T ${CONT_NAME} bash -c "
        # Create vhconf.conf if it doesn't exist
        if [ ! -f ${vhconf_path} ]; then
            mkdir -p \$(dirname ${vhconf_path})
            touch ${vhconf_path}
            echo '[O] Created missing vhconf.conf file.'
        fi

        # Backup vhconf.conf
        cp ${vhconf_path} ${vhconf_path}.backup.\$(date +%Y%m%d_%H%M%S)

        # Remove existing vhssl block if present to avoid duplicates
        sed -i '/vhssl[[:space:]]*{/,/}/d' ${vhconf_path}
        sed -i '/^virtualHostConfig[[:space:]]*{/,/}/d' ${vhconf_path}

        # Add new SSL configuration inside a virtualHostConfig block
        cat >> ${vhconf_path} <<VHSSL_EOF
vhssl {
  keyFile                 ${cert_container_path}/key.pem
  certFile                ${cert_container_path}/cert.pem
  certChain               1
}
VHSSL_EOF
    "
    
    if [ ${?} = 0 ]; then
        echo -e "[O] SSL configured for vhost: \033[32m${vhost_name}\033[0m"
        echo "[!] Restarting OpenLiteSpeed to apply changes..."
        lsws_restart
    else
        echo "[X] Failed to configure SSL for vhost"
        exit 1
    fi
    
    echo '[End] Configuring OpenLiteSpeed'
}

# Function to restart the OpenLiteSpeed service inside a Docker container
lsws_restart() {
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
    LSWS_CONF_DIR="/usr/local/lsws/conf"
    HTTPD_CONF="${LSWS_CONF_DIR}/httpd_config.conf"
    
    # 1. Xóa chứng chỉ trên host
    if [ -f "${CERT_DIR}/${CERT_FILE}" ]; then
        rm "${CERT_DIR}/${CERT_FILE}"
        echo -e "[O] Removed: ${CERT_DIR}/${CERT_FILE}"
    else
        echo "[!] Certificate file not found: ${CERT_DIR}/${CERT_FILE}"
    fi
    
    if [ -f "${CERT_DIR}/${KEY_FILE}" ]; then
        rm "${CERT_DIR}/${KEY_FILE}"
        echo -e "[O] Removed: ${CERT_DIR}/${KEY_FILE}"
    else
        echo "[!] Key file not found: ${CERT_DIR}/${KEY_FILE}"
    fi
    
    # 2. Xóa chứng chỉ trong container
    docker compose exec -T ${CONT_NAME} bash -c "
        if [ -f ${LSWS_CONF_DIR}/cert/${CERT_FILE} ]; then
            rm ${LSWS_CONF_DIR}/cert/${CERT_FILE}
            echo '[O] Removed certificate from container'
        fi
        
        if [ -f ${LSWS_CONF_DIR}/cert/${KEY_FILE} ]; then
            rm ${LSWS_CONF_DIR}/cert/${KEY_FILE}
            echo '[O] Removed key from container'
        fi
    "
    
    # 3. Xóa domain mapping khỏi SSL Listener
    echo "[!] Removing domain mapping from SSL Listener..."
    
    HAS_MAPPING=$(docker compose exec -T ${CONT_NAME} bash -c "grep -c 'map.*${DOMAIN}' ${HTTPD_CONF}" | tr -d '\r')
    
    if [ "${HAS_MAPPING}" != "0" ]; then
        # Backup trước khi xóa
        docker compose exec -T ${CONT_NAME} bash -c "cp ${HTTPD_CONF} ${HTTPD_CONF}.backup.\$(date +%Y%m%d_%H%M%S)"
        
        # Xóa dòng map của domain
        docker compose exec -T ${CONT_NAME} bash -c "
            sed -i '/listener Default HTTPS/,/^}/ {
                /map.*${DOMAIN}/d
            }' ${HTTPD_CONF}
        "
        echo -e "[O] Removed domain mapping for: \033[32m${DOMAIN}\033[0m"
        
        # Kiểm tra xem còn domain nào được map không
        REMAINING_MAPS=$(docker compose exec -T ${CONT_NAME} bash -c "grep -A 15 'listener Default HTTPS' ${HTTPD_CONF} | grep -c 'map'" | tr -d '\r')
        
        if [ "${REMAINING_MAPS}" = "0" ]; then
            echo "[!] No more domains mapped to SSL Listener"
            echo "[?] Do you want to remove the entire SSL Listener? (y/N)"
            read -r REMOVE_LISTENER
            
            if [[ "${REMOVE_LISTENER}" =~ ^[Yy]$ ]]; then
                docker compose exec -T ${CONT_NAME} bash -c "
                    sed -i '/listener Default HTTPS {/,/^}/d' ${HTTPD_CONF}
                "
                echo "[O] SSL Listener removed"
            fi
        fi
    else
        echo "[!] Domain mapping not found in SSL Listener"
    fi
    
    # 4. Hiển thị cấu hình hiện tại
    echo ""
    echo "[!] Current SSL Listener configuration:"
    docker compose exec -T ${CONT_NAME} bash -c "grep -A 15 'listener Default HTTPS' ${HTTPD_CONF}" || echo "[!] No SSL Listener found"
    echo ""
    
    # 5. Restart LiteSpeed
    echo "[!] Restarting OpenLiteSpeed..."
    lsws_restart
    
    echo ""
    echo -e "\033[1m[SUCCESS] Certificate removed for domain: ${DOMAIN}\033[0m"
    echo ""
    echo '[End] Removing SSL certificate'
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

    if [ "${TEST}" = 'true' ]; then
        check_mkcert
        exit 0
    fi

    check_mkcert
    generate_cert
    configure_litespeed
}

# Parse command-line arguments
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
        -[tT] | --test) 
            TEST=true
            ;;
        *) 
            help_message
            ;;              
    esac
    shift
done

main