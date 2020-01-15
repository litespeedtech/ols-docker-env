#!/usr/bin/env bash
APP_NAME=''
DOMAIN=''

help_message(){
    echo 'Command [-app app_name] [-domain domain_name]'
    echo 'Example: appinstall.sh -app wordpress -d example.com'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

app_download(){
    docker-compose exec litespeed su -c "appinstallctl.sh -app ${1} -domain ${2}"
    bash bin/webadmin.sh -r
    exit 0
}

main(){
    app_download ${APP_NAME} ${DOMAIN}
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -app | -a | -A) shift
            check_input "${1}"
            APP_NAME="${1}"
            ;;
        -d | -D | -domain) shift
            check_input "${1}"
            DOMAIN="${1}"
            ;;          
        *) 
            help_message
            ;;              
    esac
    shift
done

main