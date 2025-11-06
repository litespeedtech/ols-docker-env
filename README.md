# OpenLiteSpeed WordPress Docker Container

![ols-docker-env](https://socialify.git.ci/litespeedtech/ols-docker-env/image?custom_language=Shell&description=1&font=Inter&forks=1&issues=1&language=1&logo=https%3A%2F%2Fwww.litespeedtech.com%2Fimages%2Flogos%2Flitespeed%2Flitespeed-logo-square.svg&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Auto)

[![Build Status](https://github.com/litespeedtech/ols-docker-env/workflows/docker-build/badge.svg)](https://github.com/litespeedtech/ols-docker-env/actions/)
[![docker pulls](https://img.shields.io/docker/pulls/litespeedtech/openlitespeed?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![LiteSpeed on Slack](https://img.shields.io/badge/slack-LiteSpeed-blue.svg?logo=slack)](https://litespeedtech.com/slack)
[![Follow on Twitter](https://img.shields.io/twitter/follow/litespeedtech.svg?label=Follow&style=social)](https://twitter.com/litespeedtech)

Install a lightweight WordPress container with OpenLiteSpeed Edge or Stable version based on Ubuntu 24.04 Linux.

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
docker compose up
```

Note: If you wish to run a single web server container, please see the [usage method here](https://github.com/litespeedtech/ols-dockerfiles#usage).

## Components

The docker image installs the following packages on your system:

|Component|Version|
| :-------------: | :-------------: |
|Linux|Ubuntu 24.04|
|OpenLiteSpeed|[Latest version](https://hub.docker.com/r/litespeedtech/openlitespeed)|
|MariaDB|[Stable version: 11.4](https://hub.docker.com/_/mariadb)|
|PHP|[Latest version](http://rpms.litespeedtech.com/debian/)|
|LiteSpeed Cache|[Latest from WordPress.org](https://wordpress.org/plugins/litespeed-cache/)|
|ACME|[Latest from ACME official](https://github.com/acmesh-official/get.acme.sh)|
|WordPress|[Latest from WordPress](https://wordpress.org/download/)|
|phpMyAdmin|[Latest from dockerhub](https://hub.docker.com/r/phpmyadmin/phpmyadmin/)|
|Redis|[Latest from dockerhub](https://hub.docker.com/_/redis/)|

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
