#!/bin/bash
DEFAULT_VH_ROOT='/var/www/vhosts'
VH_DOC_ROOT=''
VHNAME=''
APP_NAME=''
DOMAIN=''
WWW_UID=''
WWW_GID=''
WPCONSTCONF=''
PUB_IP=$(curl -s http://checkip.amazonaws.com)
DB_HOST='mysql'
PLUGINLIST="litespeed-cache.zip"
THEME='twentytwenty'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
	echo -e "\033[1mOPTIONS\033[0m"
    echow '-A, -app [wordpress] -D, --domain [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Example: appinstallctl.sh --app wordpress --domain example.com"
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

linechange(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    if [ -n "${LINENUM}" ] && [ "${LINENUM}" -eq "${LINENUM}" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi 
}

ck_ed(){
    if [ ! -f /bin/ed ]; then
        echo "Install ed package.."
        apt-get install ed -y > /dev/null 2>&1
    fi    
}

ck_unzip(){
    if [ ! -f /usr/bin/unzip ]; then 
        echo "Install unzip package.."
        apt-get install unzip -y > /dev/null 2>&1
    fi		
}

get_owner(){
	WWW_UID=$(stat -c "%u" ${DEFAULT_VH_ROOT})
	WWW_GID=$(stat -c "%g" ${DEFAULT_VH_ROOT})
	if [ ${WWW_UID} -eq 0 ] || [ ${WWW_GID} -eq 0 ]; then
		WWW_UID=1000
		WWW_GID=1000
		echo "Set owner to ${WWW_UID}"
	fi
}

get_db_pass(){
	if [ -f ${DEFAULT_VH_ROOT}/${1}/.db_pass ]; then
		SQL_DB=$(grep -i Database ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
		SQL_USER=$(grep -i Username ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
		SQL_PASS=$(grep -i Password ${VH_ROOT}/.db_pass | awk -F ':' '{print $2}' | tr -d '"')
	else
		echo 'db pass file can not locate, skip wp-config pre-config.'
	fi
}

set_vh_docroot(){
	if [ "${VHNAME}" != '' ]; then
	    VH_ROOT="${DEFAULT_VH_ROOT}/${VHNAME}"
	    VH_DOC_ROOT="${DEFAULT_VH_ROOT}/${VHNAME}/html"
		WPCONSTCONF="${VH_DOC_ROOT}/wp-content/plugins/litespeed-cache/data/const.default.json"
	elif [ -d ${DEFAULT_VH_ROOT}/${1}/html ]; then
	    VH_ROOT="${DEFAULT_VH_ROOT}/${1}"
        VH_DOC_ROOT="${DEFAULT_VH_ROOT}/${1}/html"
		WPCONSTCONF="${VH_DOC_ROOT}/wp-content/plugins/litespeed-cache/data/const.default.json"
	else
	    echo "${DEFAULT_VH_ROOT}/${1}/html does not exist, please add domain first! Abort!"
		exit 1
	fi	
}

check_sql_native(){
	local COUNTER=0
	local LIMIT_NUM=100
	until [ "$(curl -v mysql:3306 2>&1 | grep -i 'native\|Connected')" ]; do
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

install_wp_plugin(){
    for PLUGIN in ${PLUGINLIST}; do
        wget -q -P ${VH_DOC_ROOT}/wp-content/plugins/ https://downloads.wordpress.org/plugin/${PLUGIN}
        if [ ${?} = 0 ]; then
		    ck_unzip
            unzip -qq -o ${VH_DOC_ROOT}/wp-content/plugins/${PLUGIN} -d ${VH_DOC_ROOT}/wp-content/plugins/
        else
            echo "${PLUGINLIST} FAILED to download"
        fi
    done
    rm -f ${VH_DOC_ROOT}/wp-content/plugins/*.zip
}

set_htaccess(){
    if [ ! -f ${VH_DOC_ROOT}/.htaccess ]; then 
        touch ${VH_DOC_ROOT}/.htaccess
    fi   
    cat << EOM > ${VH_DOC_ROOT}/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOM
}

get_theme_name(){
    THEME_NAME=$(grep WP_DEFAULT_THEME ${VH_DOC_ROOT}/wp-includes/default-constants.php | grep -v '!' | awk -F "'" '{print $4}')
    echo "${THEME_NAME}" | grep 'twenty' >/dev/null 2>&1
    if [ ${?} = 0 ]; then
        THEME="${THEME_NAME}"
    fi
}

set_lscache(){ 
	wget -q -O ${WPCONSTCONF} https://raw.githubusercontent.com/litespeedtech/lscache_wp/refs/heads/master/data/const.default.json
    if [ -f ${WPCONSTCONF} ]; then
        sed -ie 's/"object": .*"/"object": '\"true\"'/g' ${WPCONSTCONF}
		sed -ie 's/"object-kind": .*"/"object-kind": '\"true\"'/g' ${WPCONSTCONF}
		sed -ie 's/"object-host": .*"/"object-host": '\"redis\"'/g' ${WPCONSTCONF}
		sed -ie 's/"object-port": .*"/"object-port": '\"6379\"'/g' ${WPCONSTCONF}
    fi
    THEME_PATH="${VH_DOC_ROOT}/wp-content/themes/${THEME}"
    if [ ! -f ${THEME_PATH}/functions.php ]; then
        cat >> "${THEME_PATH}/functions.php" <<END
<?php
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
END
    elif [ ! -f ${THEME_PATH}/functions.php.bk ]; then 
        cp ${THEME_PATH}/functions.php ${THEME_PATH}/functions.php.bk
        ck_ed
        ed ${THEME_PATH}/functions.php << END >>/dev/null 2>&1
2i
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
.
w
q
END
    fi
}

preinstall_wordpress(){
	if [ "${VHNAME}" != '' ]; then
	    get_db_pass ${VHNAME}
	else
		get_db_pass ${DOMAIN}
	fi	
	if [ ! -f ${VH_DOC_ROOT}/wp-config.php ] && [ -f ${VH_DOC_ROOT}/wp-config-sample.php ]; then
		cp ${VH_DOC_ROOT}/wp-config-sample.php ${VH_DOC_ROOT}/wp-config.php
		NEWDBPWD="define('DB_PASSWORD', '${SQL_PASS}');"
		linechange 'DB_PASSWORD' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_USER', '${SQL_USER}');"
		linechange 'DB_USER' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
		NEWDBPWD="define('DB_NAME', '${SQL_DB}');"
		linechange 'DB_NAME' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
        #NEWDBPWD="define('DB_HOST', '${PUB_IP}');"
		NEWDBPWD="define('DB_HOST', '${DB_HOST}');"
		linechange 'DB_HOST' ${VH_DOC_ROOT}/wp-config.php "${NEWDBPWD}"
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
			--quiet
	else
	    echo 'wordpress already exist, abort!'
		exit 1
	fi
}

change_owner(){
		if [ "${VHNAME}" != '' ]; then
		    chown -R ${WWW_UID}:${WWW_GID} ${DEFAULT_VH_ROOT}/${VHNAME} 
		else
		    chown -R ${WWW_UID}:${WWW_GID} ${DEFAULT_VH_ROOT}/${DOMAIN}
		fi
}

main(){
	set_vh_docroot ${DOMAIN}
	get_owner
	cd ${VH_DOC_ROOT}
	if [ "${APP_NAME}" = 'wordpress' ] || [ "${APP_NAME}" = 'wp' ]; then
		check_sql_native
		app_wordpress_dl
		preinstall_wordpress
		install_wp_plugin
		set_htaccess
		get_theme_name
		set_lscache
		change_owner
		exit 0
	else
		echo "APP: ${APP_NAME} not support, exit!"
		exit 1	
	fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
	case ${1} in
		-[hH] | -help | --help)
			help_message
			;;
		-[aA] | -app | --app) shift
			check_input "${1}"
			APP_NAME="${1}"
			;;
		-[dD] | -domain | --domain) shift
			check_input "${1}"
			DOMAIN="${1}"
			;;
		-vhname | --vhname) shift
			VHNAME="${1}"
			;;	       
		*) 
			help_message
			;;              
	esac
	shift
done
main
