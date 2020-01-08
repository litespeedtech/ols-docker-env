#FROM debian:jessie-slim
FROM ubuntu:18.04

RUN apt-get update && apt-get install wget curl -y

RUN wget https://openlitespeed.org/preuse/openlitespeed-1.6.4.tgz && \
    tar xzvf openlitespeed-1.6.4.tgz && cd openlitespeed && ./install.sh && rm -rf /openlitespeed

RUN apt-get install -y software-properties-common && \
    add-apt-repository 'deb http://ftp.debian.org/debian jessie-backports main' && \
    apt-get update && apt-get install -y python-certbot-apache -t jessie-backports

RUN apt-get install mysql-client lsphp73 lsphp73-common lsphp73-mysql lsphp73-opcache \
    lsphp73-curl lsphp73-json lsphp73-imagick lsphp73-redis lsphp73-memcached -y

EXPOSE 7080

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
	chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp && \
	ln -s /usr/local/lsws/lsphp73/bin/php7.3 /usr/bin/php

RUN rm -rf /usr/local/lsws/conf
ADD conf /usr/local/lsws/conf
RUN chown 999 /usr/local/lsws/conf -R
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
WORKDIR /var/www/html/
CMD ["/usr/local/lsws/bin/openlitespeed","-n"]

