#!/bin/bash
#yum update
# first check JAVA, GCC/G++, etc.
echo "----- Install JAVA ------"
if which java; then
    echo "Java has been installed already."
else
   yum -y install java-1.7.0-openjdk
fi

echo "----- Install GCC/G++ ------"
if which gcc; then
    echo "gcc has been installed already."
else
   yum -y groupinstall "Development Tools"
fi

if which g++; then
    echo "g++ has been installed already."
else
   yum -y groupinstall "Development Tools"
fi

echo "----- Install Some Other libs ------"
yum -y install libtool autoconf zlib-devel


# first check if python is installed and its version
python -V > install.dump 2>&1
python_stat=0
if grep Python install.dump; then
    if grep "Python 2.[6-9]" install.dump; then
        echo "Python version OK."
        python_stat=1
    elif grep "Python 3.*" install.dump; then
        echo "Python version OK."
        python_stat=2
    else 
        echo "Old Python version, need to update."
        python_stat=3
    fi
else
    echo "No Python installed"
    python_stat=4
fi

echo $python_stat 

if [ $python_stat -eq 3 ] || [ $python_stat -eq 4 ] 
then
    echo "----- Install Python 2.7 ------"
    echo "----- Install Prerequisites for Python  ------"
#    yum update
    yum -y install zlib-devel readline-devel tk gdbm-devel sqlite-devel autoconf libtool
    yum -y install openssl-devel
    yum -y install texinfo
    yum -y groupinstall "Development Tools"
    cd Python-2.7.5
    ./configure
    touch Include/Python-ast.h
    touch Python/Python-ast.c
    make
    make altinstall
    echo "----- Python 2.7 installed ------\n" 
    # check if we need to install virtualenv
    if [ $python_stat -eq 3 ]
    then
        echo "----- Install virtualenv ------"
        cd virtualenv-1.11.1
        /usr/local/bin/python setup.py install
        echo "----- create GSQL_ENV ------"
        virtualenv GSQL_ENV
        source GSQL_ENV/bin/activate
    fi
fi

echo "----- Install Other Libs/Pkgs ------"
yum -y install unzip python-devel gmp-devel lsof

# Now we need to install fabric
echo "----- Install Fabric ------"
cd pycrypto-2.6
python setup.py install
cd ../ecdsa-0.11
python setup.py install
cd ../paramiko-1.14.0
python setup.py install
cd ../nose-1.3.4
python setup.py install
cd ../PyYAML-3.10
python setup.py install
cd ../setuptools-5.4.1
python setup.py install
cd ../Fabric-1.8.2 
python setup.py install

echo "----- Install Kazoo ------"
cd ../kazoo-2.0.1
python setup.py install

echo "---- Install psutil ------"
cd ../psutil-2.1.3
python setup.py install

echo "----- Install Redis ------"
cd ../
tar xvfz redis-stable.tar.gz
cd redis-stable
# the following three are found needed on a AMAZON Linux....
cd deps
make hiredis  jemalloc  linenoise  lua
cd ../
make
cp src/redis-server  /usr/bin/
cp src/redis-cli  /usr/bin/

#now we need to install tcmalloc
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
# copy the *.so file to /usr/lib
cp /usr/local/lib/libtcmalloc* /usr/lib/
cp /usr/local/lib/libprofiler* /usr/lib/
cp /usr/local/lib/libunwind* /usr/lib/

# change open file limit
echo "* hard nofile 1000000" >> /etc/security/limits.conf
echo "* soft nofile 1000000" >> /etc/security/limits.conf

if [ "$#" -ne 0 ]
then
  echo "----- Install Build/Compile Tools ------"
  yum -y install cmake
  yum -y install java-1.7.0-openjdk-devel
  echo "Go to http://www.scons.org/download.php to download and install scons"
fi

echo "kill -HUP 1  and logoff and logon to make limit take effect"




