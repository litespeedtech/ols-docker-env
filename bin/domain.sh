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
    echow "-A, --add [domain_name]"
    echo "${EPACE}${EPACE}Example: domain.sh -A example.com, will add the domain to Listener and auto create a new virtual host."
    echow "-D, --del [domain_name]"
    echo "${EPACE}${EPACE}Example: domain.sh -D example.com, will delete the domain from Listener."
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."    
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

add_domain(){
    check_input ${1}
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --add ${1}"
    if [ ! -d "./sites/${1}" ]; then 
        mkdir -p ./sites/${1}/{html,logs,certs}
    fi
    bash bin/webadmin.sh -r
}

del_domain(){
    check_input ${1}
    docker-compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --del ${1}"
    bash bin/webadmin.sh -r
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[aA] | -add | --add) shift
            add_domain ${1}
            ;;
        -[dD] | -del | --del | --delete) shift
            del_domain ${1}
            ;;          
        *) 
            help_message
            ;;              
    esac
    shift
done
          