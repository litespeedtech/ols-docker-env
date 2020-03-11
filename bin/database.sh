#!/usr/bin/env bash
source .env

DOMAIN=''
SQL_DB=''
SQL_USER=''
SQL_PASS=''
ANY="'%'"
SET_OK=0
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '-D, --domain [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Example: database.sh -D example.com"
    echo "${EPACE}${EPACE}Will auto generate Database/username/password for the domain"
    echow '-D, --domain [DOMAIN_NAME] -U, --user [xxx] -P, --password [xxx] -DB, --database [xxx]'
    echo "${EPACE}${EPACE}Example: database.sh -D example.com -U USERNAME -P PASSWORD -DB DATABASENAME"
    echo "${EPACE}${EPACE}Will create Database/username/password by given"
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."
    exit 0    
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

specify_name(){
    check_input ${SQL_USER}
    check_input ${SQL_PASS}
    check_input ${SQL_DB}
}

auto_name(){
    SQL_DB="${TRANSNAME}"
    SQL_USER="${TRANSNAME}"
    SQL_PASS="'${RANDOM_PASS}'"
}

gen_pass(){
    RANDOM_PASS="$(openssl rand -base64 12)"
}

trans_name(){
    TRANSNAME=$(echo ${1} | tr -d '.&&-')
}

display_credential(){
    if [ ${SET_OK} = 0 ]; then
        echo "Database: ${SQL_DB}"
        echo "Username: ${SQL_USER}"
        echo "Password: $(echo ${SQL_PASS} | tr -d "'")"
    fi    
}

store_credential(){
    if [ -d "./sites/${1}" ]; then
        if [ -f ./sites/${1}/.db_pass ]; then 
            mv ./sites/${1}/.db_pass ./sites/${1}/.db_pass.bk
        fi
        cat > "./sites/${1}/.db_pass" << EOT
"Database":"${SQL_DB}"
"Username":"${SQL_USER}"
"Password":"$(echo ${SQL_PASS} | tr -d "'")"
EOT
    else
        echo "./sites/${1} not found, abort credential store!"
    fi    
}

check_db_access(){
    docker-compose exec mysql su -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e 'status'" >/dev/null 2>&1
    if [ ${?} != 0 ]; then
        echo '[X] DB access failed, please check!'
        exit 1
    fi    
}

check_db_exist(){
    docker-compose exec mysql su -c "test -e /var/lib/mysql/${1}"
    if [ ${?} = 0 ]; then
        echo "Database ${1} already exist, skip DB creation!"
        exit 0    
    fi      
}

db_setup(){  
    docker-compose exec mysql su -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} \
    -e "CREATE DATABASE '${SQL_DB}';" \
    -e "GRANT ALL PRIVILEGES ON '${SQL_DB}'.* TO '${SQL_USER}'@'${ANY}' IDENTIFIED BY '${SQL_PASS}';" \
    -e "FLUSH PRIVILEGES;"'
    SET_OK=${?}
}

auto_setup_main(){
    check_input ${DOMAIN}
    gen_pass
    trans_name ${DOMAIN}
    auto_name
    check_db_exist ${SQL_DB}
    check_db_access
    db_setup
    display_credential
    store_credential ${DOMAIN}
}

specify_setup_main(){
    specify_name
    check_db_exist ${SQL_DB}
    check_db_access
    db_setup
    display_credential
    store_credential ${DOMAIN}
}

main(){
    if [ "${SQL_USER}" != '' ] && [ "${SQL_PASS}" != '' ] && [ "${SQL_DB}" != '' ]; then
        specify_setup_main
    else
        auto_setup_main
    fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[dD] | -domain| --domain) shift
            DOMAIN="${1}"
            ;;
        -[uU] | -user | --user) shift
            SQL_USER="${1}"
            ;;
        -[pP] | -password| --password) shift
            SQL_PASS="'${1}'"
            ;;            
        -db | -DB | -database| --database) shift
            SQL_DB="${1}"
            ;;            
        *) 
            help_message
            ;;              
    esac
    shift
done
main
