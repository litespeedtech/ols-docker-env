#!/bin/bash

set -o errexit

setup_dependencies() {
    echo "INFO: Setting up dependencies."
    sudo apt-get install git -y
    sudo rm /usr/local/bin/docker-compose
    curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` \
        > docker-compose
    chmod +x docker-compose
    sudo mv docker-compose /usr/local/bin
    docker-compose --version
}

update_docker_configuration() {
    echo "INFO: Updating docker configuration."
    echo '{
    "experimental": true,
    "storage-driver": "overlay2",
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50
}' | sudo tee /etc/docker/daemon.json  
    sudo service docker restart  
}    

main() {
  setup_dependencies
  update_docker_configuration
  echo "SUCCESS: Done! Finished setting up Travis machine."
}

main