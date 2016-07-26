FROM clubcedille/debian-supervisord

RUN  echo "# fusiondirectory repository \n\
deb http://repos.fusiondirectory.org/debian-wheezy wheezy main \n\
\n\
# fusiondirectory debian-extra repository \n\
deb http://repos.fusiondirectory.org/debian-extra wheezy main" > /etc/apt/sources.list.d/fusion.list && \
gpg --keyserver keys.gnupg.net --recv-key 62B4981F && \
gpg --export -a "Fusiondirectory Archive Manager <contact@fusiondirectory.org>" | apt-key add -


RUN apt-get update && \
     DEBIAN_FRONTEND=noninteractive apt-get install  -y slapd ldap-utils \
     fusiondirectory-schema \
     fusiondirectory-plugin-systems-schema \
     fusiondirectory-plugin-mail-schema \
     fusiondirectory-plugin-audit-schema \
     fusiondirectory-plugin-alias-schema \
     fusiondirectory-plugin-ssh-schema \
     fusiondirectory-plugin-sudo-schema \
     fusiondirectory-plugin-fusioninventory-schema \
     fusiondirectory-plugin-dns-schema \
     fusiondirectory-plugin-dsa-schema \
     fusiondirectory-plugin-ppolicy-schema \
     fusiondirectory-plugin-personal-schema

RUN schema2ldif /etc/ldap/schema/fusiondirectory/rfc2307bis.schema > /etc/ldap/schema/fusiondirectory/rfc2307bis.ldif && \
    sed -i "s|include: file:///etc/ldap/schema/nis.ldif|include: file:///etc/ldap/schema/fusiondirectory/rfc2307bis.ldif|g" /usr/share/slapd/slapd.init.ldif

# Default configuration: can be overridden at the docker command line
ENV SLDAP_ROOTPASS toor
ENV SLDAP_ORGANISATION Acme Widgets Inc.
ENV SLDAP_DOMAIN example.com


ADD slapd/slapd.sh /usr/local/bin/slapd.sh

# Add configurations
ADD slapd/overlay_ldif /root/overlay_ldif
ADD slapd/basedn_ldif /root/basedn_ldif

ADD supervisor-slapd.conf /etc/supervisor/conf.d/slapd.conf

# To prevent this error : "TERM environment variable not set."
ENV TERM xterm

EXPOSE 386
