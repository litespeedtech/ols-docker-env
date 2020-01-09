#FROM debian:jessie-slim
FROM litespeedtech/openlitespeed-beta:latest

ARG extensions

RUN apt-get install $extensions -y

#RUN apt-get install -y software-properties-common && \
#    add-apt-repository 'deb http://ftp.debian.org/debian jessie-backports main' && \
#    apt-get update && apt-get install -y python-certbot-apache -t jessie-backports

RUN apt-get install -y software-properties-common && \
    add-apt-repository universe && \
    add-apt-repository ppa:certbot/certbot && \
    apt-get update && \
    apt-get install -y certbot python-certbot-apache



#RUN echo "admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php* -q /usr/local/lsws/admin/misc/htpasswd.php ${WEB_ADMIN_PASSWORD})" \
#    > /usr/local/lsws/admin/conf/htpasswd

