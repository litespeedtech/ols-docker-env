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

CONT_NAME='litespeed'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mUSAGE\033[0m"
    echo "${EPACE}webadmin.sh [OPTIONS]"
    echo ""
    echo -e "\033[1mOPTIONS\033[0m"
    echow '[PASSWORD]'         
    echo "${EPACE}${EPACE}Example: webadmin.sh MY_SECURE_PASS"
    echow '-R, --restart'
    echo "${EPACE}${EPACE}Gracefully restart LiteSpeed Web Server"
    echow '-M, --mod-secure [enable|disable]'
    echo "${EPACE}${EPACE}Enable/disable Mod_Secure OWASP rules"
    echow '-U, --upgrade'
    echo "${EPACE}${EPACE}Upgrade to latest stable version"
    echow '-S, --serial [SERIAL|TRIAL]'
    echo "${EPACE}${EPACE}Apply LiteSpeed license serial"
    echow '-H, --help'
    exit 0
}

lsws_restart(){
    echow "🔄 Restarting LiteSpeed..."
    ${COMPOSE_CMD} exec -T "${CONT_NAME}" su -c '/usr/local/lsws/bin/lswsctrl restart' || {
        echow "❌ Restart failed!"
        exit 1
    }
    echow "✅ LiteSpeed restarted"
}

apply_serial(){
    local serial=${1}
    [[ -z "$serial" ]] && { echow "❌ Serial required!"; help_message; }
    echow "🔑 Applying serial: ${serial}..."
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -c "serialctl.sh --serial '${serial}'" || {
        echow "❌ Serial application failed!"
        exit 1
    }
    lsws_restart
}

mod_secure(){
    local action=${1}
    case "${action,,}" in
        enable)
            echow "🛡️  Enabling Mod_Secure OWASP..."
            ${COMPOSE_CMD} exec "${CONT_NAME}" su -s /bin/bash root -c "owaspctl.sh --enable" || {
                echow "❌ Mod_Secure enable failed!"
                exit 1
            }
            lsws_restart
            ;;
        disable)
            echow "🔓 Disabling Mod_Secure..."
            ${COMPOSE_CMD} exec "${CONT_NAME}" su -s /bin/bash root -c "owaspctl.sh --disable" || {
                echow "❌ Mod_Secure disable failed!"
                exit 1
            }
            lsws_restart
            ;;
        *)
            echow "❌ Invalid action: ${action} (use enable/disable)"
            help_message
            ;;
    esac
}

ls_upgrade(){
    echow "🔄 Upgrading LiteSpeed to latest stable..."
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -c '/usr/local/lsws/admin/misc/lsup.sh' || {
        echow "❌ Upgrade failed!"
        exit 1
    }
    lsws_restart
    echow "✅ Upgrade complete"
}

set_web_admin(){
    local password=${1}
    [[ -z "$password" ]] && { echow "❌ Password required!"; help_message; }
    echow "🔐 Setting admin password..."
    local LSADPATH='/usr/local/lsws/admin'
    ${COMPOSE_CMD} exec "${CONT_NAME}" su -s /bin/bash lsadm -c "
        if [ -e ${LSADPATH}/fcgi-bin/admin_php ]; then
            echo \"admin:\$($(printf %q \"${LSADPATH}\"/fcgi-bin/admin_php) -q '$(printf %q \"${LSADPATH}\"/misc/htpasswd.php)' '$(printf %q \"${password}\")')\"
        else
            echo \"admin:\$($(printf %q \"${LSADPATH}\"/fcgi-bin/admin_php5) -q '$(printf %q \"${LSADPATH}\"/misc/htpasswd.php)' '$(printf %q \"${password}\")')\"
        fi > ${LSADPATH}/conf/htpasswd
    " || {
        echow "❌ Admin password update failed!"
        exit 1
    }
    echow "✅ Admin password updated"
}

# Parse arguments properly
while [[ $# -gt 0 ]]; do
    case ${1} in
        -[hH]*|--help|help)
            help_message
            ;;
        -[rR]*|--restart)
            lsws_restart
            exit 0
            ;;
        -[mM]*|--mod-secure)
            shift
            mod_secure "$1"
            exit 0
            ;;
        -[uU]*|--upgrade)
            ls_upgrade
            exit 0
            ;;
        -[sS]*|--serial)
            shift
            apply_serial "$1"
            exit 0
            ;;
        *)
            # Password as positional argument
            set_web_admin "$1"
            exit 0
            ;;
    esac
    shift
done

echow "❌ No action specified!"
help_message
