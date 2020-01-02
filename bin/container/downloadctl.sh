#!/bin/bash
DEFAULT_VH_ROOT='/var/www/vhosts'
VH_DOC_ROOT=''
APP_NAME=''
DOMAIN=''
WWW_UID=''
WWW_GID=''
PUB_IP=$(curl http://checkip.amazonaws.com)

help_message(){
    echo 'Command [-app app_name] [-domain domain_name]'
    echo 'Example: download.sh -app wordpress -d example.com'
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

linechange(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    if [ -n "${LINENUM}" ] && [ "${LINENUM}" -eq "${LINENUM}" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi 
}

get_owner(){
	WWW_UID=$(stat -c "%u" ${DEFAULT_VH_ROOT}/${1})
	WWW_GID=$(stat -c "%g" ${DEFAULT_VH_ROOT}/${1})
	if [ ${WWW_UID} -eq 0 ] || [ ${WWW_GID} -eq 0 ]; then
		echo "Found ${WWW_UID}:${WWW_GID} has root, will auto fix to 1000"
		WWW_UID=1000
		WWW_GID=1000
	fi
}

get_db_pass(){
    if [ -f ${DEFAULT_VH_ROOT}/${1}/.db_pass ]; then
	    SQL_DB=$(grep -i Database ${VH_DOC_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
        SQL_USER=$(grep -i Username ${VH_DOC_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
        SQL_PASS=$(grep -i Password ${VH_DOC_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
    else
	    echo 'DB_PASS can not locate!'
	fi
}

set_vh_docroot(){
	if [ -d ${DEFAULT_VH_ROOT}/${1}/html ]; then
        VH_DOC_ROOT="${DEFAULT_VH_ROOT}/${1}/html"
	else
	    echo "${DEFAULT_VH_ROOT}/${1}/html does not exist, please add domain first! Abort!"
		exit 1
	fi	
}

check_sql_native(){
    local COUNTER=0
	local LIMIT_NUM=100
	until [ "$(curl -v mysql:3306 2>&1 | grep native)" ];
	do
	    echo "Counter: ${COUNTER}/${LIMIT_NUM}"
		COUNTER=$((COUNTER+1))
		if [ ${COUNTER} = 10 ]; then
			echo '--- MySQL is starting, please wait... ---'
		elif [ ${COUNTER} = ${LIMIT_NUM} ]; then	
		    echo '--- MySQL is timeout, exit! ---'
			exit 1
		fi
		sleep 1
	done
}

preinstall_wordpress(){
	get_db_pass ${DOMAIN}
	if [ ! -f ${VH_DOC_ROOT}/wp-config.php ] && [ -f ${VH_DOC_ROOT}/wp-config-sample.php ]; then
		cp ${VH_DOC_ROOT}/wp-config-sample.php ${VH_DOC_ROOT}/wp-config.php
		NEWDBPWD="define('DB_PASSWORD', '${SQL_PASS}');"
		linechange 'DB_PASSWORD' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_USER', '${SQL_USER}');"
		linechange 'DB_USER' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_NAME', '${SQL_DB}');"
		linechange 'DB_NAME' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
	elif [ -f ${VH_DOC_ROOT}/wp-config.php ]; then
	    echo "${VH_DOC_ROOT}/wp-config.php already exist, exit !"
		exit 1
	else
	    echo 'Skip!'
		exit 2
    fi    
}

app_wordpress_dl(){
	if [ ! -f "${VH_DOC_ROOT}/wp-config.php" ] && [ ! -f "${VH_DOC_ROOT}/wp-config-sample.php" ]; then
		wp core download \
			--allow-root \
			--force
		chown -R ${WWW_UID}:${WWW_GID} ${DEFAULT_VH_ROOT}/${DOMAIN}
	else
	    echo 'wp-config*.php	already exist, abort!'
		exit 1
	fi
}

main(){
	get_owner
	cd ${VH_DOC_ROOT}
	if [ "${APP_NAME}" = 'wordpress' ] || [ "${APP_NAME}" = 'wp' ]; then
	    check_sql_native
	    app_wordpress_dl
		preinstall_wordpress
		exit 0
	else
	    echo "APP: ${APP_NAME} not support, exit!"
		exit 1	
	fi
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -app | -a | -A) shift
            check_input "${1}"
            APP_NAME="${1}"
            ;;
        -d | -D | -domain) shift
            check_input "${1}"
            DOMAIN="${1}"
			set_vh_docroot ${DOMAIN}
            ;;          
        *) 
            help_message
            ;;              
    esac
    shift
done
main
