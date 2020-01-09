#!/usr/bin/env bash
DOMAIN=''

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

strip_www(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        DOMAIN=$(echo ${1} | cut -c 5-)
    else
        DOMAIN=${1}    
    fi
}

lecertapply(){
    docker-compose exec litespeed su -c "certbot certonly --agree-tos --register-unsafely-without-email \
        --non-interactive --webroot -w /var/www/vhosts/${1}/html -d ${1} -d www.${1}"
}    

main(){
    strip_www ${1}
    lecertapply ${DOMAIN}
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


