#!/usr/bin/env bash
docker-compose exec litespeed su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && addDomainCtl.sh $1"
[ ! -d "./sites/$1" ] && mkdir -p ./sites/$1/{html,logs}

