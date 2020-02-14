#!/usr/bin/env bash
DOMAIN=''
TYPE=0
CONT_NAME='litespeed'
NOMAIL='off'
EMAIL=''
DOC_ROOT=''

help_message(){
    case ${1} in
        "1")
        echo 'Command 1. [-domain DOMAIN_NAME] [-mail YOUR_MAIL]'
        echo 'Command 2. [-domain DOMAIN_NAME] [--no-mail]'
        echo 'Coomand 3. [-domain DOMAIN_NAME] [-mail YOUR_MAIL] [-doc DOCUMENT_ROOT_PATH]'
        echo 'Script will apply the Lets encrypt certificate for you'
        echo 'If you apply with --nomail, the script will then use --register-unsafely-without-email for you'
        echo 'Script will use /var/www/vhosts/DOMAIN_NAME/html as default document root unless you specify the doc path'
        ;;
        "2")
        echo 'Service finished, enjoy your accelarated LiteSpeed server!'
        ;;
    esac    
}

echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}

check_input(){
    if [ -z "${1}" ]; then
        help_message 1
        exit 1
    fi
}

domain_filter(){
    DOMAIN="${1}"
    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#ftp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#scp://}"
    DOMAIN="${DOMAIN#sftp://}"
    DOMAIN=${DOMAIN%%/*}
}

email_filter(){
    if [ "${NOMAIL}" = 'off' ]; then
        if [ "${EMAIL}" = '' ]; then
            help_message 1
            exit 1
        fi
        CKREG="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
        if [[ ${1} =~ ${CKREG} ]] ; then
            echo -e "[O] The E-mail you entered \033[32m${EMAIL}\033[0m is valid."
        else
            echo -e "[X] The E-mail you entered \e[31m${EMAIL}\e[39m is invalid"
            exit 1
        fi
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
        echo -e "[O] The domain you entered \033[32m${DOMAIN}\033[0m is accessible."
        TYPE=1
        curl -Is http://${WWW_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ ${?} = 0 ]; then
            echo -e "[O] The domain you entered \033[32m${WWW_DOMAIN}\033[0m is accessible."
            TYPE=2
        else
            echo -e "[!] The domain you entered ${WWW_DOMAIN} is inaccessible." 
        fi
    else
        echo -e "[X] The domain you entered \e[31m${DOMAIN}\e[39m is inaccessible, please verify."
        exit 1    
    fi
}

doc_root_verify(){
    if [ "${DOC_ROOT}" = '' ]; then
        DOC_PATH="/var/www/vhosts/${1}/html"
    else
        DOC_PATH="${DOC_ROOT}"    
    fi
    docker-compose exec ${CONT_NAME} su -c "[ -e ${DOC_PATH} ]"
    if [ ${?} -eq 0 ]; then
        echo -e "[O] The document root folder \033[32m${DOC_PATH}\033[0m is exit."
    else
        echo -e "[X] The document root folder you entered \e[31m${DOC_PATH}\e[39m is not exist!"
        exit 1
    fi
}

lecert_apply(){
    local TMP_MAIL
    if [ "${EMAIL}" != '' ]; then
        TMP_MAIL="-m ${EMAIL}"
    elif [ "${NOMAIL}" = 'on' ]; then
        TMP_MAIL='--register-unsafely-without-email'
    else
        echo 'unknown mail type!'
        exit 2            
    fi
    if [ ${TYPE} = 1 ]; then
        docker-compose exec ${CONT_NAME} su -c "certbot certonly --agree-tos ${TMP_MAIL} \
            --non-interactive --webroot -w ${DOC_PATH} -d ${1}"
    elif [ ${TYPE} = 2 ]; then
        docker-compose exec ${CONT_NAME} su -c "certbot certonly --agree-tos ${TMP_MAIL} \
            --non-interactive --webroot -w ${DOC_PATH} -d ${1} -d www.${1}"
    else
        echo 'unknown Type!'
        exit 2
    fi
    if [ ${?} -eq 0 ]; then
        echoG 'Certificate has been successfully installed'
    else
        echo 'Oops, something went wrong...'
        exit 1
    fi    
}    

certbot_hook(){
    echo 'Add certbot hook if not exist.'
    docker-compose exec ${CONT_NAME} su -s /bin/bash -c "certhookctl.sh"
}

lsws_restart(){
    docker-compose exec ${CONT_NAME} su -c '/usr/local/lsws/bin/lswsctrl restart >/dev/null'
}

main(){
    domain_filter ${DOMAIN}
    www_domain ${DOMAIN}
    domain_verify
    email_filter ${EMAIL}
    doc_root_verify ${DOMAIN}
    lecert_apply ${DOMAIN} ${EMAIL}
    certbot_hook
    lsws_restart
    help_message 2
}    

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message 1
            ;;
        -[dD] | -domain | --domain) shift
            check_input ${1}
            DOMAIN="${1}"
            ;;
        -[mM] | -mail | --mail) shift
            check_input ${1}
            EMAIL="${1}"
            ;;
        -no-mail | -nomail | --no-mail)
            NOMAIL='on'
            ;;
        -doc | -DOC | --doc) shift
            check_input ${1}
            DOC_ROOT="${1}"
            ;;
        *) 
            help_message 1
            exit 1
            ;;
    esac
    shift
done
main