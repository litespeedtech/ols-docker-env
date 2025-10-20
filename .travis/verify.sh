#!/bin/bash

set -o errexit
EX_DM='example.com' 

install_demo(){
    ./bin/demosite.sh
}

verify_lsws(){
    curl -sIk http://localhost:7080/ | grep -i LiteSpeed
    if [ ${?} = 0 ]; then
        echo '[O]  https://localhost:7080/'
    else
        echo '[X]  https://localhost:7080/'
        exit 1
    fi          
}    

verify_page(){
    curl -sIk http://localhost:80/ | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo '[O]  http://localhost:80/' 
    else
        echo '[X]  http://localhost:80/'
        curl -sIk http://localhost:80/
        exit 1
    fi        
    curl -sIk https://localhost:443/ | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo '[O]  https://localhost:443/' 
    else
        echo '[X]  https://localhost:443/'
        curl -sIk https://localhost:443/
        exit 1
    fi       
}

verify_phpadmin(){
    curl -sIk http://localhost:8080/ | grep -i phpMyAdmin
    if [ ${?} = 0 ]; then
        echo '[O]  http://localhost:8080/' 
    else
        echo '[X]  http://localhost:8080/'
        exit 1
    fi      
    curl -sIk https://localhost:8443/ | grep -i phpMyAdmin
    if [ ${?} = 0 ]; then
        echo '[O]  http://localhost:8443/' 
    else
        echo '[X]  http://localhost:8443/'
        exit 1
    fi      
}

verify_add_vh_wp(){
    echo "Setup a WordPress site with ${EX_DM} domain"
    bash bin/domain.sh --add "${EX_DM}"
    bash bin/database.sh --domain "${EX_DM}"
    bash bin/appinstall.sh --app wordpress --domain "${EX_DM}"
    curl -sIk http://${EX_DM}:80/ --resolve ${EX_DM}:80:127.0.0.1 | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo "[O]  http://${EX_DM}:80/"
    else
        echo "[X]  http://${EX_DM}:80/"
        curl -sIk http://${EX_DM}:80/
        exit 1
    fi
}
verify_del_vh_wp(){
    echo "Remove ${EX_DM} domain"
    bash bin/domain.sh --del ${EX_DM}
    if [ ${?} = 0 ]; then
        echo "[O]  ${EX_DM} VH is removed"
    else
        echo "[X]  ${EX_DM} VH is not removed"
        exit 1
    fi
    echo "Remove examplecom DataBase"
    bash bin/database.sh --delete -DB examplecom
}

verify_owasp(){
    echo 'Updating LSWS'
    bash bin/webadmin.sh --upgrade 2>&1 /dev/null
    echo 'Enabling OWASP'
    bash bin/webadmin.sh --mod-secure enable
    curl -sIk http://localhost:80/phpinfo.php | awk '/HTTP/ && /403/'
    if [ ${?} = 0 ]; then
        echo '[O]  OWASP enable' 
    else
        echo '[X]  OWASP enable'
        curl -sIk http://localhost:80/phpinfo.php | awk '/HTTP/ && /403/'
        exit 1
    fi
    bash bin/webadmin.sh --mod-secure disable
    curl -sIk http://localhost:80/phpinfo.php | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo '[O]  OWASP disable' 
    else
        echo '[X]  OWASP disable'
        curl -sIk http://localhost:80/phpinfo.php
        exit 1
    fi       
}


main(){
    verify_lsws
    verify_phpadmin
    install_demo
    verify_page
    verify_owasp
    verify_add_vh_wp
    verify_del_vh_wp
}
main