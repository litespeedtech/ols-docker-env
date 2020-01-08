#FROM debian:jessie-slim
FROM litespeedtech/openlitespeed-beta:latest

ARG extensions

RUN apt-get install $extensions -y

#RUN echo "admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php* -q /usr/local/lsws/admin/misc/htpasswd.php ${WEB_ADMIN_PASSWORD})" \
#    > /usr/local/lsws/admin/conf/htpasswd

