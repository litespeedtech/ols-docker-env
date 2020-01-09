#!/usr/bin/env bash
source .env

DOMAIN=''
SQL_DB=''
SQL_USER=''
SQL_PASS=''
ANY="'%'"
SET_OK=0

help_message(){
    echo 'Command [-domain xxx]'
    echo 'Command [-domain xxx] [-user xxx] [-password xxx] [-database xxx]'
    echo 'Example 1: database.sh -domain example.com'
    echo 'Example 2: database.sh -domain example.com -user USERNAME -password PASSWORD -database DATABASENAME'
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

add_sql_client(){
    docker-compose exec mysql su -c 'apk add mysql-client'
}

check_db_access(){
    #add_sql_client
    docker-compose exec mysql su -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e 'status'" >/dev/null 2>&1
    if [ ${?} != 0 ]; then
        echo "DB access failed, please check!"
        exit 1
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
    check_db_access
    db_setup
    display_credential
    store_credential ${DOMAIN}
}

specify_setup_main(){
    specify_name
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
        -d | -D | -domain) shift
            DOMAIN="${1}"
            ;;
        -u | -U | -user) shift
            SQL_USER="${1}"
            ;;
        -p | -P | -password) shift
            SQL_PASS="'${1}'"
            ;;            
        -db | -DB | -database) shift
            SQL_DB="${1}"
            ;;            
        *) 
            help_message
            ;;              
    esac
    shift
done
main
