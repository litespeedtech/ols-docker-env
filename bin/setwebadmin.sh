#!/usr/bin/env bash
docker-compose exec litespeed su -s /bin/bash lsadm -c \
    'echo "admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php* -q $/usr/local/lsws/admin/misc/htpasswd.php '${1}')" > /usr/local/lsws/admin/conf/htpasswd';
          