#!/bin/bash
cd /var/www/vhosts/$1/html
if [ ! -f "./wp-config.php" ]; then
	# su -s /bin/bash www-data -c
    COUNTER=0
	until [ "$(curl -v mysql:3306 2>&1 | grep native)" ];
	do
	    echo "Counter: ${COUNTER}"
		COUNTER=$((COUNTER+1))
		if [ ${COUNTER} = 10 ]; then
			echo '--- MySQL is starting, please wait... ---'
		elif [ ${COUNTER} = 100 ]; then	
		    echo '--- MySQL is timeout, exit! ---'
			exit 1
		fi
		sleep 1
	done
	wp core download \
	    --allow-root \
	    --force
	first_www_uid=$(stat -c "%u" /var/www/vhosts/localhost)
	first_www_gid=$(stat -c "%g" /var/www/vhosts/localhost)
	chown $first_www_uid:$first_www_gid /var/www/vhosts/localhost -R

fi


www_uid=$(stat -c "%u" /var/www/vhosts/localhost)
if [ ${www_uid} -eq 0 ]; then
    #echo "./sites/localhost is owned by root, auto changing ownership of ./sites/localhost to uid 1000"
    chown 1000:1000 /var/www/vhosts/localhost -R
fi

echo "WordPress installation finished."
exec "$@"

