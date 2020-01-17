#!/usr/bin/env bash
DOMAIN=''
TYPE=0
CONT_NAME='litespeed'

help_message(){
    echo 'Command [your_domain]'
    echo 'Script will get database password and wordpress password from .env file and install the demo wordpress site for you'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
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
        echo "[OK] ${DOMAIN} is accessible."
        TYPE=1
        curl -Is http://${WWW_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ ${?} = 0 ]; then
            echo "[OK] ${WWW_DOMAIN} is accessible."
            TYPE=2
        else
            echo "${WWW_DOMAIN} is inaccessible." 
        fi
    else
        echo "${MY_DOMAIN} is inaccessible, please verify."; exit 1    
    fi
}

lecertapply(){
    if [ ${TYPE} = 1 ]; then
        docker-compose exec ${CONT_NAME} su -c "certbot certonly --agree-tos --register-unsafely-without-email \
            --non-interactive --webroot -w /var/www/vhosts/${1}/html -d ${1}"
    elif [ ${TYPE} = 2 ]; then
        docker-compose exec ${CONT_NAME} su -c "certbot certonly --agree-tos --register-unsafely-without-email \
            --non-interactive --webroot -w /var/www/vhosts/${1}/html -d ${1} -d www.${1}"
    else
        echo 'unknown Type!'
        exit 2
    fi          
}    

certbothook(){
    docker-compose exec ${CONT_NAME} su -s /bin/bash -c "certhookctl.sh"
}    

main(){
    www_domain ${1}
    domain_verify
    lecertapply ${DOMAIN}
    certbothook
    bash bin/webadmin.sh -r
}    

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        *) 
            main ${1}
            ;;              
    esac
    shift
done