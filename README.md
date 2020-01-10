# OpenLiteSpeed WordPress Docker Container (beta)
[![Build Status](https://travis-ci.com/litespeedtech/ols-docker-env.svg?branch=master)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![OpenLiteSpeed](https://img.shields.io/badge/openlitespeed-1.6.4-informational?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![docker pulls](https://img.shields.io/docker/pulls/litespeedtech/openlitespeed-beta?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed-beta)

Lightweight WordPress container with OpenLiteSpeed 1.6.4 & PHP 7.3 based on Ubuntu 18.04 Linux.

### Prerequisites
1. [Install Docker](https://www.docker.com/)
2. [Install Docker Compose](https://docs.docker.com/compose/)
3. Clone this repository or copy the files from this repository into a new folder.
```
git clone https://github.com/litespeedtech/ols-docker-env.git
```

## Configuration
Edit the `.env` file to update the demo site domain, default MySQL user and password.

## Installation
Open a terminal and `cd` to the folder in which `docker-compose.yml` is saved and run:
```
docker-compose up
```

## Components
The docker image installs several packages and performs other actions on your system.

|Component|Version|
| :-------------: | :-------------: |
|Linux|Ubuntu 18.04|
|OpenLiteSpeed|[Latest version](https://openlitespeed.org/downloads/)|
|MariaDB|[Stable version: 10.3](https://hub.docker.com/_/mariadb)|
|PHP|[Stable version: 7.3](http://rpms.litespeedtech.com/debian/)|
|LiteSpeed Cache|[Latest from WordPress.org](https://wordpress.org/plugins/litespeed-cache/)|
|Certbot|[Latest from Certbot's PPA](https://launchpad.net/~certbot/+archive/ubuntu/certbot)|
|WordPress|[Latest from WordPress](https://wordpress.org/download/)|

## Usage
### Starting containers
You can start the containers with up or start methods:
```
docker-compose up
```
Running with daemon mode
```
docker-compose up -d
```
The containers are now built and running. 

### Stopping containers
```
docker-compose stop
```
### Removing containers
To stop and remove all the containers use the down command:
```
docker-compose down
```
### Install packages
Edit docker-compose.yml file and put the PACKAGE name on extensions entry, we use `vim` as example.
```
litespeed:
  build:
    context: ./config/litespeed/xxx/
    args:
      extensions: vim
```
After saving, running with `--build` after config changing
```
docker-compose up --build
```

### Set WebAdmin Password
Strongly recommended to set personal passwprd at first time
```
bash bin/webadmin.sh my_password
```
### Start demo site
After running follow command, you should be able to access the WordPress installation with the configured domain in the browser address. By default it is http://localhost.
```
bash bin/demosite.sh
```
### Create Domain and Virtual Host
```
bash bin/domain.sh -add example.com
```
### Create Database
Auto generate method:
```
bash bin/database.sh -domain example.com
```
Specify method:
```
bash bin/database.sh -domain example.com -user user_name -password my_password -database database_name
```
### Download wordpress site
If you ran the database.sh script first for the same domain, it will pre-config the wp-config for you
```
./bin/appinstall.sh -app wordpress -domain example.com
```
### Apply Let's Encrypt Certificate
Entering the root domain and it will auto check and auto apply with/with out www certificate for us.
```
./bin/cert.sh example.com
```

### Data Structure
There's an existing `sites` folder next to your `docker-compose.yml` file.

* `sites/DOMAIN/html/` – the location of your Document root (WordPress application will install here)
* `sites/DOMAIN/logs/` - the location of your access log

### Adminer (formerly phpMinAdmin)
You can also visit http://127.0.0.1:8080 to access DataBase after starting the containers.

The default username is root, and the password is the same as supplied in the .env file.

## Support & Feedback
If you still have a question after using OpenLiteSpeed Docker, you have a few options.
* Join [the GoLiteSpeed Slack community](litespeedtech.com/slack) for real-time discussion
* Post to [the OpenLiteSpeed Forums](https://forum.openlitespeed.org/) for community support
* Reporting any issue on [Github ols-docker-env](https://github.com/litespeedtech/ols-docker-env/issues) project

**Pull requests are always welcome**