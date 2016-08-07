#!/bin/bash

export LDAP_DOMAIN_DC="dc=$(echo ${SLDAP_DOMAIN} | sed  's/\./,dc=/g')"

status () {
    echo "---> ${@}" >&2
}



function preconfigure_slapd {
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
}


# Configure slapd. This function is use after its declaration.
function configure_slapd {


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
         ls /opt/slapd/overlay_ldif/*.in | sed 's/\.in$//g' | xargs -i bash -c  "envsubst < {}.in > {}.ldif"
         ls /opt/slapd/overlay_ldif/*.ldif | xargs -i ldapmodify -H ldapi:/// -Y EXTERNAL -f {}

         echo "Configure BaseDn"
         ls /opt/slapd/basedn_ldif/*.in | sed 's/\.in$//g' | xargs -i bash -c  "envsubst < {}.in > {}.ldif"
         ls /opt/slapd/basedn_ldif/*.ldif | xargs -i ldapmodify -H ldapi:/// -D cn=admin,${LDAP_DOMAIN_DC} -w ${SLDAP_ROOTPASS} -f {}

         # Generate and keep seesion ID
         if [ ! -f /etc/default/slapd-id ]; then
             openssl rand 100000 |   tr -dc _A-Z-a-z-0-9 | head -c${1:-32} > /etc/default/slapd-id
         fi

         # Assign session ID to potential Docker volumes
         cat /etc/default/slapd-id > /var/lib/ldap/slapd_bootstrapped
         cat /etc/default/slapd-id > /etc/ldap/slapd.d/slapd_configs_bootstrapped
        )

}

function wait_slapd {

    set +e
    for i in {0..30}
    do
        ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config >/dev/null
        is_slapd_running=$?

        if (( "${is_slapd_running}" == 0 )); then
            break 1;
        else
            if (( "$i"  == 30 )); then
                echo "Ldap server dont respond after $i seconds"
                exit 1 ;
            fi;
        fi;
        sleep 1
        echo .
    done
    set -e
}
