#!/bin/bash
cd localhost/html
if [ ! -f "./wp-config.php" ]; then
	# su -s /bin/bash www-data -c
    wp --allow-root core download --force
    counter=0
	until [ "$(curl -v --silent mysql:3306 2>&1 | grep native)" ];
	do
		counter=$((counter+1))
		if [ $counter = 10 ]; then
			echo --- MySQL is starting, please wait... ---
			counter=0
		fi
		sleep 1
	done
    wp --allow-root core config --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" --dbpass="$MYSQL_PASSWORD" --dbhost=mysql --dbprefix="WP_DB_PREFIX" --force
	wp --allow-root core install --title="$WP_TITLE" --url="$DOMAIN" --admin_user="$ADMIN_USERNAME" --admin_email="$ADMIN_EMAIL" --admin_password="$ADMIN_PASSWORD" --skip-email
	wp --allow-root plugin install litespeed-cache 
	wp --allow-root plugin activate litespeed-cache

fi


#www_uid=$(stat -c "%u" /var/www/vhosts/localhost)
#if [ ${www_uid} -eq 0 ]; then
#    #echo "./sites/localhost is owned by root, auto changing ownership of ./sites/localhost to uid 1000"
#	chown 1000 /var/www/vhosts/localhost -R
#fi

echo "WordPress installation finished."
exec "$@"