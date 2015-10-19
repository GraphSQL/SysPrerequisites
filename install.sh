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

if [[ $EUID -ne 0 ]]
then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi

has_internet(){
  ping -c2 -i0.5 -W1 -q www.github.com >/dev/null 2>&1
  return $?
}

cancel(){
    [ ! -z $PID ] && kill -9 $PID
    echo
    warn "Installation canceled by user"
    exit 1
}

trap cancel INT

if which apt-get > /dev/null 2>&1
then
    OS=UBUNTU
    PKGMGR=`which apt-get`
elif which yum >/dev/null 2>&1
then
    OS=RHEL
    PKGMGR=`which yum`
else
    warn "Unsupported OS."
    exit 2
fi

notice "Welcome to GraphSQL System Prerequisite Installer"

(
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
 	    read -p "Continue with user \"${GSQL_USER}\" (y/N): " USER_ROOT
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
    if [ "$?" != 0 ]
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
    progress "Creating folder ${DATA_PATH} ..."
    mkdir -p ${DATA_PATH}
    chown -R ${GSQL_USER} ${DATA_PATH}
 	fi
 	
  read -p "GraphSQL engine version: [4.3] " GIUM_VER
  GIUM_VER=${GIUM_VER:-4.3}

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
 	  #$PKGMGR -y groupinstall "development tools"
    PKGS="curl java-1.7.0-openjdk-devel wget gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake zlib-devel libyaml-devel gdbm-devel autoconf unzip python-devel gmp-devel lsof cmake openssh-clients nmap-ncat nc ntp postfix sysstat hdparm"
 	  $PKGMGR -y install $PKGS
	  chkconfig --level 345 ntpd on
	  service ntpd start
 	else
 	  #$PKGMGR -y install "build-essential"
    $PKGMGR update >/dev/null 2>&1 # this only updates source.lst, not packages
    PKGS="curl openjdk-7-jdk wget gcc cpp g++ bison flex libtool automake zlib1g-dev libyaml-dev autoconf unzip python-dev libgmp-dev lsof cmake ntp postfix sysstat hdparm "
 	  $PKGMGR -y install $PKGS
	  update-rc.d ntp enable
	  service ntp start 
 	fi

  # make libjvm.so available to gpath
  jvm=$(find /usr -type f -name libjvm.so|grep server | head -1)
  if [ "J$jvm" = 'J' ]
  then
    warn "Cannot find libjvm.so. GPath will not work without this file."
  else
    if which apt-get >/dev/null 2>&1
    then
      ln -sf $jvm /usr/lib/libjvm.so
    else
      ln -sf $jvm /lib64/libjvm.so
    fi

  fi
  
	if [ -f ./SysPrerequisites-master.tar ] #already downloaded
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
 	
  if ! which redis-server >/dev/null 2>&1
  then
    if [ -f graphsql_redis-2.8.17.tar.gz ]
    then
      progress "Installing redis server"
      tar xzf graphsql_redis-2.8.17.tar.gz
      cd redis-2.8.17
      make install
      utils/install_server.sh
      cd ..
      rm -rf redis-2.8.17
      service redis_6379 start
    fi
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
      progress "Installing Python Module $pymod"
      cd $pymod && python setup.py install
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

  if ! hash jq 2>/dev/null; then
    cp bin/jq /usr/bin/
  fi

 	echo
  
  # TOKEN is a faked one. Run feed_token.sh to change the token below.
  TOKEN='84C73D474150B3B54771053B17FA32CB31328EF3'
  GIT_TOKEN=$(echo $TOKEN |tr '97531' '13579' |tr 'FEDCBA' 'abcdef')

 	if has_internet
 	then
      progress "Downloading GIUM package"
      if [ "$GIUM_VER" != '4.3' ]
      then
 	      su - ${GSQL_USER} -c "curl -H 'Authorization: token $GIT_TOKEN' -L https://api.github.com/repos/GraphSQL/gium/tarball -o gium.tar"
      else
        if ! grep -q 'net.core.somaxconn' /etc/sysctl.conf
        then 
          echo "net.core.somaxconn = 10240" >> /etc/sysctl.conf
          sysctl -p > /dev/null
        fi
 	      su - ${GSQL_USER} -c "curl -H 'Authorization: token $GIT_TOKEN' -L https://api.github.com/repos/GraphSQL/gium/tarball/4.3 -o gium.tar"
      fi
 	fi

 	giumtar=$(eval "echo ~${GSQL_USER}/gium.tar")
  if [ -f $giumtar ]
  then
    progress "Installing GIUM package for ${GSQL_USER}"
    su - ${GSQL_USER} -c "tar xf gium.tar; GraphSQL-gium-*/install.sh; rm -rf GraphSQL-gium-*; rm -f gium.tar"
  else
    warn "You need to manually install IUM for user \"${GSQL_USER}\""
  fi

	## Install gsql_monitor service
  echo
	progress "Installing GSQL monitoring service"
	[ -x ./install-monitor-service.sh ] && ./install-monitor-service.sh $GSQL_USER
        [ -x ./SysPrerequisites-master/install-monitor-service.sh ] && (cd ./SysPrerequisites-master; ./install-monitor-service.sh $GSQL_USER)
	#rm -rf SysPrerequisites-master

 ) 2>&1 | tee ${HOME}/install-gsql.log

echo
echo "System prerequisites installation completed"
echo "Please check ${HOME}/install-gsql.log for installation details"
echo

echo "You may verify system settings by running \"check_system.sh\" script in SysPrerequisites-master folder."
