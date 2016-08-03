#!/bin/bash

# Crash hard and loud if error incomming...
set -e

status () {
  echo "---> ${@}" >&2
}

# Test variables bounding
set -x
: SLDAP_ROOTPASS=${SLAP_ROOTPASS}
: SLDAP_DOMAIN=${SLDAP_DOMAIN}
: SLDAP_ORGANISATION=${SLDAP_ORGANISATION}

export LDAP_DOMAIN_DC="dc=$(echo ${SLDAP_DOMAIN} | sed  's/\./,dc=/g')"


function notify_slapd_started {
    while [[ "$finish" -ne 1 ]]; do echo "LDAP is ready to serve master" | gosu nobody:nobody nc -q1 -l -p 1337 ; done
}


function start_slapd {
        status "starting slapd"

        # Remove password as environment variable
        export SLDAP_ROOTPASS=""
        export FUSIONDIRECTORY_PASSWORD=""

        set -x
        exec /usr/sbin/slapd -h 'ldap:/// ldapi:///' -u openldap -g openldap -d 0 # `expr 64 + 256 + 512` # `expr 64 + 256 + 512` &
}

# Configure slapd. This function is use after its declaration.
function configure_slapd {

        status "configuring slapd for first run"

        cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${SLDAP_ROOTPASS}
slapd slapd/internal/adminpw password ${SLDAP_ROOTPASS}
slapd slapd/password2 password ${SLDAP_ROOTPASS}
slapd slapd/password1 password ${SLDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${SLDAP_DOMAIN}
slapd shared/organization string ${SLDAP_ORGANISATION}
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF


        dpkg-reconfigure -f noninteractive slapd

        (sleep 4;
         status "Prepare LDAP/Fusion-Directory schemas"
         fusiondirectory-insert-schema;
         fusiondirectory-insert-schema --insert \
                                       /etc/ldap/schema/fusiondirectory/mail-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/mail-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/alias-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/alias-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/systems-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/service-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/systems-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/audit-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/audit-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/openssh-lpk.schema \
                                       /etc/ldap/schema/fusiondirectory/sudo-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/sudo.schema \
                                       /etc/ldap/schema/fusiondirectory/inventory-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/fusioninventory-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/fusioninventory-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/dns-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/dns-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/dnszone.schema \
                                       /etc/ldap/schema/fusiondirectory/dsa-fd-conf.schema \
                                       /etc/ldap/schema/ppolicy.schema \
                                       /etc/ldap/schema/fusiondirectory/ppolicy-fd-conf.schema \
                                       /etc/ldap/schema/fusiondirectory/personal-fd.schema \
                                       /etc/ldap/schema/fusiondirectory/personal-fd-conf.schema

         echo "Configure overlays"
         ls /root/overlay_ldif/*.in | sed 's/\.in$//g' | xargs -i bash -c  "envsubst < {}.in > {}.ldif"
         ls /root/overlay_ldif/*.ldif | xargs -i ldapmodify -H ldapi:/// -Y EXTERNAL -f {}

         echo "Configure BaseDn"
         ls /root/basedn_ldif/*.in | sed 's/\.in$//g' | xargs -i bash -c  "envsubst < {}.in > {}.ldif"
         ls /root/basedn_ldif/*.ldif | xargs -i ldapmodify -H ldapi:/// -D cn=admin,${LDAP_DOMAIN_DC} -w ${SLDAP_ROOTPASS} -f {}

         # Generate and keep seesion ID
         if [ ! -f /etc/default/slapd-id ]; then
             openssl rand 100000 |   tr -dc _A-Z-a-z-0-9 | head -c${1:-32} > /etc/default/slapd-id
         fi

         # Assign session ID to potential Docker volumes
         cat /etc/default/slapd-id > /var/lib/ldap/slapd_bootstrapped
         cat /etc/default/slapd-id > /etc/ldap/slapd.d/slapd_configs_bootstrapped

         # Remove password as environment variable
         export SLDAP_ROOTPASS=""
         export FUSIONDIRECTORY_PASSWORD=""

         echo "Notify setup ready to client"
         export finish=0
         trap 'finish=1; exit 1' INT TERM

        ) &

}


# Here, handle error manually
set +e

cmp -s /etc/ldap/slapd.d/slapd_configs_bootstrapped /var/lib/ldap/slapd_bootstrapped > /dev/null
CMP_RESULT=$?

case "$CMP_RESULT" in
    "1")
        status "The content ID of these files must be same to enforce slapd data integrity :
        /etc/ldap/slapd.d/slapd_configs_bootstrapped: $(cat /etc/ldap/slapd.d/slapd_configs_bootstrapped)
        /var/lib/ldap/slapd_bootstrapped: $(cat /var/lib/ldap/slapd_bootstrapped)"
        exit 1
        ;;
    "2")
        # continue to crash hard on error
        set -e

        if [ ! -e /etc/ldap/slapd.d/slapd_configs_bootstrapped ] && [ ! -e /var/lib/ldap/slapd_bootstrapped ] ; then
            configure_slapd
            start_slapd &
            notify_slapd_started
            exit 0
        else

            status "Only one of these files does not exist between
         /etc/ldap/slapd.d/slapd_configs_bootstrapped
        and
        /var/lib/ldap/slapd_bootstrapped"
            exit 2
        fi

        ;;
    0)
        # continue to crash hard on error
        set -e

        status "found already-configured slapd"
        start_slapd &
        notify_slapd_started
        exit 0

        ;;
    *)
        echo "Unhandled error number $CMP_RESULT from the following command :
        cmp -s /etc/ldap/slapd.d/slapd_configs_bootstrapped /var/lib/ldap/slapd_bootstrapped > /dev/null"
        exit 3
esac
