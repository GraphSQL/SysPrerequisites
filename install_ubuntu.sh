#!/bin/bash
apt-get update
# first check JAVA, GCC/G++, etc.
echo "----- Install JAVA ------"
if which java; then
    echo "Java has been installed already."
else
   apt-get -y install openjdk-7-jre-headless
fi

echo "----- Install GCC/G++ ------"
if which gcc; then
    echo "gcc has been installed already."
else
   apt-get -y install build-essential
fi

if which g++; then
    echo "g++ has been installed already."
else
   apt-get -y install build-essential
   apt-get -y install g++
fi

echo "----- Install Some Other libs ------"
apt-get -y install libtool autoconf unzip zlib1g-dev

# first check if python is installed and its version
python -V > install.dump 2>&1
python_stat=0
if grep Python install.dump; then
    if grep "Python 2.[7-9]" install.dump; then
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
    apt-get update
    apt-get -y install build-essential zlib1g-dev libbz2-dev libreadline-dev libreadline-gplv2-dev libncursesw5-dev tk-dev libgdbm-dev libc6-dev
    apt-get -y install make autoconf libtool
    apt-get -y install sqlite3 libsqlite3-dev
    apt-get -y install libssl-dev
    apt-get -y install g++
    cd Python-2.7.5
    ./configure
    touch Include/Python-ast.h
    touch Python/Python-ast.c
    make
    make install
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
./configure
make
make install

# copy the *.so file to /usr/lib
cp /usr/local/lib/libtcmalloc* /usr/lib/
cp /usr/local/lib/libprofiler* /usr/lib/
cp /usr/local/lib/libunwind* /usr/lib/

# change open file limit
echo "* hard nofile 1000000" >> /etc/security/limits.conf
echo "* soft nofile 1000000" >> /etc/security/limits.conf

