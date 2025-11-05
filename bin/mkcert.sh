#!/usr/bin/env bash
DOMAIN=''
INSTALL=''
REMOVE=''
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

# Function to verify if domain has been added (by checking document root existence)
domain_verify(){
    local domain="${1}"
    local doc_path="/var/www/vhosts/${domain}/html"
    
    echo "[!] Checking if domain '${domain}' has been added..."
    
    if docker compose exec -T ${CONT_NAME} bash -c "[ -d ${doc_path} ]" 2>/dev/null; then
        echo -e "[O] Domain \033[32m${domain}\033[0m exists (document root found)"
        return 0
    else
        echo -e "[X] Domain \033[31m${domain}\033[0m has NOT been added yet!"
        echo "[!] Document root not found: ${doc_path}"
        echo "[!] Please add this domain first using: bash bin/domain.sh -a ${domain}"
        exit 1
    fi
}

# Function to generate SSL certificate using mkcert
generate_cert(){
    echo '[Start] Generating SSL certificate'
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

# Function to create docker-local.conf template for local development
create_local_template(){
    echo '[Start] Creating docker-local.conf template'
    
    local source_file="/usr/local/lsws/conf/templates/docker.conf"
    local dest_file="/usr/local/lsws/conf/templates/docker-local.conf"

    # Check if template file already exists
    if docker compose exec -T ${CONT_NAME} bash -c "[ -f ${dest_file} ]" 2>/dev/null; then
        echo "[i] Template file already exists: ${dest_file}"
        echo '[End] Creating docker-local.conf template'
        return 0
    fi
    
    # Copy and modify template file in a single command
    docker compose exec -T ${CONT_NAME} bash -c "
        # Copy template file
        cp ${source_file} ${dest_file}
        
        # Remove old vhssl block and last closing brace
        sed -i '/^  vhssl  {/,/^  }/d; \$d' ${dest_file}
        
        # Append new vhssl configuration
        cat >> ${dest_file} <<'VHSSL_EOF'
  vhssl  {
    keyFile               /usr/local/lsws/conf/cert/\$VH_NAME/key.pem
    certFile              /usr/local/lsws/conf/cert/\$VH_NAME/cert.pem
    certChain             1
  }
}
VHSSL_EOF
        
        # Fix ownership and permissions
        chown nobody:nogroup ${dest_file} 2>/dev/null || chown lsadm:lsadm ${dest_file}
        chmod 644 ${dest_file}
    "
    
    echo -e "[O] Template \033[32mdocker-local.conf\033[0m created successfully!"
    echo -e "    SSL certificates path: /usr/local/lsws/conf/cert/\$VH_NAME/"
    echo '[End] Creating docker-local.conf template'
}

# Function to register dockerLocal vhTemplate in httpd_config.conf
register_local_template() {
  echo '[Start] Registering vhTemplate: dockerLocal'

  local config_file="/usr/local/lsws/conf/httpd_config.conf"
  local template_name="dockerLocal"
  local template_path="conf/templates/docker-local.conf"

  docker compose exec -T ${CONT_NAME} bash -c "
    if ! grep -q 'vhTemplate ${template_name} {' ${config_file}; then
      cat >> ${config_file} <<EOF

vhTemplate ${template_name} {
  templateFile            ${template_path}
  listeners               HTTP, HTTPS
  note                    ${template_name}
}
EOF
      echo '[✔] Template ${template_name} registered.'
    else
      echo '[i] Template ${template_name} already exists, skipped.'
    fi
  "

  echo '[End] Registering vhTemplate complete.'
}

# Function to configure OpenLiteSpeed for local SSL
configure_litespeed(){
    echo '[Start] Configuring OpenLiteSpeed for local SSL'
    
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
    local cert_container_path="${lsws_conf_dir}/cert/${DOMAIN}"

    # Step 1: Create docker-local.conf template if not exists
    echo "[!] Step 1: Creating docker-local template..."
    create_local_template
    
    # Step 2: Register dockerLocal vhTemplate in httpd_config.conf
    echo "[!] Step 2: Registering dockerLocal template..."
    register_local_template

    # Step 3: Find the Virtual Host name mapped to the domain
    echo "[!] Step 3: Searching for Virtual Host mapped to '${DOMAIN}'..."
    local vhost_name=$(docker compose exec -T ${CONT_NAME} bash -c "grep -B 2 'vhDomain.*${DOMAIN}' ${httpd_conf} | grep 'member' | awk '{print \$2}'" | tr -d '\r')

    if [ -z "${vhost_name}" ]; then
        echo "[X] No Virtual Host found for domain '${DOMAIN}' in ${httpd_conf}."
        echo "[!] Please add this domain to your environment first (e.g., using the 'domain' script)."
        exit 1
    fi
    echo "[O] Found Virtual Host member name: '${vhost_name}'"

    # Step 4: Copy certificate files into the container
    echo "[!] Step 4: Copying certificates to container..."
    docker compose exec -T ${CONT_NAME} bash -c "mkdir -p ${cert_container_path}"
    docker compose cp "${cert_host_path}/cert.pem" "${CONT_NAME}:${cert_container_path}/cert.pem"
    docker compose cp "${cert_host_path}/key.pem" "${CONT_NAME}:${cert_container_path}/key.pem"
    echo "[O] Certificates copied to: ${cert_container_path}"

    # Step 5: Move domain from old template (docker) to new template (dockerLocal)
    echo "[!] Step 5: Moving domain from 'docker' template to 'dockerLocal' template..."
    docker compose exec -T ${CONT_NAME} bash -c "
        # Backup httpd_config.conf
        cp ${httpd_conf} ${httpd_conf}.backup.\$(date +%Y%m%d_%H%M%S)
        
        # Find the member block for this vhost in 'docker' template
        sed -i '/^vhTemplate docker {/,/^}/ {
            /member ${vhost_name} {/,/}/d
        }' ${httpd_conf}
        
        # Add the member to 'dockerLocal' template
        # Find the last line of dockerLocal template and insert before it
        sed -i '/^vhTemplate dockerLocal {/,/^}/ {
            /^}/ i\  member ${vhost_name} {\n    vhDomain              ${DOMAIN},www.${DOMAIN}\n  }
        }' ${httpd_conf}
    "
    
    if [ ${?} = 0 ]; then
        echo -e "[O] Domain '\033[32m${DOMAIN}\033[0m' moved to 'dockerLocal' template"
        echo "[!] Restarting OpenLiteSpeed to apply changes..."
        lsws_restart
    else
        echo "[X] Failed to move domain to dockerLocal template"
        exit 1
    fi
    
    echo '[End] Configuring OpenLiteSpeed'
}

# Function to remove SSL certificate and revert configuration
remove_cert(){
    echo '[Start] Removing SSL certificate'
    
    local cert_host_path="${CERT_DIR}/${DOMAIN}"
    local lsws_conf_dir="/usr/local/lsws/conf"
    local httpd_conf="${lsws_conf_dir}/httpd_config.conf"
    local cert_container_path="${lsws_conf_dir}/cert/${DOMAIN}"
    
    # Step 1: Find Virtual Host name mapped to the domain
    echo "[!] Step 1: Finding Virtual Host for domain '${DOMAIN}'..."
    local vhost_name=$(docker compose exec -T ${CONT_NAME} bash -c "grep -B 2 'vhDomain.*${DOMAIN}' ${httpd_conf} | grep 'member' | awk '{print \$2}'" | tr -d '\r')
    
    if [ -z "${vhost_name}" ]; then
        echo "[!] No Virtual Host found for domain '${DOMAIN}' in dockerLocal template"
        echo "[!] Certificate may have already been removed or was never configured"
    else
        echo "[O] Found Virtual Host member name: '${vhost_name}'"
        
        # Step 2: Remove member from dockerLocal template
        echo "[!] Step 2: Removing domain from 'dockerLocal' template..."
        docker compose exec -T ${CONT_NAME} bash -c "
            # Backup httpd_config.conf
            cp ${httpd_conf} ${httpd_conf}.backup.\$(date +%Y%m%d_%H%M%S)
            
            # Remove the member block from dockerLocal template
            sed -i '/^vhTemplate dockerLocal {/,/^}/ {
                /member ${vhost_name} {/,/}/d
            }' ${httpd_conf}
            
            # Add the member back to 'docker' template (without SSL)
            sed -i '/^vhTemplate docker {/,/^}/ {
                /^}/ i\  member ${vhost_name} {\n    vhDomain              ${DOMAIN},www.${DOMAIN}\n  }
            }' ${httpd_conf}
        "
        
        if [ ${?} = 0 ]; then
            echo -e "[O] Domain '\033[32m${DOMAIN}\033[0m' moved back to 'docker' template"
        else
            echo "[X] Failed to move domain back to docker template"
        fi
    fi
    
    # Step 3: Remove certificate files from host
    echo "[!] Step 3: Removing certificate files from host..."
    if [ -d "${cert_host_path}" ]; then
        rm -rf "${cert_host_path}"
        echo -e "[O] Removed: ${cert_host_path}"
    else
        echo "[!] Certificate directory not found on host: ${cert_host_path}"
    fi
    
    # Step 4: Remove certificate files from container
    echo "[!] Step 4: Removing certificate files from container..."
    docker compose exec -T ${CONT_NAME} bash -c "
        if [ -d ${cert_container_path} ]; then
            rm -rf ${cert_container_path}
            echo '[O] Removed certificate directory from container: ${cert_container_path}'
        else
            echo '[!] Certificate directory not found in container'
        fi
    "
    
    # Step 5: Check if dockerLocal template is empty and remove if needed
    echo "[!] Step 5: Checking if dockerLocal template has any members..."
    local member_count=$(docker compose exec -T ${CONT_NAME} bash -c "grep -A 20 'vhTemplate dockerLocal' ${httpd_conf} | grep -c 'member'" | tr -d '\r')
    
    if [ "${member_count}" = "0" ]; then
        echo "[!] dockerLocal template has no members, removing template..."
        docker compose exec -T ${CONT_NAME} bash -c "
            sed -i '/^vhTemplate dockerLocal {/,/^}/d' ${httpd_conf}
        "
        echo "[O] Removed empty dockerLocal template"
        
        # Also remove docker-local.conf template file
        docker compose exec -T ${CONT_NAME} bash -c "
            if [ -f ${lsws_conf_dir}/templates/docker-local.conf ]; then
                rm ${lsws_conf_dir}/templates/docker-local.conf
                echo '[O] Removed docker-local.conf template file'
            fi
        "
    else
        echo "[i] dockerLocal template still has ${member_count} member(s), keeping template"
    fi
    
    # Step 6: Restart LiteSpeed
    echo "[!] Step 6: Restarting OpenLiteSpeed..."
    lsws_restart
    
    echo ""
    echo -e "\033[1m[SUCCESS] Certificate removed for domain: ${DOMAIN}\033[0m"
    echo ""
    echo '[End] Removing SSL certificate'
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

# Main function to orchestrate the script operations
main(){
    if [ "${INSTALL}" = 'true' ]; then
        install_mkcert
        exit 0
    fi

    domain_filter "${DOMAIN}"

    if [ "${REMOVE}" = 'true' ]; then
        remove_cert
        exit 0
    fi

    check_mkcert
    domain_verify "${DOMAIN}"
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
        *) 
            help_message
            ;;              
    esac
    shift
done

main