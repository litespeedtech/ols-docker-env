#!/usr/bin/env bash
source .env
DEMO_VH='localhost'
APP_NAME='wordpress'
DEMO_PATH="/var/www/${DEMO_VH}"

help_message(){
    echo 'Command [-domain]'
    echo 'Script will get database password and wordpress password from .env file and install the demo wordpress site for you'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

run_database(){
    bash bin/database.sh -domain ${DEMO_VH} -user ${MYSQL_USER} -password ${MYSQL_PASSWORD} -database ${MYSQL_DATABASE}
}


app_download(){
    docker-compose exec litespeed su -c "appinstallctl.sh -app ${1} -domain ${2} -vhname localhost"
}

main(){
    run_database
    app_download ${APP_NAME} ${DOMAIN}
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        *) 
            help_message
            ;;              
    esac
    shift
done
main