#!/usr/bin/env bash

help_message(){
    echo 'Command [PASSWORD]'
    echo 'Example: webadmin.sh mypassword'
    echo 'Command [-r]'
    echo 'Example: webadmin.sh -r' 
    echo 'Will restart LiteSpeed Web Server'
    exit 0
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

set_web_admin(){
    docker-compose exec litespeed su -s /bin/bash lsadm -c \
        'echo "admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php* -q /usr/local/lsws/admin/misc/htpasswd.php '${1}')" > /usr/local/lsws/admin/conf/htpasswd';
}

lsws_restart(){
    docker-compose exec litespeed su -c '/usr/local/lsws/bin/lswsctrl restart'
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
        *) 
            main ${1}
            ;;              
    esac
    shift
done