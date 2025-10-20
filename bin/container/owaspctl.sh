#!/bin/bash
LSDIR='/usr/local/lsws'
OWASP_DIR="${LSDIR}/conf/owasp"
CRS_DIR='owasp-modsecurity-crs'
RULE_FILE='modsec_includes.conf'
LS_HTTPD_CONF="${LSDIR}/conf/httpd_config.xml"
OLS_HTTPD_CONF="${LSDIR}/conf/httpd_config.conf"
EPACE='        '
OWASP_V='4.3.0'

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '-E, --enable'
    echo "${EPACE}${EPACE}Will Enable mod_secure module with latest OWASP version of rules"
    echow '-D, --disable'
    echo "${EPACE}${EPACE}Will Disable mod_secure module with latest OWASP version of rules" 
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."       
    exit 0
}

check_lsv(){
    if [ -f ${LSDIR}/bin/openlitespeed ]; then
        LSV='openlitespeed'
    elif [ -f ${LSDIR}/bin/litespeed ]; then
        LSV='lsws'
    else
        echo 'Version not exist, abort!'
        exit 1     
    fi
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

mk_owasp_dir(){
    if [ -d ${OWASP_DIR} ] ; then
        rm -rf ${OWASP_DIR}
    fi
    mkdir -p ${OWASP_DIR}
    if [ ${?} -ne 0 ] ; then
        echo "Unable to create directory: ${OWASP_DIR}, exit!"
        exit 1
    fi
}

fst_match_line(){
    FIRST_LINE_NUM=$(grep -n -m 1 "${1}" ${2} | awk -F ':' '{print $1}')
}
fst_match_after(){
    FIRST_NUM_AFTER=$(tail -n +${1} ${2} | grep -n -m 1 ${3} | awk -F ':' '{print $1}')
}
lst_match_line(){
    fst_match_after ${1} ${2} ${3}
    LAST_LINE_NUM=$((${FIRST_LINE_NUM}+${FIRST_NUM_AFTER}-1))
}

enable_ols_modsec(){
    grep 'module mod_security {' ${OLS_HTTPD_CONF} >/dev/null 2>&1
    if [ ${?} -eq 0 ] ; then
        echo "Already configured for modsecurity."
    else
        echo 'Enable modsecurity'
        sed -i "s=module cache=module mod_security {\nmodsecurity  on\
        \nmodsecurity_rules \`\nSecRuleEngine On\n\`\nmodsecurity_rules_file \
        ${OWASP_DIR}/${RULE_FILE}\n  ls_enabled              1\n}\
        \n\nmodule cache=" ${OLS_HTTPD_CONF}
    fi    
}

enable_ls_modsec(){
    grep '<enableCensorship>1</enableCensorship>' ${LS_HTTPD_CONF} >/dev/null 2>&1
    if [ ${?} -eq 0 ] ; then
        echo "LSWS already configured for modsecurity"
    else
        echo 'Enable modsecurity'
        sed -i \
        "s=<enableCensorship>0</enableCensorship>=<enableCensorship>1</enableCensorship>=" ${LS_HTTPD_CONF}
        sed -i \
        "s=</censorshipControl>=</censorshipControl>\n\
        <censorshipRuleSet>\n\
        <name>ModSec</name>\n\
        <enabled>1</enabled>\n\
        <ruleSet>include ${OWASP_DIR}/${RULE_FILE}</ruleSet>\n\
        </censorshipRuleSet>=" ${LS_HTTPD_CONF}
    fi
}

enable_modsec(){
    if [ "${LSV}" = 'lsws' ]; then
        enable_ls_modsec
    elif [ "${LSV}" = 'openlitespeed' ]; then
        enable_ols_modsec
    fi
}

disable_ols_modesec(){
    grep 'module mod_security {' ${OLS_HTTPD_CONF} >/dev/null 2>&1
    if [ ${?} -eq 0 ] ; then
        echo 'Disable modsecurity'
        fst_match_line 'module mod_security' ${OLS_HTTPD_CONF}
        lst_match_line ${FIRST_LINE_NUM} ${OLS_HTTPD_CONF} '}'
        sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${OLS_HTTPD_CONF}
    else
        echo 'Already disabled for modsecurity'
    fi    
}

disable_ls_modesec(){
    grep '<enableCensorship>0</enableCensorship>' ${LS_HTTPD_CONF}
    if [ ${?} -eq 0 ] ; then
        echo 'Already disabled for modsecurity'
    else
        echo 'Disable modsecurity'
        sed -i \
        "s=<enableCensorship>1</enableCensorship>=<enableCensorship>0</enableCensorship>=" ${LS_HTTPD_CONF}
        fst_match_line 'censorshipRuleSet' ${LS_HTTPD_CONF}
        lst_match_line ${FIRST_LINE_NUM} ${LS_HTTPD_CONF} '/censorshipRuleSet'
        sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${LS_HTTPD_CONF}
    fi    
}

disable_modsec(){
    check_lsv
    if [ "${LSV}" = 'lsws' ]; then
        disable_ls_modesec
    elif [ "${LSV}" = 'openlitespeed' ]; then
        disable_ols_modesec
    fi
}

install_unzip(){
    if [ ! -f /usr/bin/unzip ]; then
        echo 'Install Unzip'
        apt update >/dev/null 2>&1
        apt-get install unzip -y >/dev/null 2>&1
    fi
}

backup_owasp(){
    if [ -d ${OWASP_DIR} ]; then
        echo "Detect ${OWASP_DIR} folder exist, move to ${OWASP_DIR}.$(date +%F).bk"
        if [ -d ${OWASP_DIR}.$(date +%F).bk ]; then
            rm -rf ${OWASP_DIR}.$(date +%F).bk
        fi
        mv ${OWASP_DIR} ${OWASP_DIR}.$(date +%F).bk
    fi
}   

install_owasp(){
    cd ${OWASP_DIR}
    echo 'Download OWASP rules'
    wget -q https://github.com/coreruleset/coreruleset/archive/refs/tags/v${OWASP_V}.zip
    unzip -qq v${OWASP_V}.zip
    rm -f v${OWASP_V}.zip
    mv coreruleset-* ${CRS_DIR}
}

configure_owasp(){
    echo 'Config OWASP rules.'
    cd ${OWASP_DIR}
    if [ -f ${CRS_DIR}/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example ]; then
        mv ${CRS_DIR}/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example ${CRS_DIR}/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
    fi
    if [ -f ${CRS_DIR}/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example ]; then
        mv ${CRS_DIR}/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example ${CRS_DIR}/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
    fi
    if [ -f ${RULE_FILE} ]; then
        mv ${RULE_FILE} ${RULE_FILE}.bk
    fi
    echo 'include modsecurity.conf' >> ${RULE_FILE}
    if [ -f ${CRS_DIR}/crs-setup.conf.example ]; then
        mv ${CRS_DIR}/crs-setup.conf.example ${CRS_DIR}/crs-setup.conf
        echo "include ${CRS_DIR}/crs-setup.conf" >> ${RULE_FILE}
    fi    
    ALL_RULES="$(ls ${CRS_DIR}/rules/ | grep 'REQUEST-\|RESPONSE-')"
    echo "${ALL_RULES}"  | while read LINE; do echo "include ${CRS_DIR}/rules/${LINE}" >> ${RULE_FILE}; done
    echo 'SecRuleEngine On' > modsecurity.conf
    chown -R lsadm ${OWASP_DIR}
}

main_owasp(){
    backup_owasp
    mk_owasp_dir
    install_unzip
    install_owasp
    configure_owasp
    check_lsv
    enable_modsec    
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[eE] | -enable | --enable)
            main_owasp
            ;;
        -[dD] | -disable | --disable)
            disable_modsec
            ;;          
        *) 
            help_message
            ;;
    esac
    shift
done
