#! /bin/bash
systemctl stop slapd
systemctl disable slapd
yum -y remove openldap-servers openldap-clients
rm -rf /var/lib/ldap
userdel ldap
rm -rf /etc/openldap
rm -rf /root/ldap-sync
