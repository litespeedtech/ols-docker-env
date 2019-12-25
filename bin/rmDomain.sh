#!/usr/bin/env bash
docker-compose exec litespeed su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && rmDomainCtl.sh $1"

