#!/bin/bash
#================================================================
# Let's Encrypt renewal script for Apache on Ubuntu/Debian
# @author Erika Heidi<erika@do.co>
# Usage: ./le-renew.sh [base-domain-name]
# More info: http://do.co/1mbVihI
#================================================================

SCRIPTS_DIR=$(realpath $(dirname ${BASH_SOURCE[0]})/..);

domain=$1
le_path='/opt/letsencrypt'
le_conf='/etc/letsencrypt'
exp_limit=30;

function log {
  echo "$(date): $1";
}

echo '================================================================';
log "RENEW CERTIFICATE FOR $domain";

get_domain_list(){
        certdomain=$1
        config_file="$le_conf/renewal/$certdomain.conf"

        if [ ! -f $config_file ] ; then
                log "[ERROR] The config file for the certificate $certdomain was not found."
                exit 1;
        fi

        domains=$(grep --only-matching --perl-regex "(?<=domains \= ).*" "${config_file}")
        last_char=$(echo "${domains}" | awk '{print substr($0,length,1)}')

        if [ "${last_char}" = "," ]; then
                domains=$(echo "${domains}" |awk '{print substr($0, 1, length-1)}')
        fi

        log $domains;
}

if [ -z "$domain" ] ; then
        log "[ERROR] you must provide the domain name for the certificate renewal."
        exit 1;
fi

last_letsencrypt_domain_id=$( ls -t /etc/letsencrypt/live/ | grep $domain* | head -n 1 );
cert_file="/etc/letsencrypt/live/$last_letsencrypt_domain_id/fullchain.pem"
log "last certificate directory: $last_letsencrypt_domain_id";

if [ ! -f $cert_file ]; then
        log "[ERROR] certificate file not found for domain $domain."
        exit 1;
fi

exp=$(date -d "`openssl x509 -in $cert_file -text -noout|grep "Not After"|cut -c 25-`" +%s)
datenow=$(date -d "now" +%s)
days_exp=$(echo \( $exp - $datenow \) / 86400 |bc)

log "Checking expiration date for $domain..."

if [ "$days_exp" -gt "$exp_limit" ] ; then
        log "The certificate is up to date, no need for renewal ($days_exp days left)."
        exit 0;
else
        log "The certificate for $domain is about to expire soon. Starting renewal request..."

        log "enabling renew config";
        a2dissite "${domain}.conf"
        a2ensite "${domain}-renew.conf"

        log "Restarting Apache..."
        /usr/sbin/service apache2 reload

        log "execute letsencrypt-renew"
        "$le_path"/letsencrypt-auto --apache --renew-by-default -n -d "${domain}"

        a2ensite "${domain}.conf"
        a2dissite "${domain}-renew.conf"

        log "Restarting Apache..."
        /usr/sbin/service apache2 restart

        log "Renewal process finished for domain $domain"
        exit 0;
fi
