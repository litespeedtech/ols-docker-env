#!/usr/bin/env bash
domain=${1//\./\\.}
#replace . with \.
#so example.com becomes example\.com, this is because in regex . is used for matching any character
#so the regex would match on example.com and example7com, because . matches on "7"
perl -0777 -p -i.bak -e "s/(vhtemplate centralConfigLog \{[^}]+)*(^.*member "$domain" \{.*[^}]*})/\1#thislinewillbedeletedj98311/gmi" httpd_config.conf  
perl -i -ne '/#thislinewillbedeletedj98311/ or print' httpd_config.conf
#aboves replaces the matched group with a string and random numbers, then second command searches for that string and deletes the line
#if anyone can figure out how to do above in oneline, feel free to let us know
