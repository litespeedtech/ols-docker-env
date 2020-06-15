#!/usr/bin/env bash
CONT_NAME='litespeed'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '[Enter Your PASSWORD]'
    echo "${EPACE}${EPACE}Example: webadmin.sh MY_SECURE_PASS, to update web admin password immediatly."
    echow '-R, --restart'
    echo "${EPACE}${EPACE}Will gracefully restart LiteSpeed Web Server."
    echow '-M, --mod-secure [enable|disable]'
    echo "${EPACE}${EPACE}Example: webadmin.sh -M enable, will enable and apply Mod_Secure OWASP rules on server"
    echow '-U, --upgrade'
    echo "${EPACE}${EPACE}Will upgrade web server to latest stable version"
    echow '-S, --serial [YOUR_SERIAL|TRIAL]'
    echo "${EPACE}${EPACE}Will apply your serial number to LiteSpeed Web Server."
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."
    exit 0
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

lsws_restart(){
    docker-compose exec ${CONT_NAME} su -c '/usr/local/lsws/bin/lswsctrl restart >/dev/null'
}

apply_serial(){
    docker-compose exec ${CONT_NAME} su -c "serialctl.sh --serial ${1}"
    lsws_restart
}

mod_secure(){
    if [ "${1}" = 'enable' ] || [ "${1}" = 'Enable' ]; then
        docker-compose exec ${CONT_NAME} su -s /bin/bash root -c "owaspctl.sh --enable"
        lsws_restart
    elif [ "${1}" = 'disable' ] || [ "${1}" = 'Disable' ]; then
        docker-compose exec ${CONT_NAME} su -s /bin/bash root -c "owaspctl.sh --disable"
        lsws_restart
    else
        help_message
    fi
}

ls_upgrade(){
    echo 'Upgrade web server to latest stable version.'
    docker-compose exec ${CONT_NAME} su -c '/usr/local/lsws/admin/misc/lsup.sh 2>/dev/null'
}

set_web_admin(){
    echo 'Update web admin password.'
    local LSADPATH='/usr/local/lsws/admin'
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c \
        'if [ -e /usr/local/lsws/admin/fcgi-bin/admin_php ]; then \
        echo "admin:$('${LSADPATH}'/fcgi-bin/admin_php -q '${LSADPATH}'/misc/htpasswd.php '${1}')" > '${LSADPATH}'/conf/htpasswd; \
        else echo "admin:$('${LSADPATH}'/fcgi-bin/admin_php5 -q '${LSADPATH}'/misc/htpasswd.php '${1}')" > '${LSADPATH}'/conf/htpasswd; \
        fi';
}

main(){
    set_web_admin ${1}
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[rR] | -restart | --restart)
            lsws_restart
            ;;
        -M | -mode-secure | --mod-secure) shift
            mod_secure ${1}
            ;;
        -lsup | --lsup | --upgrade | -U) shift
            ls_upgrade
            ;;
        -[sS] | -serial | --serial) shift
            apply_serial ${1}
            ;;             
        *) 
            main ${1}
            ;;              
    esac
    shift
done