#!/usr/bin/env bash
docker-compose exec litespeed su -c "certbot certonly --agree-tos --register-unsafely-without-email --webroot -w /var/www/vhosts/${1}/html -d ${1} -d www.${1}"
echo OLS needs to be restarted to detect the certificates
