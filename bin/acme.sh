#!/usr/bin/env bash
EMAIL=''
DOMAIN=''
INSTALL=''
UNINSTALL=''
CONT_NAME='litespeed'
EPACE='        '
RENEW=''
RENEW_ALL=''
FORCE=''
REVOKE=''
REMOVE=''
LSDIR='/usr/local/lsws'
HTTPD_CONF="${LSDIR}/conf/httpd_config.conf"
ACME_HOME="${LSDIR}/acme"
ACME_CONF="${LSDIR}/conf/cert/acme"
ERROR_LOG="${LSDIR}/logs/error.log"
TEMPLATE_NAME='dockerAcme'
TEMPLATE_FILE='conf/templates/docker-acme.conf'
WAIT_SECS=180

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    case ${1} in
    "1")    
        echo 'You will need to install ACME the first time.'
        echo 'Please run acme.sh --install --email example@example.com'
        ;;
    "2")
        echo -e "\033[1mOPTIONS\033[0m" 
        echow '-D, --domain [DOMAIN_NAME]'         
        echo "${EPACE}${EPACE}Example: acme.sh --domain example.com"
        echo "${EPACE}${EPACE}OpenLiteSpeed will apply for example.com, and include www.example.com when it is reachable."
        echow '-H, --help'
        echo "${EPACE}${EPACE}Display help and exit."
        echo -e "\033[1m   Only for the First time\033[0m"
        echow '--install --email [EMAIL_ADDR]'
        echo "${EPACE}${EPACE}Will install OpenLiteSpeed ACME support with the Email provided"       
        echow '-r, --renew'
        echo "${EPACE}${EPACE}Renew a specific domain with -D or --domain parameter if it is due. To force renew, use -f parameter."
        echow '-R, --renew-all'
        echo "${EPACE}${EPACE}Renew all domains if they are due. To force renew, use -f parameter."
        echow '-f, -F, --force'
        echo "${EPACE}${EPACE}Force renew for a specific domain or all domains."
        echow '-v, --revoke'
        echo "${EPACE}${EPACE}Revoke the certificate of a domain and stop using ACME for it."
        echow '-V, --remove'
        echo "${EPACE}${EPACE}Stop using ACME for a domain. OpenLiteSpeed deletes its certificate."
        echow '-U, --uninstall'
        echo "${EPACE}${EPACE}Stop using ACME for all domains and uninstall OpenLiteSpeed ACME support."
        exit 0
        ;;
    "3")
        echo 'Please run acme.sh --domain [DOMAIN_NAME] to apply certificate'
        exit 0
        ;;
    esac
}

check_input(){
    if [ -z "${1}" ]; then
        help_message 2
    fi
}

domain_filter(){
    if [ -z "${1}" ]; then
        help_message 3
    fi
    DOMAIN="${1}"
    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#sftp://}"
    DOMAIN=${DOMAIN%%/*}
    validate_domain "${DOMAIN}"
}

validate_domain(){
    if ! echo "${1}" | grep -Eq '^(localhost|([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})$'; then
        echo -e "[X] Invalid domain name: \e[31m${1}\e[39m. Abort!"
        exit 1
    fi
}

email_filter(){
    local EMAIL_CLEAN="${1}"

    # Hard limits: non-empty, <=254 chars (RFC 5321), and not starting with '-'
    # (prevents argument injection into acme.sh, e.g. --email=--foo).
    if [ -z "${EMAIL_CLEAN}" ] || [ "${#EMAIL_CLEAN}" -gt 254 ] || [ "${EMAIL_CLEAN:0:1}" = '-' ]; then
        echo -e "[X] The E-mail \e[31m${EMAIL_CLEAN}\e[39m is invalid"
        exit 1
    fi

    CKREG='^[A-Za-z0-9._%+-]+@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$'

    if [[ "${EMAIL_CLEAN}" =~ ${CKREG} ]]; then
        echo -e "[O] The E-mail \033[32m${EMAIL_CLEAN}\033[0m is valid."
    else
        echo -e "[X] The E-mail \e[31m${EMAIL_CLEAN}\e[39m is invalid"
        exit 1
    fi
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

domain_verify(){
    curl -Is http://${DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
    if [ ${?} = 0 ]; then
        echo -e "[O] The domain name \033[32m${DOMAIN}\033[0m is accessible."
        curl -Is http://${WWW_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ ${?} = 0 ]; then
            echo -e "[O] The domain name \033[32m${WWW_DOMAIN}\033[0m is accessible."
        else
            echo -e "[!] The domain name ${WWW_DOMAIN} is inaccessible, OpenLiteSpeed will leave it out if its own check fails too."
        fi
    else
        echo -e "[X] The domain name \e[31m${DOMAIN}\e[39m is inaccessible, please verify."
        exit 1    
    fi
}

container_id(){
    CONT_ID=$(docker compose ps -q ${CONT_NAME} 2>/dev/null)
    if [ -z "${CONT_ID}" ]; then
        echo "[X] The ${CONT_NAME} container is not running, please run docker compose up -d first."
        exit 1
    fi
}

mount_source(){
    docker inspect -f "{{range .Mounts}}{{if eq .Destination \"${1}\"}}{{.Source}}{{end}}{{end}}" ${CONT_ID}
}

# Prints the stat(1) format ${1} of the container file ${2}, or ${3} if it is missing.
file_stat(){
    docker compose exec -T ${CONT_NAME} sh -c 'stat -c "${1}" "${2}" 2>/dev/null || echo "${3}"' sh "${1}" "${2}" "${3}"
}

lsws_restart(){
    docker compose exec -T ${CONT_NAME} su -c "${LSDIR}/bin/lswsctrl restart >/dev/null"
    if [ ${?} = 0 ]; then
        echo '[O] OpenLiteSpeed restarted.'
    else
        echo '[X] OpenLiteSpeed restart failed.'
    fi
}

acme_installed(){
    docker compose exec -T ${CONT_NAME} test -f ${ACME_HOME}/acme.sh -a -f ${ACME_CONF}/server.conf
}

require_acme(){
    if ! acme_installed; then
        help_message 1
        exit 1
    fi
}

install_acme(){
    echo '[Start] Install ACME'
    if [ -z "${1}" ]; then
        help_message 1
        exit 1
    fi
    email_filter "${1}"
    if ! docker compose exec -T ${CONT_NAME} test -f ${LSDIR}/admin/misc/install_acme.sh; then
        echo '[X] This OpenLiteSpeed image has no ACME support, please update OLS_VERSION in .env.'
        exit 1
    fi
    CONF_SRC=$(mount_source ${LSDIR}/conf)
    ACME_SRC=$(mount_source ${ACME_HOME})
    if [ -z "${CONF_SRC}" ] || [ -z "${ACME_SRC}" ]; then
        echo "[X] ${ACME_HOME} is not mounted in the ${CONT_NAME} container."
        echo "[!] Add ./lsws/acme:${ACME_HOME} to its volumes in docker-compose.yml and run docker compose up -d"
        exit 1
    fi
    IMAGE_ID=$(docker inspect -f '{{.Image}}' ${CONT_ID})
    # install_acme.sh does nothing when ${ACME_HOME} exists, and in the litespeed
    # container it is always a mount point. Run it in a throwaway container of
    # the same image that shares the conf volume, then copy the result into
    # the acme volume.
    docker run --rm -i -e ACME_EMAIL="${1}" \
        -v "${CONF_SRC}:${LSDIR}/conf" -v "${ACME_SRC}:/acme-volume" \
        --entrypoint /bin/bash ${IMAGE_ID} -s <<'EOF'
set -e
if ! command -v git >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends git >/dev/null
fi
mkdir -p /usr/local/lsws/conf/cert/acme
bash /usr/local/lsws/admin/misc/install_acme.sh -e "${ACME_EMAIL}"
test -f /usr/local/lsws/acme/acme.sh
test -f /usr/local/lsws/conf/cert/acme/server.conf
grep -q acmeThumbPrint /usr/local/lsws/conf/httpd_config.conf
cp -a /usr/local/lsws/acme/. /acme-volume/
chown lsadm:lsadm /acme-volume
EOF
    if [ ${?} != 0 ]; then
        echo '[X] ACME installation failed, please check the messages above.'
        exit 1
    fi
    echo '[O] ACME installed.'
    lsws_restart
    echo '[End] Install ACME'
}

uninstall_acme(){
    echo '[Start] Uninstall ACME'
    for MEMBER in $(template_members ${TEMPLATE_NAME}); do
        if move_member "${MEMBER}" ${TEMPLATE_NAME} docker; then
            echo -e "[O] Domain '\033[32m${MEMBER}\033[0m' moved back to 'docker' template"
        else
            echo "[X] Failed to move ${MEMBER} back to docker template"
            exit 1
        fi
    done
    docker compose exec -T ${CONT_NAME} bash -s -- "${HTTPD_CONF}" "${TEMPLATE_NAME}" "${LSDIR}/${TEMPLATE_FILE}" <<'EOF'
if grep -q "^vhTemplate ${2} {" "${1}"; then
    cp "${1}" "${1}.backup.$(date +%Y%m%d_%H%M%S)"
    awk -v tpl="${2}" '
        $1 == "vhTemplate" && $2 == tpl && $3 == "{" {skip = 1}
        !skip {print}
        skip && /^}/ {skip = 0}
    ' "${1}" > "${1}.tmp" && cat "${1}.tmp" > "${1}"
    rm -f "${1}.tmp"
    echo "[O] Template ${2} removed."
fi
rm -f "${3}"
EOF
    if acme_installed; then
        CONF_SRC=$(mount_source ${LSDIR}/conf)
        ACME_SRC=$(mount_source ${ACME_HOME})
        IMAGE_ID=$(docker inspect -f '{{.Image}}' ${CONT_ID})
        # uninstall_acme.sh runs acme.sh --uninstall, which also removes root's
        # acme.sh cron job and ~/.acme.sh/acme.sh, so keep it away from the
        # litespeed container's /root/.acme.sh.
        docker run --rm -i -v "${CONF_SRC}:${LSDIR}/conf" -v "${ACME_SRC}:${ACME_HOME}" \
            --entrypoint /bin/bash ${IMAGE_ID} -s <<'EOF' 2>&1 | grep -v 'Device or resource busy'
bash /usr/local/lsws/admin/misc/uninstall_acme.sh
EOF
    else
        echo '[i] ACME is not installed.'
    fi
    lsws_restart
    echo '[End] Uninstall ACME'
}

check_acme(){
    echo '[Start] Checking ACME'
    if ! acme_installed; then
        install_acme "${EMAIL}"
        if [ -z "${DOMAIN}" ]; then
            help_message 3
        fi
    elif [ "${INSTALL}" = 'true' ] && [ -z "${DOMAIN}" ]; then
        echo '[i] ACME is already installed.'
        help_message 3
    fi
    echo '[End] Checking ACME'
}

check_server_acme(){
    if docker compose exec -T ${CONT_NAME} grep -Eq '^[[:space:]]*acme[[:space:]]+0[[:space:]]*$' ${HTTPD_CONF}; then
        echo "[X] ACME is disabled for the whole server (acme 0 in ${HTTPD_CONF})."
        exit 1
    fi
}

# Sets MEMBER_TPL to the template holding the member named ${1} and CERT_DOMAIN
# to its first vhDomain entry, which OpenLiteSpeed names the certificate after.
find_member(){
    read -r MEMBER_TPL CERT_DOMAIN <<< "$(docker compose exec -T ${CONT_NAME} awk -v name="${1}" '
        $1 == "vhTemplate" && $3 == "{" {tpl = $2; next}
        /^}/ {tpl = ""; next}
        tpl != "" && $1 == "member" && $2 == name && $3 == "{" {found = tpl; next}
        found != "" && $1 == "vhDomain" {sub(/,.*/, "", $2); print found, $2; exit}
        found != "" && $1 == "}" {print found, name; exit}
    ' ${HTTPD_CONF})"
    if [ -n "${CERT_DOMAIN}" ] && [ "${CERT_DOMAIN}" != "${1}" ]; then
        validate_domain "${CERT_DOMAIN}"
        echo "[i] The certificate of ${1} is named after its first vhDomain entry: ${CERT_DOMAIN}"
    fi
    CERT_FILE="${ACME_CONF}/certs/${CERT_DOMAIN}_ecc/fullchain.cer"
}

template_members(){
    docker compose exec -T ${CONT_NAME} awk -v tpl="${1}" '
        $1 == "vhTemplate" && $3 == "{" {cur = $2; next}
        /^}/ {cur = ""; next}
        cur == tpl && $1 == "member" && $3 == "{" {print $2}
    ' ${HTTPD_CONF}
}

# Moves the member block ${1} verbatim from template ${2} to template ${3}.
move_member(){
    docker compose exec -T ${CONT_NAME} bash -s -- "${1}" "${2}" "${3}" "${HTTPD_CONF}" <<'EOF'
cp "${4}" "${4}.backup.$(date +%Y%m%d_%H%M%S)"
awk -v name="${1}" -v from="${2}" -v to="${3}" '
    {line[NR] = $0}
    $1 == "vhTemplate" && $3 == "{" {tpl = $2; next}
    /^}/ {if (tpl == to) last = NR; tpl = ""; next}
    tpl == from && $1 == "member" && $2 == name && $3 == "{" {first = NR; inside = 1; next}
    inside && $1 == "}" {stop = NR; inside = 0}
    END {
        if (!first || !stop || !last)
            exit 1
        for (i = 1; i <= NR; i++) {
            if (i == last)
                for (j = first; j <= stop; j++)
                    print line[j]
            if (i < first || i > stop)
                print line[i]
        }
    }
' "${4}" > "${4}.tmp" && cat "${4}.tmp" > "${4}"
RC=${?}
rm -f "${4}.tmp"
exit ${RC}
EOF
}

create_acme_template(){
    echo '[Start] Creating docker-acme.conf template'
    docker compose exec -T ${CONT_NAME} bash -s -- "${LSDIR}/conf/templates/docker.conf" "${LSDIR}/${TEMPLATE_FILE}" <<'EOF'
if [ -f "${2}" ]; then
    echo "[i] Template file already exists: ${2}"
    exit 0
fi
# Copy docker.conf without its vhssl block and closing brace, then let
# OpenLiteSpeed ACME provide the certificate.
awk '
    /^  vhssl  {/ {skip = 1}
    skip {if (/^  }/) skip = 0; next}
    {line[++n] = $0}
    END {
        while (n && line[n] !~ /^}/)
            n--
        if (!n)
            exit 1
        for (i = 1; i < n; i++)
            print line[i]
    }
' "${1}" > "${2}.tmp"
cat >> "${2}.tmp" <<'VHSSL_EOF'
  vhssl  {
    acme  {
      enabled             2
    }
  }
}
VHSSL_EOF
if [ ! -s "${2}.tmp" ] || grep -Eq '^[[:space:]]*(keyFile|certFile)[[:space:]]' "${2}.tmp"; then
    echo "[X] Unable to create ${2} from ${1}"
    rm -f "${2}.tmp"
    exit 1
fi
mv "${2}.tmp" "${2}"
chown lsadm:lsadm "${2}"
chmod 644 "${2}"
echo "[O] Template ${2} created."
EOF
    if [ ${?} != 0 ]; then
        exit 1
    fi
    echo '[End] Creating docker-acme.conf template'
}

register_acme_template(){
    echo "[Start] Registering vhTemplate: ${TEMPLATE_NAME}"
    docker compose exec -T ${CONT_NAME} bash -s -- "${HTTPD_CONF}" "${TEMPLATE_NAME}" "${TEMPLATE_FILE}" <<'EOF'
if grep -q "^vhTemplate ${2} {" "${1}"; then
    echo "[i] Template ${2} already exists, skipped."
    exit 0
fi
cp "${1}" "${1}.backup.$(date +%Y%m%d_%H%M%S)"
cat >> "${1}" <<TPL_EOF

vhTemplate ${2} {
  templateFile            ${3}
  listeners               HTTP, HTTPS
  note                    ${2}
}
TPL_EOF
echo "[O] Template ${2} registered."
EOF
    echo '[End] Registering vhTemplate complete.'
}

show_cert(){
    docker compose exec -T ${CONT_NAME} openssl x509 -noout -enddate -ext subjectAltName -in "${CERT_FILE}" | sed "s/^ */${EPACE}/"
}

# Waits for OpenLiteSpeed to finish the certificate requests started by a
# restart. Returns 0 if the certificate was replaced, 1 if the request failed
# and 2 on timeout, printing the related [ACME] log lines for the last two.
wait_cert(){
    docker compose exec -T ${CONT_NAME} bash -s -- "${CERT_DOMAIN}" "${CERT_FILE}" "${CERT_MTIME}" "${ERROR_LOG}" "${LOG_SIZE}" "${WAIT_SECS}" <<'EOF'
DOMAIN_RE=$(echo "${1}" | sed 's/\./\\./g')
END_TIME=$(( $(date +%s) + ${6} ))
SIZE=${5}
RC=2
while [ $(date +%s) -lt ${END_TIME} ]; do
    sleep 5
    if [ $(stat -c %s "${4}" 2>/dev/null || echo 0) -lt ${SIZE} ]; then
        SIZE=0
    fi
    NEW=$(tail -c +$((SIZE + 1)) "${4}" 2>/dev/null | grep '\[ACME\]')
    if echo "${NEW}" | grep -q 'certs succeeded'; then
        if [ "$(stat -c %Y "${2}" 2>/dev/null || echo none)" != "${3}" ]; then
            exit 0
        fi
        RC=1
        break
    fi
    if echo "${NEW}" | grep -Eq "Could not validate domain: ${DOMAIN_RE}[ .]"; then
        RC=1
        break
    fi
done
echo "${NEW}" | grep -E "${DOMAIN_RE}|certs succeeded" | tail -n 20
exit ${RC}
EOF
}

# Waits for OpenLiteSpeed to serve the certificate in CERT_FILE for ${1}.
cert_served(){
    docker compose exec -T ${CONT_NAME} bash -s -- "${1}" "${CERT_FILE}" <<'EOF'
WANT=$(openssl x509 -noout -fingerprint -sha256 -in "${2}" 2>/dev/null)
for i in $(seq 1 12); do
    GOT=$(echo | timeout 10 openssl s_client -connect 127.0.0.1:443 -servername "${1}" 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
    if [ -n "${WANT}" ] && [ "${WANT}" = "${GOT}" ]; then
        exit 0
    fi
    sleep 5
done
exit 1
EOF
}

check_served(){
    if cert_served "${1}"; then
        echo -e "[O] OpenLiteSpeed is serving the certificate for \033[32m${1}\033[0m."
        return 0
    fi
    echo '[!] OpenLiteSpeed is not serving the new certificate yet, restarting it again.'
    lsws_restart
    if cert_served "${1}"; then
        echo -e "[O] OpenLiteSpeed is serving the certificate for \033[32m${1}\033[0m."
    else
        echo "[X] OpenLiteSpeed is still not serving the new certificate for ${1}, please check ${ERROR_LOG}."
    fi
}

acme_cmd(){
    SERVER=$(docker compose exec -T ${CONT_NAME} head -n 1 ${ACME_CONF}/server.conf)
    # The same environment OpenLiteSpeed gives acme.sh, as the same user.
    docker compose exec -T -u lsadm ${CONT_NAME} env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        LE_CONFIG_HOME=${ACME_CONF}/data LE_WORKING_DIR=${ACME_HOME} ACME_DIRECTORY="${SERVER}" \
        ${ACME_HOME}/acme.sh "${@}" --server "${SERVER}"
}

require_acme_member(){
    find_member "${1}"
    if [ "${MEMBER_TPL}" != "${TEMPLATE_NAME}" ]; then
        echo -e "[X] The domain \e[31m${1}\e[39m does not use ACME, please run acme.sh --domain ${1} first."
        exit 1
    fi
}

apply_cert(){
    echo '[Start] Apply Lets Encrypt Certificate'
    if [ "${1}" = 'localhost' ]; then
        echo "[X] Let's Encrypt does not issue certificates for localhost."
        exit 1
    fi
    find_member "${1}"
    case "${MEMBER_TPL}" in
    "${TEMPLATE_NAME}")
        if docker compose exec -T ${CONT_NAME} test -f "${CERT_FILE}"; then
            echo -e "[O] The domain \033[32m${1}\033[0m already uses ACME:"
            show_cert
            echo "[!] To renew it, run acme.sh --renew --domain ${1} [--force]"
            echo '[End] Apply Lets Encrypt Certificate'
            return 0
        fi
        echo "[!] The domain ${1} is in the ${TEMPLATE_NAME} template but has no certificate yet, retrying."
        ;;
    docker)
        create_acme_template
        register_acme_template
        ;;
    '')
        echo -e "[X] No virtual host member named \e[31m${1}\e[39m was found in ${HTTPD_CONF}."
        echo "[!] Please add the domain first: bash bin/domain.sh --add ${1}"
        exit 1
        ;;
    *)
        echo -e "[X] The domain \e[31m${1}\e[39m is in the ${MEMBER_TPL} template, which sets its own certificate."
        if [ "${MEMBER_TPL}" = 'dockerLocal' ]; then
            echo "[!] Please run bash bin/mkcert.sh --remove --domain ${1} first."
        fi
        exit 1
        ;;
    esac

    CERT_MTIME=$(file_stat %Y "${CERT_FILE}" none)
    LOG_SIZE=$(file_stat %s "${ERROR_LOG}" 0)
    if [ "${MEMBER_TPL}" = 'docker' ]; then
        if move_member "${1}" docker ${TEMPLATE_NAME}; then
            echo -e "[O] Domain '\033[32m${1}\033[0m' moved to '${TEMPLATE_NAME}' template"
        else
            echo "[X] Failed to move domain to ${TEMPLATE_NAME} template"
            exit 1
        fi
    fi
    echo "[!] Restarting OpenLiteSpeed, it will request the certificate. This can take a few minutes."
    lsws_restart
    wait_cert
    case ${?} in
    0)
        echo -e "[O] The certificate for \033[32m${CERT_DOMAIN}\033[0m was issued:"
        show_cert
        check_served "${CERT_DOMAIN}"
        ;;
    1)
        echo -e "[X] The certificate for \e[31m${CERT_DOMAIN}\e[39m was not issued, see the log lines above."
        echo "[!] Please check the DNS and that port 80 reaches this server, then run this command again."
        echo "[!] To go back to the docker template, run acme.sh --remove --domain ${1}"
        ;;
    *)
        echo "[!] OpenLiteSpeed has not finished after ${WAIT_SECS} seconds, please check ${ERROR_LOG}."
        ;;
    esac
    echo '[End] Apply Lets Encrypt Certificate'
}

renew_acme(){
    echo '[Start] Renew ACME'
    require_acme_member "${1}"
    if [ "${FORCE}" = 'true' ]; then
        acme_cmd --renew -d "${CERT_DOMAIN}" --stateless --force
    else
        acme_cmd --renew -d "${CERT_DOMAIN}" --stateless
    fi
    case ${?} in
    0)
        echo '[O] The certificate was renewed.'
        lsws_restart
        show_cert
        check_served "${CERT_DOMAIN}"
        ;;
    2)
        echo '[i] The certificate is not due for renewal yet. To force renew, use -f parameter.'
        ;;
    *)
        echo '[X] The renewal failed, please check the messages above.'
        ;;
    esac
    echo '[End] Renew ACME'
}

renew_all_acme(){
    echo '[Start] Renew all ACME'
    if [ "${FORCE}" = 'true' ]; then
        acme_cmd --renew-all --force
    else
        acme_cmd --renew-all
    fi
    echo '[End] Renew all ACME'
    lsws_restart
}

revoke(){
    echo '[Start] Revoke a domain'
    require_acme_member "${1}"
    if ! acme_cmd --revoke -d "${CERT_DOMAIN}"; then
        echo '[X] The revoke failed, please check the messages above.'
        exit 1
    fi
    if move_member "${1}" ${TEMPLATE_NAME} docker; then
        echo -e "[O] Domain '\033[32m${1}\033[0m' moved back to 'docker' template"
    else
        echo "[X] Failed to move domain back to docker template"
        exit 1
    fi
    # OpenLiteSpeed deletes certificates that are no longer used when it starts.
    lsws_restart
    echo '[End] Revoke a domain'
}

remove(){
    echo '[Start] Remove a domain'
    require_acme_member "${1}"
    if move_member "${1}" ${TEMPLATE_NAME} docker; then
        echo -e "[O] Domain '\033[32m${1}\033[0m' moved back to 'docker' template"
    else
        echo "[X] Failed to move domain back to docker template"
        exit 1
    fi
    # OpenLiteSpeed revokes and deletes certificates that are no longer used
    # when it starts.
    lsws_restart
    echo '[End] Remove a domain'
}

main(){
    container_id
    if [ "${UNINSTALL}" = 'true' ]; then
        uninstall_acme
        exit 0
    elif [ "${RENEW_ALL}" = 'true' ]; then
        require_acme
        renew_all_acme
        exit 0
    elif [ "${RENEW}" = 'true' ]; then
        require_acme
        domain_filter "${DOMAIN}"
        www_domain "${DOMAIN}"
        renew_acme "${DOMAIN}"
        exit 0
    elif [ "${REVOKE}" = 'true' ]; then
        require_acme
        domain_filter "${DOMAIN}"
        www_domain "${DOMAIN}"
        revoke "${DOMAIN}"
        exit 0
    elif [ "${REMOVE}" = 'true' ]; then
        require_acme
        domain_filter "${DOMAIN}"
        www_domain "${DOMAIN}"
        remove "${DOMAIN}"
        exit 0
    fi

    check_acme
    domain_filter "${DOMAIN}"
    www_domain "${DOMAIN}"
    check_server_acme
    domain_verify
    apply_cert "${DOMAIN}"
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message 2
            ;;
        -[dD] | -domain | --domain) shift
            check_input "${1}"
            DOMAIN="${1}"
            ;;
        -[iI] | --install ) 
            INSTALL=true
            ;;
        -[uU] | --uninstall )
            UNINSTALL=true
            ;;
        -[fF] | --force ) 
            FORCE=true
            ;;
        -[r] | --renew )
            RENEW=true
            ;;
        -[R] | --renew-all )
            RENEW_ALL=true
            ;;
        -[v] | --revoke )
            REVOKE=true
            ;;
        -[V] | --remove )
            REMOVE=true
            ;;
        -[eE] | --email ) shift
            check_input "${1}"
            EMAIL="${1}"
            ;;           
        *) 
            help_message 2
            ;;              
    esac
    shift
done

main
