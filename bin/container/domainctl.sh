#!/usr/bin/env bash
CK_RESULT=''
HTTPD_CONF='httpd_config.conf'

help_message(){
    echo 'Command [-add|-del] [domain_name]'
    echo 'Example 1: domain-ctl.sh -add example.com'
    echo 'Example 2: domain-ctl.sh -del example.com'
}

dot_escape(){
    ESCAPE=$(echo ${1} | sed 's/\./\\./g')
}  

check_duplicate(){
    CK_RESULT=$(grep -E "${1}" ${2})
}

fst_match_line(){
    FIRST_LINE_NUM=$(grep -n -m 1 ${1} ${2} | awk -F ':' '{print $1}')
}
fst_match_after(){
    FIRST_NUM_AFTER=$(tail -n +${1} ${2} | grep -n -m 1 ${3} | awk -F ':' '{print $1}')
}
lst_match_line(){
    fst_match_after ${1} ${2} '}'
    LAST_LINE_NUM=$((${FIRST_LINE_NUM}+${FIRST_NUM_AFTER}-1))
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

check_www(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        echo 'www domain shoudnt be passed!'
        exit 1
    fi
}

www_domain(){
    check_www ${1}
    WWW_DOMAIN=$(echo www.${1})
}

add_domain(){
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    www_domain ${1}
    check_duplicate "member.*${DOMAIN}" ${HTTPD_CONF}
    if [ "${CK_RESULT}" != '' ]; then
        echo "# It appears the domain already exist! Check the ${HTTPD_CONF} if you believe this is a mistake!"
        exit 1
    else
        perl -0777 -p -i -e 's/(vhTemplate centralConfigLog \{[^}]+)\}*(^.*listeners.*$)/\1$2
  member '${1}' {
    vhDomain              '${1},${WWW_DOMAIN}'
  }/gmi' ${HTTPD_CONF}     
    fi
}

del_domain(){
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    check_duplicate "member.*${DOMAIN}" ${HTTPD_CONF}
    if [ "${CK_RESULT}" = '' ]; then
        echo "# We couldn't find the domain you wanted to remove! Check the ${HTTPD_CONF} if you believe this is a mistake!"
        exit 1
    else
        fst_match_line ${1} ${HTTPD_CONF}
        lst_match_line ${FIRST_LINE_NUM} ${HTTPD_CONF}
        sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${HTTPD_CONF}
    fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -add | -a | -A) shift
            add_domain ${1}
            ;;
        -del | -d | -D | -delete) shift
            del_domain ${1}
            ;;          
        *) 
            help_message
            ;;
    esac
    shift
done