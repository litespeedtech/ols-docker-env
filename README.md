# OpenLiteSpeed WordPress Docker Container
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

The containers are now built and running. You should be able to access the WordPress installation with the configured domain in the browser address. By default it is http://127.0.0.1.

