# docker-debian-fusiondirectory

## Introduction

A basic configuration of the OpenLDAP server, slapd, with support for data
volumes.

This image will initialize a basic configuration of slapd. Most common schemas
are preloaded (all the schemas that come preloaded with the default Debian install of slapd).

*The only one modification changed from default schema is replacement of NIS by rfc2307bis-2.*

**Additional overlay** :

- memberOf
- ppolicy
- refint

**Additionnal schema** :

- Fusion Directory plugins for commons systems
- ppolicy

## Quickstart

Refer to :

https://github.com/ClubCedille/docker-debian-fusiondirectory/blob/master/README.md


## TODO

- [x] Having ldap database in Docker volume.
- Add more options on this Docker image.
