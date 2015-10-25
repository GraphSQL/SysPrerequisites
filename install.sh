#!/bin/bash

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

warn()
{
  echo "${bldred}Warning: $* $txtrst"
}

notice()
{
  echo "${bldblu}$* $txtrst"
}

progress()
{
  echo "${bldgre}*** $* ...$txtrst"
}

usage(){
  echo "Usage: $0 [username] [path_for_gstore]"
  exit 1
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

get_os(){
  if which apt-get > /dev/null 2>&1
  then
    echo UBUNTU
  elif which yum >/dev/null 2>&1
  then
    echo RHEL
  else
    warn "Unsupported OS."
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
      chkconfig --level 345 ${srv_name} on
    elif which update-rc.d  >/dev/null 2>&1
    then
      update-rc.d ${srv_name} defaults ${start_order} ${stop_order}
    else
      warn "Please follow your system manual to install $srv_name service: $SRC"
    fi
  else
    warn "Service file $srv_src not found in folder"
  fi
}


if [[ $EUID -ne 0 ]]
then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi

LOG=/dev/null #use /dev/null to suppress logs
cp -f /dev/null $LOG >/dev/null 2>&1

trap cancel INT

OS=$(get_os)
if [ "Q$OS" = "QRHEL" ]  # Redhat or CentOS
then
  PKGMGR=`which yum`
else
  PKGMGR=`which apt-get`
fi

  notice "Welcome to GraphSQL System Prerequisite Installer"

  if [ -f ./SysPrerequisites-master.tar ]
  then
    tar -xf SysPrerequisites-master.tar
    cd SysPrerequisites-master
  else
    if [ ! -d ./nose-1.3.4 ]
    then
      if has_internet
      then
        progress "Downloading System Prerequisite package"
        curl  -L https://github.com/GraphSQL/SysPrerequisites/archive/master.tar.gz -o SysPrerequisites-master.tar
        tar -xf SysPrerequisites-master.tar
        cd SysPrerequisites-master
      else
        warn "No Internet connection. Cannot find SysPrerequisites in the current directory"
        warn "Program terminated"
        exit 3
      fi
    fi
  fi

  [ $# -gt 0 ] && GSQL_USER=$1
 	
 	while [ "U$GSQL_USER" = 'U' ] 
 	do
    echo
    echo -n "Enter the user who will own and run GraphSQL software: [graphsql] "
    read GSQL_USER
    GSQL_USER=${GSQL_USER:-graphsql}
    if [ "${GSQL_USER}" = "root" ]
    then
      echo
      warn "Running GraphSQL software as \"${GSQL_USER}\" is not recommended."
      read -p "Continue with user \"${GSQL_USER}\"? (y/N): " USER_ROOT
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
 	  passwd ${GSQL_USER}
 	fi
 	
 	if [ $# -gt 1 ]
 	then
    DATA_PATH=$2
  else
    USER_HOME=$(eval echo ~$GSQL_USER)
    echo
    echo 'Enter the path to install GraphSQL software and to store graph data. '
    echo -n 'This path is referred as "graphsql.root.dir":' "[$USER_HOME] "
    read DATA_PATH
    DATA_PATH=${DATA_PATH:-${USER_HOME}}
 	fi
 	
 	if [ -d ${DATA_PATH} ]
 	then
    notice "Folder ${DATA_PATH} already exists"
    notice "You may need to run command \"chown -R ${GSQL_USER} ${DATA_PATH}\" "
    sleep 3
 	else
    progress "Creating folder ${DATA_PATH}"
    mkdir -p ${DATA_PATH}
    chown -R ${GSQL_USER} ${DATA_PATH}
 	fi
 	
  progress "Changing file handles and process limits in /etc/security/limits.conf"
  noFile=1000000
 	if ! grep -q "$GSQL_USER hard nofile $noFile" /etc/security/limits.conf
 	then 
 	  echo "$GSQL_USER hard nofile $noFile" >> /etc/security/limits.conf
 	fi
 	
 	if ! grep -q "$GSQL_USER soft nofile $noFile" /etc/security/limits.conf
 	then 
 	  echo "$GSQL_USER soft nofile $noFile" >> /etc/security/limits.conf
 	fi
 	
  noProc=102400
  if ! grep -q "$GSQL_USER hard nproc $noProc" /etc/security/limits.conf
  then 
    echo "$GSQL_USER hard nproc $noProc" >> /etc/security/limits.conf
  fi
  
  if ! grep -q "$GSQL_USER soft nproc $noProc" /etc/security/limits.conf
  then 
    echo "$GSQL_USER soft nproc $noProc" >> /etc/security/limits.conf
  fi

  if ! grep -q 'net.core.somaxconn' /etc/sysctl.conf
  then 
    echo "net.core.somaxconn = 10240" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
  fi

	progress "Updating /etc/hosts"
	IPS=$(ip addr|grep 'inet '|awk '{print $2}'|egrep -o "[0-9]{1,}.[0-9]{1,}.[0-9]{1,}.[0-9]{1,}"|xargs echo)
	for ip in $IPS
	do
		if ! grep $ip /etc/hosts >/dev/null 2>&1
		then
			echo "$ip	`hostname`" >> /etc/hosts
		fi
	done

  progress "Installing required system tools and libraries"
 	
 	if [ $OS = 'RHEL' ]
 	then
    PKGS="curl java-1.7.0-openjdk-devel wget gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake zlib-devel libyaml-devel gdbm-devel autoconf unzip python-devel gmp-devel lsof cmake openssh-clients nmap-ncat nc ntp postfix sysstat hdparm"
    $PKGMGR -y install $PKGS 1>>$LOG 2>&1
    if [ "$?" != "0" ]
    then
      warn "Failed to install one or more system packages: ${PKGS}. Program terminated."
      exit 3
    fi

	  chkconfig --level 345 ntpd on 1>>$LOG 2>&1
	  service ntpd start 1>>$LOG 2>&1
 	else
    $PKGMGR update >/dev/null 2>&1
    PKGS="curl openjdk-7-jdk wget gcc cpp g++ bison flex libtool automake zlib1g-dev libyaml-dev autoconf unzip python-dev libgmp-dev lsof cmake ntp postfix sysstat hdparm "
    $PKGMGR -y install $PKGS 1>>$LOG 2>&1
    if [ "$?" != "0" ]
    then
      warn "Failed to install one or more system packages: ${PKGS}. Program terminated."
      exit 3
    fi

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

 	for pymod in \
   	'pycrypto-2.6' \
 		'ecdsa-0.11' \
 		'paramiko-1.14.0' \
 		'nose-1.3.4' \
 		'PyYAML-3.10' \
 		'setuptools-5.4.1' \
 		'Fabric-1.8.2' \
 		'kazoo-2.0.1' \
 		'elasticsearch-py' \
 		'requests-2.7.0' \
 		'psutil-2.1.3'
 	do
    if [ -d $pymod ]
    then
      progress "Installing Python module $pymod"
      cd $pymod
      python setup.py install 1>>$LOG 2>&1
      cd ..
    else
      warn "$pymod not found"
    fi
 	done  

  numberPy="/usr/lib64/python2.6/site-packages/Crypto/Util/number.py"
  if [ -f $numberPy ]
  then
    sed -i -e 's/_warn("Not using mpz_powm_sec/pass #_warn("Not using mpz_powm_sec/' $numberPy
  fi

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
  GIUM_BRANCH='prod_0.1'

  read -p "Enter the IUM branch to install: [4.3] " GIUM_BRANCH
  GIUM_BRANCH=${GIUM_BRANCH:-4.3}
  [ "$GIUM_BRANCH" = '4.2' ] && GIUM_BRANCH='master'

 	if has_internet
 	then
    progress "Downloading GIUM package"
 	  su - ${GSQL_USER} -c "curl -H 'Authorization: token $GIT_TOKEN' -L https://api.github.com/repos/GraphSQL/gium/tarball/${GIUM_BRANCH} -o gium.tar"
 	fi

  if [ -f ${USER_HOME}/gium.tar ]
  then
    progress "Installing GIUM package for ${GSQL_USER}"
    su - ${GSQL_USER} -c "tar xf gium.tar; GraphSQL-gium-*/install.sh; rm -rf GraphSQL-gium-*; rm -f gium.tar"
  else
    warn "GIUM package not found. Please install IUM for user \"${GSQL_USER}\" manually"
  fi

  echo
  #progress "Installing GraphSQL service"
  #install_service $GSQL_USER graphsql 87

	progress "Installing GSQL monitor service"
  install_service $GSQL_USER gsql_monitor 88

	#rm -rf SysPrerequisites-master

echo
echo "System prerequisite installation completed."
echo

echo "You may verify system settings by running \"check_system.sh\" script in SysPrerequisites folder."
