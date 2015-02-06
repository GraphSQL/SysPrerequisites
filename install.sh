#!/bin/bash

usage(){
  echo "Usage: $0 <username> <path_for_user_original_data>"
  exit 1
}

if [ $EUID -ne 0 ]
then
  echo "Sudo or root rights are requqired to install prerequsites for GSQL software."
  echo "Please log in as root, or run command 'sudo bash' if you have sudo privileges."
  exit 1
fi

if which apt-get > /dev/null 2>&1
then
    OS=UBUNTU
    PKGMGR=`which apt-get`
    JavaPkg='openjdk-7-jre-headless'
elif which yum >/dev/null 2>&1
then
    OS=RHEL
    PKGMGR=`which yum`
    JavaPkg='java-1.7.0-openjdk'
else
    echo "Unsupported OS. Please follow your system manual to install GSQL monitor service: ${SRC}/GSQL/scripts/monitor"
    exit 1
fi

echo "Operating System is $OS"

(
GSQL_USER=${1:-graphsql}
echo "Creating user ${GSQL_USER} for to run GSQL softare"
if id ${GSQL_USER} >/dev/null 2>&1
then
  echo "User ${GSQL_USER} already exists."
else
  useradd ${GSQL_USER} -m -c "GraphSQL User"
  echo "Setting password for user ${GSQL_USER}"
  passwd ${GSQL_USER}
fi

DATA_PATH=${2:-/graphsql}
echo "Creating folder ${DATA_PATH} to hold original user data ..."
if [ -d ${DATA_PATH} ]
then
  echo "Folder ${DATA_PATH} already exists"
else
  sudo mkdir -p ${DATA_PATH}
fi
chown -R ${GSQL_USER}:${GSQL_USER} ${DATA_PATH}

echo "Changing file handler limits in /etc/security/limits.conf"
if ! grep -q '* hard nofile 1000000' /etc/security/limits.conf
then 
  echo "* hard nofile 1000000" >> /etc/security/limits.conf
fi

if ! grep -q '* soft nofile 1000000' /etc/security/limits.conf
then 
  echo "* soft nofile 1000000" >> /etc/security/limits.conf
fi
kill -HUP 1

echo "Install/Upgrade required tools and libraries ..."
#PKGS="$JavaPkg gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake zlib-devel readline-devel tk gdbm-devel autoconf openssl-devel texinfo unzip python-devel gmp-devel lsof"
#PKGS="$JavaPkg gcc cpp gcc-c++ libgcc glibc glibc-common glibc-devel glibc-headers bison flex libtool automake autoconf unzip lsof"
PKGS="$JavaPkg unzip lsof"
$PKGMGR -y install $PKGS

echo "Downloading System Prerequisite package ..."
systar=`eval echo ~${GSQL_USER}/SysPrerequisites-master.tar`
if [ ! -f $systar ]
then
  su - ${GSQL_USER} -c "curl  -L https://github.com/GraphSQL/SysPrerequisites/archive/master.tar.gz -o SysPrerequisites-master.tar"
else
  echo "Found a copy of SysPrerequisites-master.tar"
fi

su - ${GSQL_USER} -c "tar -xf SysPrerequisites-master.tar"

eval cd ~${GSQL_USER}/SysPrerequisites-master
for pymod in 'pycrypto-2.6' \
		'ecdsa-0.11' \
		'paramiko-1.14.0' \
		'nose-1.3.4' \
		'PyYAML-3.10' \
		'setuptools-5.4.1' \
		'Fabric-1.8.2' \
		'kazoo-2.0.1' \
		'psutil-2.1.3'
do
  echo "----- Install Python Module $pymod ------"
  cd $pymod
  python setup.py install
  cd ..
done  
  
echo "----- Install Redis ------"
cd ../
tar xfz redis-stable.tar.gz
cd redis-stable
# the following three are found needed on a AMAZON Linux....
cd deps
make hiredis  jemalloc  linenoise  lua
cd ../
make

echo "Copying redis server and client binary to /usr/bin"
suod cp src/redis-server  /usr/bin/
cp src/redis-cli  /usr/bin/

echo "----- Install TCMalloc ------"
cd ../libunwind-1.1
autoreconf -i
./configure
make
make install
cd ../gperftools-2.2.1
./configure --enable-frame-pointers
make
make install
echo "Copying the TCMalloc libraries to /usr/lib"
cp /usr/local/lib/libtcmalloc* /usr/lib/
cp /usr/local/lib/libprofiler* /usr/lib/
cp /usr/local/lib/libunwind* /usr/lib/

echo "Downloading GIUM package ..."
giumtar=`eval ~${GSQL_USER}/gium.tar`
if [ ! -f giumtar ]
then
  su - ${GSQL_USER} -c "curl -H 'Authorization: token 910a68cc2ae0dba5ca9c3f17be3b7add588d0d02' -L https://api.github.com/repos/GraphSQL/gium/tarball -o gium.tar"
else
  echo "Found a copy of SysPrerequisites-master.tar"
fi
su - ${GSQL_USER} -c "tar xvf gium.tar; cd GraphSQL-gium-*; ./install.sh"
source ~/.bashrc

) 2>&1 | tee ${HOME}/install-gsql.log

echo 
echo "Please check ${HOME}/install-gsql.log for details"
 
#gsql_admin check
#Installed:
#  java-1.7.0-openjdk.x86_64 1:1.7.0.75-2.5.4.0.el6_6  lsof.x86_64 0:4.82-4.el6 
#  unzip.x86_64 0:6.0-1.el6                           
#
#Dependency Installed:
#  alsa-lib.x86_64 0:1.0.22-3.el6                                                
#  atk.x86_64 0:1.30.0-1.el6                                                     
#  avahi-libs.x86_64 0:0.6.25-15.el6                                             
#  cairo.x86_64 0:1.8.8-3.1.el6                                                  
#  cups-libs.x86_64 1:1.4.2-67.el6                                               
#  flac.x86_64 0:1.2.1-6.1.el6                                                   
#  fontconfig.x86_64 0:2.8.0-5.el6                                               
#  freetype.x86_64 0:2.3.11-14.el6_3.1                                           
#  gdk-pixbuf2.x86_64 0:2.24.1-5.el6                                             
#  giflib.x86_64 0:4.1.6-3.1.el6                                                 
#  gnutls.x86_64 0:2.8.5-14.el6_5                                                
#  gtk2.x86_64 0:2.24.23-6.el6                                                   
#  hicolor-icon-theme.noarch 0:0.11-1.1.el6                                      
#  jasper-libs.x86_64 0:1.900.1-16.el6_6.3                                       
#  jpackage-utils.noarch 0:1.7.5-3.12.el6                                        
#  libICE.x86_64 0:1.0.6-1.el6                                                   
#  libSM.x86_64 0:1.2.1-2.el6                                                    
#  libX11.x86_64 0:1.6.0-2.2.el6                                                 
#  libX11-common.noarch 0:1.6.0-2.2.el6                                          
#  libXau.x86_64 0:1.0.6-4.el6                                                   
#  libXcomposite.x86_64 0:0.4.3-4.el6                                            
#  libXcursor.x86_64 0:1.1.14-2.1.el6                                            
#  libXdamage.x86_64 0:1.1.3-4.el6                                               
#  libXext.x86_64 0:1.3.2-2.1.el6                                                
#  libXfixes.x86_64 0:5.0.1-2.1.el6                                              
#  libXfont.x86_64 0:1.4.5-4.el6_6                                               
#  libXft.x86_64 0:2.3.1-2.el6                                                   
#  libXi.x86_64 0:1.7.2-2.2.el6                                                  
#  libXinerama.x86_64 0:1.1.3-2.1.el6                                            
#  libXrandr.x86_64 0:1.4.1-2.1.el6                                              
#  libXrender.x86_64 0:0.9.8-2.1.el6                                             
#  libXtst.x86_64 0:1.2.2-2.1.el6                                                
#  libasyncns.x86_64 0:0.8-1.1.el6                                               
#  libfontenc.x86_64 0:1.0.5-2.el6                                               
#  libjpeg-turbo.x86_64 0:1.2.1-3.el6_5                                          
#  libogg.x86_64 2:1.1.4-2.1.el6                                                 
#  libpng.x86_64 2:1.2.49-1.el6_2                                                
#  libsndfile.x86_64 0:1.0.20-5.el6                                              
#  libtasn1.x86_64 0:2.3-6.el6_5                                                 
#  libthai.x86_64 0:0.1.12-3.el6                                                 
#  libtiff.x86_64 0:3.9.4-10.el6_5                                               
#  libvorbis.x86_64 1:1.2.3-4.el6_2.1                                            
#  libxcb.x86_64 0:1.9.1-2.el6                                                   
#  pango.x86_64 0:1.28.1-10.el6                                                  
#  pixman.x86_64 0:0.32.4-4.el6                                                  
#  pkgconfig.x86_64 1:0.23-9.1.el6                                               
#  pulseaudio-libs.x86_64 0:0.9.21-17.el6                                        
#  shared-mime-info.x86_64 0:0.70-6.el6                                          
#  ttmkfdir.x86_64 0:3.0.9-32.1.el6                                              
#  tzdata-java.noarch 0:2014j-1.el6                                              
#  xorg-x11-font-utils.x86_64 1:7.2-11.el6                                       
#  xorg-x11-fonts-Type1.noarch 0:7.2-9.1.el6                                     
#
#Dependency Updated:
#  glib2.x86_64 0:2.28.8-4.el6             zlib.x86_64 0:1.2.3-29.el6            
