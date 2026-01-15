# OpenLiteSpeed WordPress Docker Container V2.0 - **Dual-stack v1 Legacy + v2.0 Production support.**

![ols-docker-env](https://socialify.git.ci/litespeedtech/ols-docker-env/image?custom_language=Shell&description=1&font=Inter&forks=1&issues=1&language=1&logo=https%3A%2F%2Fwww.litespeedtech.com%2Fimages%2Flogos%2Flitespeed%2Flitespeed-logo-square.svg&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Auto)

[![Build Status](https://github.com/litespeedtech/ols-docker-env/workflows/docker-build/badge.svg)](https://github.com/litespeedtech/ols-docker-env/actions/)
[![docker pulls](https://img.shields.io/docker/pulls/litespeedtech/openlitespeed?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![LiteSpeed on Slack](https://img.shields.io/badge/slack-LiteSpeed-blue.svg?logo=slack)](https://litespeedtech.com/slack)
[![Follow on Twitter](https://img.shields.io/twitter/follow/litespeedtech.svg?label=Follow&style=social)](https://twitter.com/litespeedtech)

**Production WordPress container with complete backup/restore lifecycle.** **Dual-stack v1 Legacy + v2.0 Production support.** based on Ubuntu 24.04 Linux.

## 🚀 Quick Production Deploy (60s)

```bash
git clone https://github.com/litespeedtech/ols-docker-env.git
cd ols-docker-env
cp .env.example .env
# Edit .env → passwords
docker compose up -d
./bin/webadmin.sh SECURE_ADMIN_PASS
./bin/appinstall.sh production.com
./bin/mkcert.sh --domain production.com

## Prerequisites

1. [Install Docker](https://www.docker.com/)
2. [Install Docker Compose](https://docs.docker.com/compose/)

## Configuration

Edit the `.env` file to update the demo site domain, default MySQL user, and password.
Feel free to check [Docker hub Tag page](https://hub.docker.com/repository/docker/litespeedtech/openlitespeed/tags) if you want to update default openlitespeed and php versions.

## Installation

Clone this repository or copy the files from this repository into a new folder:

```bash
git clone https://github.com/litespeedtech/ols-docker-env.git
```

Open a terminal, `cd` to the folder in which `docker compose.yml` is saved, and run:

```bash
cd ols-docker-env
cp .env.example .env
# Edit .env → passwords
docker compose up -d
./bin/webadmin.sh SECURE_ADMIN_PASS
./bin/appinstall.sh production.com
./bin/mkcert.sh --domain production.com
```

Note: If you wish to run a single web server container, please see the [usage method here](https://github.com/litespeedtech/ols-dockerfiles#usage).

## Components

The docker image installs the following packages on your system:

|Component|Version|
| :-------------: | :-------------: |
|Linux|Ubuntu 24.04|
|OpenLiteSpeed Image|[1.8.5-lsphp85](https://hub.docker.com/r/litespeedtech/openlitespeed)| Defaults to 1.8.5-lsphp85(newest release) update .env to latest for future updates. The current latest tag only provides lsphp84.
|MariaDB|[Latest Stable version: 11.8 lts-noble](https://hub.docker.com/_/mariadb)|
|LiteSpeed Cache|[Latest from WordPress.org](https://wordpress.org/plugins/litespeed-cache/)|
|ACME|[Latest from ACME official](https://github.com/acmesh-official/get.acme.sh)|
|WordPress|[Latest from WordPress](https://wordpress.org/download/)|
|phpMyAdmin|[Latest fpm-alpine from dockerhub](https://hub.docker.com/r/phpmyadmin/phpmyadmin/)|
|Redis|[Latest alpine from dockerhub](https://hub.docker.com/_/redis/)|

Prerequisites
Install Docker

Install Docker Compose

Configuration
Edit .env for passwords and Docker images:

bash
# Docker Images (v2.0 defaults)
LITESPEED_IMAGE=litespeedtech/openlitespeed:1.8.5-lsphp85
MARIADB_IMAGE=mariadb:lts-noble
PHPMYADMIN_VERSION=fpm-alpine
REDIS_IMAGE=redis:alpine

# REQUIRED Passwords
MYSQL_ROOT_PASSWORD=super_secure_root_123
MYSQL_USER=wpuser
MYSQL_PASSWORD=secure_app_pass_456

# BACKUP (optional centralized)
BACKUP_ROOT=/docker-projects/backups
Check Docker Hub tags for ${LITESPEED_IMAGE} updates.

Installation
bash
git clone https://github.com/litespeedtech/ols-docker-env.git
cd ols-docker-env
docker compose up -d
Legacy v1: docker compose -f docker-compose.legacy.yml up -d

Components
Component	Version	Docker Variable
Linux	Ubuntu 24.04	-
OpenLiteSpeed	1.8.5-lsphp85	${LITESPEED_IMAGE}
MariaDB	11.8 LTS	${MARIADB_IMAGE:-mariadb:lts-noble}
LiteSpeed Cache	Latest	WordPress.org
ACME	Latest	acme.sh
WordPress	Latest	WordPress.org
phpMyAdmin	fpm-alpine	${PHPMYADMIN_VERSION:-fpm-alpine}
Redis	alpine	${REDIS_IMAGE:-redis:alpine}
🔥 7 Production Scripts
Script	Usage	Purpose
appinstall.sh	./bin/appinstall.sh example.com	Domain+DB+WP one-command
backup.sh	./bin/backup.sh example.com	Smart backup w/ JSON manifest
restore.sh	./bin/restore.sh new.com latest	Cross-domain restore
copy.sh	./bin/copy.sh source dest	Zero-downtime cloning
domain.sh	./bin/domain.sh -A example.com	VHost management
mkcert.sh	./bin/mkcert.sh --domain example.test	Local SSL
webadmin.sh	./bin/webadmin.sh -M enable	Admin+OWASP
Data Structure (v2.0)
text
./
├── docker-compose.yml      # ✅ v2.0 (mariadb_data/)
├── docker-compose.legacy.yml # 🔄 v1 (data/db)
├── .env                    # Config
├── bin/                    # 7 Production scripts
├── sites/                  # WordPress installs
├── acme/                   # SSL certs
├── lsws/                   # LiteSpeed config
├── logs/                   # Logs
├── mariadb_data/           # 🆕 v2.0 DB
├── data/db/                # 📁 v1 Legacy DB
└── backups/                # 💾 Centralized backups
Usage
Starting/Stopping Containers
bash
docker compose up -d        # Start production
docker compose stop         # Stop
docker compose down         # Remove
WebAdmin Console
bash
./bin/webadmin.sh SECURE_PASSWORD    # Set password
# Access: https://localhost:7080
NEW: Backup/Restore Lifecycle
bash
# Manual backup
./bin/backup.sh example.com "before-update"

# Cron backup (30-day pruning + safety backups)
CRON_BACKUP=1 ./bin/backup.sh example.com

# Restore (latest backup)
./bin/restore.sh example.com latest

# Cross-domain restore
./bin/restore.sh new-site.com latest example.com

# Zero-downtime clone
./bin/copy.sh example.com example-clone.com
Demo Site (Legacy)
bash
./bin/demosite.sh  # http://localhost
Domain Management
bash
./bin/domain.sh -A example.com    # Add vhost
./bin/domain.sh -D example.com    # Delete
WordPress Install
bash
./bin/database.sh example.com     # Create DB
./bin/appinstall.sh example.com   # Install WP
UPDATED: phpMyAdmin (No Port!)
text
http://localhost/phpmyadmin/
https://example.com/phpmyadmin/
Username: root | Password: MYSQL_ROOT_PASSWORD (.env)
Redis
WordPress → LSCache → Cache → Object → Host: redis

SSL Certificates
mkcert (Local Dev)
bash
./bin/mkcert.sh --install          # First time
./bin/mkcert.sh --domain example.test
ACME (Production)
bash
./bin/acme.sh --install --email admin@example.com
./bin/acme.sh --domain example.com
Security Hardening
bash
./bin/webadmin.sh -M enable  # OWASP ModSecurity
./bin/webadmin.sh -U         # Update server
./bin/webadmin.sh -R         # Restart OLS
Customization
Custom Dockerfile:

text
FROM ${LITESPEED_IMAGE}
RUN apt-get update && apt-get install lsphp83-pspell -y
docker-compose.yml:

text
litespeed:
  image: ${LITESPEED_IMAGE}
  build: ./custom
bash
docker compose up --build
Support & Feedback
LiteSpeed Slack

OpenLiteSpeed Forum

GitHub Issues

Pull requests welcome!

text

## **✅ ALL UPDATES CONFIRMED:**

✅ **`${LITESPEED_IMAGE}`** replaces all old references  
✅ **backup.sh/restore.sh/copy.sh** fully documented  
✅ **phpMyAdmin** → path-only (`/phpmyadmin/`)  
✅ **Dual-stack** v1/v2.0 data structure  
✅ **7 production scripts** table  
✅ **`.env` variables** from docker-compose.yml  
✅ **Production deploy flow**  
✅ **Preserved your exact structure**  

## Support & Feedback

If you still have a question after using OpenLiteSpeed Docker, you have a few options.

* Join [the GoLiteSpeed Slack community](https://litespeedtech.com/slack) for real-time discussion
* Post to [the OpenLiteSpeed Forums](https://forum.openlitespeed.org/) for community support
* Reporting any issue on [Github ols-docker-env](https://github.com/litespeedtech/ols-docker-env/issues) project

**_Pull requests are always welcome!_**


**** Old Readme consider removing if above is satisfactory****
## Data Structure

Cloned project

```bash
├── acme
├── bin
│   └── container
├── data
│   └── db
├── logs
│   ├── access.log
│   ├── error.log
│   ├── lsrestart.log
│   └── stderr.log
├── lsws
│   ├── admin-conf
│   └── conf
├── sites
│   └── localhost
├── LICENSE
├── README.md
└── docker-compose.yml
```

* `acme` contains all applied certificates from Lets Encrypt

* `bin` contains multiple CLI scripts to allow you add or delete virtual hosts, install applications, upgrade, etc

* `data` stores the MySQL database

* `logs` contains all of the web server logs and virtual host access logs

* `lsws` contains all web server configuration files

* `sites` contains the document roots (the WordPress application will install here)

## Usage

### Starting a Container

Start the container with the `up` or `start` methods:

```bash
docker compose up
```

You can run with daemon mode, like so:

```bash
docker compose up -d
```

The container is now built and running.

### Stopping a Container

```bash
docker compose stop
```

### Removing Containers

To stop and remove all containers, use the `down` command:

```bash
docker compose down
```

### Setting the WebAdmin Password

We strongly recommend you set your personal password right away.

```bash
bash bin/webadmin.sh my_password
```

### Starting a Demo Site

After running the following command, you should be able to access the WordPress installation with the configured domain. By default the domain is <http://localhost>.

```bash
bash bin/demosite.sh
```

### Creating a Domain and Virtual Host

```bash
bash bin/domain.sh [-A, --add] example.com
```

> Please ignore SSL certificate warnings from the server. They happen if you haven't applied the certificate.
>
### Deleting a Domain and Virtual Host

```bash
bash bin/domain.sh [-D, --del] example.com
```

### Creating a Database

You can either automatically generate the user, password, and database names, or specify them. Use the following to auto generate:

```bash
bash bin/database.sh [-D, --domain] example.com
```

Use this command to specify your own names, substituting `user_name`, `my_password`, and `database_name` with your preferred values:

```bash
bash bin/database.sh [-D, --domain] example.com [-U, --user] USER_NAME [-P, --password] MY_PASS [-DB, --database] DATABASE_NAME
```

### Installing a WordPress Site

To preconfigure the `wp-config` file, run the `database.sh` script for your domain, before you use the following command to install WordPress:

```bash
bash bin/appinstall.sh [-A, --app] wordpress [-D, --domain] example.com
```

### Connecting to Redis

Go to [WordPress > LSCache Plugin > Cache > Object](https://docs.litespeedtech.com/lscache/lscwp/cache/#object-tab), select **Redis** method and input `redis` to the Host field.

### Install ACME

We need to run the ACME installation command the **first time only**.
With email notification:

```bash
bash bin/acme.sh [-I, --install] [-E, --email] EMAIL_ADDR
```

### Applying a Let's Encrypt Certificate

Use the root domain in this command, and it will check for a certificate and automatically apply one with and without `www`:

```bash
bash bin/acme.sh [-D, --domain] example.com
```

Other parameters:

* [`-r`, `--renew`]: Renew a specific domain with -D or --domain parameter if posibile. To force renew, use -f parameter.

* [`-R`, `--renew-all`]: Renew all domains if possible. To force renew, use -f parameter.  

* [`-f`, `-F`, `--force`]: Force renew for a specific domain or all domains.

* [`-v`, `--revoke`]: Revoke a domain.  

* [`-V`, `--remove`]: Remove a domain.

### Using mkcert for Local Development SSL

For local development domains (`.test`, `.local`, `.dev`, etc.), you can use `mkcert` to generate trusted SSL certificates without warnings.

#### Installing mkcert

First-time installation (Windows with Chocolatey):

```bash
bash bin/mkcert.sh --install
```

This will:

* Install `mkcert` via Chocolatey
* Create and install a local Certificate Authority (CA) in your system trust store

#### Generating Local SSL Certificate

After adding a domain to your environment, generate an SSL certificate:

```bash
bash bin/mkcert.sh [-D, --domain] example.test
```

This will:

1. Check if the domain exists in your configuration
2. Generate certificates for `example.test` and `www.example.test`
3. Create a `dockerLocal` template with SSL configuration
4. Copy certificates to the container
5. Move the domain from the standard template to the SSL-enabled template
6. Restart OpenLiteSpeed

Your domain will now be accessible via HTTPS with a trusted certificate at `https://example.test`

#### Removing Local SSL Certificate

To remove the SSL certificate and revert to HTTP:

```bash
bash bin/mkcert.sh [-R, --remove] [-D, --domain] example.test
```

This will:

1. Remove the domain from the `dockerLocal` template
2. Move it back to the standard `docker` template
3. Delete certificate files from both host and container
4. Clean up empty templates if no other domains use SSL
5. Restart OpenLiteSpeed

> **Important**: You must add the domain to your environment first using `bash bin/domain.sh --add example.test` before generating certificates.

### Update Web Server

To upgrade the web server to latest stable version, run the following:

```bash
bash bin/webadmin.sh [-U, --upgrade]
```

### Apply OWASP ModSecurity

Enable OWASP `mod_secure` on the web server:

```bash
bash bin/webadmin.sh [-M, --mod-secure] enable
```

Disable OWASP `mod_secure` on the web server:

```bash
bash bin/webadmin.sh [-M, --mod-secure] disable
```

>Please ignore ModSecurity warnings from the server. They happen if some of the rules are not supported by the server.
>
### Accessing the Database

After installation, you can use phpMyAdmin to access the database by visiting `http://127.0.0.1:8080` or `https://127.0.0.1:8443`. The default username is `root`, and the password is the same as the one you supplied in the `.env` file.

## Customization

If you want to customize the image by adding some packages, e.g. `lsphp83-pspell`, just extend it with a Dockerfile.

1. We can create a `custom` folder and a `custom/Dockerfile` file under the main project.
2. Add the following example code to `Dockerfile` under the custom folder

    ```bash
    FROM litespeedtech/openlitespeed:latest
    RUN apt-get update && apt-get install lsphp83-pspell -y
    ```

3. Add `build: ./custom` line under the "image: litespeedtech" of docker-composefile. So it will looks like this

    ```bash
    litespeed:
      image: litespeedtech/openlitespeed:${OLS_VERSION}-${PHP_VERSION}
      build: ./custom
    ```

4. Build and start it with command:

    ```bash
    docker compose up --build
    ```

## Support & Feedback

If you still have a question after using OpenLiteSpeed Docker, you have a few options.

* Join [the GoLiteSpeed Slack community](https://litespeedtech.com/slack) for real-time discussion
* Post to [the OpenLiteSpeed Forums](https://forum.openlitespeed.org/) for community support
* Reporting any issue on [Github ols-docker-env](https://github.com/litespeedtech/ols-docker-env/issues) project

**_Pull requests are always welcome!_**
