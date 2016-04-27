#!/bin/bash

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

help()
{
  echo "`basename $0` [-h] [-l] [-i <ium_version>] [-u <user>] [-r <graphsql_root_dir>]" 
  echo "  -h  --  show this message"
  echo "  -l  --  send output to a log file." 
  echo "  -i  --  IUM version (branch)"
  echo "  -r  --  Graphsql.Root.Dir"
  echo "  -u  --  GraphSQL user"
  exit 0
}

warn()
{
  echo "${bldred}Warning: $* $txtrst" | tee -a $LOG
}

notice()
{
  echo "${bldblu}$* $txtrst" | tee -a $LOG
}

progress()
{
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

## check OS version. Terminate if OS is not supported.  
get_os(){
  if which apt-get > /dev/null 2>&1
  then
    os_version=$(lsb_release  -r | awk '{print $2}' | cut -d. -f1)
    if [ "$os_version" -lt 12 ]
    then
      warn "Unsupported OS. Please upgrade to Ubuntu 12.x or above."
      exit 2
    else
      echo UBUNTU
    fi
  elif which yum >/dev/null 2>&1
  then
    os_version=$(rpm -qa | grep 'kernel-' | head -1 |grep -o .'el[0-9]'. | grep -o '[0-9]') 
    if [ "$os_version" -lt 6 ]
    then
      warn "Unsupported OS. Please upgrade to RHEL or CentOS 6.x or above."
      exit 2
    else
      echo RHEL
    fi
  else
    warn "Unknown OS. Please contact GraphSQL support."
    exit 2
  fi
}

install_service(){
  run_as=$1
  srv_name=$2
  start_order=$3
  let "stop_order = 100 - ${start_order}"

  srv_src=./${srv_name}
  srv_dest=/etc/init.d/${srv_name}
  if [ -f $srv_src ]
  then
    cp -f $srv_src $srv_dest
    chmod 0755 $srv_dest
    chown 0:0 $srv_dest
    sed -i -e "s#user=.*#user=${run_as}#" $srv_dest

    if which chkconfig >/dev/null 2>&1  # Redhat or CentOS
    then
      chkconfig --level 2345 ${srv_name} on
    elif which update-rc.d  >/dev/null 2>&1
    then
      update-rc.d ${srv_name} defaults ${start_order} ${stop_order} >/dev/null 2>&1
    else
      warn "Please follow your system manual to install $srv_name service: $SRC"
    fi
  else
    warn "Service file $srv_src not found in folder"
  fi
}

set_limits()
{
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
}

set_sysctl()
{
  coreLocation=$1
  sysctl_file=/etc/sysctl.conf # use /etc/sysctl.d/98-graphsql.conf for newer OS

  sed -i -e 's/^net.core.somaxconn/#net.core.somaxconn/' $sysctl_file 
  echo "net.core.somaxconn = 10240" >> $sysctl_file

  sed -i -e 's/^kernel.core_pattern/#kernel.core_pattern/' $sysctl_file
  echo "kernel.core_pattern=${coreLocation}/core-%e-%s-%p.%t" >> $sysctl_file

  sysctl -p > /dev/null 2>&1
}

set_etcHosts()
{
  IPS=$(ip addr|grep 'inet '|awk '{print $2}'|egrep -o "[0-9]{1,}.[0-9]{1,}.[0-9]{1,}.[0-9]{1,}"|xargs echo)
  for ip in $IPS
  do
    if ! grep $ip /etc/hosts >/dev/null 2>&1
    then
      echo "$ip `hostname`" >> /etc/hosts
    fi
  done
}


## Main ##
if [[ $EUID -ne 0 ]]
then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi

trap cancel INT

while getopts ":hli:r:u:" opt; do
  case $opt in
    h|H)
      help
      ;;
    l|L)
      LOG="syspre_install.log"
      ;;
    i|I)
      IUM_BRANCH=$OPTARG
      ;;
    r|R)
      DATA_PATH=$OPTARG
      ;;
    u|U)
      GSQL_USER=$OPTARG
      ;;
  esac
done

LOG=${LOG:-/dev/null} # suppress log by default
IUM_BRANCH=${IUM_BRANCH:-prod_0.1}
cp -f /dev/null $LOG >/dev/null 2>&1

OS=$(get_os)
if [ "Q$OS" = "QRHEL" ]  # Redhat or CentOS
then
  PKGMGR=`which yum`
else
  PKGMGR=`which apt-get`
fi

notice "Welcome to GraphSQL System Prerequisite Installer"

if [ -d ./SysPrerequisites-graphsql ]
then
  cd SysPrerequisites-graphsql
else
  if [ ! -f ./check_system.sh ]
  then
    if has_internet
    then
      progress "Downloading system prerequisite package"
      curl  -L https://github.com/GraphSQL/SysPrerequisites/archive/graphsql.tar.gz | tar zxf -
      cd SysPrerequisites-graphsql
    else
      warn "No Internet connection. Please download system prerequisite package from https://github.com/GraphSQL/SysPrerequisites/archive/graphsql.tar.gz"
      warn "Program terminated"
      exit 3
    fi
  fi
fi

while [ "U$GSQL_USER" = 'U' ]
do
  echo
  echo -n "Enter the user who will own and run GraphSQL software: [graphsql] "
  read GSQL_USER < /dev/tty
  GSQL_USER=${GSQL_USER:-graphsql}
  if [ "${GSQL_USER}" = "root" ]
  then
    echo
    warn "Running GraphSQL software as \"${GSQL_USER}\" is not recommended."
    read -p "Continue with user \"${GSQL_USER}\"? (y/N): " USER_ROOT < /dev/tty
    if [ "y${USER_ROOT}" = "yy" -o "y${USER_ROOT}" = "yY" ]
    then
      break
    else
      GSQL_USER=''
    fi
  fi
done
 	
if id ${GSQL_USER} >/dev/null 2>&1
then
  notice "User ${GSQL_USER} already exists."
else
  progress "Creating user ${GSQL_USER}"
  useradd ${GSQL_USER} -m -c "GraphSQL User" -s /bin/bash
  if [ "$?" != "0" ]
  then
    warn "Failed to create user ${GSQL_USER}. Program terminated."
    exit 2
  fi
  progress "Setting password for user ${GSQL_USER}"
  passwd ${GSQL_USER} < /dev/tty
fi
 	
USER_HOME=$(eval echo ~$GSQL_USER)

if [ "D${DATA_PATH}" = "D" ]
then
  echo
  echo 'Enter the path to install GraphSQL software and to store graph data.'
  echo -n 'This path is referred as "Graphsql.Root.Dir":' "[$USER_HOME] "
  read DATA_PATH < /dev/tty
  DATA_PATH=${DATA_PATH:-${USER_HOME}}
fi
 	
if [ -d ${DATA_PATH} ]
then
  notice "Folder ${DATA_PATH} already exists"
  notice "You may need to run command \"chown -R ${GSQL_USER} ${DATA_PATH}\" "
else
  progress "Creating folder ${DATA_PATH}"
  mkdir -p ${DATA_PATH}
  chown -R ${GSQL_USER} ${DATA_PATH}
fi
 	
progress "Tuning system parameters"
set_limits ${GSQL_USER} ${DATA_PATH}
set_sysctl ${USER_HOME}/graphsql_coredump  # leave core dumps at home

progress "Updating /etc/hosts"
set_etcHosts

progress "Checking required system tools and libraries"
if which javac > /dev/null 2>&1
then
  jdk_ver=$(javac -version 2>&1 |awk '{print $2}' | tr -d '.')
  jdk_num=${jdk_ver%_*}
  if [ "$jdk_num" -lt 170 ]
  then
    jdk_installed='N'
  else
    jdk_installed='Y'
  fi
else
  jdk_installed='N'
fi

if [ "$jdk_installed" = 'N' ]
then
  if [ "$OS" = 'RHEL' ]
  then
    toBeInstalled='java-1.7.0-openjdk-devel'
  else
    toBeInstalled='openjdk-7-jdk'
  fi
else
  toBeInstalled=''
fi

if [ "$OS" = 'RHEL' ]
then
  if [ ! -f  /etc/yum.repos.d/epel.repo ]
  then
    $PKGMGR -y install epel-release 1>>$LOG 2>&1  # required for python-unittest2
  fi
  
  PKGS="curl wget gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake zlib-devel libyaml-devel gdbm-devel autoconf unzip python-devel gmp-devel lsof cmake openssh-clients ntp postfix python-unittest2"
  for pkg in $PKGS
  do
    if ! rpm -q $pkg > /dev/null 2>&1
    then
      toBeInstalled="$toBeInstalled $pkg"
    fi
  done
else #Ubuntu
  $PKGMGR update >/dev/null 2>&1
  PKGS="curl wget gcc cpp g++ bison flex libtool automake zlib1g-dev libyaml-dev autoconf unzip python-dev libgmp-dev lsof cmake ntp postfix"
  for pkg in $PKGS
  do
    if ! dpkg -s $pkg 2>&1| grep -q 'install ok installed'
    then
      toBeInstalled="$toBeInstalled $pkg"
      if [ $pkg = "postfix" ]
      then
        debconf-set-selections <<< "postfix postfix/mailname string localhost.localdomain"
        debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local Only'"
      fi
    fi
  done
fi

if [ "T${toBeInstalled}" != "T" ]
then
  echo "Installing missing packages:${toBeInstalled}"
  if has_internet
  then
    $PKGMGR -y install ${toBeInstalled} 1>>$LOG 2>&1
    if [ "$?" != "0" ]
    then
      warn "Failed to install one or more packages. Program terminated."
      exit 3
    fi
  else
    if [ -d ./Packages ] # local repository
    then
      if [ $OS = 'RHEL' ]
      then
        gsql_repo="/etc/yum.repos.d/graphsql.repo"
        echo [graphsql] > $gsql_repo
        echo name=GraphSQL SysPrerequisite - Local >> $gsql_repo
        echo baseurl=file://${PWD}/Packages >> $gsql_repo
        echo gpgcheck=0 >> $gsql_repo
        echo enabled=1 >> $gsql_repo
        $PKGMGR --disablerepo \* --enablerepo graphsql -y install ${toBeInstalled} 1>>$LOG 2>&1
        rm -f $gsql_repo
      else
        gsql_source="/etc/apt/sources.list-gsql"
        cp -f /etc/apt/sources.list $gsql_source
        echo "deb file://${PWD}/Packages ./" > /etc/apt/sources.list
        $PKGMGR update >/dev/null 2>&1
        $PKGMGR -y --allow-unauthenticated install ${toBeInstalled} 1>>$LOG 2>&1

        mv -f $gsql_source /etc/apt/sources.list
        $PKGMGR update >/dev/null 2>&1
      fi
      result=$?

      if [ "$result" != "0" ]
      then
        warn "Failed to install one or more packages. Program terminated."
        exit 3
      fi
    else
      warn "No Internet access. Please download the offline installer or manually install $toBeInstalled "
      exit 4
    fi
  fi
fi

if [ $OS = 'RHEL' ]
then
  chkconfig --level 345 ntpd on 1>>$LOG 2>&1
  service ntpd start 1>>$LOG 2>&1
else
  update-rc.d ntp enable 1>>$LOG 2>&1
  service ntp start 1>>$LOG 2>&1
fi

# make libjvm.so available to gpath
jvm=$(find /usr -type f -name libjvm.so|grep server | head -1)
if [ "J$jvm" = 'J' ]
then
  warn "Cannot find libjvm.so. GPath will not work without this file."
else
  if [ $OS = 'RHEL' ]
  then
    ln -sf $jvm /lib64/libjvm.so
  else
    ln -sf $jvm /usr/lib/libjvm.so
  fi
fi

if [ ! -d /etc/tsar -a -f tsar.tar.gz ]
then
  progress "Installing utility tsar"
  tar zxf tsar.tar.gz
  cd tsar
  make install >>$LOG 2>&1
  cd ..
  rm -rf tsar
fi

if ! which redis-server >/dev/null 2>&1
then
  if [ -f graphsql_redis-2.8.17.tar.gz ]
  then
    progress "Installing redis server"
    tar xzf graphsql_redis-2.8.17.tar.gz
    cd redis-2.8.17
    make install 1>>$LOG 2>&1
    utils/install_server.sh 1>>$LOG 2>&1
    cd ..
    rm -rf redis-2.8.17
  fi
fi

if [ -f /etc/init.d/redis_6379 ]
then
  service redis_6379 start 1>>$LOG 2>&1
else
  service redis start 1>>$LOG 2>&1
fi

declare -a pyMod
declare -a pyDir
if has_internet
then
  #The indices of the two arrays must match. Use associative arrays if bash >= 4.0
  pyMod=(Crypto ecdsa paramiko nose yaml setuptools fabric kazoo elasticsearch requests flask zmq psutil)
  pyDir=(pycrypto-2.6 ecdsa-0.11 paramiko-1.14.0 nose-1.3.4 PyYAML-3.10 setuptools-5.4.1 Fabric-1.8.2 kazoo-2.0.1 elasticsearch-py requests-2.7.0 Flask-0.10.1 pyzmq-15.2.0 psutil-2.1.3)
else
  pyMod=(Crypto ecdsa paramiko nose yaml setuptools fabric kazoo urllib3 elasticsearch requests itsdangerous jinja2 werkzeug flask zmq psutil)
  pyDir=(pycrypto-2.6 ecdsa-0.11 paramiko-1.14.0 nose-1.3.4 PyYAML-3.10 setuptools-5.4.1 Fabric-1.8.2 kazoo-2.0.1 urllib3-1.10.1 elasticsearch-py requests-2.7.0 itsdangerous-0.21 Jinja2-2.6 Werkzeug-0.11.9 Flask-0.10.1 pyzmq-15.2.0 psutil-2.1.3)

fi

for i in $(seq 0 $((${#pyMod[@]} - 1)))
do
  if ! python -c "import ${pyMod[$i]}" >/dev/null 2>&1
  then
    if [ -f ${pyDir[$i]}.tar.gz ]
    then
      tar zxf ${pyDir[$i]}.tar.gz
      if [ -f ./${pyDir[$i]}/setup.py ]
      then
        cd ${pyDir[$i]}
        progress "Installing Python module ${pyMod[$i]}"
        python setup.py install 1>>$LOG 2>&1
        [ "$?" != 0 ] && warn "Failed to install ${pyMod[$i]}"
        cd ..
      fi
      rm -rf ${pyDir[$i]}
    else
      warn "${pyDir[$i]}.tar.gz not found"
    fi
  fi
done

for numberPy in "/usr/lib64/python2.6/site-packages/Crypto/Util/number.py" \
                "/usr/lib/python2.6/site-packages/pycrypto-2.6.1-py2.6-linux-x86_64.egg/Crypto/Util/number.py"
do
  [ -f $numberPy ] && sed -i -e 's/_warn("Not using mpz_powm_sec/pass #_warn("Not using mpz_powm_sec/' $numberPy
done

if [ ! -d $USER_HOME/.python-eggs ]
then
  su - ${GSQL_USER} -c "mkdir ~/.python-eggs; chmod go-w ~/.python-eggs"
else
  su - ${GSQL_USER} -c "chmod go-w ~/.python-eggs"
fi

if ! hash jq 2>/dev/null; then
  cp bin/jq /usr/bin/
fi

echo

TOKEN='84C73D474150B3B54771053B17FA32CB31328EF3'
GIT_TOKEN=$(echo $TOKEN |tr '97531' '13579' |tr 'FEDCBA' 'abcdef')

if has_internet
then
  progress "Downloading IUM package"
  su - ${GSQL_USER} -c "curl -H 'Authorization: token $GIT_TOKEN' -L https://api.github.com/repos/GraphSQL/gium/tarball/${IUM_BRANCH} -o gium.tar"
fi

if [ -f ${USER_HOME}/gium.tar ]
then
  progress "Installing IUM package for ${GSQL_USER}"
  su - ${GSQL_USER} -c "tar xf gium.tar; GraphSQL-gium-*/install.sh; rm -rf GraphSQL-gium-*; rm -f gium.tar"
else
  warn "IUM package not found. Please install IUM for user \"${GSQL_USER}\" manually"
fi

echo
progress "Installing GraphSQL service"
install_service $GSQL_USER graphsql 87

progress "Installing GraphSQL Monitor service"
install_service $GSQL_USER gsql_monitor 88


echo
echo "System prerequisite installation completed."
[ "$LOG" = "/dev/null" ] || echo "Check \"${LOG}\" for details."
echo
echo "Please run \"${PWD}/check_system.sh\" to verify system settings."
