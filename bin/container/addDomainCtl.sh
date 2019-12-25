#!/usr/bin/env bash
perl -0777 -p -i.bak -e "s/(vhTemplate centralConfigLog \{[^}]+)\}*(^$)/\1
  member $1 {
    vhDomain              $1
  }/gmi" httpd_config.conf  
