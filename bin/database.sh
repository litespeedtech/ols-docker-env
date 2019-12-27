#!/usr/bin/env bash
source .env
echo "MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}"
DOMAIN=''
SQL_DB=''
SQL_USER=''
SQL_PASS=''
ANY='%'

help_message(){
    echo 'Command [-domain xxx]'
    echo 'Command [-user xxx] [-password xxx] [-database xxx]'
    echo 'Example 1: database.sh -domain example.com'
    echo 'Example 2: domain.sh -user USERNAME -password PASSWORD -database DATABASENAME'
    echo 'Script will auto assign database & username by the domain and random password for example 1'
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
    SQL_DB=${TRANSNAME}
    SQL_USER=${TRANSNAME}
    SQL_PASS=${RANDOM_PASS}
}

gen_pass(){
    RANDOM_PASS="$(openssl rand -base64 12)"
}

trans_name(){
    TRANSNAME=$(echo ${1} | tr -d '.&&-')
}

display_credential(){
    echo Database: ${SQL_DB}
    echo Username: ${SQL_USER}
    echo Password: ${SQL_PASS}
    exit 0
}

add_sql_client(){
    docker-compose exec mysql su -c 'apk add mysql-client'
}

check_db_access(){
    docker-compose exec mysql su -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e 'status'"
    if [ ${?} != 0 ]; then
        echo "DB access failed, please check!"
        exit 1
    fi    
}

db_setup(){  
    docker-compose exec mysql su -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} \
    -e 'CREATE DATABASE ${SQL_DB};' \
    -e 'GRANT ALL PRIVILEGES ON ${SQL_DB}.* TO ${SQL_USER}@${ANY} IDENTIFIED BY ${SQL_PASS};' \
    -e 'FLUSH PRIVILEGES;'"
}

auto_setup_main(){
    check_input ${DOMAIN}
    gen_pass
    trans_name ${DOMAIN}
    auto_name
    db_setup
    display_credential
}

specify_setup_main(){
    specify_name
    db_setup
    display_credential
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -d | -D | -domain) shift
            DOMAIN="${1}"
            ;;
        -u | -U | -user) shift
            SQL_USER="${1}"
            ;;
        -p | -P | -password) shift
            SQL_PASS="${1}"
            ;;            
        -db | -DB | -database) shift
            SQL_PDB="${1}"
            ;;            
        *) 
            help_message
            ;;              
    esac
    shift
done

if [ ${DOMAIN} = '' ]; then
    specify_setup_main
else
    auto_setup_main
fi
