#!/usr/bin/env bash
# create random password

if [ -z "$1" ]
then
      echo "Missing arguments, exit"
      exit 0
fi

PASSWDDBnoQoutes="$(openssl rand -base64 12)"
PASSWDDB="'$PASSWDDBnoQoutes'"
SITE=$1

MAINDB="${SITE}_db"
echo Database: $MAINDB
echo Username: $MAINDB
echo Password: $PASSWDDBnoQoutes
any="'%'"

docker-compose exec mysql su -c 'apk add mysql-client'
docker-compose exec mysql su -c 'mysql -uroot -ppassword -e "CREATE DATABASE '${MAINDB}' /*\!40100 DEFAULT CHARACTER SET utf8 */;"'
docker-compose exec mysql su -c 'mysql -uroot -ppassword -e "CREATE USER '${MAINDB}'@${any} IDENTIFIED BY '${PASSWDDB}';"'
docker-compose exec mysql su -c 'mysql -uroot -ppassword -e "GRANT ALL PRIVILEGES ON '${MAINDB}'.* TO '${MAINDB}'@${any};"'
docker-compose exec mysql su -c "mysql -uroot -ppassword -e 'FLUSH PRIVILEGES;'"
