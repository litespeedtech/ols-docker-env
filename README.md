# OpenLiteSpeed WordPress Docker Container (beta)
[![Build Status](https://travis-ci.com/litespeedtech/ols-docker-env.svg?branch=master)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![OpenLiteSpeed](https://img.shields.io/badge/openlitespeed-1.5.10-informational?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)
[![docker pulls](https://img.shields.io/docker/pulls/litespeed/openlitespeed?style=flat&color=blue)](https://hub.docker.com/r/litespeedtech/openlitespeed)

Lightweight WordPress container with OpenLiteSpeed 1.5.10 & PHP 7.3 based on Ubuntu 18.04 Linux.

WordPress version will install: Latest

### Prerequisites
1. [Install Docker](https://www.docker.com/)
2. [Install Docker Compose](https://docs.docker.com/compose/)
3. Clone this repository or copy the files from this repository into a new folder.
```
git clone https://github.com/litespeedtech/ols-docker-env.git
```

## Configuration
Edit the `.env` file to change the WordPress Domain, user and password, default MySQL root and wordpress password .

## Installation
Open a terminal and `cd` to the folder in which `docker-compose.yml` is saved and run:
```
docker-compose up
```
There's an existing `sites` folder next to your docker-compose.yml file.

* `sites` – the location of your WordPress application
* `sites/localhost/logs/` - the location of your access log

The containers are now built and running. You should be able to access the WordPress installation with the configured domain in the browser address. By default it is http://127.0.0.1.

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
Running with start method
```
docker-compose start
```
### Stopping containers
```
docker-compose stop
```
### Removing containers
To stop and remove all the containers use the down command:
```
docker-compose down
```


### Adminer (formerly phpMinAdmin)
You can also visit http://127.0.0.1:8080 to access Data Base after starting the containers.

The default username is root, and the password is the same as supplied in the .env file.

## Support & Feedback
If you still have a question after using OpenLiteSpeed Docker, you have a few options.
* Join [the GoLiteSpeed Slack community](litespeedtech.com/slack) for real-time discussion
* Post to [the OpenLiteSpeed Forums](https://forum.openlitespeed.org/) for community support
* Reporting any issue on [Github ols-docker-env](https://github.com/litespeedtech/ols-docker-env/issues) project

**Pull requests are always welcome**