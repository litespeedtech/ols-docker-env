# OpenLiteSpeed WordPress Docker Container (Beta)
[![Build Status](https://travis-ci.com/litespeedtech/ols-docker-env.svg?branch=master)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![OpenLiteSpeed](https://img.shields.io/badge/openlitespeed-1.6.5-informational?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![docker pulls](https://img.shields.io/docker/pulls/litespeedtech/openlitespeed-beta?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed-beta)

Install a Lightweight WordPress container with OpenLiteSpeed 1.6.5+ & PHP 7.3+ based on Ubuntu 18.04 Linux.

### Prerequisites
1. [Install Docker](https://www.docker.com/)
2. [Install Docker Compose](https://docs.docker.com/compose/)
3. Clone this repository or copy the files from this repository into a new folder:
```
git clone https://github.com/litespeedtech/ols-docker-env.git
```

## Configuration
Edit the `.env` file to update the demo site domain, default MySQL user, and password.

## Installation
Open a terminal, `cd` to the folder in which `docker-compose.yml` is saved, and run:
```
docker-compose up
```

## Components
The docker image installs the following packages on your system:

|Component|Version|
| :-------------: | :-------------: |
|Linux|Ubuntu 18.04|
|OpenLiteSpeed|[Latest version](https://openlitespeed.org/downloads/)|
|MariaDB|[Stable version: 10.3](https://hub.docker.com/_/mariadb)|
|PHP|[Stable version: 7.3](http://rpms.litespeedtech.com/debian/)|
|LiteSpeed Cache|[Latest from WordPress.org](https://wordpress.org/plugins/litespeed-cache/)|
|Certbot|[Latest from Certbot's PPA](https://launchpad.net/~certbot/+archive/ubuntu/certbot)|
|WordPress|[Latest from WordPress](https://wordpress.org/download/)|

## Data Structure
There is a `sites` directory next to your `docker-compose.yml` file, and it contains the following:

* `sites/DOMAIN/html/` – Document root (the WordPress application will install here)
* `sites/DOMAIN/logs/` - Access log storage

## Usage
### Starting a Container
Start the container with the `up` or `start` methods:
```
docker-compose up
```
You can run with daemon mode, like so:
```
docker-compose up -d
```
The container is now built and running. 

### Stopping a Container
```
docker-compose stop
```
### Removing Containers
To stop and remove all containers, use the `down` command:
```
docker-compose down
```
### Installing Packages
Edit the `docker-compose.yml` file, and add the package name as an `extensions` argument. We used `vim` in this example:
```
litespeed:
  build:
    context: ./config/litespeed/xxx/
    args:
      extensions: vim
```
After saving the changed configuration, run with `--build`:
```
docker-compose up --build
```

### Setting the WebAdmin Password
We strongly recommend you set your personal password right away.
```
bash bin/webadmin.sh my_password
```
### Starting a Demo Site
After running the following command, you should be able to access the WordPress installation with the configured domain. By default the domain is http://localhost.
```
bash bin/demosite.sh
```
### Creating a Domain and Virtual Host
```
bash bin/domain.sh -add example.com
```
### Creating a Database
You can either automatically generate the user, password, and database names, or specify them. Use the following to auto generate:
```
bash bin/database.sh -domain example.com
```
Use this command to specify your own names, substituting `user_name`, `my_password`, and `database_name` with your preferred values:
```
bash bin/database.sh -domain example.com -user user_name -password my_password -database database_name
```
### Installing a WordPress Site
To preconfigure the `wp-config` file, run the `database.sh` script for your domain, before you use the following command to install WordPress:
```
./bin/appinstall.sh -app wordpress -domain example.com
```
### Applying a Let's Encrypt Certificate
Use the root domain in this command, and it will check for a certificate and automatically apply one with and without `www`:
```
./bin/cert.sh example.com
```

### Accessing the Database
After installation, you can use Adminer (formerly phpMinAdmin) to access the database by visiting http://127.0.0.1:8080. The default username is `root`, and the password is the same as the one you supplied in the `.env` file.

## Support & Feedback
If you still have a question after using OpenLiteSpeed Docker, you have a few options.
* Join [the GoLiteSpeed Slack community](litespeedtech.com/slack) for real-time discussion
* Post to [the OpenLiteSpeed Forums](https://forum.openlitespeed.org/) for community support
* Reporting any issue on [Github ols-docker-env](https://github.com/litespeedtech/ols-docker-env/issues) project

**Pull requests are always welcome**