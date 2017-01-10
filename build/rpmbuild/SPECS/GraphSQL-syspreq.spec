Name:   GraphSQL-syspreq
Version:  0.8
Release:  1%{?dist}
Summary:  System prerequisites for GraphSQL system

Group:    System
License:  Commercial
URL:    http://www.graphsql.com/

Requires: curl, java, gcc, gcc-c++, pkgconfig, make, libtool, patch, gettext, openssh-clients, ntp

%description
GraphSQL System prerequisites.

%prep
ls

%build
ls

%install
ls

%files
%doc

%changelog

%post

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

warn(){
  echo "${bldred}Warning: $* $txtrst" | tee -a $LOG
}

notice(){
  echo "${bldblu}$* $txtrst" | tee -a $LOG
}

progress(){
  echo "${bldgre}*** $* ...$txtrst" | tee -a $LOG
}

has_internet(){
  ping -c2 -i0.5 -W1 -q www.github.com >/dev/null 2>&1
  return $?
}

cancel(){
  [ ! -z $PID ] && kill -9 $PID
  echo
  warn "Installation cancelled by user"
  exit 1
}

set_limits(){
  limit_user=$1
  data_path=$2

  noFile=1000000
  noProc=102400
  maxCore=2000000 #2GB
  partitionSize=$(df -Pk $data_path | tail -1 | awk '{print $4}')
  let "core = partitionSize / 10"
  [ "$core" -gt $maxCore ] && core=$maxCore

  limit_file=/etc/security/limits.d/98-graphsql.conf
  echo "$limit_user soft nofile $noFile" > $limit_file
  echo "$limit_user hard nofile $noFile" >> $limit_file
  echo "$limit_user soft nproc $noProc" >> $limit_file
  echo "$limit_user hard nproc $noProc" >> $limit_file
  echo "$limit_user soft core $core" >> $limit_file
  echo "$limit_user hard core $core" >> $limit_file

  if [ -f /etc/profile ]  # this is often seen on ubuntu system
  then
    sed -i -e 's/^\([ \t]*ulimit * -[SHcnu]\{2,3\} .*\)$/#\1/' /etc/profile
  fi

  if [ -f /etc/pam.d/common-session ]
  then
       if ! grep pam_limits /etc/pam.d/common-session >/dev/null 2>&1
       then
           echo "session required        pam_limits.so" >> /etc/pam.d/common-session
       fi
  fi
}

set_sysctl(){
  coreLocation=$1
  sysctl_file=/etc/sysctl.conf # use /etc/sysctl.d/98-graphsql.conf for newer OS

  sed -i -e 's/^net.core.somaxconn/#net.core.somaxconn/' $sysctl_file
  echo "net.core.somaxconn = 10240" >> $sysctl_file

  sed -i -e 's/^kernel.core_pattern/#kernel.core_pattern/' $sysctl_file
  echo "kernel.core_pattern=${coreLocation}/core-%e-%s-%p.%t" >> $sysctl_file

  # sysctl -p > /dev/null 2>&1
}

set_etcHosts(){
  IPS=$(ip addr|grep 'inet '|awk '{print $2}'|egrep -o "[0-9]{1,}.[0-9]{1,}.[0-9]{1,}.[0-9]{1,}"|xargs echo)
  for ip in $IPS
  do
    if ! grep $ip /etc/hosts >/dev/null 2>&1
    then
      echo "$ip `hostname`" >> /etc/hosts
    fi
  done
}

notice "Welcome to GraphSQL System Prerequisite Installer"

GSQL_USER='graphsql'
progress "Creating user ${GSQL_USER}"
useradd ${GSQL_USER} -m -c "GraphSQL User" -s /bin/bash >/dev/null 2>&1
echo "${GSQL_USER}" |passwd ${GSQL_USER} >/dev/null 2>&1

USER_HOME=$(eval echo ~$GSQL_USER)
DATA_PATH=${USER_HOME}
progress "Creating folder ${DATA_PATH}"
mkdir -p ${DATA_PATH}
chown -R ${GSQL_USER} ${DATA_PATH}
exit 0

progress "Tuning system parameters"
set_limits ${GSQL_USER} ${DATA_PATH}
set_sysctl ${USER_HOME}/graphsql_coredump  # leave core dumps at home

progress "Updating /etc/hosts"
set_etcHosts
