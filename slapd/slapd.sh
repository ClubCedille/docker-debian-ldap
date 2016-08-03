#!/bin/bash

# Crash hard and loud if error incomming...
set -e

PROJECT_DIR=$(dirname "${BASH_SOURCE}")

source ${PROJECT_DIR}/tools.sh

# Test variables bounding
set -x
: SLDAP_ROOTPASS=${SLAP_ROOTPASS}
: SLDAP_DOMAIN=${SLDAP_DOMAIN}
: SLDAP_ORGANISATION=${SLDAP_ORGANISATION}

export LDAP_DOMAIN_DC="dc=$(echo ${SLDAP_DOMAIN} | sed  's/\./,dc=/g')"


# Here, handle error manually
set +e

cmp -s /etc/ldap/slapd.d/slapd_configs_bootstrapped /var/lib/ldap/slapd_bootstrapped > /dev/null
CMP_RESULT=$?

set +x

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
        status "Theses files don't exist :  /etc/ldap/slapd.d/slapd_configs_bootstrapped /var/lib/ldap/slapd_bootstrapped. So, bootstrap slapd."

        if [ ! -e /etc/ldap/slapd.d/slapd_configs_bootstrapped ] && [ ! -e /var/lib/ldap/slapd_bootstrapped ] ; then
            preconfigure_slapd
            supervisorctl start slapd-deamon-config
            wait_slapd
            configure_slapd
            supervisorctl stop slapd-deamon-config

            # Remove password as environment variable
            export SLDAP_ROOTPASS=""
            export FUSIONDIRECTORY_PASSWORD=""

            supervisorctl start slapd-deamon
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


        # Remove password as environment variable
        export SLDAP_ROOTPASS=""
        export FUSIONDIRECTORY_PASSWORD=""

        supervisorctl start slapd-deamon
        exit 0

        ;;
    *)
        echo "Unhandled error number $CMP_RESULT from the following command :
        cmp -s /etc/ldap/slapd.d/slapd_configs_bootstrapped /var/lib/ldap/slapd_bootstrapped > /dev/null"
        exit 3
esac
