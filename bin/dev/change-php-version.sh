#! /bin/bash

if [ "$1" != "lsphp74" ] && [ "$1" != "lsphp81" ] && [ "$1" != "lsphp82" ]; then
    echo "This lsphp version is not supported yet"
    exit;
fi

# blank is file format
sed -i "s/add[[:space:]]\+lsapi:[[:alnum:]]\+[[:space:]]\+php/add                     lsapi:$1 php/g" /usr/local/lsws/conf/httpd_config.conf

cat /usr/local/lsws/conf/httpd_config.conf | grep -A 3 "scripthandler"
echo "---After change will being lsphp you choose if not contact dev pls---"
/usr/local/lsws/bin/lswsctrl restart