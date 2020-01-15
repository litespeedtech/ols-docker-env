#!/bin/bash
BOTCRON='/etc/cron.d/certbot'

certbothook(){
    grep 'lswsctrl restart' ${BOTCRON} >/dev/null
    if [ ${?} = 1 ]; then
        echo 'Add LSWS hook to certbot cronjob.'
        sed -i 's/0.*renew/&  --deploy-hook "\/usr\/local\/lsws\/bin\/lswsctrl restart"/g' ${BOTCRON}
    fi    
}

certbothook