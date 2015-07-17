#!/bin/bash

# The installation of gsql_monitor requires root or sudo privilege.

if [ $EUID -ne 0 ]
then
  echo "Sudo or root rights requqired to run this script."
  exit 1
fi

for cmd in cp chmod chown sudo sed
do
  if which $cmd >/dev/null 2>&1
  then
    eval $cmd=$(which $cmd)
  else
    echo "Command $cmd not found. Failed to install the program."
    exit 1
  fi
done

if [ -f ./gsql_monitor ]
then
  SRC="./gsql_monitor"
else
  BASE_DIR=`dirname $0`
  SRC="${BASE_DIR}/admin/src/GSQL/scripts/gsql_monitor"
fi

if [ $# -lt 1 ]
then
  read -p "Enter GraphSQL user name: " user
else
  user=$1
fi

if ! id $user >/dev/null 2>&1
then
  echo "User \"$user\" not found. Aborted."
  exit 1
fi

if which apt-get > /dev/null 2>&1
then
  OS=UBUNTU
elif which yum >/dev/null 2>&1
then
  OS=RHEL
else
  echo "Unsupported OS. Please follow your system manual to install GSQL monitor service: $SRC"
  exit 1
fi

echo "Copying GSQL monitor startup script to /etc/init.d ..."
INSTALL="/usr/bin/install"
if [ -x "$INSTALL" ]
then
  $sudo "$INSTALL" -m 0755 -o 0 -g 0 $SRC /etc/init.d/gsql_monitor
else
  $sudo $cp $SRC /etc/init.d/gsql_monitor
  $sudo $chmod 0755 /etc/init.d/gsql_monitor
  $sudo $chown 0:0 /etc/init.d/gsql_monitor
fi

$sudo $sed -i -e "s#user=.*#user=${user}#" /etc/init.d/gsql_monitor

CHKCONFIG="/usr/sbin/chkconfig"
UPDATERC="/usr/sbin/update-rc.d"
if [ "Q$OS" = "QRHEL" ] && [ -x $CHKCONFIG ]  # Redhat or CentOS
then
  $sudo $CHKCONFIG --level 345 gsql_monitor on
elif [ "Q$OS" = "QUBUNTU" ] && [ -x $UPDATERC ]  #Ubuntu or Debian
then
  $sudo $UPDATERC gsql_monitor defaults 88 12 
else
  echo "Please follow your system manual to install GSQL monitor service: $SRC"
fi
