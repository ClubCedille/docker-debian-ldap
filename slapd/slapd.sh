#!/bin/sh

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

if [ ! -e /var/lib/ldap/docker_bootstrapped ]; then
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
   echo "Prepare functiondirectory schemas"
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

   echo "Notify setup ready to client"
   while true; do  echo "LDAP is ready to serve master" | nc -l 1337; done
  ) &


  touch /var/lib/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

status "starting slapd"
set -x
exec /usr/sbin/slapd -h 'ldap:/// ldapi:///' -u openldap -g openldap -d `expr 64 + 256 + 512` # `expr 64 + 256 + 512`
