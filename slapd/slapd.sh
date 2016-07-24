#!/bin/bash
set -eu

status () {
  echo "---> ${@}" >&2
}

set -x
: LDAP_ROOTPASS=${LDAP_ROOTPASS}
: LDAP_DOMAIN=${LDAP_DOMAIN}
: LDAP_ORGANISATION=${LDAP_ORGANISATION}

if [ ! -e /var/lib/ldap/docker_bootstrapped ]; then
  status "configuring slapd for first run"

  cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ROOTPASS}
slapd slapd/internal/adminpw password ${LDAP_ROOTPASS}
slapd slapd/password2 password ${LDAP_ROOTPASS}
slapd slapd/password1 password ${LDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
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
                                 /etc/ldap/schema/fusiondirectory/dsa-fd-conf.schema
   # /etc/ldap/schema/fusiondirectory/ppolicy-fd-conf.schema \
       # /etc/ldap/schema/fusiondirectory/personal-fd.schema \
       # /etc/ldap/schema/fusiondirectory/personal-fd-conf.schema \

  ) &


  touch /var/lib/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

status "starting slapd"
set -x
exec /usr/sbin/slapd -h 'ldap:/// ldapi:///' -u openldap -g openldap -d 0 # `expr 64 + 256 + 512`
