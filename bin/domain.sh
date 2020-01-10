#!/usr/bin/env bash
CONT_NAME='litespeed'

help_message(){
    echo 'Command [-add|-del] [domain_name]'
    echo 'Example 1: domain.sh -add example.com'
    echo 'Example 2: domain.sh -del example.com'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

add_domain(){
    check_input ${1}
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh -add ${1}"
    if [ ! -d "./sites/${1}" ]; then 
        mkdir -p ./sites/${1}/{html,logs,certs}
    fi
    bash bin/webadmin.sh -r
}

del_domain(){
    check_input ${1}
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh -del ${1}"
    bash bin/webadmin.sh -r
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -add | -a | -A) shift
            add_domain ${1}
            ;;
        -del | -d | -D | -delete) shift
            del_domain ${1}
            ;;          
        *) 
            help_message
            ;;              
    esac
    shift
done
          