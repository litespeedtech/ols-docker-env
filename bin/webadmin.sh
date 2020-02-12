#!/usr/bin/env bash
CONT_NAME='litespeed'

help_message(){
    echo 'Command [PASSWORD]'
    echo 'Example: webadmin.sh mypassword'
    echo 'Command [-r]'
    echo 'Example: webadmin.sh -r' 
    echo 'Will restart LiteSpeed Web Server'
    echo 'Command [-modsec] [enable|disable]'
    echo 'Example: webadmin -modsec enable'
    echo 'Command [-lsup]'
    echo 'Example: webadmin.sh -lsup'
    echo 'Will upgrade to latest stable version' 
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

mod_secure(){
    if [ "${1}" = 'enable' ] || [ "${1}" = 'Enable' ]; then
        docker-compose exec ${CONT_NAME} su -s /bin/bash root -c "owaspctl.sh -enable"
        lsws_restart
    elif [ "${1}" = 'disable' ] || [ "${1}" = 'Disable' ]; then
        docker-compose exec ${CONT_NAME} su -s /bin/bash root -c "owaspctl.sh -disable"
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
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c \
        'echo "admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php* -q /usr/local/lsws/admin/misc/htpasswd.php '${1}')" > /usr/local/lsws/admin/conf/htpasswd';
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
        -modsec | -sec| --sec) shift
            mod_secure ${1}
            ;;
        -lsup | -upgrade) shift
            ls_upgrade
            ;;            
        *) 
            main ${1}
            ;;              
    esac
    shift
done