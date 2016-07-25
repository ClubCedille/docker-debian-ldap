# docker-debian-fusiondirectory

## Introduction

A basic configuration of the OpenLDAP server, slapd, with support for data
volumes.


This image will initialize a basic configuration of slapd. Most common schemas
are preloaded (all the schemas that come preloaded with the default Debian install of slapd).

The only one modification changed from default schema is replacement of NIS by rfc2307bis-2.



schema modify from default configuration is rfc2307bis-2

added to the directory will be
the root organisational unit.

 opendldap
