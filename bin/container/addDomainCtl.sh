#!/usr/bin/env bash

domain=${1//\./\\.}
#replace . with \.
#so example.com becomes example\.com, this is because in regex . is used for matching any character
#so the regex would match on example.com and example7com, because . matches on "7"
#httpd_conf=`cat httpd_config.conf`
check=$(perl -0777 -ne 'print $1 if /(^  member '$domain' \{.*[^}]*})/m' httpd_config.conf)
#check=$(perl -0777 -le "print $1 if /(^  member $domain \{.*[^}]*})/m" httpd_config.conf)
if [ ! -z "$check" ]; then
    echo "# It appears the domain already exist, therefor we won\'t add it. Check the httpd_config.conf if you believe this is a mistake"
    exit 0
else
    echo "# Domain has been added"
fi

perl -0777 -p -i -e 's/(vhTemplate centralConfigLog \{[^}]+)\}*(^.*listeners.*$)/\1$2
  member '$1' {
    vhDomain              '$1'
  }/gmi' httpd_config.conf

#perl -0777 -p -i.bak -e "s/(vhTemplate centralConfigLog \{[^}]+)\}*(^$)/\1
#  member $1 {
#    vhDomain              $1
#  }/gmi" httpd_config.conf  
