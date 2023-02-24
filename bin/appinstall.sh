#!/usr/bin/env bash
APP_NAME=''
DOMAIN=''
EPACE='        '
TITLE=''
USERNAME=''
PASSWORD=''
EMAIL=''

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '-A, --app [app_name] -D, --domain [DOMAIN_NAME], -T, --title [site_title], -U, --username [admin_username], -P, --password [admin_password], -E, --email [admin_email]'
    echo "${EPACE}${EPACE}Example: appinstall.sh -A wordpress -D example.com -T example -U admin -P p@ssw0rd -E foo@bar"
    echo "${EPACE}${EPACE}Will install WordPress CMS under the example.com domain"
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

app_download(){
    docker compose exec litespeed su -c "appinstallctl.sh --app ${1} --domain ${2}"
    bash bin/webadmin.sh -r
}

main(){
  if [ "${APP_NAME}" = 'wordpress' ] || [ "${APP_NAME}" = 'wp' ]; then
    app_download ${APP_NAME} ${DOMAIN} ${TITLE} ${USERNAME} ${PASSWORD} ${EMAIL}
    status_code=$(curl --data-urlencode "weblog_title=${TITLE}" \
         --data-urlencode "user_name=${USERNAME}" \
         --data-urlencode "admin_password=${PASSWORD}" \
         --data-urlencode "admin_password2=${PASSWORD}" \
         --data-urlencode "admin_email=${EMAIL}" \
         --data-urlencode "Submit=Install+WordPress" \
         --silent \
         --write-out '%{http_code}' \
         http://${DOMAIN}/wp-admin/install.php?step=2)
    echo "Status $status_code"
    if [[ "$status_code" -ne 200 ]]
    then
      echo "Set up failed, you need to set up manually via your domain"
    else
      echo "Set up full-configured wordpress successfully"
    fi
  fi
  if [ "${APP_NAME}" = 'empty' ] || [ "${APP_NAME}" = 'mt' ]; then
    app_download ${APP_NAME} ${DOMAIN}
  fi
  exit 0
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
        -[tT] | -title | --title) shift
            check_input "${1}"
            TITLE="${1}"
            ;;
         -[uU] | -username | --username) shift
            check_input "${1}"
            USERNAME="${1}"
            ;;
        -[pP] | -password | --password) shift
            check_input "${1}"
            PASSWORD="${1}"
            ;;
        -[eE] | -email | --email) shift
            check_input "${1}"
            EMAIL="${1}"
            ;;
        *) 
            help_message
            ;;              
    esac
    shift
done

main