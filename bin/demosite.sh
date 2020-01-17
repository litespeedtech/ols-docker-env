#!/usr/bin/env bash
source .env
DEMO_VH='localhost'
APP_NAME='wordpress'
CONT_NAME='litespeed'
DEMO_PATH="/var/www/${DEMO_VH}"

help_message(){
    echo 'Script will get database password and wordpress password from .env file and install the demo wordpress site for you'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

store_credential(){
    if [ -d "./sites/${1}" ]; then
        if [ -f ./sites/${1}/.db_pass ]; then 
            mv ./sites/${1}/.db_pass ./sites/${1}/.db_pass.bk
        fi
        cat > "./sites/${1}/.db_pass" << EOT
"Database":"${MYSQL_DATABASE}"
"Username":"${MYSQL_USER}"
"Password":"$(echo ${MYSQL_PASSWORD} | tr -d "'")"
EOT
    else
        echo "./sites/${1} not found, abort credential store!"
    fi    
}

app_download(){
    docker-compose exec ${CONT_NAME} su -c "appinstallctl.sh -app ${1} -domain ${2} -vhname ${DEMO_VH}"
}

main(){
    store_credential ${DEMO_VH}
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