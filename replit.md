# OpenLiteSpeed WordPress Docker Environment

## Overview
This is a Docker-based project for deploying WordPress with OpenLiteSpeed web server. Since Docker is not available in Replit, a static documentation page has been created to display project information.

## Project Structure
- `public/index.html` - Documentation landing page
- `server.js` - Simple Node.js static file server
- `docker-compose.yml` - Docker Compose configuration (requires Docker)
- `bin/` - Production shell scripts for WordPress management
- `sites/` - Directory for website files (used with Docker)

## Running Locally
The project runs a Node.js static server on port 5000 that serves the documentation page.

## Original Purpose
This project is designed to be cloned to a Docker-enabled environment where it creates:
- OpenLiteSpeed 1.8.5 web server
- MariaDB 11.8 LTS database
- Redis for caching
- phpMyAdmin for database management

## Notes
- Docker and Docker Compose are required for full functionality
- The Replit version displays documentation only
