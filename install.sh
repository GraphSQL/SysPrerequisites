#!/bin/bash

usage(){
  echo "Usage: $0 [username] [path_for_user_original_data]"
  exit 1
}

has_internet(){
  ping -c3 -i0.5 -W1 -q www.github.com >/dev/null 2>&1
  return $?
}

if [[ $EUID -ne 0 ]]
then
  echo "Sudo or root rights are requqired to install prerequsites for GSQL software."
  echo "Please log in as root, or run command 'sudo bash' if you have sudo privileges."
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

(
 	if [ $# -gt 0 ]
 	then
 	  GSQL_USER=$1
 	fi
 	
 	while [ "U$GSQL_USER" = 'U' ] 
 	do
 	  read -p "Enter the user who will own and run GraphSQL software:" GSQL_USER
    if [ "${GSQL_USER}" = "root" ]
    then
      echo
      echo "Warning!!! Running GraphSQL software as \"${GSQL_USER}\" is not recommended."
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
 	  echo "User ${GSQL_USER} already exists."
 	else
 	  echo "Creating user ${GSQL_USER} ..."
 	  useradd ${GSQL_USER} -m -c "GraphSQL User" -s /bin/bash
 	  echo "Setting password for user ${GSQL_USER}"
 	  passwd ${GSQL_USER}
 	fi
 	
 	if [ $# -gt 1 ]
 	then
 	    DATA_PATH=$2
      echo "Use command line argument $2 for folder path"
 	fi
 	
 	while [ "D$DATA_PATH" = 'D' ] 
 	do
 	  read -p 'Enter the absolute path for "graphsql.root.dir":' DATA_PATH
 	done
 	
 	if [ -d ${DATA_PATH} ]
 	then
 	    echo "Folder ${DATA_PATH} already exists"
 	    echo "You may need to run command \"chown -R ${GSQL_USER} ${DATA_PATH}\" "
	    sleep 3
 	else
 	    echo "Creating folder ${DATA_PATH} to hold original data ..."
 	    mkdir -p ${DATA_PATH}
 	    chown -R ${GSQL_USER} ${DATA_PATH}
 	fi
 	
 	echo "Changing file handler limits in /etc/security/limits.conf"
 	if ! grep -q '* hard nofile 1000000' /etc/security/limits.conf
 	then 
 	  echo "* hard nofile 1000000" >> /etc/security/limits.conf
 	fi
 	
 	if ! grep -q '* soft nofile 1000000' /etc/security/limits.conf
 	then 
 	  echo "* soft nofile 1000000" >> /etc/security/limits.conf
 	fi
 	
 	echo "Install/Upgrade required tools and libraries ..."
 	
 	if [ $OS = 'RHEL' ]
 	then
 	  #$PKGMGR -y groupinstall "development tools"
 	  PKGS="java-1.7.0-openjdk-devel wget gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake zlib-devel libyaml-devel gdbm-devel autoconf unzip python-devel gmp-devel lsof redis cmake openssh-clients nmap-ncat"
 	  $PKGMGR -y install $PKGS
 	else
 	  #$PKGMGR -y install "build-essential"
    $PKGMGR update >/dev/null 2>&1 # this only updates source.lst, not packages
 	  PKGS="openjdk-7-jdk wget gcc cpp g++ bison flex libtool automake zlib1g-dev libyaml-dev autoconf unzip python-dev libgmp-dev lsof redis-server cmake"
 	  $PKGMGR -y install $PKGS
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
 	   			echo "Downloading System Prerequisite package ..."
 	   			curl  -L https://github.com/GraphSQL/SysPrerequisites/archive/master.tar.gz -o SysPrerequisites-master.tar
 	   			tar -xf SysPrerequisites-master.tar
 	   			cd SysPrerequisites-master
 	  	else
 	   			echo "No Internet connection. Cannot find SysPrerequisites in the current directory"
 	   			echo "Program terminated"
 	   			exit 3
 	  	fi
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
 	  echo "----- Install Python Module $pymod ------"
 	  cd $pymod
 	    python setup.py install
 	  cd ..
 	done  

    if ! hash jq 2>/dev/null; then
       cp bin/jq /usr/bin
    fi

# 	echo "----- Install Redis ------"
# 	tar xfz redis-stable.tar.gz
# 	cd redis-stable
# 	  make
# 	  echo "Copying redis server and client binary to /usr/bin"
# 	  cp src/redis-server  /usr/bin/
# 	  cp src/redis-cli  /usr/bin/
# 	cd ..
 	
	#rm -rf SysPrerequisites-master
 	echo
 	giumtar=$(eval "echo ~${GSQL_USER}/gium.tar")
 	if [ ! -f $giumtar ]
 	then
 	  if has_internet
 	  then
 	    echo "---- Downloading GIUM package ----"
 	    su - ${GSQL_USER} -c "curl -H 'Authorization: token 8105fbea7214e5c5881db5ee2e26d69a89ac384a' -L https://api.github.com/repos/GraphSQL/gium/tarball -o gium.tar"
 	  else
 	    echo "No Internet connection. Please copy GIUM package to $giumtar and rerun the program"
 	    exit 4 
 	  fi
 	fi
 	

 	echo
 	echo "----- Installing IUM for user \"${GSQL_USER}\" ------"
 	su - ${GSQL_USER} -c "tar xf gium.tar; GraphSQL-gium-*/install.sh; rm -rf GraphSQL-gium-*; rm -f gium.tar"
 ) 2>&1 | tee ${HOME}/install-gsql.log

echo 
echo "Please check ${HOME}/install-gsql.log for installation details"
echo "You may verify system settings by running \"check_system.sh\" script in SysPrerequisites-master folder."
 
