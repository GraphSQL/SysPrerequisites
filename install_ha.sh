#!/bin/bash

# check parameter numbers
PRINT_USAGE=0
if [ "$#" -ne 2 ]; then
  PRINT_USAGE=1
fi

if [ $PRINT_USAGE -eq 1 ]; then
  echo "install_ha.sh <graphsql_path> <node_number>"
  echo "  example:"
  echo "    install_ha.sh /data/graphsql 1"
  exit 1
fi

if which apt-get > /dev/null 2>&1
then
    OS=UBUNTU
    PKGMGR=`which apt-get`
elif which yum >/dev/null 2>&1
then
    OS=RHEL
    PKGMGR=`which yum`
else
    echo "Unsupported OS." 
    exit 2
fi

echo "Operating System is $OS"

## Cannot handle gsql_admin, because gsql_admin is installed with a non root
## user usually. Which means it's hard to know where gsql_admin without user 
## information.
## The solution is let user run gsql_admin config-apply ha, and user specify
## a folder where the configure file located.
# Check if gsql_admin is ready
# if which gsql_admin > /dev/null; then
#  echo "gsql_admin found."
# else
#  echo "gsql_admin is not installed, please install gsql_admin and configure first."
#  exit 1
# fi

if grep "net.ipv4.ip_nonlocal_bind" /etc/sysctl.conf > /dev/null; then
  echo "net.ipv4.ip_nonlocal_bind is already enabled."
else
  echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
  sysctl -p
fi

$PKGMGR install haproxy
$PKGMGR install keepalived
chkconfig keepalived on
chkconfig haproxy on

# create symbol links for haproxy config and keepalived config
rm -f /etc/haproxy/haproxy.cfg
rm -f /etc/keepalived/keepalived.conf
ln -s $1/ha_config/haproxy$2.conf /etc/haproxy/haproxy.cfg
ln -s $1/ha_config/keepalived$2.conf /etc/keepalived/keepalived.conf


service haproxy restart 
service keepalived restart 

exit 0
