#!/bin/bash

cd `dirname $0`
source prettyprt

help(){
  echo "`basename $0` [-h] [-d] [-r <graphsql_root_dir>] [-u <user>] [-o] [-n]"
  echo "  -h  --  show this message"
  echo "  -d  --  use default config, GraphSQL user: graphsql, GraphSQL root dir: /home/graphsql/graphsql"
  echo "  -r  --  GraphSQL.Root.Dir"
  echo "  -u  --  GraphSQL user"
  echo "  -o  --  Enforce offline install"
  echo "  -n  --  Enforce online install, if no internet access, it will fail"
  exit 0
}

has_internet(){
  ping -c2 -i0.5 -W1 -q www.github.com >/dev/null 2>&1
  return $?
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

  sysctl -p > /dev/null 2>&1
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

cleanup(){
  rm -rf "$off_repo_dir"
  rm -f "$off_repo"
  if [[ $OS == "UBUNTU" ]] && cat /etc/apt/sources.list | grep "$newsource"; then
    sed -i '$ d' /etc/apt/sources.list
  fi
}

## Main ##
if [[ $EUID -ne 0 ]]; then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi

trap cleanup INT TERM EXIT

while getopts ":hdr:u:on" opt; do
  case $opt in
    h|H)
      help
      ;;
    v|V)
      LOG="`pwd`/gsql_syspre_install.log"
      ;;
    r|R)
      DATA_PATH=$OPTARG
      ;;
    u|U)
      GSQL_USER=$OPTARG
      ;;
    d|D)
      DEFAULT_INSTALL=true
      ;;
    o|O)
      OFFLINE=true
      ;;
    n|N)
      ONLINE=true
      ;;
  esac
done

# check os version, fail if not supported
LOG=${LOG:-/dev/null}
OS=$(get_os)
notice "Welcome to GraphSQL System Prerequisite Installer"

# ask for input if not specify username, input path, retrieve path if default
while [ "U$GSQL_USER" = 'U' ]; do
  echo
  echo -n "Enter the user who will own and run GraphSQL software: [graphsql] "
  read GSQL_USER < /dev/tty
  GSQL_USER=${GSQL_USER:-graphsql}
  if [ "${GSQL_USER}" = "root" ]; then
    echo
    warn "Running GraphSQL software as \"${GSQL_USER}\" is not recommended."
    read -p "Continue with user \"${GSQL_USER}\"? (y/N): " USER_ROOT < /dev/tty
    if [ "y${USER_ROOT}" = "yy" -o "y${USER_ROOT}" = "yY" ]; then
      break
    else
      GSQL_USER=''
    fi
  fi
done

if id ${GSQL_USER} >/dev/null 2>&1; then
  notice "User ${GSQL_USER} already exists."
else
  progress "Creating user ${GSQL_USER}"
  useradd ${GSQL_USER} -m -c "GraphSQL User" -s /bin/bash
  if [ "$?" != "0" ]; then
    warn "Failed to create user ${GSQL_USER}. Program terminated."
    exit 2
  fi
  progress "Setting password for user ${GSQL_USER}"
  passwd ${GSQL_USER} < /dev/tty
fi

USER_HOME=$(eval echo ~$GSQL_USER)

if [ "D${DATA_PATH}" = "D" ]; then
  echo
  echo 'Enter the path to install GraphSQL software and to store graph data.'
  echo -n 'This path is referred as "Graphsql.Root.Dir":' "[$USER_HOME] "
  read DATA_PATH < /dev/tty
  DATA_PATH=${DATA_PATH:-${USER_HOME}}
fi

if [ -d ${DATA_PATH} ]; then
  notice "Folder ${DATA_PATH} already exists"
  # notice "You may need to run command \"chown -R ${GSQL_USER} ${DATA_PATH}\" "
  chown -R "$GSQL_USER" "$DATA_PATH"
else
  progress "Creating folder ${DATA_PATH}"
  mkdir -p ${DATA_PATH}
  chown -R ${GSQL_USER} ${DATA_PATH}
fi

# setup repo, online or offline according to options or internet connection
progress "Setting up software package repository ..."
if [ "Q$OS" = "QRHEL" ]; then
  off_repo_dir="${PWD}/rpm_offline_repo"
else 
  off_repo_dir="${PWD}/deb_offline_repo"  
fi

off_repo="/etc/yum.repos.d/graphsql.repo"
if [[ ! $ONLINE && ! $OFFLINE ]]; then
  if [ -f "${off_repo_dir}.tar.gz" ]; then
    OFFLINE=true
  else 
    ONLINE=true
  fi
fi 

if [ "$OFFLINE" = true ]; then
  if [ ! -f "${off_repo_dir}.tar.gz" ]; then
    warn "No offline installation repository. Program terminated."
    exit 3
  fi
  if [ "Q$OS" = "QRHEL" ]; then
    if ! rpm -q tar >/dev/null 2>&1; then
      warn "Tar should be installed before GraphSQL installation. Program terminated."
      exit 3
    fi
  else
    if ! dpkg -s tar 2>&1 | grep -q 'install ok installed'; then
      warn "Tar should be installed before GraphSQL installation. Program terminated."
      exit 3
    fi
  fi
  tar -xzf "${off_repo_dir}.tar.gz"
  url="baseurl=file://${off_repo_dir// /%20}"
  newsource="deb file://${off_repo_dir// /%20}/ ./"
  title="${pkg_name}-Local"
elif [ "$ONLINE" = true ]; then
  if ! has_internet; then
    warn "No Internet connection. Program terminated"
    exit 3
  fi
  if [ "Q$OS" = "QRHEL" ]; then
    if ! rpm -q tar >/dev/null 2>&1; then
      yum -y install tar 1>>"$LOG" 2>&1
    fi
    if gcc --version | grep "4.4.7"; then
      wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
  else
    if ! dpkg -s tar 2>&1 | grep -q 'install ok installed'; then
      apt-get -y install tar 1>>"$LOG" 2>&1
    fi
  fi
  url="baseurl=http://service.graphsql.com/repo/centos"
  newsource="deb http://service.graphsql.com/repo/ubuntu ./"
  title="${pkg_name}-Remote"
fi

if [ "Q$OS" = "QRHEL" ]; then
  echo "[${title}]" > $off_repo
  echo "name=${title}" >> $off_repo
  echo "$url" >> $off_repo
  echo "gpgcheck=0" >> $off_repo
  echo "enabled=1" >> $off_repo
else
  echo "$newsource" >> /etc/apt/sources.list
  apt-get update 1>/dev/null
fi
  
# install rpm
progress "Installing required system software packages ..."
if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
  yum install -y ${pkg_name}
  rm -f "$off_repo"
  if gcc --version | grep "4.4.7"; then
    echo "#!/bin/bash" > /etc/profile.d/enableGcc11.sh
    echo "source /opt/rh/devtoolset-2/enable" >> /etc/profile.d/enableGcc11.sh
    echo "export X_SCLS=\"\`scl enable devtoolset-2 'echo \$X_SCLS'\`\"" >> /etc/profile.d/enableGcc11.sh
  fi  
else
  apt-get install -y --force-yes ${pkg_name}
  sed -i '$ d' /etc/apt/sources.list
fi
rm -rf "$off_repo_dir"

# config system, this should be defined in a separate shell file for easy extensibility
progress "Configuring system ..."
echo "#!/bin/bash" > /etc/profile.d/enableGcc11.sh
echo "source /opt/rh/devtoolset-2/enable" >> /etc/profile.d/enableGcc11.sh
echo "export X_SCLS=\"\`scl enable devtoolset-2 'echo \$X_SCLS'\`\"" >> /etc/profile.d/enableGcc11.sh
set_limits ${GSQL_USER} ${DATA_PATH}
set_sysctl ${USER_HOME}/graphsql_coredump  # leave core dumps at home

progress "Updating /etc/hosts"
set_etcHosts
